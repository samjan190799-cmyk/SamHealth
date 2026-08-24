import Foundation
import SwiftUI
import Combine
import HealthKit
import UserNotifications

// MARK: - Менеджер интеграции с Apple Health (HealthKit) и локальным кэшем
@MainActor
public class HealthKitManager: ObservableObject {
    public static let shared = HealthKitManager()
    
    public let healthStore = HKHealthStore()
    
    // MARK: - Флаги состояния
    @Published public var isHealthDataAvailable: Bool = HKHealthStore.isHealthDataAvailable()
    @Published public var isAuthorized: Bool = false
    @Published public var isRequested: Bool = false
    @Published public var authorizationError: String? = nil
    @Published public var showAuthorizationAlert: Bool = false
    @Published public var authorizationAlertMessage: String = ""
    @Published public var isSyncing: Bool = false
    @Published public var lastSyncTime: Date? = nil
    
    // Индикаторы глубокого импорта
    @Published public var isHistoricalSyncInProgress: Bool = false
    @Published public var historicalSyncStatusMessage: String? = nil
    @Published public var historicalSyncStats: (days: Int, workouts: Int, weights: Int) = (0, 0, 0)
    
    // MARK: - Пульс
    @Published public var isLiveHeartRateActive: Bool = false
    @Published public var liveHeartRate: Double = 72.0
    @Published public var latestHeartRate: Double = 72.0
    @Published public var restingHeartRate: Double = 64.0
    public var heartRate: Double {
        isLiveHeartRateActive ? liveHeartRate : latestHeartRate
    }
    
    public var heartRateZone: HeartRateZone {
        HeartRateZone.zone(for: Int(heartRate))
    }
    
    @Published public var isHeartRateMonitoringEnabled: Bool = false
    @Published public var heartRateAlertsEnabled: Bool = false
    @Published public var highHeartRateThreshold: Int = 110
    @Published public var recoveryAlertsEnabled: Bool = false
    
    // MARK: - Основные дневные показатели
    @Published public var stepsToday: Int = 0
    public var todaySteps: Int { stepsToday }
    
    @Published public var todayFloors: Int = 0
    @Published public var stepDistanceKm: Double = 0.0
    public var distanceTodayKm: Double { stepDistanceKm }
    public var distanceMetersToday: Double { stepDistanceKm * 1000.0 }
    
    @Published public var activeEnergyBurned: Double = 0.0
    @Published public var activeEnergyGoal: Double = 500.0
    @Published public var basalEnergyBurned: Double = 1650.0
    public var calculatedBasalEnergy: Double { basalEnergyBurned > 0 ? basalEnergyBurned : 1650.0 }
    public var totalEnergyBurned: Double {
        (activeEnergyBurned > 0 ? activeEnergyBurned : calculatedStepCalories) + basalEnergyBurned
    }
    
    public var calorieBalance: Double {
        caloriesConsumedToday - totalEnergyBurned
    }
    
    @Published public var appleExerciseTimeMinutes: Int = 0
    public var exerciseTime: Double { Double(appleExerciseTimeMinutes) }
    @Published public var exerciseGoal: Double = 30.0
    @Published public var appleStandHours: Int = 8
    @Published public var standHoursGoal: Int = 12
    
    @Published public var currentWeight: Double = 74.5
    @Published public var weightTrend: WeightTrendType = .stable
    
    // MARK: - Сон и Фазы
    @Published public var todaySleepHours: Double = 0.0
    public var sleepDuration: Double { todaySleepHours }
    @Published public var deepSleepDuration: Double = 0.0
    @Published public var remSleepDuration: Double = 0.0
    @Published public var coreSleepDuration: Double = 0.0
    @Published public var awakeDuration: Double = 0.0
    @Published public var sleepQualityScore: Int = 0
    
    // MARK: - Кардио и Восстановление (HRV, VO2 Max, SpO2)
    @Published public var hrvSDNN: Double = 0.0 // мс (Вариабельность пульса)
    @Published public var recoveryScore: Int = 0 // 0-100%
    @Published public var stressLevel: String = "--"
    @Published public var vo2Max: Double = 0.0 // мл/кг/мин (Кардиовыносливость)
    @Published public var cardioFitnessLevel: String = "--"
    @Published public var walkingHeartRateAverage: Double = 0.0 // уд/мин
    @Published public var bloodOxygen: Double = 0.0 // %
    @Published public var respiratoryRate: Double = 0.0 // вдохов/мин
    
    // MARK: - Вода
    @Published public var waterConsumedToday: Double = 0.0
    public var waterConsumed: Double {
        get { waterConsumedToday }
        set { waterConsumedToday = newValue; saveLocalData() }
    }
    @Published public var waterGoal: Double = 2500.0
    
    // MARK: - Питание
    @Published public var caloriesConsumedToday: Double = 0.0
    @Published public var proteinConsumedToday: Double = 0.0
    @Published public var fatConsumedToday: Double = 0.0
    @Published public var carbsConsumedToday: Double = 0.0
    
    // MARK: - Списки и История
    @Published public var weeklySteps: [WeeklyStepsData] = []
    @Published public var workoutHistory: [WorkoutRecord] = []
    @Published public var weightHistory: [WeightRecord] = []
    @Published public var dailyActivityHistory: [String: DailyActivitySummary] = [:]
    @Published public var nutritionHistory: [DailyNutritionRecord] = []
    @Published public var lastWorkoutString: String = "Нет записей"
    
    public var calculatedStepCalories: Double {
        let weight = currentWeight > 30 ? currentWeight : 74.5
        let factor = (weight / 70.0) * 0.042
        return Double(stepsToday) * factor
    }
    
    private var todayKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    public init() {
        loadLocalData()
        checkExistingAuthorization()
    }
    
