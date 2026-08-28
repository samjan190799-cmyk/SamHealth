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
    public var reminderHour: Int?
    public var reminderMinute: Int?
    public var isReminderEnabled: Bool
    public var xpReward: Int
    
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
        reminderHour: Int? = nil,
        reminderMinute: Int? = nil,
        isReminderEnabled: Bool = false,
        xpReward: Int = 20
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
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.isReminderEnabled = isReminderEnabled
        self.xpReward = xpReward
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: HabitItem, rhs: HabitItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.completedDates == rhs.completedDates &&
        lhs.urgeResistedCount == rhs.urgeResistedCount &&
        lhs.quitStartDate == rhs.quitStartDate &&
        lhs.title == rhs.title
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
    
    public func isCompleted(on dateKey: String) -> Bool {
        return completedDates.contains(dateKey)
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
    
    // Подсчет стрика для полезной привычки
    public var buildStreakDays: Int {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        var streak = 0
        var checkDate = Date()
        
        let todayKey = formatter.string(from: checkDate)
        if completedDates.contains(todayKey) {
            streak += 1
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else { return streak }
            checkDate = yesterday
        } else {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            let yesterdayKey = formatter.string(from: yesterday)
            if completedDates.contains(yesterdayKey) {
                checkDate = yesterday
            } else {
                return 0
            }
        }
        
        while true {
            let key = formatter.string(from: checkDate)
            if completedDates.contains(key) {
                streak += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prev
            } else {
                break
            }
        }
        return streak
    }
    
    // Майлстоуны победы
    public var milestones: [HabitMilestone] {
        let days = cleanStreakDays
        return [
            HabitMilestone(days: 1, title: "1 день", badgeIcon: "shield.fill", isUnlocked: days >= 1),
            HabitMilestone(days: 3, title: "3 дня", badgeIcon: "flame.fill", isUnlocked: days >= 3),
            HabitMilestone(days: 7, title: "1 неделя", badgeIcon: "medal.fill", isUnlocked: days >= 7),
            HabitMilestone(days: 14, title: "2 недели", badgeIcon: "trophy.fill", isUnlocked: days >= 14),
            HabitMilestone(days: 30, title: "1 месяц", badgeIcon: "crown.fill", isUnlocked: days >= 30),
            HabitMilestone(days: 100, title: "100 дней", badgeIcon: "sparkles", isUnlocked: days >= 100)
        ]
    }
    
    public var currentActiveMilestone: HabitMilestone? {
        milestones.last(where: { $0.isUnlocked })
    }
    
    public var nextMilestone: HabitMilestone? {
        milestones.first(where: { !$0.isUnlocked })
    }
}

// MARK: - Color Hex Extension Helper
extension Color {
    public init?(hex: String) {
        var clean = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if clean.hasPrefix("#") { clean.remove(at: clean.startIndex) }
        guard clean.count == 6, let rgbValue = UInt64(clean, radix: 16) else { return nil }
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
