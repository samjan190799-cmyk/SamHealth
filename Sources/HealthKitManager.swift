import Foundation
import SwiftUI
import Combine
import UserNotifications

// MARK: - Автономный менеджер данных здоровья Forma (100% Local Storage)
@MainActor
public class HealthKitManager: ObservableObject {
    public static let shared = HealthKitManager()
    
    // Флаги состояния
    @Published public var isHealthDataAvailable: Bool = true
    @Published public var isAuthorized: Bool = true
    @Published public var isRequested: Bool = true
    @Published public var authorizationError: String? = nil
    @Published public var isSyncing: Bool = false
    @Published public var lastSyncTime: Date? = Date()
    
    // Индикаторы глубокого импорта
    @Published public var isHistoricalSyncInProgress: Bool = false
    @Published public var historicalSyncStatusMessage: String? = nil
    @Published public var historicalSyncStats: (days: Int, workouts: Int, weights: Int) = (0, 0, 0)
    
    // Основные метрики здоровья за сегодня
    @Published public var stepsToday: Int = 0
    @Published public var todayFloors: Int = 0
    @Published public var stepDistanceKm: Double = 0.0
    @Published public var activeEnergyBurned: Double = 0.0
    @Published public var basalEnergyBurned: Double = 1650.0 // Средний базовый обмен
    @Published public var appleExerciseTimeMinutes: Int = 0
    @Published public var appleStandHours: Int = 8
    
    @Published public var latestHeartRate: Double = 72.0
    @Published public var restingHeartRate: Double = 64.0
    @Published public var currentWeight: Double = 74.5
    @Published public var weightTrend: WeightTrendType = .stable
    @Published public var todaySleepHours: Double = 7.5
    @Published public var waterConsumedToday: Double = 0.0
    @Published public var caloriesConsumedToday: Double = 0.0
    
    // Исторические списки
    @Published public var weeklySteps: [WeeklyStepsData] = []
    @Published public var workoutHistory: [WorkoutRecord] = []
    @Published public var weightHistory: [WeightRecord] = []
    @Published public var dailyActivityHistory: [String: DailyActivitySummary] = [:]
    @Published public var nutritionHistory: [DailyNutritionRecord] = []
    @Published public var lastWorkoutString: String = "Нет записей"
    
