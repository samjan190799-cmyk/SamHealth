import SwiftUI

public enum HabitMainTab: String, CaseIterable, Identifiable {
    case quit = "Вредные 🛡️"
    case build = "Полезные ⚡"
    
    public var id: String { self.rawValue }
}

@MainActor
public struct HabitsView: View {
    @EnvironmentObject var health: HealthKitManager
    @EnvironmentObject var stepManager: BackgroundStepManager
    @ObservedObject var habitsManager = HabitsManager.shared
    @ObservedObject var gamification = GamificationManager.shared
    @ObservedObject var coachManager = AICoachManager.shared
    
    @State private var selectedTab: HabitMainTab = .quit
    @State private var showingCreateSheet = false
    @State private var defaultCreateType: HabitType = .quit
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
                VStack(spacing: 20) {
                    
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
                    
                    // СЕГМЕНТИРОВАННЫЙ ПЕРЕКЛЮЧАТЕЛЬ НА ДВЕ ВКЛАДКИ
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
                                    
                                    // Бейдж количества привычек
                                    let count = tab == .quit ? habitsManager.quitHabits.count : habitsManager.buildHabits.count
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
                                        ? (tab == .quit ? Color(red: 239/255, green: 68/255, blue: 68/255) : Color(red: 16/255, green: 185/255, blue: 129/255))
                                        : Theme.cardBackground
                                )
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(isSelected ? Color.clear : Color.primary.opacity(0.08), lineWidth: 1)
                                )
                                .shadow(color: isSelected ? (tab == .quit ? Color.red : Color.green).opacity(0.25) : Color.clear, radius: 6, y: 2)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // КОНТЕНТ ВЫБРАННОЙ ВКЛАДКИ
                    if selectedTab == .quit {
                        // ================= ВКЛАДКА 1: ВРЕДНЫЕ ПРИВЫЧКИ =================
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
                            
                            // Заголовок с кнопкой добавления
                            HStack {
                                Label("Отказ от вредных привычек", systemImage: "shield.fill")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(Theme.textPrimary)
                                
                                Spacer()
                                
                                Button(action: {
                                    defaultCreateType = .quit
                                    showingCreateSheet = true
                                    HapticManager.shared.impact(.light)
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Добавить")
                                    }
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Theme.moveColor)
                                }
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
                                    Text("Добавьте любую привычку (курение, сахар, компульсии, соцсети), чтобы отслеживать чистые дни и получать поддержку.")
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                        .multilineTextAlignment(.center)
                                    
                                    Button(action: {
                                        defaultCreateType = .quit
                                        showingCreateSheet = true
                                    }) {
                                        Text("+ Создать отказ от привычки")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Theme.moveColor)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(Theme.moveColor.opacity(0.12))
                                            .cornerRadius(10)
                                    }
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
                                        Text("ИИ-Психолог выдержки")
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
                                    Text("Нажмите «Оценить с ИИ», чтобы персональный тренер дал глубокий психологический разбор по триггерам, дофамину и удержанию чистых стриков.")
                                        .font(.system(size: 12))
                                        .foregroundColor(Theme.textSecondary)
                                        .lineSpacing(3)
                                }
                            }
                            .premiumCard()
                            .padding(.horizontal)
                        }
                    } else {
                        // ================= ВКЛАДКА 2: ПОЛЕЗНЫЕ ПРИВЫЧКИ =================
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
                            
                            // Заголовок с кнопкой добавления
                            HStack {
                                Label("Полезные привычки", systemImage: "sparkles")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(Theme.textPrimary)
                                
                                Spacer()
                                
                                Button(action: {
                                    defaultCreateType = .build
                                    showingCreateSheet = true
                                    HapticManager.shared.impact(.light)
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Добавить")
                                    }
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Theme.exerciseColor)
                                }
                            }
                            .padding(.horizontal)
                            
                            let columns = [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ]
                            
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(habitsManager.buildHabits) { habit in
                                    GoodHabitGridCard(habit: habit) {
                                        habitsManager.toggleHabitCompletion(id: habit.id)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            
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
                                    Text("Персональный ИИ-коуч поможет выстроить идеальную цепочку утренних и вечерних привычек (Habit Stacking) для максимальной энергии.")
                                        .font(.system(size: 12))
                                        .foregroundColor(Theme.textSecondary)
                                        .lineSpacing(3)
                                }
                            }
                            .premiumCard()
                            .padding(.horizontal)
                        }
                    }
                    
                    // КНОПКА ДОБАВЛЕНИЯ ПРИВЫЧКИ
                    Button(action: {
                        defaultCreateType = selectedTab == .quit ? .quit : .build
                        showingCreateSheet = true
                        HapticManager.shared.impact(.light)
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.headline)
                            Text(selectedTab == .quit ? "Создать отказ от привычки" : "Создать полезную привычку")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundColor(Theme.textPrimary)
                        .background(Theme.cardBackground)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .buttonStyle(AppleDesignAwardsButtonStyle(scaleAmount: 0.96))
                    .padding(.horizontal)
                    .padding(.bottom, 100) // Защита от перекрытия нижним таб-баром
                }
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateHabitSheet(initialType: defaultCreateType)
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

// MARK: - HERO КАРТОЧКА ОТКАЗА ОТ ВРЕДНОЙ ПРИВЫЧКИ (СИММЕТРИЧНЫЕ КНОПКИ)
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

// MARK: - КАРТОЧКА ПОЛЕЗНОЙ ПРИВЫЧКИ (Good Habit Grid Card)
struct GoodHabitGridCard: View {
    let habit: HabitItem
    var onToggle: () -> Void
    
    var body: some View {
        Button(action: {
            onToggle()
        }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(habit.color.opacity(0.18))
                            .frame(width: 36, height: 36)
                        Image(systemName: habit.icon)
                            .font(.subheadline.bold())
                            .foregroundColor(habit.color)
                    }
                    
                    Spacer()
                    
                    // Интерактивный чекбокс
                    ZStack {
                        Circle()
                            .fill(habit.isCompletedToday ? habit.color : Color.primary.opacity(0.08))
                            .frame(width: 26, height: 26)
                        
                        if habit.isCompletedToday {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if habit.buildStreakDays > 1 {
                        Text("🔥 \(habit.buildStreakDays) дн. стрик")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.orange)
                    } else {
                        Text("+\(habit.xpReward) XP")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(habit.color)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
            .background(Theme.cardBackground)
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(habit.isCompletedToday ? habit.color.opacity(0.35) : Color.primary.opacity(0.06), lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
        }
        .buttonStyle(AppleDesignAwardsButtonStyle(scaleAmount: 0.96))
    }
}
