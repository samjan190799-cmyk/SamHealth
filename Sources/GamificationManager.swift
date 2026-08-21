import Foundation
import SwiftUI
import Combine

public struct FormaAchievement: Identifiable, Codable, Hashable {
    public var id: String
    public var title: String
    public var description: String
    public var icon: String
    public var category: AchievementCategory
    public var xpReward: Int
    public var targetValue: Double
    public var currentValue: Double
    public var isUnlocked: Bool
    public var unlockedDate: Date?
    
    public enum AchievementCategory: String, Codable, CaseIterable {
        case steps = "Шаги"
        case workouts = "Тренировки"
        case water = "Водный баланс"
        case streaks = "Стрики"
        case master = "Мастерство"
    }
}

public struct UserRank {
    public let level: Int
    public let title: String
    public let icon: String
    public let minXP: Int
    public let maxXP: Int
    public let color: Color
    
    public var progress: Double {
        guard maxXP > minXP else { return 1.0 }
        let currentXP = UserDefaults.standard.integer(forKey: "forma_user_xp")
        let capped = min(max(currentXP, minXP), maxXP)
        return Double(capped - minXP) / Double(maxXP - minXP)
    }
}

@MainActor
public class GamificationManager: ObservableObject {
    public static let shared = GamificationManager()
    
    @Published public var totalXP: Int = 0
    @Published public var currentStreak: Int = 0
    @Published public var bestStreak: Int = 0
    @Published public var achievements: [FormaAchievement] = []
    @Published public var newlyUnlockedAchievement: FormaAchievement? = nil
    @Published public var showCelebrationModal: Bool = false
    
    private let ranks: [UserRank] = [
        UserRank(level: 1, title: "Новичок Forma", icon: "figure.walk", minXP: 0, maxXP: 500, color: .gray),
        UserRank(level: 2, title: "Любитель фитнеса", icon: "figure.run", minXP: 500, maxXP: 1500, color: .blue),
        UserRank(level: 3, title: "Атлет Forma", icon: "dumbbell.fill", minXP: 1500, maxXP: 3500, color: .green),
        UserRank(level: 4, title: "Мастер выносливости", icon: "bolt.fill", minXP: 3500, maxXP: 7500, color: Color(red: 0/255, green: 229/255, blue: 255/255)),
        UserRank(level: 5, title: "Легенда Forma", icon: "crown.fill", minXP: 7500, maxXP: 15000, color: Color(red: 255/255, green: 45/255, blue: 85/255))
    ]
    
    public var currentRank: UserRank {
        for rank in ranks.reversed() {
            if totalXP >= rank.minXP {
                return rank
            }
        }
        return ranks[0]
    }
    
    public var nextRank: UserRank? {
        let currentLvl = currentRank.level
        return ranks.first(where: { $0.level == currentLvl + 1 })
    }
    
    public var xpForCurrentLevel: Int {
        return max(0, totalXP - currentRank.minXP)
    }
    
    public var xpNeededForNextLevel: Int {
        if let next = nextRank {
            return max(1, next.minXP - currentRank.minXP)
        }
        return 1
    }
    
    private init() {
        self.totalXP = UserDefaults.standard.integer(forKey: "forma_user_xp")
        self.currentStreak = UserDefaults.standard.integer(forKey: "forma_current_streak")
        self.bestStreak = UserDefaults.standard.integer(forKey: "forma_best_streak")
        loadAchievements()
    }
    
    // MARK: - Инициализация каталога достижений
    
