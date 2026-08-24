import Foundation
import WidgetKit

public struct FormaWidgetDataSnapshot: Codable {
    public var stepsToday: Int
    public var stepGoal: Int
    public var activeCalories: Double
    public var activeCaloriesGoal: Double
    public var exerciseMinutes: Int
    public var exerciseMinutesGoal: Int
    public var standHours: Int
    public var standHoursGoal: Int
    public var currentHeartRate: Int
    public var waterConsumed: Double
    public var waterGoal: Double
    public var caloriesConsumed: Double
    public var totalCaloriesBurned: Double
    public var energyBalance: Double
    public var currentWeight: Double
    public var targetWeight: Double
    public var coachId: String
    public var coachName: String
    public var coachAvatarAssetName: String
    public var coachBadgeEmoji: String
    public var coachAdvice: String
    public var lastUpdated: Date
    public var hourlyStepCounts: [Int]
    
    public init(
        stepsToday: Int = 0,
        stepGoal: Int = 10000,
        activeCalories: Double = 0.0,
        activeCaloriesGoal: Double = 500.0,
        exerciseMinutes: Int = 0,
        exerciseMinutesGoal: Int = 30,
        standHours: Int = 0,
        standHoursGoal: Int = 12,
        currentHeartRate: Int = 0,
        waterConsumed: Double = 0.0,
        waterGoal: Double = 2500.0,
        caloriesConsumed: Double = 0.0,
        totalCaloriesBurned: Double = 0.0,
        energyBalance: Double = 0.0,
        currentWeight: Double = 75.0,
        targetWeight: Double = 70.0,
        coachId: String = "alex",
        coachName: String = "Алекс",
        coachAvatarAssetName: String = "CoachAlexAvatar",
        coachBadgeEmoji: String = "⚡",
        coachAdvice: String = "Начните день с активности и стакана чистой воды!",
        lastUpdated: Date = Date(),
        hourlyStepCounts: [Int] = [0, 0, 0, 0, 0, 0, 0]
    ) {
        self.stepsToday = stepsToday
        self.stepGoal = stepGoal
        self.activeCalories = activeCalories
        self.activeCaloriesGoal = activeCaloriesGoal
        self.exerciseMinutes = exerciseMinutes
        self.exerciseMinutesGoal = exerciseMinutesGoal
        self.standHours = standHours
        self.standHoursGoal = standHoursGoal
        self.currentHeartRate = currentHeartRate
        self.waterConsumed = waterConsumed
        self.waterGoal = waterGoal
        self.caloriesConsumed = caloriesConsumed
        self.totalCaloriesBurned = totalCaloriesBurned
        self.energyBalance = energyBalance
        self.currentWeight = currentWeight
        self.targetWeight = targetWeight
        self.coachId = coachId
        self.coachName = coachName
        self.coachAvatarAssetName = coachAvatarAssetName
        self.coachBadgeEmoji = coachBadgeEmoji
        self.coachAdvice = coachAdvice
        self.lastUpdated = lastUpdated
        self.hourlyStepCounts = hourlyStepCounts
    }
}

public final class FormaWidgetDataManager {
    public static let shared = FormaWidgetDataManager()
    public static let appGroupId = "group.com.samvel.forma"
    private static let storageKey = "forma_widget_snapshot_data"
    private static let sharedFileName = "forma_widget_snapshot.json"
    
    public var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: FormaWidgetDataManager.appGroupId) ?? UserDefaults.standard
    }
    
    private var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: FormaWidgetDataManager.appGroupId)
    }
    
    public init() {}
    
    public func saveSnapshot(_ snapshot: FormaWidgetDataSnapshot) {
        guard let encoded = try? JSONEncoder().encode(snapshot) else { return }
        
        // 1. Сохраняем в AppGroup UserDefaults
        if let userDefaults = sharedDefaults {
            userDefaults.set(encoded, forKey: FormaWidgetDataManager.storageKey)
            userDefaults.synchronize()
        }
        
        // 2. Сохраняем в стандартный UserDefaults на всякий случай
        UserDefaults.standard.set(encoded, forKey: FormaWidgetDataManager.storageKey)
        UserDefaults.standard.synchronize()
        
        // 3. Сохраняем в общий JSON-файл в директории App Group
        if let containerURL = sharedContainerURL {
            let fileURL = containerURL.appendingPathComponent(FormaWidgetDataManager.sharedFileName)
            try? encoded.write(to: fileURL, options: .atomic)
        }
        
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
    
    public func getSnapshot() -> FormaWidgetDataSnapshot {
        // 1. Проверяем AppGroup UserDefaults
        if let userDefaults = sharedDefaults,
           let data = userDefaults.data(forKey: FormaWidgetDataManager.storageKey),
           let decoded = try? JSONDecoder().decode(FormaWidgetDataSnapshot.self, from: data) {
            return decoded
        }
        
        // 2. Проверяем общий JSON-файл в App Group
        if let containerURL = sharedContainerURL {
            let fileURL = containerURL.appendingPathComponent(FormaWidgetDataManager.sharedFileName)
            if let fileData = try? Data(contentsOf: fileURL),
               let decoded = try? JSONDecoder().decode(FormaWidgetDataSnapshot.self, from: fileData) {
                return decoded
            }
        }
        
        // 3. Проверяем стандартный UserDefaults
        if let data = UserDefaults.standard.data(forKey: FormaWidgetDataManager.storageKey),
           let decoded = try? JSONDecoder().decode(FormaWidgetDataSnapshot.self, from: data) {
            return decoded
        }
        
        return FormaWidgetDataSnapshot()
    }
}
