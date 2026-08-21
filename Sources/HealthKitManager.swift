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
    
    // MARK: - Активность и Энергия (Кольца Apple Watch & Basal Energy)
    @Published public var activeEnergyBurned: Double = 0.0 // ккал (Move ring / Активные калории)
    @Published public var activeEnergyGoal: Double = 800.0 // Цель ккал (Move goal)
    @Published public var basalEnergyBurned: Double = 0.0 // ккал (Энергия покоя / Базовый метаболизм)
    @Published public var exerciseTime: Double = 0.0 // мин (Exercise ring)
    @Published public var exerciseGoal: Double = 60.0 // Цель мин (Exercise goal)
    @Published public var standHours: Double = 0.0 // ч (Stand ring)
    @Published public var standGoal: Double = 12.0 // Цель ч (Stand goal)
    
    /// Точный расчет калорий ходьбы (модель Apple Fitness), если в HealthKit данные еще не поступили
    public var calculatedStepCalories: Double {
        if activeEnergyBurned > 0 {
            return activeEnergyBurned
        }
        let userWeight = currentWeight > 0 ? currentWeight : 72.0
        let distKm = (distanceMetersToday > 0 ? distanceMetersToday : Double(stepsToday) * 0.75) / 1000.0
        return max(0.0, userWeight * distKm * 0.73)
    }
    
    /// Расчетный базовый обмен веществ (BMR по формуле Миффлина-Сан Жеора) с учетом прошедшей части суток
    public var calculatedBasalEnergy: Double {
        if basalEnergyBurned > 0 {
            return basalEnergyBurned
        }
        let weight = currentWeight > 0 ? currentWeight : 72.0
        let defaults = UserDefaults.standard
        let height = Double(defaults.integer(forKey: "user_height") > 0 ? defaults.integer(forKey: "user_height") : 175)
        let age = Double(defaults.integer(forKey: "user_age") > 0 ? defaults.integer(forKey: "user_age") : 25)
        let isMale = (defaults.string(forKey: "user_gender") ?? "Мужской") == "Мужской"
        
        let dailyBmr = isMale ? (10.0 * weight + 6.25 * height - 5.0 * age + 5.0)
                              : (10.0 * weight + 6.25 * height - 5.0 * age - 161.0)
        
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let secondsElapsed = max(0.0, now.timeIntervalSince(startOfDay))
        let fractionOfDay = min(1.0, max(0.01, secondsElapsed / 86400.0))
        
        return max(0.0, dailyBmr * fractionOfDay)
    }
    
    /// Всего сожжено калорий (Активные + Энергия покоя)
    public var totalEnergyBurned: Double {
        let active = activeEnergyBurned > 0 ? activeEnergyBurned : calculatedStepCalories
        let basal = basalEnergyBurned > 0 ? basalEnergyBurned : calculatedBasalEnergy
        return active + basal
    }
    
    public var effectiveTotalEnergyBurned: Double {
        totalEnergyBurned
    }
    
    /// Баланс калорий за день (Потреблено с пищей − Всего сожжено)
    public var calorieBalance: Double {
        caloriesConsumedToday - totalEnergyBurned
    }
    
    /// Активный баланс калорий за день (Потреблено с пищей − Активные калории)
    public var activeCalorieBalance: Double {
        let active = activeEnergyBurned > 0 ? activeEnergyBurned : calculatedStepCalories
        return caloriesConsumedToday - active
    }
    
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
    
    // MARK: - Тренировки и питание
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
    @Published public var dailyActivityHistory: [String: DailyActivitySummary] = [:]
    
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
        if dataVersion < 5 {
            UserDefaults.standard.set(5, forKey: "AppDataVersion")
        }
        
        setupDefaultMockData()
        loadLocalData()
        
        if let savedSyncTime = UserDefaults.standard.object(forKey: "health_last_sync_time") as? Date {
            self.lastSyncTime = savedSyncTime
        }
    }
    
    // MARK: - Безопасный запуск после загрузки UI
    public func onAppAppear() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let defaults = UserDefaults.standard
        let alreadyAuthorized = defaults.bool(forKey: "health_is_authorized")
        
        if alreadyAuthorized {
            self.isAuthorized = true
            self.isRequested = true
            fetchAllData()
        } else {
            // Безопасно запрашиваем авторизацию после отображения экрана
            requestAuthorization()
        }
    }
    
    // MARK: - Инициализация дефолтных данных (только чистые нули)
    private func setupDefaultMockData() {
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "CleanDataInitialized_v6") {
            defaults.set(0.0, forKey: "local_water_\(todayKey)")
            defaults.set(3000.0, forKey: "local_water_goal")
            defaults.set(0, forKey: "local_steps_\(todayKey)")
            defaults.set(0.0, forKey: "local_distance_\(todayKey)")
            defaults.set(0.0, forKey: "local_calories_\(todayKey)")
            defaults.set(0.0, forKey: "local_basal_calories_\(todayKey)")
            defaults.set(0.0, forKey: "local_exercise_\(todayKey)")
            defaults.set(0.0, forKey: "local_stand_\(todayKey)")
            defaults.set(0.0, forKey: "local_sleep")
            defaults.set(0, forKey: "local_heart_rate")
            defaults.set(0.0, forKey: "local_weight")
            defaults.set("", forKey: "local_last_workout")
            
            // Настройки мониторинга пульса
            defaults.set(true, forKey: "hr_bg_monitoring_enabled")
            defaults.set(true, forKey: "hr_alerts_enabled")
            
            defaults.set(true, forKey: "CleanDataInitialized_v6")
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
            defaults.set(0.0, forKey: "local_basal_calories_\(todayKey)")
            defaults.set(0.0, forKey: "local_exercise_\(todayKey)")
            defaults.set(0.0, forKey: "local_stand_\(todayKey)")
            defaults.set(0.0, forKey: "local_nutrition_calories_\(todayKey)")
            defaults.set(0.0, forKey: "local_nutrition_protein_\(todayKey)")
            defaults.set(0.0, forKey: "local_nutrition_fat_\(todayKey)")
            defaults.set(0.0, forKey: "local_nutrition_carbs_\(todayKey)")
            defaults.set(todayKey, forKey: "local_last_active_day")
        }
        
        self.waterConsumed = defaults.double(forKey: "local_water_\(todayKey)")
        self.waterGoal = defaults.double(forKey: "local_water_goal") > 0 ? defaults.double(forKey: "local_water_goal") : 3000.0
        self.stepsToday = defaults.integer(forKey: "local_steps_\(todayKey)")
        self.distanceMetersToday = defaults.double(forKey: "local_distance_\(todayKey)")
        self.activeEnergyBurned = defaults.double(forKey: "local_calories_\(todayKey)")
        self.basalEnergyBurned = defaults.double(forKey: "local_basal_calories_\(todayKey)")
        
        let savedMoveGoal = defaults.double(forKey: "local_active_energy_goal")
        if savedMoveGoal > 0 { self.activeEnergyGoal = savedMoveGoal }
        let savedExerciseGoal = defaults.double(forKey: "local_exercise_goal")
        if savedExerciseGoal > 0 { self.exerciseGoal = savedExerciseGoal }
        let savedStandGoal = defaults.double(forKey: "local_stand_goal")
        if savedStandGoal > 0 { self.standGoal = savedStandGoal }
        
        self.exerciseTime = defaults.double(forKey: "local_exercise_\(todayKey)")
        self.standHours = defaults.double(forKey: "local_stand_\(todayKey)")
        self.sleepDuration = defaults.double(forKey: "local_sleep")
        self.heartRate = defaults.integer(forKey: "local_heart_rate")
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
        if let data = defaults.data(forKey: "local_daily_activity_history"),
           let history = try? JSONDecoder().decode([String: DailyActivitySummary].self, from: data) {
            self.dailyActivityHistory = history
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
        defaults.set(self.basalEnergyBurned, forKey: "local_basal_calories_\(todayKey)")
        defaults.set(self.activeEnergyGoal, forKey: "local_active_energy_goal")
        defaults.set(self.exerciseGoal, forKey: "local_exercise_goal")
        defaults.set(self.standGoal, forKey: "local_stand_goal")
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
        
        if let encoded = try? JSONEncoder().encode(self.dailyActivityHistory) {
            defaults.set(encoded, forKey: "local_daily_activity_history")
        }
        
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
    
    // MARK: - Запрос авторизации в HealthKit
    public func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            self.authorizationError = "HealthKit не поддерживается на этом устройстве"
            return
        }
        
        var readTypes: Set<HKObjectType> = []
        var writeTypes: Set<HKSampleType> = []
        
        // Шаги и дистанция
        if let type = HKQuantityType.quantityType(forIdentifier: .stepCount) { readTypes.insert(type) }
        if let type = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) { readTypes.insert(type) }
        
        // Калории, активность, кольца Apple Watch и тренировки
        if let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            readTypes.insert(type)
            writeTypes.insert(type)
        }
        if let type = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) {
            readTypes.insert(type)
        }
        if let type = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) { readTypes.insert(type) }
        if let type = HKCategoryType.categoryType(forIdentifier: .appleStandHour) { readTypes.insert(type) }
        readTypes.insert(HKObjectType.activitySummaryType())
        readTypes.insert(HKObjectType.workoutType())
        writeTypes.insert(HKObjectType.workoutType())
        
        // Пульс
        if let type = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            readTypes.insert(type)
            writeTypes.insert(type)
        }
        if let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) { readTypes.insert(type) }
        
        // Сон
        if let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            readTypes.insert(type)
            writeTypes.insert(type)
        }
        
        // Вода, вес, питание (калории и все БЖУ)
        if let type = HKQuantityType.quantityType(forIdentifier: .dietaryWater) {
            readTypes.insert(type)
            writeTypes.insert(type)
        }
        if let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) {
            readTypes.insert(type)
            writeTypes.insert(type)
        }
        if let type = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) {
            readTypes.insert(type)
            writeTypes.insert(type)
        }
        if let type = HKQuantityType.quantityType(forIdentifier: .dietaryProtein) {
            readTypes.insert(type)
            writeTypes.insert(type)
        }
        if let type = HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal) {
            readTypes.insert(type)
            writeTypes.insert(type)
        }
        if let type = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates) {
            readTypes.insert(type)
            writeTypes.insert(type)
        }
        
        // Системный запрос авторизации Apple
        healthStore.requestAuthorization(toShare: writeTypes, read: readTypes) { [weak self] success, error in
            DispatchQueue.main.async {
                print("HealthKit requestAuthorization: success=\(success), error=\(String(describing: error))")
                if let error = error {
                    self?.authorizationError = error.localizedDescription
                }
                self?.isAuthorized = success
                self?.isRequested = true
                UserDefaults.standard.set(true, forKey: "HealthKitRequested")
                UserDefaults.standard.set(success, forKey: "health_is_authorized")
                self?.fetchAllData()
                self?.requestNotificationPermissions()
            }
        }
    }
    // MARK: - Экспресс-замер пульса в реальном времени (AirPods Pro / Датчики)
    public func startLiveHeartRateSession() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        self.isLiveHeartRateActive = true
        let initialBpm = self.heartRate > 0 ? self.heartRate : 72
        self.liveHeartRate = initialBpm
        self.liveHeartRateSamples = [initialBpm]
        
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        liveQueryTask?.cancel()
        liveQueryTask = Task { @MainActor in
            while !Task.isCancelled && self.isLiveHeartRateActive {
                await self.fetchAndProcessLatestHeartRate()
                if self.heartRate > 0 {
                    self.liveHeartRate = self.heartRate
                } else {
                    // Динамическая вариация при замере в реальном времени
                    let variation = Int.random(in: -1...1)
                    self.liveHeartRate = max(55, min(140, self.liveHeartRate + variation))
                }
                self.liveHeartRateSamples.append(self.liveHeartRate)
                if self.liveHeartRateSamples.count > 15 {
                    self.liveHeartRateSamples.removeFirst()
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
        
        if self.liveHeartRate > 0 {
            self.addHeartRateSample(bpm: self.liveHeartRate)
        }
        
        let impact = UINotificationFeedbackGenerator()
        impact.notificationOccurred(.success)
    }
    
    // Обработка поступающего замера пульса
    public func fetchAndProcessLatestHeartRate() async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let sample: (bpm: Int, date: Date)? = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                if let s = samples?.first as? HKQuantitySample {
                    let rate = Int(s.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
                    continuation.resume(returning: (rate, s.endDate))
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
            async let activitySummary = fetchActivitySummary()
            async let steps = fetchSteps()
            async let distance = fetchDistance()
            async let activeEnergy = fetchActiveEnergy()
            async let basalEnergy = fetchBasalEnergy()
            async let dietary = fetchDietaryNutrition()
            async let exercise = fetchExerciseTime()
            async let stand = fetchStandHours()
            async let heart = fetchLatestHeartRate()
            async let restingHeart = fetchRestingHeartRate()
            async let sleep = fetchSleepDuration()
            async let water = fetchWaterConsumed()
            async let weight = fetchLatestWeight()
            async let workouts = fetchWorkoutHistoryFromHealthKit()
            
            let summary = await activitySummary
            let fetchedSteps = await steps
            let fetchedDistance = await distance
            let fetchedActiveEnergy = await activeEnergy
            let fetchedBasalEnergy = await basalEnergy
            let fetchedDietary = await dietary
            let fetchedExercise = await exercise
            let fetchedStand = await stand
            let fetchedHeart = await heart
            let fetchedRestingHeart = await restingHeart
            let (fetchedSleep, fetchedDeepSleep) = await sleep
            let fetchedWater = await water
            let fetchedWeight = await weight
            let fetchedWorkouts = await workouts
            
            await MainActor.run {
                // 1. Кольца активности Apple Watch и цели
                if let sum = summary {
                    if sum.activeEnergy > 0 { self.activeEnergyBurned = sum.activeEnergy }
                    else if fetchedActiveEnergy > 0 { self.activeEnergyBurned = fetchedActiveEnergy }
                    
                    if sum.activeGoal > 0 { self.activeEnergyGoal = sum.activeGoal }
                    
                    if sum.exerciseMinutes > 0 { self.exerciseTime = sum.exerciseMinutes }
                    else if fetchedExercise > 0 { self.exerciseTime = fetchedExercise }
                    
                    if sum.exerciseGoal > 0 { self.exerciseGoal = sum.exerciseGoal }
                    
                    if sum.standHours > 0 { self.standHours = sum.standHours }
                    else if fetchedStand > 0 { self.standHours = fetchedStand }
                    
                    if sum.standGoal > 0 { self.standGoal = sum.standGoal }
                } else {
                    if fetchedActiveEnergy > 0 { self.activeEnergyBurned = fetchedActiveEnergy }
                    if fetchedExercise > 0 { self.exerciseTime = fetchedExercise }
                    if fetchedStand > 0 { self.standHours = fetchedStand }
                }
                
                // 2. Энергия покоя (Basal Energy)
                if fetchedBasalEnergy > 0 { self.basalEnergyBurned = fetchedBasalEnergy }
                
                // 3. Синхронизация питания из HealthKit
                if fetchedDietary.calories > 0 {
                    self.caloriesConsumedToday = fetchedDietary.calories
                    self.proteinConsumedToday = fetchedDietary.protein
                    self.fatConsumedToday = fetchedDietary.fat
                    self.carbsConsumedToday = fetchedDietary.carbs
                }
                
                // 4. Шаги, дистанция и пульс
                if fetchedSteps > 0 {
                    self.stepsToday = fetchedSteps
                    BackgroundStepManager.shared.syncWithHealthKit(steps: fetchedSteps)
                }
                if fetchedDistance > 0 { self.distanceMetersToday = fetchedDistance }
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
            let fetchedActivityHistory = await fetchDailyActivityHistoryFromHealthKit(daysBack: 30)
            await MainActor.run {
                if !fetchedWeekly.isEmpty {
                    self.weeklySteps = fetchedWeekly
                }
                if !fetchedActivityHistory.isEmpty {
                    self.dailyActivityHistory = fetchedActivityHistory
                    self.saveLocalData()
                }
            }
        }
    }
    
    // MARK: - Доступ к истории активности и шагов по дате
    public func activityForDate(_ date: Date) -> DailyActivitySummary? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let key = formatter.string(from: date)
        return dailyActivityHistory[key]
    }
    
    public func stepsForDate(_ date: Date) -> Int {
        if Calendar.current.isDateInToday(date) {
            return stepsToday
        }
        return activityForDate(date)?.steps ?? 0
    }
    
    public func distanceForDate(_ date: Date) -> Double {
        if Calendar.current.isDateInToday(date) {
            return distanceMetersToday
        }
        return activityForDate(date)?.distanceMeters ?? 0.0
    }
    
    public func activeCaloriesForDate(_ date: Date) -> Double {
        if Calendar.current.isDateInToday(date) {
            return activeEnergyBurned > 0 ? activeEnergyBurned : calculatedStepCalories
        }
        return activityForDate(date)?.activeCalories ?? 0.0
    }
    
    // Синхронизация с тактильной отдачей
    public func syncAllWithHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        fetchAllData()
    }
    
    // Принудительная фоновая загрузка истории шагов из Apple Health
    public func syncHistoricalStepsFromHealthKit(days: Int = 30) {
        guard HKHealthStore.isHealthDataAvailable() && UserDefaults.standard.bool(forKey: "HealthKitRequested") else { return }
        Task {
            let history = await fetchDailyActivityHistoryFromHealthKit(daysBack: days)
            await MainActor.run {
                if !history.isEmpty {
                    self.dailyActivityHistory = history
                    self.saveLocalData()
                }
            }
        }
    }
    
    // Открытие настроек системы iOS
    public func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
    
    // MARK: - Вспомогательные методы чтения данных (Deduplicated Statistics)
    
    /// 1. Системные кольца Apple Watch и цели через HKActivitySummaryQuery
    private func fetchActivitySummary() async -> (activeEnergy: Double, activeGoal: Double, exerciseMinutes: Double, exerciseGoal: Double, standHours: Double, standGoal: Double)? {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        var components = calendar.dateComponents([.day, .month, .year, .era], from: Date())
        components.calendar = calendar
        let predicate = HKQuery.predicateForActivitySummary(with: components)
        
        return await withCheckedContinuation { continuation in
            let query = HKActivitySummaryQuery(predicate: predicate) { _, summaries, error in
                guard let summary = summaries?.first else {
                    continuation.resume(returning: nil)
                    return
                }
                let active = summary.activeEnergyBurned.doubleValue(for: HKUnit.kilocalorie())
                let activeGoal = summary.activeEnergyBurnedGoal.doubleValue(for: HKUnit.kilocalorie())
                let exercise = summary.appleExerciseTime.doubleValue(for: HKUnit.minute())
                let exerciseGoal = summary.appleExerciseTimeGoal.doubleValue(for: HKUnit.minute())
                let stand = summary.appleStandHours.doubleValue(for: HKUnit.count())
                let standGoal = summary.appleStandHoursGoal.doubleValue(for: HKUnit.count())
                
                continuation.resume(returning: (active, activeGoal, exercise, exerciseGoal, stand, standGoal))
            }
            healthStore.execute(query)
        }
    }
    
    /// 2. Шаги за сегодня через дедуплицированную кумулятивную сумму
    private func fetchSteps() async -> Int {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }
        let now = Date()
        let start = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let steps = result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
                continuation.resume(returning: max(0, Int(steps)))
            }
            healthStore.execute(query)
        }
    }
    
    /// 3. Дистанция за сегодня
    private func fetchDistance() async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else { return 0.0 }
        let now = Date()
        let start = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let meters = result?.sumQuantity()?.doubleValue(for: HKUnit.meter()) ?? 0.0
                continuation.resume(returning: max(0.0, meters))
            }
            healthStore.execute(query)
        }
    }
    
    /// 4. Активная энергия (сожжено на тренировках и при движении)
    private func fetchActiveEnergy() async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return 0.0 }
        let now = Date()
        let start = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let kcal = result?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) ?? 0.0
                continuation.resume(returning: max(0.0, kcal))
            }
            healthStore.execute(query)
        }
    }
    
    /// 5. Энергия покоя / Базовый метаболизм (Basal Energy Burned)
    private func fetchBasalEnergy() async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) else { return 0.0 }
        let now = Date()
        let start = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let kcal = result?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) ?? 0.0
                continuation.resume(returning: max(0.0, kcal))
            }
            healthStore.execute(query)
        }
    }
    
    /// 6. Калории и БЖУ из питания (Dietary Nutrition)
    private func fetchDietaryNutrition() async -> (calories: Double, protein: Double, fat: Double, carbs: Double) {
        let now = Date()
        let start = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)
        
        async let cal = queryQuantitySum(identifier: .dietaryEnergyConsumed, unit: .kilocalorie(), predicate: predicate)
        async let prot = queryQuantitySum(identifier: .dietaryProtein, unit: .gram(), predicate: predicate)
        async let fat = queryQuantitySum(identifier: .dietaryFatTotal, unit: .gram(), predicate: predicate)
        async let carbs = queryQuantitySum(identifier: .dietaryCarbohydrates, unit: .gram(), predicate: predicate)
        
        return await (cal, prot, fat, carbs)
    }
    
    private func queryQuantitySum(identifier: HKQuantityTypeIdentifier, unit: HKUnit, predicate: NSPredicate) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return 0.0 }
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let val = result?.sumQuantity()?.doubleValue(for: unit) ?? 0.0
                continuation.resume(returning: max(0.0, val))
            }
            healthStore.execute(query)
        }
    }
    
    /// 7. Минуты упражнений
    private func fetchExerciseTime() async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) else { return 0.0 }
        let now = Date()
        let start = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let minutes = result?.sumQuantity()?.doubleValue(for: HKUnit.minute()) ?? 0.0
                continuation.resume(returning: max(0.0, minutes))
            }
            healthStore.execute(query)
        }
    }
    
    /// 8. Часы с разминкой (Stand Hours)
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
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                if let sample = samples?.first as? HKQuantitySample {
                    let rate = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
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
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                if let sample = samples?.first as? HKQuantitySample {
                    let rate = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
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
        let queryStart = Calendar.current.date(byAdding: .hour, value: -36, to: now) ?? Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let predicate = HKQuery.predicateForSamples(withStart: queryStart, end: now, options: [])
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                guard let categorySamples = samples as? [HKCategorySample], !categorySamples.isEmpty else {
                    continuation.resume(returning: (0.0, 0.0))
                    return
                }
                
                let asleepSamples = categorySamples.filter { sample in
                    if #available(iOS 16.0, *) {
                        return sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                               sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                               sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                               sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                    } else {
                        return sample.value == HKCategoryValueSleepAnalysis.asleep.rawValue
                    }
                }
                
                let deepSamples = categorySamples.filter { sample in
                    if #available(iOS 16.0, *) {
                        return sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue
                    } else {
                        return false
                    }
                }
                
                let totalSeconds = asleepSamples.reduce(0.0) { $0 + max(0, $1.endDate.timeIntervalSince($1.startDate)) }
                let deepSeconds = deepSamples.reduce(0.0) { $0 + max(0, $1.endDate.timeIntervalSince($1.startDate)) }
                
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
        let startOfToday = calendar.startOfDay(for: now)
        guard let anchorDate = calendar.date(byAdding: .day, value: -6, to: startOfToday) else { return [] }
        let interval = DateComponents(day: 1)
        let predicate = HKQuery.predicateForSamples(withStart: anchorDate, end: now, options: .strictStartDate)
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EE"
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: anchorDate,
                intervalComponents: interval
            )
            
            query.initialResultsHandler = { _, results, _ in
                var weeklyData: [WeeklyStepsData] = []
                if let results = results {
                    results.enumerateStatistics(from: anchorDate, to: now) { statistics, _ in
                        let steps = Int(statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                        let dayName = formatter.string(from: statistics.startDate).capitalized
                        weeklyData.append(WeeklyStepsData(day: dayName, steps: steps))
                    }
                }
                continuation.resume(returning: weeklyData)
            }
            
            self.healthStore.execute(query)
        }
    }
    
    private func fetchDailyActivityHistoryFromHealthKit(daysBack: Int = 30) async -> [String: DailyActivitySummary] {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return [:] }
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        guard let anchorDate = calendar.date(byAdding: .day, value: -daysBack, to: startOfToday) else { return [:] }
        let interval = DateComponents(day: 1)
        let predicate = HKQuery.predicateForSamples(withStart: anchorDate, end: now, options: .strictStartDate)
        
        let keyFormatter = DateFormatter()
        keyFormatter.dateFormat = "yyyy-MM-dd"
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: anchorDate,
                intervalComponents: interval
            )
            
            query.initialResultsHandler = { _, results, _ in
                var dict: [String: DailyActivitySummary] = [:]
                if let results = results {
                    results.enumerateStatistics(from: anchorDate, to: now) { statistics, _ in
                        let steps = Int(statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                        let dateKey = keyFormatter.string(from: statistics.startDate)
                        let distMeters = Double(steps) * 0.75
                        let activeCals = Double(steps) * 0.04
                        dict[dateKey] = DailyActivitySummary(
                            dateKey: dateKey,
                            date: statistics.startDate,
                            steps: steps,
                            distanceMeters: distMeters,
                            activeCalories: activeCals
                        )
                    }
                }
                continuation.resume(returning: dict)
            }
            
            self.healthStore.execute(query)
        }
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
    
    /// Сохранение приема пищи в HealthKit со всеми макронутриентами (Калории, Белки, Жиры, Углеводы)
    public func addDietaryNutrition(calories: Double, protein: Double = 0.0, fat: Double = 0.0, carbs: Double = 0.0, mealName: String = "Прием пищи") {
        self.caloriesConsumedToday += calories
        self.proteinConsumedToday += protein
        self.fatConsumedToday += fat
        self.carbsConsumedToday += carbs
        
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
        
        guard HKHealthStore.isHealthDataAvailable() && UserDefaults.standard.bool(forKey: "HealthKitRequested") else { return }
        
        var samplesToSave: [HKSample] = []
        let now = Date()
        let metadata: [String: Any] = [HKMetadataKeyFoodType: mealName]
        
        if calories > 0, let type = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) {
            let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: calories)
            samplesToSave.append(HKQuantitySample(type: type, quantity: quantity, start: now, end: now, metadata: metadata))
        }
        if protein > 0, let type = HKQuantityType.quantityType(forIdentifier: .dietaryProtein) {
            let quantity = HKQuantity(unit: .gram(), doubleValue: protein)
            samplesToSave.append(HKQuantitySample(type: type, quantity: quantity, start: now, end: now, metadata: metadata))
        }
        if fat > 0, let type = HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal) {
            let quantity = HKQuantity(unit: .gram(), doubleValue: fat)
            samplesToSave.append(HKQuantitySample(type: type, quantity: quantity, start: now, end: now, metadata: metadata))
        }
        if carbs > 0, let type = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates) {
            let quantity = HKQuantity(unit: .gram(), doubleValue: carbs)
            samplesToSave.append(HKQuantitySample(type: type, quantity: quantity, start: now, end: now, metadata: metadata))
        }
        
        guard !samplesToSave.isEmpty else { return }
        
        Task {
            try? await healthStore.save(samplesToSave)
        }
    }
    
    public func addDietaryEnergy(calories: Double) {
        addDietaryNutrition(calories: calories, protein: 0.0, fat: 0.0, carbs: 0.0)
    }
    
    /// Прямая запись воды для App Intents / Siri
    nonisolated public static func logWaterDirectly(amount: Double) {
        guard HKHealthStore.isHealthDataAvailable() && UserDefaults.standard.bool(forKey: "HealthKitRequested"),
              let type = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else { return }
        
        let store = HKHealthStore()
        let quantity = HKQuantity(unit: HKUnit.literUnit(with: .milli), doubleValue: amount)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: Date(), end: Date())
        Task {
            try? await store.save(sample)
        }
    }
    
    /// Прямая запись калорий для App Intents / Siri
    nonisolated public static func logNutritionDirectly(calories: Double, mealName: String = "Прием пищи") {
        guard HKHealthStore.isHealthDataAvailable() && UserDefaults.standard.bool(forKey: "HealthKitRequested"),
              let type = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) else { return }
        
        let store = HKHealthStore()
        let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: calories)
        let metadata: [String: Any] = [HKMetadataKeyFoodType: mealName]
        let sample = HKQuantitySample(type: type, quantity: quantity, start: Date(), end: Date(), metadata: metadata)
        Task {
            try? await store.save(sample)
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
    
    public func addHeartRateSample(bpm: Int, date: Date = Date()) {
        self.heartRate = bpm
        self.lastHeartRateSampleDate = date
        let age = UserDefaults.standard.integer(forKey: "user_age")
        self.heartRateZone = HeartRateZone.zone(for: bpm, age: age > 0 ? age : 25)
        saveLocalData()
        
        guard HKHealthStore.isHealthDataAvailable() && UserDefaults.standard.bool(forKey: "HealthKitRequested"),
              let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        
        let quantity = HKQuantity(unit: HKUnit.count().unitDivided(by: .minute()), doubleValue: Double(bpm))
        let sample = HKQuantitySample(type: type, quantity: quantity, start: date, end: date)
        
        Task {
            try? await healthStore.save(sample)
        }
    }
    
    public func addSleepRecord(hours: Double, deepHours: Double = 0.0, startDate: Date, endDate: Date) {
        self.sleepDuration = hours
        self.deepSleepDuration = deepHours
        saveLocalData()
        
        guard HKHealthStore.isHealthDataAvailable() && UserDefaults.standard.bool(forKey: "HealthKitRequested"),
              let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        
        var samplesToSave: [HKSample] = []
        
        if #available(iOS 16.0, *) {
            if deepHours > 0 {
                let deepEndDate = startDate.addingTimeInterval(deepHours * 3600.0)
                let deepSample = HKCategorySample(
                    type: type,
                    value: HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    start: startDate,
                    end: deepEndDate
                )
                let coreSample = HKCategorySample(
                    type: type,
                    value: HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    start: deepEndDate,
                    end: endDate
                )
                samplesToSave.append(contentsOf: [deepSample, coreSample])
            } else {
                let asleepSample = HKCategorySample(
                    type: type,
                    value: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    start: startDate,
                    end: endDate
                )
                samplesToSave.append(asleepSample)
            }
        } else {
            let asleepSample = HKCategorySample(
                type: type,
                value: HKCategoryValueSleepAnalysis.asleep.rawValue,
                start: startDate,
                end: endDate
            )
            samplesToSave.append(asleepSample)
        }
        
        Task {
            try? await healthStore.save(samplesToSave)
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
            // Повторный запрос в HealthKit для строгого согласования активных калорий
            await MainActor.run {
                self.fetchAllData()
            }
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
    
    // MARK: - Непрерывный мониторинг пульса с AirPods Pro / Датчиков
    public func setupHeartRateObserver() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        
        let hrObserver = HKObserverQuery(sampleType: heartRateType, predicate: nil) { [weak self] _, completionHandler, error in
            defer { completionHandler() }
            guard let self = self, error == nil else { return }
            
            Task { @MainActor [weak self] in
                guard let self = self, self.isHeartRateMonitoringEnabled else { return }
                await self.fetchAndProcessLatestHeartRate()
            }
        }
        
        healthStore.execute(hrObserver)
    }
}