    // Модель расчета калорий ходьбы (Apple Fitness model: ~0.04 ккал/шаг для веса 70-75 кг)
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
        updateTodayMetricsFromLocal()
    }
    
    // MARK: - Жизненный цикл приложения
    public func onAppAppear() {
        loadLocalData()
        updateTodayMetricsFromLocal()
    }
    
    public func fetchAllData() {
        loadLocalData()
        updateTodayMetricsFromLocal()
        lastSyncTime = Date()
    }
    
    public func syncAllWithHaptic() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        fetchAllData()
        let notif = UINotificationFeedbackGenerator()
        notif.notificationOccurred(.success)
    }
    
    public func resetAndReauthorize() {
        loadLocalData()
        updateTodayMetricsFromLocal()
    }
    
    public func requestAuthorization() {
        self.isAuthorized = true
        self.isRequested = true
        fetchAllData()
    }
    
    public func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
    
    // MARK: - Локальная загрузка и сохранение данных
    public func loadLocalData() {
        let defaults = UserDefaults.standard
        
        // Шаги и дистанция
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
        
        if defaults.double(forKey: "health_user_weight") > 0 {
            self.currentWeight = defaults.double(forKey: "health_user_weight")
        }
        
        if defaults.double(forKey: "health_sleep_\(todayKey)") > 0 {
            self.todaySleepHours = defaults.double(forKey: "health_sleep_\(todayKey)")
        }
        
        // Загрузка тренировок
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
        
        // Загрузка веса
        if let data = defaults.data(forKey: "health_weight_history"),
           let weights = try? JSONDecoder().decode([WeightRecord].self, from: data) {
            self.weightHistory = weights
            if let last = weights.last {
                self.currentWeight = last.weight
            }
        }
        
        // Загрузка активности
        if let data = defaults.data(forKey: "health_daily_activity_history"),
           let activity = try? JSONDecoder().decode([String: DailyActivitySummary].self, from: data) {
            self.dailyActivityHistory = activity
        }
        
        // Загрузка питания
        if let data = defaults.data(forKey: "health_nutrition_history"),
           let nutrition = try? JSONDecoder().decode([DailyNutritionRecord].self, from: data) {
            self.nutritionHistory = nutrition
        }
        
        // Загрузка недельных шагов
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
        defaults.set(caloriesConsumedToday, forKey: "nutrition_calories_\(todayKey)")
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
    }
    
    private func updateTodayMetricsFromLocal() {
        self.activeEnergyBurned = self.calculatedStepCalories
        
        // Обновляем дневную сводку
        let summary = DailyActivitySummary(
            dateKey: todayKey,
            date: Date(),
            steps: stepsToday,
            distanceMeters: stepDistanceKm * 1000.0,
            activeCalories: activeEnergyBurned
        )
        self.dailyActivityHistory[todayKey] = summary
        self.historicalSyncStats = (dailyActivityHistory.count, workoutHistory.count, weightHistory.count)
    }
    
    private func generateDefaultWeeklySteps() {
        let days = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
        self.weeklySteps = days.map { day in
            WeeklyStepsData(day: day, steps: Int.random(in: 4000...11000))
        }
    }
    
    // MARK: - Прямая запись метрик (Локальное сохранение)
    
    public func logWaterDirectly(milliliters: Double) {
        self.waterConsumedToday += milliliters
        UserDefaults.standard.set(self.waterConsumedToday, forKey: "water_consumed_\(todayKey)")
        saveLocalData()
    }
    
    public func addWater(milliliters: Double) {
        logWaterDirectly(milliliters: milliliters)
    }
    
    public func logNutritionDirectly(calories: Double, protein: Double = 0, fat: Double = 0, carbs: Double = 0) {
        self.caloriesConsumedToday += calories
        UserDefaults.standard.set(self.caloriesConsumedToday, forKey: "nutrition_calories_\(todayKey)")
        
        let newRecord = DailyNutritionRecord(dateString: todayKey, calories: caloriesConsumedToday)
        if let idx = self.nutritionHistory.firstIndex(where: { $0.dateString == todayKey }) {
            self.nutritionHistory[idx] = newRecord
        } else {
            self.nutritionHistory.append(newRecord)
        }
        saveLocalData()
    }
    
    public func addDietaryNutrition(calories: Double, protein: Double, fat: Double, carbs: Double, mealName: String = "") {
        logNutritionDirectly(calories: calories, protein: protein, fat: fat, carbs: carbs)
    }
    
    public var todaySteps: Int {
        return stepsToday
    }
    
    public var distanceTodayKm: Double {
        return stepDistanceKm
    }
    
    public func addWeight(weightInKg: Double) {
        self.currentWeight = weightInKg
        let newRecord = WeightRecord(date: Date(), weight: weightInKg)
        self.weightHistory.append(newRecord)
        
        if weightHistory.count >= 2 {
            let prev = weightHistory[weightHistory.count - 2].weight
            let diff = weightInKg - prev
            if diff > 0.1 { self.weightTrend = .up }
            else if diff < -0.1 { self.weightTrend = .down }
            else { self.weightTrend = .stable }
        }
        saveLocalData()
    }
    
    public func saveWorkout(activityType: String, durationMinutes: Int, caloriesBurned: Double) {
        let record = WorkoutRecord(
            date: Date(),
            type: activityType,
            durationMinutes: durationMinutes,
            caloriesBurned: caloriesBurned
        )
        self.workoutHistory.insert(record, at: 0)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM"
        self.lastWorkoutString = "\(durationMinutes) мин — \(activityType)\n(\(formatter.string(from: Date())))"
        
        // Начисляем опыт за тренировку в геймификацию
        GamificationManager.shared.addXP(100, reason: "Завершена тренировка \(activityType)")
        saveLocalData()
    }
    
    public func addSleepRecord(hours: Double) {
        self.todaySleepHours = hours
        saveLocalData()
    }
    
    public func addHeartRateSample(bpm: Double) {
        self.latestHeartRate = bpm
    }
    
    public func syncHistoricalStepsFromHealthKit(days: Int = 365) {
        loadLocalData()
    }
    
    public func syncFullHistoricalData(daysBack: Int = 365) async {
        await MainActor.run {
            self.isHistoricalSyncInProgress = true
            self.historicalSyncStatusMessage = "Синхронизация данных..."
        }
        
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        await MainActor.run {
            self.loadLocalData()
            self.updateTodayMetricsFromLocal()
            self.isHistoricalSyncInProgress = false
            self.historicalSyncStatusMessage = nil
            self.lastSyncTime = Date()
        }
    }
    
    // MARK: - Пакетный импорт данных из CSV в локальное хранилище
    
    public func importWorkoutsFromCSV(_ workouts: [WorkoutRecord], saveToHK: Bool = false) async {
        for w in workouts {
            self.workoutHistory.append(w)
        }
        self.workoutHistory.sort(by: { $0.date > $1.date })
        saveLocalData()
    }
    
    public func importWeightsFromCSV(_ weights: [WeightRecord], saveToHK: Bool = false) async {
        for w in weights {
            self.weightHistory.append(w)
        }
        self.weightHistory.sort(by: { $0.date < $1.date })
        if let last = self.weightHistory.last {
            self.currentWeight = last.weight
        }
        saveLocalData()
    }
    
    public func importActivitiesFromCSV(_ activities: [DailyActivitySummary], saveToHK: Bool = false) async {
        for a in activities {
            self.dailyActivityHistory[a.dateKey] = a
        }
        saveLocalData()
    }
    
    public func importNutritionsFromCSV(_ nutritions: [DailyNutritionRecord], waters: [(date: Date, ml: Double)], saveToHK: Bool = false) async {
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
}
