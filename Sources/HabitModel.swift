import Foundation
import SwiftUI

// MARK: - Тип привычки: Формирование полезной или Отказ от вредной
public enum HabitType: String, Codable, CaseIterable, Sendable {
    case quit = "quit"       // Отказ от вредной привычки (Не грызть ногти, Без сахара)
    case build = "build"     // Формирование полезной привычки (Вода, Шаги, Витамины, Растяжка)
    
    public var localizedTitle: String {
        switch self {
        case .quit: return "Отказ от привычки"
        case .build: return "Полезная привычка"
        }
    }
}

// MARK: - Категория привычки
public enum HabitCategory: String, Codable, CaseIterable, Sendable {
    case quitting = "quitting"
    case health = "health"
    case fitness = "fitness"
    case mindfulness = "mindfulness"
    case nutrition = "nutrition"
    case recovery = "recovery"
    
    public var title: String {
        switch self {
        case .quitting: return "Отказ"
        case .health: return "Здоровье"
        case .fitness: return "Спорт"
        case .mindfulness: return "Осознанность"
        case .nutrition: return "Питание"
        case .recovery: return "Отдых"
        }
    }
    
    public var icon: String {
        switch self {
        case .quitting: return "shield.fill"
        case .health: return "cross.fill"
        case .fitness: return "figure.run"
        case .mindfulness: return "sparkles"
        case .nutrition: return "leaf.fill"
        case .recovery: return "moon.stars.fill"
        }
    }
}

// MARK: - Время суток (Таймлайн дня: Habit Stacking)
public enum HabitTimeOfDay: String, Codable, CaseIterable, Sendable, Identifiable {
    case anytime = "anytime"
    case morning = "morning"
    case afternoon = "afternoon"
    case evening = "evening"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .anytime: return "Любое время"
        case .morning: return "Утро"
        case .afternoon: return "День"
        case .evening: return "Вечер"
        }
    }
    
    public var emoji: String {
        switch self {
        case .anytime: return "⚡"
        case .morning: return "🌅"
        case .afternoon: return "☀️"
        case .evening: return "🌙"
        }
    }
    
    public var icon: String {
        switch self {
        case .anytime: return "clock"
        case .morning: return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening: return "moon.stars.fill"
        }
    }
    
    public var badgeTitle: String {
        switch self {
        case .anytime: return "⚡ В любое время"
        case .morning: return "🌅 Утренний ритуал"
        case .afternoon: return "☀️ Дневной фокус"
        case .evening: return "🌙 Вечерний детокс"
        }
    }
    
    public static var current: HabitTimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 5 && hour < 12 {
            return .morning
        } else if hour >= 12 && hour < 18 {
            return .afternoon
        } else {
            return .evening
        }
    }
}

// MARK: - Автоматическая проверка из HealthKit или ручная
public enum HabitTargetType: Codable, Sendable, Equatable {
    case manual
    case healthKitSteps(target: Int)
    case healthKitWater(targetMl: Double)
    case healthKitWorkouts(targetCount: Int)
    case healthKitSleep(targetHours: Double)
    
    private enum CodingKeys: String, CodingKey {
        case type, targetInt, targetDouble
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .manual:
            try container.encode("manual", forKey: .type)
        case .healthKitSteps(let target):
            try container.encode("steps", forKey: .type)
            try container.encode(target, forKey: .targetInt)
        case .healthKitWater(let target):
            try container.encode("water", forKey: .type)
            try container.encode(target, forKey: .targetDouble)
        case .healthKitWorkouts(let target):
            try container.encode("workouts", forKey: .type)
            try container.encode(target, forKey: .targetInt)
        case .healthKitSleep(let target):
            try container.encode("sleep", forKey: .type)
            try container.encode(target, forKey: .targetDouble)
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "steps":
            let val = try container.decodeIfPresent(Int.self, forKey: .targetInt) ?? 10000
            self = .healthKitSteps(target: val)
        case "water":
            let val = try container.decodeIfPresent(Double.self, forKey: .targetDouble) ?? 2500.0
            self = .healthKitWater(targetMl: val)
        case "workouts":
            let val = try container.decodeIfPresent(Int.self, forKey: .targetInt) ?? 1
            self = .healthKitWorkouts(targetCount: val)
        case "sleep":
            let val = try container.decodeIfPresent(Double.self, forKey: .targetDouble) ?? 8.0
            self = .healthKitSleep(targetHours: val)
        default:
            self = .manual
        }
    }
    
    /// Является ли цель объективно проверяемой через Apple HealthKit
    public var isHealthKitVerified: Bool {
        switch self {
        case .manual:
            return false
        case .healthKitSteps, .healthKitWater, .healthKitWorkouts, .healthKitSleep:
            return true
        }
    }
}

