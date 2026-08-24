import SwiftUI
import Charts

// MARK: - Периоды отображения графика веса
public enum WeightTimeRange: String, CaseIterable, Identifiable {
    case week = "7Д"
    case month = "30Д"
    case threeMonths = "3М"
    case year = "1Г"
    case all = "Все"
    
    public var id: String { self.rawValue }
    
    public var days: Int? {
        switch self {
        case .week: return 7
        case .month: return 30
        case .threeMonths: return 90
        case .year: return 365
        case .all: return nil
        }
    }
}

// MARK: - 0. КАРТОЧКА ЭНЕРГЕТИЧЕСКОГО БАЛАНСА И ДЕФИЦИТА КАЛОРИЙ
public struct DailyEnergyBalanceCardView: View {
    public let caloriesConsumed: Double
    public let protein: Double
    public let fat: Double
    public let carbs: Double
    public let activeCaloriesBurned: Double
    public let userWeight: Double
    public let userHeight: Int
    public let userAge: Int
    public let userGender: String
    
    @ObservedObject private var coachManager = AICoachManager.shared
    
    public init(
        caloriesConsumed: Double,
        protein: Double,
        fat: Double,
        carbs: Double,
        activeCaloriesBurned: Double,
        userWeight: Double,
        userHeight: Int,
        userAge: Int,
        userGender: String
    ) {
        self.caloriesConsumed = caloriesConsumed
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
        self.activeCaloriesBurned = activeCaloriesBurned
        self.userWeight = userWeight
        self.userHeight = userHeight
        self.userAge = userAge
        self.userGender = userGender
    }
    
    // Базовый метаболизм (BMR) по формуле Миффлина-Сан Жеора
    private var bmrCalories: Double {
        let w = max(30.0, userWeight)
        let h = Double(max(100, userHeight))
        let a = Double(max(14, userAge))
        let isMale = userGender.lowercased().contains("муж") || userGender.lowercased() == "male"
        
        if isMale {
            return (10.0 * w) + (6.25 * h) - (5.0 * a) + 5.0
        } else {
            return (10.0 * w) + (6.25 * h) - (5.0 * a) - 161.0
        }
    }
    
    private var totalCaloriesBurned: Double {
        bmrCalories + activeCaloriesBurned
    }
    
    // Разница: Съедено - Сожжено
    private var energyBalance: Double {
        caloriesConsumed - totalCaloriesBurned
    }
    
    // Оценка изменения жировой массы (7700 ккал = 1 кг жира)
    private var estimatedFatChangeGrams: Double {
        (energyBalance / 7700.0) * 1000.0
    }
    
    private var status: (title: String, color: Color, badge: String, icon: String) {
        if energyBalance < -150 {
            return ("Дефицит калорий", .green, "\(Int(energyBalance)) ккал", "flame.fill")
        } else if energyBalance > 150 {
            return ("Профицит калорий", .orange, "+\(Int(energyBalance)) ккал", "bolt.fill")
        } else {
            return ("Энергобаланс", Theme.standColor, "\(Int(energyBalance)) ккал", "equal.circle.fill")
        }
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Заголовок и текущий статус
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: status.icon)
                        .foregroundColor(status.color)
                    Text("Энергетический баланс сегодня")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text(status.title)
                    Text(status.badge)
                        .bold()
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(status.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(status.color.opacity(0.12))
                .cornerRadius(10)
            }
            
