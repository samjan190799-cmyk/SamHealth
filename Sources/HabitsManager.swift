import Foundation
import SwiftUI
import Combine

@MainActor
public final class HabitsManager: ObservableObject {
    public static let shared = HabitsManager()
    
    @Published public var habits: [HabitItem] = []
    @Published public var selectedCategory: HabitCategory? = nil
    @Published public var showCreateSheet: Bool = false
    @Published public var showSOSSheet: Bool = false
    @Published public var activeSOSHabit: HabitItem? = nil
    @Published public var todayCompletedCount: Int = 0
    @Published public var todayTotalCount: Int = 0
    
    // Состояния для ИИ-анализа и советов
    @Published public var aiDisciplineAdvice: String? = nil
    @Published public var isAnalyzingWithAI: Bool = false
    @Published public var habitSpecificAdvice: [UUID: String] = [:]
    @Published public var loadingAdviceHabitId: UUID? = nil
    
    private let storageKey = "forma_habits_v1"
    private let aiAdviceStorageKey = "forma_habits_ai_advice_v1"
    
    private init() {
        loadHabits()
        if let savedAdvice = UserDefaults.standard.string(forKey: aiAdviceStorageKey), !savedAdvice.isEmpty {
            self.aiDisciplineAdvice = savedAdvice
        }
        updateTodayStats()
    }
    
    // MARK: - Загрузка и инициализация
    
