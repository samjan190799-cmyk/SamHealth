import SwiftUI
import Combine
import HealthKit
import UIKit
import UserNotifications

@MainActor
public class HealthKitManager: ObservableObject {
    
    // MARK: - Состояние авторизации и синхронизации
    @Published public var isAuthorized: Bool = UserDefaults.standard.bool(forKey: "HealthKitRequested")
    @Published public var isRequested: Bool = UserDefaults.standard.bool(forKey: "HealthKitRequested")
    @Published public var isSyncing = false
    @Published public var lastSyncTime: Date? = nil
    @Published public var authorizationError: String? = nil
    @Published public var isHealthDataAvailable: Bool = HKHealthStore.isHealthDataAvailable()
    
    // MARK: - Экспресс-замер пульса в реальном времени (AirPods Pro / Датчики)
    @Published public var isLiveHeartRateActive: Bool = false
    @Published public var liveHeartRate: Int = 0
    @Published public var liveHeartRateSamples: [Int] = []
    private var liveQueryTask: Task<Void, Never>? = nil
    
    // MARK: - Активность (Кольца Apple Watch)
    @Published public var activeEnergyBurned: Double = 0.0 // ккал
    @Published public var activeEnergyGoal: Double = 800.0 // Цель ккал
    @Published public var exerciseTime: Double = 0.0 // мин
    @Published public var exerciseGoal: Double = 60.0 // Цель мин
    @Published public var standHours: Double = 0.0 // ч
    @Published public var standGoal: Double = 12.0 // Цель ч
    
    // MARK: - Шаги и дистанция
    @Published public var stepsToday: Int = 0
    @Published public var distanceMetersToday: Double = 0.0
    @Published public var weeklySteps: [WeeklyStepsData] = []
    
    // MARK: - Здоровье, Пульс и AirPods Pro
    @Published public var heartRate: Int = 0 // уд/мин (текущий/последний)
    @Published public var restingHeartRate: Int = 0 // уд/мин (в покое)
    @Published public var heartRateZone: HeartRateZone = .rest
    @Published public var heartRateTrend: HeartRateTrendType = .stable
    @Published public var lastHeartRateSampleDate: Date? = nil
    
    // Настройки мониторинга пульса и алертов
    @Published public var isHeartRateMonitoringEnabled: Bool = true
    @Published public var heartRateAlertsEnabled: Bool = true
    @Published public var highHeartRateThreshold: Int = 105 // Порог тахикардии в покое (уд/мин)
    @Published public var lowHeartRateThreshold: Int = 48  // Порог брадикардии (уд/мин)
    @Published public var recoveryAlertsEnabled: Bool = true // Уведомления об успешном восстановлении
    
    // MARK: - Сон
    @Published public var sleepDuration: Double = 0.0 // ч (общее время сна)
    @Published public var deepSleepDuration: Double = 0.0 // ч (глубокий сон)
    
    // MARK: - Водный баланс
    @Published public var waterConsumed: Double = 0.0 // мл
    @Published public var waterGoal: Double = 3000.0 // мл (3.0 L)
    
    // MARK: - Вес и композиция тела
    @Published public var currentWeight: Double = 0.0 // кг
    @Published public var weightTrend: WeightTrendType = .stable
    
    // MARK: - Тренировки и калории
    @Published public var lastWorkoutString: String = "Нет данных"
    @Published public var caloriesConsumedToday: Double = 0.0
    @Published public var proteinConsumedToday: Double = 0.0
    @Published public var fatConsumedToday: Double = 0.0
    @Published public var carbsConsumedToday: Double = 0.0
    @Published public var calorieGoal: Double = 2200.0
    
    // MARK: - История здоровья
    @Published public var weightHistory: [WeightRecord] = []
    @Published public var workoutHistory: [WorkoutRecord] = []
    @Published public var nutritionHistory: [DailyNutritionRecord] = []
    
    private let healthStore = HKHealthStore()
    
    // Защита от спама уведомлениями (кулдауны)
    private var lastAlertTimestamps: [String: Date] = [:]
    private var lastWorkoutEndTime: Date? = nil
    private var preWorkoutHeartRate: Int = 70
    
    private var todayKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    public init() {
        let dataVersion = UserDefaults.standard.integer(forKey: "AppDataVersion")
        if dataVersion < 4 {
            UserDefaults.standard.set(4, forKey: "AppDataVersion")
        }
        
        setupDefaultMockData()
        loadLocalData()
        
        if let savedSyncTime = UserDefaults.standard.object(forKey: "health_last_sync_time") as? Date {
            self.lastSyncTime = savedSyncTime
        }
        
        if HKHealthStore.isHealthDataAvailable() {
            self.isRequested = true
            self.isAuthorized = true
            UserDefaults.standard.set(true, forKey: "HealthKitRequested")
            UserDefaults.standard.set(true, forKey: "health_is_authorized")
            setupBackgroundDelivery()
            fetchAllData()
        }
    }
    
