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
