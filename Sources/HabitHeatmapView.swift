import SwiftUI

// MARK: - Интерактивная матрица активности привычек (Heatmap 30-90 дней)
@MainActor
public struct HabitHeatmapView: View {
    @ObservedObject var habitsManager = HabitsManager.shared
    
    @State private var selectedPeriodDays: Int = 30
    @State private var selectedDay: HabitHeatmapDay? = nil
    
    private let periods: [Int] = [30, 60, 90]
    
    public init() {}
    
    private var heatmapDays: [HabitHeatmapDay] {
        habitsManager.heatmapData(days: selectedPeriodDays)
    }
    
    // Группировка дней по неделям (колонки) для рендеринга GitHub/Fitness-style сетки (7 строк: Пн..Вс)
    private var weeksGrid: [[HabitHeatmapDay?]] {
        let days = heatmapDays
        guard !days.isEmpty else { return [] }
        
        var columns: [[HabitHeatmapDay?]] = []
        var currentColumn: [HabitHeatmapDay?] = Array(repeating: nil, count: 7)
        
        for day in days {
            // dayOfWeek: 1 = Пн ... 7 = Вс (индекс 0...6)
            let rowIndex = max(0, min(6, day.dayOfWeek - 1))
            currentColumn[rowIndex] = day
            
            // Если воскресенье (индекс 6) — завершаем колонку
            if rowIndex == 6 {
                columns.append(currentColumn)
                currentColumn = Array(repeating: nil, count: 7)
            }
        }
        
        // Добавляем оставшиеся дни текущей недели
        if currentColumn.contains(where: { $0 != nil }) {
            columns.append(currentColumn)
        }
        
        return columns
    }
    
    // Статистические показатели
    private var perfectDaysCount: Int {
        heatmapDays.filter { $0.isPerfectDay }.count
    }
    
    private var frozenDaysCount: Int {
        heatmapDays.filter { $0.isFrozen }.count
    }
    
    private var consistencyRatePercent: Int {
        let days = heatmapDays
        guard !days.isEmpty else { return 0 }
        let activeCount = days.filter { $0.fraction > 0 || $0.isFrozen }.count
        return Int(round((Double(activeCount) / Double(days.count)) * 100.0))
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            
            // 1. Заголовок матрицы и переключатель периодов
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Image(systemName: "square.grid.3x3.fill")
                        .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                        .font(.system(size: 14, weight: .bold))
                    Text("Матрица дисциплины")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                }
                
                Spacer()
                
                // Переключатель 30 / 60 / 90 дней
                HStack(spacing: 4) {
                    ForEach(periods, id: \.self) { period in
                        let isSelected = selectedPeriodDays == period
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                selectedPeriodDays = period
                                selectedDay = nil
                            }
                            HapticManager.shared.selection()
                        }) {
                            Text("\(period)д")
                                .font(.system(size: 11, weight: isSelected ? .bold : .semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .foregroundColor(isSelected ? .white : Theme.textSecondary)
                                .background(
                                    isSelected
                                        ? Color(red: 16/255, green: 185/255, blue: 129/255)
                                        : Color.clear
                                )
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(2)
                .background(Color.primary.opacity(0.06))
                .clipShape(Capsule())
            }
            
            // 2. Сетка ячеек активности
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 5) {
                        
                        // Метки дней недели слева (Пн, Ср, Пт)
                        VStack(spacing: 5) {
                            Text("Пн").font(.system(size: 8, weight: .bold)).foregroundColor(Theme.textSecondary)
                                .frame(height: 14)
                            Text("").frame(height: 14)
                            Text("Ср").font(.system(size: 8, weight: .bold)).foregroundColor(Theme.textSecondary)
                                .frame(height: 14)
                            Text("").frame(height: 14)
                            Text("Пт").font(.system(size: 8, weight: .bold)).foregroundColor(Theme.textSecondary)
                                .frame(height: 14)
                            Text("").frame(height: 14)
                            Text("Вс").font(.system(size: 8, weight: .bold)).foregroundColor(Theme.textSecondary)
                                .frame(height: 14)
                        }
                        .padding(.trailing, 2)
                        
                        // Колонки недель
                        ForEach(0..<weeksGrid.count, id: \.self) { colIndex in
                            let column = weeksGrid[colIndex]
                            VStack(spacing: 5) {
                                ForEach(0..<7, id: \.self) { rowIndex in
                                    if let day = column[rowIndex] {
                                        HeatmapTileView(
                                            day: day,
                                            isSelected: selectedDay?.id == day.id,
                                            onTap: {
                                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                                    if selectedDay?.id == day.id {
                                                        selectedDay = nil
                                                    } else {
                                                        selectedDay = day
                                                    }
                                                }
                                                HapticManager.shared.impact(.light)
                                            }
                                        )
                                        .id(day.id)
                                    } else {
                                        // Пустая заглушка до начала месяца / недели
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.clear)
                                            .frame(width: 14, height: 14)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 2)
                }
                .onAppear {
                    // Автоскролл к последнему (сегодняшнему) дню при открытии
                    if let lastDay = heatmapDays.last {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            proxy.scrollTo(lastDay.id, anchor: .trailing)
                        }
                    }
                }
            }
            
            // 3. Легенда цветовых уровней
            HStack(spacing: 8) {
                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(red: 56/255, green: 189/255, blue: 248/255))
                        .frame(width: 8, height: 8)
                    Text("🧊 Защита")
                        .font(.system(size: 9))
                        .foregroundColor(Theme.textSecondary)
                }
                
                Spacer()
                
                HStack(spacing: 3) {
                    Text("Меньше")
                        .font(.system(size: 9))
                        .foregroundColor(Theme.textSecondary)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 8, height: 8)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.3))
                        .frame(width: 8, height: 8)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.6))
                        .frame(width: 8, height: 8)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(red: 16/255, green: 185/255, blue: 129/255))
                        .frame(width: 8, height: 8)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 16/255, green: 185/255, blue: 129/255), Color(red: 0/255, green: 229/255, blue: 255/255)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 8, height: 8)
                    
                    Text("100% ⚡")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                }
            }
            .padding(.top, 2)
            
            // 4. Интерактивная плашка выбранного дня (при тапе)
            if let day = selectedDay {
                DayDetailBanner(day: day)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // 5. Нижняя аналитическая сводка
            HStack(spacing: 8) {
                HeatmapSummaryStat(
                    title: "Идеальных",
                    value: "\(perfectDaysCount)",
                    icon: "sparkles",
                    color: Color(red: 16/255, green: 185/255, blue: 129/255)
                )
                
                HeatmapSummaryStat(
                    title: "Щитов стрика",
                    value: "\(frozenDaysCount)",
                    icon: "shield.fill",
                    color: Color(red: 56/255, green: 189/255, blue: 248/255)
                )
                
                HeatmapSummaryStat(
                    title: "Стабильность",
                    value: "\(consistencyRatePercent)%",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .orange
                )
            }
        }
        .premiumCard()
    }
}

