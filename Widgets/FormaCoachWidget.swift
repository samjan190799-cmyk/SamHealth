import SwiftUI
import WidgetKit
import AppIntents

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
        sample.coachAdvice = "Держите темп! До цели по шагам и гидратации осталось совсем немного."
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
                .containerBackground(Color(red: 16/255, green: 20/255, blue: 28/255), for: .widget)
        }
        .configurationDisplayName("ИИ-Тренер")
        .description("Персональные советы, мотивация и быстрый запуск ИИ-сканера еды.")
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
    
    // MARK: - Home Screen: Small Widget (Интерактивный с быстрой кнопкой сканера)
    private var smallCoachView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(snapshot.coachAvatarAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color(red: 50/255, green: 215/255, blue: 75/255), lineWidth: 1.5))
                
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 3) {
                        Text(snapshot.coachName)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        Text(snapshot.coachBadgeEmoji)
                            .font(.system(size: 10))
                    }
                    Text("ИИ-Наставник")
                        .font(.system(size: 9))
                        .foregroundColor(Color.white.opacity(0.6))
                }
                
                Spacer()
            }
            
            Spacer(minLength: 0)
            
            Text(snapshot.coachAdvice)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(Color.white.opacity(0.95))
                .lineLimit(3)
                .lineSpacing(1.5)
            
            Spacer(minLength: 0)
            
            // Интерактивная кнопка: Запуск ИИ Сканера еды
            Button(intent: OpenFoodScannerWidgetIntent()) {
                HStack(spacing: 4) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 11, weight: .bold))
                    Text("ИИ Сканер")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .background(
                    LinearGradient(
                        colors: [Color(red: 45/255, green: 200/255, blue: 100/255), Color(red: 25/255, green: 155/255, blue: 85/255)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(11)
        .widgetURL(URL(string: "forma://coach")!)
    }
    
    // MARK: - Home Screen: Medium Widget (Совет тренера + Интерактивные кнопки сканера и воды)
    private var mediumCoachView: some View {
        HStack(spacing: 12) {
            // Аватар тренера
            VStack(spacing: 5) {
                Image(snapshot.coachAvatarAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 52, height: 52)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color(red: 50/255, green: 215/255, blue: 75/255), lineWidth: 2))
                    .shadow(color: Color(red: 50/255, green: 215/255, blue: 75/255).opacity(0.3), radius: 6)
                
                HStack(spacing: 2) {
                    Text(snapshot.coachName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                    Text(snapshot.coachBadgeEmoji)
                        .font(.system(size: 10))
                }
                
                Text("Online")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.green)
            }
            .frame(width: 65)
            
            // Правая часть с советом и интерактивными кнопками
            VStack(alignment: .leading, spacing: 5) {
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
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(3)
                    .lineSpacing(1.5)
                
                Spacer(minLength: 0)
                
                // Интерактивные кнопки: Чат с тренером и ИИ Сканер еды
                HStack(spacing: 6) {
                    Link(destination: URL(string: "forma://coach")!) {
                        HStack(spacing: 3) {
                            Image(systemName: "bubble.left.fill")
                                .font(.system(size: 9))
                            Text("Чат")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(Color(red: 50/255, green: 215/255, blue: 75/255))
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(Color(red: 50/255, green: 215/255, blue: 75/255).opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    
                    Button(intent: AddWaterWidgetIntent(amountMl: 250)) {
                        HStack(spacing: 2) {
                            Image(systemName: "drop.fill")
                                .font(.system(size: 8))
                            Text("+250 мл")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(Color(red: 0/255, green: 215/255, blue: 255/255))
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(Color(red: 0/255, green: 200/255, blue: 255/255).opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    
                    Link(destination: URL(string: "forma://scan")!) {
                        HStack(spacing: 3) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 10, weight: .bold))
                            Text("ИИ Сканер")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 45/255, green: 200/255, blue: 100/255), Color(red: 25/255, green: 155/255, blue: 85/255)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
    }
    
    // MARK: - Lock Screen: Rectangular
    private var lockScreenRectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text("\(snapshot.coachBadgeEmoji) \(snapshot.coachName):")
                    .font(.system(size: 11, weight: .bold))
                Spacer()
                Text("FORMA")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.5))
            }
            
            Text(snapshot.coachAdvice)
                .font(.system(size: 10.5))
                .foregroundColor(Color.white.opacity(0.85))
                .lineLimit(2)
        }
    }
}