    public func loadHabits() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([HabitItem].self, from: data),
           !saved.isEmpty {
            self.habits = saved
        } else {
            self.habits = defaultInitialHabits()
            saveHabits()
        }
        updateTodayStats()
    }
    
    public func saveHabits() {
        if let encoded = try? JSONEncoder().encode(habits) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
        updateTodayStats()
    }
    
    private func defaultInitialHabits() -> [HabitItem] {
        let calendar = Calendar.current
        let today = Date()
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: today) ?? today
        let fiveDaysAgo = calendar.date(byAdding: .day, value: -5, to: today) ?? today
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        // Создадим историю для демо-стриков (до вчерашнего дня, чтобы сегодня пользователь мог сам отметить)
        var pastDates: [String] = []
        for i in 1...14 {
            if let d = calendar.date(byAdding: .day, value: -i, to: today) {
                pastDates.append(formatter.string(from: d))
            }
        }
        
        return [
            HabitItem(
                title: "Отказ от вредной привычки",
                subtitle: "Свобода от компульсий и стресса (настройте под себя)",
                type: .quit,
                category: .quitting,
                icon: "shield.fill",
                colorHex: "#EF4444",
                targetType: .manual,
                createdAt: twoWeeksAgo,
                quitStartDate: twoWeeksAgo,
                completedDates: pastDates,
                relapseDates: [],
                urgeResistedCount: 12,
                xpReward: 35
            ),
            HabitItem(
                title: "Без добавленного сахара",
                subtitle: "Контроль энергии и баланс инсулина",
                type: .quit,
                category: .nutrition,
                icon: "cube.slash.fill",
                colorHex: "#F59E0B",
                targetType: .manual,
                createdAt: fiveDaysAgo,
                quitStartDate: fiveDaysAgo,
                completedDates: Array(pastDates.prefix(5)),
                relapseDates: [],
                urgeResistedCount: 4,
                xpReward: 25
            ),
            HabitItem(
                title: "Пить 2.5 л воды",
                subtitle: "Оптимальная гидратация клеток",
                type: .build,
                category: .health,
                icon: "drop.fill",
                colorHex: "#00E5FF",
                targetType: .healthKitWater(targetMl: 2500),
                completedDates: Array(pastDates.prefix(7)),
                xpReward: 20
            ),
            HabitItem(
                title: "10 000 шагов в день",
                subtitle: "Базовая кардио-активность",
                type: .build,
                category: .fitness,
                icon: "figure.walk",
                colorHex: "#10B981",
                targetType: .healthKitSteps(target: 10000),
                completedDates: Array(pastDates.prefix(10)),
                xpReward: 30
            ),
            HabitItem(
                title: "Витамины & Омега-3",
                subtitle: "Прием во время завтрака",
                type: .build,
                category: .health,
                icon: "pill.fill",
                colorHex: "#FBBF24",
                targetType: .manual,
                completedDates: Array(pastDates.prefix(6)),
                reminderHour: 9,
                reminderMinute: 0,
                isReminderEnabled: true,
                xpReward: 15
            ),
            HabitItem(
                title: "15 мин вечерней растяжки",
                subtitle: "Снятие мышечных зажимов перед сном",
                type: .build,
                category: .recovery,
                icon: "figure.yoga",
                colorHex: "#A855F7",
                targetType: .manual,
                completedDates: Array(pastDates.prefix(4)),
                reminderHour: 21,
                reminderMinute: 30,
                isReminderEnabled: true,
                xpReward: 20
            )
        ]
    }
    
    // MARK: - Действия с привычками
    
    public func toggleHabitCompletion(id: UUID, date: Date = Date()) {
        guard let index = habits.firstIndex(where: { $0.id == id }) else { return }
        var habit = habits[index]
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateKey = formatter.string(from: date)
        
        if habit.completedDates.contains(dateKey) {
            habit.completedDates.removeAll(where: { $0 == dateKey })
            HapticManager.shared.impact(.light)
        } else {
            habit.completedDates.append(dateKey)
            GamificationManager.shared.addXP(habit.xpReward, reason: "Привычка: \(habit.title)")
            HapticManager.shared.notification(.success)
        }
        
        habits[index] = habit
        saveHabits()
    }
    
    // Фиксация статуса за сегодня для привычки отказа (Сдержался / Срыв)
    public func markQuitHabitToday(id: UUID, isResisted: Bool) {
        guard let index = habits.firstIndex(where: { $0.id == id }) else { return }
        var habit = habits[index]
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayKey = formatter.string(from: Date())
        
        if isResisted {
            if !habit.completedDates.contains(todayKey) {
                habit.completedDates.append(todayKey)
                habit.urgeResistedCount += 1
                GamificationManager.shared.addXP(habit.xpReward, reason: "Выдержка: \(habit.title)")
                HapticManager.shared.notification(.success)
            } else {
                // Если повторный клик - переключаем
                habit.completedDates.removeAll(where: { $0 == todayKey })
                HapticManager.shared.impact(.light)
            }
        } else {
            // Фиксация срыва
            habit.relapseDates.append(Date())
            habit.quitStartDate = Date()
            habit.completedDates.removeAll(where: { $0 == todayKey })
            HapticManager.shared.notification(.warning)
        }
        
        habits[index] = habit
        saveHabits()
    }
    
    // Режим "Сдержался 🛡️" через SOS-шторку
    public func logUrgeResisted(id: UUID, triggerReason: String = "") {
        guard let index = habits.firstIndex(where: { $0.id == id }) else { return }
        var habit = habits[index]
        habit.urgeResistedCount += 1
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayKey = formatter.string(from: Date())
        if !habit.completedDates.contains(todayKey) {
            habit.completedDates.append(todayKey)
        }
        
        habits[index] = habit
        saveHabits()
        
        GamificationManager.shared.addXP(15, reason: "Выдержка: \(habit.title)")
        HapticManager.shared.notification(.success)
    }
    
    // Сброс стрика при срыве
    public func resetQuitStreak(id: UUID) {
        guard let index = habits.firstIndex(where: { $0.id == id }) else { return }
        var habit = habits[index]
        habit.relapseDates.append(Date())
        habit.quitStartDate = Date()
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayKey = formatter.string(from: Date())
        habit.completedDates.removeAll(where: { $0 == todayKey })
        
        habits[index] = habit
        saveHabits()
        HapticManager.shared.notification(.warning)
    }
    
    // Создание / Редактирование / Удаление
    public func addHabit(_ habit: HabitItem) {
        habits.insert(habit, at: 0)
        saveHabits()
        HapticManager.shared.notification(.success)
    }
    
    public func updateHabit(_ habit: HabitItem) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        habits[index] = habit
        saveHabits()
    }
    
    public func deleteHabit(id: UUID) {
        habits.removeAll(where: { $0.id == id })
        saveHabits()
        HapticManager.shared.impact(.medium)
    }
    
    // MARK: - ИИ-Анализ и Советы
    
    public func runAIDisciplineAnalysis(health: HealthKitManager, stepManager: BackgroundStepManager, language: String = "ru") async {
        guard !isAnalyzingWithAI else { return }
        isAnalyzingWithAI = true
        HapticManager.shared.impact(.medium)
        
        let effectiveSteps = health.stepsToday > 0 ? health.stepsToday : stepManager.stepsToday
        let currentWater = health.waterConsumed
        let sleepHours = health.todaySleepHours
        let coach = AICoachManager.shared.currentCoach
        let workoutSummary = health.workoutHistory.prefix(3).map { "\($0.type): \($0.durationMinutes) мин" }.joined(separator: ", ")
        
        do {
            let advice = try await GeminiScanService.shared.analyzeHabitsAndDiscipline(
                habits: habits,
                todaySteps: effectiveSteps,
                waterConsumed: currentWater,
                sleepHours: sleepHours,
                workoutHistorySummary: workoutSummary,
                coach: coach,
                language: language
            )
            self.aiDisciplineAdvice = advice
            UserDefaults.standard.set(advice, forKey: aiAdviceStorageKey)
            HapticManager.shared.notification(.success)
        } catch {
            self.aiDisciplineAdvice = "Не удалось связаться с ИИ. Проверьте API ключ в Настройках или подключение к интернету."
            HapticManager.shared.notification(.warning)
        }
        
        isAnalyzingWithAI = false
    }
    
    public func fetchAdviceForHabit(habit: HabitItem, language: String = "ru") async {
        guard loadingAdviceHabitId == nil else { return }
        loadingAdviceHabitId = habit.id
        HapticManager.shared.impact(.light)
        
        let coach = AICoachManager.shared.currentCoach
        
        do {
            let advice = try await GeminiScanService.shared.getHabitStrategyAdvice(
                habit: habit,
                coach: coach,
                language: language
            )
            self.habitSpecificAdvice[habit.id] = advice
            HapticManager.shared.notification(.success)
        } catch {
            self.habitSpecificAdvice[habit.id] = "Не удалось загрузить персональную стратегию. Проверьте настройки API ключей."
            HapticManager.shared.notification(.warning)
        }
        
        loadingAdviceHabitId = nil
    }
    
    // MARK: - Автоматическая проверка из HealthKit
    public func evaluateAutoHabits(health: HealthKitManager, stepManager: BackgroundStepManager) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayKey = formatter.string(from: Date())
        var changed = false
        
        let currentSteps = health.stepsToday > 0 ? health.stepsToday : stepManager.stepsToday
        let currentWater = health.waterConsumed
        let workoutCount = health.workoutHistory.filter { formatter.string(from: $0.date) == todayKey }.count
        let sleepHours = health.todaySleepHours
        
        for i in 0..<habits.count {
            let habit = habits[i]
            guard habit.type == .build else { continue }
            
            var shouldComplete = false
            switch habit.targetType {
            case .healthKitSteps(let target):
                if currentSteps >= target { shouldComplete = true }
            case .healthKitWater(let target):
                if currentWater >= target { shouldComplete = true }
            case .healthKitWorkouts(let target):
                if workoutCount >= target { shouldComplete = true }
            case .healthKitSleep(let target):
                if sleepHours >= target { shouldComplete = true }
            case .manual:
                break
            }
            
            if shouldComplete && !habit.completedDates.contains(todayKey) {
                habits[i].completedDates.append(todayKey)
                GamificationManager.shared.addXP(habit.xpReward, reason: "Авто-привычка: \(habit.title)")
                changed = true
            }
        }
        
        if changed {
            saveHabits()
        }
    }
    
    // MARK: - Статистика
    private func updateTodayStats() {
        let todayHabits = habits
        self.todayTotalCount = todayHabits.count
        self.todayCompletedCount = todayHabits.filter { $0.isCompletedToday }.count
    }
    
    public var todayProgressFraction: Double {
        guard todayTotalCount > 0 else { return 0.0 }
        return Double(todayCompletedCount) / Double(todayTotalCount)
    }
    
    public var quitHabits: [HabitItem] {
        habits.filter { $0.type == .quit }
    }
    
    public var buildHabits: [HabitItem] {
        habits.filter { $0.type == .build }
    }
    
    public var filteredHabits: [HabitItem] {
        if let cat = selectedCategory {
            return habits.filter { $0.category == cat }
        }
        return habits
    }
}
