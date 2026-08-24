import Foundation
import UserNotifications
import UIKit

public final class FormaNotificationManager: ObservableObject {
    public static let shared = FormaNotificationManager()
    
    @Published public var isAuthorized: Bool = false
    
    private init() {
        checkPermissionStatus()
    }
    
    public func checkPermissionStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            }
        }
    }
    
    public func requestPermission(completion: @escaping (Bool) -> Void = { _ in }) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                completion(granted)
            }
        }
    }
    
    // MARK: - Планирование умных уведомлений
    public func scheduleSmartReminders(
        mealEnabled: Bool,
        waterEnabled: Bool,
        activityEnabled: Bool,
        isRandomTime: Bool,
        startHour: Int, // например, 8 (08:00)
        endHour: Int,   // например, 22 (22:00)
        frequencyPerDay: Int, // 3, 5, 8
        coach: AICoachPersona
    ) {
        // Удаляем старые запланированные уведомления напоминалок
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        
        guard mealEnabled || waterEnabled || activityEnabled else { return }
        
        // Убедимся, что есть разрешение
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                return
            }
            
            let safeStart = max(6, min(20, startHour))
            let safeEnd = max(safeStart + 2, min(23, endHour))
            let count = max(2, min(10, frequencyPerDay))
            let totalActiveHours = safeEnd - safeStart
            
            var scheduleTimes: [(hour: Int, minute: Int, type: ReminderType)] = []
            
            // Типы включенных напоминаний
            var enabledTypes: [ReminderType] = []
            if mealEnabled { enabledTypes.append(.meal) }
            if waterEnabled { enabledTypes.append(.water) }
            if activityEnabled { enabledTypes.append(.activity) }
            
            if isRandomTime {
                // Генерация случайных часов и минут внутри диапазона
                var usedHours = Set<Int>()
                for i in 0..<count {
                    var randomHour = Int.random(in: safeStart..<safeEnd)
                    var attempts = 0
                    while usedHours.contains(randomHour) && attempts < 10 {
                        randomHour = Int.random(in: safeStart..<safeEnd)
                        attempts += 1
                    }
                    usedHours.insert(randomHour)
                    let randomMinute = Int.random(in: 0...59)
                    let type = enabledTypes[i % enabledTypes.count]
                    scheduleTimes.append((hour: randomHour, minute: randomMinute, type: type))
                }
            } else {
                // Равномерное распределение
                let interval = Double(totalActiveHours) / Double(count)
                for i in 0..<count {
                    let calculatedHour = safeStart + Int(Double(i) * interval)
                    let minute = (i * 17) % 60
                    let type = enabledTypes[i % enabledTypes.count]
                    scheduleTimes.append((hour: calculatedHour, minute: minute, type: type))
                }
            }
            
            // Регистрируем каждое уведомление
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
                    identifier: "forma_reminder_\(item.type.rawValue)_\(index)",
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
    
    // MARK: - Отправка тестового уведомления прямо сейчас
    public func sendTestNotification(type: ReminderType, coach: AICoachPersona) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.sound = .default
        
        let (title, body) = notificationContent(for: type, coach: coach)
        content.title = title
        content.body = body
        content.badge = 1
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3.0, repeats: false)
        let request = UNNotificationRequest(
            identifier: "forma_test_notification_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        center.add(request)
    }
    
    // MARK: - Генерация текста от выбранного тренера
    public enum ReminderType: String {
        case meal = "meal"
        case water = "water"
        case activity = "activity"
    }
    
    private func notificationContent(for type: ReminderType, coach: AICoachPersona) -> (title: String, body: String) {
        let emoji = coach.badgeEmoji
        let name = coach.name
        
        switch type {
        case .meal:
            let titles = [
                "\(emoji) Тренер \(name) • Время подкрепиться",
                "\(emoji) \(name) • Контроль питания",
                "🥗 Поел ли ты? • \(name)"
            ]
            let bodies = [
                "Залогируй свой прием пищи через сканер или поиск, чтобы держать КБЖУ под контролем!",
                "Твоему телу нужна энергия для прогресса. Не забудь отметить еду в дневнике питания.",
                "Сделай фото тарелки — я рассчитаю калории и белки за секунду!",
                "Правильное питание — 80% успеха твоей формы. Что у тебя сегодня на обед?"
            ]
            return (titles.randomElement()!, bodies.randomElement()!)
            
        case .water:
            let titles = [
                "💧 Тренер \(name) • Водный баланс",
                "\(emoji) \(name) • Время для воды",
                "🥛 Попил ли ты воды? • \(name)"
            ]
            let bodies = [
                "Сделай глоток чистой воды прямо сейчас для отличного самочувствия и обмена веществ!",
                "Поддерживай гидратацию в течение дня. Выпей стакан воды и отметь в приложении 💧",
                "Мышцы на 75% состоят из воды. Не забывай пополнять водный баланс!",
                "Свежесть и энергия начинаются со стакана воды. Сделай паузу на пару глотков!"
            ]
            return (titles.randomElement()!, bodies.randomElement()!)
            
        case .activity:
            let titles = [
                "🏃‍♂️ Тренер \(name) • Разминка",
                "\(emoji) \(name) • Закрой кольца активности",
                "⚡ Время подвигаться • \(name)"
            ]
            let bodies = [
                "Встань и разомнись 2-3 минуты. Пройдись или сделай 15 легких приседаний!",
                "Твое тело создано для движения. Давай добавим шагов к дневной цели 🎯",
                "Сделай глубокий вдох, выпрями спину и разомни плечи!"
            ]
            return (titles.randomElement()!, bodies.randomElement()!)
        }
    }
}
