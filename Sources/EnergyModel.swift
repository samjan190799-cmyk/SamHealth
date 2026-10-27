import Foundation

// MARK: - Энергия за день (чистая логика)
//
// Без HealthKit, SwiftUI и UserDefaults: файл проверяется юнит-тестами (Tests/EnergyModel).
//
// Что было не так до этого. Один и тот же расход считался в шести местах по-разному:
//  • на главной базовый обмен брался из Apple Health, а без данных — заглушка 1 650 ккал;
//  • в питании и в трекере веса — формула Миффлина, умноженная на «поправку соматотипа»,
//    у которой нет научного обоснования;
//  • в обоих случаях базовый обмен брался за ВЕСЬ день, а съеденное и активные калории — только
//    до текущего часа, поэтому утром «дефицит» выходил огромным (−2 000 ккал в 11 утра);
//  • цель по калориям была числом 2 200 для всех: и для 55-килограммовой женщины, и для
//    100-килограммового мужчины;
//  • кнопка «Применить нормы (… л воды и N ккал)» сохраняла только воду.
//
// Теперь: базовый обмен — формула Миффлина — Сан-Жеора по профилю, ровно один раз; расход
// «на сейчас» — это базовый обмен пропорционально прошедшей части суток плюс активные калории
// на этот момент; цель — из профиля или из сохранённой пользователем нормы.

// MARK: Профиль

public enum BiologicalSex: Equatable {
    case male
    case female

    /// Пол хранится в настройках строкой: «Мужской», «Женский» (в старых версиях — ещё «male»).
    public init(storedValue: String) {
        let value = storedValue.lowercased()
        self = (value.contains("муж") || value == "male") ? .male : .female
    }
}

/// Данные, нужные формуле. Значения вне разумных границ приводятся к границе,
/// а нечисловые заменяются типичными: формула на них не определена.
public struct EnergyProfile: Equatable {
    public static let weightRange: ClosedRange<Double> = 30.0...250.0
    public static let heightRange: ClosedRange<Double> = 100.0...230.0
    public static let ageRange: ClosedRange<Double> = 14.0...100.0

    public static let typicalWeightKg = 75.0
    public static let typicalHeightCm = 175.0
    public static let typicalAgeYears = 25.0

    public let weightKg: Double
    public let heightCm: Double
    public let ageYears: Double
    public let sex: BiologicalSex

    public init(weightKg: Double, heightCm: Double, ageYears: Double, sex: BiologicalSex) {
        self.weightKg = Self.sanitized(weightKg, range: Self.weightRange, fallback: Self.typicalWeightKg)
        self.heightCm = Self.sanitized(heightCm, range: Self.heightRange, fallback: Self.typicalHeightCm)
        self.ageYears = Self.sanitized(ageYears, range: Self.ageRange, fallback: Self.typicalAgeYears)
        self.sex = sex
    }

    private static func sanitized(_ value: Double, range: ClosedRange<Double>, fallback: Double) -> Double {
        guard value.isFinite else { return fallback }
        return min(max(value, range.lowerBound), range.upperBound)
    }
}

// MARK: Расчёты

public enum EnergyModel {
    /// Ккал на шаг при весе 70 кг; растёт пропорционально весу. Используется, только когда
    /// Apple Health не отдаёт активную энергию.
    public static let kcalPerStepAt70Kg = 0.042

    /// Коэффициент «лёгкая активность» (1,375): ориентир для нормы, пока пользователь не задал свою.
    public static let defaultActivityFactor = 1.375

    /// 1 кг жировой ткани ≈ 7 700 ккал.
    public static let kcalPerKgFat = 7_700.0

    public static let storedGoalRange = 1_000...6_000
    public static let defaultGoalRange = 1_200...4_500

    /// Ключ нормы калорий в UserDefaults.
    public static let dailyGoalDefaultsKey = "forma_daily_calorie_goal"

    /// Базовый обмен за сутки, ккал. Формула Миффлина — Сан-Жеора:
    /// 10·вес + 6,25·рост − 5·возраст + 5 (мужчины) или − 161 (женщины).
    public static func restingEnergyPerDay(_ profile: EnergyProfile) -> Double {
        let base = 10.0 * profile.weightKg + 6.25 * profile.heightCm - 5.0 * profile.ageYears
        return base + (profile.sex == .male ? 5.0 : -161.0)
    }

    /// Доля суток, прошедшая к моменту `now`, от 0 до 1. Считается по фактической длине дня,
    /// поэтому в дни перевода часов (23 или 25 часов) тоже сходится ровно в 1 к полуночи.
    public static func dayFraction(at now: Date, calendar: Calendar = .current) -> Double {
        let start = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return 0 }
        let length = end.timeIntervalSince(start)
        guard length > 0 else { return 0 }
        return min(1.0, max(0.0, now.timeIntervalSince(start) / length))
    }

    /// Базовый обмен, накопленный с начала суток.
    public static func restingEnergySoFar(
        _ profile: EnergyProfile,
        at now: Date,
        calendar: Calendar = .current
    ) -> Double {
        restingEnergyPerDay(profile) * dayFraction(at: now, calendar: calendar)
    }

    /// Оценка активных калорий по шагам. Нужна, только когда Apple Health ничего не отдал.
    public static func stepEnergyEstimate(steps: Int, weightKg: Double) -> Double {
        let weight = weightKg.isFinite
            ? min(max(weightKg, EnergyProfile.weightRange.lowerBound), EnergyProfile.weightRange.upperBound)
            : EnergyProfile.typicalWeightKg
        return Double(max(steps, 0)) * kcalPerStepAt70Kg * (weight / 70.0)
    }

    /// Сальдо «съедено минус сожжено». Отрицательное — дефицит, положительное — профицит.
    public static func balance(consumed: Double, burned: Double) -> Double {
        consumed - burned
    }

    /// Теоретическое изменение жировой ткани, граммы (знак как у сальдо).
    public static func fatChangeGrams(forBalance balance: Double) -> Double {
        balance / kcalPerKgFat * 1_000.0
    }

    // MARK: Норма калорий

    /// Ориентир нормы: поддержание веса при лёгкой активности, округлено до 50 ккал.
    public static func defaultDailyGoal(for profile: EnergyProfile) -> Int {
        let maintenance = restingEnergyPerDay(profile) * defaultActivityFactor
        let rounded = Int((maintenance / 50.0).rounded()) * 50
        return min(max(rounded, defaultGoalRange.lowerBound), defaultGoalRange.upperBound)
    }

    /// Суточные цели по белкам, жирам и углеводам, граммы. Опорная диета — прежние постоянные
    /// 140 / 70 / 240 г при 2 200 ккал; для другой нормы калорий они масштабируются пропорционально
    /// и округляются до 5 г. Раньше цели были теми же 140 / 70 / 240 г для всех.
    public static func macroGoals(forCalorieGoal calories: Int) -> (protein: Int, fat: Int, carbs: Int) {
        let scale = Double(min(max(calories, defaultGoalRange.lowerBound), storedGoalRange.upperBound)) / 2_200.0
        func rounded(_ grams: Double) -> Int { Int((grams * scale / 5.0).rounded()) * 5 }
        return (protein: rounded(140), fat: rounded(70), carbs: rounded(240))
    }

    /// Норма, которой пользуется приложение: сохранённая пользователем (из калибровки),
    /// если она в разумных пределах, иначе ориентир по профилю.
    public static func resolveDailyGoal(stored: Int, profile: EnergyProfile) -> Int {
        storedGoalRange.contains(stored) ? stored : defaultDailyGoal(for: profile)
    }
}
