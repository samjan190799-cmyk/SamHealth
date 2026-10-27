import Foundation

// MARK: - План умных напоминаний (чистая логика)
//
// Без UserNotifications и без UIKit: план считается функцией от настроек и текущего времени,
// поэтому проверяется юнит-тестами (Tests/NotificationPlanner). Менеджер уведомлений только
// превращает этот план в запросы iOS.
//
// Что было не так до этого:
//  • каждое планирование начиналось с removeAllPendingNotificationRequests() и стирало
//    напоминания привычек, которые при запуске уже не пересоздавались;
//  • все напоминания были разовыми на 7 дней вперёд и обновлялись только при открытии
//    приложения: через неделю без запуска они кончались;
//  • при каждом запуске настройки пользователя заменялись значениями по умолчанию.
//
// Теперь напоминания о еде и воде — ежедневные повторяющиеся (iOS доставляет их сама, приложение
// не нужно открывать). Скользящее окно из разовых запросов остаётся только для напоминаний об
// активности: их нужно уметь отменять на сегодня, если шаги уже набраны.

public enum SmartReminderKind: String, CaseIterable, Equatable {
    case meal
    case water
    case activity
}

public struct SmartReminderSettings: Equatable {
    public var mealEnabled: Bool
    public var waterEnabled: Bool
    public var activityEnabled: Bool
    public var startHour: Int
    public var endHour: Int
    public var frequencyPerDay: Int

    public init(
        mealEnabled: Bool = true,
        waterEnabled: Bool = true,
        activityEnabled: Bool = true,
        startHour: Int = 9,
        endHour: Int = 21,
        frequencyPerDay: Int = 5
    ) {
        self.mealEnabled = mealEnabled
        self.waterEnabled = waterEnabled
        self.activityEnabled = activityEnabled
        self.startHour = startHour
        self.endHour = endHour
        self.frequencyPerDay = frequencyPerDay
    }

    public var enabledKinds: [SmartReminderKind] {
        var kinds: [SmartReminderKind] = []
        if mealEnabled { kinds.append(.meal) }
        if waterEnabled { kinds.append(.water) }
        if activityEnabled { kinds.append(.activity) }
        return kinds
    }
}

public struct ReminderSlot: Equatable {
    public var hour: Int
    public var minute: Int
    public var kind: SmartReminderKind
    public var index: Int
}

public struct PlannedReminder: Equatable {
    public enum Schedule: Equatable {
        /// Каждый день в это время. iOS повторяет сама, приложение не нужно открывать.
        case daily(hour: Int, minute: Int)
        /// Один раз в конкретный день.
        case once(year: Int, month: Int, day: Int, hour: Int, minute: Int)
    }

    public var identifier: String
    public var kind: SmartReminderKind
    public var schedule: Schedule
}

public enum SmartReminderPlanner {
    /// Ежедневные повторяющиеся напоминания (еда, вода).
    public static let dailyPrefix = "forma_smart_daily_"
    /// Разовые напоминания по дням: старые версии ставили так всё; теперь — только активность.
    public static let oneOffPrefix = "forma_smart_reminder_"

    /// Скользящее окно для напоминаний об активности.
    public static let activityWindowDays = 7
    /// Потолок разовых запросов: у iOS лимит 64 ожидающих уведомления на приложение,
    /// остальное (привычки, AI-итоги) тоже должно поместиться.
    public static let maxOneOffRequests = 21

    /// Управляется ли этот идентификатор планировщиком (только такие можно удалять при перепланировании).
    public static func isManagedIdentifier(_ id: String) -> Bool {
        id.hasPrefix(dailyPrefix) || id.hasPrefix(oneOffPrefix)
    }

    public static func slots(for settings: SmartReminderSettings) -> [ReminderSlot] {
        let kinds = settings.enabledKinds
        guard !kinds.isEmpty else { return [] }

        let safeStart = max(7, min(20, settings.startHour))
        let safeEnd = max(safeStart + 2, min(23, settings.endHour))
        let count = max(2, min(8, settings.frequencyPerDay))
        let interval = Double(safeEnd - safeStart) / Double(count)

        return (0..<count).map { i in
            ReminderSlot(
                hour: safeStart + Int(Double(i) * interval),
                minute: (i * 15) % 60,
                kind: kinds[i % kinds.count],
                index: i
            )
        }
    }

    public static func plan(
        settings: SmartReminderSettings,
        now: Date,
        calendar: Calendar = .current
    ) -> [PlannedReminder] {
        var result: [PlannedReminder] = []
        var oneOffCount = 0

        let slots = slots(for: settings)

        // 1. Еда и вода — ежедневно, идентификатор не зависит от даты
        for slot in slots where slot.kind != .activity {
            result.append(PlannedReminder(
                identifier: "\(dailyPrefix)\(slot.kind.rawValue)_\(slot.index)",
                kind: slot.kind,
                schedule: .daily(hour: slot.hour, minute: slot.minute)
            ))
        }

        // 2. Активность — скользящее окно разовых запросов, ближайшие дни в приоритете
        let activitySlots = slots.filter { $0.kind == .activity }
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)

        outer: for dayOffset in 0..<activityWindowDays {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            let year = calendar.component(.year, from: day)
            let month = calendar.component(.month, from: day)
            let dayOfMonth = calendar.component(.day, from: day)

            for slot in activitySlots {
                if dayOffset == 0 {
                    let passed = slot.hour < currentHour || (slot.hour == currentHour && slot.minute <= currentMinute)
                    if passed { continue }
                }
                if oneOffCount >= maxOneOffRequests { break outer }

                let dateString = String(format: "%04d%02d%02d", year, month, dayOfMonth)
                result.append(PlannedReminder(
                    identifier: "\(oneOffPrefix)\(dateString)_\(slot.kind.rawValue)_\(slot.index)",
                    kind: .activity,
                    schedule: .once(year: year, month: month, day: dayOfMonth, hour: slot.hour, minute: slot.minute)
                ))
                oneOffCount += 1
            }
        }

        return result
    }
}
