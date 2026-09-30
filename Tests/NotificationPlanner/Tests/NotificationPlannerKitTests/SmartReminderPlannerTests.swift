import XCTest
@testable import NotificationPlannerKit

final class SmartReminderPlannerTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    private let defaults = SmartReminderSettings()   // 9–21, 5 раз в день, всё включено

    // MARK: слоты

    func testDefaultSlots() {
        let slots = SmartReminderPlanner.slots(for: defaults)
        XCTAssertEqual(slots.map { $0.hour }, [9, 11, 13, 16, 18])
        XCTAssertEqual(slots.map { $0.minute }, [0, 15, 30, 45, 0])
        XCTAssertEqual(slots.map { $0.kind }, [.meal, .water, .activity, .meal, .water])
    }

    func testSettingsAreClamped() {
        let extreme = SmartReminderSettings(startHour: 3, endHour: 30, frequencyPerDay: 100)
        let slots = SmartReminderPlanner.slots(for: extreme)
        XCTAssertEqual(slots.count, 8)
        XCTAssertGreaterThanOrEqual(slots.first!.hour, 7)
        XCTAssertLessThanOrEqual(slots.last!.hour, 23)

        XCTAssertEqual(SmartReminderPlanner.slots(for: SmartReminderSettings(frequencyPerDay: 0)).count, 2)
    }

    func testNothingEnabledMeansNothingPlanned() {
        let off = SmartReminderSettings(mealEnabled: false, waterEnabled: false, activityEnabled: false)
        XCTAssertTrue(SmartReminderPlanner.slots(for: off).isEmpty)
        XCTAssertTrue(SmartReminderPlanner.plan(settings: off, now: date(2026, 9, 30, 12), calendar: calendar).isEmpty)
    }

    func testDisabledKindsAreExcluded() {
        let waterOnly = SmartReminderSettings(mealEnabled: false, waterEnabled: true, activityEnabled: false)
        let plan = SmartReminderPlanner.plan(settings: waterOnly, now: date(2026, 9, 30, 12), calendar: calendar)
        XCTAssertFalse(plan.isEmpty)
        XCTAssertTrue(plan.allSatisfy { $0.kind == .water })
    }

    // MARK: главное исправление — еда и вода не зависят от открытия приложения

    func testMealAndWaterAreDailyRepeatingWithDateIndependentIds() {
        // Регрессия: раньше это были разовые запросы на 7 дней и кончались, если приложение не открывали.
        let monday = SmartReminderPlanner.plan(settings: defaults, now: date(2026, 9, 28, 8), calendar: calendar)
        let friday = SmartReminderPlanner.plan(settings: defaults, now: date(2026, 10, 2, 20), calendar: calendar)

        func daily(_ plan: [PlannedReminder]) -> [PlannedReminder] {
            plan.filter { $0.kind != .activity }
        }
        XCTAssertEqual(daily(monday), daily(friday), "план еды и воды не должен зависеть от дня запуска")
        XCTAssertEqual(daily(monday).count, 4)   // meal, water, meal, water
        for item in daily(monday) {
            guard case .daily = item.schedule else { return XCTFail("ожидалось ежедневное повторение") }
            XCTAssertTrue(item.identifier.hasPrefix(SmartReminderPlanner.dailyPrefix))
            XCTAssertFalse(item.identifier.contains("2026"), "в идентификаторе не должно быть даты")
        }
    }

    func testActivityIsARollingWindowOfOneOffRequests() {
        let plan = SmartReminderPlanner.plan(settings: defaults, now: date(2026, 9, 30, 12), calendar: calendar)
        let activity = plan.filter { $0.kind == .activity }
        XCTAssertEqual(activity.count, SmartReminderPlanner.activityWindowDays)   // один слот × 7 дней

        guard case let .once(y, m, d, h, min) = activity[0].schedule else { return XCTFail() }
        XCTAssertEqual([y, m, d, h, min], [2026, 9, 30, 13, 30])
        XCTAssertEqual(activity[0].identifier, "forma_smart_reminder_20260930_activity_2")
    }

    func testPastSlotsTodayAreSkipped() {
        let plan = SmartReminderPlanner.plan(settings: defaults, now: date(2026, 9, 30, 14), calendar: calendar)
        let activity = plan.filter { $0.kind == .activity }
        XCTAssertEqual(activity.count, SmartReminderPlanner.activityWindowDays - 1)   // 13:30 сегодня уже прошло
        guard case let .once(_, _, d, _, _) = activity[0].schedule else { return XCTFail() }
        XCTAssertEqual(d, 1)   // ближайшее — завтра, 1 октября
    }

    func testTodaysActivityReminderCanBeFoundByTheCancelPrefix() {
        // evaluateActivityReminders отменяет сегодняшние по этому шаблону; идентификаторы не должны его потерять
        let plan = SmartReminderPlanner.plan(settings: defaults, now: date(2026, 9, 30, 8), calendar: calendar)
        XCTAssertTrue(plan.contains { $0.identifier.contains("forma_smart_reminder_20260930_activity") })
    }

    // MARK: бюджет уведомлений iOS (лимит 64)

    func testRequestBudgetIsRespectedForWorstCaseSettings() {
        let worst = SmartReminderSettings(mealEnabled: false, waterEnabled: false, activityEnabled: true,
                                          startHour: 7, endHour: 23, frequencyPerDay: 8)
        let plan = SmartReminderPlanner.plan(settings: worst, now: date(2026, 9, 30, 6), calendar: calendar)
        XCTAssertLessThanOrEqual(plan.count, SmartReminderPlanner.maxOneOffRequests)

        let mixed = SmartReminderSettings(frequencyPerDay: 8)
        let total = SmartReminderPlanner.plan(settings: mixed, now: date(2026, 9, 30, 6), calendar: calendar).count
        XCTAssertLessThanOrEqual(total, 8 + SmartReminderPlanner.maxOneOffRequests)
    }

    func testNearestDaysWinWhenBudgetIsTight() {
        let worst = SmartReminderSettings(mealEnabled: false, waterEnabled: false, activityEnabled: true, frequencyPerDay: 8)
        let plan = SmartReminderPlanner.plan(settings: worst, now: date(2026, 9, 30, 6), calendar: calendar)
        guard case let .once(_, _, firstDay, _, _) = plan.first!.schedule,
              case let .once(_, _, lastDay, _, _) = plan.last!.schedule else { return XCTFail() }
        XCTAssertEqual(firstDay, 30)
        XCTAssertLessThan(lastDay, 30 + SmartReminderPlanner.activityWindowDays)
    }

    // MARK: идентификаторы

    func testIdentifiersAreUnique() {
        let plan = SmartReminderPlanner.plan(settings: SmartReminderSettings(frequencyPerDay: 8),
                                             now: date(2026, 9, 30, 6), calendar: calendar)
        XCTAssertEqual(Set(plan.map { $0.identifier }).count, plan.count)
    }

    func testManagedIdentifiersDoNotTouchHabitOrAiNotifications() {
        // Регрессия: removeAllPendingNotificationRequests() стирал привычки, AI-итоги и адаптивную воду.
        XCTAssertTrue(SmartReminderPlanner.isManagedIdentifier("forma_smart_daily_water_1"))
        XCTAssertTrue(SmartReminderPlanner.isManagedIdentifier("forma_smart_reminder_20260930_activity_2"))   // и старые разовые
        XCTAssertFalse(SmartReminderPlanner.isManagedIdentifier("forma_habit_8F1A2B3C_fixed"))
        XCTAssertFalse(SmartReminderPlanner.isManagedIdentifier("forma_habit_8F1A2B3C_smart_0"))
        XCTAssertFalse(SmartReminderPlanner.isManagedIdentifier("forma_ai_deficit_midday"))
        XCTAssertFalse(SmartReminderPlanner.isManagedIdentifier("forma_ai_deficit_evening"))
        XCTAssertFalse(SmartReminderPlanner.isManagedIdentifier("forma_adaptive_hydration_reminder"))
        XCTAssertFalse(SmartReminderPlanner.isManagedIdentifier("step_goal_50_20260930"))
    }

    func testPlannedIdentifiersAreAllManaged() {
        let plan = SmartReminderPlanner.plan(settings: defaults, now: date(2026, 9, 30, 6), calendar: calendar)
        XCTAssertTrue(plan.allSatisfy { SmartReminderPlanner.isManagedIdentifier($0.identifier) })
    }
}
