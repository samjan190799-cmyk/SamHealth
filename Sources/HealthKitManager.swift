import SwiftUI
import Combine
import HealthKit

@MainActor
public class HealthKitManager: ObservableObject {
    
    // Состояние авторизации
    @Published public var isAuthorized = false
    @Published public var isRequested = false
    @Published public var authorizationError: String? = nil
    
    // Активность (Кольца)
    @Published public var activeEnergyBurned: Double = 0.0 // ккал
    @Published public var activeEnergyGoal: Double = 800.0 // Цель ккал
    @Published public var exerciseTime: Double = 0.0 // мин
    @Published public var exerciseGoal: Double = 60.0 // Цель мин
    @Published public var standHours: Double = 0.0 // ч
    @Published public var standGoal: Double = 12.0 // Цель ч
    
    // Шаги
    @Published public var stepsToday: Int = 0
    @Published public var weeklySteps: [WeeklyStepsData] = []
    
    // Здоровье
    @Published public var heartRate: Int = 0 // уд/мин
    @Published public var sleepDuration: Double = 0.0 // ч
    
    // Вода
    @Published public var waterConsumed: Double = 0.0 // мл
    @Published public var waterGoal: Double = 3000.0 // мл (3.0 L)
    
    // Вес
    @Published public var currentWeight: Double = 0.0 // кг
    @Published public var weightTrend: WeightTrendType = .stable
    
    // Последняя тренировка
    @Published public var lastWorkoutString: String = "Нет данных"
    @Published public var caloriesConsumedToday: Double = 0.0
    
    // История здоровья (вес, тренировки, питание)
    @Published public var weightHistory: [WeightRecord] = []
    @Published public var workoutHistory: [WorkoutRecord] = []
    @Published public var nutritionHistory: [DailyNutritionRecord] = []
    
    private let healthStore = HKHealthStore()
    
    private var todayKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    public init() {
        // Миграция: если версия данных не совпадает, сбрасываем все старые данные
        let dataVersion = UserDefaults.standard.integer(forKey: "AppDataVersion")
        if dataVersion < 3 {
            UserDefaults.standard.removeObject(forKey: "MockDataInitialized")
            UserDefaults.standard.set(3, forKey: "AppDataVersion")
        }
        setupDefaultMockData()
        loadLocalData()
        
        // Если доступ к HealthKit уже запрашивался ранее, пробуем автоматически прогрузить
        if UserDefaults.standard.bool(forKey: "HealthKitRequested") && HKHealthStore.isHealthDataAvailable() {
            self.isRequested = true
            self.isAuthorized = true
            fetchAllData()
        }
    }
    
    // Инициализация дефолтных данных
    private func setupDefaultMockData() {
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "MockDataInitialized") {
            // Вода — обнуляется каждый день, начальное значение 0
            defaults.set(0.0, forKey: "local_water_\(todayKey)")
            defaults.set(3000.0, forKey: "local_water_goal") // Цель 3.0 л
            // Шаги, калории, упражнения — начинаем с нуля
            defaults.set(0, forKey: "local_steps_\(todayKey)")
            defaults.set(0.0, forKey: "local_calories_\(todayKey)")
            defaults.set(0.0, forKey: "local_exercise_\(todayKey)")
            defaults.set(0.0, forKey: "local_stand_\(todayKey)")
            // Здоровье — стартовые показатели
            defaults.set(7.2, forKey: "local_sleep")
            defaults.set(72, forKey: "local_heart_rate")
            defaults.set(0.0, forKey: "local_weight")
            defaults.set("", forKey: "local_last_workout")
            
            // Недельные шаги — начинаем с нулей
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
    
    // Загрузка локальных данных
    public func loadLocalData() {
        let defaults = UserDefaults.standard
        
        // --- ЕЖЕДНЕВНЫЙ СБРОС ---
        // Если сохранённый день отличается от сегодняшнего, сбрасываем дневные данные
        let savedDay = defaults.string(forKey: "local_last_active_day") ?? ""
        if savedDay != todayKey {
            defaults.set(0.0, forKey: "local_water_\(todayKey)")
            defaults.set(0, forKey: "local_steps_\(todayKey)")
            defaults.set(0.0, forKey: "local_calories_\(todayKey)")
            defaults.set(0.0, forKey: "local_exercise_\(todayKey)")
            defaults.set(0.0, forKey: "local_stand_\(todayKey)")
            defaults.set(0.0, forKey: "local_nutrition_calories_\(todayKey)")
            defaults.set(todayKey, forKey: "local_last_active_day")
        }
        
        self.waterConsumed = defaults.double(forKey: "local_water_\(todayKey)")
        self.waterGoal = defaults.double(forKey: "local_water_goal") > 0 ? defaults.double(forKey: "local_water_goal") : 3000.0
        self.stepsToday = defaults.integer(forKey: "local_steps_\(todayKey)")
        self.activeEnergyBurned = defaults.double(forKey: "local_calories_\(todayKey)")
        self.exerciseTime = defaults.double(forKey: "local_exercise_\(todayKey)")
        self.standHours = defaults.double(forKey: "local_stand_\(todayKey)")
        self.sleepDuration = defaults.double(forKey: "local_sleep")
        self.heartRate = defaults.integer(forKey: "local_heart_rate")
        self.currentWeight = defaults.double(forKey: "local_weight")
        self.lastWorkoutString = defaults.string(forKey: "local_last_workout") ?? "Нет данных"
        self.caloriesConsumedToday = defaults.double(forKey: "local_nutrition_calories_\(todayKey)")
        
        // Загрузка недельных шагов
        if let data = defaults.data(forKey: "local_weekly_steps"),
           let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            self.weeklySteps = json.compactMap { dict in
                guard let day = dict["day"] as? String, let steps = dict["steps"] as? Int else { return nil }
                return WeeklyStepsData(day: day, steps: steps)
            }
        }
        
        // Загрузка истории здоровья
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
    }
    
