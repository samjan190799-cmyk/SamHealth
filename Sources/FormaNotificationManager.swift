import Foundation
import UserNotifications
import UIKit

@MainActor
public final class FormaNotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    public static let shared = FormaNotificationManager()
    
    @Published public var isAuthorized: Bool = false
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        checkPermissionStatus()
    }
    
    public func checkPermissionStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.isAuthorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            }
        }
    }
    
    public func requestPermission(completion: @escaping (Bool) -> Void = { _ in }) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            Task { @MainActor in
                self.isAuthorized = granted
                if granted {
                    self.autoScheduleDefaultRemindersIfNeeded()
                }
                completion(granted)
            }
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate (Foreground notifications)
    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge, .list])
    }
    
    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
    
    // MARK: - Автоматическое планирование по умолчанию
    public func autoScheduleDefaultRemindersIfNeeded() {
        let coach = AICoachManager.shared.currentCoach
        scheduleSmartReminders(
            mealEnabled: true,
            waterEnabled: true,
            activityEnabled: true,
            isRandomTime: false,
            startHour: 9,
            endHour: 22,
            frequencyPerDay: 4,
            coach: coach
        )
    }
    
    // MARK: - Планирование умных уведомлений
    public func scheduleSmartReminders(
        mealEnabled: Bool,
        waterEnabled: Bool,
        activityEnabled: Bool,
        isRandomTime: Bool,
        startHour: Int,
        endHour: Int,
        frequencyPerDay: Int,
        coach: AICoachPersona
    ) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        
        guard mealEnabled || waterEnabled || activityEnabled else { return }
        
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                return
            }
            
            let safeStart = max(7, min(20, startHour))
            let safeEnd = max(safeStart + 2, min(23, endHour))
            let count = max(2, min(8, frequencyPerDay))
            let totalActiveHours = safeEnd - safeStart
            
            var scheduleTimes: [(hour: Int, minute: Int, type: ReminderType)] = []
            
            var enabledTypes: [ReminderType] = []
            if mealEnabled { enabledTypes.append(.meal) }
            if waterEnabled { enabledTypes.append(.water) }
            if activityEnabled { enabledTypes.append(.activity) }
            
            if enabledTypes.isEmpty { return }
            
            let interval = Double(totalActiveHours) / Double(count)
            for i in 0..<count {
                let calculatedHour = safeStart + Int(Double(i) * interval)
                let minute = (i * 15) % 60
                let type = enabledTypes[i % enabledTypes.count]
                scheduleTimes.append((hour: calculatedHour, minute: minute, type: type))
            }
            
            for (index, item) in scheduleTimes.enumerated() {
                let content = UNMutableNotificationContent()
                content.sound = .default
                
                let (title, body) = self.notificationContent(for: item.type, coach: coach)
                content.title = title
                content.body = body
                content.badge = 1
                
                var dateComponents = DateComponents()
                dateComponents.hour = item.hour
                dateComponents.minute = item.minute
                
                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                let request = UNNotificationRequest(
                    identifier: "forma_smart_reminder_\(item.type.rawValue)_\(index)",
                    content: content,
                    trigger: trigger
                )
                
                center.add(request) { error in
                    if let err = error {
                        print("Ошибка добавления уведомления: \(err.localizedDescription)")
                    }
                }
            }
        }
    }
    
    // MARK: - Отправка мгновенного тестового уведомления
    public func sendTestNotification(type: ReminderType = .water, coach: AICoachPersona = AICoachManager.shared.currentCoach) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.sound = .default
        
        let (title, body) = notificationContent(for: type, coach: coach)
        content.title = "⚡️ " + title
        content.body = body
        content.badge = 1
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.5, repeats: false)
        let request = UNNotificationRequest(
            identifier: "forma_test_notification_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let err = error {
                print("Ошибка отправки теста: \(err.localizedDescription)")
            }
        }
    }
    
    private func notificationContent(for type: ReminderType, coach: AICoachPersona) -> (title: String, body: String) {
        switch type {
        case .water:
            let titles = [
                "💧 Время чистой воды",
                "💧 Водный баланс — Forma",
                "⚡️ Тренер \(coach.name): глоток энергии"
            ]
            let bodies = [
                "Выпейте стакан чистой воды, чтобы поддержать метаболизм и гидратацию.",
                "Небольшой глоток воды вернет концентрацию и снимет усталость!",
                "Пора освежиться! Запишите выпитый стакан в Forma."
            ]
            return (titles.randomElement()!, bodies.randomElement()!)
            
        case .meal:
            let titles = [
                "🥗 Время приема пищи",
                "🍽 Контроль питания — Forma",
                "🍎 Тренер \(coach.name)"
            ]
            let bodies = [
                "Не забудьте зафиксировать свой прием пищи и БЖУ в приложении.",
                "Полноценный белок и овощи дадут отличный запас энергии на день!",
                "Сфотографируйте еду через AI-Сканер для мгновенного подсчета калорий."
            ]
            return (titles.randomElement()!, bodies.randomElement()!)
            
        case .activity:
            let titles = [
                "🏃‍♂️ Разминка и шаги",
                "⚡️ Время размяться!",
                "🔥 Тренер \(coach.name) на связи"
            ]
            let bodies = [
                "Сделайте небольшую прогулку или легкую растяжку прямо сейчас.",
                "Встаньте, потянитесь и сделайте 200 шагов для перезагрузки тела!",
                "Ваша дневная цель активности близка. Дожмите оставшиеся шаги!"
            ]
            return (titles.randomElement()!, bodies.randomElement()!)
        }
    }
    
    public enum ReminderType: String, CaseIterable, Codable {
        case water = "water"
        case meal = "meal"
        case activity = "activity"
    }
}
