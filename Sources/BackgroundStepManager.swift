import SwiftUI
import CoreMotion
import Combine
import UserNotifications

// Почасовая структура данных для графика распределения шагов за день
public struct HourlyStepData: Identifiable, Equatable {
    public var id: Int { hour }
    public let hour: Int          // 0...23
    public let label: String      // "00:00", "04:00" etc.
    public var steps: Int
    
    public init(hour: Int, label: String, steps: Int) {
        self.hour = hour
        self.label = label
        self.steps = steps
    }
}

@MainActor
public class BackgroundStepManager: ObservableObject {
    public static let shared = BackgroundStepManager()
    
    // CoreMotion шагомер
    private let pedometer = CMPedometer()
    
    // Опубликованные свойства для UI
    @Published public var stepsToday: Int = 0
    @Published public var distanceMeters: Double = 0.0
    @Published public var floorsAscended: Int = 0
    @Published public var currentCadence: Double? = nil // шагов/сек
    @Published public var currentPace: Double? = nil    // сек/метр
    @Published public var hourlySteps: [HourlyStepData] = []
    
    @Published public var isPedometerAvailable: Bool = false
    @Published public var isLiveTrackingActive: Bool = false
    @Published public var lastSyncTime: Date? = nil
    
    // Настройки пользователя (синхронизируются с UserDefaults)
    @Published public var stepGoal: Int = 10000
    @Published public var isBackgroundTrackingEnabled: Bool = true
    @Published public var notificationsEnabled: Bool = true
    
    private var isQuerying = false
    
    private var todayKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    private init() {
        self.isPedometerAvailable = CMPedometer.isStepCountingAvailable()
        loadSettingsAndCachedData()
        generateEmptyHourlyData()
    }
    
    // MARK: - Инициализация и загрузка кэша
    
    public func loadSettingsAndCachedData() {
        let defaults = UserDefaults.standard
        
        let savedGoal = defaults.integer(forKey: "step_goal")
        self.stepGoal = savedGoal > 0 ? savedGoal : 10000
        
        if defaults.object(forKey: "background_step_tracking_enabled") != nil {
            self.isBackgroundTrackingEnabled = defaults.bool(forKey: "background_step_tracking_enabled")
        } else {
            self.isBackgroundTrackingEnabled = true
        }
        
        if defaults.object(forKey: "step_notifications_enabled") != nil {
            self.notificationsEnabled = defaults.bool(forKey: "step_notifications_enabled")
        } else {
            self.notificationsEnabled = true
        }
        
        // Загрузка кэшированных шагов за сегодня
        let cachedSteps = defaults.integer(forKey: "local_steps_\(todayKey)")
        if cachedSteps > 0 {
            self.stepsToday = cachedSteps
        }
        self.distanceMeters = defaults.double(forKey: "local_step_distance_\(todayKey)")
        self.floorsAscended = defaults.integer(forKey: "local_step_floors_\(todayKey)")
        
        if let lastSync = defaults.object(forKey: "local_last_step_sync") as? Date {
            self.lastSyncTime = lastSync
        }
    }
    
    private func generateEmptyHourlyData() {
        var list: [HourlyStepData] = []
        for h in 0..<24 {
            let label = String(format: "%02d:00", h)
            list.append(HourlyStepData(hour: h, label: label, steps: 0))
        }
        self.hourlySteps = list
    }
    
    // MARK: - Обработка изменений сцены (ScenePhase)
    
    public func handleScenePhaseChange(to phase: ScenePhase) {
        switch phase {
        case .active:
            // При возвращении в приложение считываем актуальные данные из сопроцессора и запускаем live updates
            Task {
                await refreshStepsFromPedometer()
                startLiveUpdates()
            }
        case .background:
            // При уходе в фон останавливаем живые обновления для экономии энергии
            stopLiveUpdates()
        case .inactive:
            break
        @unknown default:
            break
        }
    }
    
    // MARK: - Считывание шагов из CoreMotion CMPedometer
    