// MARK: - Майлстоун победы (для отказа от привычек)
public struct HabitMilestone: Identifiable, Sendable {
    public var id: String { "\(days)_days" }
    public let days: Int
    public let title: String
    public let badgeIcon: String
    public let isUnlocked: Bool
}

// MARK: - Основная модель привычки
public struct HabitItem: Identifiable, Codable, Sendable, Hashable {
    public var id: UUID
    public var title: String
    public var subtitle: String
    public var type: HabitType
    public var category: HabitCategory
    public var icon: String
    public var colorHex: String
    public var targetType: HabitTargetType
    public var createdAt: Date
    public var quitStartDate: Date?
    public var completedDates: [String] // "yyyy-MM-dd"
    public var relapseDates: [Date]
    public var urgeResistedCount: Int
    
    // Цели и сроки
    public var goalTargetDays: Int? // Например: 10, 21, 30, 100 дней
    public var goalEndDate: Date? // Выбранная в календаре дата окончания
    
    // Уведомления
    public var reminderHour: Int?
    public var reminderMinute: Int?
    public var isReminderEnabled: Bool
    public var isSmartRemindersEnabled: Bool // Случайные умные уведомления от ИИ
    public var xpReward: Int
    public var timeOfDay: HabitTimeOfDay?
    public var frozenDates: [String]? // "yyyy-MM-dd" даты спасенные Щитом Стрика 🧊
    public var dailyCostSavings: Double? // Сумма ежедневной экономии в рублях при отказе (например, 300 ₽)
    
    public var effectiveTimeOfDay: HabitTimeOfDay {
        timeOfDay ?? .anytime
    }
    
    public var effectiveFrozenDates: [String] {
        frozenDates ?? []
    }
    
    /// Суммарно сэкономленные деньги благодаря чистым дням (для привычек отказа)
    public var totalMoneySaved: Double {
        guard type == .quit else { return 0.0 }
        let rate = (dailyCostSavings ?? 300.0)
        return max(0.0, Double(cleanStreakDays) * rate)
    }
    
