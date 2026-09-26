import Foundation
import SwiftUI
import ActivityKit
import Combine

@MainActor
public final class FormaLiveActivityManager: ObservableObject {
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
    
    /// Завершение Live Activity (мгновенное закрытие плашки на Lock Screen и Dynamic Island)
    public func endWorkoutActivity(
        finalSeconds: Int? = nil,
        finalCalories: Int? = nil,
        finalDistance: Double? = nil
    ) {
        let allActivities = Activity<FormaWorkoutActivityAttributes>.activities
        guard !allActivities.isEmpty || currentActivity != nil else {
            self.currentActivity = nil
            return
        }
        
        let targetActivity = currentActivity ?? allActivities.first
        let currentSeconds = finalSeconds ?? targetActivity?.content.state.elapsedSeconds ?? 0
        let currentCal = finalCalories ?? targetActivity?.content.state.calories ?? 0
        let currentDist = finalDistance ?? targetActivity?.content.state.distanceMeters ?? 0.0
        let currentHr = targetActivity?.content.state.heartRate ?? 0
        let currentSteps = targetActivity?.content.state.steps ?? 0
        
        let finalState = FormaWorkoutActivityAttributes.ContentState(
            elapsedSeconds: currentSeconds,
            calories: currentCal,
            heartRate: currentHr,
            distanceMeters: currentDist,
            steps: currentSteps,
            isPaused: true,
            isFinished: true,
            exerciseName: "Тренировка завершена"
        )
        
        let finalContent = ActivityContent(
            state: finalState,
            staleDate: nil
        )
        
        Task {
            for act in Activity<FormaWorkoutActivityAttributes>.activities {
                await act.end(finalContent, dismissalPolicy: .immediate)
            }
        }
        self.currentActivity = nil
        print("[LiveActivity] Все Live Activities завершены с политикой .immediate")
    }
    
    /// Принудительная очистка зависших Live Activities, если тренировка фактически не активна
    public func cleanUpOrphanedActivities() {
        let allActivities = Activity<FormaWorkoutActivityAttributes>.activities
        guard !allActivities.isEmpty else { return }
        print("[LiveActivity] Очистка \(allActivities.count) висящих активностей...")
        Task {
            for act in allActivities {
                await act.end(nil, dismissalPolicy: .immediate)
            }
        }
        self.currentActivity = nil
    }
}
