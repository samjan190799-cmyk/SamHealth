import SwiftUI

@MainActor
public struct CreateHabitSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var habitsManager = HabitsManager.shared
    
    @State private var habitType: HabitType = .build
    @State private var title: String = ""
    @State private var subtitle: String = ""
    @State private var selectedCategory: HabitCategory = .health
    @State private var selectedIcon: String = "star.fill"
    @State private var selectedColorHex: String = "#10B981"
    @State private var isReminderEnabled: Bool = false
    @State private var reminderDate: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var targetType: HabitTargetType = .manual
    
    private let availableIcons = [
        "hand.raised.slash.fill", "cube.slash.fill", "nosign", "smoke.fill",
        "drop.fill", "figure.walk", "figure.run", "figure.yoga",
        "pill.fill", "moon.stars.fill", "book.fill", "sparkles",
        "heart.fill", "brain.head.profile", "flame.fill", "dumbbell.fill"
    ]
    
    private let availableColors = [
        "#10B981", "#00E5FF", "#A855F7", "#EF4444",
        "#F59E0B", "#3B82F6", "#EC4899", "#8B5CF6"
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
        HabitTemplate(title: "Не грызть ногти", subtitle: "Свобода от компульсивного стресса", type: .quit, category: .quitting, icon: "hand.raised.slash.fill", colorHex: "#EF4444", targetType: .manual),
        HabitTemplate(title: "Без добавленного сахара", subtitle: "Контроль энергии и чистота кожи", type: .quit, category: .nutrition, icon: "cube.slash.fill", colorHex: "#F59E0B", targetType: .manual),
        HabitTemplate(title: "Без соцсетей до 11:00", subtitle: "Утренний фокус и продуктивность", type: .quit, category: .mindfulness, icon: "nosign", colorHex: "#8B5CF6", targetType: .manual),
        HabitTemplate(title: "Пить 2.5 л воды", subtitle: "Авто-трекинг через HealthKit", type: .build, category: .health, icon: "drop.fill", colorHex: "#00E5FF", targetType: .healthKitWater(targetMl: 2500)),
        HabitTemplate(title: "10 000 шагов в день", subtitle: "Ежедневная норма ходьбы", type: .build, category: .fitness, icon: "figure.walk", colorHex: "#10B981", targetType: .healthKitSteps(target: 10000)),
        HabitTemplate(title: "Витамины & Омега-3", subtitle: "Прием с утренним завтраком", type: .build, category: .health, icon: "pill.fill", colorHex: "#F59E0B", targetType: .manual),
        HabitTemplate(title: "15 мин растяжки", subtitle: "Перед вечерним отходом ко сну", type: .build, category: .recovery, icon: "figure.yoga", colorHex: "#A855F7", targetType: .manual),
        HabitTemplate(title: "10 мин медитации", subtitle: "Дыхание и ментальная разгрузка", type: .build, category: .mindfulness, icon: "sparkles", colorHex: "#EC4899", targetType: .manual),
        HabitTemplate(title: "Сон 8 часов", subtitle: "Синхронизация с датчиками сна", type: .build, category: .recovery, icon: "moon.stars.fill", colorHex: "#3B82F6", targetType: .healthKitSleep(targetHours: 8.0))
    ]
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 22) {
                        
                        // Переключатель типа
                        Picker("Тип привычки", selection: $habitType) {
                            Text("Полезная привычка").tag(HabitType.build)
                            Text("Отказ от вредной 🛡️").tag(HabitType.quit)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        // Шаблоны быстрого выбора
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
                            TextField("Название (например: Не грызть ногти)", text: $title)
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
                        
                        // Выбор категории
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Категория")
                                .font(.caption.bold())
                                .foregroundColor(Theme.textSecondary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(HabitCategory.allCases, id: \.self) { cat in
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
                                            .background(selectedCategory == cat ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05))
                                            .foregroundColor(selectedCategory == cat ? Color.accentColor : Theme.textPrimary)
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
                            
                            // Палитра иконок
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(availableIcons, id: \.self) { ico in
                                        Button(action: {
                                            selectedIcon = ico
                                            HapticManager.shared.selection()
                                        }) {
                                            ZStack {
                                                Circle()
                                                    .fill(selectedIcon == ico ? (Color(hex: selectedColorHex) ?? .blue).opacity(0.2) : Color.primary.opacity(0.05))
                                                    .frame(width: 44, height: 44)
                                                Image(systemName: ico)
                                                    .font(.system(size: 18, weight: .bold))
                                                    .foregroundColor(selectedIcon == ico ? (Color(hex: selectedColorHex) ?? .blue) : Theme.textPrimary)
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // Палитра цветов
                            HStack(spacing: 12) {
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
                        
                        // Напоминание
                        VStack(spacing: 12) {
                            Toggle("Ежедневное напоминание", isOn: $isReminderEnabled)
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
                        
                        // Кнопка сохранения
                        Button(action: {
                            saveNewHabit()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                Text("Создать привычку")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .foregroundColor(.white)
                            .background(
                                (Color(hex: selectedColorHex) ?? Theme.exerciseColor)
                            )
                            .cornerRadius(18)
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
            .navigationTitle("Новая привычка")
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
            reminderHour: hour,
            reminderMinute: minute,
            isReminderEnabled: isReminderEnabled,
            xpReward: habitType == .quit ? 30 : 20
        )
        
        habitsManager.addHabit(newHabit)
        dismiss()
    }
}