            // Две основные колонки: Поступило vs Сожжено
            HStack(spacing: 12) {
                // Поступило (Еда)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "fork.knife")
                            .font(.caption2)
                            .foregroundColor(Color.green)
                        Text("Поступило")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                    
                    Text("\(Int(caloriesConsumed)) ккал")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                    
                    HStack(spacing: 6) {
                        Text("Б:\(Int(protein))г").foregroundColor(.green)
                        Text("Ж:\(Int(fat))г").foregroundColor(.orange)
                        Text("У:\(Int(carbs))г").foregroundColor(.blue)
                    }
                    .font(.system(size: 9, weight: .bold))
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.04))
                .cornerRadius(14)
                
                // Сожжено (BMR + Активность)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                            .foregroundColor(Theme.moveColor)
                        Text("Сожжено всего")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                    
                    Text("\(Int(totalCaloriesBurned)) ккал")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                    
                    Text("Базовый: \(Int(bmrCalories)) • Актив: \(Int(activeCaloriesBurned))")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.04))
                .cornerRadius(14)
            }
            
            // Визуальная шкала баланса
            VStack(spacing: 4) {
                GeometryReader { geo in
                    let width = geo.size.width
                    // Диапазон от -1000 ккал (слева) до +1000 ккал (справа)
                    let normalized = min(max((energyBalance + 1000.0) / 2000.0, 0.0), 1.0)
                    let pointerX = normalized * width
                    
                    ZStack(alignment: .leading) {
                        HStack(spacing: 2) {
                            // Зона дефицита (зеленая)
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.green, Theme.standColor],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: width * 0.5)
                            
                            // Зона профицита (оранжевая / красная)
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.orange, Color.red],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: width * 0.5)
                        }
                        .frame(height: 8)
                        .clipShape(Capsule())
                        
                        // Центр (0 ккал)
                        Rectangle()
                            .fill(Color.white.opacity(0.5))
                            .frame(width: 2, height: 12)
                            .offset(x: width * 0.5 - 1)
                        
                        // Указатель текущего баланса
                        Circle()
                            .fill(Color.white)
                            .frame(width: 14, height: 14)
                            .shadow(color: Color.black.opacity(0.4), radius: 3)
                            .offset(x: max(0, min(pointerX - 7, width - 14)))
                    }
                }
                .frame(height: 14)
                
                HStack {
                    Text("🔥 Сжигание жира (-1000)")
                    Spacer()
                    Text("0 (Баланс)")
                    Spacer()
                    Text("⚡ Набор (+1000)")
                }
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
            }
            
            Divider()
                .background(Color.white.opacity(0.08))
            
            // Физиологический вердикт
            HStack(spacing: 8) {
                if energyBalance < -150 {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    Text("Прогноз за день: **Сжигание ~\(Int(abs(estimatedFatChangeGrams))) г** жировой ткани.")
                        .font(.caption)
                        .foregroundColor(Theme.textPrimary)
                } else if energyBalance > 150 {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(.orange)
                    Text("Прогноз за день: Профицит **+\(Int(estimatedFatChangeGrams)) г** (запас энергии / рост мышц).")
                        .font(.caption)
                        .foregroundColor(Theme.textPrimary)
                } else {
                    Image(systemName: "equal.circle.fill")
                        .foregroundColor(Theme.standColor)
                    Text("Прогноз за день: Вес стабилен (расход равен потреблению).")
                        .font(.caption)
                        .foregroundColor(Theme.textPrimary)
                }
            }
        }
        .premiumCard()
    }
}

// MARK: - 1. КАРТОЧКА ПРОГРЕССА К ЦЕЛЕВОМУ ВЕСУ
public struct WeightGoalProgressCardView: View {
    public let currentWeight: Double
    public let targetWeight: Double
    public let startWeight: Double
    public let weightHistory: [WeightRecord]
    public var onOpenLog: () -> Void
    
    @ObservedObject private var coachManager = AICoachManager.shared
    
    public init(
        currentWeight: Double,
        targetWeight: Double,
        startWeight: Double,
        weightHistory: [WeightRecord],
        onOpenLog: @escaping () -> Void
    ) {
        self.currentWeight = currentWeight
        self.targetWeight = targetWeight
        self.startWeight = startWeight
        self.weightHistory = weightHistory
        self.onOpenLog = onOpenLog
    }
    
    private var isLosingGoal: Bool {
        targetWeight <= startWeight
    }
    
    private var progress: Double {
        guard startWeight != targetWeight, currentWeight > 0 else { return 1.0 }
        let totalToChange = abs(targetWeight - startWeight)
        guard totalToChange > 0 else { return 1.0 }
        
        let changed = isLosingGoal ? (startWeight - currentWeight) : (currentWeight - startWeight)
        return min(max(changed / totalToChange, 0.0), 1.0)
    }
    
    private var remainingKg: Double {
        abs(currentWeight - targetWeight)
    }
    
