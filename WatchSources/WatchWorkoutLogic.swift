import Foundation
import HealthKit

// MARK: - Чистая логика тренировок на часах
//
// Здесь собрано то, что не зависит от самих часов (датчиков, WatchKit, интерфейса), поэтому проверяется
// автоматически: сопоставление тренировки с типом занятия Apple Health, счёт повторов по акселерометру,
// оценка калорий без датчика пульса. Файл подключён и к приложению часов, и к тестам.

/// Сопоставление названия тренировки из списка часов с типом занятия HealthKit.
/// От типа зависят калории, шаги/дистанция и то, в какое кольцо и раздел «Здоровья» попадёт занятие.
enum WatchWorkoutMapping {

    static func activityType(for name: String) -> HKWorkoutActivityType {
        let n = name.lowercased()
        if n.contains("бег на улице") || n == "бег" {
            return .running
        } else if n.contains("дорожка") {
            return .running
        } else if n.contains("ходьба") {
            return .walking
        } else if n.contains("хайкинг") || n.contains("горы") {
            return .hiking
        } else if n.contains("велоспорт") || n == "велосипед" {
            return .cycling
        } else if n.contains("велотренажер") || n.contains("спиннинг") {
            return .cycling
        } else if n.contains("плавание") || n.contains("вода") || n.contains("бассейн") {
            return .swimming
        } else if n.contains("скакалка") {
            return .jumpRope
        } else if n.contains("гребн") || n.contains("гребля") {
            return .rowing
        } else if n.contains("эллипс") {
            return .elliptical
        } else if n.contains("степпер") {
            return .stairClimbing
        } else if n.contains("силов") || n.contains("гантели") || n.contains("штанга") {
            return .traditionalStrengthTraining
        } else if n.contains("калистеника") || n.contains("турник") {
            return .crossTraining
        } else if n.contains("hiit") || n.contains("интервальн") {
            return .highIntensityIntervalTraining
        } else if n.contains("кроссфит") {
            return .crossTraining
        } else if n.contains("бокс") || n.contains("кикбоксинг") {
            return .boxing
        } else if n.contains("единоборства") || n.contains("мма") {
            return .martialArts
        } else if n.contains("йога") {
            return .yoga
        } else if n.contains("пилатес") {
            return .pilates
        } else if n.contains("растяжка") || n.contains("гибкость") {
            return .flexibility
        } else if n.contains("кор") || n.contains("планка") {
            return .coreTraining
        } else if n.contains("дыха") {
            // Раньше искали «дыхан» и не находили «Дыхательные практики»: занятие записывалось как силовая тренировка
            return .mindAndBody
        } else if n.contains("футбол") {
            return .soccer
        } else if n.contains("баскетбол") {
            return .basketball
        } else if n.contains("теннис") && !n.contains("настольный") && !n.contains("падел") {
            return .tennis
        } else if n.contains("падел") || n.contains("настольный") {
            return .tableTennis
        } else if n.contains("бадминтон") {
            return .badminton
        } else if n.contains("лыжи") || n.contains("сноуборд") {
            return .downhillSkiing
        } else if n.contains("отжимания") || n.contains("приседания") || n.contains("подтягивания") || n.contains("берпи") {
            return .traditionalStrengthTraining
        }
        return .functionalStrengthTraining
    }

    /// Улица или помещение: на улице часы ведут GPS-маршрут и считают дистанцию по спутникам.
    static func locationType(for name: String) -> HKWorkoutSessionLocationType {
        let n = name.lowercased()
        if n.contains("на улице") || n.contains("хайкинг") || n.contains("открытая вода") || n.contains("лыжи") || n.contains("сноуборд") {
            return .outdoor
        }
        // «Спортивная ходьба» раньше попадала сюда только при точном совпадении «ходьба» и записывалась как
        // занятие в помещении — без GPS-маршрута и дистанции.
        if n.contains("ходьба") {
            return .outdoor
        }
        if n == "бег" || n == "велоспорт" || n == "футбол" {
            return .outdoor
        }
        return .indoor
    }

    /// Бассейн или открытая вода — нужно часам, чтобы правильно считать гребки и круги. Для остальных — nil.
    static func swimmingLocation(for name: String) -> HKWorkoutSwimmingLocationType? {
        guard activityType(for: name) == .swimming else { return nil }
        return name.lowercased().contains("открытая") ? .openWater : .pool
    }

    /// Длина бассейна по умолчанию, м. Без неё часы не считают круги и дистанцию в бассейне.
    static let defaultPoolLengthMeters: Double = 25
}

/// Счёт повторов по магнитуде ускорения (в g) с запястья.
/// Повтор — это «рывок вверх» выше `upperThreshold`, после которого сглаженная магнитуда падает ниже `lowerThreshold`.
/// Сглаживание — скользящее среднее по `windowSize` отсчётам, между повторами — пауза `debounce`.
struct WatchRepCounter {
    let upperThreshold: Double
    let lowerThreshold: Double
    let debounce: TimeInterval
    let windowSize: Int

    private(set) var history: [Double] = []
    private(set) var isAboveUpper = false
    private(set) var lastRepTime: TimeInterval = 0

    init(upperThreshold: Double = 1.22, lowerThreshold: Double = 0.82, debounce: TimeInterval = 1.0, windowSize: Int = 5) {
        self.upperThreshold = upperThreshold
        self.lowerThreshold = lowerThreshold
        self.debounce = debounce
        self.windowSize = windowSize
    }

    mutating func reset() {
        history.removeAll()
        isAboveUpper = false
    }

    /// Принимает очередной отсчёт; возвращает true, если завершён ещё один повтор.
    @discardableResult
    mutating func process(magnitude: Double, at time: TimeInterval) -> Bool {
        history.append(magnitude)
        if history.count > windowSize {
            history.removeFirst()
        }
        let smooth = history.reduce(0, +) / Double(history.count)

        if !isAboveUpper {
            if smooth > upperThreshold {
                isAboveUpper = true
            }
            return false
        }

        guard smooth < lowerThreshold else { return false }
        isAboveUpper = false
        if time - lastRepTime > debounce {
            lastRepTime = time
            return true
        }
        return false
    }
}

/// Оценка калорий по МЕТ, когда нет данных датчиков (запасной вариант автономного режима).
enum WatchCalorieEstimator {
    /// Вес, который принимается, пока профиль с телефона недоступен на часах
    static let defaultWeightKg: Double = 75

    /// ккал = МЕТ × 3,5 × вес / 200 в минуту
    static func kcal(met: Double, weightKg: Double, seconds: Double) -> Double {
        guard met > 0, weightKg > 0, seconds > 0 else { return 0 }
        return met * 3.5 * weightKg / 200.0 / 60.0 * seconds
    }
}
