import SwiftUI
import HealthKit
import Combine

@MainActor
public class HealthKitManager: ObservableObject {
    public let healthStore = HKHealthStore()
    
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
    
    private var todayKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    public init() {
        setupDefaultMockData()
        
        if HKHealthStore.isHealthDataAvailable() {
            checkAuthorizationStatus()
        } else {
            // Если HealthKit недоступен, мы работаем в локальном/демо-режиме
            self.isAuthorized = false
            self.isRequested = UserDefaults.standard.bool(forKey: "HealthKitRequested")
            loadLocalData()
        }
    }
    
    private func checkAuthorizationStatus() {
        self.isRequested = UserDefaults.standard.bool(forKey: "HealthKitRequested")
        if self.isRequested {
            self.isAuthorized = true
            fetchAllData()
        } else {
            loadLocalData()
        }
    }
    
    // Инициализация дефолтных данных (чтобы при первом запуске приложение соответствовало скриншоту)
    private func setupDefaultMockData() {
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "MockDataInitialized") {
            defaults.set(1700.0, forKey: "local_water_\(todayKey)") // 1.7 L
            defaults.set(3000.0, forKey: "local_water_goal") // 3.0 L
            defaults.set(9450, forKey: "local_steps_\(todayKey)") // 9450 шагов
            defaults.set(680.0, forKey: "local_calories_\(todayKey)") // 680 CAL
            defaults.set(45.0, forKey: "local_exercise_\(todayKey)") // 45 мин
            defaults.set(8.0, forKey: "local_stand_\(todayKey)") // 8 ч
            defaults.set(7.2, forKey: "local_sleep")
            defaults.set(74, forKey: "local_heart_rate")
            defaults.set(78.5, forKey: "local_weight")
            defaults.set("45m Run\n(May 15)", forKey: "local_last_workout")
            
            // Недельные шаги
            let weeklyData = [
                ["day": "Пн", "steps": 8200],
                ["day": "Вт", "steps": 9450],
                ["day": "Ср", "steps": 7100],
                ["day": "Чт", "steps": 10200],
                ["day": "Пт", "steps": 8800],
                ["day": "Сб", "steps": 6450],
                ["day": "Вс", "steps": 7900]
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
        
        // Загрузка недельных шагов
        if let data = defaults.data(forKey: "local_weekly_steps"),
           let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            self.weeklySteps = json.compactMap { dict in
                guard let day = dict["day"] as? String, let steps = dict["steps"] as? Int else { return nil }
                return WeeklyStepsData(day: day, steps: steps)
            }
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
    }
    
    public func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            // Если недоступно, переходим в демо-режим
            DispatchQueue.main.async {
                self.isRequested = true
                UserDefaults.standard.set(true, forKey: "HealthKitRequested")
                self.loadLocalData()
            }
            return
        }
        
