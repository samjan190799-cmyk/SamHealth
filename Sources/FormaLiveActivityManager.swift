import Foundation
import SwiftUI
import ActivityKit
import Combine

@MainActor
public class FormaLiveActivityManager: ObservableObject {
    public static let shared = FormaLiveActivityManager()
    
    private var currentActivity: Activity<FormaWorkoutActivityAttributes>? = nil
    
    private init() {}
    
    public var isLiveActivityActive: Bool {
        return currentActivity != nil
    }
    
    /// Запуск Live Activity на Dynamic Island и экране блокировки
    public func startWorkoutActivity(workoutType: String, icon: String, startDate: Date = Date()) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("[LiveActivity] Live Activities не разрешены пользователем или системой.")
            return
        }
        
        // Завершаем предыдущую активность, если она была активна
        endWorkoutActivity()
        
        let attributes = FormaWorkoutActivityAttributes(
            workoutType: workoutType,
            workoutIcon: icon,
            startDate: startDate
        )
        
        let initialContentState = FormaWorkoutActivityAttributes.ContentState(
            elapsedSeconds: 0,
            calories: 0,
            heartRate: 0,
            distanceMeters: 0.0,
            steps: 0,
            isPaused: false,
            exerciseName: workoutType
        )
        
        let activityContent = ActivityContent(
            state: initialContentState,
            staleDate: Calendar.current.date(byAdding: .hour, value: 4, to: Date())
        )
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: activityContent,
                pushType: nil
            )
            self.currentActivity = activity
            print("[LiveActivity] Успешно запущена активность: \(activity.id)")
        } catch {
            print("[LiveActivity] Ошибка запуска Live Activity: \(error.localizedDescription)")
        }
    }
    
    /// Обновление метрик тренировки в Dynamic Island
    public func updateWorkoutActivity(
        elapsedSeconds: Int,
        calories: Int,
        heartRate: Int,
        distanceMeters: Double,
        steps: Int,
        isPaused: Bool,
        exerciseName: String? = nil,
        currentSet: Int = 0,
        totalSets: Int = 0
    ) {
        guard let activity = currentActivity else { return }
        
        let updatedState = FormaWorkoutActivityAttributes.ContentState(
            elapsedSeconds: elapsedSeconds,
            calories: calories,
            heartRate: heartRate,
            distanceMeters: distanceMeters,
            steps: steps,
            isPaused: isPaused,
            exerciseName: exerciseName,
            currentSet: currentSet,
            totalSets: totalSets
        )
        
        let content = ActivityContent(
            state: updatedState,
            staleDate: Calendar.current.date(byAdding: .minute, value: 5, to: Date())
        )
        
        Task {
            await activity.update(content)
        }
    }
    
    /// Завершение Live Activity
    public func endWorkoutActivity(
        finalSeconds: Int? = nil,
        finalCalories: Int? = nil,
        finalDistance: Double? = nil
    ) {
        guard let activity = currentActivity else { return }
        
        let finalState = FormaWorkoutActivityAttributes.ContentState(
            elapsedSeconds: finalSeconds ?? activity.content.state.elapsedSeconds,
            calories: finalCalories ?? activity.content.state.calories,
            heartRate: activity.content.state.heartRate,
            distanceMeters: finalDistance ?? activity.content.state.distanceMeters,
            steps: activity.content.state.steps,
            isPaused: false,
            exerciseName: "Тренировка завершена"
        )
        
        let finalContent = ActivityContent(
            state: finalState,
            staleDate: nil
        )
        
        Task {
            await activity.end(finalContent, dismissalPolicy: .default)
        }
        self.currentActivity = nil
        print("[LiveActivity] Live Activity завершена.")
    }
}
