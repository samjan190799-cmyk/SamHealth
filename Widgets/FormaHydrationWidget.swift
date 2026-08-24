import SwiftUI
import WidgetKit

public struct FormaHydrationEntry: TimelineEntry {
    public let date: Date
    public let snapshot: FormaWidgetDataSnapshot
    
    public init(date: Date = Date(), snapshot: FormaWidgetDataSnapshot = FormaWidgetDataManager.shared.getSnapshot()) {
        self.date = date
        self.snapshot = snapshot
    }
}

public struct FormaHydrationTimelineProvider: TimelineProvider {
    public init() {}
    
    public func placeholder(in context: Context) -> FormaHydrationEntry {
        FormaHydrationEntry()
    }
    
    public func getSnapshot(in context: Context, completion: @escaping (FormaHydrationEntry) -> Void) {
        completion(FormaHydrationEntry())
    }
    
    public func getTimeline(in context: Context, completion: @escaping (Timeline<FormaHydrationEntry>) -> Void) {
        let entry = FormaHydrationEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 20, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

public struct FormaHydrationWidget: Widget {
    public let kind: String = "FormaHydrationWidget"
    
    public init() {}
    
    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FormaHydrationTimelineProvider()) { entry in
            FormaHydrationWidgetEntryView(entry: entry)
                .containerBackground(Color(red: 18/255, green: 20/255, blue: 28/255), for: .widget)
        }
        .configurationDisplayName("Вода и Энергобаланс")
        .description("Отслеживайте гидратацию за день и дефицит калорий.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryInline
        ])
    }
}

public struct FormaHydrationWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    public let entry: FormaHydrationEntry
    
    private var snapshot: FormaWidgetDataSnapshot {
        entry.snapshot
    }
    
    public var body: some View {
        switch family {
        case .systemSmall:
            smallHydrationView
        case .systemMedium:
            mediumHydrationView
        case .accessoryCircular:
            lockScreenCircularView
        case .accessoryInline:
            lockScreenInlineView
        default:
            smallHydrationView
        }
    }
    
    // MARK: - Home Screen: Small Widget
    private var smallHydrationView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color(red: 0/255, green: 145/255, blue: 255/255).opacity(0.2))
                        .frame(width: 28, height: 28)
                    Image(systemName: "drop.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(red: 0/255, green: 145/255, blue: 255/255))
                }
                
                Spacer()
                
                let waterPct = Double(snapshot.waterConsumed) / Double(max(1.0, snapshot.waterGoal))
                Text("\(Int(min(waterPct * 100, 999)))%")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(red: 0/255, green: 145/255, blue: 255/255))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(red: 0/255, green: 145/255, blue: 255/255).opacity(0.12))
                    .cornerRadius(8)
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Int(snapshot.waterConsumed))")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("из \(Int(snapshot.waterGoal)) мл")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.6))
            }
            
            // Водный прогресс бар
            GeometryReader { geo in
                let waterPct = min(Double(snapshot.waterConsumed) / Double(max(1.0, snapshot.waterGoal)), 1.0)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 6)
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0/255, green: 191/255, blue: 255/255), Color(red: 0/255, green: 122/255, blue: 255/255)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(6, geo.size.width * CGFloat(waterPct)), height: 6)
                }
            }
            .frame(height: 6)
            
            HStack {
                Text("Баланс: \(Int(snapshot.energyBalance)) ккал")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(snapshot.energyBalance < 0 ? .green : .orange)
                Spacer()
                Text("💧 +250 мл")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Color(red: 0/255, green: 145/255, blue: 255/255))
            }
        }
        .padding(12)
    }
    
    // MARK: - Home Screen: Medium Widget
    private var mediumHydrationView: some View {
        HStack(spacing: 16) {
            // Левая часть: Вода
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                        .foregroundColor(Color(red: 0/255, green: 145/255, blue: 255/255))
                        .font(.caption2)
                    Text("ГИДРАТАЦИЯ")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(Color.white.opacity(0.5))
                }
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(snapshot.waterConsumed))")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("/ \(Int(snapshot.waterGoal)) мл")
                        .font(.system(size: 10))
                        .foregroundColor(Color.white.opacity(0.5))
                }
                
                // Прогресс бар воды
                GeometryReader { geo in
                    let waterPct = min(Double(snapshot.waterConsumed) / Double(max(1.0, snapshot.waterGoal)), 1.0)
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 6)
                        Capsule()
                            .fill(Color(red: 0/255, green: 145/255, blue: 255/255))
                            .frame(width: max(6, geo.size.width * CGFloat(waterPct)), height: 6)
                    }
                }
                .frame(height: 6)
                
                Text(snapshot.waterConsumed >= snapshot.waterGoal ? "💧 Норма выполнена!" : "Осталось: \(Int(max(0, snapshot.waterGoal - snapshot.waterConsumed))) мл")
                    .font(.system(size: 9))
                    .foregroundColor(Color.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Правая часть: Энергобаланс
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: snapshot.energyBalance < 0 ? "flame.fill" : "bolt.fill")
                        .foregroundColor(snapshot.energyBalance < 0 ? .green : .orange)
                        .font(.caption2)
                    Text("ЭНЕРГОБАЛАНС")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(Color.white.opacity(0.5))
                }
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(snapshot.energyBalance))")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(snapshot.energyBalance < 0 ? .green : .orange)
                    Text("ккал")
                        .font(.system(size: 10))
                        .foregroundColor(Color.white.opacity(0.5))
                }
                
                Text("Съедено: \(Int(snapshot.caloriesConsumed)) • Сожжено: \(Int(snapshot.totalCaloriesBurned))")
                    .font(.system(size: 9))
                    .foregroundColor(Color.white.opacity(0.6))
                    .lineLimit(1)
                
                Text(snapshot.energyBalance < 0 ? "🔥 Сжигание жира" : "⚡ Профицит энергии")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(snapshot.energyBalance < 0 ? .green : .orange)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
    }
    
    // MARK: - Lock Screen: Circular
    private var lockScreenCircularView: some View {
        let waterPct = min(Double(snapshot.waterConsumed) / Double(max(1.0, snapshot.waterGoal)), 1.0)
        Gauge(value: waterPct) {
            Image(systemName: "drop.fill")
                .font(.system(size: 10, weight: .bold))
        } currentValueLabel: {
            Text("\(Int(snapshot.waterConsumed / 1000 * 10))")
                .font(.system(size: 12, weight: .bold))
        }
        .gaugeStyle(.accessoryCircular)
    }
    
    // MARK: - Lock Screen: Inline
    private var lockScreenInlineView: some View {
        Text("💧 \(Int(snapshot.waterConsumed))/\(Int(snapshot.waterGoal)) мл • \(Int(snapshot.energyBalance)) ккал")
    }
}
