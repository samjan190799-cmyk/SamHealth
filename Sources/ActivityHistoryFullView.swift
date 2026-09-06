import SwiftUI

public struct ActivityHistoryFullView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var health: HealthKitManager
    @EnvironmentObject var stepManager: BackgroundStepManager
    
    @AppStorage("app_language") private var appLanguage = "ru"
    @State private var selectedTimeRange = 0 // 0: 7 дней, 1: 30 дней
    @State private var selectedDay: DailyActivitySummary? = nil
    @State private var isAnalyzingTrends = false
    @State private var aiTrendAnalysis: String? = nil
    @State private var showingAITrendsModal = false
    
    private func tr(_ key: String) -> String {
        LocalizationManager.tr(key, lang: appLanguage)
    }
    
    // Сформированный список дней для выбранного диапазона
    private var daysList: [DailyActivitySummary] {
        let count = selectedTimeRange == 0 ? 7 : 30
        var list: [DailyActivitySummary] = []
        let calendar = Calendar.current
        let today = Date()
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        
        for i in 0..<count {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                let key = formatter.string(from: date)
                if calendar.isDateInToday(date) {
                    let activeCal = health.activeEnergyBurned > 0 ? health.activeEnergyBurned : (health.calculatedStepCalories > 0 ? health.calculatedStepCalories : Double(health.stepsToday) * 0.04)
                    let steps = max(health.stepsToday, stepManager.stepsToday)
                    let dist = max(health.distanceMetersToday, stepManager.distanceMeters)
                    list.append(DailyActivitySummary(dateKey: key, date: date, steps: steps, distanceMeters: dist, activeCalories: activeCal))
                } else if let summary = health.dailyActivityHistory[key] {
                    list.append(summary)
                } else {
                    // Генерируем запись из истории тренировок или шагов HealthKit
                    let steps = health.stepsForDate(date)
                    let dist = Double(steps) * 0.75
                    let cal = Double(steps) * 0.04
                    list.append(DailyActivitySummary(dateKey: key, date: date, steps: steps, distanceMeters: dist, activeCalories: cal))
                }
            }
        }
        return list
    }
    
    // Статистика за период
    private var totalSteps: Int {
        daysList.reduce(0) { $0 + $1.steps }
    }
    private var avgDailySteps: Int {
        daysList.isEmpty ? 0 : totalSteps / daysList.count
    }
    private var totalCalories: Double {
        daysList.reduce(0.0) { $0 + $1.activeCalories }
    }
    private var totalDistanceKm: Double {
        daysList.reduce(0.0) { $0 + ($1.distanceMeters / 1000.0) }
    }
    private var maxStepsDay: DailyActivitySummary? {
        daysList.max(by: { $0.steps < $1.steps })
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // ПЕРЕКЛЮЧАТЕЛЬ ДИАПАЗОНА (7 ДНЕЙ / 30 ДНЕЙ)
                        Picker("", selection: $selectedTimeRange) {
                            Text("7 дней").tag(0)
                            Text("30 дней").tag(1)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        // КАРТОЧКА СУММАРНОЙ СТАТИСТИКИ
                        summaryMetricsGrid
                            .padding(.horizontal)
                        
                        // ГРАФИК АКТИВНОСТИ ПО ДНЯМ
                        activityBarChartSection
                            .padding(.horizontal)
                        
                        // КНОПКА ИИ-АНАЛИЗА ТРЕНДОВ
                        aiTrendAnalysisCard
                            .padding(.horizontal)
                        
                        // ПОДРОБНЫЙ СПИСОК ПО ДНЯМ
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Журнал активности по дням")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                                Spacer()
                                Text("\(daysList.count) дн.")
                                    .font(.caption.bold())
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .padding(.horizontal, 4)
                            
                            ForEach(daysList) { day in
                                dayActivityRow(day: day)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("История активности")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Сетка суммарных метрик
    private var summaryMetricsGrid: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                metricCard(
                    icon: "figure.walk",
                    iconColor: Color(red: 0/255, green: 229/255, blue: 255/255),
                    title: "Всего шагов",
                    value: "\(totalSteps.formattedWithSeparator())",
                    subtitle: "Ср: \(avgDailySteps) / день"
                )
                
                metricCard(
                    icon: "flame.fill",
                    iconColor: Color(red: 255/255, green: 69/255, blue: 58/255),
                    title: "Сожжено",
                    value: "\(Int(totalCalories)) ккал",
                    subtitle: "Ср: \(Int(totalCalories / Double(max(1, daysList.count)))) ккал/дн"
                )
            }
            
            HStack(spacing: 12) {
                metricCard(
                    icon: "location.fill",
                    iconColor: Color(red: 50/255, green: 215/255, blue: 75/255),
                    title: "Дистанция",
                    value: String(format: "%.1f км", totalDistanceKm),
                    subtitle: "За выбранный период"
                )
                
                metricCard(
                    icon: "trophy.fill",
                    iconColor: Color.yellow,
                    title: "Лучший день",
                    value: "\(maxStepsDay?.steps ?? 0) ш.",
                    subtitle: formatDateShort(maxStepsDay?.date ?? Date())
                )
            }
        }
    }
    
    private func metricCard(icon: String, iconColor: Color, title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(iconColor)
                }
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textPrimary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.bold())
                    .foregroundColor(Theme.textSecondary)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textSecondary.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.cardBackground)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 3)
    }
    
    // MARK: - Столбчатый график
    private var activityBarChartSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Динамика шагов")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Text("Цель: 10 000")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            
            let maxStepsInList = max(10000, daysList.map { $0.steps }.max() ?? 10000)
            
            HStack(alignment: .bottom, spacing: selectedTimeRange == 0 ? 10 : 4) {
                ForEach(daysList.reversed()) { day in
                    let heightRatio = min(Double(day.steps) / Double(maxStepsInList), 1.0)
                    let isToday = Calendar.current.isDateInToday(day.date)
                    let isGoalReached = day.steps >= 10000
                    
                    VStack(spacing: 6) {
                        ZStack(alignment: .bottom) {
                            Capsule()
                                .fill(Color.primary.opacity(0.06))
                                .frame(height: 120)
                            
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: isGoalReached
                                            ? [Color(red: 50/255, green: 215/255, blue: 75/255), Color(red: 0/255, green: 229/255, blue: 255/255)]
                                            : [Color(red: 255/255, green: 149/255, blue: 0/255), Color(red: 255/255, green: 69/255, blue: 58/255)],
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                                )
                                .frame(height: max(8, 120 * CGFloat(heightRatio)))
                        }
                        
                        if selectedTimeRange == 0 {
                            Text(getDayOfWeekShort(day.date))
                                .font(.system(size: 10, weight: isToday ? .heavy : .regular))
                                .foregroundColor(isToday ? Theme.exerciseColor : Theme.textSecondary)
                        } else {
                            Text(getDayNumber(day.date))
                                .font(.system(size: 8))
                                .foregroundColor(isToday ? Theme.exerciseColor : Theme.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 150)
        }
        .padding(16)
        .background(Theme.cardBackground)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 3)
    }
    
    // MARK: - Карточка ИИ-анализа трендов
    private var aiTrendAnalysisCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                AITrainerAvatarView(coachState: isAnalyzingTrends ? .exercising : .idle, size: 36)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("ИИ-Анализ трендов и формы")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    Text("Анализ выносливости и прогрессии нагрузок")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                }
                
                Spacer()
            }
            
            if let analysis = aiTrendAnalysis {
                Text(analysis)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Theme.textPrimary)
                    .lineSpacing(4)
                    .padding(12)
                    .background(Color.primary.opacity(0.03))
                    .cornerRadius(12)
            }
            
            Button(action: {
                generateAITrends()
            }) {
                HStack(spacing: 6) {
                    if isAnalyzingTrends {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(aiTrendAnalysis == nil ? "Оценить динамику недели" : "Обновить анализ")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Theme.exerciseColor)
                .cornerRadius(12)
            }
            .disabled(isAnalyzingTrends)
        }
        .padding(16)
        .background(Theme.cardBackground)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 3)
    }
    
    private func generateAITrends() {
        isAnalyzingTrends = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        let stepsAvg = avgDailySteps
        let totalCal = totalCalories
        let distance = totalDistanceKm
        let bestDaySteps = maxStepsDay?.steps ?? 0
        let daysCount = daysList.count
        
        Task {
            do {
                let res = try await GeminiScanService.shared.analyzeActivityTrends(
                    daysCount: daysCount,
                    totalSteps: totalSteps,
                    avgDailySteps: stepsAvg,
                    totalCalories: totalCal,
                    totalDistanceKm: distance,
                    bestDaySteps: bestDaySteps,
                    language: appLanguage
                )
                await MainActor.run {
                    self.aiTrendAnalysis = res
                    self.isAnalyzingTrends = false
                }
            } catch {
                await MainActor.run {
                    self.aiTrendAnalysis = "Не удалось сгенерировать анализ: \(error.localizedDescription)"
                    self.isAnalyzingTrends = false
                }
            }
        }
    }
    
    // MARK: - Строка одного дня в журнале
    private func dayActivityRow(day: DailyActivitySummary) -> some View {
        let isToday = Calendar.current.isDateInToday(day.date)
        let isGoalReached = day.steps >= 10000
        let distanceKm = day.distanceMeters / 1000.0
        
        return HStack(spacing: 14) {
            // Круговой бейдж даты
            VStack(spacing: 2) {
                Text(getDayOfWeekShort(day.date))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isToday ? Theme.exerciseColor : Theme.textSecondary)
                Text(getDayNumber(day.date))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
            }
            .frame(width: 44, height: 44)
            .background(isToday ? Theme.exerciseColor.opacity(0.12) : Color.primary.opacity(0.04))
            .cornerRadius(12)
            
            // Данные о шагах и калориях
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("\(day.steps.formattedWithSeparator()) шагов")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                    
                    if isGoalReached {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundColor(Theme.exerciseColor)
                    }
                }
                
                HStack(spacing: 8) {
                    Text(String(format: "%.2f км", distanceKm))
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    Text("•")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary.opacity(0.5))
                    Text("\(Int(day.activeCalories)) ккал")
                        .font(.caption.bold())
                        .foregroundColor(Color(red: 255/255, green: 69/255, blue: 58/255))
                }
            }
            
            Spacer()
            
            // Прогресс бар-полоска
            let pct = min(Double(day.steps) / 10000.0, 1.0)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 50, height: 6)
                Capsule()
                    .fill(isGoalReached ? Theme.exerciseColor : Color.orange)
                    .frame(width: max(4, 50 * CGFloat(pct)), height: 6)
            }
        }
        .padding(14)
        .background(Theme.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.02), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Вспомогательные функции форматирования
    private func getDayOfWeekShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appLanguage == "hy" ? "hy" : (appLanguage == "en" ? "en" : "ru"))
        formatter.dateFormat = "EE"
        return formatter.string(from: date).capitalized
    }
    
    private func getDayNumber(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private func formatDateShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
}

fileprivate extension Int {
    func formattedWithSeparator() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
