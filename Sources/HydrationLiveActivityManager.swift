import Foundation
import ActivityKit
import SwiftUI

// MARK: - Менеджер Live Activity и Dynamic Island для трекера воды
@MainActor
public final class HydrationLiveActivityManager: ObservableObject {
    public static let shared = HydrationLiveActivityManager()
    
    @Published public private(set) var isLiveActivityActive: Bool = false
    
    private var currentActivity: Activity<FormaHydrationActivityAttributes>? {
        Activity<FormaHydrationActivityAttributes>.activities.first
    }
    
    private init() {
        updateActiveStatus()
    }
    
    public func updateActiveStatus() {
        isLiveActivityActive = (currentActivity != nil)
    }
    
    /// Запуск или обновление Живой Активности на экране блокировки и в Dynamic Island
    public func syncHydrationLiveActivity(
        consumed: Double,
        goal: Double,
        lastBeverage: LoggedBeverageRecord?,
        activeCaffeineMg: Double,
        sleepCutoffDate: Date?,
        needsCaffeineCompensation: Bool
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        let safeGoal = max(goal, 1000.0)
        let percent = Int(min(consumed / safeGoal * 100.0, 999.0))
        
        var sleepStr = ""
        if let cutoff = sleepCutoffDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            sleepStr = "после \(formatter.string(from: cutoff))"
        }
        
        let contentState = FormaHydrationActivityAttributes.ContentState(
            waterConsumedMl: consumed,
            waterGoalMl: safeGoal,
            progressPercent: percent,
            lastBeverageName: lastBeverage?.displayName ?? "Чистая вода",
            lastBeverageEmoji: lastBeverage?.beverageType.emoji ?? "💧",
            lastLogDate: lastBeverage?.date ?? Date(),
            activeCaffeineMg: activeCaffeineMg,
            sleepCutoffStr: sleepStr,
            needsCaffeineCompensation: needsCaffeineCompensation
        )
        
        Task {
            if let existingActivity = currentActivity {
                await existingActivity.update(
                    ActivityContent(state: contentState, staleDate: Calendar.current.date(byAdding: .hour, value: 4, to: Date()))
                )
                self.updateActiveStatus()
            } else if consumed > 0 {
                // Если активность еще не запущена, но пользователь уже начал пить воду сегодня
                do {
                    let attributes = FormaHydrationActivityAttributes(startDate: Date())
                    let activity = try Activity.request(
                        attributes: attributes,
                        content: ActivityContent(state: contentState, staleDate: Calendar.current.date(byAdding: .hour, value: 4, to: Date())),
                        pushType: nil
                    )
                    _ = activity
                    self.updateActiveStatus()
                } catch {
                    print("Не удалось запустить Hydration Live Activity: \(error)")
                }
            }
        }
    }
    
    /// Остановка Live Activity при сбросе дня
    public func endLiveActivity() {
        Task {
            for activity in Activity<FormaHydrationActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            self.updateActiveStatus()
        }
    }
}