    private var weeklyChangeRate: Double {
        guard weightHistory.count >= 2 else { return 0.0 }
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let recent = weightHistory.filter { $0.date >= weekAgo }
        
        if let first = recent.first, let last = recent.last, first.id != last.id {
            return last.weight - first.weight
        }
        return 0.0
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Верхняя плашка: Текущий вес и кнопка добавления
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Текущий вес")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(currentWeight > 0 ? String(format: "%.1f", currentWeight) : "--")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                        
                        Text("кг")
                            .font(.headline)
                            .foregroundColor(Theme.textSecondary)
                        
                        if weeklyChangeRate != 0 {
                            HStack(spacing: 3) {
                                Image(systemName: weeklyChangeRate < 0 ? "arrow.down.right" : "arrow.up.right")
                                Text(String(format: "%@%.1f кг/нед", weeklyChangeRate > 0 ? "+" : "", weeklyChangeRate))
                            }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(isLosingGoal ? (weeklyChangeRate < 0 ? .green : .orange) : (weeklyChangeRate > 0 ? .green : .orange))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(10)
                        }
                    }
                }
                
                Spacer()
                
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onOpenLog()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("Внести вес")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(coachManager.currentCoach.accentColor)
                    .cornerRadius(14)
                    .shadow(color: coachManager.currentCoach.accentColor.opacity(0.3), radius: 6)
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.08))
            
            // Шкала прогресса до целевого веса
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "flag.checkered")
                            .foregroundColor(coachManager.currentCoach.accentColor)
                        Text("Цель: \(String(format: "%.1f кг", targetWeight))")
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(Theme.textPrimary)
                    }
                    
                    Spacer()
                    
                    Text("\(Int(progress * 100))% достигнуто")
                        .font(.caption)
                        .bold()
                        .foregroundColor(coachManager.currentCoach.accentColor)
                }
                
                // Прогресс бар
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 10)
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Theme.standColor, coachManager.currentCoach.accentColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(10, geo.size.width * CGFloat(progress)), height: 10)
                    }
                }
                .frame(height: 10)
                
                HStack {
                    Text("Старт: \(String(format: "%.1f кг", startWeight > 0 ? startWeight : currentWeight))")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                    
                    Spacer()
                    
                    if remainingKg > 0.05 {
                        Text("Осталось: \(String(format: "%.1f кг", remainingKg))")
                            .font(.caption2)
                            .bold()
                            .foregroundColor(Theme.textPrimary)
                    } else {
                        Text("🎉 Цель достигнута!")
                            .font(.caption2)
                            .bold()
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .premiumCard()
    }
}

// MARK: - 2. ИНТЕРАКТИВНЫЙ ГРАФИК ДИНАМИКИ ВЕСА (CHARTS)
public struct WeightDynamicsChartView: View {
    public let weightHistory: [WeightRecord]
    public let targetWeight: Double
    
    @State private var selectedRange: WeightTimeRange = .month
    @State private var selectedDate: Date? = nil
    @State private var selectedWeight: Double? = nil
    
    @ObservedObject private var coachManager = AICoachManager.shared
    
    public init(weightHistory: [WeightRecord], targetWeight: Double) {
        self.weightHistory = weightHistory
        self.targetWeight = targetWeight
    }
    
    private var filteredRecords: [WeightRecord] {
        let sorted = weightHistory.sorted(by: { $0.date < $1.date })
        guard let days = selectedRange.days else { return sorted }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let filtered = sorted.filter { $0.date >= cutoff }
        return filtered.isEmpty ? sorted.suffix(10) : filtered
    }
    
    private var minWeight: Double {
        let minHist = filteredRecords.map { $0.weight }.min() ?? 60.0
        let target = targetWeight > 0 ? targetWeight : minHist
        return max(30.0, min(minHist, target) - 2.0)
    }
    
    private var maxWeight: Double {
        let maxHist = filteredRecords.map { $0.weight }.max() ?? 90.0
        let target = targetWeight > 0 ? targetWeight : maxHist
        return max(maxHist, target) + 2.0
    }
    
    private var periodDifference: (delta: Double, percent: Double)? {
        guard let first = filteredRecords.first, let last = filteredRecords.last, first.id != last.id else { return nil }
        let delta = last.weight - first.weight
        let pct = first.weight > 0 ? (delta / first.weight) * 100.0 : 0.0
        return (delta, pct)
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Заголовок и селектор периода
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Динамика веса")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                    
                    if let diff = periodDifference {
                        HStack(spacing: 4) {
                            Image(systemName: diff.delta < 0 ? "arrow.down.right" : "arrow.up.right")
                            Text(String(format: "%@%.1f кг (%.1f%%)", diff.delta > 0 ? "+" : "", diff.delta, diff.percent))
                        }
                        .font(.caption2)
                        .bold()
                        .foregroundColor(diff.delta < 0 ? .green : (diff.delta > 0 ? .orange : Theme.textSecondary))
                    }
                }
                
