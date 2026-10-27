import XCTest
import HealthKit
#if os(watchOS)
@testable import FormaWatch
#endif

// Проверка логики приложения часов без самих часов. Файл запускается дважды:
//  • в симуляторе Apple Watch (схема FormaWatch, набор FormaWatchTests);
//  • в iOS-наборе FormaTests: логика платформо-независима.
// Датчики (пульс, акселерометр на запястье, GPS) эти тесты не проверяют — для них нужны настоящие часы.

// MARK: - Каталог тренировок часов

final class WatchWorkoutCatalogTests: XCTestCase {

    func testCatalogHasAllThirtyFiveWorkouts() {
        XCTAssertEqual(WatchWorkoutItem.allItems.count, 35)
    }

    func testWorkoutNamesAreUnique() {
        let names = WatchWorkoutItem.allItems.map(\.name)
        XCTAssertEqual(Set(names).count, names.count, "Названия тренировок должны быть уникальны: по названию находится тип занятия")
    }

    func testMetValuesAreRealistic() {
        for item in WatchWorkoutItem.allItems {
            XCTAssertTrue((1.0...12.0).contains(item.met), "\(item.name): МЕТ \(item.met) вне разумных пределов")
        }
    }
}

// MARK: - Сопоставление с типами Apple Health

final class WatchWorkoutMappingTests: XCTestCase {

    private let expectedActivity: [String: HKWorkoutActivityType] = [
        "Бег на улице": .running,
        "Беговая дорожка": .running,
        "Спортивная ходьба": .walking,
        "Хайкинг и горы": .hiking,
        "Велоспорт": .cycling,
        "Велотренажер": .cycling,
        "Плавание в бассейне": .swimming,
        "Открытая вода": .swimming,
        "Скакалка": .jumpRope,
        "Гребной тренажер": .rowing,
        "Эллипс": .elliptical,
        "Степпер": .stairClimbing,
        "Силовая тренировка": .traditionalStrengthTraining,
        "Гантели и штанга": .traditionalStrengthTraining,
        "Калистеника / Турники": .crossTraining,
        "HIIT / Интервальная": .highIntensityIntervalTraining,
        "Кроссфит": .crossTraining,
        "Бокс / Кикбоксинг": .boxing,
        "Единоборства / ММА": .martialArts,
        "Йога": .yoga,
        "Пилатес": .pilates,
        "Растяжка и гибкость": .flexibility,
        "Тренировка кора": .coreTraining,
        "Дыхательные практики": .mindAndBody,
        "Футбол": .soccer,
        "Баскетбол": .basketball,
        "Большой теннис": .tennis,
        "Падел / Настольный теннис": .tableTennis,
        "Бадминтон": .badminton,
        "Лыжи и сноуборд": .downhillSkiing,
        "Отжимания": .traditionalStrengthTraining,
        "Приседания": .traditionalStrengthTraining,
        "Планка": .coreTraining,
        "Подтягивания": .traditionalStrengthTraining,
        "Берпи": .traditionalStrengthTraining
    ]

    func testExpectedTableCoversWholeCatalog() {
        XCTAssertEqual(Set(expectedActivity.keys), Set(WatchWorkoutItem.allItems.map(\.name)),
                       "Таблица ожиданий должна покрывать все тренировки каталога")
    }

    func testEveryWorkoutMapsToExpectedActivityType() {
        for item in WatchWorkoutItem.allItems {
            XCTAssertEqual(WatchWorkoutMapping.activityType(for: item.name), expectedActivity[item.name],
                           "«\(item.name)» записывается в Apple Health не тем типом занятия")
        }
    }

    func testNoWorkoutFallsBackToGenericType() {
        // Тип по умолчанию (функциональная силовая) означает, что название не распознано.
        for item in WatchWorkoutItem.allItems {
            XCTAssertNotEqual(WatchWorkoutMapping.activityType(for: item.name), .functionalStrengthTraining,
                              "«\(item.name)» не распознана и ушла в тип по умолчанию")
        }
    }

