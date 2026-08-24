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
        stepsToday: Int = 8450,
        stepGoal: Int = 10000,
        activeCalories: Double = 420.0,
        activeCaloriesGoal: Double = 600.0,
        exerciseMinutes: Int = 32,
        exerciseMinutesGoal: Int = 45,
        standHours: Int = 8,
        standHoursGoal: Int = 12,
        currentHeartRate: Int = 72,
        waterConsumed: Double = 1750.0,
        waterGoal: Double = 2500.0,
        caloriesConsumed: Double = 1850.0,
        totalCaloriesBurned: Double = 2300.0,
        energyBalance: Double = -450.0,
        currentWeight: Double = 74.5,
        targetWeight: Double = 70.0,
        coachId: String = "alex",
        coachName: String = "Алекс",
        coachAvatarAssetName: String = "CoachAlexAvatar",
        coachBadgeEmoji: String = "⚡",
        coachAdvice: String = "Отличная активность! Держи темп и не забудь закрыть кольцо разминки.",
        lastUpdated: Date = Date(),
        hourlyStepCounts: [Int] = [450, 1200, 800, 2100, 1600, 950, 1350]
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
    
    public var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: FormaWidgetDataManager.appGroupId) ?? UserDefaults.standard
    }
    
    public init() {}
    
    public func saveSnapshot(_ snapshot: FormaWidgetDataSnapshot) {
        guard let userDefaults = sharedDefaults else { return }
        if let encoded = try? JSONEncoder().encode(snapshot) {
            userDefaults.set(encoded, forKey: FormaWidgetDataManager.storageKey)
            userDefaults.synchronize()
            
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
        }
    }
    
    public func getSnapshot() -> FormaWidgetDataSnapshot {
        guard let userDefaults = sharedDefaults,
              let data = userDefaults.data(forKey: FormaWidgetDataManager.storageKey),
              let decoded = try? JSONDecoder().decode(FormaWidgetDataSnapshot.self, from: data) else {
            return FormaWidgetDataSnapshot()
        }
        return decoded
    }
}
