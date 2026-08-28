import SwiftUI

public enum GoalDurationSelection: String, CaseIterable, Identifiable {
    case days10 = "10 дней"
    case days21 = "21 день"
    case days30 = "30 дней"
    case days100 = "100 дней"
    case calendarDate = "Дата в календаре 📅"
    
    public var id: String { rawValue }
    
    public var days: Int? {
        switch self {
        case .days10: return 10
        case .days21: return 21
        case .days30: return 30
        case .days100: return 100
        case .calendarDate: return nil
        }
    }
}

@MainActor
public struct CreateHabitSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var habitsManager = HabitsManager.shared
    
    @State private var habitType: HabitType
    @State private var title: String = ""
    @State private var subtitle: String = ""
    @State private var selectedCategory: HabitCategory
    @State private var selectedIcon: String
    @State private var selectedColorHex: String
    
    // Цели и календарь
    @State private var isGoalDurationEnabled: Bool = false
    @State private var selectedGoalDuration: GoalDurationSelection = .days30
    @State private var customGoalEndDate: Date = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    
    // Уведомления
    @State private var isSmartRemindersEnabled: Bool = true
    @State private var isReminderEnabled: Bool = false
    @State private var reminderDate: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var targetType: HabitTargetType = .manual
    
    public init(initialType: HabitType = .build) {
        self._habitType = State(initialValue: initialType)
        self._selectedColorHex = State(initialValue: initialType == .quit ? "#EF4444" : "#10B981")
        self._selectedCategory = State(initialValue: initialType == .quit ? .quitting : .health)
        self._selectedIcon = State(initialValue: initialType == .quit ? "shield.fill" : "star.fill")
    }
    
    private let availableIcons = [
        "star.fill", "figure.walk", "drop.fill", "figure.run", "figure.yoga",
        "pill.fill", "moon.stars.fill", "book.fill", "sparkles", "heart.fill",
        "brain.head.profile", "dumbbell.fill", "cup.and.saucer.fill",
        "shield.fill", "nosign", "smoke.fill", "cube.slash.fill", "hand.raised.slash.fill"
    ]
    
    private let availableColors = [
        "#10B981", "#00E5FF", "#3B82F6", "#A855F7",
        "#EF4444", "#F59E0B", "#EC4899", "#8B5CF6"
    ]
    
    private struct HabitTemplate: Identifiable {
        var id: String { title }
        let title: String
        let subtitle: String
        let type: HabitType
        let category: HabitCategory
        let icon: String
        let colorHex: String
        let targetType: HabitTargetType
    }
    
    private let templates: [HabitTemplate] = [
        // Полезные привычки
        HabitTemplate(title: "Пить 2.5 л воды", subtitle: "Авто-трекинг через HealthKit", type: .build, category: .health, icon: "drop.fill", colorHex: "#00E5FF", targetType: .healthKitWater(targetMl: 2500)),
        HabitTemplate(title: "10 000 шагов в день", subtitle: "Ежедневная норма ходьбы", type: .build, category: .fitness, icon: "figure.walk", colorHex: "#10B981", targetType: .healthKitSteps(target: 10000)),
        HabitTemplate(title: "Витамины & Омега-3", subtitle: "Прием с утренним завтраком", type: .build, category: .health, icon: "pill.fill", colorHex: "#F59E0B", targetType: .manual),
        HabitTemplate(title: "15 мин растяжки", subtitle: "Перед вечерним отходом ко сну", type: .build, category: .recovery, icon: "figure.yoga", colorHex: "#A855F7", targetType: .manual),
        HabitTemplate(title: "10 мин медитации", subtitle: "Дыхание и ментальная разгрузка", type: .build, category: .mindfulness, icon: "sparkles", colorHex: "#EC4899", targetType: .manual),
        HabitTemplate(title: "Сон 8 часов", subtitle: "Синхронизация с датчиками сна", type: .build, category: .recovery, icon: "moon.stars.fill", colorHex: "#3B82F6", targetType: .healthKitSleep(targetHours: 8.0)),
        
        // Отказ от вредных привычек
        HabitTemplate(title: "Без курения / никотина", subtitle: "Чистые легкие и выносливость", type: .quit, category: .quitting, icon: "smoke.fill", colorHex: "#EF4444", targetType: .manual),
        HabitTemplate(title: "Без добавленного сахара", subtitle: "Контроль энергии и баланс инсулина", type: .quit, category: .nutrition, icon: "cube.slash.fill", colorHex: "#F59E0B", targetType: .manual),
        HabitTemplate(title: "Без соцсетей до 11:00", subtitle: "Утренний фокус и продуктивность", type: .quit, category: .mindfulness, icon: "nosign", colorHex: "#8B5CF6", targetType: .manual),
        HabitTemplate(title: "Без фастфуда", subtitle: "Здоровая микрофлора и чистая кожа", type: .quit, category: .nutrition, icon: "nosign", colorHex: "#EC4899", targetType: .manual),
        HabitTemplate(title: "Без кофеина после 15:00", subtitle: "Глубокий и восстанавливающий сон", type: .quit, category: .recovery, icon: "cup.and.saucer.fill", colorHex: "#3B82F6", targetType: .manual),
        HabitTemplate(title: "Контроль компульсивного стресса", subtitle: "Осознанность и спокойствие рук", type: .quit, category: .quitting, icon: "hand.raised.slash.fill", colorHex: "#10B981", targetType: .manual)
    ]
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // Переключатель типа
                        Picker("Тип привычки", selection: $habitType) {
                            Text("Полезная привычка ⚡").tag(HabitType.build)
                            Text("Отказ от вредной 🛡️").tag(HabitType.quit)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .onChange(of: habitType) { _, newType in
                            if newType == .quit {
                                if selectedCategory != .quitting {
                                    selectedCategory = .quitting
                                }
                                if selectedColorHex == "#10B981" {
                                    selectedColorHex = "#EF4444"
                                }
                                if selectedIcon == "star.fill" {
                                    selectedIcon = "shield.fill"
                                }
                            } else {
                                if selectedCategory == .quitting {
                                    selectedCategory = .health
                                }
                                if selectedColorHex == "#EF4444" {
                                    selectedColorHex = "#10B981"
                                }
                                if selectedIcon == "shield.fill" {
                                    selectedIcon = "star.fill"
                                }
                            }
                            HapticManager.shared.selection()
                        }
                        
                        // Шаблоны быстрого выбора под выбранный тип
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Готовые шаблоны")
                                .font(.caption.bold())
                                .foregroundColor(Theme.textSecondary)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(templates.filter { $0.type == habitType }) { tmpl in
                                        Button(action: {
                                            applyTemplate(tmpl)
                                            HapticManager.shared.selection()
                                        }) {
                                            HStack(spacing: 8) {
                                                Image(systemName: tmpl.icon)
                                                    .foregroundColor(Color(hex: tmpl.colorHex) ?? .blue)
                                                Text(tmpl.title)
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundColor(Theme.textPrimary)
                                            }
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(Theme.cardBackground)
                                            .cornerRadius(14)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14)
                                                    .stroke(title == tmpl.title ? (Color(hex: tmpl.colorHex) ?? .blue) : Color.primary.opacity(0.08), lineWidth: 1.5)
                                            )
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // Основные поля
                        VStack(spacing: 14) {
                            TextField(habitType == .build ? "Название (например: 10 000 шагов в день)" : "Название (например: Не грызть ногти)", text: $title)
                                .font(.system(size: 16, weight: .semibold))
                                .padding(14)
                                .background(Color.primary.opacity(0.05))
                                .cornerRadius(14)
                            
                            TextField("Описание / Зачем это нужно (опционально)", text: $subtitle)
                                .font(.system(size: 14))
                                .padding(14)
                                .background(Color.primary.opacity(0.05))
                                .cornerRadius(14)
                        }
                        .premiumCard()
                        .padding(.horizontal)
                        
                        // БЛОК: ЦЕЛЬ И КАЛЕНДАРЬ СРОКОВ 🎯
                        VStack(alignment: .leading, spacing: 14) {
                            Toggle(isOn: $isGoalDurationEnabled) {
                                HStack(spacing: 8) {
                                    Image(systemName: "target")
                                        .foregroundColor(Theme.exerciseColor)
                                        .font(.system(size: 16, weight: .bold))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(habitType == .quit ? "Срок цели воздержания" : "Срок выполнения цели")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(Theme.textPrimary)
                                        Text(habitType == .quit ? "Например: 10 дней, месяц или дата в календаре" : "Например: 10 дней по 10 000 шагов")
                                            .font(.system(size: 11))
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                }
                            }
                            .tint(Color(hex: selectedColorHex) ?? Theme.exerciseColor)
                            
                            if isGoalDurationEnabled {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Длительность цели")
                                        .font(.caption.bold())
                                        .foregroundColor(Theme.textSecondary)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(GoalDurationSelection.allCases) { dur in
                                                Button(action: {
                                                    selectedGoalDuration = dur
                                                    HapticManager.shared.selection()
                                                }) {
                                                    Text(dur.rawValue)
                                                        .font(.system(size: 13, weight: selectedGoalDuration == dur ? .bold : .medium))
                                                        .padding(.horizontal, 12)
                                                        .padding(.vertical, 8)
                                                        .background(selectedGoalDuration == dur ? (Color(hex: selectedColorHex) ?? .blue).opacity(0.18) : Color.primary.opacity(0.05))
                                                        .foregroundColor(selectedGoalDuration == dur ? (Color(hex: selectedColorHex) ?? .blue) : Theme.textPrimary)
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 12)
                                                                .stroke(selectedGoalDuration == dur ? (Color(hex: selectedColorHex) ?? .blue) : Color.clear, lineWidth: 1.5)
                                                        )
                                                        .cornerRadius(12)
                                                }
                                            }
                                        }
                                    }
                                    
                                    if selectedGoalDuration == .calendarDate {
                                        DatePicker(
                                            "Целевая дата окончания",
                                            selection: $customGoalEndDate,
                                            in: Calendar.current.date(byAdding: .day, value: 1, to: Date())!...,
                                            displayedComponents: .date
                                        )
                                        .datePickerStyle(.graphical)
                                        .padding(.top, 4)
                                    }
                                }
                                .padding(.top, 6)
                            }
                        }
                        .premiumCard()
                        .padding(.horizontal)
                        
                        // БЛОК: УМНЫЕ УВЕДОМЛЕНИЯ ИИ-КОУЧА 🧠
                        VStack(alignment: .leading, spacing: 14) {
                            Toggle(isOn: $isSmartRemindersEnabled) {
                                HStack(spacing: 8) {
                                    Image(systemName: "sparkles")
                                        .foregroundColor(Theme.aiAccent)
                                        .font(.system(size: 16, weight: .bold))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Умные случайные напоминания")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(Theme.textPrimary)
                                        Text(habitType == .quit ? "ИИ пришлет вопрос «Держишься?», советы и мотивацию" : "Случайные вдохновляющие напоминания от тренера")
                                            .font(.system(size: 11))
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                }
                            }
                            .tint(Theme.aiAccent)
                            
                            Divider()
                            
                            Toggle("Точное ежедневное напоминание", isOn: $isReminderEnabled)
                                .font(.system(size: 15, weight: .semibold))
                                .tint(Color(hex: selectedColorHex) ?? .blue)
                            
                            if isReminderEnabled {
                                DatePicker("Время", selection: $reminderDate, displayedComponents: .hourAndMinute)
                                    .datePickerStyle(.compact)
                                    .font(.system(size: 14))
                            }
                        }
                        .premiumCard()
                        .padding(.horizontal)
                        
                        // Выбор категории
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Категория")
                                .font(.caption.bold())
                                .foregroundColor(Theme.textSecondary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(HabitCategory.allCases.filter { habitType == .quit || $0 != .quitting }, id: \.self) { cat in
                                        Button(action: {
                                            selectedCategory = cat
                                            HapticManager.shared.selection()
                                        }) {
                                            HStack(spacing: 6) {
                                                Image(systemName: cat.icon)
                                                Text(cat.title)
                                            }
                                            .font(.system(size: 13, weight: .semibold))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(selectedCategory == cat ? (Color(hex: selectedColorHex) ?? .blue).opacity(0.18) : Color.primary.opacity(0.05))
                                            .foregroundColor(selectedCategory == cat ? (Color(hex: selectedColorHex) ?? .blue) : Theme.textPrimary)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(selectedCategory == cat ? (Color(hex: selectedColorHex) ?? .blue) : Color.clear, lineWidth: 1.5)
                                            )
                                            .cornerRadius(12)
                                        }
                                    }
                                }
                            }
                        }
                        .premiumCard()
                        .padding(.horizontal)
                        
                        // Выбор иконки и цвета
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Иконка и цвет")
                                .font(.caption.bold())
                                .foregroundColor(Theme.textSecondary)
                            
                            // Иконки
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(availableIcons, id: \.self) { ico in
                                        Button(action: {
                                            selectedIcon = ico
                                            HapticManager.shared.selection()
                                        }) {
                                            ZStack {
                                                Circle()
                                                    .fill(selectedIcon == ico ? (Color(hex: selectedColorHex) ?? .blue).opacity(0.2) : Color.primary.opacity(0.06))
                                                    .frame(width: 42, height: 42)
                                                Image(systemName: ico)
                                                    .font(.system(size: 18))
                                                    .foregroundColor(selectedIcon == ico ? (Color(hex: selectedColorHex) ?? .blue) : Theme.textPrimary)
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // Цвета
                            HStack(spacing: 10) {
                                ForEach(availableColors, id: \.self) { col in
                                    Button(action: {
                                        selectedColorHex = col
                                        HapticManager.shared.selection()
                                    }) {
                                        ZStack {
                                            Circle()
                                                .fill(Color(hex: col) ?? .blue)
                                                .frame(width: 32, height: 32)
                                            if selectedColorHex == col {
                                                Image(systemName: "checkmark")
                                                    .font(.caption.bold())
                                                    .foregroundColor(.white)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                        .premiumCard()
                        .padding(.horizontal)
                        
                        // Кнопка сохранения
                        Button(action: {
                            saveNewHabit()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                Text(habitType == .quit ? "Создать отказ от привычки" : "Создать полезную привычку")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .foregroundColor(.white)
                            .background(
                                (Color(hex: selectedColorHex) ?? Theme.exerciseColor)
                            )
                            .cornerRadius(16)
                            .shadow(color: (Color(hex: selectedColorHex) ?? Theme.exerciseColor).opacity(0.3), radius: 8, y: 3)
                        }
                        .buttonStyle(AppleDesignAwardsButtonStyle(scaleAmount: 0.96))
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle(habitType == .quit ? "Отказ от привычки" : "Новая полезная привычка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                    .foregroundColor(Theme.textSecondary)
                }
            }
        }
    }
    
    private func applyTemplate(_ tmpl: HabitTemplate) {
        self.title = tmpl.title
        self.subtitle = tmpl.subtitle
        self.habitType = tmpl.type
        self.selectedCategory = tmpl.category
        self.selectedIcon = tmpl.icon
        self.selectedColorHex = tmpl.colorHex
        self.targetType = tmpl.targetType
    }
    
    private func saveNewHabit() {
        let calendar = Calendar.current
        let hour = isReminderEnabled ? calendar.component(.hour, from: reminderDate) : nil
        let minute = isReminderEnabled ? calendar.component(.minute, from: reminderDate) : nil
        
        var targetDays: Int? = nil
        var targetEndDate: Date? = nil
        
        if isGoalDurationEnabled {
            if let days = selectedGoalDuration.days {
                targetDays = days
            } else if selectedGoalDuration == .calendarDate {
                targetEndDate = customGoalEndDate
            }
        }
        
        let newHabit = HabitItem(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            subtitle: subtitle.trimmingCharacters(in: .whitespacesAndNewlines),
            type: habitType,
            category: selectedCategory,
            icon: selectedIcon,
            colorHex: selectedColorHex,
            targetType: targetType,
            createdAt: Date(),
            quitStartDate: habitType == .quit ? Date() : nil,
            goalTargetDays: targetDays,
            goalEndDate: targetEndDate,
            reminderHour: hour,
            reminderMinute: minute,
            isReminderEnabled: isReminderEnabled,
            isSmartRemindersEnabled: isSmartRemindersEnabled,
            xpReward: habitType == .quit ? 30 : 20
        )
        
        habitsManager.addHabit(newHabit)
        dismiss()
    }
}
