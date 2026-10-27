import XCTest
@testable import EnergyModelKit

final class EnergyModelTests: XCTestCase {

    // MARK: Помощники

    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func utcDate(_ hour: Int, _ minute: Int = 0, _ second: Int = 0) -> Date {
        utc.date(from: DateComponents(year: 2026, month: 10, day: 6, hour: hour, minute: minute, second: second))!
    }

    private let man = EnergyProfile(weightKg: 75, heightCm: 175, ageYears: 25, sex: .male)

    // MARK: Формула Миффлина — Сан-Жеора

    func testMifflinMale() {
        let profile = EnergyProfile(weightKg: 75, heightCm: 175, ageYears: 30, sex: .male)
        // 10·75 + 6,25·175 − 5·30 + 5 = 750 + 1093,75 − 150 + 5
        XCTAssertEqual(EnergyModel.restingEnergyPerDay(profile), 1698.75, accuracy: 0.001)
    }

    func testMifflinFemale() {
        let profile = EnergyProfile(weightKg: 60, heightCm: 165, ageYears: 30, sex: .female)
        // 10·60 + 6,25·165 − 5·30 − 161 = 600 + 1031,25 − 150 − 161
        XCTAssertEqual(EnergyModel.restingEnergyPerDay(profile), 1320.25, accuracy: 0.001)
    }

    func testSexParsingMatchesStoredSettingsValues() {
        XCTAssertEqual(BiologicalSex(storedValue: "Мужской"), .male)
        XCTAssertEqual(BiologicalSex(storedValue: "Женский"), .female)
        XCTAssertEqual(BiologicalSex(storedValue: "male"), .male)
        XCTAssertEqual(BiologicalSex(storedValue: "Male"), .male)
        XCTAssertEqual(BiologicalSex(storedValue: "female"), .female)
        XCTAssertEqual(BiologicalSex(storedValue: ""), .female)
    }

    func testWomanNeverMatchedAsMan() {
        // «Женский» не должен содержать «муж»: регрессия на поиск подстроки
        XCTAssertEqual(BiologicalSex(storedValue: "женский"), .female)
    }

    // MARK: Границы профиля

    func testProfileClampsOutOfRangeValues() {
        let tiny = EnergyProfile(weightKg: 10, heightCm: 50, ageYears: 5, sex: .male)
        XCTAssertEqual(tiny.weightKg, 30)
        XCTAssertEqual(tiny.heightCm, 100)
        XCTAssertEqual(tiny.ageYears, 14)

        let huge = EnergyProfile(weightKg: 500, heightCm: 400, ageYears: 200, sex: .male)
        XCTAssertEqual(huge.weightKg, 250)
        XCTAssertEqual(huge.heightCm, 230)
        XCTAssertEqual(huge.ageYears, 100)
    }

    func testProfileReplacesNonFiniteValuesWithTypicalOnes() {
        let broken = EnergyProfile(weightKg: .nan, heightCm: .infinity, ageYears: -.infinity, sex: .female)
        XCTAssertEqual(broken.weightKg, EnergyProfile.typicalWeightKg)
        XCTAssertEqual(broken.heightCm, EnergyProfile.typicalHeightCm)
        XCTAssertEqual(broken.ageYears, EnergyProfile.typicalAgeYears)
        XCTAssertTrue(EnergyModel.restingEnergyPerDay(broken).isFinite)
    }

    // MARK: Доля суток

    func testDayFractionAtMidnightAndNoon() {
        XCTAssertEqual(EnergyModel.dayFraction(at: utcDate(0), calendar: utc), 0, accuracy: 1e-9)
        XCTAssertEqual(EnergyModel.dayFraction(at: utcDate(12), calendar: utc), 0.5, accuracy: 1e-9)
        XCTAssertEqual(EnergyModel.dayFraction(at: utcDate(18), calendar: utc), 0.75, accuracy: 1e-9)
    }

    func testDayFractionJustBeforeNextMidnightApproachesOne() {
        let fraction = EnergyModel.dayFraction(at: utcDate(23, 59, 59), calendar: utc)
        XCTAssertGreaterThan(fraction, 0.9999)
        XCTAssertLessThan(fraction, 1.0)
    }