    public func refreshStepsFromPedometer() async {
        guard CMPedometer.isStepCountingAvailable() else { return }
        guard !isQuerying else { return }
        isQuerying = true
        defer { isQuerying = false }
        
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            pedometer.queryPedometerData(from: startOfDay, to: now) { [weak self] data, error in
                Task { @MainActor [weak self] in
                    guard let self = self else {
                        continuation.resume()
                        return
                    }
                    
                    if let data = data {
                        let steps = data.numberOfSteps.intValue
                        let distance = data.distance?.doubleValue ?? (Double(steps) * 0.75)
                        let floors = data.floorsAscended?.intValue ?? 0
                        
                        self.updateStepData(steps: steps, distance: distance, floors: floors, saveToHealthKitIfPossible: true)
                        await self.updateHourlyBreakdown(totalSteps: steps, now: now)
                    }
                    continuation.resume()
                }
            }
        }
    }
    
    // Живое обновление в реальном времени при открытом приложении
    public func startLiveUpdates() {
        guard CMPedometer.isStepCountingAvailable() else { return }
        guard !isLiveTrackingActive else { return }
        
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        isLiveTrackingActive = true
        
        pedometer.startUpdates(from: startOfDay) { [weak self] data, error in
            Task { @MainActor [weak self] in
                guard let self = self, self.isLiveTrackingActive else { return }
                if let data = data {
                    let steps = data.numberOfSteps.intValue
                    let distance = data.distance?.doubleValue ?? (Double(steps) * 0.75)
                    let floors = data.floorsAscended?.intValue ?? 0
                    
                    if let cadence = data.currentCadence?.doubleValue {
                        self.currentCadence = cadence
                    }
                    if let pace = data.currentPace?.doubleValue {
                        self.currentPace = pace
                    }
                    
                    self.updateStepData(steps: steps, distance: distance, floors: floors, saveToHealthKitIfPossible: false)
                }
            }
        }
    }
    
    public func stopLiveUpdates() {
        guard isLiveTrackingActive else { return }
        isLiveTrackingActive = false
        pedometer.stopUpdates()
    }
    
    // MARK: - Почасовая разбивка за сегодня
    
    private func updateHourlyBreakdown(totalSteps: Int, now: Date) async {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: now)
        let currentHour = min(23, max(0, calendar.component(.hour, from: now)))
        
        var realHourly: [Int: Int] = [:]
        
        if CMPedometer.isStepCountingAvailable() && totalSteps > 0 {
            for h in 0...currentHour {
                if let hourStart = calendar.date(byAdding: .hour, value: h, to: startOfDay),
                   let hourEnd = calendar.date(byAdding: .hour, value: h + 1, to: startOfDay) {
                    let endLimit = min(now, hourEnd)
                    if hourStart < endLimit {
                        let stepsInHour = await queryStepsForInterval(from: hourStart, to: endLimit)
                        if stepsInHour > 0 {
                            realHourly[h] = stepsInHour
                        }
                    }
                }
            }
        }
        
        let sumQueried = realHourly.values.reduce(0, +)
        
        var list: [HourlyStepData] = []
        for h in 0..<24 {
            let label = String(format: "%02d:00", h)
            if h > currentHour {
                list.append(HourlyStepData(hour: h, label: label, steps: 0))
            } else if sumQueried > 0, let realSteps = realHourly[h] {
                list.append(HourlyStepData(hour: h, label: label, steps: realSteps))
            } else {
                // Если нет интервальной детализации (симулятор/ограничения),
                // распределяем по естественной суточной кривой активности человека
                let weight: Double
                switch h {
                case 0...6: weight = 0.01   // Ночной покой
                case 7...9: weight = 0.15   // Утренняя активность / дорога
                case 10...12: weight = 0.08  // Рабочее утро
                case 13...14: weight = 0.18  // Обед / дневная прогулка
                case 15...17: weight = 0.09  // День
                case 18...20: weight = 0.20  // Вечерняя тренировка / возвращение
                case 21...23: weight = 0.05  // Вечерний отдых
                default: weight = 0.05
                }
                
                var passedWeights = 0.0
                for hr in 0...currentHour {
                    switch hr {
                    case 0...6: passedWeights += 0.01
                    case 7...9: passedWeights += 0.15
                    case 10...12: passedWeights += 0.08
                    case 13...14: passedWeights += 0.18
                    case 15...17: passedWeights += 0.09
                    case 18...20: passedWeights += 0.20
                    case 21...23: passedWeights += 0.05
                    default: passedWeights += 0.05
                    }
                }
                
                let ratio = passedWeights > 0 ? (weight / passedWeights) : 1.0 / Double(currentHour + 1)
                let estimatedSteps = max(0, Int(Double(totalSteps) * ratio))
                list.append(HourlyStepData(hour: h, label: label, steps: estimatedSteps))
            }
        }
        
        await MainActor.run {
            self.hourlySteps = list
        }
    }
    
    private func queryStepsForInterval(from start: Date, to end: Date) async -> Int {
        await withCheckedContinuation { continuation in
            pedometer.queryPedometerData(from: start, to: end) { data, _ in
                let steps = data?.numberOfSteps.intValue ?? 0
                continuation.resume(returning: steps)
            }
        }
    }
    
    // MARK: - Обновление состояния и проверка целей
    
    public func updateStepData(steps: Int, distance: Double, floors: Int, saveToHealthKitIfPossible: Bool) {
        guard steps >= self.stepsToday || self.stepsToday == 0 else { return }
        
        self.stepsToday = steps
        self.distanceMeters = distance
        self.floorsAscended = floors
        self.lastSyncTime = Date()
        
        // Сохранение в UserDefaults
        let defaults = UserDefaults.standard
        defaults.set(steps, forKey: "local_steps_\(todayKey)")
        defaults.set(distance, forKey: "local_step_distance_\(todayKey)")
        defaults.set(floors, forKey: "local_step_floors_\(todayKey)")
        defaults.set(Date(), forKey: "local_last_step_sync")
        
        // Проверка достижения целей и отправка локального пуш-уведомления
        if notificationsEnabled {
            checkAndSendGoalNotifications(steps: steps)
        }
    }
    
    // Синхронизация с HealthKit (если данные из HealthKit свежее)
    public func syncWithHealthKit(steps: Int) {
        if steps > self.stepsToday {
            self.stepsToday = steps
            let defaults = UserDefaults.standard
            defaults.set(steps, forKey: "local_steps_\(todayKey)")
            defaults.set(Date(), forKey: "local_last_step_sync")
            self.lastSyncTime = Date()
            
            if notificationsEnabled {
                checkAndSendGoalNotifications(steps: steps)
            }
        }
    }
    
    // MARK: - Настройки пользователя
    
    public func setStepGoal(_ newGoal: Int) {
        self.stepGoal = newGoal
        UserDefaults.standard.set(newGoal, forKey: "step_goal")
    }
    
    public func toggleBackgroundTracking(_ enabled: Bool) {
        self.isBackgroundTrackingEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "background_step_tracking_enabled")
    }
    
    public func toggleNotifications(_ enabled: Bool) {
        self.notificationsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "step_notifications_enabled")
        if enabled {
            requestNotificationPermission()
        }
    }
    
    // MARK: - Локальные мотивационные уведомления (100% Offline)
    
    public func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            Task { @MainActor in
                if !granted {
                    self.notificationsEnabled = false
                    UserDefaults.standard.set(false, forKey: "step_notifications_enabled")
                }
            }
        }
    }
    
    private func checkAndSendGoalNotifications(steps: Int) {
        let defaults = UserDefaults.standard
        let goal = self.stepGoal > 0 ? self.stepGoal : 10000
        let lang = defaults.string(forKey: "app_language") ?? "ru"
        
        // 1. Порог 50%
        let key50 = "notified_50_\(todayKey)"
        if steps >= goal / 2 && !defaults.bool(forKey: key50) {
            defaults.set(true, forKey: key50)
            let title = LocalizationManager.tr("notif_step_50_title", lang: lang)
            let body = String(format: LocalizationManager.tr("notif_step_50_body", lang: lang), steps, goal)
            sendLocalNotification(title: title, body: body, identifier: "step_goal_50")
        }
        
        // 2. Порог 80%
        let key80 = "notified_80_\(todayKey)"
        let step80 = Int(Double(goal) * 0.8)
        if steps >= step80 && !defaults.bool(forKey: key80) {
            defaults.set(true, forKey: key80)
            let title = LocalizationManager.tr("notif_step_80_title", lang: lang)
            let body = String(format: LocalizationManager.tr("notif_step_80_body", lang: lang), steps, goal)
            sendLocalNotification(title: title, body: body, identifier: "step_goal_80")
        }
        
        // 3. Порог 100%
        let key100 = "notified_100_\(todayKey)"
        if steps >= goal && !defaults.bool(forKey: key100) {
            defaults.set(true, forKey: key100)
            let title = LocalizationManager.tr("notif_step_100_title", lang: lang)
            let body = String(format: LocalizationManager.tr("notif_step_100_body", lang: lang), goal)
            sendLocalNotification(title: title, body: body, identifier: "step_goal_100")
        }
    }
    
    private func sendLocalNotification(title: String, body: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "\(identifier)_\(todayKey)",
            content: content,
            trigger: nil // Доставить немедленно
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("BackgroundStepManager: Ошибка отправки уведомления: \(error.localizedDescription)")
            }
        }
    }
}
