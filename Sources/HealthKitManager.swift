import Foundation
import SwiftUI
import Combine
import HealthKit
import UserNotifications

// MARK: - Менеджер интеграции с Apple Health (HealthKit) и локальным кэшем
@MainActor
public class HealthKitManager: ObservableObject {
    public static let shared = HealthKitManager()
    
    public let healthStore = HKHealthStore()
    
    // MARK: - Флаги состояния
    @Published public var isHealthDataAvailable: Bool = HKHealthStore.isHealthDataAvailable()
    @Published public var isAuthorized: Bool = false
    @Published public var isRequested: Bool = false
    @Published public var authorizationError: String? = nil
    @Published public var showAuthorizationAlert: Bool = false
    @Published public var authorizationAlertMessage: String = ""
    @Published public var isSyncing: Bool = false
    @Published public var lastSyncTime: Date? = nil
    
    // Индикаторы глубокого импорта
    @Published public var isHistoricalSyncInProgress: Bool = false
    @Published public var historicalSyncStatusMessage: String? = nil
    @Published public var historicalSyncStats: (days: Int, workouts: Int, weights: Int) = (0, 0, 0)
    
    // MARK: - Пульс
    @Published public var isLiveHeartRateActive: Bool = false
    @Published public var liveHeartRate: Double = 0.0
    @Published public var latestHeartRate: Double = 0.0
    @Published public var restingHeartRate: Double = 0.0
    public var heartRate: Double {
        isLiveHeartRateActive ? liveHeartRate : latestHeartRate
    }
    
    public var heartRateZone: HeartRateZone {
        HeartRateZone.zone(for: Int(heartRate))
    }
    
    @Published public var isHeartRateMonitoringEnabled: Bool = false
    @Published public var heartRateAlertsEnabled: Bool = false
    @Published public var highHeartRateThreshold: Int = 110
    @Published public var recoveryAlertsEnabled: Bool = false
    
    // MARK: - Основные дневные показатели
    @Published public var stepsToday: Int = 0
    public var todaySteps: Int { stepsToday }
    
    @Published public var todayFloors: Int = 0
    @Published public var stepDistanceKm: Double = 0.0
    public var distanceTodayKm: Double { stepDistanceKm }
    public var distanceMetersToday: Double { stepDistanceKm * 1000.0 }
    
    @Published public var activeEnergyBurned: Double = 0.0
    @Published public var activeEnergyGoal: Double = 500.0
    @Published public var basalEnergyBurned: Double = 1650.0
    public var calculatedBasalEnergy: Double { basalEnergyBurned > 0 ? basalEnergyBurned : 1650.0 }
    public var totalEnergyBurned: Double {
        (activeEnergyBurned > 0 ? activeEnergyBurned : calculatedStepCalories) + basalEnergyBurned
    }
    
    public var calorieBalance: Double {
        caloriesConsumedToday - totalEnergyBurned
    }
    
    /// Теоретическое изменение массы тела/жира в граммах за сегодня (7700 ккал = 1 кг жира)
    public var estimatedFatChangeGrams: Double {
        (calorieBalance / 7700.0) * 1000.0
    }
    
    /// Текстовая сводка всех съеденных за сегодня блюд для AI-тренеров и нутрициолога
    public var mealsSummaryString: String {
        var baseStr = ""
        if loggedMealsToday.isEmpty {
            if caloriesConsumedToday > 0 {
                baseStr = "Всего съедено за сегодня: \(Int(caloriesConsumedToday)) ккал (Б: \(Int(proteinConsumedToday))г, Ж: \(Int(fatConsumedToday))г, У: \(Int(carbsConsumedToday))г)"
            } else {
                baseStr = "Приемов пищи за сегодня пока не зафиксировано."
            }
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            baseStr = loggedMealsToday.map { meal in
                let timeStr = formatter.string(from: meal.date)
                return "\(meal.category.title) (\(timeStr)): \(meal.name) [\(meal.resolvedTexture.shortBadge)] — \(Int(meal.calories)) ккал (Б: \(Int(meal.protein))г, Ж: \(Int(meal.fat))г, У: \(Int(meal.carbs))г)"
            }.joined(separator: "\n")
        }
        return "\(baseStr)\n• Баланс ЖКТ и консистенции рациона: \(digestiveBalanceSummary)"
    }
    
