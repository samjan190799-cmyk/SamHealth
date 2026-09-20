import Foundation
import SwiftUI
import Combine

@MainActor
public final class HabitsManager: ObservableObject {
    public static let shared = HabitsManager()
    
    @Published public var habits: [HabitItem] = []
    @Published public var selectedCategory: HabitCategory? = nil
    @Published public var selectedTimeOfDayFilter: HabitTimeOfDay? = nil
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
    
    // Награда за стрик (модальное поздравление)
    @Published public var newlyEarnedReward: HabitRewardItem? = nil
    
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
        let migrationKey = "forma_habits_sanitized_clean_v1"
        let isSanitized = UserDefaults.standard.bool(forKey: migrationKey)
        
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([HabitItem].self, from: data),
           !saved.isEmpty {
            if !isSanitized {
                // Одноразовая очистка старых демо-дат (14 дней в прошлом) для существующих установок
                self.habits = saved.map { habit in
                    var h = habit
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    let todayKey = formatter.string(from: Date())
                    // Если были искусственные демо-даты, очищаем их
                    if h.completedDates.count >= 4 && (h.createdAt < Date().addingTimeInterval(-86400 * 3)) {
                        if h.completedDates.contains(todayKey) {
                            h.completedDates = [todayKey]
                        } else {
                            h.completedDates = []
                        }
                    }
                    if h.type == .quit, let start = h.quitStartDate, start < Date().addingTimeInterval(-86400 * 3) {
                        h.quitStartDate = Date()
                        h.createdAt = Date()
                    }
                    return h
                }
                UserDefaults.standard.set(true, forKey: migrationKey)
                saveHabits()
            } else {
                self.habits = saved
            }
        } else {
            self.habits = defaultInitialHabits()
            UserDefaults.standard.set(true, forKey: migrationKey)
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
        let today = Date()
        
        return [
            HabitItem(
                title: "Отказ от вредной привычки",
                subtitle: "Свобода от компульсий и стресса (настройте под себя)",
                type: .quit,
                category: .quitting,
                icon: "shield.fill",
                colorHex: "#EF4444",
                targetType: .manual,
                createdAt: today,
                quitStartDate: today,
                completedDates: [],
                relapseDates: [],
                urgeResistedCount: 0,
                xpReward: 35,
                timeOfDay: .anytime
            ),
            HabitItem(
                title: "Без добавленного сахара",
                subtitle: "Контроль энергии и баланс инсулина",
                type: .quit,
                category: .nutrition,
                icon: "cube.slash.fill",
                colorHex: "#F59E0B",
                targetType: .manual,
                createdAt: today,
                quitStartDate: today,
                completedDates: [],
                relapseDates: [],
                urgeResistedCount: 0,
                xpReward: 25,
                timeOfDay: .anytime
            ),
            HabitItem(
                title: "Пить 2.5 л воды",
                subtitle: "Оптимальная гидратация клеток",
                type: .build,
                category: .health,
                icon: "drop.fill",
                colorHex: "#00E5FF",
                targetType: .healthKitWater(targetMl: 2500),
                completedDates: [],
                xpReward: 20,
                timeOfDay: .anytime
            ),
            HabitItem(
                title: "10 000 шагов в день",
                subtitle: "Базовая кардио-активность",
                type: .build,
                category: .fitness,
                icon: "figure.walk",
                colorHex: "#10B981",
                targetType: .healthKitSteps(target: 10000),
                completedDates: [],
                xpReward: 30,
                timeOfDay: .afternoon
            ),
            HabitItem(
                title: "Витамины & Омега-3",
                subtitle: "Прием во время завтрака",
                type: .build,
                category: .health,
                icon: "pill.fill",
                colorHex: "#FBBF24",
                targetType: .manual,
                completedDates: [],
                reminderHour: 9,
                reminderMinute: 0,
                isReminderEnabled: true,
                xpReward: 15,
                timeOfDay: .morning
            ),
            HabitItem(
                title: "15 мин вечерней растяжки",
                subtitle: "Снятие мышечных зажимов перед сном",
                type: .build,
                category: .recovery,
                icon: "figure.yoga",
                colorHex: "#A855F7",
                targetType: .manual,
                completedDates: [],
                reminderHour: 21,
                reminderMinute: 30,
                isReminderEnabled: true,
                xpReward: 20,
                timeOfDay: .evening
            )
        ]
    }
    
