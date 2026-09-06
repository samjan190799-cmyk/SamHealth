import SwiftUI

public enum HabitMainTab: String, CaseIterable, Identifiable {
    case build = "Полезные ⚡"
    case quit = "Вредные 🛡️"
    
    public var id: String { self.rawValue }
}

@MainActor
public struct HabitsView: View {
    @EnvironmentObject var health: HealthKitManager
    @EnvironmentObject var stepManager: BackgroundStepManager
    @ObservedObject var habitsManager = HabitsManager.shared
    @ObservedObject var gamification = GamificationManager.shared
    @ObservedObject var coachManager = AICoachManager.shared
    @ObservedObject var subscription = SubscriptionManager.shared
    
    @State private var selectedTab: HabitMainTab = .build
    @State private var showingCreateSheet = false
    @State private var showingPaywall = false
    @State private var defaultCreateType: HabitType = .build
    @State private var activeSOSHabit: HabitItem? = nil
    @State private var showingResetAlert = false
    @State private var habitToReset: HabitItem? = nil
    @State private var habitToDelete: HabitItem? = nil
    @State private var showingDeleteAlert = false
    
    @AppStorage("app_language") private var appLanguage = "ru"
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appLanguage == "hy" ? "hy_AM" : (appLanguage == "en" ? "en_US" : "ru_RU"))
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: Date()).capitalized
    }
    
    public var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 18) {
                    
                    // ШАПКА ЭКРАНА С КОЛЬЦОМ ПРОГРЕССА ДНЯ
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Привычки")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.textPrimary)
                            Text(formattedDate)
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                        }
                        
                        Spacer()
                        
                        // Кольцо "Идеальный день"
                        ZStack {
                            Circle()
                                .stroke(Color.primary.opacity(0.08), lineWidth: 5)
                                .frame(width: 58, height: 58)
                            
                            Circle()
                                .trim(from: 0, to: CGFloat(habitsManager.todayProgressFraction))
                                .stroke(
                                    LinearGradient(
                                        colors: [Color(red: 0/255, green: 229/255, blue: 255/255), Color(red: 50/255, green: 215/255, blue: 75/255)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                                )
                                .frame(width: 58, height: 58)
                                .rotationEffect(.degrees(-90))
                                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: habitsManager.todayProgressFraction)
                            
                            VStack(spacing: 0) {
                                Text("\(habitsManager.todayCompletedCount)/\(habitsManager.todayTotalCount)")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                                Text("готово")
                                    .font(.system(size: 8))
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    
                    // СЕГМЕНТИРОВАННЫЙ ПЕРЕКЛЮЧАТЕЛЬ НА 2 ВКЛАДКИ
                    HStack(spacing: 8) {
                        ForEach(HabitMainTab.allCases) { tab in
                            let isSelected = selectedTab == tab
                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    selectedTab = tab
                                }
                                HapticManager.shared.selection()
                            }) {
                                HStack(spacing: 6) {
                                    Text(tab.rawValue)
                                        .font(.system(size: 14, weight: isSelected ? .bold : .semibold))
                                    
                                    let count = tab == .build ? habitsManager.buildHabits.count : habitsManager.quitHabits.count
                                    Text("\(count)")
                                        .font(.system(size: 11, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(isSelected ? Color.white.opacity(0.25) : Color.primary.opacity(0.08))
                                        .clipShape(Capsule())
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundColor(isSelected ? .white : Theme.textPrimary)
                                .background(
                                    isSelected
                                        ? (tab == .build ? Color(red: 16/255, green: 185/255, blue: 129/255) : Color(red: 239/255, green: 68/255, blue: 68/255))
                                        : Theme.cardBackground
                                )
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(isSelected ? Color.clear : Color.primary.opacity(0.08), lineWidth: 1)
                                )
                                .shadow(color: isSelected ? (tab == .build ? Color.green : Color.red).opacity(0.25) : Color.clear, radius: 6, y: 2)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // ГЛАВНАЯ КНОПКА СОЗДАНИЯ ПРИВЫЧКИ (ПЕРЕНЕСЕНА НАВЕРХ В НАЧАЛО ВКЛАДКИ)
                    Button(action: {
                        if !subscription.canCreateHabit(currentHabitsCount: habitsManager.habits.count) {
                            showingPaywall = true
                            HapticManager.shared.notification(.warning)
                            return
                        }
                        defaultCreateType = selectedTab == .build ? .build : .quit
                        showingCreateSheet = true
                        HapticManager.shared.impact(.medium)
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text(selectedTab == .build ? "Создать полезную привычку" : "Создать отказ от привычки")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundColor(.white)
                        .background(
                            selectedTab == .build
                                ? LinearGradient(colors: [Color(red: 16/255, green: 185/255, blue: 129/255), Color(red: 5/255, green: 150/255, blue: 105/255)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [Color(red: 239/255, green: 68/255, blue: 68/255), Color(red: 185/255, green: 28/255, blue: 28/255)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .cornerRadius(16)
                        .shadow(color: (selectedTab == .build ? Color.green : Color.red).opacity(0.28), radius: 8, y: 3)
                    }
                    .buttonStyle(AppleDesignAwardsButtonStyle(scaleAmount: 0.96))
                    .padding(.horizontal)
                    
                    if !subscription.isPro {
                        Button(action: {
                            showingPaywall = true
                            HapticManager.shared.selection()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.yellow)
                                    .font(.system(size: 11))
                                Text("Лимит: \(habitsManager.habits.count)/\(subscription.maxFreeHabitsCount) привычек")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Theme.textPrimary)
                                Text("PRO 💎")
                                    .font(.system(size: 9, weight: .heavy))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.yellow.opacity(0.2))
                                    .foregroundColor(.yellow)
                                    .clipShape(Capsule())
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color.primary.opacity(0.04))
                            .cornerRadius(12)
                        }
                        .padding(.top, -6)
                    }
                    
                    // КОНТЕНТ ВКЛАДОК
                    if selectedTab == .build {
                        // ================= ВКЛАДКА 1: ПОЛЕЗНЫЕ ПРИВЫЧКИ =================
                        VStack(spacing: 18) {
                            
                            // Сводка по полезным привычкам
                            HStack(spacing: 12) {
                                let completed = habitsManager.buildHabits.filter { $0.isCompletedToday }.count
                                let total = habitsManager.buildHabits.count
                                let maxStreak = habitsManager.buildHabits.map { $0.buildStreakDays }.max() ?? 0
                                
                                HabitStatPill(title: "Выполнено", value: "\(completed)/\(total)", icon: "checkmark.circle.fill", color: Color(red: 16/255, green: 185/255, blue: 129/255))
                                HabitStatPill(title: "Рекорд стрика", value: "\(maxStreak) дн.", icon: "flame.fill", color: .orange)
                                HabitStatPill(title: "Синхронизация", value: "HealthKit", icon: "heart.fill", color: .pink)
                            }
                            .padding(.horizontal)
                            
                            if habitsManager.buildHabits.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 32))
                                        .foregroundColor(Theme.textSecondary.opacity(0.6))
                                    Text("Нет активных полезных привычек")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Theme.textPrimary)
                                    Text("Нажмите кнопку выше «Создать полезную привычку», чтобы настроить цели (шаги, вода, растяжка) с напоминаниями и календарем.")
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(20)
                                .premiumCard()
                                .padding(.horizontal)
                            } else {
                                // ПОЛНОРАЗМЕРНЫЕ HERO КАРТОЧКИ ПОЛЕЗНЫХ ПРИВЫЧЕК
                                ForEach(habitsManager.buildHabits) { habit in
                                    GoodHabitHeroCard(
                                        habit: habit,
                                        isCompletedToday: habit.isCompletedToday,
                                        onToggleCompletion: {
                                            habitsManager.toggleHabitCompletion(id: habit.id)
                                        },
                                        onFetchAdvice: {
                                            Task {
                                                await habitsManager.fetchAdviceForHabit(habit: habit, language: appLanguage)
                                            }
                                        },
                                        onDelete: {
                                            habitToDelete = habit
                                            showingDeleteAlert = true
                                        }
                                    )
                                    .padding(.horizontal)
                                }
                            }
                            
                            // Блок ИИ-Анализа полезных привычек
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 10) {
                                    AITrainerAvatarView(coachState: habitsManager.isAnalyzingWithAI ? .exercising : .idle, size: 36)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("ИИ-Коуч по привычкам")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(Theme.textPrimary)
                                        Text("Тренер \(coachManager.currentCoach.name)")
                                            .font(.system(size: 11))
                                            .foregroundColor(coachManager.currentCoach.accentColor)
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        Task {
                                            await habitsManager.runAIDisciplineAnalysis(health: health, stepManager: stepManager, language: appLanguage)
                                        }
                                    }) {
                                        HStack(spacing: 4) {
                                            if habitsManager.isAnalyzingWithAI {
                                                ProgressView()
                                                    .scaleEffect(0.7)
                                                    .tint(coachManager.currentCoach.accentColor)
                                            } else {
                                                Image(systemName: "sparkles")
                                            }
                                            Text(habitsManager.isAnalyzingWithAI ? "Анализ..." : "Оценить рутину")
                                        }
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(coachManager.currentCoach.accentColor)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(coachManager.currentCoach.accentColor.opacity(0.12))
                                        .cornerRadius(10)
                                    }
                                    .disabled(habitsManager.isAnalyzingWithAI)
                                }
                                
                                if let advice = habitsManager.aiDisciplineAdvice {
                                    Text(advice)
                                        .font(.system(size: 13))
                                        .foregroundColor(Theme.textPrimary)
                                        .lineSpacing(3)
                                        .padding(12)
                                        .background(Color.primary.opacity(0.04))
                                        .cornerRadius(14)
                                } else {
                                    Text("Персональный ИИ-коуч поможет выстроить идеальную цепочку привычек (Habit Stacking) для максимальной энергии и дисциплины.")
                                        .font(.system(size: 12))
                                        .foregroundColor(Theme.textSecondary)
                                        .lineSpacing(3)
                                }
                            }
                            .premiumCard()
                            .padding(.horizontal)
                        }
                    } else {
                        // ================= ВКЛАДКА 2: ВРЕДНЫЕ ПРИВЫЧКИ =================
                        VStack(spacing: 18) {
                            
                            // Сводка по чистым дням
                            HStack(spacing: 12) {
                                let totalCleanDays = habitsManager.quitHabits.reduce(0) { $0 + $1.cleanStreakDays }
                                let totalUrges = habitsManager.quitHabits.reduce(0) { $0 + $1.urgeResistedCount }
                                
                                HabitStatPill(title: "Чистых дней", value: "\(totalCleanDays)", icon: "flame.fill", color: .orange)
                                HabitStatPill(title: "Выдержек", value: "\(totalUrges)", icon: "shield.fill", color: Color(red: 239/255, green: 68/255, blue: 68/255))
                                HabitStatPill(title: "Привычек", value: "\(habitsManager.quitHabits.count)", icon: "nosign", color: .purple)
                            }
                            .padding(.horizontal)
                            
                            if habitsManager.quitHabits.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "shield.slash")
                                        .font(.system(size: 32))
                                        .foregroundColor(Theme.textSecondary.opacity(0.6))
                                    Text("Нет активных привычек отказа")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Theme.textPrimary)
                                    Text("Нажмите кнопку выше «Создать отказ от привычки», чтобы задать цель воздержания (например: 10 или 30 дней) и включить умные проверки выдержки.")
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(20)
                                .premiumCard()
                                .padding(.horizontal)
                            } else {
                                ForEach(habitsManager.quitHabits) { habit in
                                    QuitHabitHeroCard(
                                        habit: habit,
                                        isMarkedToday: habit.isCompletedToday,
                                        onMarkTodayResisted: {
                                            habitsManager.markQuitHabitToday(id: habit.id, isResisted: true)
                                        },
                                        onMarkTodayRelapse: {
                                            habitToReset = habit
                                            showingResetAlert = true
                                        },
                                        onSOS: {
                                            activeSOSHabit = habit
                                            HapticManager.shared.impact(.medium)
                                        },
                                        onFetchAdvice: {
                                            Task {
                                                await habitsManager.fetchAdviceForHabit(habit: habit, language: appLanguage)
                                            }
                                        },
                                        onDelete: {
                                            habitToDelete = habit
                                            showingDeleteAlert = true
                                        }
                                    )
                                    .padding(.horizontal)
                                }
                            }
                            
                            // Блок ИИ-Анализа выдержки
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 10) {
                                    AITrainerAvatarView(coachState: habitsManager.isAnalyzingWithAI ? .exercising : .idle, size: 36)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("ИИ-Наставник выдержки")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(Theme.textPrimary)
                                        Text("Тренер \(coachManager.currentCoach.name) • Online")
                                            .font(.system(size: 11))
                                            .foregroundColor(coachManager.currentCoach.accentColor)
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        Task {
                                            await habitsManager.runAIDisciplineAnalysis(health: health, stepManager: stepManager, language: appLanguage)
                                        }
                                    }) {
                                        HStack(spacing: 4) {
                                            if habitsManager.isAnalyzingWithAI {
                                                ProgressView()
                                                    .scaleEffect(0.7)
                                                    .tint(coachManager.currentCoach.accentColor)
                                            } else {
                                                Image(systemName: "sparkles")
                                            }
                                            Text(habitsManager.isAnalyzingWithAI ? "Анализ..." : "Оценить с ИИ")
                                        }
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(coachManager.currentCoach.accentColor)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(coachManager.currentCoach.accentColor.opacity(0.12))
                                        .cornerRadius(10)
                                    }
                                    .disabled(habitsManager.isAnalyzingWithAI)
                                }
                                
                                if let advice = habitsManager.aiDisciplineAdvice {
                                    Text(advice)
                                        .font(.system(size: 13))
                                        .foregroundColor(Theme.textPrimary)
                                        .lineSpacing(3)
                                        .padding(12)
                                        .background(Color.primary.opacity(0.04))
                                        .cornerRadius(14)
                                } else {
                                    Text("Нажмите «Оценить с ИИ», чтобы персональный тренер дал менторский разбор по триггерам, мотивации и удержанию чистых стриков.")
                                        .font(.system(size: 12))
                                        .foregroundColor(Theme.textSecondary)
                                        .lineSpacing(3)
                                }
                            }
                            .premiumCard()
                            .padding(.horizontal)
                        }
                    }
                    
                    Spacer()
                        .frame(height: 80)
                }
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateHabitSheet(initialType: defaultCreateType)
        }
        .sheet(isPresented: $showingPaywall) {
            FormaPaywallView()
        }
        .sheet(item: $activeSOSHabit) { habit in
            PanicSOSBreathingSheet(habit: habit)
        }
        .alert("Зафиксировать срыв?", isPresented: $showingResetAlert) {
            Button("Отмена", role: .cancel) { }
            Button("Сбросить стрик", role: .destructive) {
                if let h = habitToReset {
                    habitsManager.markQuitHabitToday(id: h.id, isResisted: false)
                }
            }
        } message: {
            Text("Срывы бывают у каждого — главное не опускать руки и начать новый чистый стрик прямо сейчас!")
        }
        .alert("Удалить привычку?", isPresented: $showingDeleteAlert) {
            Button("Отмена", role: .cancel) { }
            Button("Удалить", role: .destructive) {
                if let h = habitToDelete {
                    habitsManager.deleteHabit(id: h.id)
                }
            }
        } message: {
            Text("Вы уверены, что хотите удалить эту привычку? Вся история стриков будет удалена.")
        }
        .onAppear {
            habitsManager.evaluateAutoHabits(health: health, stepManager: stepManager)
        }
        .onChange(of: health.stepsToday) {
            habitsManager.evaluateAutoHabits(health: health, stepManager: stepManager)
        }
        .onChange(of: health.waterConsumed) {
            habitsManager.evaluateAutoHabits(health: health, stepManager: stepManager)
        }
    }
}

