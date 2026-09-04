import SwiftUI
import HealthKit

public enum WatchWorkoutCategory: String, CaseIterable, Identifiable {
    case all = "Все"
    case cardio = "Кардио"
    case strength = "Сила"
    case mindBody = "Тело"
    case sports = "Спорт"
    case challenges = "Упражнения"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .all: return "sparkles"
        case .cardio: return "figure.run"
        case .strength: return "dumbbell.fill"
        case .mindBody: return "figure.yoga"
        case .sports: return "figure.soccer"
        case .challenges: return "flame.fill"
        }
    }
}

public struct WatchWorkoutItem: Identifiable, Hashable {
    public var id: String { name }
    public let name: String
    public let icon: String
    public let color: Color
    public let category: WatchWorkoutCategory
    public let met: Double
    public let isTimeBased: Bool
    
    public init(name: String, icon: String, color: Color, category: WatchWorkoutCategory, met: Double, isTimeBased: Bool = false) {
        self.name = name
        self.icon = icon
        self.color = color
        self.category = category
        self.met = met
        self.isTimeBased = isTimeBased
    }
}

public extension WatchWorkoutItem {
    static let allItems: [WatchWorkoutItem] = [
        // КАРДИО & ВЫНОСЛИВОСТЬ
        WatchWorkoutItem(name: "Бег на улице", icon: "figure.run", color: .red, category: .cardio, met: 9.8),
        WatchWorkoutItem(name: "Беговая дорожка", icon: "figure.run.treadmill", color: .red, category: .cardio, met: 8.5),
        WatchWorkoutItem(name: "Спортивная ходьба", icon: "figure.walk", color: .green, category: .cardio, met: 3.8),
        WatchWorkoutItem(name: "Хайкинг и горы", icon: "figure.hiking", color: .green, category: .cardio, met: 6.5),
        WatchWorkoutItem(name: "Велоспорт", icon: "figure.outdoor.cycle", color: .blue, category: .cardio, met: 7.5),
        WatchWorkoutItem(name: "Велотренажер", icon: "figure.indoor.cycle", color: .blue, category: .cardio, met: 6.8),
        WatchWorkoutItem(name: "Плавание в бассейне", icon: "figure.pool.swim", color: .cyan, category: .cardio, met: 8.0),
        WatchWorkoutItem(name: "Открытая вода", icon: "figure.open.water.swim", color: .cyan, category: .cardio, met: 8.5),
        WatchWorkoutItem(name: "Скакалка", icon: "figure.jumprope", color: .orange, category: .cardio, met: 11.0),
        WatchWorkoutItem(name: "Гребной тренажер", icon: "figure.rower", color: .teal, category: .cardio, met: 7.2),
        WatchWorkoutItem(name: "Эллипс", icon: "figure.elliptical", color: .mint, category: .cardio, met: 6.0),
        WatchWorkoutItem(name: "Степпер", icon: "figure.stair.stepper", color: .purple, category: .cardio, met: 8.5),
        
        // СИЛОВЫЕ & HIIT
        WatchWorkoutItem(name: "Силовая тренировка", icon: "figure.strengthtraining.functional", color: .orange, category: .strength, met: 5.5),
        WatchWorkoutItem(name: "Гантели и штанга", icon: "dumbbell.fill", color: .orange, category: .strength, met: 6.0),
        WatchWorkoutItem(name: "Калистеника / Турники", icon: "figure.cross.training", color: .yellow, category: .strength, met: 7.0),
        WatchWorkoutItem(name: "HIIT / Интервальная", icon: "figure.highintensity.intervaltraining", color: .red, category: .strength, met: 9.0),
        WatchWorkoutItem(name: "Кроссфит", icon: "figure.mixed.cardio", color: .orange, category: .strength, met: 8.5),
        WatchWorkoutItem(name: "Бокс / Кикбоксинг", icon: "figure.boxing", color: .red, category: .strength, met: 9.5),
        WatchWorkoutItem(name: "Единоборства / ММА", icon: "figure.martial.arts", color: .purple, category: .strength, met: 9.0),
        
        // MIND & BODY
        WatchWorkoutItem(name: "Йога", icon: "figure.yoga", color: .teal, category: .mindBody, met: 3.0, isTimeBased: true),
        WatchWorkoutItem(name: "Пилатес", icon: "figure.pilates", color: .mint, category: .mindBody, met: 3.5, isTimeBased: true),
        WatchWorkoutItem(name: "Растяжка и гибкость", icon: "figure.flexibility", color: .blue, category: .mindBody, met: 2.8, isTimeBased: true),
        WatchWorkoutItem(name: "Тренировка кора", icon: "figure.core.training", color: .purple, category: .mindBody, met: 4.5),
        WatchWorkoutItem(name: "Дыхательные практики", icon: "wind", color: .cyan, category: .mindBody, met: 1.5, isTimeBased: true),
        
        // СПОРТ
        WatchWorkoutItem(name: "Футбол", icon: "figure.soccer", color: .green, category: .sports, met: 8.0),
        WatchWorkoutItem(name: "Баскетбол", icon: "figure.basketball", color: .orange, category: .sports, met: 7.5),
        WatchWorkoutItem(name: "Большой теннис", icon: "figure.tennis", color: .yellow, category: .sports, met: 7.0),
        WatchWorkoutItem(name: "Падел / Настольный теннис", icon: "figure.table.tennis", color: .blue, category: .sports, met: 5.5),
        WatchWorkoutItem(name: "Бадминтон", icon: "figure.badminton", color: .mint, category: .sports, met: 6.0),
        WatchWorkoutItem(name: "Лыжи и сноуборд", icon: "figure.skiing.downhill", color: .cyan, category: .sports, met: 7.0),
        
        // УПРАЖНЕНИЯ / ЧЕЛЛЕНДЖИ
        WatchWorkoutItem(name: "Отжимания", icon: "figure.strengthtraining.traditional", color: .orange, category: .challenges, met: 6.0),
        WatchWorkoutItem(name: "Приседания", icon: "figure.cross.training", color: .blue, category: .challenges, met: 6.5),
        WatchWorkoutItem(name: "Планка", icon: "figure.core.training", color: .purple, category: .challenges, met: 4.0, isTimeBased: true),
        WatchWorkoutItem(name: "Подтягивания", icon: "figure.arms.open", color: .yellow, category: .challenges, met: 7.0),
        WatchWorkoutItem(name: "Берпи", icon: "figure.jumprope", color: .red, category: .challenges, met: 10.0)
    ]
}