                Spacer()
                
                // Переключатель диапазонов
                Picker("", selection: $selectedRange) {
                    ForEach(WeightTimeRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 200)
            }
            
            // Интерактивная плашка выбранной точки
            if let date = selectedDate, let weight = selectedWeight {
                HStack {
                    Text(formatDate(date))
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Text(String(format: "%.1f кг", weight))
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(coachManager.currentCoach.accentColor)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.06))
                .cornerRadius(10)
            }
            
            // Сам График
            if filteredRecords.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.largeTitle)
                        .foregroundColor(Theme.textSecondary.opacity(0.5))
                    Text("Недостаточно данных для графика")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
            } else {
                Chart {
                    // 1. Линия целевого веса
                    if targetWeight > 0 {
                        RuleMark(y: .value("Цель", targetWeight))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                            .foregroundStyle(coachManager.currentCoach.accentColor.opacity(0.7))
                            .annotation(position: .top, alignment: .trailing) {
                                Text("Цель \(String(format: "%.1f", targetWeight)) кг")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(coachManager.currentCoach.accentColor)
                                    .padding(3)
                                    .background(Theme.cardBackground.opacity(0.8))
                                    .cornerRadius(4)
                            }
                    }
                    
                    // 2. Градиентная область под графиком
                    ForEach(filteredRecords) { record in
                        AreaMark(
                            x: .value("Дата", record.date),
                            y: .value("Вес", record.weight)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [coachManager.currentCoach.accentColor.opacity(0.35), coachManager.currentCoach.accentColor.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                    
                    // 3. Основная плавная линия
                    ForEach(filteredRecords) { record in
                        LineMark(
                            x: .value("Дата", record.date),
                            y: .value("Вес", record.weight)
                        )
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 3))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Theme.standColor, coachManager.currentCoach.accentColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        
                        PointMark(
                            x: .value("Дата", record.date),
                            y: .value("Вес", record.weight)
                        )
                        .symbolSize(CGSize(width: 7, height: 7))
                        .foregroundStyle(Color.white)
                    }
                }
                .chartYScale(domain: minWeight...maxWeight)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                            .foregroundStyle(Color.white.opacity(0.08))
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                            .foregroundStyle(Theme.textSecondary)
                            .font(.system(size: 10))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                            .foregroundStyle(Color.white.opacity(0.08))
                        AxisValueLabel()
                            .foregroundStyle(Theme.textSecondary)
                            .font(.system(size: 10))
                    }
                }
                .frame(height: 190)
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let location = value.location
                                        if let date: Date = proxy.value(atX: location.x) {
                                            // Находим ближайший замер
                                            if let closest = filteredRecords.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }) {
                                                selectedDate = closest.date
                                                selectedWeight = closest.weight
                                            }
                                        }
                                    }
                                    .onEnded { _ in
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                            selectedDate = nil
                                            selectedWeight = nil
                                        }
                                    }
                            )
                    }
                }
            }
        }
        .premiumCard()
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM, HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - 3. КАЛЬКУЛЯТОР И ШКАЛА ИМТ (BMI)
public struct BMICalculatorCardView: View {
    public let currentWeight: Double
    public let heightCm: Int
    
    public init(currentWeight: Double, heightCm: Int) {
        self.currentWeight = currentWeight
        self.heightCm = heightCm
    }
    
    private var bmi: Double {
        guard heightCm > 50, currentWeight > 20 else { return 0.0 }
        let hMeters = Double(heightCm) / 100.0
        return currentWeight / (hMeters * hMeters)
    }
    
    private var category: (title: String, color: Color, desc: String) {
        switch bmi {
        case ..<18.5:
            return ("Дефицит веса", Color.blue, "Рекомендуется постепенный набор мышечной массы.")
        case 18.5..<25.0:
            return ("Норма", Color.green, "Идеальный здоровый диапазон массы тела.")
        case 25.0..<30.0:
            return ("Избыточный вес", Color.orange, "Небольшой профицит массы, легко корректируется.")
        default:
            return ("Высокий ИМТ", Color.red, "Рекомендуется мягкий дефицит калорий и активность.")
        }
    }
    
