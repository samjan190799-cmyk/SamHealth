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

                    // ШАПКА ЭКРАНА: заголовок как в остальных вкладках, справа кнопка «+».
                    // Под ней рекламный баннер: они в одной связке без промежутка, чтобы пустой баннер не давал зазора.
                    VStack(spacing: 0) {
                        FormaScreenHeader(title: "Привычки", subtitle: formattedDate) {
                            // Кнопка добавления привычки. Кольца дня в шапке больше нет: то же самое показывает герой ниже
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
                                Image(systemName: "plus")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(selectedTab == .build ? Color(red: 16/255, green: 185/255, blue: 129/255) : Color(red: 239/255, green: 68/255, blue: 68/255)))
                                    .frame(width: FormaTouch.minTarget, height: FormaTouch.minTarget)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityLabel("Добавить привычку")
                        }

                        // ПРОМО-БАННЕР И СТАТУС НАГРАД FORMA PRO ЗА ДИСЦИПЛИНУ
                        FormaPromotionalBannerView(placement: .habits, spacing: 12)
                            .padding(.horizontal)
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
                                // Привычка — компактная строка: нажатие на кольцо отмечает день, нажатие на строку
                                // раскрывает подробности. Строки стоят плотнее, чем блоки ленты, поэтому собраны в свой столбец.
                                VStack(spacing: FormaSpacing.s) {
                                    ForEach(habitsManager.filteredBuildHabits) { habit in
                                        HabitBuildRow(
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
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            // ИИ-коуч по привычкам: общий вид ИИ-карточек
                            HabitsAICoachCard(
                                title: "ИИ-коуч по привычкам",
                                placeholder: "Коуч поможет выстроить цепочку привычек так, чтобы энергии и дисциплины хватало на весь день.",
                                actionTitle: "Оценить рутину",
                                onAnalyze: {
                                    Task {
                                        await habitsManager.runAIDisciplineAnalysis(health: health, stepManager: stepManager, language: appLanguage)
                                    }
                                }
                            )
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
                                VStack(spacing: FormaSpacing.s) {
                                    ForEach(habitsManager.quitHabits) { habit in
                                        HabitQuitRow(
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
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            // ИИ-наставник выдержки: тот же общий вид ИИ-карточек
                            HabitsAICoachCard(
                                title: "ИИ-наставник выдержки",
                                placeholder: "Наставник разберёт триггеры, мотивацию и то, как удержать чистую серию.",
                                actionTitle: "Оценить с ИИ",
                                onAnalyze: {
                                    Task {
                                        await habitsManager.runAIDisciplineAnalysis(health: health, stepManager: stepManager, language: appLanguage)
                                    }
                                }
                            )
                            .padding(.horizontal)
                        }
                    }
                    
                    // СТАТИСТИКА (баннер FORMA PRO теперь наверху, под шапкой)
                    Group {
                        // ПАНЕЛЬ ЗАЩИТЫ СТРИКА (Streak Freeze Shields)
                        StreakFreezeShieldBarView()
                            .padding(.horizontal)

                        // МАТРИЦА АКТИВНОСТИ (Heatmap 30-90 дней)
                        HabitHeatmapView()
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
                    .font(.system(size: 11, weight: .semibold))
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
                .background(Color(red: 56/255, green: 189/255, blue: 248/255))
                .clipShape(RoundedRectangle(cornerRadius: FormaRadius.chip, style: .continuous))
                // Видимая кнопка небольшая, а нажимается область не меньше 44 pt
                .frame(minHeight: FormaTouch.minTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(AppleDesignAwardsButtonStyle(scaleAmount: 0.94))
        }
        .padding(12)
        .formaSurface(FormaRadius.control)
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

    @State private var isRevealed = FormaRevealMemory.contains("habits.hero")

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
                    stat(icon: "flame.fill", color: Theme.flameOrange, value: "\(bestStreak)", unit: "рекорд")
                    stat(icon: "snowflake", color: Theme.standColor, value: "\(shields)", unit: Self.shieldsWord(shields))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .formaHeroCard(tint: Self.green, padding: FormaSpacing.xl - 4)
        .task {
            guard !isRevealed else { return }
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            isRevealed = true
            FormaRevealMemory.insert("habits.hero")
        }
        .accessibilityElement(children: .combine)
    }

    /// 1 щит, 2 щита, 5 щитов
    static func shieldsWord(_ count: Int) -> String {
        let lastTwo = count % 100
        let last = count % 10
        if (11...14).contains(lastTwo) { return "щитов" }
        if last == 1 { return "щит" }
        if (2...4).contains(last) { return "щита" }
        return "щитов"
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