    public init(
        id: UUID = UUID(),
        title: String,
        subtitle: String = "",
        type: HabitType = .build,
        category: HabitCategory = .health,
        icon: String = "star.fill",
        colorHex: String = "#10B981",
        targetType: HabitTargetType = .manual,
        createdAt: Date = Date(),
        quitStartDate: Date? = nil,
        completedDates: [String] = [],
        relapseDates: [Date] = [],
        urgeResistedCount: Int = 0,
        goalTargetDays: Int? = nil,
        goalEndDate: Date? = nil,
        reminderHour: Int? = nil,
        reminderMinute: Int? = nil,
        isReminderEnabled: Bool = false,
        isSmartRemindersEnabled: Bool = true,
        xpReward: Int = 20,
        timeOfDay: HabitTimeOfDay? = .anytime,
        frozenDates: [String]? = [],
        dailyCostSavings: Double? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.type = type
        self.category = category
        self.icon = icon
        self.colorHex = colorHex
        self.targetType = targetType
        self.createdAt = createdAt
        self.quitStartDate = quitStartDate ?? (type == .quit ? createdAt : nil)
        self.completedDates = completedDates
        self.relapseDates = relapseDates
        self.urgeResistedCount = urgeResistedCount
        self.goalTargetDays = goalTargetDays
        self.goalEndDate = goalEndDate
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.isReminderEnabled = isReminderEnabled
        self.isSmartRemindersEnabled = isSmartRemindersEnabled
        self.xpReward = xpReward
        self.timeOfDay = timeOfDay ?? .anytime
        self.frozenDates = frozenDates ?? []
        self.dailyCostSavings = dailyCostSavings
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, title, subtitle, type, category, icon, colorHex, targetType
        case createdAt, quitStartDate, completedDates, relapseDates, urgeResistedCount
        case goalTargetDays, goalEndDate
        case reminderHour, reminderMinute, isReminderEnabled, isSmartRemindersEnabled
        case xpReward, timeOfDay, frozenDates, dailyCostSavings
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle) ?? ""
        self.type = try container.decodeIfPresent(HabitType.self, forKey: .type) ?? .build
        self.category = try container.decodeIfPresent(HabitCategory.self, forKey: .category) ?? .health
        self.icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? "star.fill"
        self.colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) ?? "#10B981"
        self.targetType = try container.decodeIfPresent(HabitTargetType.self, forKey: .targetType) ?? .manual
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.quitStartDate = try container.decodeIfPresent(Date.self, forKey: .quitStartDate)
        self.completedDates = try container.decodeIfPresent([String].self, forKey: .completedDates) ?? []
        self.relapseDates = try container.decodeIfPresent([Date].self, forKey: .relapseDates) ?? []
        self.urgeResistedCount = try container.decodeIfPresent(Int.self, forKey: .urgeResistedCount) ?? 0
        self.goalTargetDays = try container.decodeIfPresent(Int.self, forKey: .goalTargetDays)
        self.goalEndDate = try container.decodeIfPresent(Date.self, forKey: .goalEndDate)
        self.reminderHour = try container.decodeIfPresent(Int.self, forKey: .reminderHour)
        self.reminderMinute = try container.decodeIfPresent(Int.self, forKey: .reminderMinute)
        self.isReminderEnabled = try container.decodeIfPresent(Bool.self, forKey: .isReminderEnabled) ?? false
        self.isSmartRemindersEnabled = try container.decodeIfPresent(Bool.self, forKey: .isSmartRemindersEnabled) ?? true
        self.xpReward = try container.decodeIfPresent(Int.self, forKey: .xpReward) ?? 20
        self.timeOfDay = try container.decodeIfPresent(HabitTimeOfDay.self, forKey: .timeOfDay) ?? .anytime
        self.frozenDates = try container.decodeIfPresent([String].self, forKey: .frozenDates) ?? []
        self.dailyCostSavings = try container.decodeIfPresent(Double.self, forKey: .dailyCostSavings)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(subtitle, forKey: .subtitle)
        try container.encode(type, forKey: .type)
        try container.encode(category, forKey: .category)
        try container.encode(icon, forKey: .icon)
        try container.encode(colorHex, forKey: .colorHex)
        try container.encode(targetType, forKey: .targetType)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(quitStartDate, forKey: .quitStartDate)
        try container.encode(completedDates, forKey: .completedDates)
        try container.encode(relapseDates, forKey: .relapseDates)
        try container.encode(urgeResistedCount, forKey: .urgeResistedCount)
        try container.encodeIfPresent(goalTargetDays, forKey: .goalTargetDays)
        try container.encodeIfPresent(goalEndDate, forKey: .goalEndDate)
        try container.encodeIfPresent(reminderHour, forKey: .reminderHour)
        try container.encodeIfPresent(reminderMinute, forKey: .reminderMinute)
        try container.encode(isReminderEnabled, forKey: .isReminderEnabled)
        try container.encode(isSmartRemindersEnabled, forKey: .isSmartRemindersEnabled)
        try container.encode(xpReward, forKey: .xpReward)
        try container.encodeIfPresent(timeOfDay, forKey: .timeOfDay)
        try container.encodeIfPresent(frozenDates, forKey: .frozenDates)
        try container.encodeIfPresent(dailyCostSavings, forKey: .dailyCostSavings)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: HabitItem, rhs: HabitItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.completedDates == rhs.completedDates &&
        lhs.effectiveFrozenDates == rhs.effectiveFrozenDates &&
        lhs.urgeResistedCount == rhs.urgeResistedCount &&
        lhs.quitStartDate == rhs.quitStartDate &&
        lhs.title == rhs.title &&
        lhs.goalTargetDays == rhs.goalTargetDays &&
        lhs.goalEndDate == rhs.goalEndDate &&
        lhs.timeOfDay == rhs.timeOfDay &&
        lhs.dailyCostSavings == rhs.dailyCostSavings
    }
    
    // MARK: - Вычисляемые свойства
    
    public var color: Color {
        Color(hex: colorHex) ?? (type == .quit ? Color(red: 255/255, green: 75/255, blue: 75/255) : Color(red: 16/255, green: 185/255, blue: 129/255))
    }
    
    public var todayDateKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    public var isCompletedToday: Bool {
        return completedDates.contains(todayDateKey)
    }
    
    public var isFrozenToday: Bool {
        return effectiveFrozenDates.contains(todayDateKey)
    }
    
    public var hasRecentFreeze: Bool {
        return !effectiveFrozenDates.isEmpty
    }
    
    public var isHealthKitAutoCompletedToday: Bool {
        return targetType.isHealthKitVerified && isCompletedToday
    }
    
    public func isCompleted(on dateKey: String) -> Bool {
        return completedDates.contains(dateKey)
    }
    
    public func isFrozen(on dateKey: String) -> Bool {
        return effectiveFrozenDates.contains(dateKey)
    }
    
    // Подсчет чистого времени для Quit-привычки
    public var cleanDuration: TimeInterval {
        guard let start = quitStartDate else { return 0 }
        let now = Date()
        return max(0, now.timeIntervalSince(start))
    }
    
    public var cleanStreakDays: Int {
        guard let start = quitStartDate else { return 0 }
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: start)
        let today = calendar.startOfDay(for: Date())
        let components = calendar.dateComponents([.day], from: startDay, to: today)
        return max(0, components.day ?? 0)
    }
    
    public var cleanStreakHours: Int {
        let totalHours = Int(cleanDuration / 3600)
        return totalHours % 24
    }
    
    // Подсчет стрика для полезной привычки с поддержкой Щитов Заморозки 🧊
    public var buildStreakDays: Int {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        var streak = 0
        var checkDate = Date()
        
        let todayKey = formatter.string(from: checkDate)
        if completedDates.contains(todayKey) || effectiveFrozenDates.contains(todayKey) {
            streak += 1
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else { return streak }
            checkDate = yesterday
        } else {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            let yesterdayKey = formatter.string(from: yesterday)
            if completedDates.contains(yesterdayKey) || effectiveFrozenDates.contains(yesterdayKey) {
                checkDate = yesterday
            } else {
                return 0
            }
        }
        
        while true {
            let key = formatter.string(from: checkDate)
            if completedDates.contains(key) || effectiveFrozenDates.contains(key) {
                streak += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prev
            } else {
                break
            }
        }
        return streak
    }
    
    // MARK: - Вычисление целей и прогресса
    
    /// Общее целевое количество дней (если задано явно или через календарь)
    public var targetGoalTotalDays: Int? {
        if let days = goalTargetDays, days > 0 {
            return days
        }
        if let endDate = goalEndDate {
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: createdAt)
            let end = calendar.startOfDay(for: endDate)
            let diff = calendar.dateComponents([.day], from: start, to: end).day ?? 0
            return max(1, diff)
        }
        return nil
    }
    
    /// Текущие выполненные дни к цели
    public var currentDaysTowardsGoal: Int {
        if type == .quit {
            return cleanStreakDays
        } else {
            return buildStreakDays
        }
    }
    
    /// Доля выполнения цели (0.0 ... 1.0)
    public var goalProgressFraction: Double? {
        guard let total = targetGoalTotalDays, total > 0 else { return nil }
        return min(1.0, max(0.0, Double(currentDaysTowardsGoal) / Double(total)))
    }
    
    /// Оставшиеся дни до цели
    public var goalRemainingDays: Int? {
        guard let total = targetGoalTotalDays else { return nil }
        return max(0, total - currentDaysTowardsGoal)
    }
    
    /// Текущий стрик дней (универсально для обоих типов привычек)
    public var currentStreakDays: Int {
        currentDaysTowardsGoal
    }
    
    /// Квалифицирована ли привычка для получения подарков PRO-доступа
    /// (Только объективно проверяемые привычки HealthKit или реальные дни воздержания)
    public var isEligibleForStreakProReward: Bool {
        if targetType.isHealthKitVerified {
            return true
        }
        if type == .quit {
            return true
        }
        return false
    }
    
    // Майлстоуны для Quit-привычек
    public var milestones: [HabitMilestone] {
        let days = cleanStreakDays
        return [
            HabitMilestone(days: 1, title: "1 день чист", badgeIcon: "sparkle", isUnlocked: days >= 1),
            HabitMilestone(days: 3, title: "3 дня выдержки", badgeIcon: "flame.fill", isUnlocked: days >= 3),
            HabitMilestone(days: 7, title: "1 неделя победы", badgeIcon: "star.fill", isUnlocked: days >= 7),
            HabitMilestone(days: 14, title: "2 недели свободы", badgeIcon: "shield.checkered", isUnlocked: days >= 14),
            HabitMilestone(days: 21, title: "21 день (Нейро-перестройка)", badgeIcon: "brain.head.profile", isUnlocked: days >= 21),
            HabitMilestone(days: 30, title: "1 месяц силы воли", badgeIcon: "crown.fill", isUnlocked: days >= 30),
            HabitMilestone(days: 60, title: "2 месяца контроля", badgeIcon: "medal.fill", isUnlocked: days >= 60),
            HabitMilestone(days: 90, title: "90 дней (Новая личность)", badgeIcon: "trophy.fill", isUnlocked: days >= 90),
            HabitMilestone(days: 180, title: "Полгода чистоты", badgeIcon: "sun.max.fill", isUnlocked: days >= 180),
            HabitMilestone(days: 365, title: "1 год триумфа", badgeIcon: "sparkles", isUnlocked: days >= 365)
        ]
    }
    
    public var currentActiveMilestone: HabitMilestone? {
        milestones.filter { $0.isUnlocked }.last
    }
    
    public var nextMilestone: HabitMilestone? {
        milestones.first { !$0.isUnlocked }
    }
}

