import SwiftUI
import HealthKit
import Combine

@MainActor
public class HealthKitManager: ObservableObject {
    public let healthStore = HKHealthStore()
    
    // Авторизация
    @Published public var isAuthorized = false
    @Published public var isRequested = false
    @Published public var authorizationError: String? = nil
    
    // Активность (Кольца)
    @Published public var activeEnergyBurned: Double = 0.0 // ккал
    @Published public var activeEnergyGoal: Double = 600.0 // Заглушка цели
    @Published public var exerciseTime: Double = 0.0 // мин
    @Published public var exerciseGoal: Double = 30.0 // Заглушка цели
    @Published public var standHours: Double = 0.0 // ч
    @Published public var standGoal: Double = 12.0 // Заглушка цели
    
    // Шаги
    @Published public var stepsToday: Int = 0
    @Published public var weeklySteps: [WeeklyStepsData] = []
    
    // Здоровье
    @Published public var heartRate: Int = 0 // уд/мин
    @Published public var sleepDuration: Double = 0.0 // ч
    
    // Вода
    @Published public var waterConsumed: Double = 0.0 // мл
    @Published public var waterGoal: Double = 2000.0 // мл
    
    // Вес
    @Published public var currentWeight: Double = 0.0 // кг
    @Published public var weightTrend: WeightTrendType = .stable
    
    // Последняя тренировка
    @Published public var lastWorkoutString: String = "Нет данных"
    
    public init() {
        if HKHealthStore.isHealthDataAvailable() {
            checkAuthorizationStatus()
        } else {
            authorizationError = "HealthKit не поддерживается на этом устройстве"
        }
    }
    
    private func checkAuthorizationStatus() {
        // Проверяем, запрашивались ли уже права. Так как получить точный статус разрешения на чтение в HealthKit
        // из соображений конфиденциальности нельзя, мы ориентируемся на сохраненный флаг в UserDefaults.
        self.isRequested = UserDefaults.standard.bool(forKey: "HealthKitRequested")
        if self.isRequested {
            self.isAuthorized = true
            fetchAllData()
        }
    }
    
    public func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
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
            self.authorizationError = "Не удалось инициализировать типы HealthKit"
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
                if success {
                    self.isAuthorized = true
                    self.isRequested = true
                    UserDefaults.standard.set(true, forKey: "HealthKitRequested")
                    self.fetchAllData()
                } else {
                    self.authorizationError = error?.localizedDescription ?? "Не удалось получить доступ к HealthKit"
                }
            }
        }
    }
    
    // Загрузка всех данных
    public func fetchAllData() {
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
        self.activeEnergyBurned = value
    }
    
    // Чтение времени упражнений
    private func fetchExerciseTime() async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) else { return }
        let value = await fetchSumToday(for: type, unit: HKUnit.minute())
        self.exerciseTime = value
    }
    
    // Чтение часов разминки
    private func fetchStandHours() async {
        guard let type = HKObjectType.categoryType(forIdentifier: .appleStandHour) else { return }
        
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                guard let categorySamples = samples as? [HKCategorySample] else {
                    continuation.resume()
                    return
                }
                
                // Считаем количество часов со значением .stood (разминался)
                let stoodHoursCount = categorySamples.filter { $0.value == HKCategoryValueAppleStandHour.stood.rawValue }.count
                DispatchQueue.main.async {
                    self.standHours = Double(stoodHoursCount)
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
        self.stepsToday = Int(value)
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
        
        await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(quantityType: type, quantitySamplePredicate: predicate, options: .separateBySource, anchorDate: startOfWeek, intervalComponents: interval)
            
            query.initialResultsHandler = { _, results, error in
                guard let statsCollection = results else {
                    continuation.resume()
                    return
                }
                
                var stepsList: [WeeklyStepsData] = []
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "ru_RU")
                formatter.dateFormat = "EE" // Двухбуквенный день недели (Пн, Вт...)
                
                statsCollection.enumerateStatistics(from: startOfWeek, to: now) { statistics, _ in
                    let dayName = formatter.string(from: statistics.startDate).capitalized
                    let sum = statistics.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0.0
                    stepsList.append(WeeklyStepsData(day: dayName, steps: Int(sum)))
                }
                
                DispatchQueue.main.async {
                    self.weeklySteps = stepsList
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
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume()
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
        
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                guard let sleepSamples = samples as? [HKCategorySample] else {
                    continuation.resume()
                    return
                }
                
                // Фильтруем только время в постели или сон
                let totalSleep = sleepSamples
                    .filter { $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue || $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue || $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue || $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue }
                    .reduce(0.0) { sum, sample in
                        sum + sample.endDate.timeIntervalSince(sample.startDate)
                    }
                
                DispatchQueue.main.async {
                    self.sleepDuration = totalSleep / 3600.0 // Переводим в часы
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
        self.waterConsumed = value
    }
    
    // Чтение веса и расчет тренда
    private func fetchWeightAndTrend() async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }
        
        let calendar = Calendar.current
        let now = Date()
        guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: now)) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: sevenDaysAgo, end: now, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                guard let weightSamples = samples as? [HKQuantitySample], !weightSamples.isEmpty else {
                    continuation.resume()
                    return
                }
                
                let weights = weightSamples.map { $0.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo)) }
                guard let latestWeight = weights.last else {
                    continuation.resume()
                    return
                }
                
                // Определяем тренд по сравнению с предыдущими замерами за последние 7 дней
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
        guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else { return }
        
        let quantity = HKQuantity(unit: HKUnit.literUnit(with: .milli), doubleValue: amount)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: Date(), end: Date())
        
        healthStore.save(sample) { [weak self] success, error in
            if success {
                DispatchQueue.main.async {
                    self?.waterConsumed += amount
                }
            }
        }
    }
    
    // Запись потребленной еды (калории)
    public func addDietaryEnergy(calories: Double) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) else { return }
        
        let quantity = HKQuantity(unit: HKUnit.kilocalorie(), doubleValue: calories)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: Date(), end: Date())
        
        healthStore.save(sample) { success, _ in
            if success {
                // Если успешно записали, обновляем кольца активности
                Task {
                    await self.fetchActiveEnergy()
                }
            }
        }
    }
    
    // Вспомогательный метод для получения суммы за сегодня
    private func fetchSumToday(for type: HKQuantityType, unit: HKUnit) async -> Double {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                let sum = result?.sumQuantity()?.doubleValue(for: unit) ?? 0.0
                continuation.resume(returning: sum)
            }
            healthStore.execute(query)
        }
    }
    
    // Запись тренировки в HealthKit
    public func saveWorkout(activityType: HKWorkoutActivityType, startDate: Date, endDate: Date, activeEnergyBurned: Double, distance: Double) {
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
        
        healthStore.save(workout) { [weak self] success, _ in
            if success {
                Task {
                    await self?.fetchAllData()
                }
            }
        }
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
                        self.lastWorkoutString = "Нет данных"
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