    private var healthyWeightRange: (min: Double, max: Double) {
        let hMeters = Double(max(100, heightCm)) / 100.0
        let minW = 18.5 * hMeters * hMeters
        let maxW = 24.9 * hMeters * hMeters
        return (minW, maxW)
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "figure.arms.open")
                        .foregroundColor(category.color)
                    Text("Индекс массы тела (ИМТ)")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                }
                
                Spacer()
                
                Text(category.title)
                    .font(.caption)
                    .bold()
                    .foregroundColor(category.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(category.color.opacity(0.12))
                    .cornerRadius(10)
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(bmi > 0 ? String(format: "%.1f", bmi) : "--")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                
                Text("кг/м²")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                
                Spacer()
                
                Text("Рост: \(heightCm) см")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            
            // Сегментированная цветная шкала ИМТ
            VStack(spacing: 4) {
                GeometryReader { geo in
                    let width = geo.size.width
                    let needlePosition = min(max((bmi - 15.0) / (35.0 - 15.0), 0.0), 1.0) * width
                    
                    ZStack(alignment: .leading) {
                        HStack(spacing: 3) {
                            Rectangle().fill(Color.blue).frame(width: width * 0.18)
                            Rectangle().fill(Color.green).frame(width: width * 0.32)
                            Rectangle().fill(Color.orange).frame(width: width * 0.25)
                            Rectangle().fill(Color.red).frame(width: width * 0.25)
                        }
                        .frame(height: 8)
                        .clipShape(Capsule())
                        
                        // Стрелка / Указатель текущего ИМТ
                        Circle()
                            .fill(Color.white)
                            .frame(width: 14, height: 14)
                            .shadow(color: Color.black.opacity(0.4), radius: 2)
                            .offset(x: max(0, min(needlePosition - 7, width - 14)))
                    }
                }
                .frame(height: 14)
                
                HStack {
                    Text("< 18.5")
                    Spacer()
                    Text("18.5 – 24.9")
                    Spacer()
                    Text("25 – 29.9")
                    Spacer()
                    Text("> 30")
                }
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
            }
            
            Divider()
                .background(Color.white.opacity(0.08))
            
            HStack {
                Text("Здоровый вес для вашего роста:")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Text(String(format: "%.1f – %.1f кг", healthyWeightRange.min, healthyWeightRange.max))
                    .font(.caption)
                    .bold()
                    .foregroundColor(.green)
            }
        }
        .premiumCard()
    }
}

// MARK: - 4. ВИДЖЕТ РАЗБОРА И ПРОГНОЗА ОТ ИИ-ТРЕНЕРА
public struct AICoachWeightForecastCardView: View {
    public let weightHistory: [WeightRecord]
    public let targetWeight: Double
    public let userHeight: Int
    public var onAskCoach: () -> Void
    
    @ObservedObject private var coachManager = AICoachManager.shared
    
    public init(weightHistory: [WeightRecord], targetWeight: Double, userHeight: Int, onAskCoach: @escaping () -> Void) {
        self.weightHistory = weightHistory
        self.targetWeight = targetWeight
        self.userHeight = userHeight
        self.onAskCoach = onAskCoach
    }
    
    private var coach: AICoachPersona {
        coachManager.currentCoach
    }
    
    private var estimatedDaysToGoal: Int? {
        guard weightHistory.count >= 2, let last = weightHistory.last, let first = weightHistory.first else { return nil }
        let totalDays = max(1, Calendar.current.dateComponents([.day], from: first.date, to: last.date).day ?? 1)
        let totalKgChanged = abs(last.weight - first.weight)
        guard totalKgChanged > 0.1 else { return nil }
        
        let kgPerDay = totalKgChanged / Double(totalDays)
        let remainingKg = abs(last.weight - targetWeight)
        guard kgPerDay > 0.005 else { return nil }
        
        return Int(remainingKg / kgPerDay)
    }
    
    private func formattedTargetDate(days: Int) -> String {
        let calendar = Calendar.current
        let targetDate = calendar.date(byAdding: .day, value: days, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: targetDate)
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                AITrainerAvatarView(coachState: .idle, size: 44, customCoach: coach)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Совет тренера \(coach.name)")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                    
                    Text("\(coach.badgeEmoji) \(coach.tagline)")
                        .font(.caption2)
                        .foregroundColor(coach.accentColor)
                }
                