        // Типы для чтения
        guard let stepCount = HKQuantityType.quantityType(forIdentifier: .stepCount),
              let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
              let exerciseTime = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime),
              let standHour = HKObjectType.categoryType(forIdentifier: .appleStandHour),
              let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate),
              let sleepAnalysis = HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
              let bodyMass = HKQuantityType.quantityType(forIdentifier: .bodyMass),
              let water = HKQuantityType.quantityType(forIdentifier: .dietaryWater),
              let energyConsumed = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) else {
            DispatchQueue.main.async {
                self.isRequested = true
                UserDefaults.standard.set(true, forKey: "HealthKitRequested")
                self.loadLocalData()
            }
            return
        }
        
        let readTypes: Set<HKObjectType> = [
            stepCount, activeEnergy, exerciseTime, standHour, heartRate, sleepAnalysis, bodyMass, water, energyConsumed
        ]
        
        // Типы для записи
        let writeTypes: Set<HKSampleType> = [
            water, energyConsumed, bodyMass, HKWorkoutType.workoutType()
        ]
        
        healthStore.requestAuthorization(toShare: writeTypes, read: readTypes) { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // В ЛЮБОМ СЛУЧАЕ переходим в приложение, чтобы не блокировать интерфейс
                self.isRequested = true
                UserDefaults.standard.set(true, forKey: "HealthKitRequested")
                
                if success {
                    self.isAuthorized = true
                    self.fetchAllData()
                } else {
                    self.isAuthorized = false
                    self.authorizationError = error?.localizedDescription ?? "Права на HealthKit не предоставлены. Включен демо-режим."
                    self.loadLocalData()
                }
            }
        }
    }
    
    // Загрузка всех данных
    public func fetchAllData() {
        guard isAuthorized else {
            loadLocalData()
            return
        }
        
        Task {
            await fetchActiveEnergy()
            await fetchExerciseTime()
            await fetchStandHours()
            await fetchStepsToday()
            await fetchWeeklySteps()
            await fetchHeartRate()
            await fetchSleepDuration()
            await fetchWaterConsumed()
            await fetchWeightAndTrend()
            await fetchLastWorkout()
        }
    }
    
    // Чтение активной энергии
    private func fetchActiveEnergy() async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        let value = await fetchSumToday(for: type, unit: HKUnit.kilocalorie())
        if value > 0 {
            self.activeEnergyBurned = value
        } else {
            self.activeEnergyBurned = UserDefaults.standard.double(forKey: "local_calories_\(todayKey)")
        }
    }
    
    // Чтение времени упражнений
    private func fetchExerciseTime() async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) else { return }
        let value = await fetchSumToday(for: type, unit: HKUnit.minute())
        if value > 0 {
            self.exerciseTime = value
        } else {
            self.exerciseTime = UserDefaults.standard.double(forKey: "local_exercise_\(todayKey)")
        }
    }
    
    // Чтение часов разминки
    private func fetchStandHours() async {
        guard let type = HKObjectType.categoryType(forIdentifier: .appleStandHour) else { return }
        
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { [weak self] _, samples, error in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                guard let categorySamples = samples as? [HKCategorySample] else {
                    continuation.resume()
                    return
                }
                
                let stoodHoursCount = categorySamples.filter { $0.value == HKCategoryValueAppleStandHour.stood.rawValue }.count
                DispatchQueue.main.async {
                    if stoodHoursCount > 0 {
                        self.standHours = Double(stoodHoursCount)
                    } else {
                        self.standHours = UserDefaults.standard.double(forKey: "local_stand_\(todayKey)")
                    }
                    continuation.resume()
                }
            }
            self.healthStore.execute(query)
        }
    }
    
    // Чтение шагов за сегодня
    private func fetchStepsToday() async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        let value = await fetchSumToday(for: type, unit: HKUnit.count())
        if value > 0 {
            self.stepsToday = Int(value)
        } else {
            self.stepsToday = UserDefaults.standard.integer(forKey: "local_steps_\(todayKey)")
        }
    }
    
    // Чтение недельной статистики по шагам
    private func fetchWeeklySteps() async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        
        let calendar = Calendar.current
        let now = Date()
        guard let startOfWeek = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfWeek, end: now, options: .strictStartDate)
        var interval = DateComponents()
        interval.day = 1
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let query = HKStatisticsCollectionQuery(quantityType: type, quantitySamplePredicate: predicate, options: .separateBySource, anchorDate: startOfWeek, intervalComponents: interval)
            
            query.initialResultsHandler = { [weak self] _, results, error in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                guard let statsCollection = results else {
                    continuation.resume()
                    return
                }
                
                var stepsList: [WeeklyStepsData] = []
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "ru_RU")
                formatter.dateFormat = "EE"
                
                statsCollection.enumerateStatistics(from: startOfWeek, to: now) { statistics, _ in
                    let dayName = formatter.string(from: statistics.startDate).capitalized
                    let sum = statistics.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0.0
                    stepsList.append(WeeklyStepsData(day: dayName, steps: Int(sum)))
                }
                
                DispatchQueue.main.async {
                    if !stepsList.isEmpty && stepsList.map({ $0.steps }).reduce(0, +) > 0 {
                        self.weeklySteps = stepsList
                    } else {
                        // Загрузка локальных недельных данных
                        if let data = UserDefaults.standard.data(forKey: "local_weekly_steps"),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                            self.weeklySteps = json.compactMap { dict in
                                guard let day = dict["day"] as? String, let steps = dict["steps"] as? Int else { return nil }
                                return WeeklyStepsData(day: day, steps: steps)
                            }
                        }
                    }
                    continuation.resume()
                }
            }
            self.healthStore.execute(query)
        }
    }
    
    // Чтение пульса
    private func fetchHeartRate() async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, error in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                guard let sample = samples?.first as? HKQuantitySample else {
                    DispatchQueue.main.async {
                        self.heartRate = UserDefaults.standard.integer(forKey: "local_heart_rate")
                        continuation.resume()
                    }
                    return
                }
                
                let hrValue = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                DispatchQueue.main.async {
                    self.heartRate = Int(hrValue)
                    continuation.resume()
                }
            }
            self.healthStore.execute(query)
        }
    }
    
    // Чтение сна за последние 24 часа
    private func fetchSleepDuration() async {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        
        let calendar = Calendar.current
        let now = Date()
        guard let startOfRange = calendar.date(byAdding: .day, value: -1, to: now) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfRange, end: now, options: .strictStartDate)
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { [weak self] _, samples, error in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                guard let sleepSamples = samples as? [HKCategorySample], !sleepSamples.isEmpty else {
                    DispatchQueue.main.async {
                        self.sleepDuration = UserDefaults.standard.double(forKey: "local_sleep")
                        continuation.resume()
                    }
                    return
                }
                
                let totalSleep = sleepSamples
                    .filter { $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue || $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue || $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue || $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue }
                    .reduce(0.0) { sum, sample in
                        sum + sample.endDate.timeIntervalSince(sample.startDate)
                    }
                
                DispatchQueue.main.async {
                    self.sleepDuration = totalSleep / 3600.0
                    continuation.resume()
                }
            }
            self.healthStore.execute(query)
        }
    }
    
    // Чтение выпитой воды
    private func fetchWaterConsumed() async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else { return }
        let value = await fetchSumToday(for: type, unit: HKUnit.literUnit(with: .milli))
        if value > 0 {
            self.waterConsumed = value
        } else {
            self.waterConsumed = UserDefaults.standard.double(forKey: "local_water_\(todayKey)")
        }
    }
    
    // Чтение веса и расчет тренда
    private func fetchWeightAndTrend() async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }
        
        let calendar = Calendar.current
        let now = Date()
        guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: now)) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: sevenDaysAgo, end: now, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, error in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                guard let weightSamples = samples as? [HKQuantitySample], !weightSamples.isEmpty else {
                    DispatchQueue.main.async {
                        self.currentWeight = UserDefaults.standard.double(forKey: "local_weight")
                        self.weightTrend = .stable
                        continuation.resume()
                    }
                    return
                }
                
                let weights = weightSamples.map { $0.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo)) }
                guard let latestWeight = weights.last else {
                    continuation.resume()
                    return
                }
                
                let trend: WeightTrendType
                if weights.count > 1 {
                    let previousWeight = weights[weights.count - 2]
                    let diff = latestWeight - previousWeight
                    if diff > 0.1 {
                        trend = .up
                    } else if diff < -0.1 {
                        trend = .down
                    } else {
                        trend = .stable
                    }
                } else {
                    trend = .stable
                }
                
                DispatchQueue.main.async {
                    self.currentWeight = latestWeight
                    self.weightTrend = trend
                    continuation.resume()
                }
            }
            self.healthStore.execute(query)
        }
    }
    
    // Запись выпитой воды
    public func addWater(amount: Double) {
        // Всегда обновляем локальные данные для мгновенного отклика
        self.waterConsumed += amount
        saveLocalData()
        
        guard isAuthorized, let type = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else { return }
        
        let quantity = HKQuantity(unit: HKUnit.literUnit(with: .milli), doubleValue: amount)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: Date(), end: Date())
        
        healthStore.save(sample) { _, _ in }
    }
    
    // Запись потребленной еды (калории)
    public func addDietaryEnergy(calories: Double) {
        // Обновляем локально активные калории (повышаем подвижность)
        self.activeEnergyBurned += calories
        saveLocalData()
        
        guard isAuthorized, let type = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) else { return }
        
        let quantity = HKQuantity(unit: HKUnit.kilocalorie(), doubleValue: calories)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: Date(), end: Date())
        
        healthStore.save(sample) { _, _ in }
    }
    
    // Вспомогательный метод для получения суммы за сегодня
    private func fetchSumToday(for type: HKQuantityType, unit: HKUnit) async -> Double {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        return await withCheckedContinuation { (continuation: CheckedContinuation<Double, Never>) in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                let sum = result?.sumQuantity()?.doubleValue(for: unit) ?? 0.0
                continuation.resume(returning: sum)
            }
            healthStore.execute(query)
        }
    }
    
    // Запись тренировки в HealthKit
    public func saveWorkout(activityType: HKWorkoutActivityType, startDate: Date, endDate: Date, activeEnergyBurned: Double, distance: Double) {
        // Форматируем для локального вывода
        let durationMinutes = Int(endDate.timeIntervalSince(startDate) / 60)
        let typeName: String
        switch activityType {
        case .running: typeName = "Run"
        case .functionalStrengthTraining: typeName = "Strength"
        case .yoga: typeName = "Yoga"
        case .walking: typeName = "Walk"
        case .cycling: typeName = "Cycling"
        default: typeName = "Workout"
        }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMM d"
        let dateStr = formatter.string(from: startDate)
        
        self.lastWorkoutString = "\(durationMinutes)m \(typeName)\n(\(dateStr))"
        self.activeEnergyBurned += activeEnergyBurned
        
        // Симулируем шаги, если это бег или ходьба
        if activityType == .running || activityType == .walking {
            let addedSteps = Int(distance * 1.25)
            self.stepsToday += addedSteps
        }
        
        saveLocalData()
        
        guard isAuthorized else { return }
        
        let workout = HKWorkout(
            activityType: activityType,
            start: startDate,
            end: endDate,
            duration: endDate.timeIntervalSince(startDate),
            totalEnergyBurned: HKQuantity(unit: HKUnit.kilocalorie(), doubleValue: activeEnergyBurned),
            totalDistance: HKQuantity(unit: HKUnit.meter(), doubleValue: distance),
            device: HKDevice.local(),
            metadata: nil
        )
        
        healthStore.save(workout) { _, _ in }
    }
    
    // Чтение последней тренировки
    private func fetchLastWorkout() async {
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { [weak self] _, samples, error in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                guard let workout = samples?.first as? HKWorkout else {
                    DispatchQueue.main.async {
                        self.lastWorkoutString = UserDefaults.standard.string(forKey: "local_last_workout") ?? "Нет данных"
                        continuation.resume()
                    }
                    return
                }
                
                let durationMinutes = Int(workout.duration / 60)
                let typeName: String
                switch workout.workoutActivityType {
                case .running: typeName = "Run"
                case .functionalStrengthTraining: typeName = "Strength"
                case .yoga: typeName = "Yoga"
                case .walking: typeName = "Walk"
                case .cycling: typeName = "Cycling"
                default: typeName = "Workout"
                }
                
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US")
                formatter.dateFormat = "MMM d"
                let dateStr = formatter.string(from: workout.startDate)
                
                DispatchQueue.main.async {
                    self.lastWorkoutString = "\(durationMinutes)m \(typeName)\n(\(dateStr))"
                    continuation.resume()
                }
            }
            self.healthStore.execute(query)
        }
    }
}
