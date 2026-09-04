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
    
    // MARK: - Планирование умных напоминаний по привычкам (Habits)
    public func scheduleHabitReminders(for habit: HabitItem, coach: AICoachPersona) {
        let center = UNUserNotificationCenter.current()
        let baseId = "forma_habit_\(habit.id.uuidString)"
        
        // Удаляем старые уведомления для этой привычки
        center.getPendingNotificationRequests { requests in
            let idsToRemove = requests.filter { $0.identifier.starts(with: baseId) }.map { $0.identifier }
            if !idsToRemove.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: idsToRemove)
            }
        }
        
        guard habit.isReminderEnabled || habit.isSmartRemindersEnabled else { return }
        
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                return
            }
            
            // 1. Фиксированное напоминание в заданный час
            if habit.isReminderEnabled, let h = habit.reminderHour, let m = habit.reminderMinute {
                let content = UNMutableNotificationContent()
                content.sound = .default
                content.badge = 1
                
                if habit.type == .quit {
                    content.title = "🛡️ \(habit.title)"
                    content.body = "Как проходит день? Зайдите в Forma зафиксировать чистый день без срывов!"
                } else {
                    content.title = "⚡ \(habit.title)"
                    content.body = "Время для вашей полезной привычки! Сделайте шаг к своей цели."
                }
                
                var dateComponents = DateComponents()
                dateComponents.hour = h
                dateComponents.minute = m
                
                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                let request = UNNotificationRequest(
                    identifier: "\(baseId)_fixed",
                    content: content,
                    trigger: trigger
                )
                center.add(request)
            }
            
            // 2. Умные случайные уведомления с разными мотивирующими текстами
            if habit.isSmartRemindersEnabled {
                let checkinHours = habit.type == .quit ? [11, 15, 19, 21] : [10, 14, 18, 20]
                
                for (slotIndex, targetHour) in checkinHours.prefix(3).enumerated() {
                    let content = UNMutableNotificationContent()
                    content.sound = .default
                    content.badge = 1
                    
                    let (title, body) = self.habitSmartCheckinContent(for: habit, coach: coach, slotIndex: slotIndex)
                    content.title = title
                    content.body = body
                    
                    var dateComponents = DateComponents()
                    dateComponents.hour = targetHour
                    dateComponents.minute = (slotIndex * 17 + 12) % 60 // разброс по минутам
                    
                    let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                    let request = UNNotificationRequest(
                        identifier: "\(baseId)_smart_\(slotIndex)",
                        content: content,
                        trigger: trigger
                    )
                    center.add(request)
                }
            }
        }
    }
    
    public func removeHabitReminders(for habitId: UUID) {
        let center = UNUserNotificationCenter.current()
        let baseId = "forma_habit_\(habitId.uuidString)"
        center.getPendingNotificationRequests { requests in
            let idsToRemove = requests.filter { $0.identifier.starts(with: baseId) }.map { $0.identifier }
            if !idsToRemove.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: idsToRemove)
            }
        }
    }
    
    private func habitSmartCheckinContent(for habit: HabitItem, coach: AICoachPersona, slotIndex: Int) -> (title: String, body: String) {
        if habit.type == .quit {
            let options: [(String, String)] = [
                (
                    "🛡️ Держишься? • Тренер \(coach.name)",
                    "Как самочувствие? Помни: импульс длится всего 90 секунд. Ты контролируешь ситуацию!"
                ),
                (
                    "🔥 Проверка выдержки: «\(habit.title)»",
                    "Твой стрик: \(habit.cleanStreakDays) дней победы. Не отдавай свою свободу слабости!"
                ),
                (
                    "🧘 Минутка осознанности",
                    "Чувствуешь стресс или тягу сорваться? Включи 60-секундное дыхание SOS в Forma."
                ),
                (
                    "💪 Горжусь твоей дисциплиной!",
                    "Каждый час воздержания перестраивает нейронные пути в твоем мозге. Продолжай!"
                )
            ]
            return options[slotIndex % options.count]
        } else {
            let options: [(String, String)] = [
                (
                    "⚡️ Время для привычки • \(coach.name)",
                    "«\(habit.title)» ждет тебя! Сделаем сегодня и продвинем стрик?"
                ),
                (
                    "🏆 Твой прогресс: «\(habit.title)»",
                    "Стрик: \(habit.buildStreakDays) дн. Дисциплина — это ключ к твоей идеальной форме."
                ),
                (
                    "✨ Маленький шаг к великой цели",
                    "Выполни «\(habit.title)» прямо сейчас и отметь в Forma (+20 XP)!"
                ),
                (
                    "🔥 Тренер \(coach.name) на связи",
                    "Не прерывай цепочку побед. Твое тело и разум скажут тебе спасибо!"
                )
            ]
            return options[slotIndex % options.count]
        }
    }
    
    // MARK: - Планирование общих умных уведомлений питания/воды
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
                
                center.add(request)
            }
        }
    }
    
    // MARK: - Отправка мгновенного тестового уведомления
    public func sendTestNotification(type: ReminderType = .water, coach: AICoachPersona? = nil) {
        let targetCoach = coach ?? AICoachManager.shared.currentCoach
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.sound = .default
        
        let (title, body) = notificationContent(for: type, coach: targetCoach)
        content.title = "⚡️ " + title
        content.body = body
        content.badge = 1
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.5, repeats: false)
        let request = UNNotificationRequest(
            identifier: "forma_test_notification_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        center.add(request)
    }
    
    nonisolated private func notificationContent(for type: ReminderType, coach: AICoachPersona) -> (title: String, body: String) {
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
    
    // MARK: - Адаптивное умное напоминание о кофеине и паузе без воды
    public func scheduleAdaptiveDehydrationNotification(hasUncompensatedCaffeine: Bool, hoursSinceLastDrink: Double) {
        let center = UNUserNotificationCenter.current()
        let identifier = "forma_adaptive_hydration_reminder"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        
        let currentHour = Calendar.current.component(.hour, from: Date())
        guard currentHour >= 8 && currentHour <= 21 else { return }
        
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            
            let content = UNMutableNotificationContent()
            content.sound = .default
            content.badge = 1
            var delaySeconds: TimeInterval = 0
            
            if hasUncompensatedCaffeine {
                content.title = "☕️ Восстановите водный баланс"
                content.body = "Кофеин выводит влагу из организма. Рекомендуем выпить стакан чистой воды (200 мл)."
                delaySeconds = 35 * 60 // 35 минут после кофе
            } else if hoursSinceLastDrink >= 2.5 {
                content.title = "💧 Время сделать пару глотков"
                content.body = "Прошло почти 3 часа без воды. Небольшой стакан поддержит ясность ума и энергию."
                delaySeconds = 30 * 60 // через 30 мин будет 3 часа
            } else {
                return
            }
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(delaySeconds, 60), repeats: false)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            center.add(request)
        }
    }
    
    public enum ReminderType: String, CaseIterable, Codable {
        case water = "water"
        case meal = "meal"
        case activity = "activity"
    }
}
