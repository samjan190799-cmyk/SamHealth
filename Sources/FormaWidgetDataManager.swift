import Foundation
import WidgetKit

public struct FormaWidgetDataSnapshot: Codable {
    public var stepsToday: Int
    public var stepGoal: Int
    public var activeCalories: Double
    public var activeCaloriesGoal: Double
    public var exerciseMinutes: Int
    public var exerciseMinutesGoal: Int
    public var standHours: Int
    public var standHoursGoal: Int
    public var currentHeartRate: Int
    public var waterConsumed: Double
    public var waterGoal: Double
    public var caloriesConsumed: Double
    public var totalCaloriesBurned: Double
    public var energyBalance: Double
    public var currentWeight: Double
    public var targetWeight: Double
    public var coachId: String
    public var coachName: String
    public var coachAvatarAssetName: String
    public var coachBadgeEmoji: String
    public var coachAdvice: String
    public var lastUpdated: Date
    public var hourlyStepCounts: [Int]
    
    public init(
        stepsToday: Int = 0,
        stepGoal: Int = 10000,
        activeCalories: Double = 0.0,
        activeCaloriesGoal: Double = 500.0,
        exerciseMinutes: Int = 0,
        exerciseMinutesGoal: Int = 30,
        standHours: Int = 0,
        standHoursGoal: Int = 12,
        currentHeartRate: Int = 0,
        waterConsumed: Double = 0.0,
        waterGoal: Double = 2500.0,
        caloriesConsumed: Double = 0.0,
        totalCaloriesBurned: Double = 0.0,
        energyBalance: Double = 0.0,
        currentWeight: Double = 75.0,
        targetWeight: Double = 70.0,
        coachId: String = "alex",
        coachName: String = "Алекс",
        coachAvatarAssetName: String = "CoachAlexAvatar",
        coachBadgeEmoji: String = "⚡",
        coachAdvice: String = "Начните день с активности и стакана чистой воды!",
        lastUpdated: Date = Date(),
        hourlyStepCounts: [Int] = [0, 0, 0, 0, 0, 0, 0]
    ) {
        self.stepsToday = stepsToday
        self.stepGoal = stepGoal
        self.activeCalories = activeCalories
        self.activeCaloriesGoal = activeCaloriesGoal
        self.exerciseMinutes = exerciseMinutes
        self.exerciseMinutesGoal = exerciseMinutesGoal
        self.standHours = standHours
        self.standHoursGoal = standHoursGoal
        self.currentHeartRate = currentHeartRate
        self.waterConsumed = waterConsumed
        self.waterGoal = waterGoal
        self.caloriesConsumed = caloriesConsumed
        self.totalCaloriesBurned = totalCaloriesBurned
        self.energyBalance = energyBalance
        self.currentWeight = currentWeight
        self.targetWeight = targetWeight
        self.coachId = coachId
        self.coachName = coachName
        self.coachAvatarAssetName = coachAvatarAssetName
        self.coachBadgeEmoji = coachBadgeEmoji
        self.coachAdvice = coachAdvice
        self.lastUpdated = lastUpdated
        self.hourlyStepCounts = hourlyStepCounts
    }
}

public final class FormaWidgetDataManager {
    public static let shared = FormaWidgetDataManager()
    public static let appGroupId = "group.com.samvel.forma"
    private static let storageKey = "forma_widget_snapshot_data"
    private static let sharedFileName = "forma_widget_snapshot.json"
    
