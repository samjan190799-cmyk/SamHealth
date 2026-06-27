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
    
    // История здоровья (вес, тренировки, питание)
    @Published public var weightHistory: [WeightRecord] = []
    @Published public var workoutHistory: [WorkoutRecord] = []
    @Published public var nutritionHistory: [DailyNutritionRecord] = []
    
    private var todayKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    public init() {
        // Миграция: если версия данных не совпадает, сбрасываем все старые данные
        let dataVersion = UserDefaults.standard.integer(forKey: "AppDataVersion")
        if dataVersion < 2 {
            UserDefaults.standard.removeObject(forKey: "MockDataInitialized")
            UserDefaults.standard.set(2, forKey: "AppDataVersion")
        }
        setupDefaultMockData()
        loadLocalData()
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
        
        // Логируем калории в историю по дням
        if let idx = self.nutritionHistory.firstIndex(where: { $0.dateString == todayKey }) {
            self.nutritionHistory[idx].calories += calories
        } else {
            let newNutrition = DailyNutritionRecord(dateString: todayKey, calories: calories)
            self.nutritionHistory.append(newNutrition)
        }
        
        // Ограничим историю 30 днями
        if self.nutritionHistory.count > 30 {
            self.nutritionHistory.removeFirst()
        }
        
        saveLocalData()
    }
    
    // Запись текущего веса
    public func addWeight(weight: Double) {
        let record = WeightRecord(weight: weight)
        self.weightHistory.append(record)
        // Ограничиваем историю веса 30 записями
        if self.weightHistory.count > 30 {
            self.weightHistory.removeFirst()
        }
        
        // Рассчитываем тренд веса на основе последних двух записей
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
        saveLocalData()
    }
    
    // Запись тренировки локально
    public func saveWorkout(activityType: String, startDate: Date, endDate: Date, activeEnergyBurned: Double, distance: Double) {
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
        default: typeName = activityType
        }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM"
        let dateStr = formatter.string(from: startDate)
        
        self.lastWorkoutString = "\(durationMinutes) мин — \(typeName)\n(\(dateStr))"
        self.activeEnergyBurned += activeEnergyBurned
        
        // Симулируем шаги, если это бег, ходьба или скакалка
        if activityType == "Run" || activityType == "Walk" {
            let addedSteps = Int(distance * 1.25)
            self.stepsToday += addedSteps
        } else if activityType == "JumpRope" {
            let addedSteps = durationMinutes * 130
            self.stepsToday += addedSteps
        }
        
        // Запись тренировки в историю
        let record = WorkoutRecord(
            type: typeName,
            date: startDate,
            durationMinutes: durationMinutes,
            caloriesBurned: activeEnergyBurned
        )
        self.workoutHistory.append(record)
        if self.workoutHistory.count > 20 {
            self.workoutHistory.removeFirst()
        }
        
        saveLocalData()
    }
}