    // MARK: - Zero-Click автосинхронизация с Apple HealthKit
    
    public func syncWithHealthKit(health: HealthKitManager, stepManager: BackgroundStepManager) {
        let today = Date()
        let todayKey = AppDateHelper.dayKey(for: today)
        var hasChanges = false
        
        let steps = max(health.stepsToday, stepManager.stepsToday)
        let waterMl = health.waterConsumedToday
        let todayWorkoutsCount = health.workoutHistory.filter { Calendar.current.isDateInToday($0.date) }.count
        let exerciseMinutes = health.appleExerciseTimeMinutes
        let sleepHours = health.todaySleepHours
        
        for i in 0..<habits.count {
            let habit = habits[i]
            guard habit.type == .build, habit.targetType.isHealthKitVerified else { continue }
            
            if habit.completedDates.contains(todayKey) {
                continue
            }
            
            var shouldAutoComplete = false
            
            switch habit.targetType {
            case .healthKitSteps(let target):
                if steps >= target && target > 0 {
                    shouldAutoComplete = true
                }
            case .healthKitWater(let targetMl):
                if waterMl >= targetMl && targetMl > 0 {
                    shouldAutoComplete = true
                }
            case .healthKitWorkouts(let targetCount):
                if (todayWorkoutsCount >= targetCount && targetCount > 0) || exerciseMinutes >= 30 {
                    shouldAutoComplete = true
                }
            case .healthKitSleep(let targetHours):
                if sleepHours >= targetHours && targetHours > 0 {
                    shouldAutoComplete = true
                }
            case .manual:
                break
            }
            
            if shouldAutoComplete {
                habits[i].completedDates.append(todayKey)
                GamificationManager.shared.addXP(habit.xpReward, reason: "⚡ Авто-зачет HealthKit: \(habit.title)")
                checkAndAwardHabitStreakRewards(for: habits[i])
                hasChanges = true
            }
        }
        
        if hasChanges {
            saveHabits()
            HapticManager.shared.notification(.success)
        }
    }
    
    // MARK: - Действия с привычками
    
    public func toggleHabitCompletion(id: UUID, date: Date = Date()) {
        guard let index = habits.firstIndex(where: { $0.id == id }) else { return }
        var habit = habits[index]
        
        let calendar = Calendar.current
        // Анти-чит: нельзя отмечать привычки будущей датой
        if calendar.startOfDay(for: date) > calendar.startOfDay(for: Date()) {
            HapticManager.shared.notification(.warning)
            return
        }
        
        let dateKey = AppDateHelper.dayKey(for: date)
        
        if habit.completedDates.contains(dateKey) {
            habit.completedDates.removeAll(where: { $0 == dateKey })
            HapticManager.shared.impact(.light)
        } else {
            habit.completedDates.append(dateKey)
            GamificationManager.shared.addXP(habit.xpReward, reason: "Привычка: \(habit.title)")
            HapticManager.shared.notification(.success)
            checkAndAwardHabitStreakRewards(for: habit)
        }
        
        habits[index] = habit
        saveHabits()
    }
    