    public func loadAchievements() {
        let defaultAchievements: [FormaAchievement] = [
            FormaAchievement(
                id: "first_5k",
                title: "Первые 5 000",
                description: "Пройти 5 000 шагов за один день",
                icon: "figure.walk",
                category: .steps,
                xpReward: 100,
                targetValue: 5000,
                currentValue: 0,
                isUnlocked: false
            ),
            FormaAchievement(
                id: "step_master_10k",
                title: "Золотая десятка",
                description: "Выполнить дневную норму 10 000 шагов",
                icon: "medal.fill",
                category: .steps,
                xpReward: 200,
                targetValue: 10000,
                currentValue: 0,
                isUnlocked: false
            ),
            FormaAchievement(
                id: "step_super_20k",
                title: "20K Ультра",
                description: "Пройти 20 000 шагов за одни сутки",
                icon: "bolt.fill",
                category: .steps,
                xpReward: 350,
                targetValue: 20000,
                currentValue: 0,
                isUnlocked: false
            ),
            FormaAchievement(
                id: "first_workout",
                title: "Первый рывок",
                description: "Завершить первую тренировку в Forma",
                icon: "figure.run",
                category: .workouts,
                xpReward: 150,
                targetValue: 1,
                currentValue: 0,
                isUnlocked: false
            ),
            FormaAchievement(
                id: "workout_veteran_10",
                title: "Ветеран спорта",
                description: "Провести 10 полноценных тренировок",
                icon: "flame.fill",
                category: .workouts,
                xpReward: 400,
                targetValue: 10,
                currentValue: 0,
                isUnlocked: false
            ),
            FormaAchievement(
                id: "marathon_42k",
                title: "Марафонец",
                description: "Преодолеть суммарно 42 км дистанции",
                icon: "figure.outdoor.cycle",
                category: .workouts,
                xpReward: 500,
                targetValue: 42.0,
                currentValue: 0,
                isUnlocked: false
            ),
            FormaAchievement(
                id: "iron_will_5",
                title: "Железная воля",
                description: "Завершить 5 силовых тренировок с гантелями",
                icon: "dumbbell.fill",
                category: .workouts,
                xpReward: 300,
                targetValue: 5,
                currentValue: 0,
                isUnlocked: false
            ),
            FormaAchievement(
                id: "hydration_norm",
                title: "Чистый баланс",
                description: "Выполнить дневную норму воды",
                icon: "drop.fill",
                category: .water,
                xpReward: 100,
                targetValue: 1.0,
                currentValue: 0,
                isUnlocked: false
            ),
            FormaAchievement(
                id: "streak_3_days",
                title: "Огонек (3 дня)",
                description: "Поддерживать активность 3 дня подряд",
                icon: "flame.circle.fill",
                category: .streaks,
                xpReward: 150,
                targetValue: 3,
                currentValue: 0,
                isUnlocked: false
            ),
            FormaAchievement(
                id: "streak_7_days",
                title: "Непобедимый (7 дней)",
                description: "7 дней непрерывного здорового стрика",
                icon: "sparkles",
                category: .streaks,
                xpReward: 350,
                targetValue: 7,
                currentValue: 0,
                isUnlocked: false
            ),
            FormaAchievement(
                id: "streak_30_days",
                title: "Легенда месяца (30 дней)",
                description: "30 дней ежедневной активности без пропусков",
                icon: "crown.fill",
                category: .streaks,
                xpReward: 1000,
                targetValue: 30,
                currentValue: 0,
                isUnlocked: false
            ),
            FormaAchievement(
                id: "all_rings_closed",
                title: "Идеальные кольца",
                description: "Закрыть все кольца активности Apple",
                icon: "circle.circle.fill",
                category: .master,
                xpReward: 250,
                targetValue: 1,
                currentValue: 0,
                isUnlocked: false
            )
        ]
        
        if let data = UserDefaults.standard.data(forKey: "forma_achievements_v1"),
           let saved = try? JSONDecoder().decode([FormaAchievement].self, from: data) {
            // Мерджим сохраненные с дефолтными
            var merged = defaultAchievements
            for (idx, def) in defaultAchievements.enumerated() {
                if let s = saved.first(where: { $0.id == def.id }) {
                    merged[idx] = s
                }
            }
            self.achievements = merged
        } else {
            self.achievements = defaultAchievements
            saveAchievements()
        }
    }
    
    private func saveAchievements() {
        if let encoded = try? JSONEncoder().encode(achievements) {
            UserDefaults.standard.set(encoded, forKey: "forma_achievements_v1")
        }
        UserDefaults.standard.set(totalXP, forKey: "forma_user_xp")
        UserDefaults.standard.set(currentStreak, forKey: "forma_current_streak")
        UserDefaults.standard.set(bestStreak, forKey: "forma_best_streak")
    }
    