    // MARK: - Инициализация дефолтных данных
    private func setupDefaultMockData() {
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "MockDataInitialized") {
            defaults.set(0.0, forKey: "local_water_\(todayKey)")
            defaults.set(3000.0, forKey: "local_water_goal")
            defaults.set(0, forKey: "local_steps_\(todayKey)")
            defaults.set(0.0, forKey: "local_distance_\(todayKey)")
            defaults.set(0.0, forKey: "local_calories_\(todayKey)")
            defaults.set(0.0, forKey: "local_exercise_\(todayKey)")
            defaults.set(0.0, forKey: "local_stand_\(todayKey)")
            defaults.set(7.5, forKey: "local_sleep")
            defaults.set(70, forKey: "local_heart_rate")
            defaults.set(0.0, forKey: "local_weight")
            defaults.set("", forKey: "local_last_workout")
            
            // Дефолтные настройки мониторинга пульса
            defaults.set(true, forKey: "hr_bg_monitoring_enabled")
            defaults.set(true, forKey: "hr_alerts_enabled")
            defaults.set(105, forKey: "hr_high_threshold")
            defaults.set(48, forKey: "hr_low_threshold")
            defaults.set(true, forKey: "hr_recovery_enabled")
            
            let weeklyData: [[String: Any]] = [
                ["day": "Пн", "steps": 0],
                ["day": "Вт", "steps": 0],
                ["day": "Ср", "steps": 0],
                ["day": "Чт", "steps": 0],
                ["day": "Пт", "steps": 0],
                ["day": "Сб", "steps": 0],
                ["day": "Вс", "steps": 0]
            ]
            if let data = try? JSONSerialization.data(withJSONObject: weeklyData) {
                defaults.set(data, forKey: "local_weekly_steps")
            }
            
            defaults.set(true, forKey: "MockDataInitialized")
        }
    }
    
    // MARK: - Загрузка локальных данных
    public func loadLocalData() {
        let defaults = UserDefaults.standard
        
        if defaults.bool(forKey: "HealthKitRequested") || defaults.bool(forKey: "health_is_authorized") {
            self.isAuthorized = true
            self.isRequested = true
        }
        
        let savedDay = defaults.string(forKey: "local_last_active_day") ?? ""
        if savedDay != todayKey {
            defaults.set(0.0, forKey: "local_water_\(todayKey)")
            defaults.set(0, forKey: "local_steps_\(todayKey)")
            defaults.set(0.0, forKey: "local_distance_\(todayKey)")
            defaults.set(0.0, forKey: "local_calories_\(todayKey)")
            defaults.set(0.0, forKey: "local_exercise_\(todayKey)")
            defaults.set(0.0, forKey: "local_stand_\(todayKey)")
            defaults.set(0.0, forKey: "local_nutrition_calories_\(todayKey)")
            defaults.set(todayKey, forKey: "local_last_active_day")
        }
        
        self.waterConsumed = defaults.double(forKey: "local_water_\(todayKey)")
        self.waterGoal = defaults.double(forKey: "local_water_goal") > 0 ? defaults.double(forKey: "local_water_goal") : 3000.0
        self.stepsToday = defaults.integer(forKey: "local_steps_\(todayKey)")
        self.distanceMetersToday = defaults.double(forKey: "local_distance_\(todayKey)")
        self.activeEnergyBurned = defaults.double(forKey: "local_calories_\(todayKey)")
        self.exerciseTime = defaults.double(forKey: "local_exercise_\(todayKey)")
        self.standHours = defaults.double(forKey: "local_stand_\(todayKey)")
        self.sleepDuration = defaults.double(forKey: "local_sleep") > 0 ? defaults.double(forKey: "local_sleep") : 7.5
        self.heartRate = defaults.integer(forKey: "local_heart_rate") > 0 ? defaults.integer(forKey: "local_heart_rate") : 70
        self.currentWeight = defaults.double(forKey: "local_weight")
        self.lastWorkoutString = defaults.string(forKey: "local_last_workout") ?? "Нет данных"
        self.caloriesConsumedToday = defaults.double(forKey: "local_nutrition_calories_\(todayKey)")
        
        // Настройки мониторинга пульса
        if defaults.object(forKey: "hr_bg_monitoring_enabled") != nil {
            self.isHeartRateMonitoringEnabled = defaults.bool(forKey: "hr_bg_monitoring_enabled")
        }
        if defaults.object(forKey: "hr_alerts_enabled") != nil {
            self.heartRateAlertsEnabled = defaults.bool(forKey: "hr_alerts_enabled")
        }
        let savedHighThreshold = defaults.integer(forKey: "hr_high_threshold")
        self.highHeartRateThreshold = savedHighThreshold > 0 ? savedHighThreshold : 105
        
        let savedLowThreshold = defaults.integer(forKey: "hr_low_threshold")
        self.lowHeartRateThreshold = savedLowThreshold > 0 ? savedLowThreshold : 48
        
        if defaults.object(forKey: "hr_recovery_enabled") != nil {
            self.recoveryAlertsEnabled = defaults.bool(forKey: "hr_recovery_enabled")
        }
        
        let age = defaults.integer(forKey: "user_age")
        self.heartRateZone = HeartRateZone.zone(for: self.heartRate, age: age > 0 ? age : 25)
        
        if let data = defaults.data(forKey: "local_weekly_steps"),
           let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            self.weeklySteps = json.compactMap { dict in
                guard let day = dict["day"] as? String, let steps = dict["steps"] as? Int else { return nil }
                return WeeklyStepsData(day: day, steps: steps)
            }
        }
        
        if let data = defaults.data(forKey: "local_weight_history"),
           let history = try? JSONDecoder().decode([WeightRecord].self, from: data) {
            self.weightHistory = history
        }
        if let data = defaults.data(forKey: "local_workout_history"),
           let history = try? JSONDecoder().decode([WorkoutRecord].self, from: data) {
            self.workoutHistory = history
        }
        if let data = defaults.data(forKey: "local_nutrition_history"),
           let history = try? JSONDecoder().decode([DailyNutritionRecord].self, from: data) {
            self.nutritionHistory = history
        }
        self.proteinConsumedToday = defaults.double(forKey: "local_nutrition_protein_\(todayKey)")
        self.fatConsumedToday = defaults.double(forKey: "local_nutrition_fat_\(todayKey)")
        self.carbsConsumedToday = defaults.double(forKey: "local_nutrition_carbs_\(todayKey)")
    }
    
    // MARK: - Сохранение локальных данных
    public func saveLocalData() {
        let defaults = UserDefaults.standard
        defaults.set(self.waterConsumed, forKey: "local_water_\(todayKey)")
        defaults.set(self.stepsToday, forKey: "local_steps_\(todayKey)")
        defaults.set(self.distanceMetersToday, forKey: "local_distance_\(todayKey)")
        defaults.set(self.activeEnergyBurned, forKey: "local_calories_\(todayKey)")
        defaults.set(self.exerciseTime, forKey: "local_exercise_\(todayKey)")
        defaults.set(self.standHours, forKey: "local_stand_\(todayKey)")
        defaults.set(self.sleepDuration, forKey: "local_sleep")
        defaults.set(self.heartRate, forKey: "local_heart_rate")
        defaults.set(self.currentWeight, forKey: "local_weight")
        defaults.set(self.lastWorkoutString, forKey: "local_last_workout")
        defaults.set(self.caloriesConsumedToday, forKey: "local_nutrition_calories_\(todayKey)")
        defaults.set(self.proteinConsumedToday, forKey: "local_nutrition_protein_\(todayKey)")
        defaults.set(self.fatConsumedToday, forKey: "local_nutrition_fat_\(todayKey)")
        defaults.set(self.carbsConsumedToday, forKey: "local_nutrition_carbs_\(todayKey)")
        
        defaults.set(self.isHeartRateMonitoringEnabled, forKey: "hr_bg_monitoring_enabled")
        defaults.set(self.heartRateAlertsEnabled, forKey: "hr_alerts_enabled")
        defaults.set(self.highHeartRateThreshold, forKey: "hr_high_threshold")
        defaults.set(self.lowHeartRateThreshold, forKey: "hr_low_threshold")
        defaults.set(self.recoveryAlertsEnabled, forKey: "hr_recovery_enabled")
        
        var stepsList = self.weeklySteps
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EE"
        let todayName = formatter.string(from: Date()).capitalized
        
        if let idx = stepsList.firstIndex(where: { $0.day == todayName }) {
            stepsList[idx] = WeeklyStepsData(day: todayName, steps: self.stepsToday)
        } else {
            stepsList.append(WeeklyStepsData(day: todayName, steps: self.stepsToday))
        }
        self.weeklySteps = stepsList
        
        let rawArray = stepsList.map { ["day": $0.day, "steps": $0.steps] }
        if let data = try? JSONSerialization.data(withJSONObject: rawArray) {
            defaults.set(data, forKey: "local_weekly_steps")
        }
        
        if let data = try? JSONEncoder().encode(self.weightHistory) {
            defaults.set(data, forKey: "local_weight_history")
        }
        if let data = try? JSONEncoder().encode(self.workoutHistory) {
            defaults.set(data, forKey: "local_workout_history")
        }
        if let data = try? JSONEncoder().encode(self.nutritionHistory) {
            defaults.set(data, forKey: "local_nutrition_history")
        }
    }
    
    // MARK: - Запрос авторизации в HealthKit (Modern Swift Concurrency)
    public func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            self.authorizationError = "HealthKit не поддерживается на этом устройстве"
            self.isAuthorized = false
            self.isRequested = true
            return
        }
        
        guard let steps = HKQuantityType.quantityType(forIdentifier: .stepCount),
              let distance = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning),
              let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
              let exerciseTime = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime),
              let standHour = HKCategoryType.categoryType(forIdentifier: .appleStandHour),
              let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate),
              let restingHeartRate = HKQuantityType.quantityType(forIdentifier: .restingHeartRate),
              let sleep = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis),
              let water = HKQuantityType.quantityType(forIdentifier: .dietaryWater),
              let weight = HKQuantityType.quantityType(forIdentifier: .bodyMass),
              let dietaryEnergy = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) else {
            self.authorizationError = "Не удалось подготовить типы данных HealthKit"
            self.isRequested = true
            return
        }
        
        let typesToRead: Set<HKObjectType> = [
            steps, distance, activeEnergy, exerciseTime, standHour, heartRate, restingHeartRate, sleep, water, weight, dietaryEnergy, HKObjectType.workoutType()
        ]
        
        let typesToWrite: Set<HKSampleType> = [
            water, weight, dietaryEnergy, HKObjectType.workoutType()
        ]
        
        // Сразу активируем флаги авторизации
        self.isAuthorized = true
        self.isRequested = true
        UserDefaults.standard.set(true, forKey: "HealthKitRequested")
        UserDefaults.standard.set(true, forKey: "health_is_authorized")
        
        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.isAuthorized = true
                self?.isRequested = true
                self?.setupBackgroundDelivery()
                self?.fetchAllData()
                self?.requestNotificationPermissions()
            }
        }
        
        self.setupBackgroundDelivery()
        self.fetchAllData()
    }
    
    // MARK: - Настройка фоновой доставки данных HealthKit
    public func setupBackgroundDelivery() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        // 1. Фоновая доставка шагов
        if let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            healthStore.enableBackgroundDelivery(for: stepType, frequency: .immediate) { _, _ in }
            
            let stepObserver = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, completionHandler, _ in
                Task { @MainActor [weak self] in
                    guard let self = self else {
                        completionHandler()
                        return
                    }
                    let latestSteps = await self.fetchSteps()
                    if latestSteps > 0 {
                        self.stepsToday = max(self.stepsToday, latestSteps)
                        self.saveLocalData()
                        BackgroundStepManager.shared.syncWithHealthKit(steps: latestSteps)
                    }
                    completionHandler()
                }
            }
            healthStore.execute(stepObserver)
        }
        
        // 2. Фоновый мониторинг пульса с AirPods Pro / Датчиков
        setupHeartRateObserver()
    }
    
    // MARK: - Непрерывный мониторинг пульса с AirPods Pro
    public func setupHeartRateObserver() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        
        healthStore.enableBackgroundDelivery(for: heartRateType, frequency: .immediate) { success, error in
            if let error = error {
                print("HealthKit: Ошибка включения фоновой доставки пульса: \(error.localizedDescription)")
            }
        }
        
        let hrObserver = HKObserverQuery(sampleType: heartRateType, predicate: nil) { [weak self] _, completionHandler, error in
            if let error = error {
                print("HealthKit HR Observer error: \(error.localizedDescription)")
                completionHandler()
                return
            }
            
            Task { @MainActor [weak self] in
                guard let self = self, self.isHeartRateMonitoringEnabled else {
                    completionHandler()
                    return
                }
                
                await self.fetchAndProcessLatestHeartRate()
                completionHandler()
            }
        }
        
        healthStore.execute(hrObserver)
    }
    
    // MARK: - Экспресс-замер пульса в реальном времени (AirPods Pro / Датчики)
    public func startLiveHeartRateSession() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        self.isLiveHeartRateActive = true
        if self.heartRate > 0 {
            self.liveHeartRate = self.heartRate
            self.liveHeartRateSamples = [self.heartRate]
        } else {
            self.liveHeartRate = 72
            self.liveHeartRateSamples = [72]
        }
        
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        liveQueryTask?.cancel()
        liveQueryTask = Task { @MainActor in
            while !Task.isCancelled && self.isLiveHeartRateActive {
                await self.fetchAndProcessLatestHeartRate()
                if self.heartRate > 0 {
                    self.liveHeartRate = self.heartRate
                    self.liveHeartRateSamples.append(self.heartRate)
                    if self.liveHeartRateSamples.count > 15 {
                        self.liveHeartRateSamples.removeFirst()
                    }
                }
                let feedback = UIImpactFeedbackGenerator(style: .soft)
                feedback.impactOccurred()
                try? await Task.sleep(nanoseconds: 1_500_000_000) // каждые 1.5 сек
            }
        }
    }
    
    public func stopLiveHeartRateSession() {
        self.isLiveHeartRateActive = false
        liveQueryTask?.cancel()
        liveQueryTask = nil
        let impact = UINotificationFeedbackGenerator()
        impact.notificationOccurred(.success)
    }
    
    // Обработка поступающего замера пульса
    public func fetchAndProcessLatestHeartRate() async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let sample: (bpm: Int, date: Date)? = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                if let s = samples?.first as? HKQuantitySample {
                    let rate = Int(s.quantity.doubleValue(for: HKUnit(from: "count/min")))
                    continuation.resume(returning: (rate, s.startDate))
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
        
        guard let sample = sample, sample.bpm > 0 else { return }
        
        let prevBpm = self.heartRate
        self.heartRate = sample.bpm
        self.lastHeartRateSampleDate = sample.date
        
        let age = UserDefaults.standard.integer(forKey: "user_age")
        self.heartRateZone = HeartRateZone.zone(for: sample.bpm, age: age > 0 ? age : 25)
        
        if prevBpm > 0 {
            let diff = sample.bpm - prevBpm
            if diff >= 5 {
                self.heartRateTrend = .rising
            } else if diff <= -5 {
                self.heartRateTrend = .falling
            } else {
                self.heartRateTrend = .stable
            }
        }
        
        self.saveLocalData()
        
        // Анализ ухудшения/улучшения и отправка уведомлений
        analyzeHeartRateSample(bpm: sample.bpm, date: sample.date)
    }
    
    // Логика обнаружения аномалий и восстановления пульса
    private func analyzeHeartRateSample(bpm: Int, date: Date) {
        guard isHeartRateMonitoringEnabled else { return }
        
        let defaults = UserDefaults.standard
        let lang = defaults.string(forKey: "app_language") ?? "ru"
        let now = Date()
        
        // 1. Проверка на быстрое восстановление после тренировки
        if recoveryAlertsEnabled, let workoutEnd = lastWorkoutEndTime {
            let secondsSinceWorkout = now.timeIntervalSince(workoutEnd)
            // Если тренировка завершилась менее 5 минут назад и пульс снизился до нормы (< 85 уд/мин или упал на 25+ уд/мин)
            if secondsSinceWorkout < 300 && bpm < 85 {
                let recoveryKey = "recovery_alert_\(Int(workoutEnd.timeIntervalSince1970))"
                if !defaults.bool(forKey: recoveryKey) {
                    defaults.set(true, forKey: recoveryKey)
                    self.heartRateTrend = .recovered
                    
                    let title = LocalizationManager.tr("hr_notif_recovery_title", lang: lang)
                    let body = String(format: LocalizationManager.tr("hr_notif_recovery_body", lang: lang), bpm)
                    sendHeartRateNotification(title: title, body: body, identifier: "hr_recovery")
                }
            }
        }
        
        // 2. Предупреждение о высоком пульсе в покое (Тахикардия / Стресс)
        if heartRateAlertsEnabled && bpm >= highHeartRateThreshold {
            let cooldownKey = "high_hr_alert"
            if canSendAlert(for: cooldownKey, intervalSeconds: 1200) { // Не чаще раза в 20 минут
                lastAlertTimestamps[cooldownKey] = now
                self.heartRateTrend = .spike
                
                let title = LocalizationManager.tr("hr_notif_high_title", lang: lang)
                let body = String(format: LocalizationManager.tr("hr_notif_high_body", lang: lang), bpm)
                sendHeartRateNotification(title: title, body: body, identifier: "hr_high_alert")
            }
        }
        
        // 3. Предупреждение о критически низком пульсе (Брадикардия)
        if heartRateAlertsEnabled && bpm <= lowHeartRateThreshold {
            let cooldownKey = "low_hr_alert"
            if canSendAlert(for: cooldownKey, intervalSeconds: 1800) { // Не чаще раза в 30 минут
                lastAlertTimestamps[cooldownKey] = now
                
                let title = LocalizationManager.tr("hr_notif_low_title", lang: lang)
                let body = String(format: LocalizationManager.tr("hr_notif_low_body", lang: lang), bpm)
                sendHeartRateNotification(title: title, body: body, identifier: "hr_low_alert")
            }
        }
    }
    
    private func canSendAlert(for key: String, intervalSeconds: TimeInterval) -> Bool {
        guard let lastTime = lastAlertTimestamps[key] else { return true }
        return Date().timeIntervalSince(lastTime) >= intervalSeconds
    }
    
    // Запрос прав на уведомления
    public func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
    
    // Отправка локального уведомления о пульсе
    private func sendHeartRateNotification(title: String, body: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "\(identifier)_\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil // Немедленная доставка
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("HealthKitManager: Ошибка отправки уведомления пульса: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Получение всех свежих данных из HealthKit
    public func fetchAllData() {
        loadLocalData()
        
        guard HKHealthStore.isHealthDataAvailable() else {
            return
        }
        
        self.isSyncing = true
        
        Task {
            async let steps = fetchSteps()
            async let distance = fetchDistance()
            async let calories = fetchActiveEnergy()
            async let exercise = fetchExerciseTime()
            async let stand = fetchStandHours()
            async let heart = fetchLatestHeartRate()
            async let restingHeart = fetchRestingHeartRate()
            async let sleep = fetchSleepDuration()
            async let water = fetchWaterConsumed()
            async let weight = fetchLatestWeight()
            async let workouts = fetchWorkoutHistoryFromHealthKit()
            
            let fetchedSteps = await steps
            let fetchedDistance = await distance
            let fetchedCalories = await calories
            let fetchedExercise = await exercise
            let fetchedStand = await stand
            let fetchedHeart = await heart
            let fetchedRestingHeart = await restingHeart
            let (fetchedSleep, fetchedDeepSleep) = await sleep
            let fetchedWater = await water
            let fetchedWeight = await weight
            let fetchedWorkouts = await workouts
            
            await MainActor.run {
                if fetchedSteps > 0 {
                    self.stepsToday = fetchedSteps
                    BackgroundStepManager.shared.syncWithHealthKit(steps: fetchedSteps)
                }
                if fetchedDistance > 0 { self.distanceMetersToday = fetchedDistance }
                if fetchedCalories > 0 { self.activeEnergyBurned = fetchedCalories }
                if fetchedExercise > 0 { self.exerciseTime = fetchedExercise }
                if fetchedStand > 0 { self.standHours = fetchedStand }
                if fetchedHeart > 0 {
                    self.heartRate = fetchedHeart
                    let age = UserDefaults.standard.integer(forKey: "user_age")
                    self.heartRateZone = HeartRateZone.zone(for: fetchedHeart, age: age > 0 ? age : 25)
                }
                if fetchedRestingHeart > 0 { self.restingHeartRate = fetchedRestingHeart }
                if fetchedSleep > 0 { self.sleepDuration = fetchedSleep }
                if fetchedDeepSleep > 0 { self.deepSleepDuration = fetchedDeepSleep }
                if fetchedWater > 0 { self.waterConsumed = fetchedWater }
                
                if fetchedWeight > 0 {
                    if fetchedWeight != self.currentWeight {
                        self.addWeightRecordLocally(weight: fetchedWeight)
                    }
                }
                
                if !fetchedWorkouts.isEmpty {
                    self.workoutHistory = fetchedWorkouts
                    if let last = fetchedWorkouts.first {
                        let formatter = DateFormatter()
                        formatter.locale = Locale(identifier: "ru_RU")
                        formatter.dateFormat = "d MMM"
                        self.lastWorkoutString = "\(last.durationMinutes) мин — \(last.type)\n(\(formatter.string(from: last.date)))"
                    }
                }
                
                self.lastSyncTime = Date()
                UserDefaults.standard.set(self.lastSyncTime, forKey: "health_last_sync_time")
                self.isSyncing = false
                self.saveLocalData()
            }
            
            let fetchedWeekly = await fetchWeeklyStepsFromHealthKit()
            await MainActor.run {
                if !fetchedWeekly.isEmpty {
                    self.weeklySteps = fetchedWeekly
                }
            }
        }
    }
    
    // Синхронизация с тактильной отдачей
    public func syncAllWithHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        fetchAllData()
    }
    
    // Открытие настроек системы iOS
    public func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
    
    // MARK: - Вспомогательные методы чтения данных
    
    private func fetchSteps() async -> Int {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }
        let now = Date()
        let start = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let steps = result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
                continuation.resume(returning: Int(steps))
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchDistance() async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else { return 0.0 }
        let now = Date()
        let start = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let meters = result?.sumQuantity()?.doubleValue(for: HKUnit.meter()) ?? 0.0
                continuation.resume(returning: meters)
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchActiveEnergy() async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return 0.0 }
        let now = Date()
        let start = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let kcal = result?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) ?? 0.0
                continuation.resume(returning: kcal)
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchExerciseTime() async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) else { return 0.0 }
        let now = Date()
        let start = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let minutes = result?.sumQuantity()?.doubleValue(for: HKUnit.minute()) ?? 0.0
                continuation.resume(returning: minutes)
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchStandHours() async -> Double {
        guard let type = HKCategoryType.categoryType(forIdentifier: .appleStandHour) else { return 0.0 }
        let now = Date()
        let start = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                guard let categorySamples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: 0.0)
                    return
                }
                let stoodHours = categorySamples.filter { $0.value == HKCategoryValueAppleStandHour.stood.rawValue }
                let uniqueHours = Set(stoodHours.map { Calendar.current.component(.hour, from: $0.startDate) })
                continuation.resume(returning: Double(uniqueHours.count))
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchLatestHeartRate() async -> Int {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return 0 }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                if let sample = samples?.first as? HKQuantitySample {
                    let rate = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                    continuation.resume(returning: Int(rate))
                } else {
                    continuation.resume(returning: 0)
                }
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchRestingHeartRate() async -> Int {
        guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return 0 }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                if let sample = samples?.first as? HKQuantitySample {
                    let rate = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                    continuation.resume(returning: Int(rate))
                } else {
                    continuation.resume(returning: 0)
                }
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchSleepDuration() async -> (total: Double, deep: Double) {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return (0.0, 0.0) }
        let now = Date()
        let startOfYesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let predicate = HKQuery.predicateForSamples(withStart: startOfYesterday, end: now, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                guard let categorySamples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: (0.0, 0.0))
                    return
                }
                let asleepSamples = categorySamples.filter {
                    $0.value == HKCategoryValueSleepAnalysis.asleep.rawValue ||
                    $0.value == 6 || // asleepDeep
                    $0.value == 7 || // asleepREM
                    $0.value == 8    // asleepCore
                }
                let deepSamples = categorySamples.filter { $0.value == 6 }
                
                let totalSeconds = asleepSamples.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                let deepSeconds = deepSamples.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                
                continuation.resume(returning: (totalSeconds / 3600.0, deepSeconds / 3600.0))
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchWaterConsumed() async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else { return 0.0 }
        let now = Date()
        let start = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let milliliters = result?.sumQuantity()?.doubleValue(for: HKUnit.literUnit(with: .milli)) ?? 0.0
                continuation.resume(returning: milliliters)
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchLatestWeight() async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return 0.0 }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                if let sample = samples?.first as? HKQuantitySample {
                    let weight = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                    continuation.resume(returning: weight)
                } else {
                    continuation.resume(returning: 0.0)
                }
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchWeeklyStepsFromHealthKit() async -> [WeeklyStepsData] {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return [] }
        let calendar = Calendar.current
        let now = Date()
        var weeklyData: [WeeklyStepsData] = []
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EE"
        
        for i in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -i, to: now) else { continue }
            let start = calendar.startOfDay(for: date)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let dayName = formatter.string(from: start).capitalized
            
            let steps = await withCheckedContinuation { continuation in
                let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                    let val = result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0.0
                    continuation.resume(returning: Int(val))
                }
                healthStore.execute(query)
            }
            weeklyData.append(WeeklyStepsData(day: dayName, steps: steps))
        }
        return weeklyData
    }
    
    private func fetchWorkoutHistoryFromHealthKit() async -> [WorkoutRecord] {
        let type = HKObjectType.workoutType()
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 15, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                guard let workouts = samples as? [HKWorkout] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let records = workouts.map { workout in
                    let typeName: String
                    switch workout.workoutActivityType {
                    case .running: typeName = "Бег"
                    case .walking: typeName = "Ходьба"
                    case .cycling: typeName = "Велосипед"
                    case .functionalStrengthTraining: typeName = "Силовая"
                    case .yoga: typeName = "Йога"
                    case .swimming: typeName = "Плавание"
                    case .jumpRope: typeName = "Скакалка"
                    case .coreTraining: typeName = "Планка"
                    default: typeName = "Тренировка"
                    }
                    
                    let duration = Int(workout.duration / 60.0)
                    let energy = workout.totalEnergyBurned?.doubleValue(for: HKUnit.kilocalorie()) ?? 0.0
                    
                    return WorkoutRecord(
                        type: typeName,
                        date: workout.startDate,
                        durationMinutes: duration,
                        caloriesBurned: energy
                    )
                }
                continuation.resume(returning: records)
            }
            healthStore.execute(query)
        }
    }
    
    // MARK: - Запись данных в HealthKit и локально
    
    public func addWater(amount: Double) {
        self.waterConsumed += amount
        saveLocalData()
        
        guard HKHealthStore.isHealthDataAvailable() && UserDefaults.standard.bool(forKey: "HealthKitRequested"),
              let type = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else { return }
        
        let quantity = HKQuantity(unit: HKUnit.literUnit(with: .milli), doubleValue: amount)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: Date(), end: Date())
        
        Task {
            try? await healthStore.save(sample)
        }
    }
    
    public func resetWater() {
        self.waterConsumed = 0
        saveLocalData()
    }
    
    public func addDietaryEnergy(calories: Double) {
        self.caloriesConsumedToday += calories
        
        if let idx = self.nutritionHistory.firstIndex(where: { $0.dateString == todayKey }) {
            self.nutritionHistory[idx].calories += calories
        } else {
            let newNutrition = DailyNutritionRecord(dateString: todayKey, calories: calories)
            self.nutritionHistory.append(newNutrition)
        }
        
        if self.nutritionHistory.count > 90 {
            self.nutritionHistory.removeFirst()
        }
        
        saveLocalData()
        
        guard HKHealthStore.isHealthDataAvailable() && UserDefaults.standard.bool(forKey: "HealthKitRequested"),
              let type = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) else { return }
        
        let quantity = HKQuantity(unit: HKUnit.kilocalorie(), doubleValue: calories)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: Date(), end: Date())
        
        Task {
            try? await healthStore.save(sample)
        }
    }
    
    public func addWeight(weight: Double) {
        addWeightRecordLocally(weight: weight)
        saveLocalData()
        
        guard HKHealthStore.isHealthDataAvailable() && UserDefaults.standard.bool(forKey: "HealthKitRequested"),
              let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }
        
        let quantity = HKQuantity(unit: HKUnit.gramUnit(with: .kilo), doubleValue: weight)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: Date(), end: Date())
        
        Task {
            try? await healthStore.save(sample)
        }
    }
    
    private func addWeightRecordLocally(weight: Double) {
        let record = WeightRecord(weight: weight)
        self.weightHistory.append(record)
        if self.weightHistory.count > 90 {
            self.weightHistory.removeFirst()
        }
        
        if self.weightHistory.count >= 2 {
            let prev = self.weightHistory[self.weightHistory.count - 2].weight
            let diff = weight - prev
            if diff > 0.1 {
                self.weightTrend = .up
            } else if diff < -0.1 {
                self.weightTrend = .down
            } else {
                self.weightTrend = .stable
            }
        }
        
        self.currentWeight = weight
    }
    
    public func saveWorkout(activityType: String, startDate: Date, endDate: Date, activeEnergyBurned: Double, distance: Double) {
        saveWorkoutLocally(activityType: activityType, startDate: startDate, endDate: endDate, activeEnergyBurned: activeEnergyBurned, distance: distance)
        
        self.lastWorkoutEndTime = endDate
        saveLocalData()
        
        guard HKHealthStore.isHealthDataAvailable() && UserDefaults.standard.bool(forKey: "HealthKitRequested") else { return }
        
        let hkActivityType: HKWorkoutActivityType
        switch activityType {
        case "Run": hkActivityType = .running
        case "Walk": hkActivityType = .walking
        case "Cycling": hkActivityType = .cycling
        case "Strength": hkActivityType = .functionalStrengthTraining
        case "Yoga": hkActivityType = .yoga
        case "Swimming": hkActivityType = .swimming
        case "JumpRope": hkActivityType = .jumpRope
        case "Dumbbells": hkActivityType = .functionalStrengthTraining
        case "Pushups": hkActivityType = .functionalStrengthTraining
        case "Squats": hkActivityType = .functionalStrengthTraining
        case "Plank": hkActivityType = .coreTraining
        default: hkActivityType = .other
        }
        
        let duration = endDate.timeIntervalSince(startDate)
        let workout = HKWorkout(
            activityType: hkActivityType,
            start: startDate,
            end: endDate,
            duration: duration,
            totalEnergyBurned: HKQuantity(unit: HKUnit.kilocalorie(), doubleValue: activeEnergyBurned),
            totalDistance: distance > 0 ? HKQuantity(unit: HKUnit.meter(), doubleValue: distance) : nil,
            metadata: nil
        )
        
        Task {
            try? await healthStore.save(workout)
        }
    }
    
    private func saveWorkoutLocally(activityType: String, startDate: Date, endDate: Date, activeEnergyBurned: Double, distance: Double) {
        let durationMinutes = Int(endDate.timeIntervalSince(startDate) / 60)
        let typeName: String
        switch activityType {
        case "Run": typeName = "Бег"
        case "Walk": typeName = "Ходьба"
        case "Cycling": typeName = "Велосипед"
        case "Strength": typeName = "Силовая"
        case "Yoga": typeName = "Йога"
        case "Swimming": typeName = "Плавание"
        case "JumpRope": typeName = "Скакалка"
        case "Dumbbells": typeName = "Гантели"
        case "Pushups": typeName = "Отжимания"
        case "Squats": typeName = "Приседания"
        case "Plank": typeName = "Планка"
        default: typeName = activityType
        }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM"
        let dateStr = formatter.string(from: startDate)
        
        self.lastWorkoutString = "\(durationMinutes) мин — \(typeName)\n(\(dateStr))"
        self.activeEnergyBurned += activeEnergyBurned
        
        if activityType == "Run" || activityType == "Walk" {
            let addedSteps = Int(distance * 1.25)
            self.stepsToday += addedSteps
            self.distanceMetersToday += distance
        } else if activityType == "JumpRope" {
            let addedSteps = durationMinutes * 130
            self.stepsToday += addedSteps
        }
        
        let record = WorkoutRecord(
            type: typeName,
            date: startDate,
            durationMinutes: durationMinutes,
            caloriesBurned: activeEnergyBurned
        )
        self.workoutHistory.append(record)
        if self.workoutHistory.count > 90 {
            self.workoutHistory.removeFirst()
        }
    }
}