    func testDayFractionOnSpringForwardDayUsesRealDayLength() throws {
        let newYork = try XCTUnwrap(TimeZone(identifier: "America/New_York"), "нет базы часовых поясов")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = newYork
        // 8 марта 2026: в 2:00 часы переводятся на 3:00, в сутках 23 часа.
        let noon = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12)))
        // С полуночи до 12:00 по часам прошло 11 реальных часов из 23.
        XCTAssertEqual(EnergyModel.dayFraction(at: noon, calendar: calendar), 11.0 / 23.0, accuracy: 1e-9)
    }

    func testDayFractionOnFallBackDayUsesRealDayLength() throws {
        let newYork = try XCTUnwrap(TimeZone(identifier: "America/New_York"), "нет базы часовых поясов")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = newYork
        // 1 ноября 2026: в 2:00 часы переводятся на 1:00, в сутках 25 часов.
        let noon = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 12)))
        // С полуночи до 12:00 по часам прошло 13 реальных часов из 25.
        XCTAssertEqual(EnergyModel.dayFraction(at: noon, calendar: calendar), 13.0 / 25.0, accuracy: 1e-9)
    }

    // MARK: Базовый обмен «на сейчас»

    func testRestingEnergySoFarIsProportionalToElapsedDay() {
        let perDay = EnergyModel.restingEnergyPerDay(man)
        XCTAssertEqual(EnergyModel.restingEnergySoFar(man, at: utcDate(0), calendar: utc), 0, accuracy: 1e-9)
        XCTAssertEqual(EnergyModel.restingEnergySoFar(man, at: utcDate(12), calendar: utc), perDay / 2, accuracy: 1e-6)
        XCTAssertEqual(EnergyModel.restingEnergySoFar(man, at: utcDate(23, 59, 59), calendar: utc), perDay, accuracy: perDay * 0.0001)
    }

    func testRestingEnergySoFarNeverExceedsDailyValue() {
        let perDay = EnergyModel.restingEnergyPerDay(man)
        for hour in 0..<24 {
            XCTAssertLessThanOrEqual(EnergyModel.restingEnergySoFar(man, at: utcDate(hour, 59, 59), calendar: utc), perDay)
        }
    }

    // MARK: Регрессия: утренний «дефицит»

    func testMorningBalanceIsNotInflatedByFullDayRestingEnergy() {
        // Сценарий со скриншота: 11:28, съедено 173 ккал, активных 867 ккал.
        // Раньше базовый обмен брали за весь день: дефицит выходил −2 060 и −2 344.
        let now = utcDate(11, 28)
        let resting = EnergyModel.restingEnergySoFar(man, at: now, calendar: utc)
        let burned = resting + 867
        let balance = EnergyModel.balance(consumed: 173, burned: burned)

        // 1723,75 · (11 ч 28 мин / 24 ч) + 867 = 1690,6; сальдо 173 − 1690,6 = −1517,6
        XCTAssertEqual(balance, -1517.6, accuracy: 0.5)
        XCTAssertGreaterThan(balance, -2060)
    }

    func testBalanceSignConvention() {
        XCTAssertLessThan(EnergyModel.balance(consumed: 1500, burned: 2000), 0)   // дефицит
        XCTAssertGreaterThan(EnergyModel.balance(consumed: 2500, burned: 2000), 0) // профицит
        XCTAssertEqual(EnergyModel.balance(consumed: 2000, burned: 2000), 0)
    }

    func testFatChangeFromBalance() {
        XCTAssertEqual(EnergyModel.fatChangeGrams(forBalance: -7_700), -1_000, accuracy: 1e-9)
        XCTAssertEqual(EnergyModel.fatChangeGrams(forBalance: 770), 100, accuracy: 1e-9)
        XCTAssertEqual(EnergyModel.fatChangeGrams(forBalance: 0), 0)
    }

    // MARK: Оценка по шагам

    func testStepEnergyScalesWithWeight() {
        XCTAssertEqual(EnergyModel.stepEnergyEstimate(steps: 10_000, weightKg: 70), 420, accuracy: 1e-9)
        XCTAssertEqual(EnergyModel.stepEnergyEstimate(steps: 15_000, weightKg: 100), 900, accuracy: 1e-9)
    }

    func testStepEnergyHandlesBadInput() {
        XCTAssertEqual(EnergyModel.stepEnergyEstimate(steps: -50, weightKg: 70), 0)
        XCTAssertEqual(EnergyModel.stepEnergyEstimate(steps: 0, weightKg: 70), 0)
        // Нечисловой вес заменяется типичным 75 кг: 1000 · 0,042 · 75/70 = 45
        XCTAssertEqual(EnergyModel.stepEnergyEstimate(steps: 1_000, weightKg: .nan), 45, accuracy: 1e-9)
        // Вес ограничен 30...250 кг
        XCTAssertEqual(EnergyModel.stepEnergyEstimate(steps: 1_000, weightKg: 5), 1_000 * 0.042 * (30.0 / 70.0), accuracy: 1e-9)
    }

    // MARK: Норма калорий

    func testDefaultGoalIsPersonalNotOneNumberForEveryone() {
        // Мужчина 75 кг, 175 см, 25 лет: 1723,75 · 1,375 = 2370,2 → 2350
        XCTAssertEqual(EnergyModel.defaultDailyGoal(for: man), 2350)
        // Женщина 55 кг, 160 см, 40 лет: 1189 · 1,375 = 1634,9 → 1650
        let woman = EnergyProfile(weightKg: 55, heightCm: 160, ageYears: 40, sex: .female)
        XCTAssertEqual(EnergyModel.defaultDailyGoal(for: woman), 1650)
        XCTAssertNotEqual(EnergyModel.defaultDailyGoal(for: man), EnergyModel.defaultDailyGoal(for: woman))
    }

    func testDefaultGoalIsRoundedToFifty() {
        for weight in stride(from: 45.0, through: 120.0, by: 7.0) {
            let goal = EnergyModel.defaultDailyGoal(for: EnergyProfile(weightKg: weight, heightCm: 170, ageYears: 33, sex: .male))
            XCTAssertEqual(goal % 50, 0, "вес \(weight)")
        }
    }

    func testDefaultGoalIsClampedToSaneBounds() {
        let tiny = EnergyProfile(weightKg: 30, heightCm: 100, ageYears: 100, sex: .female)
        XCTAssertEqual(EnergyModel.defaultDailyGoal(for: tiny), 1_200)
        let huge = EnergyProfile(weightKg: 250, heightCm: 230, ageYears: 14, sex: .male)
        XCTAssertEqual(EnergyModel.defaultDailyGoal(for: huge), 4_500)
    }

    func testResolveGoalPrefersStoredValueInsideRange() {
        XCTAssertEqual(EnergyModel.resolveDailyGoal(stored: 2_000, profile: man), 2_000)
        XCTAssertEqual(EnergyModel.resolveDailyGoal(stored: 1_000, profile: man), 1_000)
        XCTAssertEqual(EnergyModel.resolveDailyGoal(stored: 6_000, profile: man), 6_000)
    }

    func testResolveGoalFallsBackWhenStoredValueMissingOrAbsurd() {
        let fallback = EnergyModel.defaultDailyGoal(for: man)
        XCTAssertEqual(EnergyModel.resolveDailyGoal(stored: 0, profile: man), fallback)      // не задано
        XCTAssertEqual(EnergyModel.resolveDailyGoal(stored: 500, profile: man), fallback)    // слишком мало
        XCTAssertEqual(EnergyModel.resolveDailyGoal(stored: 7_000, profile: man), fallback)  // слишком много
        XCTAssertEqual(EnergyModel.resolveDailyGoal(stored: -1, profile: man), fallback)
    }

    // MARK: Цели по БЖУ

    func testMacroGoalsReproduceReferenceDietAtReferenceCalories() {
        let goals = EnergyModel.macroGoals(forCalorieGoal: 2_200)
        XCTAssertEqual(goals.protein, 140)
        XCTAssertEqual(goals.fat, 70)
        XCTAssertEqual(goals.carbs, 240)
    }

    func testMacroGoalsScaleWithCalorieGoalAndRoundToFive() {
        let low = EnergyModel.macroGoals(forCalorieGoal: 1_650)   // ×0,75
        XCTAssertEqual(low.protein, 105)
        XCTAssertEqual(low.fat, 55)    // 52,5 — ровно посередине: округляется от нуля, до 55
        XCTAssertEqual(low.carbs, 180)
        for goal in stride(from: 1_200, through: 4_500, by: 150) {
            let m = EnergyModel.macroGoals(forCalorieGoal: goal)
            XCTAssertEqual(m.protein % 5, 0, "белки при \(goal)")
            XCTAssertEqual(m.fat % 5, 0, "жиры при \(goal)")
            XCTAssertEqual(m.carbs % 5, 0, "углеводы при \(goal)")
        }
    }

    func testMacroGoalsAreMonotonicAndClampedForAbsurdInput() {
        let small = EnergyModel.macroGoals(forCalorieGoal: 1_500)
        let big = EnergyModel.macroGoals(forCalorieGoal: 3_000)
        XCTAssertLessThan(small.protein, big.protein)
        XCTAssertLessThan(small.fat, big.fat)
        XCTAssertLessThan(small.carbs, big.carbs)
        // Нелепые значения не дают ни нулей, ни взрывных целей
        XCTAssertEqual(EnergyModel.macroGoals(forCalorieGoal: 0).protein, EnergyModel.macroGoals(forCalorieGoal: 1_200).protein)
        XCTAssertEqual(EnergyModel.macroGoals(forCalorieGoal: 100_000).carbs, EnergyModel.macroGoals(forCalorieGoal: 6_000).carbs)
    }
}