    // MARK: - Начисление XP
    
    public func addXP(_ amount: Int, reason: String = "") {
        guard amount > 0 else { return }
        totalXP += amount
        saveAchievements()
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    // MARK: - Автоматический пересчет прогресса и стриков
    
    public func evaluateProgress(
        stepsToday: Int,
        distanceMetersToday: Double,
        workouts: [WorkoutRecord],
        waterConsumed: Double,
        waterNorm: Double,
        dailyHistory: [String: DailyActivitySummary]
    ) {
        // 1. Расчет стрика по истории дней
        calculateStreak(dailyHistory: dailyHistory, stepsToday: stepsToday)
        
        // 2. Проверка ачивок по шагам
        updateAchievement(id: "first_5k", value: Double(stepsToday))
        updateAchievement(id: "step_master_10k", value: Double(stepsToday))
        updateAchievement(id: "step_super_20k", value: Double(stepsToday))
        
        // 3. Проверка ачивок по тренировкам
        updateAchievement(id: "first_workout", value: Double(workouts.count))
        updateAchievement(id: "workout_veteran_10", value: Double(workouts.count))
        
        let totalKm = (distanceMetersToday + workouts.reduce(0.0) { $0 + ($1.durationMinutes > 0 ? Double($1.durationMinutes) * 150.0 : 0.0) }) / 1000.0
        updateAchievement(id: "marathon_42k", value: totalKm)
        
        let strengthCount = workouts.filter { $0.type.lowercased().contains("сил") || $0.type.lowercased().contains("гантел") || $0.type.lowercased().contains("отжим") || $0.type.lowercased().contains("присед") }.count
        updateAchievement(id: "iron_will_5", value: Double(strengthCount))
        
        // 4. Проверка воды
        if waterNorm > 0 && waterConsumed >= waterNorm {
            updateAchievement(id: "hydration_norm", value: 1.0)
        }
        
        // 5. Проверка стриков
        updateAchievement(id: "streak_3_days", value: Double(currentStreak))
        updateAchievement(id: "streak_7_days", value: Double(currentStreak))
        updateAchievement(id: "streak_30_days", value: Double(currentStreak))
        
        // 6. Базовый расчет накопленного XP из истории
        let baseXP = (workouts.count * 100) + (stepsToday / 100) + (currentStreak * 50) + achievements.filter { $0.isUnlocked }.reduce(0) { $0 + $1.xpReward }
        if baseXP > totalXP {
            totalXP = baseXP
            saveAchievements()
        }
    }
    
    private func updateAchievement(id: String, value: Double) {
        guard let index = achievements.firstIndex(where: { $0.id == id }) else { return }
        var item = achievements[index]
        item.currentValue = max(item.currentValue, value)
        
        if !item.isUnlocked && item.currentValue >= item.targetValue {
            item.isUnlocked = true
            item.unlockedDate = Date()
            achievements[index] = item
            
            // Начисляем XP и показываем праздничное модальное окно
            totalXP += item.xpReward
            saveAchievements()
            
            self.newlyUnlockedAchievement = item
            self.showCelebrationModal = true
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } else {
            achievements[index] = item
            saveAchievements()
        }
    }
    
    private func calculateStreak(dailyHistory: [String: DailyActivitySummary], stepsToday: Int) {
        let calendar = Calendar.current
        let today = Date()
        var streak = 0
        
        if stepsToday >= 3000 {
            streak += 1
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        for i in 1...365 {
            guard let pastDate = calendar.date(byAdding: .day, value: -i, to: today) else { break }
            let key = formatter.string(from: pastDate)
            if let dayData = dailyHistory[key], dayData.steps >= 3000 {
                streak += 1
            } else {
                break
            }
        }
        
        self.currentStreak = max(1, streak)
        if self.currentStreak > self.bestStreak {
            self.bestStreak = self.currentStreak
        }
        saveAchievements()
    }
}