    // MARK: - Проверка авторизации при старте
    private func checkExistingAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            self.isHealthDataAvailable = false
            return
        }
        
        let wasAuthorized = UserDefaults.standard.bool(forKey: "healthkit_authorized_user")
        if wasAuthorized {
            self.isAuthorized = true
            self.isRequested = true
            fetchAllData()
            setupBackgroundObservers()
        }
    }
    
    public func onAppAppear() {
        loadLocalData()
        if isAuthorized {
            fetchAllData()
        } else if HKHealthStore.isHealthDataAvailable() {
            if !UserDefaults.standard.bool(forKey: "healthkit_auto_prompted_v3") {
                UserDefaults.standard.set(true, forKey: "healthkit_auto_prompted_v3")
                requestAuthorization()
            } else {
                checkHealthDataAndAutoEnable()
            }
        }
    }
    
    public func checkHealthDataAndAutoEnable() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: stepsType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, statistics, _ in
            if let sum = statistics?.sumQuantity() {
                let steps = sum.doubleValue(for: .count())
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        self.isAuthorized = true
                    }
                    UserDefaults.standard.set(true, forKey: "healthkit_authorized_user")
                    if steps > 0 {
                        self.stepsToday = Int(steps)
                    }
                    self.fetchAllData()
                    self.setupBackgroundObservers()
                    Task {
                        await self.syncFullHistoricalData(daysBack: 365)
                    }
                }
            }
        }
        healthStore.execute(query)
    }
    
    // MARK: - Запрос разрешений Apple Health
    public func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            self.isHealthDataAvailable = false
            return
        }
        
        var readTypes: Set<HKObjectType> = []
        var shareTypes: Set<HKSampleType> = []
        
        // Шаги и движение
        if let steps = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            readTypes.insert(steps)
            shareTypes.insert(steps)
        }
        if let distance = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            readTypes.insert(distance)
            shareTypes.insert(distance)
        }
        if let flights = HKQuantityType.quantityType(forIdentifier: .flightsClimbed) {
            readTypes.insert(flights)
        }
        
        // Энергия и кольца
        if let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            readTypes.insert(activeEnergy)
            shareTypes.insert(activeEnergy)
        }
        if let basalEnergy = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) {
            readTypes.insert(basalEnergy)
        }
        if let exerciseTime = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) {
            readTypes.insert(exerciseTime)
        }
        if let standHour = HKCategoryType.categoryType(forIdentifier: .appleStandHour) {
            readTypes.insert(standHour)
        }
        
        // Пульс и кардио
        if let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            readTypes.insert(heartRate)
            shareTypes.insert(heartRate)
        }
        if let restingHR = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) {
            readTypes.insert(restingHR)
        }
        if let walkingHR = HKQuantityType.quantityType(forIdentifier: .walkingHeartRateAverage) {
            readTypes.insert(walkingHR)
        }
        if let hrv = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            readTypes.insert(hrv)
        }
        if let vo2 = HKQuantityType.quantityType(forIdentifier: .vo2Max) {
            readTypes.insert(vo2)
        }
        if let spo2 = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) {
            readTypes.insert(spo2)
        }
        if let resp = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) {
            readTypes.insert(resp)
        }
        
        // Сон
        if let sleep = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            readTypes.insert(sleep)
            shareTypes.insert(sleep)
        }
        
        // Вес
        if let weight = HKQuantityType.quantityType(forIdentifier: .bodyMass) {
            readTypes.insert(weight)
            shareTypes.insert(weight)
        }
        
        // Вода и Питание (Макро и Микронутриенты)
        if let water = HKQuantityType.quantityType(forIdentifier: .dietaryWater) {
            readTypes.insert(water)
            shareTypes.insert(water)
        }
        if let energyConsumed = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) {
            readTypes.insert(energyConsumed)
            shareTypes.insert(energyConsumed)
        }
        if let protein = HKQuantityType.quantityType(forIdentifier: .dietaryProtein) {
            readTypes.insert(protein)
            shareTypes.insert(protein)
        }
        if let fat = HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal) {
            readTypes.insert(fat)
            shareTypes.insert(fat)
        }
        if let carbs = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates) {
            readTypes.insert(carbs)
            shareTypes.insert(carbs)
        }
        if let fiber = HKQuantityType.quantityType(forIdentifier: .dietaryFiber) {
            readTypes.insert(fiber)
            shareTypes.insert(fiber)
        }
        if let sugar = HKQuantityType.quantityType(forIdentifier: .dietarySugar) {
            readTypes.insert(sugar)
            shareTypes.insert(sugar)
        }
        if let sodium = HKQuantityType.quantityType(forIdentifier: .dietarySodium) {
            readTypes.insert(sodium)
            shareTypes.insert(sodium)
        }
        
        // Тренировки
        let workoutType = HKWorkoutType.workoutType()
        readTypes.insert(workoutType)
        shareTypes.insert(workoutType)
        
        self.isRequested = true
        self.isSyncing = true
        
        healthStore.requestAuthorization(toShare: shareTypes, read: readTypes) { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isSyncing = false
                if let error = error {
                    self.authorizationError = error.localizedDescription
                    self.isAuthorized = false
                    self.authorizationAlertMessage = "Apple Health: \(error.localizedDescription)\n\nПожалуйста, проверьте «Настройки» -> «Здоровье» -> «Доступ к данным» -> «Forma»."
                    self.showAuthorizationAlert = true
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        self.isAuthorized = true
                    }
                    self.authorizationError = nil
                    UserDefaults.standard.set(true, forKey: "healthkit_authorized_user")
                    self.fetchAllData()
                    self.setupBackgroundObservers()
                    
                    // Автоматическая глубокая синхронизация 365 дней истории!
                    Task {
                        await self.syncFullHistoricalData(daysBack: 365)
                    }
                }
            }
        }
    }
    
    public func resetAndReauthorize() {
        requestAuthorization()
    }
    
    public func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
    
    // MARK: - Сбор всех данных
    public func fetchAllData() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        self.isSyncing = true
        
        Task {
            await fetchTodayMetrics()
            await fetchHeartRate()
            await fetchHRV()
            await fetchVO2Max()
            await fetchRestingAndWalkingHeartRate()
            await fetchBloodOxygen()
            await fetchSleepData()
            await fetchWorkouts()
            await fetchWeightHistory()
            await fetchWeeklySteps()
            
            await MainActor.run {
                self.isSyncing = false
                self.lastSyncTime = Date()
                self.saveLocalData()
            }
        }
    }
    
    public func syncAllWithHaptic() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        fetchAllData()
        
        Task {
            await syncFullHistoricalData(daysBack: 365)
            await MainActor.run {
                let notif = UINotificationFeedbackGenerator()
                notif.notificationOccurred(.success)
            }
        }
    }
    
    // MARK: - Запросы метрик за сегодня
    private func fetchTodayMetrics() async {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
        
        // 1. Шаги
        if let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            let steps = await executeSumQuantityQuery(type: stepsType, unit: .count(), predicate: predicate)
            if steps > 0 {
                self.stepsToday = Int(steps)
            }
        }
        
        // 2. Дистанция
        if let distType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            let distMeters = await executeSumQuantityQuery(type: distType, unit: .meter(), predicate: predicate)
            if distMeters > 0 {
                self.stepDistanceKm = distMeters / 1000.0
            }
        }
        
        // 3. Этажи
        if let floorsType = HKQuantityType.quantityType(forIdentifier: .flightsClimbed) {
            let floors = await executeSumQuantityQuery(type: floorsType, unit: .count(), predicate: predicate)
            if floors > 0 {
                self.todayFloors = Int(floors)
            }
        }
        
        // 4. Активные калории
        if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            let energy = await executeSumQuantityQuery(type: energyType, unit: .kilocalorie(), predicate: predicate)
            if energy > 0 {
                self.activeEnergyBurned = energy
            } else {
                self.activeEnergyBurned = self.calculatedStepCalories
            }
        }
        
        // 5. Базовый обмен
        if let basalType = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) {
            let basal = await executeSumQuantityQuery(type: basalType, unit: .kilocalorie(), predicate: predicate)
            if basal > 0 {
                self.basalEnergyBurned = basal
            }
        }
        
        // 6. Время упражнений
        if let exerciseType = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) {
            let exerciseMin = await executeSumQuantityQuery(type: exerciseType, unit: .minute(), predicate: predicate)
            if exerciseMin > 0 {
                self.appleExerciseTimeMinutes = Int(exerciseMin)
            }
        }
        
        // 7. Вода
        if let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) {
            let waterMl = await executeSumQuantityQuery(type: waterType, unit: .literUnit(with: .milli), predicate: predicate)
            let localWater = UserDefaults.standard.double(forKey: "water_consumed_\(todayKey)")
            let effectiveWater = max(waterMl, localWater)
            if effectiveWater > 0 {
                self.waterConsumedToday = effectiveWater
            }
        }
        
        // 8. Питание
        if let foodCalType = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) {
            let cal = await executeSumQuantityQuery(type: foodCalType, unit: .kilocalorie(), predicate: predicate)
            let localCal = UserDefaults.standard.double(forKey: "nutrition_calories_\(todayKey)")
            let effectiveCal = max(cal, localCal)
            if effectiveCal > 0 {
                self.caloriesConsumedToday = effectiveCal
            }
        }
        if let proteinType = HKQuantityType.quantityType(forIdentifier: .dietaryProtein) {
            let prot = await executeSumQuantityQuery(type: proteinType, unit: .gram(), predicate: predicate)
            let localProt = UserDefaults.standard.double(forKey: "nutrition_protein_\(todayKey)")
            let effectiveProt = max(prot, localProt)
            if effectiveProt > 0 { self.proteinConsumedToday = effectiveProt }
        }
        if let fatType = HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal) {
            let fat = await executeSumQuantityQuery(type: fatType, unit: .gram(), predicate: predicate)
            let localFat = UserDefaults.standard.double(forKey: "nutrition_fat_\(todayKey)")
            let effectiveFat = max(fat, localFat)
            if effectiveFat > 0 { self.fatConsumedToday = effectiveFat }
        }
        if let carbsType = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates) {
            let carbs = await executeSumQuantityQuery(type: carbsType, unit: .gram(), predicate: predicate)
            let localCarbs = UserDefaults.standard.double(forKey: "nutrition_carbs_\(todayKey)")
            let effectiveCarbs = max(carbs, localCarbs)
            if effectiveCarbs > 0 { self.carbsConsumedToday = effectiveCarbs }
        }
        
        // Обновляем дневную сводку
        let summary = DailyActivitySummary(
            dateKey: todayKey,
            date: Date(),
            steps: stepsToday,
            distanceMeters: stepDistanceKm * 1000.0,
            activeCalories: activeEnergyBurned
        )
        self.dailyActivityHistory[todayKey] = summary
    }
    
    // MARK: - Расчет индекса восстановления
    public func calculateRecoveryScore(hrv: Double, restingHR: Double) -> (score: Int, stress: String) {
        var baseScore = Int((hrv / 65.0) * 80.0)
        if restingHR > 0 {
            if restingHR < 60 {
                baseScore += 10
            } else if restingHR > 75 {
                baseScore -= 10
            }
        }
        let finalScore = max(10, min(100, baseScore))
        let stress: String
        if finalScore >= 75 {
            stress = "Низкий"
        } else if finalScore >= 45 {
            stress = "Умеренный"
        } else {
            stress = "Повышенный"
        }
        return (finalScore, stress)
    }
    
    // MARK: - Пульс и Кардиопоказатели
    private func fetchHeartRate() async {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: hrType, predicate: nil, limit: 1, sortDescriptors: [sort]) { [weak self] _, samples, _ in
                if let sample = samples?.first as? HKQuantitySample {
                    let hr = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    DispatchQueue.main.async {
                        self?.latestHeartRate = hr
                    }
                }
                continuation.resume()
            }
            self.healthStore.execute(query)
        }
    }
    
    private func fetchHRV() async {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: hrvType, predicate: nil, limit: 1, sortDescriptors: [sort]) { [weak self] _, samples, _ in
                if let sample = samples?.first as? HKQuantitySample {
                    let hrv = sample.quantity.doubleValue(for: .secondUnit(with: .milli))
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        self.hrvSDNN = hrv
                        let recovery = self.calculateRecoveryScore(hrv: hrv, restingHR: self.restingHeartRate)
                        self.recoveryScore = recovery.score
                        self.stressLevel = recovery.stress
                    }
                }
                continuation.resume()
            }
            self.healthStore.execute(query)
        }
    }
    
    private func fetchVO2Max() async {
        guard let vo2Type = HKQuantityType.quantityType(forIdentifier: .vo2Max) else { return }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: vo2Type, predicate: nil, limit: 1, sortDescriptors: [sort]) { [weak self] _, samples, _ in
                if let sample = samples?.first as? HKQuantitySample {
                    let vo2 = sample.quantity.doubleValue(for: HKUnit(from: "ml/kg*min"))
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        self.vo2Max = vo2
                        if vo2 >= 48.0 {
                            self.cardioFitnessLevel = "Высокая"
                        } else if vo2 >= 38.0 {
                            self.cardioFitnessLevel = "Выше среднего"
                        } else if vo2 >= 30.0 {
                            self.cardioFitnessLevel = "Средняя"
                        } else {
                            self.cardioFitnessLevel = "Ниже среднего"
                        }
                    }
                }
                continuation.resume()
            }
            self.healthStore.execute(query)
        }
    }
    
    private func fetchRestingAndWalkingHeartRate() async {
        if let rhrType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) {
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            await withCheckedContinuation { continuation in
                let query = HKSampleQuery(sampleType: rhrType, predicate: nil, limit: 1, sortDescriptors: [sort]) { [weak self] _, samples, _ in
                    if let sample = samples?.first as? HKQuantitySample {
                        let rhr = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                        DispatchQueue.main.async {
                            self?.restingHeartRate = rhr
                        }
                    }
                    continuation.resume()
                }
                self.healthStore.execute(query)
            }
        }
        
        if let whrType = HKQuantityType.quantityType(forIdentifier: .walkingHeartRateAverage) {
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            await withCheckedContinuation { continuation in
                let query = HKSampleQuery(sampleType: whrType, predicate: nil, limit: 1, sortDescriptors: [sort]) { [weak self] _, samples, _ in
                    if let sample = samples?.first as? HKQuantitySample {
                        let whr = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                        DispatchQueue.main.async {
                            self?.walkingHeartRateAverage = whr
                        }
                    }
                    continuation.resume()
                }
                self.healthStore.execute(query)
            }
        }
    }
    
    private func fetchBloodOxygen() async {
        if let spo2Type = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) {
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            await withCheckedContinuation { continuation in
                let query = HKSampleQuery(sampleType: spo2Type, predicate: nil, limit: 1, sortDescriptors: [sort]) { [weak self] _, samples, _ in
                    if let sample = samples?.first as? HKQuantitySample {
                        let spo2 = sample.quantity.doubleValue(for: .percent()) * 100.0
                        DispatchQueue.main.async {
                            self?.bloodOxygen = spo2
                        }
                    }
                    continuation.resume()
                }
                self.healthStore.execute(query)
            }
        }
        
        if let respType = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) {
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            await withCheckedContinuation { continuation in
                let query = HKSampleQuery(sampleType: respType, predicate: nil, limit: 1, sortDescriptors: [sort]) { [weak self] _, samples, _ in
                    if let sample = samples?.first as? HKQuantitySample {
                        let resp = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                        DispatchQueue.main.async {
                            self?.respiratoryRate = resp
                        }
                    }
                    continuation.resume()
                }
                self.healthStore.execute(query)
            }
        }
    }
    
    // MARK: - Сон и Фазы (Apple Watch Sleep Analysis)
    private func fetchSleepData() async {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let startPeriod = calendar.startOfDay(for: yesterday)
        let predicate = HKQuery.predicateForSamples(withStart: startPeriod, end: Date(), options: .strictStartDate)
        
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { [weak self] _, samples, _ in
                guard let self = self, let sleepSamples = samples as? [HKCategorySample] else {
                    continuation.resume()
                    return
                }
                
                var totalDurationSeconds: Double = 0
                var deepDurationSeconds: Double = 0
                var remDurationSeconds: Double = 0
                var coreDurationSeconds: Double = 0
                var awakeDurationSeconds: Double = 0
                
                for sample in sleepSamples {
                    let duration = sample.endDate.timeIntervalSince(sample.startDate)
                    if #available(iOS 16.0, *) {
                        switch sample.value {
                        case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                            coreDurationSeconds += duration
                            totalDurationSeconds += duration
                        case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                            deepDurationSeconds += duration
                            totalDurationSeconds += duration
                        case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                            remDurationSeconds += duration
                            totalDurationSeconds += duration
                        case HKCategoryValueSleepAnalysis.awake.rawValue:
                            awakeDurationSeconds += duration
                        default:
                            if sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue {
                                totalDurationSeconds += duration
                            }
                        }
                    } else {
                        if sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue {
                            totalDurationSeconds += duration
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    if totalDurationSeconds > 0 {
                        let totalHours = totalDurationSeconds / 3600.0
                        self.todaySleepHours = totalHours
                        self.deepSleepDuration = deepDurationSeconds > 0 ? (deepDurationSeconds / 3600.0) : (totalHours * 0.25)
                        self.remSleepDuration = remDurationSeconds > 0 ? (remDurationSeconds / 3600.0) : (totalHours * 0.22)
                        self.coreSleepDuration = coreDurationSeconds > 0 ? (coreDurationSeconds / 3600.0) : (totalHours * 0.50)
                        self.awakeDuration = awakeDurationSeconds > 0 ? (awakeDurationSeconds / 3600.0) : 0.3
                        
                        var score = Int((totalHours / 8.0) * 70.0)
                        if self.deepSleepDuration >= 1.5 { score += 15 }
                        if self.remSleepDuration >= 1.5 { score += 15 }
                        self.sleepQualityScore = max(30, min(100, score))
                    }
                }
                continuation.resume()
            }
            self.healthStore.execute(query)
        }
    }
    
    // MARK: - Тренировки
    private func fetchWorkouts() async {
        let workoutType = HKWorkoutType.workoutType()
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: workoutType, predicate: nil, limit: 100, sortDescriptors: [sort]) { [weak self] _, samples, _ in
                guard let self = self, let workouts = samples as? [HKWorkout] else {
                    continuation.resume()
                    return
                }
                
                var records: [WorkoutRecord] = []
                for w in workouts {
                    let activityName = self.mapHKWorkoutTypeToString(w.workoutActivityType)
                    let durationMin = max(1, Int(w.duration / 60.0))
                    let calories = w.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0.0
                    
                    let record = WorkoutRecord(
                        id: w.uuid,
                        type: activityName,
                        date: w.startDate,
                        durationMinutes: durationMin,
                        caloriesBurned: calories
                    )
                    records.append(record)
                }
                
                DispatchQueue.main.async {
                    if !records.isEmpty {
                        self.workoutHistory = records
                        if let last = records.first {
                            let formatter = DateFormatter()
                            formatter.locale = Locale(identifier: "ru_RU")
                            formatter.dateFormat = "d MMM"
                            self.lastWorkoutString = "\(last.durationMinutes) мин — \(last.type)\n(\(formatter.string(from: last.date)))"
                        }
                    }
                }
                continuation.resume()
            }
            self.healthStore.execute(query)
        }
    }
    
    // MARK: - Вес
    private func fetchWeightHistory() async {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: weightType, predicate: nil, limit: 100, sortDescriptors: [sort]) { [weak self] _, samples, _ in
                guard let self = self, let weightSamples = samples as? [HKQuantitySample] else {
                    continuation.resume()
                    return
                }
                
                var records: [WeightRecord] = []
                for s in weightSamples {
                    let kg = s.quantity.doubleValue(for: .gramUnit(with: .kilo))
                    let rec = WeightRecord(id: s.uuid, date: s.startDate, weight: kg)
                    records.append(rec)
                }
                
                DispatchQueue.main.async {
                    if !records.isEmpty {
                        self.weightHistory = records
                        if let last = records.last {
                            self.currentWeight = last.weight
                        }
                        if records.count >= 2 {
                            let prev = records[records.count - 2].weight
                            let diff = (records.last?.weight ?? 0) - prev
                            if diff > 0.1 { self.weightTrend = .up }
                            else if diff < -0.1 { self.weightTrend = .down }
                            else { self.weightTrend = .stable }
                        }
                    }
                }
                continuation.resume()
            }
            self.healthStore.execute(query)
        }
    }
    
    // MARK: - Недельные шаги
    private func fetchWeeklySteps() async {
        guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        let calendar = Calendar.current
        let now = Date()
        guard let weekAgo = calendar.date(byAdding: .day, value: -6, to: now) else { return }
        let start = calendar.startOfDay(for: weekAgo)
        
        var interval = DateComponents()
        interval.day = 1
        
        let query = HKStatisticsCollectionQuery(
            quantityType: stepsType,
            quantitySamplePredicate: nil,
            options: .cumulativeSum,
            anchorDate: start,
            intervalComponents: interval
        )
        
        await withCheckedContinuation { continuation in
            query.initialResultsHandler = { [weak self] _, results, _ in
                guard let self = self, let stats = results else {
                    continuation.resume()
                    return
                }
                
                var dayItems: [WeeklyStepsData] = []
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "ru_RU")
                formatter.dateFormat = "EE"
                
                stats.enumerateStatistics(from: start, to: now) { statistic, _ in
                    let dayName = formatter.string(from: statistic.startDate).capitalized
                    let steps = statistic.sumQuantity()?.doubleValue(for: .count()) ?? 0
                    dayItems.append(WeeklyStepsData(day: dayName, steps: Int(steps)))
                }
                
                DispatchQueue.main.async {
                    if !dayItems.isEmpty {
                        self.weeklySteps = dayItems
                    }
                }
                continuation.resume()
            }
            self.healthStore.execute(query)
        }
    }
    
    // MARK: - Автоматическая Глубокая Синхронизация Истории (365 дней)
    public func syncFullHistoricalData(daysBack: Int = 365) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        await MainActor.run {
            self.isHistoricalSyncInProgress = true
            self.historicalSyncStatusMessage = "Синхронизация истории здоровья (365 дней)..."
        }
        
        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -daysBack, to: now) else {
            await MainActor.run { self.isHistoricalSyncInProgress = false }
            return
        }
        let startAnchor = calendar.startOfDay(for: startDate)
        
        var interval = DateComponents()
        interval.day = 1
        
        // 1. Шаги за 365 дней
        if let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            let stepsQuery = HKStatisticsCollectionQuery(
                quantityType: stepsType,
                quantitySamplePredicate: nil,
                options: .cumulativeSum,
                anchorDate: startAnchor,
                intervalComponents: interval
            )
            
            await withCheckedContinuation { continuation in
                stepsQuery.initialResultsHandler = { [weak self] _, results, _ in
                    guard let self = self, let stats = results else {
                        continuation.resume()
                        return
                    }
                    
                    let keyFormatter = DateFormatter()
                    keyFormatter.dateFormat = "yyyy-MM-dd"
                    
                    var historyDict: [String: DailyActivitySummary] = [:]
                    
                    stats.enumerateStatistics(from: startAnchor, to: now) { statistic, _ in
                        let key = keyFormatter.string(from: statistic.startDate)
                        let steps = statistic.sumQuantity()?.doubleValue(for: .count()) ?? 0
                        let distKm = (steps * 0.75) / 1000.0
                        let cal = steps * 0.042
                        
                        let summary = DailyActivitySummary(
                            dateKey: key,
                            date: statistic.startDate,
                            steps: Int(steps),
                            distanceMeters: distKm * 1000.0,
                            activeCalories: cal
                        )
                        historyDict[key] = summary
                    }
                    
                    DispatchQueue.main.async {
                        self.dailyActivityHistory.merge(historyDict) { _, new in new }
                    }
                    continuation.resume()
                }
                self.healthStore.execute(stepsQuery)
            }
        }
        
        // 2. Тренировки и Вес
        await fetchWorkouts()
        await fetchWeightHistory()
        
        await MainActor.run {
            self.historicalSyncStats = (self.dailyActivityHistory.count, self.workoutHistory.count, self.weightHistory.count)
            self.isHistoricalSyncInProgress = false
            self.historicalSyncStatusMessage = nil
            self.lastSyncTime = Date()
            self.saveLocalData()
        }
    }
    
    // MARK: - Фоновые наблюдатели
    public func setupBackgroundObservers() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        if let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            let query = HKObserverQuery(sampleType: stepsType, predicate: nil) { [weak self] _, completionHandler, _ in
                Task {
                    await self?.fetchTodayMetrics()
                    completionHandler()
                }
            }
            healthStore.execute(query)
            healthStore.enableBackgroundDelivery(for: stepsType, frequency: .immediate) { _, _ in }
        }
        
        let workoutType = HKWorkoutType.workoutType()
        let wQuery = HKObserverQuery(sampleType: workoutType, predicate: nil) { [weak self] _, completionHandler, _ in
            Task {
                await self?.fetchWorkouts()
                completionHandler()
            }
        }
        healthStore.execute(wQuery)
        healthStore.enableBackgroundDelivery(for: workoutType, frequency: .immediate) { _, _ in }
    }
    
    public func setupHeartRateObserver() {
        // Фоновый мониторинг пульса
    }
    
    // MARK: - Запись данных в Apple Health и локально
    
    public func saveWorkout(activityType: String, durationMinutes: Int, caloriesBurned: Double) {
        let now = Date()
        let start = now.addingTimeInterval(-Double(durationMinutes) * 60.0)
        saveWorkout(activityType: activityType, startDate: start, endDate: now, activeEnergyBurned: caloriesBurned, distance: 0.0)
    }
    
    public func saveWorkout(activityType: String, startDate: Date, endDate: Date, activeEnergyBurned: Double, distance: Double) {
        let durationMinutes = max(1, Int(endDate.timeIntervalSince(startDate) / 60.0))
        
        let record = WorkoutRecord(
            type: activityType,
            date: startDate,
            durationMinutes: durationMinutes,
            caloriesBurned: activeEnergyBurned
        )
        self.workoutHistory.insert(record, at: 0)
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM"
        self.lastWorkoutString = "\(durationMinutes) мин — \(activityType)\n(\(formatter.string(from: startDate)))"
        
        GamificationManager.shared.addXP(100, reason: "Завершена тренировка \(activityType)")
        saveLocalData()
        
        // Запись в HKHealthStore
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let hkType = mapStringToHKWorkoutActivityType(activityType)
        let energyQty = HKQuantity(unit: .kilocalorie(), doubleValue: activeEnergyBurned)
        let distQty = distance > 0 ? HKQuantity(unit: .meter(), doubleValue: distance) : nil
        
        let workout = HKWorkout(
            activityType: hkType,
            start: startDate,
            end: endDate,
            duration: endDate.timeIntervalSince(startDate),
            totalEnergyBurned: energyQty,
            totalDistance: distQty,
            device: HKDevice.local(),
            metadata: ["App": "Forma"]
        )
        
        healthStore.save(workout) { _, _ in }
    }
    
    public func addWeight(weightInKg: Double, date: Date = Date(), timeOfDay: String? = nil, note: String? = nil) {
        let record = WeightRecord(date: date, weight: weightInKg, timeOfDay: timeOfDay, note: note)
        self.weightHistory.append(record)
        self.weightHistory.sort(by: { $0.date < $1.date })
        
        if let last = self.weightHistory.last {
            self.currentWeight = last.weight
        } else {
            self.currentWeight = weightInKg
        }
        
        if weightHistory.count >= 2 {
            let prev = weightHistory[weightHistory.count - 2].weight
            let diff = self.currentWeight - prev
            if diff > 0.1 { self.weightTrend = .up }
            else if diff < -0.1 { self.weightTrend = .down }
            else { self.weightTrend = .stable }
        }
        saveLocalData()
        
        guard HKHealthStore.isHealthDataAvailable(),
              let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }
        
        let qty = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: weightInKg)
        let sample = HKQuantitySample(type: weightType, quantity: qty, start: date, end: date)
        healthStore.save(sample) { _, _ in }
    }
    
    public func addWeight(weight: Double) {
        addWeight(weightInKg: weight, date: Date())
    }
    
    public func deleteWeightRecord(id: UUID) {
        self.weightHistory.removeAll(where: { $0.id == id })
        if let last = self.weightHistory.last {
            self.currentWeight = last.weight
        } else {
            self.currentWeight = 0.0
        }
        
        if weightHistory.count >= 2 {
            let prev = weightHistory[weightHistory.count - 2].weight
            let diff = self.currentWeight - prev
            if diff > 0.1 { self.weightTrend = .up }
            else if diff < -0.1 { self.weightTrend = .down }
            else { self.weightTrend = .stable }
        } else {
            self.weightTrend = .stable
        }
        saveLocalData()
    }
    
    public func logWaterDirectly(milliliters: Double) {
        self.waterConsumedToday += milliliters
        saveLocalData()
        
        guard HKHealthStore.isHealthDataAvailable(),
              let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else { return }
        
        let qty = HKQuantity(unit: .literUnit(with: .milli), doubleValue: milliliters)
        let sample = HKQuantitySample(type: waterType, quantity: qty, start: Date(), end: Date())
        healthStore.save(sample) { _, _ in }
    }
    
    public func addWater(milliliters: Double) {
        logWaterDirectly(milliliters: milliliters)
    }
    
    public func addWater(amount: Double) {
        logWaterDirectly(milliliters: amount)
    }
    
    public func resetWater() {
        self.waterConsumedToday = 0.0
        saveLocalData()
    }
    
    public func logNutritionDirectly(calories: Double, protein: Double = 0, fat: Double = 0, carbs: Double = 0) {
        self.caloriesConsumedToday += calories
        self.proteinConsumedToday += protein
        self.fatConsumedToday += fat
        self.carbsConsumedToday += carbs
        
        let newRecord = DailyNutritionRecord(dateString: todayKey, calories: caloriesConsumedToday)
        if let idx = self.nutritionHistory.firstIndex(where: { $0.dateString == todayKey }) {
            self.nutritionHistory[idx] = newRecord
        } else {
            self.nutritionHistory.append(newRecord)
        }
        saveLocalData()
    }
    
    public func addDietaryNutrition(calories: Double, protein: Double = 0, fat: Double = 0, carbs: Double = 0, fiber: Double? = nil, sugar: Double? = nil, sodium: Double? = nil, mealName: String = "") {
        logNutritionDirectly(calories: calories, protein: protein, fat: fat, carbs: carbs)
        
        guard HKHealthStore.isHealthDataAvailable() else { return }
        var samples: [HKQuantitySample] = []
        let now = Date()
        
        if let calType = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed), calories > 0 {
            let q = HKQuantity(unit: .kilocalorie(), doubleValue: calories)
            samples.append(HKQuantitySample(type: calType, quantity: q, start: now, end: now, metadata: ["Meal": mealName]))
        }
        if let protType = HKQuantityType.quantityType(forIdentifier: .dietaryProtein), protein > 0 {
            let q = HKQuantity(unit: .gram(), doubleValue: protein)
            samples.append(HKQuantitySample(type: protType, quantity: q, start: now, end: now))
        }
        if let fatType = HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal), fat > 0 {
            let q = HKQuantity(unit: .gram(), doubleValue: fat)
            samples.append(HKQuantitySample(type: fatType, quantity: q, start: now, end: now))
        }
        if let carbsType = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates), carbs > 0 {
            let q = HKQuantity(unit: .gram(), doubleValue: carbs)
            samples.append(HKQuantitySample(type: carbsType, quantity: q, start: now, end: now))
        }
        if let fib = fiber, fib > 0, let fiberType = HKQuantityType.quantityType(forIdentifier: .dietaryFiber) {
            let q = HKQuantity(unit: .gram(), doubleValue: fib)
            samples.append(HKQuantitySample(type: fiberType, quantity: q, start: now, end: now))
        }
        if let sug = sugar, sug > 0, let sugarType = HKQuantityType.quantityType(forIdentifier: .dietarySugar) {
            let q = HKQuantity(unit: .gram(), doubleValue: sug)
            samples.append(HKQuantitySample(type: sugarType, quantity: q, start: now, end: now))
        }
        if let sod = sodium, sod > 0, let sodiumType = HKQuantityType.quantityType(forIdentifier: .dietarySodium) {
            let q = HKQuantity(unit: .gramUnit(with: .milli), doubleValue: sod)
            samples.append(HKQuantitySample(type: sodiumType, quantity: q, start: now, end: now))
        }
        
        if !samples.isEmpty {
            healthStore.save(samples) { _, _ in }
        }
    }
    
    public func addSleepRecord(hours: Double, deepHours: Double = 0.0, startDate: Date = Date(), endDate: Date = Date()) {
        let totalHours = max(0.5, hours)
        let deep = deepHours > 0 ? min(deepHours, totalHours * 0.5) : (totalHours * 0.25)
        let rem = totalHours * 0.22
        let core = max(0.0, totalHours - deep - rem)
        
        self.todaySleepHours = totalHours
        self.deepSleepDuration = deep
        self.remSleepDuration = rem
        self.coreSleepDuration = core
        self.awakeDuration = 0.2
        
        var score = Int((totalHours / 8.0) * 70.0)
        if self.deepSleepDuration >= 1.5 { score += 15 }
        if self.remSleepDuration >= 1.5 { score += 15 }
        self.sleepQualityScore = max(30, min(100, score))
        
        saveLocalData()
        
        guard HKHealthStore.isHealthDataAvailable(),
              let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        
        let sample = HKCategorySample(type: sleepType, value: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue, start: startDate, end: endDate)
        healthStore.save(sample) { _, _ in }
    }
    
    public func addHeartRateSample(bpm: Double) {
        self.latestHeartRate = bpm
        guard HKHealthStore.isHealthDataAvailable(),
              let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        let qty = HKQuantity(unit: HKUnit.count().unitDivided(by: .minute()), doubleValue: bpm)
        let sample = HKQuantitySample(type: hrType, quantity: qty, start: Date(), end: Date())
        healthStore.save(sample) { _, _ in }
    }
    
    public func addHeartRateSample(bpm: Int) {
        addHeartRateSample(bpm: Double(bpm))
    }
    
    public func startLiveHeartRateSession() {
        self.isLiveHeartRateActive = true
    }
    
    public func stopLiveHeartRateSession() {
        self.isLiveHeartRateActive = false
    }
    
    public func toggleLiveHeartRateSession() {
        self.isLiveHeartRateActive.toggle()
    }
    
    public func syncHistoricalStepsFromHealthKit(days: Int = 365) {
        Task {
            await syncFullHistoricalData(daysBack: days)
        }
    }
    
    // MARK: - Запросы по датам
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
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let key = formatter.string(from: date)
        return dailyActivityHistory[key]?.steps ?? 0
    }
    
    // MARK: - Локальное сохранение и загрузка
    public func loadLocalData() {
        let defaults = UserDefaults.standard
        
        if defaults.object(forKey: "health_steps_\(todayKey)") != nil {
            self.stepsToday = defaults.integer(forKey: "health_steps_\(todayKey)")
        } else {
            self.stepsToday = defaults.integer(forKey: "today_step_count")
        }
        
        self.stepDistanceKm = defaults.double(forKey: "health_distance_\(todayKey)")
        if self.stepDistanceKm == 0 && self.stepsToday > 0 {
            self.stepDistanceKm = (Double(self.stepsToday) * 0.75) / 1000.0
        }
        
        self.todayFloors = defaults.integer(forKey: "health_floors_\(todayKey)")
        self.waterConsumedToday = defaults.double(forKey: "water_consumed_\(todayKey)")
        self.caloriesConsumedToday = defaults.double(forKey: "nutrition_calories_\(todayKey)")
        self.proteinConsumedToday = defaults.double(forKey: "nutrition_protein_\(todayKey)")
        self.fatConsumedToday = defaults.double(forKey: "nutrition_fat_\(todayKey)")
        self.carbsConsumedToday = defaults.double(forKey: "nutrition_carbs_\(todayKey)")
        
        if defaults.double(forKey: "health_water_goal") > 0 {
            self.waterGoal = defaults.double(forKey: "health_water_goal")
        }
        if defaults.double(forKey: "health_user_weight") > 0 {
            self.currentWeight = defaults.double(forKey: "health_user_weight")
        }
        if defaults.double(forKey: "health_sleep_\(todayKey)") > 0 {
            self.todaySleepHours = defaults.double(forKey: "health_sleep_\(todayKey)")
        }
        
        if let data = defaults.data(forKey: "health_workout_history"),
           let workouts = try? JSONDecoder().decode([WorkoutRecord].self, from: data) {
            self.workoutHistory = workouts
            if let last = workouts.first {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "ru_RU")
                formatter.dateFormat = "d MMM"
                self.lastWorkoutString = "\(last.durationMinutes) мин — \(last.type)\n(\(formatter.string(from: last.date)))"
            }
        }
        
        if let data = defaults.data(forKey: "health_weight_history"),
           let weights = try? JSONDecoder().decode([WeightRecord].self, from: data) {
            self.weightHistory = weights
            if let last = weights.last {
                self.currentWeight = last.weight
            }
        }
        
        if let data = defaults.data(forKey: "health_daily_activity_history"),
           let activity = try? JSONDecoder().decode([String: DailyActivitySummary].self, from: data) {
            self.dailyActivityHistory = activity
        }
        
        if let data = defaults.data(forKey: "health_nutrition_history"),
           let nutrition = try? JSONDecoder().decode([DailyNutritionRecord].self, from: data) {
            self.nutritionHistory = nutrition
        }
        
        if let data = defaults.data(forKey: "health_weekly_steps"),
           let weekly = try? JSONDecoder().decode([WeeklyStepsData].self, from: data) {
            self.weeklySteps = weekly
        } else {
            generateDefaultWeeklySteps()
        }
    }
    
    public func saveLocalData() {
        let defaults = UserDefaults.standard
        defaults.set(stepsToday, forKey: "health_steps_\(todayKey)")
        defaults.set(stepDistanceKm, forKey: "health_distance_\(todayKey)")
        defaults.set(todayFloors, forKey: "health_floors_\(todayKey)")
        defaults.set(waterConsumedToday, forKey: "water_consumed_\(todayKey)")
        defaults.set(waterGoal, forKey: "health_water_goal")
        defaults.set(caloriesConsumedToday, forKey: "nutrition_calories_\(todayKey)")
        defaults.set(proteinConsumedToday, forKey: "nutrition_protein_\(todayKey)")
        defaults.set(fatConsumedToday, forKey: "nutrition_fat_\(todayKey)")
        defaults.set(carbsConsumedToday, forKey: "nutrition_carbs_\(todayKey)")
        defaults.set(currentWeight, forKey: "health_user_weight")
        defaults.set(todaySleepHours, forKey: "health_sleep_\(todayKey)")
        
        if let encoded = try? JSONEncoder().encode(workoutHistory) {
            defaults.set(encoded, forKey: "health_workout_history")
        }
        if let encoded = try? JSONEncoder().encode(weightHistory) {
            defaults.set(encoded, forKey: "health_weight_history")
        }
        if let encoded = try? JSONEncoder().encode(dailyActivityHistory) {
            defaults.set(encoded, forKey: "health_daily_activity_history")
        }
        if let encoded = try? JSONEncoder().encode(nutritionHistory) {
            defaults.set(encoded, forKey: "health_nutrition_history")
        }
        if let encoded = try? JSONEncoder().encode(weeklySteps) {
            defaults.set(encoded, forKey: "health_weekly_steps")
        }
        
        syncWidgetsData()
    }
    
    // MARK: - Синхронизация данных виджетов WidgetKit
    public func syncWidgetsData() {
        let coach = AICoachManager.shared.currentCoach
        let userWeight = currentWeight > 30 ? currentWeight : 74.5
        let userGoalWeight = 70.0
        let realSteps = max(stepsToday, BackgroundStepManager.shared.stepsToday)
        let realActiveCalories = activeEnergyBurned > 0 ? activeEnergyBurned : calculatedStepCalories
        let totalBurned = realActiveCalories + (basalEnergyBurned > 0 ? basalEnergyBurned : 1650.0)
        let balance = caloriesConsumedToday - totalBurned
        let currentHR = heartRate > 0 ? Int(heartRate) : (latestHeartRate > 0 ? Int(latestHeartRate) : (restingHeartRate > 0 ? Int(restingHeartRate) : 0))
        
        let snapshot = FormaWidgetDataSnapshot(
            stepsToday: realSteps,
            stepGoal: BackgroundStepManager.shared.stepGoal > 0 ? BackgroundStepManager.shared.stepGoal : 10000,
            activeCalories: realActiveCalories,
            activeCaloriesGoal: activeEnergyGoal > 0 ? activeEnergyGoal : 500.0,
            exerciseMinutes: appleExerciseTimeMinutes,
            exerciseMinutesGoal: Int(exerciseGoal > 0 ? exerciseGoal : 30),
            standHours: appleStandHours,
            standHoursGoal: standHoursGoal > 0 ? standHoursGoal : 12,
            currentHeartRate: currentHR,
            waterConsumed: waterConsumedToday,
            waterGoal: waterGoal > 0 ? waterGoal : 2500.0,
            caloriesConsumed: caloriesConsumedToday,
            totalCaloriesBurned: totalBurned,
            energyBalance: balance,
            currentWeight: userWeight,
            targetWeight: userGoalWeight,
            coachId: coach.id.rawValue,
            coachName: coach.name,
            coachAvatarAssetName: coach.avatarAssetName,
            coachBadgeEmoji: coach.badgeEmoji,
            coachAdvice: "Отличный темп активности! Держи ритм, пей воду и не забывай о разминке.",
            lastUpdated: Date()
        )
        
        FormaWidgetDataManager.shared.saveSnapshot(snapshot)
    }
    
    private func generateDefaultWeeklySteps() {
        let days = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
        self.weeklySteps = days.map { day in
            WeeklyStepsData(day: day, steps: Int.random(in: 4000...11000))
        }
    }
    
    // MARK: - Пакетный импорт данных из CSV
    public func importWorkoutsFromCSV(_ workouts: [WorkoutRecord], saveToHK: Bool = true) async {
        for w in workouts {
            self.workoutHistory.append(w)
        }
        self.workoutHistory.sort(by: { $0.date > $1.date })
        saveLocalData()
        
        if saveToHK && HKHealthStore.isHealthDataAvailable() {
            let _ = await HealthDataCSVManager.shared.writeWorkoutsToHealthKit(workouts)
        }
    }
    
    public func importWeightsFromCSV(_ weights: [WeightRecord], saveToHK: Bool = true) async {
        for w in weights {
            self.weightHistory.append(w)
        }
        self.weightHistory.sort(by: { $0.date < $1.date })
        if let last = self.weightHistory.last {
            self.currentWeight = last.weight
        }
        saveLocalData()
        
        if saveToHK && HKHealthStore.isHealthDataAvailable() {
            let _ = await HealthDataCSVManager.shared.writeWeightsToHealthKit(weights)
        }
    }
    
    public func importActivitiesFromCSV(_ activities: [DailyActivitySummary], saveToHK: Bool = true) async {
        for a in activities {
            self.dailyActivityHistory[a.dateKey] = a
        }
        saveLocalData()
    }
    
    public func importNutritionsFromCSV(_ nutritions: [DailyNutritionRecord], waters: [(date: Date, ml: Double)], saveToHK: Bool = true) async {
        for n in nutritions {
            if let idx = self.nutritionHistory.firstIndex(where: { $0.dateString == n.dateString }) {
                self.nutritionHistory[idx].calories += n.calories
            } else {
                self.nutritionHistory.append(n)
            }
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        for w in waters {
            let key = formatter.string(from: w.date)
            if key == todayKey {
                self.waterConsumedToday += w.ml
            }
        }
        saveLocalData()
    }
    
    public func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
    
    // MARK: - Вспомогательные функции запросов
    private func executeSumQuantityQuery(type: HKQuantityType, unit: HKUnit, predicate: NSPredicate) async -> Double {
        await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, _ in
                let value = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0.0
                continuation.resume(returning: value)
            }
            self.healthStore.execute(query)
        }
    }
    
    private func mapHKWorkoutTypeToString(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "Бег"
        case .walking: return "Ходьба"
        case .cycling: return "Велосипед"
        case .swimming: return "Плавание"
        case .yoga: return "Йога"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "Силовая"
        case .jumpRope: return "Скакалка"
        case .highIntensityIntervalTraining: return "HIIT"
        default: return "Тренировка"
        }
    }
    
    private func mapStringToHKWorkoutActivityType(_ str: String) -> HKWorkoutActivityType {
        let lower = str.lowercased()
        if lower.contains("бег") || lower.contains("run") { return .running }
        if lower.contains("ходьб") || lower.contains("walk") { return .walking }
        if lower.contains("вело") || lower.contains("cycl") || lower.contains("bike") { return .cycling }
        if lower.contains("плав") || lower.contains("swim") { return .swimming }
        if lower.contains("йог") || lower.contains("yoga") { return .yoga }
        if lower.contains("сил") || lower.contains("strength") || lower.contains("гантел") || lower.contains("gym") { return .traditionalStrengthTraining }
        if lower.contains("скакал") || lower.contains("rope") { return .jumpRope }
        if lower.contains("hiit") || lower.contains("интервал") { return .highIntensityIntervalTraining }
        return .other
    }
}