    public var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: FormaWidgetDataManager.appGroupId) ?? UserDefaults.standard
    }
    
    private var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: FormaWidgetDataManager.appGroupId)
    }
    
    public init() {}
    
    /// Пример реалистичных данных для превью и первого запуска
    public static func makeSampleSnapshot() -> FormaWidgetDataSnapshot {
        FormaWidgetDataSnapshot(
            stepsToday: 6840,
            stepGoal: 10000,
            activeCalories: 385.0,
            activeCaloriesGoal: 500.0,
            exerciseMinutes: 24,
            exerciseMinutesGoal: 30,
            standHours: 8,
            standHoursGoal: 12,
            currentHeartRate: 72,
            waterConsumed: 1750.0,
            waterGoal: 2500.0,
            caloriesConsumed: 1850.0,
            totalCaloriesBurned: 2200.0,
            energyBalance: -350.0,
            currentWeight: 74.5,
            targetWeight: 70.0,
            coachId: "alex",
            coachName: "Алекс",
            coachAvatarAssetName: "CoachAlexAvatar",
            coachBadgeEmoji: "⚡",
            coachAdvice: "Отличный темп активности! Держите ритм и не забывайте пить воду.",
            lastUpdated: Date(),
            hourlyStepCounts: [450, 890, 1200, 1600, 1400, 900, 400]
        )
    }
    
    public func saveSnapshot(_ snapshot: FormaWidgetDataSnapshot) {
        guard let encoded = try? JSONEncoder().encode(snapshot) else { return }
        
        let defaultsList: [UserDefaults] = [
            UserDefaults(suiteName: FormaWidgetDataManager.appGroupId),
            UserDefaults.standard
        ].compactMap { $0 }
        
        for def in defaultsList {
            // 1. Полный JSON снимок
            def.set(encoded, forKey: FormaWidgetDataManager.storageKey)
            
            // 2. Индивидуальные примитивные ключи (не могут упасть при парсинге)
            def.set(snapshot.stepsToday, forKey: "w_steps_today")
            def.set(snapshot.stepGoal, forKey: "w_step_goal")
            def.set(snapshot.activeCalories, forKey: "w_active_calories")
            def.set(snapshot.activeCaloriesGoal, forKey: "w_active_calories_goal")
            def.set(snapshot.exerciseMinutes, forKey: "w_exercise_minutes")
            def.set(snapshot.exerciseMinutesGoal, forKey: "w_exercise_minutes_goal")
            def.set(snapshot.standHours, forKey: "w_stand_hours")
            def.set(snapshot.standHoursGoal, forKey: "w_stand_hours_goal")
            def.set(snapshot.currentHeartRate, forKey: "w_heart_rate")
            def.set(snapshot.waterConsumed, forKey: "w_water_consumed")
            def.set(snapshot.waterGoal, forKey: "w_water_goal")
            def.set(snapshot.caloriesConsumed, forKey: "w_calories_consumed")
            def.set(snapshot.totalCaloriesBurned, forKey: "w_total_burned")
            def.set(snapshot.energyBalance, forKey: "w_energy_balance")
            def.set(snapshot.coachName, forKey: "w_coach_name")
            def.set(snapshot.coachAvatarAssetName, forKey: "w_coach_avatar")
            def.set(snapshot.coachBadgeEmoji, forKey: "w_coach_emoji")
            def.set(snapshot.coachAdvice, forKey: "w_coach_advice")
            def.set(Date().timeIntervalSince1970, forKey: "w_last_updated_time")
            def.synchronize()
        }
        
        // 3. Сохраняем в общий JSON-файл в директории App Group
        if let containerURL = sharedContainerURL {
            let fileURL = containerURL.appendingPathComponent(FormaWidgetDataManager.sharedFileName)
            try? encoded.write(to: fileURL, options: .atomic)
        }
        
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
    
    public func getSnapshot() -> FormaWidgetDataSnapshot {
        let defaultsList: [UserDefaults] = [
            UserDefaults(suiteName: FormaWidgetDataManager.appGroupId),
            UserDefaults.standard
        ].compactMap { $0 }
        
        var candidates: [FormaWidgetDataSnapshot] = []
        
        // 1. Попытка десериализации полного JSON из AppGroup и Standard
        for def in defaultsList {
            if let data = def.data(forKey: FormaWidgetDataManager.storageKey),
               let decoded = try? JSONDecoder().decode(FormaWidgetDataSnapshot.self, from: data) {
                candidates.append(decoded)
            }
        }
        
        // 2. Проверяем общий JSON-файл в App Group контейнере
        if let containerURL = sharedContainerURL {
            let fileURL = containerURL.appendingPathComponent(FormaWidgetDataManager.sharedFileName)
            if let fileData = try? Data(contentsOf: fileURL),
               let decoded = try? JSONDecoder().decode(FormaWidgetDataSnapshot.self, from: fileData) {
                candidates.append(decoded)
            }
        }
        
        // 3. Выбираем снимок с наиболее свежим временем сохранения
        var bestSnapshot = candidates.max(by: { $0.lastUpdated < $1.lastUpdated }) ?? FormaWidgetDataSnapshot()
        
        // 4. Принудительно проверяем примитивные ключи (они сохраняются синхронно и гарантируют доступность данных)
        for def in defaultsList {
            let primitiveWater = def.double(forKey: "w_water_consumed")
            if primitiveWater > 0 {
                bestSnapshot.waterConsumed = max(bestSnapshot.waterConsumed, primitiveWater)
            }
            let primitiveWaterGoal = def.double(forKey: "w_water_goal")
            if primitiveWaterGoal > 0 {
                bestSnapshot.waterGoal = primitiveWaterGoal
            }
            let primitiveSteps = def.integer(forKey: "w_steps_today")
            if primitiveSteps > 0 {
                bestSnapshot.stepsToday = max(bestSnapshot.stepsToday, primitiveSteps)
            }
            let primitiveActiveCal = def.double(forKey: "w_active_calories")
            if primitiveActiveCal > 0 {
                bestSnapshot.activeCalories = max(bestSnapshot.activeCalories, primitiveActiveCal)
            }
            let savedStepGoal = def.integer(forKey: "w_step_goal")
            if savedStepGoal > 0 { bestSnapshot.stepGoal = savedStepGoal }
            let hr = def.integer(forKey: "w_heart_rate")
            if hr > 0 { bestSnapshot.currentHeartRate = hr }
        }
        
        // 5. Проверка актуальности даты снимка:
        // Если снимок сохранен во вчерашний день, обнуляем суточные счетчики (шаги, калории, воду),
        // сохраняя персональные цели и профиль тренера
        if !Calendar.current.isDateInToday(bestSnapshot.lastUpdated) {
            bestSnapshot.stepsToday = 0
            bestSnapshot.activeCalories = 0.0
            bestSnapshot.exerciseMinutes = 0
            bestSnapshot.standHours = 0
            bestSnapshot.waterConsumed = 0.0
            bestSnapshot.caloriesConsumed = 0.0
            bestSnapshot.totalCaloriesBurned = 0.0
            bestSnapshot.energyBalance = 0.0
            bestSnapshot.hourlyStepCounts = [0, 0, 0, 0, 0, 0, 0]
            bestSnapshot.lastUpdated = Date()
        }
        
        return bestSnapshot
    }
}