// MARK: - Награда за дисциплину и стрики привычек (Product-Led Growth)
public struct HabitRewardItem: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let habitTitle: String
    public let streakDays: Int
    public let rewardTitle: String
    public let proHoursGranted: Int
    public let bonusScansGranted: Int
    public let descriptionText: String
    
    public init(
        id: UUID = UUID(),
        habitTitle: String,
        streakDays: Int,
        rewardTitle: String,
        proHoursGranted: Int,
        bonusScansGranted: Int,
        descriptionText: String
    ) {
        self.id = id
        self.habitTitle = habitTitle
        self.streakDays = streakDays
        self.rewardTitle = rewardTitle
        self.proHoursGranted = proHoursGranted
        self.bonusScansGranted = bonusScansGranted
        self.descriptionText = descriptionText
    }
}

// MARK: - Модель дня для Heatmap матрицы активности (30-90 дней)
public struct HabitHeatmapDay: Identifiable, Sendable {
    public var id: String { dateKey }
    public let date: Date
    public let dateKey: String // "yyyy-MM-dd"
    public let dayOfWeek: Int // 1 (Пн) ... 7 (Вс)
    public let completedCount: Int
    public let totalCount: Int
    public let isFrozen: Bool
    public let fraction: Double
    
    public var isPerfectDay: Bool {
        totalCount > 0 && fraction >= 1.0
    }
    
    public var intensityLevel: Int {
        if isFrozen { return -1 } // специальный статус: заморожен щитом 🧊
        if totalCount == 0 || fraction == 0 { return 0 }
        if fraction < 0.34 { return 1 }
        if fraction < 0.67 { return 2 }
        if fraction < 1.0 { return 3 }
        return 4 // 100% Идеальный день ⚡
    }
    
    public init(
        date: Date,
        dateKey: String,
        dayOfWeek: Int,
        completedCount: Int,
        totalCount: Int,
        isFrozen: Bool,
        fraction: Double
    ) {
        self.date = date
        self.dateKey = dateKey
        self.dayOfWeek = dayOfWeek
        self.completedCount = completedCount
        self.totalCount = totalCount
        self.isFrozen = isFrozen
        self.fraction = fraction
    }
}


