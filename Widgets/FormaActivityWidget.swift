import SwiftUI
import WidgetKit

public struct FormaActivityEntry: TimelineEntry {
    public let date: Date
    public let snapshot: FormaWidgetDataSnapshot
    
    public init(date: Date = Date(), snapshot: FormaWidgetDataSnapshot = FormaWidgetDataManager.shared.getSnapshot()) {
        self.date = date
        self.snapshot = snapshot
    }
}

public struct FormaActivityTimelineProvider: TimelineProvider {
    public init() {}
    
    public func placeholder(in context: Context) -> FormaActivityEntry {
        FormaActivityEntry()
    }
    
    public func getSnapshot(in context: Context, completion: @escaping (FormaActivityEntry) -> Void) {
        completion(FormaActivityEntry())
    }
    
    public func getTimeline(in context: Context, completion: @escaping (Timeline<FormaActivityEntry>) -> Void) {
        let entry = FormaActivityEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
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
                
                if snapshot.currentHeartRate > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color(red: 255/255, green: 45/255, blue: 85/255))
                        Text("\(snapshot.currentHeartRate)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .padding(12)
    }
    
    // MARK: - Home Screen: Medium Widget
    private var mediumActivityView: some View {
        HStack(spacing: 16) {
            // Тройные кольца активности
            ZStack {
                // Кольцо 1: Движение (Красное)
                let movePct = min(snapshot.activeCalories / max(1.0, snapshot.activeCaloriesGoal), 1.0)
                Circle()
                    .stroke(Color(red: 255/255, green: 69/255, blue: 58/255).opacity(0.2), lineWidth: 8)
                    .frame(width: 86, height: 86)
                Circle()
                    .trim(from: 0, to: CGFloat(movePct))
                    .stroke(Color(red: 255/255, green: 69/255, blue: 58/255), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 86, height: 86)
                    .rotationEffect(.degrees(-90))
                
                // Кольцо 2: Упражнения (Зеленое)
                let exercisePct = min(Double(snapshot.exerciseMinutes) / Double(max(1, snapshot.exerciseMinutesGoal)), 1.0)
                Circle()
                    .stroke(Color(red: 50/255, green: 215/255, blue: 75/255).opacity(0.2), lineWidth: 8)
                    .frame(width: 66, height: 66)
                Circle()
                    .trim(from: 0, to: CGFloat(exercisePct))
                    .stroke(Color(red: 50/255, green: 215/255, blue: 75/255), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 66, height: 66)
                    .rotationEffect(.degrees(-90))
                
                // Кольцо 3: Разминка (Голубое)
                let standPct = min(Double(snapshot.standHours) / Double(max(1, snapshot.standHoursGoal)), 1.0)
                Circle()
                    .stroke(Color(red: 0/255, green: 229/255, blue: 255/255).opacity(0.2), lineWidth: 8)
                    .frame(width: 46, height: 46)
                Circle()
                    .trim(from: 0, to: CGFloat(standPct))
                    .stroke(Color(red: 0/255, green: 229/255, blue: 255/255), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 46, height: 46)
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 90, height: 90)
            
            // Правая колонка с показателями
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("АКТИВНОСТЬ FORMA")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(Color.white.opacity(0.5))
                    Spacer()
                    if snapshot.currentHeartRate > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Color(red: 255/255, green: 45/255, blue: 85/255))
                            Text("\(snapshot.currentHeartRate) BPM")
                                .font(.system(size: 10, weight: .bold))
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
                    title: "Шаги за день",
                    value: "\(snapshot.stepsToday)",
                    goal: "/ \(snapshot.stepGoal)"
                )
            }
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
        Gauge(value: stepProgress) {
            Image(systemName: "figure.walk")
                .font(.system(size: 10, weight: .bold))
        } currentValueLabel: {
            Text("\(snapshot.stepsToday / 1000)k")
                .font(.system(size: 12, weight: .bold))
        }
        .gaugeStyle(.accessoryCircular)
    }
    
    // MARK: - Lock Screen: Rectangular
    private var lockScreenRectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "figure.walk")
                    .font(.caption2)
                Text("\(snapshot.stepsToday) шагов")
                    .font(.system(size: 12, weight: .bold))
            }
            
            HStack(spacing: 8) {
                Text("🔥 \(Int(snapshot.activeCalories)) ккал")
                Text("⏱️ \(snapshot.exerciseMinutes) мин")
            }
            .font(.system(size: 11))
            .foregroundColor(Color.white.opacity(0.8))
            
            if snapshot.currentHeartRate > 0 {
                Text("❤️ \(snapshot.currentHeartRate) BPM • Пульс в норме")
                    .font(.system(size: 10))
                    .foregroundColor(Color.white.opacity(0.6))
            }
        }
    }
    
    // MARK: - Lock Screen: Inline
    private var lockScreenInlineView: some View {
        Text("🏃‍♂️ \(snapshot.stepsToday) шагов • 🔥 \(Int(snapshot.activeCalories)) ккал")
    }
}