    func testUnknownNameFallsBackToFunctionalStrength() {
        XCTAssertEqual(WatchWorkoutMapping.activityType(for: "Неизвестное занятие"), .functionalStrengthTraining)
    }

    func testOutdoorWorkoutsUseGPS() {
        let outdoor = ["Бег на улице", "Спортивная ходьба", "Хайкинг и горы", "Велоспорт", "Открытая вода", "Футбол", "Лыжи и сноуборд"]
        for name in outdoor {
            XCTAssertEqual(WatchWorkoutMapping.locationType(for: name), .outdoor, "«\(name)» должна идти на улице (GPS-маршрут и дистанция)")
        }
    }

    func testIndoorWorkoutsDoNotUseGPS() {
        let indoor = ["Беговая дорожка", "Велотренажер", "Плавание в бассейне", "Гребной тренажер", "Эллипс", "Степпер",
                      "Силовая тренировка", "Йога", "Пилатес", "Скакалка", "Бокс / Кикбоксинг"]
        for name in indoor {
            XCTAssertEqual(WatchWorkoutMapping.locationType(for: name), .indoor, "«\(name)» должна идти в помещении")
        }
    }

    func testSwimmingLocation() {
        XCTAssertEqual(WatchWorkoutMapping.swimmingLocation(for: "Плавание в бассейне"), .pool)
        XCTAssertEqual(WatchWorkoutMapping.swimmingLocation(for: "Открытая вода"), .openWater)
        XCTAssertNil(WatchWorkoutMapping.swimmingLocation(for: "Бег на улице"))
        XCTAssertEqual(WatchWorkoutMapping.defaultPoolLengthMeters, 25)
    }
}

// MARK: - Счёт повторов по акселерометру

final class WatchRepCounterTests: XCTestCase {

    /// Магнитуда ускорения в g: 1 g покоя + синус вертикального ускорения кисти.
    private func repSignal(amplitude: Double, repsPerSecond: Double, reps: Int, sampleRate: Double = 10) -> [Double] {
        let count = Int(Double(reps) / repsPerSecond * sampleRate) + Int(sampleRate)
        return (0..<count).map { 1.0 + amplitude * sin(2 * Double.pi * repsPerSecond * Double($0) / sampleRate) }
    }

    private func repsCounted(in signal: [Double], sampleRate: Double = 10) -> Int {
        var counter = WatchRepCounter()
        var total = 0
        for (index, magnitude) in signal.enumerated() {
            if counter.process(magnitude: magnitude, at: 1_000_000 + Double(index) / sampleRate) {
                total += 1
            }
        }
        return total
    }

    func testStrongRepsAreCountedExactly() {
        // 20 повторов раз в 2 секунды: от резких (скакалка, бёрпи) до умеренных (приседания)
        for amplitude in [0.9, 0.6, 0.45, 0.35, 0.30, 0.25] {
            XCTAssertEqual(repsCounted(in: repSignal(amplitude: amplitude, repsPerSecond: 0.5, reps: 20)), 20,
                           "Размах \(amplitude) g должен считаться точно")
        }
    }

    func testGentleRepsAreNotCounted() {
        // Известное ограничение: спокойные упражнения с контролируемым темпом дают размах ниже порога
        // (≈0,23 g), и алгоритм их не видит. Реальный размах на запястье можно узнать только на часах.
        for amplitude in [0.22, 0.20, 0.15] {
            XCTAssertEqual(repsCounted(in: repSignal(amplitude: amplitude, repsPerSecond: 0.5, reps: 20)), 0,
                           "Размах \(amplitude) g ниже порога: повторы не засчитываются")
        }
    }

    func testRepsFasterThanOneSecondAreUndercounted() {
        // Пауза между повторами 1 секунда: более частые повторы пропускаются.
        let counted = repsCounted(in: repSignal(amplitude: 0.9, repsPerSecond: 1.5, reps: 20))
        XCTAssertGreaterThan(counted, 0)
        XCTAssertLessThan(counted, 20, "Быстрые повторы (чаще раза в секунду) недосчитываются")
    }

