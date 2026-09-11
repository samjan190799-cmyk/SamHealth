import SwiftUI
import WidgetKit
import CoreMotion

public struct FormaActivityEntry: TimelineEntry {
    public let date: Date
    public let snapshot: FormaWidgetDataSnapshot
    
    public init(date: Date = Date(), snapshot: FormaWidgetDataSnapshot = FormaWidgetDataManager.shared.getSnapshot()) {
        self.date = date
        self.snapshot = snapshot
    }
}

public struct FormaActivityTimelineProvider: TimelineProvider {
    private let pedometer = CMPedometer()
    
    public init() {}
    
    public func placeholder(in context: Context) -> FormaActivityEntry {
        FormaActivityEntry(date: Date(), snapshot: FormaWidgetDataManager.makeSampleSnapshot())
    }
    
    public func getSnapshot(in context: Context, completion: @escaping (FormaActivityEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
        } else {
            completion(FormaActivityEntry())
        }
    }
    
    public func getTimeline(in context: Context, completion: @escaping (Timeline<FormaActivityEntry>) -> Void) {
        var snapshot = FormaWidgetDataManager.shared.getSnapshot()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        
        // Фолбек на CoreMotion датчик движения, если в AppGroup пока 0 шагов
        if snapshot.stepsToday == 0 && CMPedometer.isStepCountingAvailable() {
            let startOfDay = Calendar.current.startOfDay(for: Date())
            pedometer.queryPedometerData(from: startOfDay, to: Date()) { data, _ in
                if let data = data {
                    let liveSteps = data.numberOfSteps.intValue
                    if liveSteps > 0 {
                        snapshot.stepsToday = liveSteps
                        if snapshot.activeCalories == 0 {
                            snapshot.activeCalories = (Double(liveSteps) * 0.045).rounded()
                        }
                    }
                }
                let entry = FormaActivityEntry(date: Date(), snapshot: snapshot)
                let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
                completion(timeline)
            }
        } else {
            let entry = FormaActivityEntry(date: Date(), snapshot: snapshot)
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
}

public struct FormaActivityWidget: Widget {
    public let kind: String = "FormaActivityWidget"
    
    public init() {}
    
    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FormaActivityTimelineProvider()) { entry in
            FormaActivityWidgetEntryView(entry: entry)
                .containerBackground(Color(red: 18/255, green: 20/255, blue: 28/255), for: .widget)
        }
        .configurationDisplayName("Активность и Шаги")
        .description("Отслеживайте шаги, кольца активности и пульс в реальном времени.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

public struct FormaActivityWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    public let entry: FormaActivityEntry
    
    private var snapshot: FormaWidgetDataSnapshot {
        entry.snapshot
    }
    
    public var body: some View {
        switch family {
        case .systemSmall:
            smallActivityView
        case .systemMedium:
            mediumActivityView
        case .systemLarge:
            largeActivityView
        case .accessoryCircular:
            lockScreenCircularView
        case .accessoryRectangular:
            lockScreenRectangularView
        case .accessoryInline:
            lockScreenInlineView
        default:
            smallActivityView
        }
    }
    
    // MARK: - Home Screen: Small Widget
    private var smallActivityView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color(red: 0/255, green: 229/255, blue: 255/255).opacity(0.2))
                        .frame(width: 28, height: 28)
                    Image(systemName: "figure.walk")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(red: 0/255, green: 229/255, blue: 255/255))
                }
                
                Spacer()
                
                let stepProgress = Double(snapshot.stepsToday) / Double(max(1, snapshot.stepGoal))
                Text("\(Int(min(stepProgress * 100, 999)))%")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(red: 0/255, green: 229/255, blue: 255/255))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(red: 0/255, green: 229/255, blue: 255/255).opacity(0.12))
                    .cornerRadius(8)
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(snapshot.stepsToday)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("из \(snapshot.stepGoal) шагов")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.6))
            }
            
            // Прогресс бар
            GeometryReader { geo in
                let stepProgress = min(Double(snapshot.stepsToday) / Double(max(1, snapshot.stepGoal)), 1.0)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 6)
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0/255, green: 229/255, blue: 255/255), Color(red: 50/255, green: 215/255, blue: 75/255)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(6, geo.size.width * CGFloat(stepProgress)), height: 6)
                }
            }
            .frame(height: 6)
            
            HStack(spacing: 8) {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(red: 255/255, green: 69/255, blue: 58/255))
                    Text("\(Int(snapshot.activeCalories)) ккал")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                let waterPct = Int(min(snapshot.waterConsumed / max(1.0, snapshot.waterGoal) * 100.0, 999.0))
                HStack(spacing: 3) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(red: 0/255, green: 229/255, blue: 255/255))
                    Text("\(waterPct)%")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(12)
    }
    
    // MARK: - Home Screen: Medium Widget (Полное использование пространства с водой)
    private var mediumActivityView: some View {
        let waterPct = Int(min(snapshot.waterConsumed / max(1.0, snapshot.waterGoal) * 100.0, 999.0))
        let waterRatio = min(snapshot.waterConsumed / max(1.0, snapshot.waterGoal), 1.0)
        
        return HStack(spacing: 14) {
            // 4 концентрических кольца активности: Движение, Упражнения, Шаги, Вода
            ZStack {
                // Кольцо 1: Движение (Красное)
                let movePct = min(snapshot.activeCalories / max(1.0, snapshot.activeCaloriesGoal), 1.0)
                Circle()
                    .stroke(Color(red: 255/255, green: 69/255, blue: 58/255).opacity(0.18), lineWidth: 7)
                    .frame(width: 96, height: 96)
                Circle()
                    .trim(from: 0, to: CGFloat(movePct))
                    .stroke(Color(red: 255/255, green: 69/255, blue: 58/255), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .frame(width: 96, height: 96)
                    .rotationEffect(.degrees(-90))
                
                // Кольцо 2: Упражнения (Зеленое)
                let exercisePct = min(Double(snapshot.exerciseMinutes) / Double(max(1, snapshot.exerciseMinutesGoal)), 1.0)
                Circle()
                    .stroke(Color(red: 50/255, green: 215/255, blue: 75/255).opacity(0.18), lineWidth: 7)
                    .frame(width: 78, height: 78)
                Circle()
                    .trim(from: 0, to: CGFloat(exercisePct))
                    .stroke(Color(red: 50/255, green: 215/255, blue: 75/255), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .frame(width: 78, height: 78)
                    .rotationEffect(.degrees(-90))
                
                // Кольцо 3: Шаги (Голубое)
                let stepPct = min(Double(snapshot.stepsToday) / Double(max(1, snapshot.stepGoal)), 1.0)
                Circle()
                    .stroke(Color(red: 0/255, green: 229/255, blue: 255/255).opacity(0.18), lineWidth: 7)
                    .frame(width: 60, height: 60)
                Circle()
                    .trim(from: 0, to: CGFloat(stepPct))
                    .stroke(Color(red: 0/255, green: 229/255, blue: 255/255), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                
                // Кольцо 4: Водный баланс (Циановое/Синее)
                Circle()
                    .stroke(Color(red: 0/255, green: 145/255, blue: 255/255).opacity(0.18), lineWidth: 6)
                    .frame(width: 44, height: 44)
                Circle()
                    .trim(from: 0, to: CGFloat(waterRatio))
                    .stroke(Color(red: 0/255, green: 145/255, blue: 255/255), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))
                
                // Иконка капли в центре
                Image(systemName: "drop.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(red: 0/255, green: 229/255, blue: 255/255))
            }
            .frame(width: 98, height: 98)
            
            // Правая колонка с 4-мя показателями дня (без пустых мест)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("АКТИВНОСТЬ И БАЛАНС")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(Color.white.opacity(0.55))
                    Spacer()
                    if snapshot.currentHeartRate > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 9))
                                .foregroundColor(Color(red: 255/255, green: 45/255, blue: 85/255))
                            Text("\(snapshot.currentHeartRate)")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundColor(.white)
                        }
                    }
                }
                
                metricRow(
                    color: Color(red: 255/255, green: 69/255, blue: 58/255),
                    title: "Движение",
                    value: "\(Int(snapshot.activeCalories))",
                    goal: "/ \(Int(snapshot.activeCaloriesGoal)) ккал"
                )
                
                metricRow(
                    color: Color(red: 50/255, green: 215/255, blue: 75/255),
                    title: "Упражнения",
                    value: "\(snapshot.exerciseMinutes)",
                    goal: "/ \(snapshot.exerciseMinutesGoal) мин"
                )
                
                metricRow(
                    color: Color(red: 0/255, green: 229/255, blue: 255/255),
                    title: "Шаги",
                    value: "\(snapshot.stepsToday)",
                    goal: "/ \(snapshot.stepGoal)"
                )
                
                // Водный баланс со шкалой
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(red: 0/255, green: 145/255, blue: 255/255))
                        .frame(width: 6, height: 6)
                    Text("Вода")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.85))
                    Spacer()
                    Text("\(Int(snapshot.waterConsumed))")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0/255, green: 229/255, blue: 255/255))
                    Text("/ \(Int(snapshot.waterGoal)) мл (\(waterPct)%)")
                        .font(.system(size: 10))
                        .foregroundColor(Color.white.opacity(0.55))
                }
            }
        }
        .padding(12)
    }
    
    // MARK: - Home Screen: Large Widget (Все показатели и итоги дня в одном месте)
    private var largeActivityView: some View {
        let waterPct = Int(min(snapshot.waterConsumed / max(1.0, snapshot.waterGoal) * 100.0, 999.0))
        let waterRatio = min(snapshot.waterConsumed / max(1.0, snapshot.waterGoal), 1.0)
        let stepDistanceKm = (Double(snapshot.stepsToday) * 0.00075)
        let totalBurned = snapshot.totalCaloriesBurned > 0 ? snapshot.totalCaloriesBurned : (snapshot.activeCalories + 1650.0)
        let remainingWater = max(0, Int(snapshot.waterGoal - snapshot.waterConsumed))
        
        return VStack(alignment: .leading, spacing: 12) {
            // Верхняя плашка заголовка
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "flame.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(Color(red: 0/255, green: 229/255, blue: 255/255))
                    Text("FORMA • ИТОГИ ДНЯ")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                if snapshot.currentHeartRate > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(red: 255/255, green: 45/255, blue: 85/255))
                        Text("\(snapshot.currentHeartRate) BPM")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(red: 255/255, green: 45/255, blue: 85/255).opacity(0.15))
                    .cornerRadius(6)
                }
            }
            
            // Секция 1: 4 кольца активности + 4 строки ключевых метрик
            HStack(spacing: 16) {
                // Кольца активности
                ZStack {
                    // Кольцо 1: Движение
                    let movePct = min(snapshot.activeCalories / max(1.0, snapshot.activeCaloriesGoal), 1.0)
                    Circle()
                        .stroke(Color(red: 255/255, green: 69/255, blue: 58/255).opacity(0.18), lineWidth: 8)
                        .frame(width: 108, height: 108)
                    Circle()
                        .trim(from: 0, to: CGFloat(movePct))
                        .stroke(Color(red: 255/255, green: 69/255, blue: 58/255), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 108, height: 108)
                        .rotationEffect(.degrees(-90))
                    
                    // Кольцо 2: Упражнения
                    let exercisePct = min(Double(snapshot.exerciseMinutes) / Double(max(1, snapshot.exerciseMinutesGoal)), 1.0)
                    Circle()
                        .stroke(Color(red: 50/255, green: 215/255, blue: 75/255).opacity(0.18), lineWidth: 8)
                        .frame(width: 88, height: 88)
                    Circle()
                        .trim(from: 0, to: CGFloat(exercisePct))
                        .stroke(Color(red: 50/255, green: 215/255, blue: 75/255), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 88, height: 88)
                        .rotationEffect(.degrees(-90))
                    
                    // Кольцо 3: Шаги
                    let stepPct = min(Double(snapshot.stepsToday) / Double(max(1, snapshot.stepGoal)), 1.0)
                    Circle()
                        .stroke(Color(red: 0/255, green: 229/255, blue: 255/255).opacity(0.18), lineWidth: 8)
                        .frame(width: 68, height: 68)
                    Circle()
                        .trim(from: 0, to: CGFloat(stepPct))
                        .stroke(Color(red: 0/255, green: 229/255, blue: 255/255), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 68, height: 68)
                        .rotationEffect(.degrees(-90))
                    
                    // Кольцо 4: Вода
                    Circle()
                        .stroke(Color(red: 0/255, green: 145/255, blue: 255/255).opacity(0.18), lineWidth: 7)
                        .frame(width: 50, height: 50)
                    Circle()
                        .trim(from: 0, to: CGFloat(waterRatio))
                        .stroke(Color(red: 0/255, green: 145/255, blue: 255/255), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))
                    
                    // В центре: иконка победы или капли
                    VStack(spacing: 1) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(red: 0/255, green: 229/255, blue: 255/255))
                        Text("\(waterPct)%")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 112, height: 112)
                
                // Столбец метрик
                VStack(alignment: .leading, spacing: 6) {
                    metricRow(
                        color: Color(red: 255/255, green: 69/255, blue: 58/255),
                        title: "Движение",
                        value: "\(Int(snapshot.activeCalories))",
                        goal: "/ \(Int(snapshot.activeCaloriesGoal)) ккал"
                    )
                    
                    metricRow(
                        color: Color(red: 50/255, green: 215/255, blue: 75/255),
                        title: "Упражнения",
                        value: "\(snapshot.exerciseMinutes)",
                        goal: "/ \(snapshot.exerciseMinutesGoal) мин"
                    )
                    
                    metricRow(
                        color: Color(red: 0/255, green: 229/255, blue: 255/255),
                        title: "Шаги за день",
                        value: "\(snapshot.stepsToday)",
                        goal: "/ \(snapshot.stepGoal)"
                    )
                    
                    metricRow(
                        color: Color(red: 0/255, green: 145/255, blue: 255/255),
                        title: "Водный баланс",
                        value: "\(Int(snapshot.waterConsumed))",
                        goal: "/ \(Int(snapshot.waterGoal)) мл"
                    )
                }
            }
            
            // Секция 2: Информационные карточки "Что сделано сегодня"
            VStack(spacing: 8) {
                // Карточка Водного Баланса
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Image(systemName: "drop.fill")
                            .foregroundColor(Color(red: 0/255, green: 229/255, blue: 255/255))
                            .font(.system(size: 11))
                        Text("Гидратация:")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                        Text("\(Int(snapshot.waterConsumed)) мл из \(Int(snapshot.waterGoal)) мл")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.85))
                        Spacer()
                        Text(remainingWater == 0 ? "Норма закрыта! 💧" : "Осталось: \(remainingWater) мл")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(remainingWater == 0 ? .green : Color(red: 0/255, green: 229/255, blue: 255/255))
                    }
                    
                    // Шкала прогресса воды
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                                .frame(height: 6)
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 0/255, green: 229/255, blue: 255/255), Color(red: 0/255, green: 135/255, blue: 255/255)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(6, geo.size.width * CGFloat(waterRatio)), height: 6)
                        }
                    }
                    .frame(height: 6)
                }
                .padding(10)
                .background(Color.white.opacity(0.06))
                .cornerRadius(10)
                
                // Карточка Калорий и Дистанции
                HStack(spacing: 8) {
                    // Сожжено калорий
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Color(red: 255/255, green: 69/255, blue: 58/255))
                            Text("Сожжено за день")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.6))
                        }
                        Text("\(Int(totalBurned)) ккал")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                        Text("Активных: \(Int(snapshot.activeCalories)) ккал")
                            .font(.system(size: 9))
                            .foregroundColor(Color.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(8)
                    
                    // Дистанция и активность
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Image(systemName: "figure.walk")
                                .font(.system(size: 10))
                                .foregroundColor(Color(red: 50/255, green: 215/255, blue: 75/255))
                            Text("Дистанция")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.6))
                        }
                        Text(String(format: "%.2f км", stepDistanceKm))
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                        Text("\(snapshot.standHours) из \(snapshot.standHoursGoal) ч разминки")
                            .font(.system(size: 9))
                            .foregroundColor(Color.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(8)
                }
            }
            
            // Нижняя строка: Совет от ИИ-тренера
            HStack(spacing: 8) {
                Text(snapshot.coachBadgeEmoji.isEmpty ? "⚡" : snapshot.coachBadgeEmoji)
                    .font(.system(size: 14))
                Text("\(snapshot.coachName): \(snapshot.coachAdvice)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.85))
                    .lineLimit(2)
            }
            .padding(8)
            .background(Color(red: 0/255, green: 229/255, blue: 255/255).opacity(0.1))
            .cornerRadius(8)
        }
        .padding(14)
    }
    
    private func metricRow(color: Color, title: String, value: String, goal: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.white.opacity(0.8))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(goal)
                .font(.system(size: 10))
                .foregroundColor(Color.white.opacity(0.5))
        }
    }
    
    // MARK: - Lock Screen: Circular
    private var lockScreenCircularView: some View {
        let stepProgress = min(Double(snapshot.stepsToday) / Double(max(1, snapshot.stepGoal)), 1.0)
        let waterPct = Int(min(snapshot.waterConsumed / max(1.0, snapshot.waterGoal) * 100.0, 999.0))
        return Gauge(value: stepProgress) {
            Image(systemName: "figure.walk")
                .font(.system(size: 10, weight: .bold))
        } currentValueLabel: {
            VStack(spacing: -1) {
                Text("\(snapshot.stepsToday / 1000)k")
                    .font(.system(size: 11, weight: .bold))
                HStack(spacing: 1) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 7))
                    Text("\(waterPct)%")
                        .font(.system(size: 8, weight: .heavy))
                }
            }
        }
        .gaugeStyle(.accessoryCircular)
    }
    
    // MARK: - Lock Screen: Rectangular (Шаги + Калории + Дистанция + Вода + Пульс + Нативная шкала)
    private var lockScreenRectangularView: some View {
        let waterPct = Int(min(snapshot.waterConsumed / max(1.0, snapshot.waterGoal) * 100.0, 999.0))
        let waterRatio = min(snapshot.waterConsumed / max(1.0, snapshot.waterGoal), 1.0)
        let stepRatio = min(Double(snapshot.stepsToday) / Double(max(1, snapshot.stepGoal)), 1.0)
        let distanceKm = Double(snapshot.stepsToday) * 0.00075
        let progressValue = snapshot.waterConsumed > 0 ? waterRatio : stepRatio
        
        return VStack(alignment: .leading, spacing: 3) {
            // Строка 1: Шаги, калории и дистанция
            HStack(spacing: 5) {
                HStack(spacing: 2) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 10, weight: .bold))
                    Text("\(snapshot.stepsToday)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                Text("•")
                    .foregroundColor(Color.white.opacity(0.4))
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 9))
                    Text("\(Int(snapshot.activeCalories)) ккал")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                Text("•")
                    .foregroundColor(Color.white.opacity(0.4))
                HStack(spacing: 2) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 8))
                    Text(String(format: "%.1f км", distanceKm))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
            }
            
            // Строка 2: Гидратация (без слова "Вода") + Пульс + Процент
            HStack(spacing: 4) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 9))
                Text("\(Int(snapshot.waterConsumed))/\(Int(snapshot.waterGoal)) мл")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                
                if snapshot.currentHeartRate > 40 {
                    Text("•")
                        .foregroundColor(Color.white.opacity(0.4))
                    HStack(spacing: 2) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 8))
                        Text("\(snapshot.currentHeartRate)")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                    }
                }
                
                Spacer()
                
                Text(snapshot.waterConsumed > 0 ? "\(waterPct)%" : "\(Int(stepRatio * 100))%")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
            }
            
            // Строка 3: Аппаратно-ускоренная полоска без GeometryReader (устраняет микрофризы SpringBoard при разблокировке)
            ProgressView(value: min(max(0.03, progressValue), 1.0), total: 1.0)
                .progressViewStyle(LinearProgressViewStyle(tint: .white))
                .background(Color.white.opacity(0.25))
                .cornerRadius(2)
                .frame(height: 4)
        }
    }
    
    // MARK: - Lock Screen: Inline
    private var lockScreenInlineView: some View {
        let waterPct = Int(min(snapshot.waterConsumed / max(1.0, snapshot.waterGoal) * 100.0, 999.0))
        let distanceKm = Double(snapshot.stepsToday) * 0.00075
        return Text("🏃 \(snapshot.stepsToday) • 🔥 \(Int(snapshot.activeCalories))ккал • 📍 \(String(format: "%.1f", distanceKm))км • 💧 \(Int(snapshot.waterConsumed))мл (\(waterPct)%)")
    }
}