    // Сохранение локальных данных
    private func saveLocalData() {
        let defaults = UserDefaults.standard
        defaults.set(self.waterConsumed, forKey: "local_water_\(todayKey)")
        defaults.set(self.stepsToday, forKey: "local_steps_\(todayKey)")
        defaults.set(self.activeEnergyBurned, forKey: "local_calories_\(todayKey)")
        defaults.set(self.exerciseTime, forKey: "local_exercise_\(todayKey)")
        defaults.set(self.standHours, forKey: "local_stand_\(todayKey)")
        defaults.set(self.currentWeight, forKey: "local_weight")
        defaults.set(self.lastWorkoutString, forKey: "local_last_workout")
        defaults.set(self.caloriesConsumedToday, forKey: "local_nutrition_calories_\(todayKey)")
        
        // Обновление сегодняшнего дня в недельных шагах
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
        
        // Сохранение истории здоровья
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
    
    // Запрос авторизации в HealthKit
    public func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            self.authorizationError = "HealthKit не поддерживается на этом устройстве"
            self.isAuthorized = false
            self.isRequested = true
            return
        }
        
        guard let steps = HKQuantityType.quantityType(forIdentifier: .stepCount),
              let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
              let exerciseTime = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime),
              let standHour = HKCategoryType.categoryType(forIdentifier: .appleStandHour),
              let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate),
              let sleep = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis),
              let water = HKQuantityType.quantityType(forIdentifier: .dietaryWater),
              let weight = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            self.authorizationError = "Не удалось подготовить типы данных HealthKit"
            self.isRequested = true
            return
        }
        
        let typesToRead: Set<HKObjectType> = [
            steps, activeEnergy, exerciseTime, standHour, heartRate, sleep, water, weight, HKObjectType.workoutType()
        ]
        
        let typesToWrite: Set<HKSampleType> = [
            water, weight, HKObjectType.workoutType()
        ]
        
        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { success, error in
            Task { @MainActor in
                if success {
                    self.isAuthorized = true
                    self.isRequested = true
                    self.authorizationError = nil
                    UserDefaults.standard.set(true, forKey: "HealthKitRequested")
                    self.fetchAllData()
                } else {
                    self.authorizationError = error?.localizedDescription ?? "Доступ к HealthKit отклонен"
                    self.isRequested = true
                    self.isAuthorized = false
                }
            }
        }
    }
    
    // Получение всех свежих данных из HealthKit
    public func fetchAllData() {
        loadLocalData()
        
        guard HKHealthStore.isHealthDataAvailable() && UserDefaults.standard.bool(forKey: "HealthKitRequested") else {
            return
        }
        
        Task {
            async let steps = fetchSteps()
            async let calories = fetchActiveEnergy()
            async let exercise = fetchExerciseTime()
            async let stand = fetchStandHours()
            async let heart = fetchLatestHeartRate()
            async let sleep = fetchSleepDuration()
            async let water = fetchWaterConsumed()
            async let weight = fetchLatestWeight()
            async let workouts = fetchWorkoutHistoryFromHealthKit()
            
            let fetchedSteps = await steps
            let fetchedCalories = await calories
            let fetchedExercise = await exercise
            let fetchedStand = await stand
            let fetchedHeart = await heart
            let fetchedSleep = await sleep
            let fetchedWater = await water
            let fetchedWeight = await weight
            let fetchedWorkouts = await workouts
            
            await MainActor.run {
                // Обновляем только при валидных значениях, чтобы не затереть оффлайн-данные
                if fetchedSteps > 0 { self.stepsToday = fetchedSteps }
                if fetchedCalories > 0 { self.activeEnergyBurned = fetchedCalories }
                if fetchedExercise > 0 { self.exerciseTime = fetchedExercise }
                if fetchedStand > 0 { self.standHours = fetchedStand }
                if fetchedHeart > 0 { self.heartRate = fetchedHeart }
                if fetchedSleep > 0 { self.sleepDuration = fetchedSleep }
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
                
                self.saveLocalData()
            }
            
            // Запрашиваем шаги за неделю
            let fetchedWeekly = await fetchWeeklyStepsFromHealthKit()
            await MainActor.run {
                if !fetchedWeekly.isEmpty {
                    self.weeklySteps = fetchedWeekly
                }
            }
        }
    }
    
    // --- ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ЧТЕНИЯ HEALTHKIT ---
    
    private func fetchSteps() async -> Int {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }
        let now = Date()
        let start = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                let steps = result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
                continuation.resume(returning: Int(steps))
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
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
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
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
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
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
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
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
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
    
    private func fetchSleepDuration() async -> Double {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return 0.0 }
        let now = Date()
        let startOfYesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let predicate = HKQuery.predicateForSamples(withStart: startOfYesterday, end: now, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                guard let categorySamples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: 0.0)
                    return
                }
                let asleepSamples = categorySamples.filter {
                    $0.value == HKCategoryValueSleepAnalysis.asleep.rawValue ||
                    $0.value == 6 || // asleepDeep
                    $0.value == 7 || // asleepREM
                    $0.value == 8    // asleepCore
                }
                let totalSeconds = asleepSamples.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                continuation.resume(returning: totalSeconds / 3600.0)
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
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                let liters = result?.sumQuantity()?.doubleValue(for: HKUnit.literUnit(with: .milli)) ?? 0.0
                continuation.resume(returning: liters)
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchLatestWeight() async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return 0.0 }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
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
                let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
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
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 10, sortDescriptors: [sortDescriptor]) { _, samples, error in
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
    
    // --- ЗАПИСЬ ДАННЫХ В HEALTHKIT И ЛОКАЛЬНО ---
    
    public func addWater(amount: Double) {
        self.waterConsumed += amount
        saveLocalData()
        
        guard HKHealthStore.isHealthDataAvailable() && UserDefaults.standard.bool(forKey: "HealthKitRequested"),
              let type = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else { return }
        
        let quantity = HKQuantity(unit: HKUnit.literUnit(with: .milli), doubleValue: amount)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: Date(), end: Date())
        
        healthStore.save(sample) { success, error in
            if !success {
                print("Ошибка сохранения воды в HealthKit: \(error?.localizedDescription ?? "неизвестно")")
            }
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
        healthStore.save(sample) { _, _ in }
    }
    
    public func addWeight(weight: Double) {
        addWeightRecordLocally(weight: weight)
        saveLocalData()
        
        guard HKHealthStore.isHealthDataAvailable() && UserDefaults.standard.bool(forKey: "HealthKitRequested"),
              let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }
        
        let quantity = HKQuantity(unit: HKUnit.gramUnit(with: .kilo), doubleValue: weight)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: Date(), end: Date())
        
        healthStore.save(sample) { success, error in
            if !success {
                print("Ошибка сохранения веса в HealthKit: \(error?.localizedDescription ?? "неизвестно")")
            }
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
        
        healthStore.save(workout) { success, error in
            if success {
                print("Тренировка успешно сохранена в HealthKit")
            } else {
                print("Ошибка сохранения тренировки в HealthKit: \(error?.localizedDescription ?? "неизвестно")")
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
        self.activeEnergyBurned += activeEnergyBurned
        
        if activityType == "Run" || activityType == "Walk" {
            let addedSteps = Int(distance * 1.25)
            self.stepsToday += addedSteps
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
