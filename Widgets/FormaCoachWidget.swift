import SwiftUI
import WidgetKit

public struct FormaCoachEntry: TimelineEntry {
    public let date: Date
    public let snapshot: FormaWidgetDataSnapshot
    
    public init(date: Date = Date(), snapshot: FormaWidgetDataSnapshot = FormaWidgetDataManager.shared.getSnapshot()) {
        self.date = date
        self.snapshot = snapshot
    }
}

public struct FormaCoachTimelineProvider: TimelineProvider {
    public init() {}
    
    public func placeholder(in context: Context) -> FormaCoachEntry {
        var sample = FormaWidgetDataManager.makeSampleSnapshot()
        sample.coachName = "Алекс"
        sample.coachBadgeEmoji = "⚡"
        sample.coachAvatarAssetName = "CoachAlexAvatar"
        sample.coachAdvice = "Держите темп! До цели по шагам осталось совсем немного."
        return FormaCoachEntry(date: Date(), snapshot: sample)
    }
    
    public func getSnapshot(in context: Context, completion: @escaping (FormaCoachEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
        } else {
            completion(FormaCoachEntry())
        }
    }
    
    public func getTimeline(in context: Context, completion: @escaping (Timeline<FormaCoachEntry>) -> Void) {
        let entry = FormaCoachEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

public struct FormaCoachWidget: Widget {
    public let kind: String = "FormaCoachWidget"
    
    public init() {}
    
    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FormaCoachTimelineProvider()) { entry in
            FormaCoachWidgetEntryView(entry: entry)
                .containerBackground(Color(red: 18/255, green: 20/255, blue: 28/255), for: .widget)
        }
        .configurationDisplayName("ИИ-Тренер")
        .description("Персональные советы, мотивация и рекомендации от вашего ИИ-наставника.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryRectangular
        ])
    }
}

public struct FormaCoachWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    public let entry: FormaCoachEntry
    
    private var snapshot: FormaWidgetDataSnapshot {
        entry.snapshot
    }
    
    public var body: some View {
        switch family {
        case .systemSmall:
            smallCoachView
        case .systemMedium:
            mediumCoachView
        case .accessoryRectangular:
            lockScreenRectangularView
        default:
            smallCoachView
        }
    }
    
    // MARK: - Home Screen: Small Widget
    private var smallCoachView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(snapshot.coachAvatarAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color(red: 50/255, green: 215/255, blue: 75/255), lineWidth: 1.5))
                
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 3) {
                        Text(snapshot.coachName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                        Text(snapshot.coachBadgeEmoji)
                    }
                    Text("ИИ-Наставник")
                        .font(.system(size: 9))
                        .foregroundColor(Color.white.opacity(0.6))
                }
                
                Spacer()
            }
            
            Spacer()
            
            Text(snapshot.coachAdvice)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(3)
                .lineSpacing(2)
            
            HStack {
                Text("🔥 \(snapshot.stepsToday) шаг")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color(red: 50/255, green: 215/255, blue: 75/255))
                Spacer()
                Text("Online")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.green)
            }
        }
        .padding(12)
    }
    
    // MARK: - Home Screen: Medium Widget
    private var mediumCoachView: some View {
        HStack(spacing: 14) {
            // Аватар тренера
            VStack(spacing: 6) {
                Image(snapshot.coachAvatarAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 58, height: 58)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color(red: 50/255, green: 215/255, blue: 75/255), lineWidth: 2))
                    .shadow(color: Color(red: 50/255, green: 215/255, blue: 75/255).opacity(0.3), radius: 6)
                
                HStack(spacing: 3) {
                    Text(snapshot.coachName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                    Text(snapshot.coachBadgeEmoji)
                        .font(.system(size: 10))
                }
            }
            .frame(width: 70)
            
            // Правая часть с советом
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("СОВЕТ ДНЯ ОТ ТРЕНЕРА")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(Color(red: 50/255, green: 215/255, blue: 75/255))
                    Spacer()
                    Text("FORMA AI")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.4))
                }
                
                Text(snapshot.coachAdvice)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(3)
                    .lineSpacing(2)
                
                Spacer()
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.walk")
                        Text("\(snapshot.stepsToday)")
                    }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.8))
                    
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                        Text("\(Int(snapshot.activeCalories)) ккал")
                    }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(red: 255/255, green: 69/255, blue: 58/255))
                    
                    Spacer()
                    
                    HStack(spacing: 3) {
                        Image(systemName: "bubble.left.fill")
                        Text("Чат")
                    }
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color(red: 50/255, green: 215/255, blue: 75/255))
                }
            }
        }
        .padding(14)
    }
    
    // MARK: - Lock Screen: Rectangular
    private var lockScreenRectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text("\(snapshot.coachBadgeEmoji) Тренер \(snapshot.coachName):")
                    .font(.system(size: 11, weight: .bold))
            }
            
            Text(snapshot.coachAdvice)
                .font(.system(size: 11))
                .foregroundColor(Color.white.opacity(0.8))
                .lineLimit(2)
        }
    }
}