    public var todayTimingSummary: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let nowStr = formatter.string(from: Date())
        var logs: [String] = []
        if waterConsumedToday > 0 {
            logs.append("• Выпито воды: \(Int(waterConsumedToday)) мл (активность зафиксирована к \(nowStr))")
        }
        if !loggedMealsToday.isEmpty {
            logs.append("• Питание (\(loggedMealsToday.count) приемов пищи, \(Int(caloriesConsumedToday)) ккал):")
            for m in loggedMealsToday {
                logs.append("  - \(m.category.title): \(m.name) (\(Int(m.calories)) ккал, Б:\(Int(m.protein))г, Ж:\(Int(m.fat))г, У:\(Int(m.carbs))г)")
            }
        } else if caloriesConsumedToday > 0 {
            logs.append("• Питание: \(Int(caloriesConsumedToday)) ккал (Б: \(Int(proteinConsumedToday))г, Ж: \(Int(fatConsumedToday))г, У: \(Int(carbsConsumedToday))г)")
        }
        if !workoutHistory.isEmpty {
            let todayWorkouts = workoutHistory.filter { Calendar.current.isDateInToday($0.date) }
            for w in todayWorkouts {
                logs.append("• Тренировка: \(w.type), \(w.durationMinutes) мин, \(Int(w.caloriesBurned)) ккал в \(formatter.string(from: w.date))")
            }
        }
        return logs.isEmpty ? "Данных о времени приемов пищи/воды пока нет" : logs.joined(separator: "\n")
    }
    
    @Published public var appleExerciseTimeMinutes: Int = 0
    public var exerciseTime: Double { Double(appleExerciseTimeMinutes) }
    @Published public var exerciseGoal: Double = 30.0
    @Published public var appleStandHours: Int = 8
    @Published public var standHoursGoal: Int = 12
    
    @Published public var currentWeight: Double = 74.5
    @Published public var weightTrend: WeightTrendType = .stable
    
    // MARK: - Сон и Фазы
    @Published public var todaySleepHours: Double = 0.0
    public var sleepDuration: Double { todaySleepHours }
    @Published public var deepSleepDuration: Double = 0.0
    @Published public var remSleepDuration: Double = 0.0
    @Published public var coreSleepDuration: Double = 0.0
    @Published public var awakeDuration: Double = 0.0
    @Published public var sleepQualityScore: Int = 0
    
    // MARK: - Кардио и Восстановление (HRV, VO2 Max, SpO2)
    @Published public var hrvSDNN: Double = 0.0 // мс (Вариабельность пульса)
    @Published public var recoveryScore: Int = 0 // 0-100%
    @Published public var stressLevel: String = "--"
    @Published public var vo2Max: Double = 0.0 // мл/кг/мин (Кардиовыносливость)
    @Published public var cardioFitnessLevel: String = "--"
    @Published public var walkingHeartRateAverage: Double = 0.0 // уд/мин
    @Published public var bloodOxygen: Double = 0.0 // %
    @Published public var respiratoryRate: Double = 0.0 // вдохов/мин
    
    // MARK: - Вода и Напитки
    @Published public var waterConsumedToday: Double = 0.0
    public var waterConsumed: Double {
        get { waterConsumedToday }
        set { waterConsumedToday = newValue; saveLocalData() }
    }
    @Published public var waterGoal: Double = 2500.0
    @Published public var loggedBeveragesToday: [LoggedBeverageRecord] = []
    
    public var totalFluidVolumeToday: Double {
        if loggedBeveragesToday.isEmpty {
            return waterConsumedToday
        }
        return loggedBeveragesToday.reduce(0.0) { $0 + $1.volumeMl }
    }
    
    public var beverageCaloriesToday: Double {
        loggedBeveragesToday.reduce(0.0) { $0 + $1.calories }
    }
    
    public var beveragesSummaryString: String {
        if loggedBeveragesToday.isEmpty {
            return waterConsumedToday > 0 ? "Чистая вода: \(Int(waterConsumedToday)) мл" : "Записей о воде пока нет"
        }
        let list = loggedBeveragesToday.map {
            "\($0.beverageType.emoji) \($0.displayName) (\(Int($0.volumeMl)) мл)"
        }.joined(separator: ", ")
        return "\(list) • Всего жидкости: \(Int(totalFluidVolumeToday)) мл (эффективная гидратация: \(Int(waterConsumedToday)) мл, калории: \(Int(beverageCaloriesToday)) ккал)"
    }
    
    // MARK: - Умная физиологическая адаптивная норма гидратации (Smart Dynamic Hydration)
    
    /// Базовая потребность в воде от массы тела (35 мл на 1 кг массы тела, минимум 2000 мл, по умолчанию 2500 мл)
    public var baseWaterNorm: Double {
        currentWeight > 0 ? max(2000.0, currentWeight * 35.0) : 2500.0
    }
    
    /// Добавка на восполнение потерь влаги с потом от активных тренировок (0.75 мл на 1 сожженную активную ккал)
    public var activityHydrationBonus: Double {
        let burn = activeEnergyBurned > 0 ? activeEnergyBurned : calculatedStepCalories
        return min(1500.0, (burn * 0.75 / 25.0).rounded() * 25.0)
    }
    
    /// Добавка за повышенную шаговую активность сверх базовой нормы (начиная с 6 000 шагов: +100 мл за каждые 2 000 шагов)
    public var stepHydrationBonus: Double {
        let extraSteps = max(0, stepsToday - 6000)
        let bonus = (Double(extraSteps) / 2000.0) * 100.0
        return min(600.0, (bonus / 25.0).rounded() * 25.0)
    }
    
    /// Объем воды, необходимый для компенсации диуретического эффекта кофеина, энергетиков и алкоголя
    public var caffeineAndAlcoholDehydrationCompensation: Double {
        var comp = 0.0
        for bev in loggedBeveragesToday {
            switch bev.beverageType {
            case .coffee, .energyDrink:
                comp += bev.volumeMl * 0.5 // выпил 200 мл кофе -> нужно +100 мл воды для компенсации
            case .alcohol:
                comp += bev.volumeMl * 0.8 // алкоголь сильно обезвоживает
            case .soda:
                comp += bev.volumeMl * 0.2 // сахар замедляет гидратацию
            default:
                break
            }
        }
        return (comp / 25.0).rounded() * 25.0
    }
    
    /// Поступление чистой жидкости с первыми блюдами (супы, бульоны на 80% состоят из воды)
    public var soupHydrationVolume: Double {
        let soups = loggedMealsToday.filter { $0.resolvedTexture == .liquidSoup }
        let totalSoupWeight = soups.reduce(0.0) { $0 + $1.weightGrams }
        return (totalSoupWeight * 0.80 / 25.0).rounded() * 25.0
    }
    
    /// Итоговая адаптивная динамическая норма воды на сегодня
    public var dynamicWaterGoal: Double {
        let total = baseWaterNorm + activityHydrationBonus + stepHydrationBonus + caffeineAndAlcoholDehydrationCompensation
        return (total / 50.0).rounded() * 50.0
    }
    
    /// Суммарная эффективная гидратация с учетом напитков и супов
    public var totalHydrationWithSoups: Double {
        waterConsumedToday + soupHydrationVolume
    }
    
    /// Количество выпитых порций кофе / энергетиков за сегодня
    public var caffeineDrinkCountToday: Int {
        loggedBeveragesToday.filter { $0.beverageType == .coffee || $0.beverageType == .energyDrink }.count
    }
    
    /// Требуется ли компенсаторный стакан воды прямо сейчас
    public var needsCaffeineWaterCompensation: Bool {
        guard let lastDiuretic = loggedBeveragesToday.last(where: {
            $0.beverageType == .coffee || $0.beverageType == .energyDrink || $0.beverageType == .alcohol
        }) else {
            return false
        }
        let waterAfter = loggedBeveragesToday
            .filter { $0.beverageType == .water || $0.beverageType == .sparklingWater }
            .filter { $0.date >= lastDiuretic.date }
            .reduce(0.0) { $0 + $1.volumeMl }
        return waterAfter < 180.0
    }
    
    // MARK: - Трекер кофеина и Окно сна (Caffeine Safety & Sleep Window)
    
    /// Суммарное количество потребленного кофеина за сегодня (мг)
    public var caffeineConsumedTodayMg: Double {
        loggedBeveragesToday.reduce(0.0) { $0 + $1.caffeineMg }
    }
    
    /// Безопасный суточный лимит кофеина для взрослого человека (FDA / EFSA: 400 мг)
    public let caffeineSafeDailyLimitMg: Double = 400.0
    
    /// Оставшийся безопасный бюджет кофеина на сегодня (мг)
    public var caffeineRemainingBudgetMg: Double {
        max(0.0, caffeineSafeDailyLimitMg - caffeineConsumedTodayMg)
    }
    
    /// Время последнего приема напитка с кофеином
    public var lastCaffeineIntakeDate: Date? {
        loggedBeveragesToday.filter { $0.caffeineMg > 0 }.max(by: { $0.date < $1.date })?.date
    }
    
    /// Оценка текущего активного уровня кофеина в крови (мг) по модели экспоненциального полувыведения (5.5 ч)
    public var caffeineActiveInBloodMg: Double {
        let now = Date()
        var activeTotal = 0.0
        for bev in loggedBeveragesToday where bev.caffeineMg > 0 {
            let elapsedHours = max(0, now.timeIntervalSince(bev.date) / 3600.0)
            // Экспоненциальный распад с полупериодом 5.5 ч
            let remaining = bev.caffeineMg * pow(0.5, elapsedHours / 5.5)
            activeTotal += remaining
        }
        return (activeTotal * 10).rounded() / 10
    }
    
    /// Расчет времени, когда уровень кофеина опустится ниже порога глубокого сна (<25 мг)
    public var caffeineSleepCutoffDate: Date? {
        let active = caffeineActiveInBloodMg
        guard active > 25.0 else { return nil }
        let ratio = active / 25.0
        let hoursRemaining = 5.5 * (log(ratio) / log(2.0))
        return Date().addingTimeInterval(hoursRemaining * 3600.0)
    }
    
    /// Статус влияния текущей концентрации кофеина на качество сна
    public var caffeineSleepImpactStatus: CaffeineSleepImpactStatus {
        let active = caffeineActiveInBloodMg
        if active < 25.0 {
            return .safe
        } else if active <= 60.0 {
            return .moderate
        } else {
            return .caution
        }
    }
    
    // MARK: - Питание
    @Published public var caloriesConsumedToday: Double = 0.0
    @Published public var proteinConsumedToday: Double = 0.0
    @Published public var fatConsumedToday: Double = 0.0
    @Published public var carbsConsumedToday: Double = 0.0
    @Published public var loggedMealsToday: [LoggedMealRecord] = []
    @Published public var recentMealRecords: [LoggedMealRecord] = []
    
    // MARK: - Баланс ЖКТ и консистенция пищи (Супы / Бульоны vs Плотная еда)
    
    /// Все недавние приемы пищи в хронологическом порядке (сегодня + недавняя история)
    public var allMealsChronological: [LoggedMealRecord] {
        var map: [UUID: LoggedMealRecord] = [:]
        for m in recentMealRecords { map[m.id] = m }
        for m in loggedMealsToday { map[m.id] = m }
        return map.values.sorted { $0.date < $1.date }
    }
    
    /// Количество приемов плотной/твердой пищи подряд с конца хронологии
    public var solidMealStreak: Int {
        let meals = allMealsChronological
        guard !meals.isEmpty else { return 0 }
        var streak = 0
        for m in meals.reversed() {
            if m.resolvedTexture == .solidDense {
                streak += 1
            } else if m.resolvedTexture == .liquidSoup {
                break
            }
        }
        return streak
    }
    
    /// Количество приемов пищи с момента последнего супа/бульона
    public var mealsSinceLastLiquidMealCount: Int {
        let meals = allMealsChronological
        guard !meals.isEmpty else { return 0 }
        var count = 0
        for m in meals.reversed() {
            if m.resolvedTexture == .liquidSoup {
                break
            }
            count += 1
        }
        return count
    }
    
    /// Последний зафиксированный прием жидкого блюда (суп, бульон)
    public var lastLiquidMeal: LoggedMealRecord? {
        allMealsChronological.reversed().first { $0.resolvedTexture == .liquidSoup }
    }
    
    /// Сколько часов прошло с последнего приема супа/бульона
    public var hoursSinceLastLiquidMeal: Double? {
        guard let last = lastLiquidMeal else { return nil }
        return max(0, Date().timeIntervalSince(last.date) / 3600.0)
    }
    
    /// Процент жидких и легких блюд за последние дни
    public var liquidMealRatioRecent: Double {
        let meals = allMealsChronological
        guard !meals.isEmpty else { return 0.5 }
        let liquidCount = meals.filter { $0.resolvedTexture == .liquidSoup }.count
        return Double(liquidCount) / Double(meals.count)
    }
    
    /// Текущий статус баланса рациона (супы vs плотная еда)
    public var digestiveBalanceStatus: DigestiveBalanceStatus {
        let streak = solidMealStreak
        let mealsSinceSoup = mealsSinceLastLiquidMealCount
        let hours = hoursSinceLastLiquidMeal
        
        if lastLiquidMeal == nil && mealsSinceSoup >= 3 {
            return .heavyWarning
        }
        
        if streak >= 4 || (hours ?? 0) >= 36 {
            return .heavyWarning
        } else if streak >= 2 || mealsSinceSoup >= 3 || (hours ?? 0) >= 20 {
            return .needsLiquid
        } else if streak == 1 || (hours ?? 0) < 14 {
            return .moderate
        } else if lastLiquidMeal != nil && (hours ?? 0) < 10 {
            return .optimal
        } else {
            return .moderate
        }
    }
    
    /// Рекомендация по разнообразию рациона
    public var digestiveRecommendationText: String {
        switch digestiveBalanceStatus {
        case .optimal:
            return "Отличный баланс рациона! Присутствие жидких блюд поддерживает комфортное насыщение и правильный водный баланс."
        case .moderate:
            return "Баланс в норме. Старайтесь включать первое блюдо (суп или бульон) хотя бы раз в 1-2 дня."
        case .needsLiquid:
            return "Вы уже несколько приемов пищи подряд едите сухую плотную еду. Для разнообразия и комфорта добавьте на следующий прием теплый суп или бульон."
        case .heavyWarning:
            return "Длительное преобладание сухой пищи в рационе. Рекомендуем добавить теплый согревающий бульон или легкий овощной крем-суп!"
        }
    }
    
    /// Текстовая сводка для ИИ-нутрициолога и тренеров
    public var digestiveBalanceSummary: String {
        let streak = solidMealStreak
        let mealsSince = mealsSinceLastLiquidMealCount
        let lastSoupStr: String
        if let last = lastLiquidMeal {
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM в HH:mm"
            lastSoupStr = "\(last.name) (\(formatter.string(from: last.date)))"
        } else {
            lastSoupStr = "в недавней истории не зафиксирован"
        }
        
        return "Баланс рациона: \(digestiveBalanceStatus.title). Стрик плотной пищи подряд: \(streak) приемов (всего без супов: \(mealsSince)). Последний суп/бульон: \(lastSoupStr). Рекомендация: \(digestiveRecommendationText)"
    }
    
    // MARK: - Списки и История
    @Published public var weeklySteps: [WeeklyStepsData] = []
    @Published public var workoutHistory: [WorkoutRecord] = []
    @Published public var weightHistory: [WeightRecord] = []
    @Published public var dailyActivityHistory: [String: DailyActivitySummary] = [:]
    @Published public var nutritionHistory: [DailyNutritionRecord] = []
    @Published public var lastWorkoutString: String = "Нет записей"
    
    public var calculatedStepCalories: Double {
        let weight = currentWeight > 30 ? currentWeight : 74.5
        let factor = (weight / 70.0) * 0.042
        return Double(stepsToday) * factor
    }
    
    private var activeTrackingDayKey: String = ""
    
    private var todayKey: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    public init() {
        self.activeTrackingDayKey = self.todayKey
        loadLocalData()
        checkExistingAuthorization()
        setupDayChangeObservers()
    }
    
    // MARK: - Системные наблюдатели смены календарного дня
    private func setupDayChangeObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.significantTimeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.checkAndHandleDayRollover()
                self.onAppAppear()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.checkAndHandleDayRollover()
                self.onAppAppear()
            }
        }
    }
    
    /// Проверка смены суток: если наступил новый день, очищает суточные списки блюд/напитков
    /// и сбрасывает счетчики в 0, чтобы вчерашние данные не суммировались с сегодняшними.
    @discardableResult
    public func checkAndHandleDayRollover() -> Bool {
        let currentKey = todayKey
        if activeTrackingDayKey != currentKey {
            activeTrackingDayKey = currentKey
            
            // Сохраняем вчерашние блюда в долговременную историю перед очисткой суточного дневника
            for meal in self.loggedMealsToday {
                if !self.recentMealRecords.contains(where: { $0.id == meal.id }) {
                    self.recentMealRecords.append(meal)
                }
            }
            if self.recentMealRecords.count > 50 {
                self.recentMealRecords = Array(self.recentMealRecords.suffix(50))
            }
            
            // Оставляем только то, что относится к сегодняшнему дню
            self.loggedMealsToday = self.loggedMealsToday.filter { Calendar.current.isDateInToday($0.date) }
            self.loggedBeveragesToday = self.loggedBeveragesToday.filter { Calendar.current.isDateInToday($0.date) }
            
            recalculateTodayNutritionTotals()
            recalculateTodayWaterTotals()
            loadLocalData()
            return true
        }
        return false
    }
    
    // MARK: - Проверка авторизации при старте
    private func checkExistingAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            self.isHealthDataAvailable = false
            return
        }
        
        let wasAuthorized = UserDefaults.standard.bool(forKey: "healthkit_authorized_user")
        if wasAuthorized {
            self.isAuthorized = true
            self.isRequested = true
            fetchAllData()
            setupBackgroundObservers()
        }
    }
    
    public func onAppAppear() {
        checkAndHandleDayRollover()
        loadLocalData()
        if isAuthorized {
            fetchAllData()
        } else if HKHealthStore.isHealthDataAvailable() {
            if !UserDefaults.standard.bool(forKey: "healthkit_auto_prompted_v3") {
                UserDefaults.standard.set(true, forKey: "healthkit_auto_prompted_v3")
                requestAuthorization()
            } else {
                checkHealthDataAndAutoEnable()
            }
        }
    }
    
    public func checkHealthDataAndAutoEnable() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: stepsType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, statistics, _ in
            if let sum = statistics?.sumQuantity() {
                let steps = sum.doubleValue(for: .count())
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        self.isAuthorized = true
                    }
                    UserDefaults.standard.set(true, forKey: "healthkit_authorized_user")
                    if steps > 0 {
                        self.stepsToday = Int(steps)
                    }
                    self.fetchAllData()
                    self.setupBackgroundObservers()
                    Task {
                        await self.syncFullHistoricalData(daysBack: 365)
                    }
                }
            }
        }
        healthStore.execute(query)
    }
    
    // MARK: - Запрос разрешений Apple Health
    public func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            self.isHealthDataAvailable = false
            return
        }
        
        var readTypes: Set<HKObjectType> = []
        var shareTypes: Set<HKSampleType> = []
        
        // Шаги и движение
        if let steps = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            readTypes.insert(steps)
            shareTypes.insert(steps)
        }
        if let distance = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            readTypes.insert(distance)
            shareTypes.insert(distance)
        }
        if let flights = HKQuantityType.quantityType(forIdentifier: .flightsClimbed) {
            readTypes.insert(flights)
        }
        
        // Энергия и кольца
        if let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            readTypes.insert(activeEnergy)
            shareTypes.insert(activeEnergy)
        }
        if let basalEnergy = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) {
            readTypes.insert(basalEnergy)
        }
        if let exerciseTime = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) {
            readTypes.insert(exerciseTime)
        }
        if let standHour = HKCategoryType.categoryType(forIdentifier: .appleStandHour) {
            readTypes.insert(standHour)
        }
        
        // Пульс и кардио
        if let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            readTypes.insert(heartRate)
            shareTypes.insert(heartRate)
        }
        if let restingHR = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) {
            readTypes.insert(restingHR)
        }
        if let walkingHR = HKQuantityType.quantityType(forIdentifier: .walkingHeartRateAverage) {
            readTypes.insert(walkingHR)
        }
        if let hrv = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            readTypes.insert(hrv)
        }
        if let vo2 = HKQuantityType.quantityType(forIdentifier: .vo2Max) {
            readTypes.insert(vo2)
        }
        if let spo2 = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) {
            readTypes.insert(spo2)
        }
        if let resp = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) {
            readTypes.insert(resp)
        }
        
        // Сон
        if let sleep = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            readTypes.insert(sleep)
            shareTypes.insert(sleep)
        }
        
        // Вес
        if let weight = HKQuantityType.quantityType(forIdentifier: .bodyMass) {
            readTypes.insert(weight)
            shareTypes.insert(weight)
        }
        
        // Вода и Питание (Макро и Микронутриенты)
        if let water = HKQuantityType.quantityType(forIdentifier: .dietaryWater) {
            readTypes.insert(water)
            shareTypes.insert(water)
        }
        if let energyConsumed = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) {
            readTypes.insert(energyConsumed)
            shareTypes.insert(energyConsumed)
        }
        if let protein = HKQuantityType.quantityType(forIdentifier: .dietaryProtein) {
            readTypes.insert(protein)
            shareTypes.insert(protein)
        }
        if let fat = HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal) {
            readTypes.insert(fat)
            shareTypes.insert(fat)
        }
        if let carbs = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates) {
            readTypes.insert(carbs)
            shareTypes.insert(carbs)
        }
        if let fiber = HKQuantityType.quantityType(forIdentifier: .dietaryFiber) {
            readTypes.insert(fiber)
            shareTypes.insert(fiber)
        }
        if let sugar = HKQuantityType.quantityType(forIdentifier: .dietarySugar) {
            readTypes.insert(sugar)
            shareTypes.insert(sugar)
        }
        if let sodium = HKQuantityType.quantityType(forIdentifier: .dietarySodium) {
            readTypes.insert(sodium)
            shareTypes.insert(sodium)
        }
        
        // Тренировки
        let workoutType = HKWorkoutType.workoutType()
        readTypes.insert(workoutType)
        shareTypes.insert(workoutType)
        
        self.isRequested = true
        self.isSyncing = true
        
        healthStore.requestAuthorization(toShare: shareTypes, read: readTypes) { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isSyncing = false
                if let error = error {
                    self.authorizationError = error.localizedDescription
                    self.isAuthorized = false
                    self.authorizationAlertMessage = "Apple Health: \(error.localizedDescription)\n\nПожалуйста, проверьте «Настройки» -> «Здоровье» -> «Доступ к данным» -> «Forma»."
                    self.showAuthorizationAlert = true
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        self.isAuthorized = true
                    }
                    self.authorizationError = nil
                    UserDefaults.standard.set(true, forKey: "healthkit_authorized_user")
                    self.fetchAllData()
                    self.setupBackgroundObservers()
                    
                    // Автоматическая глубокая синхронизация 365 дней истории!
                    Task {
                        await self.syncFullHistoricalData(daysBack: 365)
                    }
                }
            }
        }
    }
    
    public func resetAndReauthorize() {
        requestAuthorization()
    }
    
    public func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
    
    // MARK: - Сбор всех данных
    public func fetchAllData() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        self.isSyncing = true
        
        Task {
            await fetchTodayMetrics()
            await fetchHeartRate()
            await fetchHRV()
            await fetchVO2Max()
            await fetchRestingAndWalkingHeartRate()
            await fetchBloodOxygen()
            await fetchSleepData()
            await fetchWorkouts()
            await fetchWeightHistory()
            await fetchWeeklySteps()
            
            await MainActor.run {
                self.isSyncing = false
                self.lastSyncTime = Date()
                self.saveLocalData()
            }
        }
    }
    
    public func syncAllWithHaptic() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        fetchAllData()
        
        Task {
            await syncFullHistoricalData(daysBack: 365)
            await MainActor.run {
                let notif = UINotificationFeedbackGenerator()
                notif.notificationOccurred(.success)
            }
        }
    }
    
    // MARK: - Запросы метрик за сегодня
    private func fetchTodayMetrics() async {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
        
        // 1. Шаги (если 0 в HealthKit — сбрасываем в 0, а не оставляем вчерашние)
        if let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            let steps = await executeSumQuantityQuery(type: stepsType, unit: .count(), predicate: predicate)
            self.stepsToday = Int(steps)
        }
        
        // 2. Дистанция
        if let distType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            let distMeters = await executeSumQuantityQuery(type: distType, unit: .meter(), predicate: predicate)
            self.stepDistanceKm = distMeters > 0 ? (distMeters / 1000.0) : 0.0
        }
        
        // 3. Этажи
        if let floorsType = HKQuantityType.quantityType(forIdentifier: .flightsClimbed) {
            let floors = await executeSumQuantityQuery(type: floorsType, unit: .count(), predicate: predicate)
            self.todayFloors = Int(floors)
        }
        
        // 4. Активные калории
        if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            let energy = await executeSumQuantityQuery(type: energyType, unit: .kilocalorie(), predicate: predicate)
            if energy > 0 {
                self.activeEnergyBurned = energy
            } else {
                self.activeEnergyBurned = self.calculatedStepCalories
            }
        }
        
        // 5. Базовый обмен
        if let basalType = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) {
            let basal = await executeSumQuantityQuery(type: basalType, unit: .kilocalorie(), predicate: predicate)
            if basal > 0 {
                self.basalEnergyBurned = basal
            }
        }
        
        // 6. Время упражнений
        if let exerciseType = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) {
            let exerciseMin = await executeSumQuantityQuery(type: exerciseType, unit: .minute(), predicate: predicate)
            self.appleExerciseTimeMinutes = Int(exerciseMin)
        }
        
        // 7. Вода (строго за сегодня)
        if let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) {
            let waterMl = await executeSumQuantityQuery(type: waterType, unit: .literUnit(with: .milli), predicate: predicate)
            let todayBeverages = loggedBeveragesToday.filter { Calendar.current.isDateInToday($0.date) }
            let localWater = !todayBeverages.isEmpty ? todayBeverages.reduce(0.0) { $0 + $1.effectiveHydrationMl } : UserDefaults.standard.double(forKey: "water_consumed_\(todayKey)")
            self.waterConsumedToday = max(waterMl, localWater)
        }
        
        // 8. Питание (строго за сегодня)
        let todayMeals = loggedMealsToday.filter { Calendar.current.isDateInToday($0.date) }
        let todayMealsCalories = todayMeals.reduce(0.0) { $0 + $1.calories }
        let todayMealsProtein = todayMeals.reduce(0.0) { $0 + $1.protein }
        let todayMealsFat = todayMeals.reduce(0.0) { $0 + $1.fat }
        let todayMealsCarbs = todayMeals.reduce(0.0) { $0 + $1.carbs }
        
        if let foodCalType = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) {
            let cal = await executeSumQuantityQuery(type: foodCalType, unit: .kilocalorie(), predicate: predicate)
            let localCal = !todayMeals.isEmpty ? todayMealsCalories : UserDefaults.standard.double(forKey: "nutrition_calories_\(todayKey)")
            self.caloriesConsumedToday = max(cal, localCal)
        }
        if let proteinType = HKQuantityType.quantityType(forIdentifier: .dietaryProtein) {
            let prot = await executeSumQuantityQuery(type: proteinType, unit: .gram(), predicate: predicate)
            let localProt = !todayMeals.isEmpty ? todayMealsProtein : UserDefaults.standard.double(forKey: "nutrition_protein_\(todayKey)")
            self.proteinConsumedToday = max(prot, localProt)
        }
        if let fatType = HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal) {
            let fat = await executeSumQuantityQuery(type: fatType, unit: .gram(), predicate: predicate)
            let localFat = !todayMeals.isEmpty ? todayMealsFat : UserDefaults.standard.double(forKey: "nutrition_fat_\(todayKey)")
            self.fatConsumedToday = max(fat, localFat)
        }
        if let carbsType = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates) {
            let carbs = await executeSumQuantityQuery(type: carbsType, unit: .gram(), predicate: predicate)
            let localCarbs = !todayMeals.isEmpty ? todayMealsCarbs : UserDefaults.standard.double(forKey: "nutrition_carbs_\(todayKey)")
            self.carbsConsumedToday = max(carbs, localCarbs)
        }
        
        // Обновляем дневную сводку
        let summary = DailyActivitySummary(
            dateKey: todayKey,
            date: Date(),
            steps: stepsToday,
            distanceMeters: stepDistanceKm * 1000.0,
            activeCalories: activeEnergyBurned
        )
        self.dailyActivityHistory[todayKey] = summary
    }
    
    // MARK: - Расчет индекса восстановления
    public func calculateRecoveryScore(hrv: Double, restingHR: Double) -> (score: Int, stress: String) {
        var baseScore = Int((hrv / 65.0) * 80.0)
        if restingHR > 0 {
            if restingHR < 60 {
                baseScore += 10
            } else if restingHR > 75 {
                baseScore -= 10
            }
        }
        let finalScore = max(10, min(100, baseScore))
        let stress: String
        if finalScore >= 75 {
            stress = "Низкий"
        } else if finalScore >= 45 {
            stress = "Умеренный"
        } else {
            stress = "Повышенный"
        }
        return (finalScore, stress)
    }
    
    // MARK: - Пульс и Кардиопоказатели
    private func fetchHeartRate() async {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: hrType, predicate: nil, limit: 1, sortDescriptors: [sort]) { [weak self] _, samples, _ in
                if let sample = samples?.first as? HKQuantitySample {
                    let hr = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    DispatchQueue.main.async {
                        self?.latestHeartRate = hr
                    }
                }
                continuation.resume()
            }
            self.healthStore.execute(query)
        }
    }
    
    private func fetchHRV() async {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: hrvType, predicate: nil, limit: 1, sortDescriptors: [sort]) { [weak self] _, samples, _ in
                if let sample = samples?.first as? HKQuantitySample {
                    let hrv = sample.quantity.doubleValue(for: .secondUnit(with: .milli))
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        self.hrvSDNN = hrv
                        let recovery = self.calculateRecoveryScore(hrv: hrv, restingHR: self.restingHeartRate)
                        self.recoveryScore = recovery.score
                        self.stressLevel = recovery.stress
                    }
                }
                continuation.resume()
            }
            self.healthStore.execute(query)
        }
    }
    
    private func fetchVO2Max() async {
        guard let vo2Type = HKQuantityType.quantityType(forIdentifier: .vo2Max) else { return }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: vo2Type, predicate: nil, limit: 1, sortDescriptors: [sort]) { [weak self] _, samples, _ in
                if let sample = samples?.first as? HKQuantitySample {
                    let vo2 = sample.quantity.doubleValue(for: HKUnit(from: "ml/kg*min"))
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        self.vo2Max = vo2
                        if vo2 >= 48.0 {
                            self.cardioFitnessLevel = "Высокая"
                        } else if vo2 >= 38.0 {
                            self.cardioFitnessLevel = "Выше среднего"
                        } else if vo2 >= 30.0 {
                            self.cardioFitnessLevel = "Средняя"
                        } else {
                            self.cardioFitnessLevel = "Ниже среднего"
                        }
                    }
                }
                continuation.resume()
            }
            self.healthStore.execute(query)
        }
    }
    
    private func fetchRestingAndWalkingHeartRate() async {
        if let rhrType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) {
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            await withCheckedContinuation { continuation in
                let query = HKSampleQuery(sampleType: rhrType, predicate: nil, limit: 1, sortDescriptors: [sort]) { [weak self] _, samples, _ in
                    if let sample = samples?.first as? HKQuantitySample {
                        let rhr = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                        DispatchQueue.main.async {
                            self?.restingHeartRate = rhr
                        }
                    }
                    continuation.resume()
                }
                self.healthStore.execute(query)
            }
        }
        
        if let whrType = HKQuantityType.quantityType(forIdentifier: .walkingHeartRateAverage) {
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            await withCheckedContinuation { continuation in
                let query = HKSampleQuery(sampleType: whrType, predicate: nil, limit: 1, sortDescriptors: [sort]) { [weak self] _, samples, _ in
                    if let sample = samples?.first as? HKQuantitySample {
                        let whr = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                        DispatchQueue.main.async {
                            self?.walkingHeartRateAverage = whr
                        }
                    }
                    continuation.resume()
                }
                self.healthStore.execute(query)
            }
        }
    }
    
    private func fetchBloodOxygen() async {
        if let spo2Type = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) {
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            await withCheckedContinuation { continuation in
                let query = HKSampleQuery(sampleType: spo2Type, predicate: nil, limit: 1, sortDescriptors: [sort]) { [weak self] _, samples, _ in
                    if let sample = samples?.first as? HKQuantitySample {
                        let spo2 = sample.quantity.doubleValue(for: .percent()) * 100.0
                        DispatchQueue.main.async {
                            self?.bloodOxygen = spo2
                        }
                    }
                    continuation.resume()
                }
                self.healthStore.execute(query)
            }
        }
        
        if let respType = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) {
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            await withCheckedContinuation { continuation in
                let query = HKSampleQuery(sampleType: respType, predicate: nil, limit: 1, sortDescriptors: [sort]) { [weak self] _, samples, _ in
                    if let sample = samples?.first as? HKQuantitySample {
                        let resp = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                        DispatchQueue.main.async {
                            self?.respiratoryRate = resp
                        }
                    }
                    continuation.resume()
                }
                self.healthStore.execute(query)
            }
        }
    }
    
    // MARK: - Сон и Фазы (Apple Watch Sleep Analysis)
    public func fetchSleepData() async {
        guard HKHealthStore.isHealthDataAvailable(),
              let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            return
        }
        
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        // Ночное окно: анализируем сон за последние 30 часов, завершившийся сегодня или актуальный
        let searchStart = calendar.date(byAdding: .hour, value: -30, to: now) ?? startOfToday
        let predicate = HKQuery.predicateForSamples(withStart: searchStart, end: now, options: .strictEndDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { [weak self] _, samples, _ in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                guard let sleepSamples = samples as? [HKCategorySample], !sleepSamples.isEmpty else {
                    DispatchQueue.main.async {
                        self.todaySleepHours = 0.0
                        self.deepSleepDuration = 0.0
                        self.remSleepDuration = 0.0
                        self.coreSleepDuration = 0.0
                        self.awakeDuration = 0.0
                        self.sleepQualityScore = 0
                    }
                    continuation.resume()
                    return
                }
                
                // Фильтруем замеры, относящиеся к ночи/утру текущего дня (завершившиеся после 18:00 вчерашнего дня)
                let cutoffDate = calendar.date(byAdding: .hour, value: -18, to: startOfToday) ?? searchStart
                let relevantSamples = sleepSamples.filter { $0.endDate >= cutoffDate }
                
                var deepSeconds: Double = 0
                var remSeconds: Double = 0
                var coreSeconds: Double = 0
                var unspecifiedSeconds: Double = 0
                var awakeSeconds: Double = 0
                
                for sample in relevantSamples {
                    let duration = sample.endDate.timeIntervalSince(sample.startDate)
                    guard duration > 0 else { continue }
                    
                    if #available(iOS 16.0, *) {
                        switch sample.value {
                        case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                            deepSeconds += duration
                        case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                            remSeconds += duration
                        case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                            coreSeconds += duration
                        case HKCategoryValueSleepAnalysis.awake.rawValue:
                            awakeSeconds += duration
                        case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                            unspecifiedSeconds += duration
                        default:
                            // inBed и другие промежуточные статусы не суммируем в чистый сон
                            break
                        }
                    } else {
                        if sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue {
                            unspecifiedSeconds += duration
                        }
                    }
                }
                
                let stagedTotalSeconds = deepSeconds + remSeconds + coreSeconds
                let hasStageData = stagedTotalSeconds > 0
                let totalAsleepSeconds = hasStageData ? (stagedTotalSeconds + unspecifiedSeconds) : unspecifiedSeconds
                
                DispatchQueue.main.async {
                    if totalAsleepSeconds > 0 {
                        let totalHours = totalAsleepSeconds / 3600.0
                        self.todaySleepHours = totalHours
                        self.deepSleepDuration = deepSeconds / 3600.0
                        self.remSleepDuration = remSeconds / 3600.0
                        self.coreSleepDuration = coreSeconds / 3600.0
                        self.awakeDuration = awakeSeconds / 3600.0
                        
                        // Честный расчет индекса качества сна:
                        // Базовые баллы по продолжительности (до 75 баллов при 7-9 часах)
                        var score = min(75, Int((totalHours / 8.0) * 75.0))
                        if hasStageData {
                            // Бонусы за полноценные фазы Deep и REM (по 10-15 баллов)
                            if self.deepSleepDuration >= 1.0 { score += 13 }
                            else if self.deepSleepDuration >= 0.5 { score += 7 }
                            
                            if self.remSleepDuration >= 1.0 { score += 12 }
                            else if self.remSleepDuration >= 0.5 { score += 6 }
                        } else {
                            if totalHours >= 7.0 && totalHours <= 9.0 {
                                score += 20
                            } else if totalHours >= 6.0 {
                                score += 10
                            }
                        }
                        self.sleepQualityScore = max(0, min(100, score))
                    } else {
                        self.todaySleepHours = 0.0
                        self.deepSleepDuration = 0.0
                        self.remSleepDuration = 0.0
                        self.coreSleepDuration = 0.0
                        self.awakeDuration = 0.0
                        self.sleepQualityScore = 0
                    }
                    self.saveLocalData()
                }
                continuation.resume()
            }
            self.healthStore.execute(query)
        }
    }
    
    // MARK: - Интеллектуальная дедупликация тренировок без потери данных
    public static func deduplicateWorkouts(_ workouts: [WorkoutRecord]) -> [WorkoutRecord] {
        var unique: [WorkoutRecord] = []
        for w in workouts {
            let isDuplicate = unique.contains { existing in
                // 1. Прямое совпадение по UUID
                if existing.id == w.id { return true }
                
                // 2. Совпадение по времени старта (интервал < 90 сек), длительности (±2 мин) и типу
                let timeDiff = abs(existing.date.timeIntervalSince(w.date))
                let durDiff = abs(existing.durationMinutes - w.durationMinutes)
                
                let sameOrCompatibleType = existing.type.lowercased() == w.type.lowercased() ||
                    (existing.type.contains("Силов") && w.type.contains("Силов")) ||
                    (existing.type.contains("Бег") && w.type.contains("Бег")) ||
                    (existing.type.contains("Ходьб") && w.type.contains("Ходьб"))
                
                return timeDiff < 90 && durDiff <= 2 && sameOrCompatibleType
            }
            if !isDuplicate {
                unique.append(w)
            }
        }
        return unique.sorted(by: { $0.date > $1.date })
    }
    
    // MARK: - Тренировки
    private func fetchWorkouts() async {
        let workoutType = HKWorkoutType.workoutType()
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: workoutType, predicate: nil, limit: 150, sortDescriptors: [sort]) { [weak self] _, samples, _ in
                guard let self = self, let workouts = samples as? [HKWorkout] else {
                    continuation.resume()
                    return
                }
                
                var records: [WorkoutRecord] = []
                for w in workouts {
                    let activityName = self.mapHKWorkoutTypeToString(w.workoutActivityType)
                    let customName = (w.metadata?["WorkoutName"] as? String) ?? activityName
                    let durationMin = max(1, Int(w.duration / 60.0))
                    let calories = w.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0.0
                    
                    let record = WorkoutRecord(
                        id: w.uuid,
                        type: customName,
                        date: w.startDate,
                        durationMinutes: durationMin,
                        caloriesBurned: calories
                    )
                    records.append(record)
                }
                
                DispatchQueue.main.async {
                    // Объединяем полученные из HealthKit тренировки с локальными с устранением дублирования
                    let merged = records + self.workoutHistory
                    self.workoutHistory = HealthKitManager.deduplicateWorkouts(merged)
                    
                    if let last = self.workoutHistory.first {
                        let formatter = DateFormatter()
                        formatter.locale = Locale(identifier: "ru_RU")
                        formatter.dateFormat = "d MMM"
                        self.lastWorkoutString = "\(last.durationMinutes) мин — \(last.type)\n(\(formatter.string(from: last.date)))"
                    }
                    self.saveLocalData()
                }
                continuation.resume()
            }
            self.healthStore.execute(query)
        }
    }
    
    // MARK: - Вес
    private func fetchWeightHistory() async {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: weightType, predicate: nil, limit: 100, sortDescriptors: [sort]) { [weak self] _, samples, _ in
                guard let self = self, let weightSamples = samples as? [HKQuantitySample] else {
                    continuation.resume()
                    return
                }
                
                var records: [WeightRecord] = []
                for s in weightSamples {
                    let kg = s.quantity.doubleValue(for: .gramUnit(with: .kilo))
                    let rec = WeightRecord(id: s.uuid, date: s.startDate, weight: kg)
                    records.append(rec)
                }
                
                DispatchQueue.main.async {
                    if !records.isEmpty {
                        self.weightHistory = records
                        if let last = records.last {
                            self.currentWeight = last.weight
                        }
                        if records.count >= 2 {
                            let prev = records[records.count - 2].weight
                            let diff = (records.last?.weight ?? 0) - prev
                            if diff > 0.1 { self.weightTrend = .up }
                            else if diff < -0.1 { self.weightTrend = .down }
                            else { self.weightTrend = .stable }
                        }
                    }
                }
                continuation.resume()
            }
            self.healthStore.execute(query)
        }
    }
    
    // MARK: - Недельные шаги
    private func fetchWeeklySteps() async {
        guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        let calendar = Calendar.current
        let now = Date()
        guard let weekAgo = calendar.date(byAdding: .day, value: -6, to: now) else { return }
        let start = calendar.startOfDay(for: weekAgo)
        let startOfDayToday = calendar.startOfDay(for: now)
        
        var interval = DateComponents()
        interval.day = 1
        
        let query = HKStatisticsCollectionQuery(
            quantityType: stepsType,
            quantitySamplePredicate: nil,
            options: .cumulativeSum,
            anchorDate: startOfDayToday,
            intervalComponents: interval
        )
        
        await withCheckedContinuation { continuation in
            query.initialResultsHandler = { [weak self] _, results, _ in
                guard let self = self, let stats = results else {
                    continuation.resume()
                    return
                }
                
                var dayItems: [WeeklyStepsData] = []
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "ru_RU")
                formatter.dateFormat = "EE"
                
                stats.enumerateStatistics(from: start, to: now) { statistic, _ in
                    let dayName = formatter.string(from: statistic.startDate).capitalized
                    let steps = statistic.sumQuantity()?.doubleValue(for: .count()) ?? 0
                    dayItems.append(WeeklyStepsData(day: dayName, steps: Int(steps)))
                }
                
                DispatchQueue.main.async {
                    if !dayItems.isEmpty {
                        self.weeklySteps = dayItems
                    }
                }
                continuation.resume()
            }
            self.healthStore.execute(query)
        }
    }
    
    // MARK: - Автоматическая Глубокая Синхронизация Истории (365 дней)
    public func syncFullHistoricalData(daysBack: Int = 365) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        await MainActor.run {
            self.isHistoricalSyncInProgress = true
            self.historicalSyncStatusMessage = "Синхронизация истории здоровья (365 дней)..."
        }
        
        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -daysBack, to: now) else {
            await MainActor.run { self.isHistoricalSyncInProgress = false }
            return
        }
        let startOfDayToday = calendar.startOfDay(for: now)
        let startQueryDate = calendar.startOfDay(for: startDate)
        
        var interval = DateComponents()
        interval.day = 1
        
        // 1. Шаги за 365 дней
        if let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            let stepsQuery = HKStatisticsCollectionQuery(
                quantityType: stepsType,
                quantitySamplePredicate: nil,
                options: .cumulativeSum,
                anchorDate: startOfDayToday,
                intervalComponents: interval
            )
            
            await withCheckedContinuation { continuation in
                stepsQuery.initialResultsHandler = { [weak self] _, results, _ in
                    guard let self = self, let stats = results else {
                        continuation.resume()
                        return
                    }
                    
                    let keyFormatter = DateFormatter()
                    keyFormatter.locale = Locale(identifier: "en_US_POSIX")
                    keyFormatter.calendar = Calendar(identifier: .gregorian)
                    keyFormatter.dateFormat = "yyyy-MM-dd"
                    
                    var historyDict: [String: DailyActivitySummary] = [:]
                    
                    stats.enumerateStatistics(from: startQueryDate, to: now) { statistic, _ in
                        let key = keyFormatter.string(from: statistic.startDate)
                        let steps = statistic.sumQuantity()?.doubleValue(for: .count()) ?? 0
                        let distKm = (steps * 0.75) / 1000.0
                        let cal = steps * 0.042
                        
                        let summary = DailyActivitySummary(
                            dateKey: key,
                            date: statistic.startDate,
                            steps: Int(steps),
                            distanceMeters: distKm * 1000.0,
                            activeCalories: cal
                        )
                        historyDict[key] = summary
                    }
                    
                    DispatchQueue.main.async {
                        self.dailyActivityHistory.merge(historyDict) { _, new in new }
                    }
                    continuation.resume()
                }
                self.healthStore.execute(stepsQuery)
            }
        }
        
        // 2. Тренировки и Вес
        await fetchWorkouts()
        await fetchWeightHistory()
        
        await MainActor.run {
            self.historicalSyncStats = (self.dailyActivityHistory.count, self.workoutHistory.count, self.weightHistory.count)
            self.isHistoricalSyncInProgress = false
            self.historicalSyncStatusMessage = nil
            self.lastSyncTime = Date()
            self.saveLocalData()
        }
    }
    
    // MARK: - Фоновые наблюдатели
    public func setupBackgroundObservers() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        // Наблюдатель за шагами
        if let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            let query = HKObserverQuery(sampleType: stepsType, predicate: nil) { [weak self] _, completionHandler, _ in
                Task {
                    await self?.fetchTodayMetrics()
                    completionHandler()
                }
            }
            healthStore.execute(query)
            healthStore.enableBackgroundDelivery(for: stepsType, frequency: .immediate) { _, _ in }
        }
        
        // Наблюдатель за тренировками
        let workoutType = HKWorkoutType.workoutType()
        let wQuery = HKObserverQuery(sampleType: workoutType, predicate: nil) { [weak self] _, completionHandler, _ in
            Task {
                await self?.fetchWorkouts()
                completionHandler()
            }
        }
        healthStore.execute(wQuery)
        healthStore.enableBackgroundDelivery(for: workoutType, frequency: .immediate) { _, _ in }
        
        // Наблюдатель за сном (Apple Watch / Apple Health)
        if let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            let sQuery = HKObserverQuery(sampleType: sleepType, predicate: nil) { [weak self] _, completionHandler, _ in
                Task {
                    await self?.fetchSleepData()
                    completionHandler()
                }
            }
            healthStore.execute(sQuery)
            healthStore.enableBackgroundDelivery(for: sleepType, frequency: .immediate) { _, _ in }
        }
    }
    
    public func setupHeartRateObserver() {
        // Фоновый мониторинг пульса
    }
    
    // MARK: - Запись данных в Apple Health и локально
    
    public func saveWorkout(activityType: String, durationMinutes: Int, caloriesBurned: Double) {
        let now = Date()
        let start = now.addingTimeInterval(-Double(durationMinutes) * 60.0)
        saveWorkout(activityType: activityType, startDate: start, endDate: now, activeEnergyBurned: caloriesBurned, distance: 0.0)
    }
    
    public func saveWorkout(activityType: String, startDate: Date, endDate: Date, activeEnergyBurned: Double, distance: Double) {
        let durationMinutes = max(1, Int(endDate.timeIntervalSince(startDate) / 60.0))
        
        let record = WorkoutRecord(
            type: activityType,
            date: startDate,
            durationMinutes: durationMinutes,
            caloriesBurned: activeEnergyBurned
        )
        self.workoutHistory = HealthKitManager.deduplicateWorkouts([record] + self.workoutHistory)
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM"
        self.lastWorkoutString = "\(durationMinutes) мин — \(activityType)\n(\(formatter.string(from: startDate)))"
        
        GamificationManager.shared.addXP(100, reason: "Завершена тренировка \(activityType)")
        saveLocalData()
        
        // Запись в HKHealthStore
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let hkType = mapStringToHKWorkoutActivityType(activityType)
        let energyQty = HKQuantity(unit: .kilocalorie(), doubleValue: activeEnergyBurned)
        let distQty = distance > 0 ? HKQuantity(unit: .meter(), doubleValue: distance) : nil
        
        let workout = HKWorkout(
            activityType: hkType,
            start: startDate,
            end: endDate,
            duration: endDate.timeIntervalSince(startDate),
            totalEnergyBurned: energyQty,
            totalDistance: distQty,
            device: HKDevice.local(),
            metadata: ["App": "Forma", "WorkoutName": activityType]
        )
        
        healthStore.save(workout) { _, _ in }
    }
    
    public func addWeight(weightInKg: Double, date: Date = Date(), timeOfDay: String? = nil, note: String? = nil) {
        let record = WeightRecord(date: date, weight: weightInKg, timeOfDay: timeOfDay, note: note)
        self.weightHistory.append(record)
        self.weightHistory.sort(by: { $0.date < $1.date })
        
        if let last = self.weightHistory.last {
            self.currentWeight = last.weight
        } else {
            self.currentWeight = weightInKg
        }
        
        if weightHistory.count >= 2 {
            let prev = weightHistory[weightHistory.count - 2].weight
            let diff = self.currentWeight - prev
            if diff > 0.1 { self.weightTrend = .up }
            else if diff < -0.1 { self.weightTrend = .down }
            else { self.weightTrend = .stable }
        }
        UserDefaults.standard.set(self.currentWeight, forKey: "user_weight")
        UserDefaults.standard.set(self.currentWeight, forKey: "health_user_weight")
        saveLocalData()
        
        guard HKHealthStore.isHealthDataAvailable(),
              let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }
        
        let qty = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: weightInKg)
        let sample = HKQuantitySample(type: weightType, quantity: qty, start: date, end: date)
        healthStore.save(sample) { _, _ in }
    }
    
    public func addWeight(weight: Double) {
        addWeight(weightInKg: weight, date: Date())
    }
    
    public func deleteWeightRecord(id: UUID) {
        self.weightHistory.removeAll(where: { $0.id == id })
        if let last = self.weightHistory.last {
            self.currentWeight = last.weight
        } else {
            self.currentWeight = 0.0
        }
        
        if weightHistory.count >= 2 {
            let prev = weightHistory[weightHistory.count - 2].weight
            let diff = self.currentWeight - prev
            if diff > 0.1 { self.weightTrend = .up }
            else if diff < -0.1 { self.weightTrend = .down }
            else { self.weightTrend = .stable }
        } else {
            self.weightTrend = .stable
        }
        saveLocalData()
    }
    
    // MARK: - Трекинг воды и напитков
    public func logWaterDirectly(milliliters: Double) {
        addBeverage(type: .water, volumeMl: milliliters)
    }
    
    public func addWater(milliliters: Double) {
        addBeverage(type: .water, volumeMl: milliliters)
    }
    
    public func addWater(amount: Double) {
        addBeverage(type: .water, volumeMl: amount)
    }
    
    public func addBeverage(type: BeverageType, volumeMl: Double, customCalories: Double? = nil, customName: String? = nil) {
        let record = LoggedBeverageRecord(
            beverageType: type,
            volumeMl: volumeMl,
            effectiveHydrationMl: volumeMl * type.hydrationFactor,
            calories: customCalories ?? ((volumeMl / 100.0) * type.defaultCaloriesPer100ml),
            date: Date(),
            customName: customName
        )
        self.loggedBeveragesToday.append(record)
        
        // Пересчитываем эффективный объем гидратации
        recalculateTodayWaterTotals()
        
        // Если напиток калорийный, добавляем его в дневную калорийность и рацион
        if record.calories > 0 {
            self.caloriesConsumedToday += record.calories
            let mealRecord = LoggedMealRecord(
                name: "\(type.emoji) \(record.displayName)",
                calories: record.calories,
                protein: type == .milk ? (volumeMl * 0.032) : 0,
                fat: type == .milk ? (volumeMl * 0.025) : 0,
                carbs: (type == .soda || type == .juice) ? (volumeMl * 0.11) : (type == .milk ? (volumeMl * 0.047) : 0),
                weightGrams: volumeMl,
                category: .snack,
                date: Date(),
                emoji: type.emoji
            )
            self.loggedMealsToday.append(mealRecord)
        }
        
        saveLocalData()
        
        // Синхронизация с Live Activity & Dynamic Island
        HydrationLiveActivityManager.shared.syncHydrationLiveActivity(
            consumed: self.waterConsumed,
            goal: self.dynamicWaterGoal,
            lastBeverage: record,
            activeCaffeineMg: self.caffeineActiveInBloodMg,
            sleepCutoffDate: self.caffeineSleepCutoffDate,
            needsCaffeineCompensation: self.needsCaffeineWaterCompensation
        )
        
        // Умное напоминание о кофеине/паузе
        FormaNotificationManager.shared.scheduleAdaptiveDehydrationNotification(
            hasUncompensatedCaffeine: self.needsCaffeineWaterCompensation,
            hoursSinceLastDrink: 0.0
        )
        
        // Синхронизация с HealthKit
        guard HKHealthStore.isHealthDataAvailable(),
              let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else { return }
        
        let qty = HKQuantity(unit: .literUnit(with: .milli), doubleValue: record.effectiveHydrationMl)
        let sample = HKQuantitySample(type: waterType, quantity: qty, start: Date(), end: Date())
        healthStore.save(sample) { _, _ in }
        
        // Синхронизация кофеина с HealthKit
        if record.caffeineMg > 0,
           let caffeineType = HKQuantityType.quantityType(forIdentifier: .dietaryCaffeine) {
            let caffeineQty = HKQuantity(unit: .gramUnit(with: .milli), doubleValue: record.caffeineMg)
            let caffeineSample = HKQuantitySample(type: caffeineType, quantity: caffeineQty, start: Date(), end: Date())
            healthStore.save(caffeineSample) { _, _ in }
        }
    }
    
    public func deleteBeverage(id: UUID) {
        guard let record = loggedBeveragesToday.first(where: { $0.id == id }) else { return }
        self.loggedBeveragesToday.removeAll(where: { $0.id == id })
        recalculateTodayWaterTotals()
        
        if record.calories > 0 {
            self.caloriesConsumedToday = max(0, self.caloriesConsumedToday - record.calories)
            self.loggedMealsToday.removeAll(where: { $0.name.contains(record.displayName) })
        }
        saveLocalData()
        
        HydrationLiveActivityManager.shared.syncHydrationLiveActivity(
            consumed: self.waterConsumed,
            goal: self.dynamicWaterGoal,
            lastBeverage: self.loggedBeveragesToday.last,
            activeCaffeineMg: self.caffeineActiveInBloodMg,
            sleepCutoffDate: self.caffeineSleepCutoffDate,
            needsCaffeineCompensation: self.needsCaffeineWaterCompensation
        )
    }
    
    public func recalculateTodayWaterTotals() {
        let todayBeverages = loggedBeveragesToday.filter { Calendar.current.isDateInToday($0.date) }
        if !todayBeverages.isEmpty {
            self.waterConsumedToday = todayBeverages.reduce(0.0) { $0 + $1.effectiveHydrationMl }
        } else {
            let defaults = UserDefaults.standard
            self.waterConsumedToday = defaults.double(forKey: "water_consumed_\(todayKey)")
        }
    }
    
    public func resetWater() {
        // Очищаем напитки и воду
        let totalCalsFromBeverages = loggedBeveragesToday.reduce(0.0) { $0 + $1.calories }
        if totalCalsFromBeverages > 0 {
            self.caloriesConsumedToday = max(0, self.caloriesConsumedToday - totalCalsFromBeverages)
            for bev in loggedBeveragesToday where bev.calories > 0 {
                self.loggedMealsToday.removeAll(where: { $0.name.contains(bev.displayName) })
            }
        }
        self.loggedBeveragesToday.removeAll()
        self.waterConsumedToday = 0.0
        saveLocalData()
        HydrationLiveActivityManager.shared.endLiveActivity()
    }
    
    public func logNutritionDirectly(calories: Double, protein: Double = 0, fat: Double = 0, carbs: Double = 0) {
        self.caloriesConsumedToday += calories
        self.proteinConsumedToday += protein
        self.fatConsumedToday += fat
        self.carbsConsumedToday += carbs
        
        let newRecord = DailyNutritionRecord(dateString: todayKey, calories: caloriesConsumedToday)
        if let idx = self.nutritionHistory.firstIndex(where: { $0.dateString == todayKey }) {
            self.nutritionHistory[idx] = newRecord
        } else {
            self.nutritionHistory.append(newRecord)
        }
        saveLocalData()
    }
    
    /// Добавление блюда в дневник питания за сегодня и HealthKit
    public func addLoggedMeal(_ meal: LoggedMealRecord) {
        self.loggedMealsToday.append(meal)
        
        // Поддерживаем недавнюю историю приемов пищи (до 50 записей)
        if let idx = self.recentMealRecords.firstIndex(where: { $0.id == meal.id }) {
            self.recentMealRecords[idx] = meal
        } else {
            self.recentMealRecords.append(meal)
        }
        if self.recentMealRecords.count > 50 {
            self.recentMealRecords = Array(self.recentMealRecords.suffix(50))
        }
        
        recalculateTodayNutritionTotals()
        saveLocalData()
        
        guard HKHealthStore.isHealthDataAvailable() else { return }
        var samples: [HKQuantitySample] = []
        let now = meal.date
        
        if meal.calories > 0, let calType = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) {
            let q = HKQuantity(unit: .kilocalorie(), doubleValue: meal.calories)
            samples.append(HKQuantitySample(type: calType, quantity: q, start: now, end: now, metadata: ["Meal": meal.name]))
        }
        if meal.protein > 0, let protType = HKQuantityType.quantityType(forIdentifier: .dietaryProtein) {
            let q = HKQuantity(unit: .gram(), doubleValue: meal.protein)
            samples.append(HKQuantitySample(type: protType, quantity: q, start: now, end: now))
        }
        if meal.fat > 0, let fatType = HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal) {
            let q = HKQuantity(unit: .gram(), doubleValue: meal.fat)
            samples.append(HKQuantitySample(type: fatType, quantity: q, start: now, end: now))
        }
        if meal.carbs > 0, let carbsType = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates) {
            let q = HKQuantity(unit: .gram(), doubleValue: meal.carbs)
            samples.append(HKQuantitySample(type: carbsType, quantity: q, start: now, end: now))
        }
        
        if !samples.isEmpty {
            healthStore.save(samples) { success, error in
                if let error = error {
                    print("[HealthKit] Error saving logged meal samples: \(error)")
                }
            }
        }
    }
    
    /// Удаление блюда из дневника питания за сегодня
    public func deleteLoggedMeal(id: UUID) {
        self.loggedMealsToday.removeAll(where: { $0.id == id })
        self.recentMealRecords.removeAll(where: { $0.id == id })
        recalculateTodayNutritionTotals()
        saveLocalData()
    }
    
    /// Очистка всех блюд за сегодня
    public func clearTodayMeals() {
        let todayIds = Set(loggedMealsToday.map { $0.id })
        self.loggedMealsToday.removeAll()
        self.recentMealRecords.removeAll(where: { todayIds.contains($0.id) })
        recalculateTodayNutritionTotals()
        saveLocalData()
    }
    
    private func recalculateTodayNutritionTotals() {
        // Учитываем строго блюда сегодняшнего дня, чтобы вчерашние не суммировались
        let todayMeals = loggedMealsToday.filter { Calendar.current.isDateInToday($0.date) }
        if !todayMeals.isEmpty {
            self.caloriesConsumedToday = todayMeals.reduce(0.0) { $0 + $1.calories }
            self.proteinConsumedToday = todayMeals.reduce(0.0) { $0 + $1.protein }
            self.fatConsumedToday = todayMeals.reduce(0.0) { $0 + $1.fat }
            self.carbsConsumedToday = todayMeals.reduce(0.0) { $0 + $1.carbs }
        } else {
            self.caloriesConsumedToday = 0.0
            self.proteinConsumedToday = 0.0
            self.fatConsumedToday = 0.0
            self.carbsConsumedToday = 0.0
        }
        
        let newRecord = DailyNutritionRecord(dateString: todayKey, calories: caloriesConsumedToday)
        if let idx = self.nutritionHistory.firstIndex(where: { $0.dateString == todayKey }) {
            self.nutritionHistory[idx] = newRecord
        } else {
            self.nutritionHistory.append(newRecord)
        }
    }
    
    public func addDietaryNutrition(calories: Double, protein: Double = 0, fat: Double = 0, carbs: Double = 0, fiber: Double? = nil, sugar: Double? = nil, sodium: Double? = nil, mealName: String = "") {
        logNutritionDirectly(calories: calories, protein: protein, fat: fat, carbs: carbs)
        
        guard HKHealthStore.isHealthDataAvailable() else { return }
        var samples: [HKQuantitySample] = []
        let now = Date()
        
        if let calType = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed), calories > 0 {
            let q = HKQuantity(unit: .kilocalorie(), doubleValue: calories)
            samples.append(HKQuantitySample(type: calType, quantity: q, start: now, end: now, metadata: ["Meal": mealName]))
        }
        if let protType = HKQuantityType.quantityType(forIdentifier: .dietaryProtein), protein > 0 {
            let q = HKQuantity(unit: .gram(), doubleValue: protein)
            samples.append(HKQuantitySample(type: protType, quantity: q, start: now, end: now))
        }
        if let fatType = HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal), fat > 0 {
            let q = HKQuantity(unit: .gram(), doubleValue: fat)
            samples.append(HKQuantitySample(type: fatType, quantity: q, start: now, end: now))
        }
        if let carbsType = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates), carbs > 0 {
            let q = HKQuantity(unit: .gram(), doubleValue: carbs)
            samples.append(HKQuantitySample(type: carbsType, quantity: q, start: now, end: now))
        }
        if let fib = fiber, fib > 0, let fiberType = HKQuantityType.quantityType(forIdentifier: .dietaryFiber) {
            let q = HKQuantity(unit: .gram(), doubleValue: fib)
            samples.append(HKQuantitySample(type: fiberType, quantity: q, start: now, end: now))
        }
        if let sug = sugar, sug > 0, let sugarType = HKQuantityType.quantityType(forIdentifier: .dietarySugar) {
            let q = HKQuantity(unit: .gram(), doubleValue: sug)
            samples.append(HKQuantitySample(type: sugarType, quantity: q, start: now, end: now))
        }
        if let sod = sodium, sod > 0, let sodiumType = HKQuantityType.quantityType(forIdentifier: .dietarySodium) {
            let q = HKQuantity(unit: .gramUnit(with: .milli), doubleValue: sod)
            samples.append(HKQuantitySample(type: sodiumType, quantity: q, start: now, end: now))
        }
        
        if !samples.isEmpty {
            healthStore.save(samples) { _, _ in }
        }
    }
    
    public func addSleepRecord(hours: Double, deepHours: Double = 0.0, startDate: Date = Date(), endDate: Date = Date()) {
        guard HKHealthStore.isHealthDataAvailable(),
              let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        
        let totalSeconds = max(1800, endDate.timeIntervalSince(startDate))
        var samples: [HKCategorySample] = []
        
        if #available(iOS 16.0, *), deepHours > 0 {
            let deepSec = min(deepHours * 3600.0, totalSeconds * 0.5)
            let remSec = (totalSeconds - deepSec) * 0.3
            let coreSec = max(0, totalSeconds - deepSec - remSec)
            
            let t1 = startDate
            let t2 = t1.addingTimeInterval(deepSec)
            let t3 = t2.addingTimeInterval(remSec)
            let t4 = endDate
            
            samples.append(HKCategorySample(type: sleepType, value: HKCategoryValueSleepAnalysis.asleepDeep.rawValue, start: t1, end: t2))
            if remSec > 0 {
                samples.append(HKCategorySample(type: sleepType, value: HKCategoryValueSleepAnalysis.asleepREM.rawValue, start: t2, end: t3))
            }
            if coreSec > 0 {
                samples.append(HKCategorySample(type: sleepType, value: HKCategoryValueSleepAnalysis.asleepCore.rawValue, start: t3, end: t4))
            }
        } else {
            samples.append(HKCategorySample(type: sleepType, value: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue, start: startDate, end: endDate))
        }
        
        healthStore.save(samples) { [weak self] success, _ in
            if success {
                Task {
                    await self?.fetchSleepData()
                }
            }
        }
    }
    
    public func addHeartRateSample(bpm: Double) {
        self.latestHeartRate = bpm
        guard HKHealthStore.isHealthDataAvailable(),
              let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        let qty = HKQuantity(unit: HKUnit.count().unitDivided(by: .minute()), doubleValue: bpm)
        let sample = HKQuantitySample(type: hrType, quantity: qty, start: Date(), end: Date())
        healthStore.save(sample) { _, _ in }
    }
    
    public func addHeartRateSample(bpm: Int) {
        addHeartRateSample(bpm: Double(bpm))
    }
    
    private var liveHRQuery: HKAnchoredObjectQuery?
    private var liveHRTimer: Timer?
    
    public func startLiveHeartRateSession() {
        self.isLiveHeartRateActive = true
        self.liveHeartRate = latestHeartRate > 0 ? latestHeartRate : 0.0
        
        let startImpact = UINotificationFeedbackGenerator()
        startImpact.notificationOccurred(.success)
        
        // 1. Потоковый слушатель сэмплов из Apple Watch, AirPods Pro и внешних Bluetooth-пульсометров
        if HKHealthStore.isHealthDataAvailable(),
           let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            let predicate = HKQuery.predicateForSamples(withStart: Date(), end: nil, options: .strictStartDate)
            let query = HKAnchoredObjectQuery(type: hrType, predicate: predicate, anchor: nil, limit: HKObjectQueryNoLimit) { [weak self] _, samples, _, _, _ in
                if let samples = samples as? [HKQuantitySample], let last = samples.last {
                    let bpm = last.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    Task { @MainActor [weak self] in
                        self?.applyLiveBpm(bpm)
                    }
                }
            }
            query.updateHandler = { [weak self] _, samples, _, _, _ in
                if let samples = samples as? [HKQuantitySample], let last = samples.last {
                    let bpm = last.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    Task { @MainActor [weak self] in
                        self?.applyLiveBpm(bpm)
                    }
                }
            }
            self.liveHRQuery = query
            self.healthStore.execute(query)
        }
        
        // 2. Тактильный метроном ударов сердца в реальном времени
        startHeartbeatLoop()
    }
    
    private func applyLiveBpm(_ bpm: Double) {
        guard self.isLiveHeartRateActive else { return }
        self.liveHeartRate = bpm
        self.latestHeartRate = bpm
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
    
    private func startHeartbeatLoop() {
        liveHRTimer?.invalidate()
        let bpm = liveHeartRate > 0 ? liveHeartRate : (latestHeartRate > 0 ? latestHeartRate : 70.0)
        let interval = max(0.4, min(1.5, 60.0 / max(40.0, bpm)))
        liveHRTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self, self.isLiveHeartRateActive else { return }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.75)
        }
    }
    
    public func stopLiveHeartRateSession() {
        self.isLiveHeartRateActive = false
        if let query = liveHRQuery {
            healthStore.stop(query)
            liveHRQuery = nil
        }
        liveHRTimer?.invalidate()
        liveHRTimer = nil
        
        if liveHeartRate > 0 {
            self.latestHeartRate = liveHeartRate
            addHeartRateSample(bpm: liveHeartRate)
        }
        
        let stopImpact = UIImpactFeedbackGenerator(style: .medium)
        stopImpact.impactOccurred()
    }
    
    public func toggleLiveHeartRateSession() {
        if isLiveHeartRateActive {
            stopLiveHeartRateSession()
        } else {
            startLiveHeartRateSession()
        }
    }
    
    public func syncHistoricalStepsFromHealthKit(days: Int = 365) {
        Task {
            await syncFullHistoricalData(daysBack: days)
        }
    }
    
    // MARK: - Запросы по датам
    public func activityForDate(_ date: Date) -> DailyActivitySummary? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        let key = formatter.string(from: date)
        if Calendar.current.isDateInToday(date) {
            let activeCal = activeEnergyBurned > 0 ? activeEnergyBurned : calculatedStepCalories
            let steps = stepsToday > 0 ? stepsToday : BackgroundStepManager.shared.stepsToday
            let dist = distanceMetersToday > 0 ? distanceMetersToday : BackgroundStepManager.shared.distanceMeters
            return DailyActivitySummary(dateKey: key, date: date, steps: steps, distanceMeters: dist, activeCalories: activeCal)
        }
        return dailyActivityHistory[key]
    }
    
    public func stepsForDate(_ date: Date) -> Int {
        if Calendar.current.isDateInToday(date) {
            return stepsToday > 0 ? stepsToday : BackgroundStepManager.shared.stepsToday
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        let key = formatter.string(from: date)
        return dailyActivityHistory[key]?.steps ?? 0
    }
    
    // MARK: - Локальное сохранение и загрузка
    public func loadLocalData() {
        let defaults = UserDefaults.standard
        let currentKey = todayKey
        
        if defaults.object(forKey: "health_steps_\(currentKey)") != nil {
            self.stepsToday = defaults.integer(forKey: "health_steps_\(currentKey)")
        } else {
            self.stepsToday = 0
        }
        
        self.stepDistanceKm = defaults.double(forKey: "health_distance_\(currentKey)")
        if self.stepDistanceKm == 0 && self.stepsToday > 0 {
            self.stepDistanceKm = (Double(self.stepsToday) * 0.75) / 1000.0
        }
        
        self.todayFloors = defaults.integer(forKey: "health_floors_\(currentKey)")
        
        if let data = defaults.data(forKey: "health_logged_meals_\(currentKey)"),
           let meals = try? JSONDecoder().decode([LoggedMealRecord].self, from: data) {
            // Фильтруем строго блюда сегодняшнего дня, чтобы вчерашние не сохранялись в текущем дне
            self.loggedMealsToday = meals.filter { Calendar.current.isDateInToday($0.date) }
        } else {
            self.loggedMealsToday = []
        }
        
        if let data = defaults.data(forKey: "health_recent_meals_history"),
           let recents = try? JSONDecoder().decode([LoggedMealRecord].self, from: data) {
            self.recentMealRecords = recents
        } else {
            self.recentMealRecords = self.loggedMealsToday
        }
        
        if let data = defaults.data(forKey: "health_logged_beverages_\(currentKey)"),
           let bevs = try? JSONDecoder().decode([LoggedBeverageRecord].self, from: data) {
            // Фильтруем строго напитки сегодняшнего дня
            self.loggedBeveragesToday = bevs.filter { Calendar.current.isDateInToday($0.date) }
        } else {
            self.loggedBeveragesToday = []
        }
        
        // Калории и макронутриенты рассчитываются строго из блюд сегодняшнего дня,
        // предотвращая суммирование вчерашних калорий с сегодняшними
        if !self.loggedMealsToday.isEmpty {
            self.caloriesConsumedToday = self.loggedMealsToday.reduce(0.0) { $0 + $1.calories }
            self.proteinConsumedToday = self.loggedMealsToday.reduce(0.0) { $0 + $1.protein }
            self.fatConsumedToday = self.loggedMealsToday.reduce(0.0) { $0 + $1.fat }
            self.carbsConsumedToday = self.loggedMealsToday.reduce(0.0) { $0 + $1.carbs }
        } else {
            self.caloriesConsumedToday = defaults.double(forKey: "nutrition_calories_\(currentKey)")
            self.proteinConsumedToday = defaults.double(forKey: "nutrition_protein_\(currentKey)")
            self.fatConsumedToday = defaults.double(forKey: "nutrition_fat_\(currentKey)")
            self.carbsConsumedToday = defaults.double(forKey: "nutrition_carbs_\(currentKey)")
        }
        
        // Вода рассчитывается строго из напитков сегодняшнего дня
        if !self.loggedBeveragesToday.isEmpty {
            self.waterConsumedToday = self.loggedBeveragesToday.reduce(0.0) { $0 + $1.effectiveHydrationMl }
        } else {
            self.waterConsumedToday = defaults.double(forKey: "water_consumed_\(currentKey)")
        }
        
        if defaults.double(forKey: "health_water_goal") > 0 {
            self.waterGoal = defaults.double(forKey: "health_water_goal")
        }
        if defaults.double(forKey: "health_user_weight") > 0 {
            self.currentWeight = defaults.double(forKey: "health_user_weight")
        } else if defaults.double(forKey: "user_weight") > 0 {
            self.currentWeight = defaults.double(forKey: "user_weight")
        }
        if defaults.double(forKey: "health_sleep_\(todayKey)") > 0 {
            self.todaySleepHours = defaults.double(forKey: "health_sleep_\(todayKey)")
        }
        
        if let data = defaults.data(forKey: "health_workout_history"),
           let workouts = try? JSONDecoder().decode([WorkoutRecord].self, from: data) {
            self.workoutHistory = workouts
            if let last = workouts.first {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "ru_RU")
                formatter.dateFormat = "d MMM"
                self.lastWorkoutString = "\(last.durationMinutes) мин — \(last.type)\n(\(formatter.string(from: last.date)))"
            }
        }
        
        if let data = defaults.data(forKey: "health_weight_history"),
           let weights = try? JSONDecoder().decode([WeightRecord].self, from: data) {
            self.weightHistory = weights
            if let last = weights.last {
                self.currentWeight = last.weight
            }
        }
        
        if let data = defaults.data(forKey: "health_daily_activity_history"),
           let activity = try? JSONDecoder().decode([String: DailyActivitySummary].self, from: data) {
            self.dailyActivityHistory = activity
        }
        
        if let data = defaults.data(forKey: "health_nutrition_history"),
           let nutrition = try? JSONDecoder().decode([DailyNutritionRecord].self, from: data) {
            self.nutritionHistory = nutrition
        }
        
        if let data = defaults.data(forKey: "health_weekly_steps"),
           let weekly = try? JSONDecoder().decode([WeeklyStepsData].self, from: data) {
            self.weeklySteps = weekly
        } else {
            generateDefaultWeeklySteps()
        }
    }
    
    public func saveLocalData() {
        let defaults = UserDefaults.standard
        defaults.set(stepsToday, forKey: "health_steps_\(todayKey)")
        defaults.set(stepDistanceKm, forKey: "health_distance_\(todayKey)")
        defaults.set(todayFloors, forKey: "health_floors_\(todayKey)")
        defaults.set(waterConsumedToday, forKey: "water_consumed_\(todayKey)")
        defaults.set(waterGoal, forKey: "health_water_goal")
        defaults.set(caloriesConsumedToday, forKey: "nutrition_calories_\(todayKey)")
        defaults.set(proteinConsumedToday, forKey: "nutrition_protein_\(todayKey)")
        defaults.set(fatConsumedToday, forKey: "nutrition_fat_\(todayKey)")
        defaults.set(carbsConsumedToday, forKey: "nutrition_carbs_\(todayKey)")
        defaults.set(currentWeight, forKey: "health_user_weight")
        if currentWeight > 0 {
            defaults.set(currentWeight, forKey: "user_weight")
        }
        defaults.set(todaySleepHours, forKey: "health_sleep_\(todayKey)")
        
        if let encoded = try? JSONEncoder().encode(loggedMealsToday) {
            defaults.set(encoded, forKey: "health_logged_meals_\(todayKey)")
        }
        if let encoded = try? JSONEncoder().encode(recentMealRecords) {
            defaults.set(encoded, forKey: "health_recent_meals_history")
        }
        if let encoded = try? JSONEncoder().encode(loggedBeveragesToday) {
            defaults.set(encoded, forKey: "health_logged_beverages_\(todayKey)")
        }
        if let encoded = try? JSONEncoder().encode(workoutHistory) {
            defaults.set(encoded, forKey: "health_workout_history")
        }
        if let encoded = try? JSONEncoder().encode(weightHistory) {
            defaults.set(encoded, forKey: "health_weight_history")
        }
        if let encoded = try? JSONEncoder().encode(dailyActivityHistory) {
            defaults.set(encoded, forKey: "health_daily_activity_history")
        }
        if let encoded = try? JSONEncoder().encode(nutritionHistory) {
            defaults.set(encoded, forKey: "health_nutrition_history")
        }
        if let encoded = try? JSONEncoder().encode(weeklySteps) {
            defaults.set(encoded, forKey: "health_weekly_steps")
        }
        
        syncWidgetsData()
    }
    
    // MARK: - Синхронизация данных виджетов WidgetKit
    public func syncWidgetsData() {
        let coach = AICoachManager.shared.currentCoach
        let userWeight = currentWeight > 30 ? currentWeight : 74.5
        let userGoalWeight = 70.0
        let realSteps = max(stepsToday, BackgroundStepManager.shared.stepsToday)
        let realActiveCalories = activeEnergyBurned > 0 ? activeEnergyBurned : calculatedStepCalories
        let totalBurned = realActiveCalories + (basalEnergyBurned > 0 ? basalEnergyBurned : 1650.0)
        let balance = caloriesConsumedToday - totalBurned
        let currentHR = heartRate > 0 ? Int(heartRate) : (latestHeartRate > 0 ? Int(latestHeartRate) : (restingHeartRate > 0 ? Int(restingHeartRate) : 0))
        
        let snapshot = FormaWidgetDataSnapshot(
            stepsToday: realSteps,
            stepGoal: BackgroundStepManager.shared.stepGoal > 0 ? BackgroundStepManager.shared.stepGoal : 10000,
            activeCalories: realActiveCalories,
            activeCaloriesGoal: activeEnergyGoal > 0 ? activeEnergyGoal : 500.0,
            exerciseMinutes: appleExerciseTimeMinutes,
            exerciseMinutesGoal: Int(exerciseGoal > 0 ? exerciseGoal : 30),
            standHours: appleStandHours,
            standHoursGoal: standHoursGoal > 0 ? standHoursGoal : 12,
            currentHeartRate: currentHR,
            waterConsumed: waterConsumedToday,
            waterGoal: dynamicWaterGoal > 0 ? dynamicWaterGoal : 2500.0,
            caloriesConsumed: caloriesConsumedToday,
            totalCaloriesBurned: totalBurned,
            energyBalance: balance,
            currentWeight: userWeight,
            targetWeight: userGoalWeight,
            coachId: coach.id.rawValue,
            coachName: coach.name,
            coachAvatarAssetName: coach.avatarAssetName,
            coachBadgeEmoji: coach.badgeEmoji,
            coachAdvice: "Отличный темп активности! Держи ритм, пей воду и не забывай о разминке.",
            lastUpdated: Date()
        )
        
        FormaWidgetDataManager.shared.saveSnapshot(snapshot)
        
        if waterConsumedToday > 0 {
            HydrationLiveActivityManager.shared.syncHydrationLiveActivity(
                consumed: self.waterConsumed,
                goal: self.dynamicWaterGoal,
                lastBeverage: self.loggedBeveragesToday.last,
                activeCaffeineMg: self.caffeineActiveInBloodMg,
                sleepCutoffDate: self.caffeineSleepCutoffDate,
                needsCaffeineCompensation: self.needsCaffeineWaterCompensation
            )
        }
    }
    
    private func generateDefaultWeeklySteps() {
        let days = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
        self.weeklySteps = days.map { day in
            WeeklyStepsData(day: day, steps: 0)
        }
    }
    
    // MARK: - Пакетный импорт данных из CSV
    public func importWorkoutsFromCSV(_ workouts: [WorkoutRecord], saveToHK: Bool = true) async {
        let combined = self.workoutHistory + workouts
        self.workoutHistory = HealthKitManager.deduplicateWorkouts(combined)
        saveLocalData()
        
        if saveToHK && HKHealthStore.isHealthDataAvailable() {
            let _ = await HealthDataCSVManager.shared.writeWorkoutsToHealthKit(workouts)
        }
    }
    
    public func importWeightsFromCSV(_ weights: [WeightRecord], saveToHK: Bool = true) async {
        for w in weights {
            self.weightHistory.append(w)
        }
        self.weightHistory.sort(by: { $0.date < $1.date })
        if let last = self.weightHistory.last {
            self.currentWeight = last.weight
        }
        saveLocalData()
        
        if saveToHK && HKHealthStore.isHealthDataAvailable() {
            let _ = await HealthDataCSVManager.shared.writeWeightsToHealthKit(weights)
        }
    }
    
    public func importActivitiesFromCSV(_ activities: [DailyActivitySummary], saveToHK: Bool = true) async {
        for a in activities {
            self.dailyActivityHistory[a.dateKey] = a
        }
        saveLocalData()
    }
    
    public func importNutritionsFromCSV(_ nutritions: [DailyNutritionRecord], waters: [(date: Date, ml: Double)], saveToHK: Bool = true) async {
        for n in nutritions {
            if let idx = self.nutritionHistory.firstIndex(where: { $0.dateString == n.dateString }) {
                self.nutritionHistory[idx].calories += n.calories
            } else {
                self.nutritionHistory.append(n)
            }
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        for w in waters {
            let key = formatter.string(from: w.date)
            if key == todayKey {
                self.waterConsumedToday += w.ml
            }
        }
        saveLocalData()
    }
    
    public func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
    
    // MARK: - Вспомогательные функции запросов
    private func executeSumQuantityQuery(type: HKQuantityType, unit: HKUnit, predicate: NSPredicate) async -> Double {
        await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, _ in
                let value = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0.0
                continuation.resume(returning: value)
            }
            self.healthStore.execute(query)
        }
    }
    
    nonisolated private func mapHKWorkoutTypeToString(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "Бег"
        case .walking: return "Ходьба"
        case .hiking: return "Хайкинг"
        case .cycling: return "Велоспорт"
        case .swimming: return "Плавание"
        case .jumpRope: return "Скакалка"
        case .rowing: return "Гребля"
        case .elliptical: return "Эллипс"
        case .stairClimbing: return "Степпер"
        case .traditionalStrengthTraining: return "Силовая"
        case .functionalStrengthTraining: return "Функциональная"
        case .crossTraining: return "Кроссфит"
        case .highIntensityIntervalTraining: return "HIIT"
        case .boxing: return "Бокс"
        case .martialArts: return "Единоборства"
        case .yoga: return "Йога"
        case .pilates: return "Пилатес"
        case .flexibility: return "Растяжка"
        case .coreTraining: return "Кор"
        case .mindAndBody: return "Дыхание"
        case .soccer: return "Футбол"
        case .basketball: return "Баскетбол"
        case .tennis: return "Теннис"
        case .tableTennis: return "Падел"
        case .badminton: return "Бадминтон"
        case .downhillSkiing, .crossCountrySkiing, .snowboarding: return "Лыжи/Сноуборд"
        default: return "Тренировка"
        }
    }
    
    private func mapStringToHKWorkoutActivityType(_ str: String) -> HKWorkoutActivityType {
        let lower = str.lowercased()
        if lower.contains("бег") || lower.contains("run") { return .running }
        if lower.contains("ходьб") || lower.contains("walk") { return .walking }
        if lower.contains("хайкинг") || lower.contains("гор") || lower.contains("hike") { return .hiking }
        if lower.contains("вело") || lower.contains("cycl") || lower.contains("bike") { return .cycling }
        if lower.contains("плав") || lower.contains("swim") { return .swimming }
        if lower.contains("скакал") || lower.contains("rope") { return .jumpRope }
        if lower.contains("греб") || lower.contains("row") { return .rowing }
        if lower.contains("эллипс") || lower.contains("elliptical") { return .elliptical }
        if lower.contains("степпер") || lower.contains("stair") { return .stairClimbing }
        if lower.contains("hiit") || lower.contains("интервал") { return .highIntensityIntervalTraining }
        if lower.contains("кроссфит") || lower.contains("калистеник") || lower.contains("турник") { return .crossTraining }
        if lower.contains("бокс") || lower.contains("кикбокс") { return .boxing }
        if lower.contains("единоборств") || lower.contains("мма") || lower.contains("martial") { return .martialArts }
        if lower.contains("йог") || lower.contains("yoga") { return .yoga }
        if lower.contains("пилатес") || lower.contains("pilates") { return .pilates }
        if lower.contains("растяжк") || lower.contains("гибкост") || lower.contains("stretch") { return .flexibility }
        if lower.contains("кор") || lower.contains("планк") { return .coreTraining }
        if lower.contains("дыхан") || lower.contains("breath") { return .mindAndBody }
        if lower.contains("футбол") || lower.contains("soccer") { return .soccer }
        if lower.contains("баскетбол") || lower.contains("basketball") { return .basketball }
        if lower.contains("теннис") && !lower.contains("падел") && !lower.contains("настольн") { return .tennis }
        if lower.contains("падел") || lower.contains("настольн") || lower.contains("table tennis") { return .tableTennis }
        if lower.contains("бадминтон") || lower.contains("badminton") { return .badminton }
        if lower.contains("лыж") || lower.contains("сноуборд") || lower.contains("ski") { return .downhillSkiing }
        if lower.contains("сил") || lower.contains("strength") || lower.contains("гантел") || lower.contains("штанга") || lower.contains("отжиман") || lower.contains("приседан") || lower.contains("подтягиван") || lower.contains("берпи") {
            return .traditionalStrengthTraining
        }
        return .functionalStrengthTraining
    }
}