    // Фиксация статуса за сегодня для привычки отказа (Сдержался / Срыв)
    public func markQuitHabitToday(id: UUID, isResisted: Bool) {
        guard let index = habits.firstIndex(where: { $0.id == id }) else { return }
        var habit = habits[index]
        
        let todayKey = AppDateHelper.todayKey
        
        if isResisted {
            if !habit.completedDates.contains(todayKey) {
                habit.completedDates.append(todayKey)
                habit.urgeResistedCount += 1
                GamificationManager.shared.addXP(habit.xpReward, reason: "Выдержка: \(habit.title)")
                HapticManager.shared.notification(.success)
                checkAndAwardHabitStreakRewards(for: habit)
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
            checkAndAwardHabitStreakRewards(for: habit)
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
        FormaNotificationManager.shared.scheduleHabitReminders(for: habit, coach: AICoachManager.shared.currentCoach)
        HapticManager.shared.notification(.success)
    }
    
    public func updateHabit(_ habit: HabitItem) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        habits[index] = habit
        saveHabits()
        FormaNotificationManager.shared.scheduleHabitReminders(for: habit, coach: AICoachManager.shared.currentCoach)
    }
    
    public func deleteHabit(id: UUID) {
        FormaNotificationManager.shared.removeHabitReminders(for: id)
        habits.removeAll(where: { $0.id == id })
        saveHabits()
        HapticManager.shared.impact(.medium)
    }
    
    // MARK: - Заморозка стрика (Streak Freeze)
    @discardableResult
    public func freezeHabit(id: UUID, date: Date = Date()) -> Bool {
        guard let index = habits.firstIndex(where: { $0.id == id }) else { return false }
        var habit = habits[index]
        
        let calendar = Calendar.current
        // Анти-чит: нельзя замораживать дни в будущем
        if calendar.startOfDay(for: date) > calendar.startOfDay(for: Date()) {
            HapticManager.shared.notification(.warning)
            return false
        }
        
        let dateKey = AppDateHelper.dayKey(for: date)
        
        // Если уже выполнен или уже заморожен
        if habit.completedDates.contains(dateKey) || habit.effectiveFrozenDates.contains(dateKey) {
            HapticManager.shared.notification(.warning)
            return false
        }
        
        // Проверяем наличие доступных щитов
        guard GamificationManager.shared.streakFreezesCount > 0 else {
            HapticManager.shared.notification(.error)
            return false
        }
        
        // Списываем щит
        guard GamificationManager.shared.useStreakFreeze() else {
            return false
        }
        
        var dates = habit.effectiveFrozenDates
        dates.append(dateKey)
        habit.frozenDates = dates
        
        habits[index] = habit
        saveHabits()
        HapticManager.shared.notification(.success)
        return true
    }
    
    @discardableResult
    public func unfreezeHabit(id: UUID, date: Date = Date()) -> Bool {
        guard let index = habits.firstIndex(where: { $0.id == id }) else { return false }
        var habit = habits[index]
        let dateKey = AppDateHelper.dayKey(for: date)
        
        guard habit.effectiveFrozenDates.contains(dateKey) else { return false }
        
        var dates = habit.effectiveFrozenDates
        dates.removeAll(where: { $0 == dateKey })
        habit.frozenDates = dates
        
        habits[index] = habit
        saveHabits()
        
        // Возвращаем щит на баланс
        GamificationManager.shared.awardFreeStreakFreeze(reason: "Отмена заморозки")
        HapticManager.shared.impact(.medium)
        return true
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
                checkAndAwardHabitStreakRewards(for: habits[i])
                changed = true
            }
        }
        