// MARK: - Плитка дня матрицы активности
private struct HeatmapTileView: View {
    let day: HabitHeatmapDay
    let isSelected: Bool
    let onTap: () -> Void
    
    var tileFill: some ShapeStyle {
        switch day.intensityLevel {
        case -1:
            // Ледяной защищенный день 🧊
            return AnyShapeStyle(Color(red: 56/255, green: 189/255, blue: 248/255))
        case 1:
            return AnyShapeStyle(Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.32))
        case 2:
            return AnyShapeStyle(Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.58))
        case 3:
            return AnyShapeStyle(Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.85))
        case 4:
            // 100% Идеальный день: Неоновый дуэт
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color(red: 16/255, green: 185/255, blue: 129/255), Color(red: 0/255, green: 229/255, blue: 255/255)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        default:
            return AnyShapeStyle(Color.primary.opacity(0.08))
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 3.5)
                    .fill(tileFill)
                    .frame(width: 14, height: 14)
                
                if day.isFrozen {
                    Image(systemName: "snowflake")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(.white)
                } else if day.isPerfectDay {
                    Circle()
                        .fill(Color.white.opacity(0.35))
                        .frame(width: 3.5, height: 3.5)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 3.5)
                    .stroke(isSelected ? Color.white : Color.clear, lineWidth: 1.5)
                    .shadow(color: isSelected ? Color.white.opacity(0.8) : Color.clear, radius: 3)
            )
        }
        .buttonStyle(AppleDesignAwardsButtonStyle(scaleAmount: 0.9))
    }
}

// MARK: - Интерактивная плашка с деталями выбранного дня
private struct DayDetailBanner: View {
    let day: HabitHeatmapDay
    @ObservedObject var habitsManager = HabitsManager.shared
    
    private var formattedDateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: day.date).capitalized
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if day.isFrozen {
                    Image(systemName: "snowflake")
                        .foregroundColor(Color(red: 56/255, green: 189/255, blue: 248/255))
                        .font(.system(size: 13, weight: .bold))
                    Text("\(formattedDateString) • Заморожен щитом 🧊")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(red: 56/255, green: 189/255, blue: 248/255))
                } else if day.isPerfectDay {
                    Image(systemName: "sparkles")
                        .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                        .font(.system(size: 13, weight: .bold))
                    Text("\(formattedDateString) • Идеальный день ⚡ (100%)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                } else {
                    Image(systemName: "calendar")
                        .foregroundColor(Theme.textSecondary)
                        .font(.system(size: 13))
                    Text("\(formattedDateString) • \(day.completedCount) из \(day.totalCount) выполнено (\(Int(day.fraction * 100))%)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                }
                
                Spacer()
            }
            
            // Список привычек за этот день
            VStack(spacing: 4) {
                ForEach(habitsManager.habits) { habit in
                    let isDone = habit.isCompleted(on: day.dateKey)
                    let isFrozen = habit.isFrozen(on: day.dateKey)
                    
                    HStack(spacing: 6) {
                        Image(systemName: habit.icon)
                            .font(.system(size: 10))
                            .foregroundColor(habit.color)
                            .frame(width: 16)
                        
                        Text(habit.title)
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textPrimary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if isFrozen {
                            Text("🧊 Стрик защищен")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color(red: 56/255, green: 189/255, blue: 248/255))
                        } else if isDone {
                            Text("Выполнено ✅")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                        } else {
                            Text("Пропущено ⭕")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.textSecondary.opacity(0.7))
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(10)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - Карточка сводной статистики под Heatmap
private struct HeatmapSummaryStat: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
            }
            Text(value)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(10)
    }
}