// MARK: - ПИЛЮЛЯ СТАТИСТИКИ
struct HabitStatPill: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
            }
            Text(value)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - HERO КАРТОЧКА ПОЛЕЗНОЙ ПРИВЫЧКИ (GoodHabitHeroCard)
struct GoodHabitHeroCard: View {
    let habit: HabitItem
    let isCompletedToday: Bool
    var onToggleCompletion: () -> Void
    var onFetchAdvice: () -> Void
    var onDelete: () -> Void
    
    @ObservedObject var habitsManager = HabitsManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Верхняя плашка
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(habit.color.opacity(0.18))
                        .frame(width: 40, height: 40)
                    Image(systemName: habit.icon)
                        .font(.headline.bold())
                        .foregroundColor(habit.color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    
                    HStack(spacing: 6) {
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("\(habit.buildStreakDays) дн. стрик")
                                .font(.caption.bold())
                                .foregroundColor(.orange)
                        }
                        
                        if !habit.subtitle.isEmpty {
                            Text("• \(habit.subtitle)")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
                
                Spacer()
                
                Menu {
                    Button(action: onFetchAdvice) {
                        Label("Совет ИИ по этой привычке", systemImage: "sparkles")
                    }
                    Divider()
                    Button(role: .destructive, action: onDelete) {
                        Label("Удалить привычку", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundColor(Theme.textSecondary)
                }
            }
            
            // ПРОГРЕСС ЦЕЛИ (ЕСЛИ ЗАДАН СРОК / КАЛЕНДАРЬ)
            if let totalGoal = habit.targetGoalTotalDays, let progress = habit.goalProgressFraction {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "target")
                                .foregroundColor(Theme.exerciseColor)
                                .font(.caption2.bold())
                            Text("Цель: \(habit.currentDaysTowardsGoal) из \(totalGoal) дн. (\(Int(progress * 100))%)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Theme.textPrimary)
                        }
                        Spacer()
                        if let remaining = habit.goalRemainingDays {
                            Text("Осталось: \(remaining) дн.")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.primary.opacity(0.08))
                                .frame(height: 6)
                            Capsule()
                                .fill(
                                    LinearGradient(colors: [habit.color, Color(red: 0/255, green: 229/255, blue: 255/255)], startPoint: .leading, endPoint: .trailing)
                                )
                                .frame(width: max(6, geo.size.width * CGFloat(progress)), height: 6)
                                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: progress)
                        }
                    }
                    .frame(height: 6)
                }
                .padding(10)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(12)
            }
            
            // 14-дневная матрица точек выполнения (Heat-dots)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    ForEach(0..<14, id: \.self) { dayOffset in
                        let isDone = dayOffset < min(14, habit.buildStreakDays)
                        Circle()
                            .fill(isDone ? habit.color : Color.primary.opacity(0.1))
                            .frame(width: 14, height: 14)
                    }
                }
                HStack {
                    Text("2 недели назад")
                        .font(.system(size: 9))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Text("Сегодня: \(isCompletedToday ? "Выполнено ✅" : "Отметьте ⏳")")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(isCompletedToday ? .green : Theme.textPrimary)
                }
            }
            
            // СИММЕТРИЧНЫЙ БЛОК КНОПОК ДЕЙСТВИЙ (Высота 46)
            HStack(spacing: 8) {
                // 1. Главная кнопка: Выполнено сегодня
                Button(action: onToggleCompletion) {
                    HStack(spacing: 6) {
                        Image(systemName: isCompletedToday ? "checkmark.seal.fill" : "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text(isCompletedToday ? "Выполнено сегодня ✅" : "Выполнить (+20 XP) ⚡")
                            .font(.system(size: 13, weight: .bold))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .foregroundColor(.white)
                    .background(
                        isCompletedToday
                            ? LinearGradient(colors: [Color(red: 16/255, green: 185/255, blue: 129/255), Color(red: 5/255, green: 150/255, blue: 105/255)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [habit.color, habit.color.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .cornerRadius(14)
                    .shadow(color: (isCompletedToday ? Color.green : habit.color).opacity(0.25), radius: 5, y: 2)
                }
                .buttonStyle(AppleDesignAwardsButtonStyle(scaleAmount: 0.96))
                
                // 2. Кнопка ИИ-Совет
                Button(action: onFetchAdvice) {
                    HStack(spacing: 4) {
                        if habitsManager.loadingAdviceHabitId == habit.id {
                            ProgressView()
                                .scaleEffect(0.65)
                                .tint(Theme.aiAccent)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Theme.aiAccent)
                        }
                    }
                    .frame(width: 46, height: 46)
                    .background(Theme.aiAccent.opacity(0.12))
                    .cornerRadius(14)
                }
                .buttonStyle(AppleDesignAwardsButtonStyle(scaleAmount: 0.96))
            }
            
            // Если для этой полезной привычки загружен совет ИИ
            if let customAdvice = habitsManager.habitSpecificAdvice[habit.id] {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption)
                            .foregroundColor(Theme.aiAccent)
                        Text("Персональная ИИ-стратегия")
                            .font(.caption.bold())
                            .foregroundColor(Theme.aiAccent)
                    }
                    Text(customAdvice)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textPrimary)
                        .lineSpacing(3)
                }
                .padding(12)
                .background(Theme.aiAccent.opacity(0.08))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Theme.aiAccent.opacity(0.2), lineWidth: 1)
                )
            }
        }
        .premiumCard()
    }
}

