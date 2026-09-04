import Foundation
import ActivityKit

public struct FormaWorkoutActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var elapsedSeconds: Int
        public var calories: Int
        public var heartRate: Int
        public var distanceMeters: Double
        public var steps: Int
        public var isPaused: Bool
        public var exerciseName: String?
        public var currentSet: Int
        public var totalSets: Int
        
        public init(
            elapsedSeconds: Int = 0,
            calories: Int = 0,
            heartRate: Int = 0,
            distanceMeters: Double = 0.0,
            steps: Int = 0,
            isPaused: Bool = false,
            exerciseName: String? = nil,
            currentSet: Int = 0,
            totalSets: Int = 0
        ) {
            self.elapsedSeconds = elapsedSeconds
            self.calories = calories
            self.heartRate = heartRate
            self.distanceMeters = distanceMeters
            self.steps = steps
            self.isPaused = isPaused
            self.exerciseName = exerciseName
            self.currentSet = currentSet
            self.totalSets = totalSets
        }
    }
    
    // Статические параметры тренировки
    public var workoutType: String
    public var workoutIcon: String
    public var startDate: Date
    
    public init(workoutType: String, workoutIcon: String, startDate: Date = Date()) {
        self.workoutType = workoutType
        self.workoutIcon = workoutIcon
        self.startDate = startDate
    }
}

// MARK: - Live Activity для дневного баланса воды и кофеина
public struct FormaHydrationActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var waterConsumedMl: Double
        public var waterGoalMl: Double
        public var progressPercent: Int
        public var lastBeverageName: String
        public var lastBeverageEmoji: String
        public var lastLogDate: Date
        public var activeCaffeineMg: Double
        public var sleepCutoffStr: String
        public var needsCaffeineCompensation: Bool
        
        public init(
            waterConsumedMl: Double = 0.0,
            waterGoalMl: Double = 2500.0,
            progressPercent: Int = 0,
            lastBeverageName: String = "Вода",
            lastBeverageEmoji: String = "💧",
            lastLogDate: Date = Date(),
            activeCaffeineMg: Double = 0.0,
            sleepCutoffStr: String = "",
            needsCaffeineCompensation: Bool = false
        ) {
            self.waterConsumedMl = waterConsumedMl
            self.waterGoalMl = waterGoalMl
            self.progressPercent = progressPercent
            self.lastBeverageName = lastBeverageName
            self.lastBeverageEmoji = lastBeverageEmoji
            self.lastLogDate = lastLogDate
            self.activeCaffeineMg = activeCaffeineMg
            self.sleepCutoffStr = sleepCutoffStr
            self.needsCaffeineCompensation = needsCaffeineCompensation
        }
    }
    
    public var startDate: Date
    
    public init(startDate: Date = Date()) {
        self.startDate = startDate
    }
}
