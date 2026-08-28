import SwiftUI

@MainActor
public struct HabitsView: View {
    @EnvironmentObject var health: HealthKitManager
    @EnvironmentObject var stepManager: BackgroundStepManager
    @ObservedObject var habitsManager = HabitsManager.shared
    @ObservedObject var gamification = GamificationManager.shared
    @ObservedObject var coachManager = AICoachManager.shared
    
    @State private var showingCreateSheet = false
    @State private var activeSOSHabit: HabitItem? = nil
    @State private var showingResetAlert = false
    @State private var habitToReset: HabitItem? = nil
    
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
                VStack(spacing: 22) {
                    
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
                    
                    // БЛОК 1: ОТКАЗ ОТ ВРЕДНЫХ ПРИВЫЧЕК (HERO КАРТОЧКИ)
                    if !habitsManager.quitHabits.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label("Отказ от вредных привычек", systemImage: "shield.fill")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(Theme.textPrimary)
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            ForEach(habitsManager.quitHabits) { habit in
                                QuitHabitHeroCard(
                                    habit: habit,
                                    onSOS: {
                                        activeSOSHabit = habit
                                        HapticManager.shared.impact(.medium)
                                    },
                                    onReset: {
                                        habitToReset = habit
                                        showingResetAlert = true
                                    }
                                )
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // БЛОК 2: СЕТКА ПОЛЕЗНЫХ ПРИВЫЧЕК НА СЕГОДНЯ
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Полезные привычки", systemImage: "sparkles")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(Theme.textPrimary)
                            Spacer()
                            Text("\(habitsManager.buildHabits.filter { $0.isCompletedToday }.count)/\(habitsManager.buildHabits.count)")
                                .font(.caption.bold())
                                .foregroundColor(Theme.textSecondary)
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
                    }
                    
                    // БЛОК 3: ИИ-СОВЕТ КОУЧА ПО ДИСЦИПЛИНЕ
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(Theme.aiAccent)
                                .font(.subheadline)
                            Text("ИИ-Совет по дисциплине")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Theme.textPrimary)
                        }
                        
                        let cleanNailHabit = habitsManager.quitHabits.first(where: { $0.title.lowercased().contains("ногт") })
                        let streak = cleanNailHabit?.cleanStreakDays ?? 14
                        
                        Text("Ваш стрик без компульсивного стресса держится уже \(streak) дн.! В моменты усталости за компьютером сделайте 5 глубоких вдохов или выпейте стакан воды, чтобы переключить моторику рук.")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textSecondary)
                            .lineSpacing(3)
                    }
                    .premiumCard()
                    .padding(.horizontal)
                    
                    // КНОПКА ДОБАВЛЕНИЯ НОВОЙ ПРИВЫЧКИ
                    Button(action: {
                        showingCreateSheet = true
                        HapticManager.shared.impact(.light)
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.headline)
                            Text("Новая привычка")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
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
                    .padding(.bottom, 28)
                }
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateHabitSheet()
        }
        .sheet(item: $activeSOSHabit) { habit in
            PanicSOSBreathingSheet(habit: habit)
        }
        .alert("Зафиксировать срыв?", isPresented: $showingResetAlert) {
            Button("Отмена", role: .cancel) { }
            Button("Сбросить стрик", role: .destructive) {
                if let h = habitToReset {
                    habitsManager.resetQuitStreak(id: h.id)
                }
            }
        } message: {
            Text("Срывы бывают у каждого — главное не опускать руки и начать новый чистый стрик прямо сейчас!")
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

// MARK: - HERO КАРТОЧКА ОТКАЗА ОТ ВРЕДНОЙ ПРИВЫЧКИ (Obsidian Glass)
struct QuitHabitHeroCard: View {
    let habit: HabitItem
    var onSOS: () -> Void
    var onReset: () -> Void
    
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
                    
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text("\(habit.cleanStreakDays) дней чист")
                            .font(.caption.bold())
                            .foregroundColor(.orange)
                        
                        if habit.urgeResistedCount > 0 {
                            Text("• \(habit.urgeResistedCount) раз сдержался 🛡️")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                }
                
                Spacer()
                
                Menu {
                    Button(role: .destructive, action: onReset) {
                        Label("Зафиксировать срыв", systemImage: "arrow.counterclockwise")
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
            
            // Недельная матрица точек выдержки (Heat-dots)
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
                    Text("Сегодня")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                }
            }
            
            // Интерактивная кнопка выдержки «Сдержался 🛡️»
            Button(action: onSOS) {
                HStack(spacing: 8) {
                    Image(systemName: "shield.fill")
                    Text("Сдержался 🛡️ (Фокус-режим)")
                        .font(.system(size: 14, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundColor(.white)
                .background(
                    LinearGradient(
                        colors: [habit.color, habit.color.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(14)
                .shadow(color: habit.color.opacity(0.25), radius: 6, y: 2)
            }
            .buttonStyle(AppleDesignAwardsButtonStyle(scaleAmount: 0.96))
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