        if changed {
            saveHabits()
        }
    }
    
    // MARK: - Награды за стрики и дисциплину (Product-Led Growth с защитой от фрода)
    public func checkAndAwardHabitStreakRewards(for habit: HabitItem) {
        let streak = habit.currentStreakDays
        guard streak >= 3 else { return }
        
        // 1. АНТИ-ЧИТ: ПРОВЕРКА КВАЛИФИКАЦИИ ПРИВЫЧКИ
        // Ручные чекбоксы без объективной верификации дают только XP и бейджи геймификации.
        // Доступ к бесплатному PRO за стрики открывают ТОЛЬКО:
        // - Привычки с объективной валидацией Apple HealthKit (шаги, вода, тренировки, сон)
        // - Привычки отказа, если реальное время воздержания подтверждено календарным интервалом
        guard habit.isEligibleForStreakProReward else { return }
        
        // 2. АНТИ-ЧИТ: ПРОВЕРКА ВРЕМЕНИ СОЗДАНИЯ И ВОЗРАСТА ПРИВЫЧКИ
        let calendar = Calendar.current
        let daysSinceCreation = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: habit.createdAt),
            to: calendar.startOfDay(for: Date())
        ).day ?? 0
        
        // Для привычек отказа также верифицируем фактическое время с момента quitStartDate
        if habit.type == .quit, let quitStart = habit.quitStartDate {
            let daysClean = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: quitStart),
                to: calendar.startOfDay(for: Date())
            ).day ?? 0
            guard daysClean >= 3 else { return }
        }
        
        let milestones: [(days: Int, hours: Int, scans: Int, title: String)] = [
            (3, 24, 5, "24 часа FORMA PRO + 5 AI-сканирований"),
            (7, 48, 10, "48 часов FORMA PRO + 10 AI-сканирований"),
            (21, 168, 25, "7 дней FORMA PRO + 25 AI-сканирований")
        ]
        
        for m in milestones {
            // Защита: привычка должна физически существовать в приложении как минимум (m.days - 1) дней
            guard daysSinceCreation >= (m.days - 1) else { continue }
            
            // 3. АНТИ-ЧИТ: ЗАЩИТА ЧЕРЕЗ KEYCHAIN (ОДИН РАЗ НА УСТРОЙСТВО ЗА ВСЮ ИСТОРИЮ)
            if streak >= m.days && !SubscriptionManager.shared.isStreakMilestoneClaimed(days: m.days) {
                // Перманентно фиксируем получение вехи в защищенном хранилище Keychain
                SubscriptionManager.shared.markStreakMilestoneClaimed(days: m.days)
                
                SubscriptionManager.shared.grantTemporaryPro(hours: m.hours)
                SubscriptionManager.shared.grantBonusAIScans(count: m.scans)
                
                let reward = HabitRewardItem(
                    habitTitle: habit.title,
                    streakDays: m.days,
                    rewardTitle: m.title,
                    proHoursGranted: m.hours,
                    bonusScansGranted: m.scans,
                    descriptionText: "За дисциплину и честный стрик \(m.days) дн. в привычке «\(habit.title)» вам открыт премиум-доступ ко всем возможностям приложения!"
                )
                self.newlyEarnedReward = reward
                break
            }
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
    
    public var filteredBuildHabits: [HabitItem] {
        buildHabits.filter { habit in
            if let filter = selectedTimeOfDayFilter {
                return habit.effectiveTimeOfDay == filter
            }
            return true
        }
    }
    
    public func habitsCount(for timeOfDay: HabitTimeOfDay) -> Int {
        buildHabits.filter { $0.effectiveTimeOfDay == timeOfDay }.count
    }
    
    public var filteredHabits: [HabitItem] {
        if let cat = selectedCategory {
            return habits.filter { $0.category == cat }
        }
        return habits
    }
    
    // MARK: - Heatmap активности (30, 60, 90 дней)
    public func heatmapData(days: Int = 30) -> [HabitHeatmapDay] {
        let calendar = Calendar.current
        let today = Date()
        var result: [HabitHeatmapDay] = []
        
        let validDays = max(7, min(days, 180))
        
        for offset in (0..<validDays).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let dateKey = AppDateHelper.dayKey(for: date)
            
            // В европейском стандарте: 1 = Пн, ..., 7 = Вс
            // В calendar.component(.weekday): 1 = Вс, 2 = Пн ... 7 = Сб
            let appleWeekday = calendar.component(.weekday, from: date)
            let euroDayOfWeek = appleWeekday == 1 ? 7 : (appleWeekday - 1)
            
            let currentDayStart = calendar.startOfDay(for: date)
            
            // Привычки, созданные к этой дате или ранее
            let relevantHabits = habits.filter { habit in
                calendar.startOfDay(for: habit.createdAt) <= currentDayStart
            }
            
            let habitsToCheck = relevantHabits.isEmpty ? habits : relevantHabits
            let total = habitsToCheck.count
            
            var completedCount = 0
            var anyFrozen = false
            
            for h in habitsToCheck {
                let isFrozenThisDay = h.effectiveFrozenDates.contains(dateKey)
                if isFrozenThisDay {
                    anyFrozen = true
                }
                
                if h.type == .build {
                    if h.completedDates.contains(dateKey) || isFrozenThisDay {
                        completedCount += 1
                    }
                } else {
                    let start = calendar.startOfDay(for: h.quitStartDate ?? h.createdAt)
                    let isClean = currentDayStart >= start && !h.relapseDates.contains(where: { calendar.isDate($0, inSameDayAs: date) })
                    if isClean || isFrozenThisDay {
                        completedCount += 1
                    }
                }
            }
            
            let fraction = total > 0 ? min(1.0, Double(completedCount) / Double(total)) : 0.0
            
            let dayItem = HabitHeatmapDay(
                date: date,
                dateKey: dateKey,
                dayOfWeek: euroDayOfWeek,
                completedCount: completedCount,
                totalCount: total,
                isFrozen: anyFrozen,
                fraction: fraction
            )
            result.append(dayItem)
        }
        
        return result
    }
}
