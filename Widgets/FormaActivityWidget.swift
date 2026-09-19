import SwiftUI
import WidgetKit
import CoreMotion
import AppIntents

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
                .containerBackground(Color(red: 16/255, green: 20/255, blue: 28/255), for: .widget)
        }
        .configurationDisplayName("Активность и Шаги")
        .description("Интерактивный трекинг шагов, колец активности, гидратации и ИИ-сканер еды.")
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
    
    // MARK: - Home Screen: Small Widget (Интерактивный с кнопками)
    private var smallActivityView: some View {
        let stepProgress = min(Double(snapshot.stepsToday) / Double(max(1, snapshot.stepGoal)), 1.0)
        let stepPct = Int(min(Double(snapshot.stepsToday) / Double(max(1, snapshot.stepGoal)) * 100.0, 999.0))
        
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color(red: 0/255, green: 229/255, blue: 255/255).opacity(0.18))
                        .frame(width: 28, height: 28)
                    Image(systemName: "figure.walk")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(red: 0/255, green: 229/255, blue: 255/255))
                }
                
                Spacer()
                
                Text("\(stepPct)%")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(Color(red: 0/255, green: 229/255, blue: 255/255))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(Color(red: 0/255, green: 229/255, blue: 255/255).opacity(0.14))
                    .clipShape(Capsule())
            }
            
            Spacer(minLength: 0)
            
            VStack(alignment: .leading, spacing: 1) {
                Text("\(snapshot.stepsToday)")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                
                Text("из \(snapshot.stepGoal) шагов")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.55))
            }
            
            // Прогресс бар
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 5)
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0/255, green: 229/255, blue: 255/255), Color(red: 50/255, green: 215/255, blue: 75/255)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(5, geo.size.width * CGFloat(stepProgress)), height: 5)
                }
            }
            .frame(height: 5)
            
            Spacer(minLength: 0)
            
            // Интерактивный ряд: +250 мл воды или запуск ИИ-камеры
            HStack(spacing: 6) {
                Button(intent: AddWaterWidgetIntent(amountMl: 250)) {
                    HStack(spacing: 3) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 9))
                        Text("+250")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(Color(red: 0/255, green: 220/255, blue: 255/255))
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                    .background(Color(red: 0/255, green: 200/255, blue: 255/255).opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                
                Button(intent: OpenFoodScannerWidgetIntent()) {
                    HStack(spacing: 2) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 11, weight: .bold))
                        Text("ИИ")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(Color(red: 50/255, green: 220/255, blue: 110/255))
                    .frame(width: 44, height: 28)
                    .background(Color(red: 50/255, green: 220/255, blue: 110/255).opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(11)
        .widgetURL(URL(string: "forma://steps")!)
    }
    
    // MARK: - Home Screen: Medium Widget (Кольца активности + Метрики + Интерактивные кнопки)
    private var mediumActivityView: some View {
        let waterPct = Int(min(snapshot.waterConsumed / max(1.0, snapshot.waterGoal) * 100.0, 999.0))
        let waterRatio = min(snapshot.waterConsumed / max(1.0, snapshot.waterGoal), 1.0)
        let movePct = min(snapshot.activeCalories / max(1.0, snapshot.activeCaloriesGoal), 1.0)
        let exercisePct = min(Double(snapshot.exerciseMinutes) / Double(max(1, snapshot.exerciseMinutesGoal)), 1.0)
        let stepPct = min(Double(snapshot.stepsToday) / Double(max(1, snapshot.stepGoal)), 1.0)
        
        return HStack(spacing: 12) {
            // 3 концентрических кольца активности: Движение, Упражнения, Шаги
            ZStack {
                // Кольцо 1: Движение (Красное)
                Circle()
                    .stroke(Color(red: 255/255, green: 69/255, blue: 58/255).opacity(0.18), lineWidth: 7)
                    .frame(width: 92, height: 92)
                Circle()
                    .trim(from: 0, to: CGFloat(movePct))
                    .stroke(Color(red: 255/255, green: 69/255, blue: 58/255), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .frame(width: 92, height: 92)
                    .rotationEffect(.degrees(-90))
                
                // Кольцо 2: Упражнения (Зеленое)
                Circle()
                    .stroke(Color(red: 50/255, green: 215/255, blue: 75/255).opacity(0.18), lineWidth: 7)
                    .frame(width: 74, height: 74)
                Circle()
                    .trim(from: 0, to: CGFloat(exercisePct))
                    .stroke(Color(red: 50/255, green: 215/255, blue: 75/255), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .frame(width: 74, height: 74)
                    .rotationEffect(.degrees(-90))
                
                // Кольцо 3: Шаги (Циановое)
                Circle()
                    .stroke(Color(red: 0/255, green: 229/255, blue: 255/255).opacity(0.18), lineWidth: 7)
                    .frame(width: 56, height: 56)
                Circle()
                    .trim(from: 0, to: CGFloat(stepPct))
                    .stroke(Color(red: 0/255, green: 229/255, blue: 255/255), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
                
                // Иконка в центре
                Image(systemName: "flame.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(red: 255/255, green: 69/255, blue: 58/255))
            }
            .frame(width: 96, height: 96)
            
            // Правая колонка с показателями и интерактивным доком
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("АКТИВНОСТЬ ДНЯ")
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
                    title: "Шаги",
                    value: "\(snapshot.stepsToday)",
                    goal: "/ \(snapshot.stepGoal)"
                )
                
                metricRow(
                    color: Color(red: 0/255, green: 215/255, blue: 255/255),
                    title: "Вода",
                    value: "\(Int(snapshot.waterConsumed))",
                    goal: "/ \(Int(snapshot.waterGoal)) мл"
                )
                
                Spacer(minLength: 0)
                
                // Интерактивные кнопки: быстро налить воду или запустить ИИ камеру
                HStack(spacing: 6) {
                    Button(intent: AddWaterWidgetIntent(amountMl: 250)) {
                        HStack(spacing: 2) {
                            Image(systemName: "drop.fill")
                                .font(.system(size: 8))
                            Text("+250 мл")
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(Color(red: 0/255, green: 215/255, blue: 255/255))
                        .frame(maxWidth: .infinity)
                        .frame(height: 26)
                        .background(Color(red: 0/255, green: 200/255, blue: 255/255).opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    
                    Link(destination: URL(string: "forma://scan")!) {
                        HStack(spacing: 3) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 10, weight: .bold))
                            Text("ИИ Сканер")
                                .font(.system(size: 9.5, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 26)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 45/255, green: 200/255, blue: 100/255), Color(red: 25/255, green: 155/255, blue: 85/255)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
    }
    
    // MARK: - Home Screen: Large Widget (Полный фитнес-хаб с интерактивными кнопками)
    private var largeActivityView: some View {
        let waterPct = Int(min(snapshot.waterConsumed / max(1.0, snapshot.waterGoal) * 100.0, 999.0))
        let waterRatio = min(snapshot.waterConsumed / max(1.0, snapshot.waterGoal), 1.0)
        let stepDistanceKm = (Double(snapshot.stepsToday) * 0.00075)
        let totalBurned = snapshot.totalCaloriesBurned > 0 ? snapshot.totalCaloriesBurned : (snapshot.activeCalories + 1650.0)
        
        return VStack(alignment: .leading, spacing: 10) {
            // Верхняя плашка заголовка
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "flame.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(red: 0/255, green: 229/255, blue: 255/255))
                    Text("FORMA • ИТОГИ ДНЯ")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                if snapshot.currentHeartRate > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color(red: 255/255, green: 45/255, blue: 85/255))
                        Text("\(snapshot.currentHeartRate) BPM")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(red: 255/255, green: 45/255, blue: 85/255).opacity(0.15))
                    .cornerRadius(6)
                }
            }
            
            // Секция 1: 3 кольца активности + 4 строки ключевых метрик
            HStack(spacing: 14) {
                // Кольца активности
                ZStack {
                    let movePct = min(snapshot.activeCalories / max(1.0, snapshot.activeCaloriesGoal), 1.0)
                    Circle()
                        .stroke(Color(red: 255/255, green: 69/255, blue: 58/255).opacity(0.18), lineWidth: 8)
                        .frame(width: 96, height: 96)
                    Circle()
                        .trim(from: 0, to: CGFloat(movePct))
                        .stroke(Color(red: 255/255, green: 69/255, blue: 58/255), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 96, height: 96)
                        .rotationEffect(.degrees(-90))
                    
                    let exercisePct = min(Double(snapshot.exerciseMinutes) / Double(max(1, snapshot.exerciseMinutesGoal)), 1.0)
                    Circle()
                        .stroke(Color(red: 50/255, green: 215/255, blue: 75/255).opacity(0.18), lineWidth: 8)
                        .frame(width: 76, height: 76)
                    Circle()
                        .trim(from: 0, to: CGFloat(exercisePct))
                        .stroke(Color(red: 50/255, green: 215/255, blue: 75/255), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 76, height: 76)
                        .rotationEffect(.degrees(-90))
                    
                    let stepPct = min(Double(snapshot.stepsToday) / Double(max(1, snapshot.stepGoal)), 1.0)
                    Circle()
                        .stroke(Color(red: 0/255, green: 229/255, blue: 255/255).opacity(0.18), lineWidth: 8)
                        .frame(width: 56, height: 56)
                    Circle()
                        .trim(from: 0, to: CGFloat(stepPct))
                        .stroke(Color(red: 0/255, green: 229/255, blue: 255/255), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(-90))
                    
                    Image(systemName: "figure.walk")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(red: 0/255, green: 229/255, blue: 255/255))
                }
                .frame(width: 100, height: 100)
                
                // Столбец метрик
                VStack(alignment: .leading, spacing: 5) {
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
                        color: Color(red: 0/255, green: 215/255, blue: 255/255),
                        title: "Водный баланс",
                        value: "\(Int(snapshot.waterConsumed))",
                        goal: "/ \(Int(snapshot.waterGoal)) мл"
                    )
                }
            }
            
            // Секция 2: Две карточки (Калории и Дистанция)
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 9))
                            .foregroundColor(Color(red: 255/255, green: 69/255, blue: 58/255))
                        Text("Сожжено за день")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.6))
                    }
                    Text("\(Int(totalBurned)) ккал")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(7)
                .background(Color.white.opacity(0.06))
                .cornerRadius(7)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 9))
                            .foregroundColor(Color(red: 50/255, green: 215/255, blue: 75/255))
                        Text("Дистанция")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.6))
                    }
                    Text(String(format: "%.2f км", stepDistanceKm))
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(7)
                .background(Color.white.opacity(0.06))
                .cornerRadius(7)
            }
            
            // Секция 3: Водная шкала прогресса без лишнего дублирования текста
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 9))
                        .foregroundColor(Color(red: 0/255, green: 215/255, blue: 255/255))
                    Text("Вода:")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                    Text("\(Int(snapshot.waterConsumed)) из \(Int(snapshot.waterGoal)) мл")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.75))
                    Spacer()
                    Text("\(waterPct)%")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0/255, green: 215/255, blue: 255/255))
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 5)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0/255, green: 229/255, blue: 255/255), Color(red: 0/255, green: 135/255, blue: 255/255)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(5, geo.size.width * CGFloat(waterRatio)), height: 5)
                    }
                }
                .frame(height: 5)
            }
            .padding(7)
            .background(Color.white.opacity(0.06))
            .cornerRadius(7)
            
            Spacer(minLength: 0)
            
            // ИНТЕРАКТИВНЫЙ ТУЛБАР: +250 мл, +500 мл и Кнопка ИИ Сканера еды
            HStack(spacing: 8) {
                Button(intent: AddWaterWidgetIntent(amountMl: 250)) {
                    HStack(spacing: 2) {
                        Image(systemName: "plus")
                            .font(.system(size: 8, weight: .bold))
                        Text("+250 мл")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(Color(red: 0/255, green: 215/255, blue: 255/255))
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .background(Color(red: 0/255, green: 200/255, blue: 255/255).opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                
                Button(intent: AddWaterWidgetIntent(amountMl: 500)) {
                    HStack(spacing: 2) {
                        Image(systemName: "plus")
                            .font(.system(size: 8, weight: .bold))
                        Text("+500 мл")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(Color(red: 0/255, green: 215/255, blue: 255/255))
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .background(Color(red: 0/255, green: 200/255, blue: 255/255).opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                
                Link(destination: URL(string: "forma://scan")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 11, weight: .bold))
                        Text("ИИ Сканер")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 45/255, green: 200/255, blue: 100/255), Color(red: 25/255, green: 155/255, blue: 85/255)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .padding(12)
    }
    
    private func metricRow(color: Color, title: String, value: String, goal: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color.white.opacity(0.8))
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(goal)
                .font(.system(size: 9))
                .foregroundColor(Color.white.opacity(0.5))
        }
    }
    
    // MARK: - Lock Screen: Circular
    private var lockScreenCircularView: some View {
        let stepProgress = min(Double(snapshot.stepsToday) / Double(max(1, snapshot.stepGoal)), 1.0)
        return Gauge(value: stepProgress) {
            Image(systemName: "figure.walk")
                .font(.system(size: 10, weight: .bold))
        } currentValueLabel: {
            Text("\(snapshot.stepsToday)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
        }
        .gaugeStyle(.accessoryCircular)
    }
    
    // MARK: - Lock Screen: Rectangular (БЕЗ ДУБЛИРОВАНИЯ ВОДЫ + ИНТЕРАКТИВНОСТЬ)
    private var lockScreenRectangularView: some View {
        let stepRatio = min(Double(snapshot.stepsToday) / Double(max(1, snapshot.stepGoal)), 1.0)
        let distanceKm = Double(snapshot.stepsToday) * 0.00075
        let cal = snapshot.activeCalories > 0 ? Int(snapshot.activeCalories) : Int(Double(snapshot.stepsToday) * 0.042)
        
        return VStack(alignment: .leading, spacing: 3) {
            // Строка 1: Шаги и сожженные калории
            HStack(spacing: 5) {
                HStack(spacing: 2) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 10, weight: .bold))
                    Text("\(snapshot.stepsToday)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                    Text("(\(String(format: "%.1f", distanceKm)) км)")
                        .font(.system(size: 9))
                        .foregroundColor(Color.white.opacity(0.7))
                }
                
                Spacer()
                
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 8))
                    Text("\(cal) ккал")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                }
            }
            
            // Строка 2: Шкала выполнения шагов
            ProgressView(value: min(max(0.04, stepRatio), 1.0), total: 1.0)
                .progressViewStyle(LinearProgressViewStyle(tint: .white))
                .background(Color.white.opacity(0.25))
                .cornerRadius(2)
                .frame(height: 3.5)
            
            // Строка 3: Водный баланс и интерактивная кнопка +250
            HStack {
                HStack(spacing: 2) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 8))
                    Text("\(Int(snapshot.waterConsumed)) мл")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                }
                
                Spacer()
                
                Button(intent: AddWaterWidgetIntent(amountMl: 250)) {
                    HStack(spacing: 2) {
                        Image(systemName: "plus")
                            .font(.system(size: 8, weight: .heavy))
                        Text("250")
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Color.white.opacity(0.22))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Lock Screen: Inline
    private var lockScreenInlineView: some View {
        let distanceKm = Double(snapshot.stepsToday) * 0.00075
        let cal = snapshot.activeCalories > 0 ? Int(snapshot.activeCalories) : Int(Double(snapshot.stepsToday) * 0.042)
        return Text("🚶 \(snapshot.stepsToday) (\(String(format: "%.1f", distanceKm)) км) • 🔥 \(cal) ккал • 💧 \(Int(snapshot.waterConsumed)) мл")
    }
}