                Spacer()
            }
            
            if let days = estimatedDaysToGoal, days > 0, days < 365 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("🎯 Прогноз достижения цели:")
                        .font(.caption)
                        .bold()
                        .foregroundColor(coach.accentColor)
                    
                    Text("При текущей динамике вы достигнете целевого веса **\(String(format: "%.1f", targetWeight)) кг** примерно **\(formattedTargetDate(days: days))** (через ~\(days) дн.).")
                        .font(.subheadline)
                        .foregroundColor(Theme.textPrimary)
                        .lineSpacing(3)
                }
                .padding(12)
                .background(coach.accentColor.opacity(0.1))
                .cornerRadius(14)
            } else {
                Text("Регулярно взвешивайтесь по утрам натощак после стакана воды. Я помогу отслеживать чистую динамику без учета суточных колебаний воды.")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                    .lineSpacing(3)
            }
            
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onAskCoach()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                    Text("Обсудить динамику с тренером")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [coach.accentColor, coach.accentColor.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(14)
                .shadow(color: coach.accentColor.opacity(0.25), radius: 6)
            }
        }
        .premiumCard()
    }
}

// MARK: - 5. СПИСОК ИСТОРИИ ЗАМЕРОВ
public struct WeightLogHistorySection: View {
    public let weightHistory: [WeightRecord]
    public var onDelete: (UUID) -> Void
    
    public init(weightHistory: [WeightRecord], onDelete: @escaping (UUID) -> Void) {
        self.weightHistory = weightHistory
        self.onDelete = onDelete
    }
    
    private var reversedHistory: [WeightRecord] {
        weightHistory.sorted(by: { $0.date > $1.date })
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("История взвешиваний")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Text("\(weightHistory.count) зам.")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            
            if weightHistory.isEmpty {
                Text("История замеров пуста. Добавьте первый замер веса.")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(reversedHistory.prefix(8))) { record in
                        let diff = calculateDiff(for: record)
                        
                        HStack(spacing: 12) {
                            // Иконка времени дня
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.06))
                                    .frame(width: 36, height: 36)
                                Image(systemName: iconForTimeOfDay(record.timeOfDay))
                                    .font(.system(size: 14))
                                    .foregroundColor(Theme.textSecondary)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(formatDate(record.date))
                                        .font(.subheadline)
                                        .bold()
                                        .foregroundColor(Theme.textPrimary)
                                    
                                    if let tod = record.timeOfDay {
                                        Text(tod)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(Theme.textSecondary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.white.opacity(0.05))
                                            .cornerRadius(6)
                                    }
                                }
                                
                                if let note = record.note, !note.isEmpty {
                                    Text(note)
                                        .font(.caption2)
                                        .foregroundColor(Theme.textSecondary)
                                        .lineLimit(1)
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(String(format: "%.1f кг", record.weight))
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                                
                                if let d = diff {
                                    HStack(spacing: 2) {
                                        Image(systemName: d < 0 ? "arrow.down" : "arrow.up")
                                        Text(String(format: "%@%.1f кг", d > 0 ? "+" : "", d))
                                    }
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(d < 0 ? .green : (d > 0 ? .orange : Theme.textSecondary))
                                }
                            }
                            
                            // Кнопка удаления
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                onDelete(record.id)
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.textSecondary.opacity(0.6))
                                    .padding(6)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.white.opacity(0.03))
                        .cornerRadius(14)
                    }
                }
            }
        }
        .premiumCard()
    }
    
    private func calculateDiff(for record: WeightRecord) -> Double? {
        let sorted = weightHistory.sorted(by: { $0.date < $1.date })
        guard let idx = sorted.firstIndex(where: { $0.id == record.id }), idx > 0 else { return nil }
        return record.weight - sorted[idx - 1].weight
    }
    
    private func iconForTimeOfDay(_ timeOfDay: String?) -> String {
        switch timeOfDay {
        case "Утро натощак": return "sun.and.horizon.fill"
        case "День": return "sun.max.fill"
        case "Вечер": return "moon.stars.fill"
        default: return "scalemass.fill"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Сегодня"
        } else if calendar.isDateInYesterday(date) {
            return "Вчера"
        } else {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ru_RU")
            formatter.dateFormat = "d MMMM"
            return formatter.string(from: date)
        }
    }
}