// MARK: - HERO КАРТОЧКА ОТКАЗА ОТ ВРЕДНОЙ ПРИВЫЧКИ (QuitHabitHeroCard)
struct QuitHabitHeroCard: View {
    let habit: HabitItem
    let isMarkedToday: Bool
    var onMarkTodayResisted: () -> Void
    var onMarkTodayRelapse: () -> Void
    var onSOS: () -> Void
    var onFetchAdvice: () -> Void
    var onDelete: () -> Void
    
    @ObservedObject var habitsManager = HabitsManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Верхняя плашка
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(habit.color.opacity(0.18))
                        .frame(width: 40, height: 40)
                    Image(systemName: habit.icon)
                        .font(.headline.bold())
                        .foregroundColor(habit.color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    
                    HStack(spacing: 6) {
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("\(habit.cleanStreakDays) дней чист")
                                .font(.caption.bold())
                                .foregroundColor(.orange)
                        }
                        
                        if habit.urgeResistedCount > 0 {
                            Text("• \(habit.urgeResistedCount) выдержек 🛡️")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                }
                
                Spacer()
                
                Menu {
                    Button(action: onFetchAdvice) {
                        Label("Совет ИИ по этой привычке", systemImage: "sparkles")
                    }
                    Button(action: onSOS) {
                        Label("SOS Дыхание (Фокус-режим)", systemImage: "shield.fill")
                    }
                    Button(role: .destructive, action: onMarkTodayRelapse) {
                        Label("Зафиксировать срыв", systemImage: "arrow.counterclockwise")
                    }
                    Divider()
                    Button(role: .destructive, action: onDelete) {
                        Label("Удалить привычку", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundColor(Theme.textSecondary)
                }
            }
            
            // ПРОГРЕСС ЦЕЛИ ВОЗДЕРЖАНИЯ (ЕСЛИ ЗАДАН СРОК / КАЛЕНДАРЬ)
            if let totalGoal = habit.targetGoalTotalDays, let progress = habit.goalProgressFraction {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "target")
                                .foregroundColor(Theme.moveColor)
                                .font(.caption2.bold())
                            Text("Цель воздержания: \(habit.cleanStreakDays) из \(totalGoal) дн. (\(Int(progress * 100))%)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Theme.textPrimary)
                        }
                        Spacer()
                        if let remaining = habit.goalRemainingDays {
                            Text("Осталось: \(remaining) дн.")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.primary.opacity(0.08))
                                .frame(height: 6)
                            Capsule()
                                .fill(
                                    LinearGradient(colors: [Color(red: 239/255, green: 68/255, blue: 68/255), Color.orange], startPoint: .leading, endPoint: .trailing)
                                )
                                .frame(width: max(6, geo.size.width * CGFloat(progress)), height: 6)
                                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: progress)
                        }
                    }
                    .frame(height: 6)
                }
                .padding(10)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(12)
            }
            
            // Майлстоун победы
            if let milestone = habit.currentActiveMilestone {
                HStack(spacing: 8) {
                    Image(systemName: milestone.badgeIcon)
                        .foregroundColor(.yellow)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Майлстоун: \(milestone.title)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.textPrimary)
                        if let next = habit.nextMilestone {
                            Text("Следующая цель: \(next.title) (\(max(0, next.days - habit.cleanStreakDays)) дн.)")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    Spacer()
                }
                .padding(10)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(12)
            }
            
            // Матрица точек выдержки (Heat-dots)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    ForEach(0..<14, id: \.self) { dayOffset in
                        let isClean = dayOffset < min(14, habit.cleanStreakDays)
                        Circle()
                            .fill(isClean ? habit.color : Color.primary.opacity(0.1))
                            .frame(width: 14, height: 14)
                    }
                }
                HStack {
                    Text("2 недели назад")
                        .font(.system(size: 9))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Text("Сегодня: \(isMarkedToday ? "Чисто ✅" : "Отметьте ⏳")")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(isMarkedToday ? .green : Theme.textPrimary)
                }
            }
            
            // ИДЕАЛЬНО СИММЕТРИЧНЫЙ БЛОК КНОПОК ДЕЙСТВИЙ (Высота 46)
            HStack(spacing: 8) {
                // 1. Главная кнопка: Сдержался сегодня
                Button(action: onMarkTodayResisted) {
                    HStack(spacing: 6) {
                        Image(systemName: isMarkedToday ? "checkmark.seal.fill" : "shield.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text(isMarkedToday ? "Сдержался ✅" : "Сдержался 🛡️")
                            .font(.system(size: 13, weight: .bold))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .foregroundColor(.white)
                    .background(
                        isMarkedToday
                            ? LinearGradient(colors: [Color(red: 16/255, green: 185/255, blue: 129/255), Color(red: 5/255, green: 150/255, blue: 105/255)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [habit.color, habit.color.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .cornerRadius(14)
                    .shadow(color: (isMarkedToday ? Color.green : habit.color).opacity(0.25), radius: 5, y: 2)
                }
                .buttonStyle(AppleDesignAwardsButtonStyle(scaleAmount: 0.96))
                
                // 2. Кнопка SOS Дыхание
                Button(action: onSOS) {
                    HStack(spacing: 4) {
                        Image(systemName: "lungs.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("SOS")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .frame(width: 72, height: 46)
                    .foregroundColor(Theme.textPrimary)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(14)
                }
                .buttonStyle(AppleDesignAwardsButtonStyle(scaleAmount: 0.96))
                
                // 3. Кнопка ИИ-Совет
                Button(action: onFetchAdvice) {
                    HStack(spacing: 4) {
                        if habitsManager.loadingAdviceHabitId == habit.id {
                            ProgressView()
                                .scaleEffect(0.65)
                                .tint(Theme.aiAccent)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Theme.aiAccent)
                        }
                    }
                    .frame(width: 46, height: 46)
                    .background(Theme.aiAccent.opacity(0.12))
                    .cornerRadius(14)
                }
                .buttonStyle(AppleDesignAwardsButtonStyle(scaleAmount: 0.96))
            }
            
            // Если для этой привычки загружен совет ИИ
            if let customAdvice = habitsManager.habitSpecificAdvice[habit.id] {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption)
                            .foregroundColor(Theme.aiAccent)
                        Text("Персональная ИИ-стратегия")
                            .font(.caption.bold())
                            .foregroundColor(Theme.aiAccent)
                    }
                    Text(customAdvice)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textPrimary)
                        .lineSpacing(3)
                }
                .padding(12)
                .background(Theme.aiAccent.opacity(0.08))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Theme.aiAccent.opacity(0.2), lineWidth: 1)
                )
            }
        }
        .premiumCard()
    }
}
