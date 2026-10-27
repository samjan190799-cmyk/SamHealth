import XCTest
@testable import WeeklySummaryKit

// MARK: - Вспомогательное

private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

/// Воскресенье, 19:00 — время, когда приходит уведомление с итогами
private let now = date(2026, 10, 25, 19)

private func day(ago: Int, steps: Int, calories: Double = 0) -> WeeklyDay {
    WeeklyDay(date: calendar.date(byAdding: .day, value: -ago, to: now)!, steps: steps, activeCalories: calories)
}

private func workout(ago: Int, minutes: Int, calories: Double = 200) -> WeeklyWorkout {
    WeeklyWorkout(date: calendar.date(byAdding: .day, value: -ago, to: now)!, durationMinutes: minutes, calories: calories)
}

private func build(days: [WeeklyDay] = [], workouts: [WeeklyWorkout] = [], goal: Int = 8_000,
                   habitCompletions: Int = 0, habitSlots: Int = 0, at moment: Date = now) -> WeeklySummary {
    WeeklySummaryBuilder.make(now: moment, calendar: calendar, days: days, workouts: workouts, stepGoal: goal,
                              habitCompletions: habitCompletions, habitSlots: habitSlots)
}

// MARK: - Шаги

final class WeeklyStepsTests: XCTestCase {

    func testTotalAndAverageOverSevenDays() {
        let summary = build(days: (0..<7).map { day(ago: $0, steps: 10_000) })
        XCTAssertEqual(summary.totalSteps, 70_000)
        XCTAssertEqual(summary.averageSteps, 10_000)
    }

    func testAverageDividesBySevenNotByRecordedDays() {
        // Два записанных дня по 7 000: «в среднем 7 000» было бы неправдой, пять дней шагов не записано
        let summary = build(days: [day(ago: 0, steps: 7_000), day(ago: 1, steps: 7_000)])
        XCTAssertEqual(summary.totalSteps, 14_000)
        XCTAssertEqual(summary.averageSteps, 2_000)
    }

    func testWindowIncludesSixDaysAgoAndExcludesSeven() {
        let summary = build(days: [day(ago: 6, steps: 5_000), day(ago: 7, steps: 9_000)])
        XCTAssertEqual(summary.totalSteps, 5_000, "Шесть дней назад — седьмой день окна")
        XCTAssertEqual(summary.stepsChangePercent, -44, "Восемь дней назад — уже предыдущая неделя: (5 000 − 9 000) / 9 000")
    }

    func testFutureDatesAreIgnored() {
        // Сдвиг часового пояса или часы, пошедшие вперёд, не должны раздувать итоги
        let summary = build(days: [day(ago: -1, steps: 20_000), day(ago: 0, steps: 3_000)])
        XCTAssertEqual(summary.totalSteps, 3_000)
    }

    func testDuplicateRecordsForOneDayAreNotSummed() {
        let summary = build(days: [day(ago: 2, steps: 5_000), day(ago: 2, steps: 8_000)])
        XCTAssertEqual(summary.totalSteps, 8_000)
    }

    func testRecordedLateInTheEveningBelongsToItsOwnDay() {
        // Запись в 23:59 вчера, а «сейчас» уже 00:01: вчерашний день остаётся вчерашним
        let justAfterMidnight = date(2026, 10, 26, 0, 1)
        let lateYesterday = WeeklyDay(date: date(2026, 10, 25, 23, 59), steps: 4_000, activeCalories: 0)
        let weekAgo = WeeklyDay(date: date(2026, 10, 19, 12), steps: 6_000, activeCalories: 0)
        let summary = build(days: [lateYesterday, weekAgo], at: justAfterMidnight)
        XCTAssertEqual(summary.totalSteps, 4_000, "Вчерашние 23:59 — в окне; 19 октября (7 дней назад) — уже предыдущая неделя")
        XCTAssertEqual(summary.stepsChangePercent, -33, "(4 000 − 6 000) / 6 000")
    }
}

// MARK: - Цель и лучший день

final class WeeklyGoalTests: XCTestCase {

    func testGoalDaysCountOnlyReachedGoal() {
        let summary = build(days: [day(ago: 0, steps: 9_000), day(ago: 1, steps: 8_000), day(ago: 2, steps: 7_999)], goal: 8_000)
        XCTAssertEqual(summary.goalDays, 2, "Ровно цель — засчитывается, на шаг меньше — нет")
    }

    func testNoGoalMeansNoGoalDays() {
        XCTAssertEqual(build(days: [day(ago: 0, steps: 50_000)], goal: 0).goalDays, 0)
    }