// MARK: - 6. МОДАЛЬНЫЙ ЭКРАН ВНЕСЕНИЯ ЗАМЕРА (WEIGHT LOG SHEET)
public struct WeightLogSheetView: View {
    @Environment(\.dismiss) private var dismiss
    public let initialWeight: Double
    public let onSave: (Double, Date, String, String) -> Void
    
    @State private var weightValue: Double
    @State private var selectedDate = Date()
    @State private var selectedTimeOfDay = "Утро натощак"
    @State private var noteText = ""
    
    private let timeOfDayOptions = ["Утро натощак", "День", "Вечер", "После тренировки"]
    
    @ObservedObject private var coachManager = AICoachManager.shared
    
    public init(initialWeight: Double, onSave: @escaping (Double, Date, String, String) -> Void) {
        self.initialWeight = initialWeight
        self.onSave = onSave
        _weightValue = State(initialValue: initialWeight > 30 ? initialWeight : 75.0)
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Большой цифровой дисплей
                        VStack(spacing: 8) {
                            Text("Текущее значение")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                            
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(String(format: "%.1f", weightValue))
                                    .font(.system(size: 56, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                                Text("кг")
                                    .font(.title2)
                                    .bold()
                                    .foregroundColor(coachManager.currentCoach.accentColor)
                            }
                            
                            // Степперы и кнопки быстрой корректировки
                            HStack(spacing: 12) {
                                adjustButton(delta: -1.0, title: "-1.0")
                                adjustButton(delta: -0.1, title: "-0.1")
                                adjustButton(delta: 0.1, title: "+0.1")
                                adjustButton(delta: 1.0, title: "+1.0")
                            }
                            .padding(.top, 4)
                        }
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .background(Theme.cardBackground)
                        .cornerRadius(20)
                        
                        // Слайдер плавной настройки
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Ползунок веса:")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                                Spacer()
                                Text("30 – 180 кг")
                                    .font(.caption2)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            
                            Slider(value: $weightValue, in: 30.0...180.0, step: 0.1)
                                .tint(coachManager.currentCoach.accentColor)
                                .onChange(of: weightValue) { _, _ in
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                        }
                        .padding()
                        .background(Theme.cardBackground)
                        .cornerRadius(16)
                        
                        // Чипы времени суток
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Время замера")
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(Theme.textPrimary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(timeOfDayOptions, id: \.self) { tod in
                                        Button(action: {
                                            selectedTimeOfDay = tod
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        }) {
                                            Text(tod)
                                                .font(.caption)
                                                .bold()
                                                .foregroundColor(selectedTimeOfDay == tod ? .white : Theme.textPrimary)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 8)
                                                .background(selectedTimeOfDay == tod ? coachManager.currentCoach.accentColor : Color.white.opacity(0.06))
                                                .cornerRadius(14)
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Theme.cardBackground)
                        .cornerRadius(16)
                        
                        // Дата замера
                        VStack(alignment: .leading, spacing: 8) {
                            DatePicker("Дата и время", selection: $selectedDate, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                                .font(.subheadline)
                                .foregroundColor(Theme.textPrimary)
                        }
                        .padding()
                        .background(Theme.cardBackground)
                        .cornerRadius(16)
                        
                        // Заметка
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Заметка к замеру")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                            TextField("Например: После утренней пробежки", text: $noteText)
                                .font(.subheadline)
                                .foregroundColor(Theme.textPrimary)
                        }
                        .padding()
                        .background(Theme.cardBackground)
                        .cornerRadius(16)
                        
                        // Кнопка сохранения
                        Button(action: {
                            onSave(weightValue, selectedDate, selectedTimeOfDay, noteText)
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            dismiss()
                        }) {
                            Text("Сохранить замер")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(coachManager.currentCoach.accentColor)
                                .cornerRadius(16)
                                .shadow(color: coachManager.currentCoach.accentColor.opacity(0.3), radius: 8)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Внести вес")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
    
    private func adjustButton(delta: Double, title: String) -> some View {
        Button(action: {
            weightValue = max(30.0, min(200.0, weightValue + delta))
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Theme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.08))
                .cornerRadius(10)
        }
    }
}