    func testRestingNoiseCountsNothing() {
        var generator = SystemRandomNumberGenerator()
        let noise = (0..<600).map { _ in 1.0 + Double.random(in: -0.05...0.05, using: &generator) }
        XCTAssertEqual(repsCounted(in: noise), 0)
    }

    func testWalkingMotionCountsNothing() {
        // Ходьба: размах 0,5 g на частоте шагов 1,8 Гц сглаживается и повторами не считается
        let walking = (0..<600).map { 1.0 + 0.5 * sin(2 * Double.pi * 1.8 * Double($0) / 10) }
        XCTAssertEqual(repsCounted(in: walking), 0)
    }

    func testSingleSharpJerkIsOneRep() {
        let signal = Array(repeating: 1.0, count: 10) + Array(repeating: 2.0, count: 3) + Array(repeating: 0.3, count: 3) + Array(repeating: 1.0, count: 10)
        XCTAssertEqual(repsCounted(in: signal), 1)
    }

    func testResetClearsState() {
        var counter = WatchRepCounter()
        for _ in 0..<5 { counter.process(magnitude: 2.0, at: 1_000_000) }
        XCTAssertTrue(counter.isAboveUpper)
        counter.reset()
        XCTAssertFalse(counter.isAboveUpper)
        XCTAssertTrue(counter.history.isEmpty)
    }

    func testDebounceBlocksSecondRepWithinOneSecond() {
        var counter = WatchRepCounter()
        func jerk(at base: Double) -> Bool {
            var counted = false
            for step in 0..<5 { counter.process(magnitude: 2.0, at: base + Double(step) * 0.1) }
            for step in 0..<5 { if counter.process(magnitude: 0.3, at: base + 0.5 + Double(step) * 0.1) { counted = true } }
            return counted
        }
        XCTAssertTrue(jerk(at: 1_000_000))
        XCTAssertFalse(jerk(at: 1_000_000.6), "Второй повтор через 0,6 с после первого отсекается паузой")
    }
}

// MARK: - Калории без датчиков

final class WatchCalorieEstimatorTests: XCTestCase {

    func testThirtyMinuteRunAtSeventyFiveKilograms() {
        // МЕТ 9,8 × 3,5 × 75 / 200 = 12,86 ккал в минуту → 385,9 за 30 минут
        XCTAssertEqual(WatchCalorieEstimator.kcal(met: 9.8, weightKg: 75, seconds: 30 * 60), 385.875, accuracy: 0.01)
    }

    func testScalesLinearlyWithWeightAndTime() {
        let base = WatchCalorieEstimator.kcal(met: 6, weightKg: 60, seconds: 600)
        XCTAssertEqual(WatchCalorieEstimator.kcal(met: 6, weightKg: 120, seconds: 600), base * 2, accuracy: 0.001)
        XCTAssertEqual(WatchCalorieEstimator.kcal(met: 6, weightKg: 60, seconds: 1200), base * 2, accuracy: 0.001)
    }

    func testPerSecondSumsToPerMinute() {
        var total = 0.0
        for _ in 0..<60 { total += WatchCalorieEstimator.kcal(met: 8, weightKg: 75, seconds: 1) }
        XCTAssertEqual(total, WatchCalorieEstimator.kcal(met: 8, weightKg: 75, seconds: 60), accuracy: 1e-9)
    }

    func testInvalidInputsGiveZero() {
        XCTAssertEqual(WatchCalorieEstimator.kcal(met: 0, weightKg: 75, seconds: 60), 0)
        XCTAssertEqual(WatchCalorieEstimator.kcal(met: 8, weightKg: 0, seconds: 60), 0)
        XCTAssertEqual(WatchCalorieEstimator.kcal(met: 8, weightKg: 75, seconds: -5), 0)
    }

    func testDefaultWeightIsDocumentedAssumption() {
        // Пока профиль с телефона не доступен на часах, берётся 75 кг: для других людей запасная оценка неточна
        XCTAssertEqual(WatchCalorieEstimator.defaultWeightKg, 75)
    }
}
