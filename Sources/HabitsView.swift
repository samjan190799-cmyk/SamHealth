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
        AppDateHelper.habitHeaderDate(lang: appLanguage)
    }
    
    public var body: some View {
        ZStack {
            FormaBackdrop(.habits)
            
            ScrollView {
                FormaFeed(spacing: FormaLayout.sectionSpacing) {

                    // ШАПКА ЭКРАНА: логотип и заголовок как в остальных вкладках, справа «+» и кольцо дня
                    FormaScreenHeader(title: "Привычки", subtitle: formattedDate) {
                        // КНОПКА ДОБАВЛЕНИЯ ПРИВЫЧКИ
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
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(selectedTab == .build ? Color(red: 16/255, green: 185/255, blue: 129/255) : Color(red: 239/255, green: 68/255, blue: 68/255))
                                .background(Circle().fill(Color.white).shadow(color: Color.black.opacity(0.1), radius: 3, y: 1))
                        }
                        .padding(.trailing, 8)
                        
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
                    
                    // ПЕРЕКЛЮЧАТЕЛЬ ВКЛАДОК — системный сегментированный, как «Готовые/Личные» и «Еда/Вода/Вес»
                    Picker("", selection: $selectedTab.animation(.spring(response: 0.35, dampingFraction: 0.75))) {
                        ForEach(HabitMainTab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    .onChange(of: selectedTab) { _, _ in
                        HapticManager.shared.selection()
                    }
                    
                    // КОНТЕНТ ВКЛАДОК
                    if selectedTab == .build {
                        // ================= ВКЛАДКА 1: ПОЛЕЗНЫЕ ПРИВЫЧКИ =================
                        // Group, а не VStack: карточки вкладки становятся частью общей ленты и получают её эффект
                        Group {
                            
                            // Герой вкладки: кольцо выполнения дня и серии — тот же язык, что кольца на Главной
                            HabitsDayHeroCard(
                                completed: habitsManager.buildHabits.filter { $0.isCompletedToday }.count,
                                total: habitsManager.buildHabits.count,
                                bestStreak: habitsManager.buildHabits.map { $0.buildStreakDays }.max() ?? 0,
                                shields: GamificationManager.shared.streakFreezesCount
                            )
                            .padding(.horizontal)
                            
                            // ФИЛЬТРЫ ТАЙМЛАЙНА ДНЯ (Habit Stacking & Time of Day) — чипы как категории в Тренировках
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    FormaFilterChip(
                                        title: "Все",
                                        count: habitsManager.buildHabits.count,
                                        isSelected: habitsManager.selectedTimeOfDayFilter == nil,
                                        tint: Color(red: 16/255, green: 185/255, blue: 129/255)
                                    ) {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                            habitsManager.selectedTimeOfDayFilter = nil
                                        }
                                    }
                            
                                    ForEach(HabitTimeOfDay.allCases) { tod in
                                        let isSelected = habitsManager.selectedTimeOfDayFilter == tod
                                        FormaFilterChip(
                                            title: tod.title,
                                            emoji: tod.emoji,
                                            count: habitsManager.habitsCount(for: tod),
                                            isSelected: isSelected,
                                            tint: Color(red: 16/255, green: 185/255, blue: 129/255),
                                            showsIndicator: HabitTimeOfDay.current == tod
                                        ) {
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                                habitsManager.selectedTimeOfDayFilter = isSelected ? nil : tod
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            if habitsManager.filteredBuildHabits.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 32))
                                        .foregroundColor(Theme.textSecondary.opacity(0.6))
                                    Text(habitsManager.selectedTimeOfDayFilter != nil ? "Нет привычек на этот период" : "Нет активных полезных привычек")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Theme.textPrimary)
                                    Text(habitsManager.selectedTimeOfDayFilter != nil ? "Выберите фильтр «Все» или создайте новую привычку для этого времени суток." : "Нажмите кнопку выше «Создать полезную привычку», чтобы настроить цели (шаги, вода, растяжка) с напоминаниями и календарем.")
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
                                ForEach(habitsManager.filteredBuildHabits) { habit in
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
                                HStack(spacing: 12) {
                                    AITrainerAvatarView(coachState: habitsManager.isAnalyzingWithAI ? .exercising : .idle, size: 36)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("ИИ-Коуч по привычкам")
                                            .font(.system(size: 15, weight: .bold))
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
                                        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.chip, style: .continuous))
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
                                        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
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
                        Group {
                            
                            // Сводка по чистым дням — карточка как на Главной
                            VStack(alignment: .leading, spacing: 12) {
                                let totalCleanDays = habitsManager.quitHabits.reduce(0) { $0 + $1.cleanStreakDays }
                                let totalUrges = habitsManager.quitHabits.reduce(0) { $0 + $1.urgeResistedCount }

                                FormaCardHeader(
                                    icon: "shield.lefthalf.filled",
                                    tint: Color(red: 239/255, green: 68/255, blue: 68/255),
                                    title: "Отказ от привычек",
                                    subtitle: habitsManager.quitHabits.isEmpty ? "Добавьте привычку, от которой хотите отказаться" : "Чистые дни и выдержанные соблазны"
                                )

                                HStack(spacing: 8) {
                                    HabitStatPill(title: "Чистых дней", value: "\(totalCleanDays)", icon: "flame.fill", color: .orange)
                                    HabitStatPill(title: "Выдержек", value: "\(totalUrges)", icon: "shield.fill", color: Color(red: 239/255, green: 68/255, blue: 68/255))
                                    HabitStatPill(title: "Привычек", value: "\(habitsManager.quitHabits.count)", icon: "nosign", color: .purple)
                                }
                            }
                            .premiumCard()
                            .padding(.horizontal)
                            
                            let totalSavings = habitsManager.quitHabits.reduce(0.0) { $0 + $1.totalMoneySaved }
                            if totalSavings > 0 {
                                HStack(spacing: 8) {
                                    Image(systemName: "banknote.fill")
                                        .foregroundColor(.green)
                                        .font(.subheadline)
                                    Text("Сберегли за всё время:")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(Theme.textSecondary)
                                    Spacer()
                                    Text("\(Int(totalSavings)) ₽")
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundColor(.green)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color.green.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                                        .stroke(Color.green.opacity(0.25), lineWidth: 1)
                                )
                                .padding(.horizontal)
                            }
                            
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
                                HStack(spacing: 12) {
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
                                        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.chip, style: .continuous))
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
                                        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
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
                    
                    // СТАТИСТИКА И БАННЕРЫ (перенесены вниз)
                    Group {
                        // ПАНЕЛЬ ЗАЩИТЫ СТРИКА (Streak Freeze Shields)
                        StreakFreezeShieldBarView()
                            .padding(.horizontal)
                        
                        // МАТРИЦА АКТИВНОСТИ (Heatmap 30-90 дней)
                        HabitHeatmapView()
                            .padding(.horizontal)
                            
                        // ПРОМО-БАННЕР И СТАТУС НАГРАД FORMA PRO ЗА ДИСЦИПЛИНУ
                        FormaPromotionalBannerView(placement: .habits)
                            .padding(.horizontal)
                    }
                    .padding(.top, 10)
                    
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
        .sheet(item: $habitsManager.newlyEarnedReward) { reward in
            HabitRewardCelebrationSheet(reward: reward)
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
            habitsManager.syncWithHealthKit(health: health, stepManager: stepManager)
        }
        .onChange(of: health.stepsToday) {
            habitsManager.syncWithHealthKit(health: health, stepManager: stepManager)
        }
        .onChange(of: health.waterConsumedToday) {
            habitsManager.syncWithHealthKit(health: health, stepManager: stepManager)
        }
        .onChange(of: stepManager.stepsToday) {
            habitsManager.syncWithHealthKit(health: health, stepManager: stepManager)
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
        .background(Color.primary.opacity(0.04))
        .cornerRadius(FormaLayout.chipRadius)
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
        VStack(alignment: .leading, spacing: 16) {
            // Верхняя плашка
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(habit.color.opacity(0.18))
                        .frame(width: 40, height: 40)
                    Image(systemName: habit.icon)
                        .font(.headline.bold())
                        .foregroundColor(habit.color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("\(habit.buildStreakDays) дн. стрик")
                                .font(.caption.bold())
                                .foregroundColor(.orange)
                        }
                        
                        // Бейдж времени суток (Habit Stacking)
                        HStack(spacing: 4) {
                            Image(systemName: habit.effectiveTimeOfDay.icon)
                                .font(.system(size: 8, weight: .bold))
                            Text(habit.effectiveTimeOfDay.badgeTitle)
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(Theme.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    
                    // Ледяной бейдж заморозки стрика (Streak Freeze)
                    if habit.isFrozenToday {
                        HStack(spacing: 4) {
                            Image(systemName: "snowflake")
                                .font(.system(size: 10, weight: .bold))
                            Text("🧊 Стрик защищен щитом")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(Color(red: 56/255, green: 189/255, blue: 248/255))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(red: 56/255, green: 189/255, blue: 248/255).opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color(red: 56/255, green: 189/255, blue: 248/255).opacity(0.35), lineWidth: 1)
                        )
                    } else if habit.isHealthKitAutoCompletedToday {
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.badge.checkmark.fill")
                                .font(.system(size: 10, weight: .bold))
                            Text("⚡ HealthKit Авто-зачет")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.3), lineWidth: 1)
                        )
                    } else if !habit.subtitle.isEmpty {
                        Text(habit.subtitle)
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textSecondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Menu {
                    Button(action: onFetchAdvice) {
                        Label("Совет ИИ по этой привычке", systemImage: "sparkles")
                    }
                    if habit.isFrozenToday {
                        Button {
                            habitsManager.unfreezeHabit(id: habit.id)
                        } label: {
                            Label("Снять защиту (вернуть щит)", systemImage: "flame")
                        }
                    } else if !isCompletedToday {
                        Button {
                            habitsManager.freezeHabit(id: habit.id)
                        } label: {
                            Label("Защитить стрик щитом 🧊", systemImage: "snowflake")
                        }
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
                VStack(alignment: .leading, spacing: 8) {
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
                .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
            }
            
            // 14-дневная матрица точек выполнения (Heat-dots)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(0..<14, id: \.self) { dayOffset in
                        let targetDate = Calendar.current.date(byAdding: .day, value: -(13 - dayOffset), to: Date()) ?? Date()
                        let dateKey = AppDateHelper.dayKey(for: targetDate)
                        let isDone = habit.completedDates.contains(dateKey)
                        let isFrozen = habit.effectiveFrozenDates.contains(dateKey)
                        
                        ZStack {
                            Circle()
                                .fill(
                                    isFrozen
                                        ? Color(red: 56/255, green: 189/255, blue: 248/255)
                                        : (isDone ? habit.color : Color.primary.opacity(0.1))
                                )
                                .frame(width: 14, height: 14)
                            
                            if isFrozen {
                                Image(systemName: "snowflake")
                                    .font(.system(size: 6, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
                HStack {
                    Text("2 недели назад")
                        .font(.system(size: 9))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    if habit.isFrozenToday {
                        Text("Сегодня: Защищен 🧊")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color(red: 56/255, green: 189/255, blue: 248/255))
                    } else {
                        Text("Сегодня: \(isCompletedToday ? "Выполнено ✅" : "Отметьте ⏳")")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(isCompletedToday ? .green : Theme.textPrimary)
                    }
                }
            }
            
            // СИММЕТРИЧНЫЙ БЛОК КНОПОК ДЕЙСТВИЙ (Высота 46)
            HStack(spacing: 8) {
                // 1. Главная кнопка
                if habit.isFrozenToday {
                    Button(action: {
                        habitsManager.unfreezeHabit(id: habit.id)
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "snowflake")
                                .font(.system(size: 14, weight: .bold))
                            Text("Стрик защищен 🧊 (Снять)")
                                .font(.system(size: 13, weight: .bold))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .foregroundColor(.white)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 56/255, green: 189/255, blue: 248/255), Color(red: 2/255, green: 132/255, blue: 199/255)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
                        .shadow(color: Color(red: 56/255, green: 189/255, blue: 248/255).opacity(0.3), radius: 5, y: 2)
                    }
                    .buttonStyle(AppleDesignAwardsButtonStyle(scaleAmount: 0.96))
                } else {
                    Button(action: onToggleCompletion) {
                        HStack(spacing: 8) {
                            if habit.isHealthKitAutoCompletedToday {
                                Image(systemName: "bolt.badge.checkmark.fill")
                                    .font(.system(size: 14, weight: .bold))
                                Text("Зачтено HealthKit ⚡")
                                    .font(.system(size: 13, weight: .bold))
                                    .lineLimit(1)
                            } else {
                                Image(systemName: isCompletedToday ? "checkmark.seal.fill" : "checkmark.circle.fill")
                                    .font(.system(size: 14, weight: .bold))
                                Text(isCompletedToday ? "Выполнено сегодня ✅" : "Выполнить (+20 XP) ⚡")
                                    .font(.system(size: 13, weight: .bold))
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .foregroundColor(.white)
                        .background(
                            isCompletedToday
                                ? LinearGradient(colors: [Color(red: 16/255, green: 185/255, blue: 129/255), Color(red: 5/255, green: 150/255, blue: 105/255)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [habit.color, habit.color.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
                        .shadow(color: (isCompletedToday ? Color.green : habit.color).opacity(0.25), radius: 5, y: 2)
                    }
                    .buttonStyle(AppleDesignAwardsButtonStyle(scaleAmount: 0.96))
                }
                
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
                    .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
                }
                .buttonStyle(AppleDesignAwardsButtonStyle(scaleAmount: 0.96))
            }
            
            // Если для этой полезной привычки загружен совет ИИ
            if let customAdvice = habitsManager.habitSpecificAdvice[habit.id] {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
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
                .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
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
        VStack(alignment: .leading, spacing: 16) {
            // Верхняя плашка
            HStack(spacing: 12) {
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
                    
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
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
                    
                    if habit.totalMoneySaved > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "banknote.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 10))
                            Text("\(Int(habit.totalMoneySaved)) ₽ сэкономлено")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    
                    // Ледяной бейдж заморозки стрика
                    if habit.isFrozenToday {
                        HStack(spacing: 4) {
                            Image(systemName: "snowflake")
                                .font(.system(size: 10, weight: .bold))
                            Text("🧊 Стрик защищен щитом")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(Color(red: 56/255, green: 189/255, blue: 248/255))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(red: 56/255, green: 189/255, blue: 248/255).opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color(red: 56/255, green: 189/255, blue: 248/255).opacity(0.35), lineWidth: 1)
                        )
                    }
                }
                
                Spacer()
                
                Menu {
                    Button(action: onFetchAdvice) {
                        Label("Совет ИИ по этой привычке", systemImage: "sparkles")
                    }
                    if habit.isFrozenToday {
                        Button {
                            habitsManager.unfreezeHabit(id: habit.id)
                        } label: {
                            Label("Снять защиту (вернуть щит)", systemImage: "flame")
                        }
                    } else {
                        Button {
                            habitsManager.freezeHabit(id: habit.id)
                        } label: {
                            Label("Защитить стрик щитом 🧊", systemImage: "snowflake")
                        }
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
                VStack(alignment: .leading, spacing: 8) {
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
                .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
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
                .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
            }
            
            // Матрица точек выдержки (Heat-dots)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
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
                    HStack(spacing: 8) {
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
                    .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
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
                    .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
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
                    .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
                }
                .buttonStyle(AppleDesignAwardsButtonStyle(scaleAmount: 0.96))
            }
            
            // Если для этой привычки загружен совет ИИ
            if let customAdvice = habitsManager.habitSpecificAdvice[habit.id] {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
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
                .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                        .stroke(Theme.aiAccent.opacity(0.2), lineWidth: 1)
                )
            }
        }
        .premiumCard()
    }
}

// MARK: - ПАНЕЛЬ ЩИТОВ ЗАМОРОЗКИ СТРИКА (Streak Freeze Bar)
struct StreakFreezeShieldBarView: View {
    @ObservedObject var gamification = GamificationManager.shared
    @State private var showingPurchaseAlert = false
    @State private var showingInsufficientXPAlert = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Иконка щита со льдом
            FormaCardIcon(systemName: "snowflake", tint: Color(red: 56/255, green: 189/255, blue: 248/255))
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("Щиты стрика:")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    
                    Text("\(gamification.streakFreezesCount)")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(red: 56/255, green: 189/255, blue: 248/255))
                    
                    Text("🧊")
                        .font(.system(size: 12))
                }
                
                Text(gamification.streakFreezesCount > 0 ? "Стрик не сгорит при пропуске дня" : "Пополните запас щитов за XP")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Кнопка покупки щита за 200 XP
            Button(action: {
                if gamification.totalXP >= 200 {
                    showingPurchaseAlert = true
                } else {
                    showingInsufficientXPAlert = true
                }
                HapticManager.shared.impact(.medium)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("200 XP")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    LinearGradient(
                        colors: [Color(red: 56/255, green: 189/255, blue: 248/255), Color(red: 2/255, green: 132/255, blue: 199/255)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: FormaRadius.chip, style: .continuous))
                .shadow(color: Color(red: 56/255, green: 189/255, blue: 248/255).opacity(0.3), radius: 4, y: 2)
            }
            .buttonStyle(AppleDesignAwardsButtonStyle(scaleAmount: 0.94))
        }
        .padding(12)
        .formaSurface(FormaRadius.control)
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                .stroke(Color(red: 56/255, green: 189/255, blue: 248/255).opacity(0.2), lineWidth: 1)
        )
        .alert("Купить щит заморозки?", isPresented: $showingPurchaseAlert) {
            Button("Отмена", role: .cancel) { }
            Button("Купить за 200 XP") {
                gamification.buyStreakFreezeWithXP(cost: 200)
            }
        } message: {
            Text("Один щит сохранит ваш стрик активным при непредвиденном пропуске дня или форс-мажоре. С баланса спишется 200 XP (текущий баланс: \(gamification.totalXP) XP).")
        }
        .alert("Недостаточно XP", isPresented: $showingInsufficientXPAlert) {
            Button("Понятно", role: .cancel) { }
        } message: {
            Text("Для покупки щита стрика требуется 200 XP. Ваш текущий баланс: \(gamification.totalXP) XP. Выполняйте привычки, тренируйтесь и проходите шаги для накопления опыта!")
        }
    }
}

// MARK: - Герой вкладки «Привычки»

struct HabitsDayHeroCard: View {
    let completed: Int
    let total: Int
    let bestStreak: Int
    let shields: Int

    @State private var isRevealed = false

    private static let green = Color(red: 16 / 255, green: 185 / 255, blue: 129 / 255)

    private var progress: Double {
        total > 0 ? Double(completed) / Double(total) : 0
    }

    private var headline: String {
        if total == 0 { return "Начните первую привычку" }
        if completed >= total { return "Все привычки выполнены" }
        return "\(completed) из \(total) сегодня"
    }

    private var caption: String {
        if total == 0 { return "Маленькие ежедневные шаги складываются в форму" }
        if completed >= total { return "Отличный день — серия продолжается" }
        let left = total - completed
        return left == 1 ? "Осталась одна привычка" : "Осталось \(left) — серия не прервётся"
    }

    var body: some View {
        HStack(spacing: FormaSpacing.xl) {
            ZStack {
                FormaRingStack(
                    rings: [FormaRingSpec(id: "habits", progress: progress, color: Self.green, symbol: "checkmark")],
                    isRevealed: isRevealed,
                    lineWidth: 16
                )
                Text("\(Int((isRevealed ? progress : 0) * 100))%")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: isRevealed ? progress : 0))
                    .formaAnimation(FormaMotion.fill, value: isRevealed)
            }
            .frame(width: 128, height: 128)

            VStack(alignment: .leading, spacing: FormaSpacing.m) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Сегодня")
                        .formaEyebrow()
                    Text(headline)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Text(caption)
                        .font(FormaFont.caption)
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(2)
                }

                HStack(spacing: FormaSpacing.l) {
                    stat(icon: "flame.fill", color: Theme.flameOrange, value: "\(bestStreak)", unit: "дн. рекорд")
                    stat(icon: "snowflake", color: Theme.standColor, value: "\(shields)", unit: "щитов")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .formaHeroCard(tint: Self.green, padding: FormaSpacing.xl - 4)
        .task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            isRevealed = true
        }
        .accessibilityElement(children: .combine)
    }

    private func stat(icon: String, color: Color, value: String, unit: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textPrimary)
                .monospacedDigit()
            Text(unit)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
        }
    }
}