    func testBestDayIsTheMostStepsAndTiesGoToTheNewerDay() {
        let summary = build(days: [day(ago: 3, steps: 12_000), day(ago: 1, steps: 12_000), day(ago: 2, steps: 5_000)])
        XCTAssertEqual(summary.bestDaySteps, 12_000)
        XCTAssertEqual(summary.bestDayDate, calendar.startOfDay(for: day(ago: 1, steps: 0).date))
    }
}

// MARK: - Сравнение с прошлой неделей

final class WeeklyTrendTests: XCTestCase {

    func testGrowthIsPositivePercent() {
        let summary = build(days: [day(ago: 0, steps: 66_000), day(ago: 7, steps: 60_000)])
        XCTAssertEqual(summary.stepsChangePercent, 10)
    }

    func testDeclineIsNegativePercent() {
        let summary = build(days: [day(ago: 0, steps: 30_000), day(ago: 8, steps: 60_000)])
        XCTAssertEqual(summary.stepsChangePercent, -50)
    }

    func testNoPreviousWeekMeansNoComparison() {
        XCTAssertNil(build(days: [day(ago: 0, steps: 30_000)]).stepsChangePercent)
    }

    func testChangeIsCapped() {
        let summary = build(days: [day(ago: 0, steps: 100_000), day(ago: 7, steps: 100)])
        XCTAssertEqual(summary.stepsChangePercent, WeeklySummaryBuilder.maxChangePercent)
    }

    func testEmptyCurrentWeekAgainstBusyPreviousIsMinusHundred() {
        XCTAssertEqual(build(days: [day(ago: 9, steps: 40_000)]).stepsChangePercent, -100)
    }
}

// MARK: - Тренировки, калории, привычки

final class WeeklyActivityTests: XCTestCase {

    func testOnlyWorkoutsInsideTheWindowAreCounted() {
        let summary = build(workouts: [
            workout(ago: 0, minutes: 30),
            workout(ago: 6, minutes: 45),
            workout(ago: 7, minutes: 60),
            workout(ago: -1, minutes: 90)
        ])
        XCTAssertEqual(summary.workoutCount, 2)
        XCTAssertEqual(summary.workoutMinutes, 75)
    }

    func testActiveCaloriesAreSummedAndRounded() {
        let summary = build(days: [day(ago: 0, steps: 1, calories: 300.4), day(ago: 1, steps: 1, calories: 200.4), day(ago: 9, steps: 1, calories: 999)])
        XCTAssertEqual(summary.activeCalories, 501)
    }

    func testHabitsPercentIsShareOfPossibleCheckmarks() {
        XCTAssertEqual(build(habitCompletions: 7, habitSlots: 14).habitsPercent, 50)
        XCTAssertEqual(build(habitCompletions: 14, habitSlots: 14).habitsPercent, 100)
    }

    func testHabitsPercentNeverExceedsHundred() {
        XCTAssertEqual(build(habitCompletions: 30, habitSlots: 14).habitsPercent, 100)
    }

    func testNoHabitsMeansNoPercent() {
        XCTAssertNil(build(habitCompletions: 0, habitSlots: 0).habitsPercent)
    }
}

// MARK: - Пустая неделя

final class WeeklyEmptyTests: XCTestCase {

    func testNothingRecordedIsNotASummary() {
        let summary = build()
        XCTAssertEqual(summary, WeeklySummary())
        XCTAssertFalse(summary.hasData)
    }

    func testWorkoutAloneIsEnough() {
        XCTAssertTrue(build(workouts: [workout(ago: 1, minutes: 20)]).hasData)
    }

    func testHabitsAloneAreEnoughOnlyIfSomethingWasDone() {
        XCTAssertTrue(build(habitCompletions: 3, habitSlots: 14).hasData)
        XCTAssertFalse(build(habitCompletions: 0, habitSlots: 14).hasData, "Привычки есть, но ни одной отметки — итогов нет")
    }
}

// MARK: - Формат чисел

final class WeeklyFormatTests: XCTestCase {

    func testThousandsAreSeparatedByNoBreakSpace() {
        XCTAssertEqual(WeeklySummaryFormat.grouped(0), "0")
        XCTAssertEqual(WeeklySummaryFormat.grouped(999), "999")
        XCTAssertEqual(WeeklySummaryFormat.grouped(1_000), "1\u{00A0}000")
        XCTAssertEqual(WeeklySummaryFormat.grouped(63_400), "63\u{00A0}400")
        XCTAssertEqual(WeeklySummaryFormat.grouped(1_234_567), "1\u{00A0}234\u{00A0}567")
    }

    func testNegativeNumbersKeepTheSign() {
        XCTAssertEqual(WeeklySummaryFormat.grouped(-1_500), "-1\u{00A0}500")
    }
}
