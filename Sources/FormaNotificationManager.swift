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
            let authorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            Task { @MainActor in
                let becameAuthorized = authorized && !self.isAuthorized
                self.isAuthorized = authorized
                // Разрешение выдают и из других мест (шаги, HealthKit), которые ничего не планируют:
                // без этого напоминания появлялись только после следующего запуска приложения.
                if becameAuthorized {
                    self.autoScheduleDefaultRemindersIfNeeded()
                }
            }
        }
    }
    
    /// Вызывать при каждом возврате в приложение: обновляет статус разрешения и обновляет план напоминаний.
    public func refreshOnForeground() {
        checkPermissionStatus()
        autoScheduleDefaultRemindersIfNeeded()
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
    
    // MARK: - Автоматическое планирование (идемпотентное: запросы с теми же идентификаторами заменяются)
    public func autoScheduleDefaultRemindersIfNeeded() {
        let coach = AICoachManager.shared.currentCoach
        let defaults = UserDefaults.standard
        
        func flag(_ key: String, default fallback: Bool) -> Bool {
            defaults.object(forKey: key) == nil ? fallback : defaults.bool(forKey: key)
        }
        func number(_ key: String, default fallback: Int) -> Int {
            defaults.object(forKey: key) == nil ? fallback : defaults.integer(forKey: key)
        }
        
        // Раньше здесь были жёстко заданные значения, и каждый запуск затирал настройки пользователя.
        // Ключи и значения по умолчанию — те же, что в Настройках.
        scheduleSmartReminders(
            mealEnabled: flag("notifications_meal_enabled", default: true),
            waterEnabled: flag("notifications_water_enabled", default: true),
            activityEnabled: flag("notifications_activity_enabled", default: true),
            isRandomTime: flag("notifications_random_time_enabled", default: true),
            startHour: number("notifications_start_hour", default: 9),
            endHour: number("notifications_end_hour", default: 21),
            frequencyPerDay: number("notifications_frequency_per_day", default: 5),
            coach: coach
        )
        scheduleAIDeficitNotifications(coach: coach)
        
        // Напоминания привычек стирались при каждом запуске и больше не создавались. Восстанавливаем.
        for habit in HabitsManager.shared.habits {
            scheduleHabitReminders(for: habit, coach: coach)
        }
    }
    
    // MARK: - Планирование умных напоминаний по привычкам (Habits)
    public func scheduleHabitReminders(for habit: HabitItem, coach: AICoachPersona) {
        let center = UNUserNotificationCenter.current()
        let baseId = "forma_habit_\(habit.id.uuidString)"
        
        // Удаляем старые запросы привычки и только потом добавляем новые — одной цепочкой. Раньше удаление
        // и добавление шли двумя независимыми асинхронными вызовами, и удаление иногда стирало свежее напоминание.
        center.getPendingNotificationRequests { requests in
            let idsToRemove = requests.filter { $0.identifier.starts(with: baseId) }.map { $0.identifier }
            if !idsToRemove.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: idsToRemove)
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
    //
    // Еда и вода — ежедневные повторяющиеся запросы: iOS доставляет их сама, приложение открывать не нужно.
    // Активность — скользящее окно разовых запросов (их можно отменить на сегодня, если шаги уже набраны).
    // Удаляются только СВОИ запросы; раньше здесь стоял removeAllPendingNotificationRequests(),
    // который стирал напоминания привычек и AI-итоги.
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
        let settings = SmartReminderSettings(
            mealEnabled: mealEnabled,
            waterEnabled: waterEnabled,
            activityEnabled: activityEnabled,
            startHour: startHour,
            endHour: endHour,
            frequencyPerDay: frequencyPerDay
        )
        
        center.getPendingNotificationRequests { pending in
            let stale = pending.map { $0.identifier }.filter(SmartReminderPlanner.isManagedIdentifier)
            if !stale.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: stale)
            }
            
            guard !settings.enabledKinds.isEmpty else { return }
            
            center.getNotificationSettings { notificationSettings in
                guard notificationSettings.authorizationStatus == .authorized
                        || notificationSettings.authorizationStatus == .provisional else { return }
                
                let plan = SmartReminderPlanner.plan(settings: settings, now: Date(), calendar: .current)
                for item in plan {
                    let type = ReminderType(rawValue: item.kind.rawValue) ?? .water
                    let (title, body) = self.notificationContent(for: type, coach: coach)
                    
                    let content = UNMutableNotificationContent()
                    content.sound = .default
                    content.title = title
                    content.body = body
                    content.badge = 1
                    
                    let components: DateComponents
                    let repeats: Bool
                    switch item.schedule {
                    case .daily(let hour, let minute):
                        components = DateComponents(hour: hour, minute: minute)
                        repeats = true
                    case .once(let year, let month, let day, let hour, let minute):
                        components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
                        repeats = false
                    }
                    
                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)
                    center.add(UNNotificationRequest(identifier: item.identifier, content: content, trigger: trigger))
                }
            }
        }
    }
    
    // MARK: - Умная фильтрация: отмена напоминаний об активности, если цель уже выполнена
    public func evaluateActivityReminders(currentSteps: Int) {
        // Если пройдено достаточно шагов (например, 5000), отменяем напоминания об активности НА СЕГОДНЯ
        if currentSteps >= 5000 {
            let center = UNUserNotificationCenter.current()
            let calendar = Calendar.current
            let now = Date()
            let year = calendar.component(.year, from: now)
            let month = calendar.component(.month, from: now)
            let day = calendar.component(.day, from: now)
            let todayString = String(format: "%04d%02d%02d", year, month, day)
            
            center.getPendingNotificationRequests { requests in
                let idsToRemove = requests.filter { request in
                    request.identifier.contains("forma_smart_reminder_\(todayString)_activity")
                }.map { $0.identifier }
                
                if !idsToRemove.isEmpty {
                    center.removePendingNotificationRequests(withIdentifiers: idsToRemove)
                }
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
            
        case .aiDeficit:
            let titles = [
                "⚡️ ИИ-анализ калорий и активности",
                "🎯 Рекомендация тренера \(coach.name)",
                "🔥 Баланс дефицита калорий — Forma"
            ]
            let bodies = [
                "Ваша активность сегодня изменилась. Загляните за персональным советом по питанию!",
                "ИИ проанализировал ваши шаги и тренировки. Узнайте обновленный прогноз дефицита.",
                "Отличный прогресс в движении! Посмотрите персональную рекомендацию от тренера."
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
    
    // MARK: - Умные AI-уведомления анализа активности и дефицита калорий
    public func scheduleAIDeficitNotifications(coach: AICoachPersona? = nil) {
        let center = UNUserNotificationCenter.current()
        let targetCoach = coach ?? AICoachManager.shared.currentCoach
        let defaults = UserDefaults.standard
        
        let isEnabled = defaults.object(forKey: "ai_deficit_notifications_enabled") != nil 
            ? defaults.bool(forKey: "ai_deficit_notifications_enabled") 
            : true
        
        // Сначала удаляем существующие запросы этого типа, и только потом добавляем — одной цепочкой.
        // Раньше удаление по префиксу "forma_ai_deficit_" шло параллельно с добавлением и могло стереть
        // только что созданные дневной и вечерний итоги.
        center.getPendingNotificationRequests { requests in
            let toRemove = requests.filter { $0.identifier.starts(with: "forma_ai_deficit_") }.map { $0.identifier }
            if !toRemove.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: toRemove)
            }
            
            guard isEnabled else { return }
            
            center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            
            // 1. Дневной чекпоинт (14:00) — срез пройденных шагов и планирование калорий на день
            let contentMidday = UNMutableNotificationContent()
            contentMidday.title = "⚡️ Дневной срез активности • \(targetCoach.name)"
            contentMidday.body = "ИИ проанализировал ваши утренние шаги и активность. Зайдите в Forma оценить текущий дефицит калорий до ужина!"
            contentMidday.sound = .default
            contentMidday.badge = 1
            
            var dateMidday = DateComponents()
            dateMidday.hour = 14
            dateMidday.minute = 0
            
            let triggerMidday = UNCalendarNotificationTrigger(dateMatching: dateMidday, repeats: true)
            let reqMidday = UNNotificationRequest(identifier: "forma_ai_deficit_midday", content: contentMidday, trigger: triggerMidday)
            center.add(reqMidday)
            
            // 2. Вечерний итог (20:30) — итог тренировок, шагов и финальный дефицит/профицит
            let contentEvening = UNMutableNotificationContent()
            contentEvening.title = "🔥 Итог дефицита калорий • \(targetCoach.name)"
            contentEvening.body = "ИИ подвел итоги тренировок и расхода за день. Узнайте, выполнен ли целевой дефицит калорий!"
            contentEvening.sound = .default
            contentEvening.badge = 1
            
            var dateEvening = DateComponents()
            dateEvening.hour = 20
            dateEvening.minute = 30
            
            let triggerEvening = UNCalendarNotificationTrigger(dateMatching: dateEvening, repeats: true)
            let reqEvening = UNNotificationRequest(identifier: "forma_ai_deficit_evening", content: contentEvening, trigger: triggerEvening)
            center.add(reqEvening)
            }
        }
    }
    
    public func removeAIDeficitNotifications() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let toRemove = requests.filter { $0.identifier.starts(with: "forma_ai_deficit_") }.map { $0.identifier }
            if !toRemove.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: toRemove)
            }
        }
    }
    
    public func sendTestAIDeficitNotification(coach: AICoachPersona? = nil) {
        let targetCoach = coach ?? AICoachManager.shared.currentCoach
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.title = "⚡️ AI-Анализ активности • \(targetCoach.name)"
        content.body = "Тренер \(targetCoach.name): Отличный темп активности за сегодня! Шаги и тренировки учтены, дефицит рассчитан."
        content.badge = 1
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.5, repeats: false)
        let request = UNNotificationRequest(
            identifier: "forma_ai_deficit_test_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }
    
    public enum ReminderType: String, CaseIterable, Codable {
        case water = "water"
        case meal = "meal"
        case activity = "activity"
        case aiDeficit = "aiDeficit"
    }
}
