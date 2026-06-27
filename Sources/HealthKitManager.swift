import SwiftUI
import Combine

@MainActor
public class HealthKitManager: ObservableObject {
    
    // Состояние авторизации (всегда true для локального режима)
    @Published public var isAuthorized = true
    @Published public var isRequested = true
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
        loadLocalData()
    }
    
    // Инициализация дефолтных данных
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
        // Заглушка, сразу переходим на дашборд
        self.isRequested = true
        self.isAuthorized = true
        UserDefaults.standard.set(true, forKey: "HealthKitRequested")
        loadLocalData()
    }
    
    public func fetchAllData() {
        loadLocalData()
    }
    
    // Запись выпитой воды
    public func addWater(amount: Double) {
        self.waterConsumed += amount
        saveLocalData()
    }
    
    // Запись потребленной еды (калории)
    public func addDietaryEnergy(calories: Double) {
        self.activeEnergyBurned += calories
        saveLocalData()
    }
    
    // Запись тренировки локально
    public func saveWorkout(activityType: String, startDate: Date, endDate: Date, activeEnergyBurned: Double, distance: Double) {
        let durationMinutes = Int(endDate.timeIntervalSince(startDate) / 60)
        let typeName = activityType.capitalized
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMM d"
        let dateStr = formatter.string(from: startDate)
        
        self.lastWorkoutString = "\(durationMinutes)m \(typeName)\n(\(dateStr))"
        self.activeEnergyBurned += activeEnergyBurned
        
        // Симулируем шаги, если это бег или ходьба
        if activityType == "Run" || activityType == "Walk" {
            let addedSteps = Int(distance * 1.25)
            self.stepsToday += addedSteps
        }
        
        saveLocalData()
    }
}
