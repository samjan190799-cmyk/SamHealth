import SwiftUI
import WidgetKit
import AppIntents

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
        var sample = FormaWidgetDataManager.makeSampleSnapshot()
        sample.waterConsumed = 1750.0
        sample.waterGoal = 2500.0
        sample.caloriesConsumed = 1850.0
        sample.totalCaloriesBurned = 2200.0
        sample.energyBalance = -350.0
        return FormaHydrationEntry(date: Date(), snapshot: sample)
    }
    
    public func getSnapshot(in context: Context, completion: @escaping (FormaHydrationEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
        } else {
            completion(FormaHydrationEntry())
        }
    }
    
    public func getTimeline(in context: Context, completion: @escaping (Timeline<FormaHydrationEntry>) -> Void) {
        let entry = FormaHydrationEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
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
                .containerBackground(Color(red: 16/255, green: 20/255, blue: 28/255), for: .widget)
        }
        .configurationDisplayName("Вода и ИИ-Сканер")
        .description("Интерактивный трекинг гидратации в 1 касание и быстрый запуск ИИ-сканера еды.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
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
        case .accessoryRectangular:
            lockScreenRectangularView
        case .accessoryInline:
            lockScreenInlineView
        default:
            smallHydrationView
        }
    }
    
    // MARK: - Home Screen: Small Widget (Интерактивный с кнопками +250 и ИИ-Камера)
    private var smallHydrationView: some View {
        let waterPct = Int(min(snapshot.waterConsumed / max(1.0, snapshot.waterGoal) * 100.0, 999.0))
        let waterRatio = min(snapshot.waterConsumed / max(1.0, snapshot.waterGoal), 1.0)
        
        return VStack(alignment: .leading, spacing: 6) {
            // Верхняя плашка: Иконка + Процент
            HStack {
                ZStack {
                    Circle()
                        .fill(Color(red: 0/255, green: 200/255, blue: 255/255).opacity(0.2))
                        .frame(width: 28, height: 28)
                    Image(systemName: "drop.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(red: 0/255, green: 215/255, blue: 255/255))
                }
                
                Spacer()
                
                Text("\(waterPct)%")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(Color(red: 0/255, green: 220/255, blue: 255/255))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(Color(red: 0/255, green: 200/255, blue: 255/255).opacity(0.15))
                    .clipShape(Capsule())
            }
            
            Spacer(minLength: 0)
            
            // Числовые показатели
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(Int(snapshot.waterConsumed))")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    Text("мл")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(red: 0/255, green: 215/255, blue: 255/255))
                }
                
                Text("из \(Int(snapshot.waterGoal)) мл")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.55))
            }
            
            // Градиентная полоска прогресса
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
            
            Spacer(minLength: 0)
            
            // ИНТЕРАКТИВНЫЙ ДОК: Кнопка +250 мл (AppIntent) и Кнопка ИИ Камера
            HStack(spacing: 6) {
                Button(intent: AddWaterWidgetIntent(amountMl: 250)) {
                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .black))
                        Text("250")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0/255, green: 180/255, blue: 240/255), Color(red: 0/255, green: 130/255, blue: 220/255)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
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
        .widgetURL(URL(string: "forma://water")!)
    }
    
    // MARK: - Home Screen: Medium Widget (Интерактивный с +250, +500 и кнопкой запуска ИИ-сканера)
    private var mediumHydrationView: some View {
        let waterPct = Int(min(snapshot.waterConsumed / max(1.0, snapshot.waterGoal) * 100.0, 999.0))
        let waterRatio = min(snapshot.waterConsumed / max(1.0, snapshot.waterGoal), 1.0)
        
        return HStack(spacing: 12) {
            // ЛЕВАЯ КОЛОНКА: Водный баланс + быстрые кнопки налива
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "drop.fill")
                        .foregroundColor(Color(red: 0/255, green: 215/255, blue: 255/255))
                        .font(.system(size: 11))
                    Text("ГИДРАТАЦИЯ")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(Color.white.opacity(0.5))
                    Spacer()
                    Text("\(waterPct)%")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(red: 0/255, green: 215/255, blue: 255/255))
                }
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(snapshot.waterConsumed))")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    Text("/ \(Int(snapshot.waterGoal)) мл")
                        .font(.system(size: 11, weight: .semibold))
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
                                    colors: [Color(red: 0/255, green: 229/255, blue: 255/255), Color(red: 0/255, green: 135/255, blue: 255/255)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(5, geo.size.width * CGFloat(waterRatio)), height: 5)
                    }
                }
                .frame(height: 5)
                
                Spacer(minLength: 0)
                
                // Интерактивные кнопки быстрого добавления воды
                HStack(spacing: 6) {
                    Button(intent: AddWaterWidgetIntent(amountMl: 250)) {
                        HStack(spacing: 2) {
                            Image(systemName: "plus")
                                .font(.system(size: 8, weight: .bold))
                            Text("250 мл")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(Color(red: 0/255, green: 160/255, blue: 235/255).opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    
                    Button(intent: AddWaterWidgetIntent(amountMl: 500)) {
                        HStack(spacing: 2) {
                            Image(systemName: "plus")
                                .font(.system(size: 8, weight: .bold))
                            Text("500 мл")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(Color(red: 0/255, green: 215/255, blue: 255/255))
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(Color(red: 0/255, green: 215/255, blue: 255/255).opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
                .background(Color.white.opacity(0.12))
            
            // ПРАВАЯ КОЛОНКА: Энергобаланс + Большая кнопка ИИ Камеры
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: snapshot.energyBalance < 0 ? "flame.fill" : "bolt.fill")
                        .foregroundColor(snapshot.energyBalance < 0 ? .green : .orange)
                        .font(.system(size: 11))
                    Text("ЭНЕРГОБАЛАНС")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(Color.white.opacity(0.5))
                }
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(snapshot.energyBalance))")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(snapshot.energyBalance < 0 ? .green : .orange)
                    Text("ккал")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.55))
                }
                
                Text("Съедено: \(Int(snapshot.caloriesConsumed)) • Сожжено: \(Int(snapshot.totalCaloriesBurned))")
                    .font(.system(size: 9))
                    .foregroundColor(Color.white.opacity(0.6))
                    .lineLimit(1)
                
                Spacer(minLength: 0)
                
                // Кнопка быстрого запуска ИИ-сканера еды (через Link)
                Link(destination: URL(string: "forma://scan")!) {
                    HStack(spacing: 5) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 12, weight: .bold))
                        Text("ИИ Сканер еды")
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
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
    }
    
    // MARK: - Lock Screen: Circular
    private var lockScreenCircularView: some View {
        let waterPct = min(Double(snapshot.waterConsumed) / Double(max(1.0, snapshot.waterGoal)), 1.0)
        return Gauge(value: waterPct) {
            Image(systemName: "drop.fill")
                .font(.system(size: 10, weight: .bold))
        } currentValueLabel: {
            Text("\(Int(snapshot.waterConsumed))")
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .gaugeStyle(.accessoryCircular)
    }
    
    // MARK: - Lock Screen: Rectangular (БЕЗ ДУБЛИРОВАНИЯ ВОДЫ + ИНТЕРАКТИВНОСТЬ)
    private var lockScreenRectangularView: some View {
        let waterPct = Int(min(snapshot.waterConsumed / max(1.0, snapshot.waterGoal) * 100.0, 999.0))
        let waterRatio = min(snapshot.waterConsumed / max(1.0, snapshot.waterGoal), 1.0)
        
        return VStack(alignment: .leading, spacing: 3) {
            // Строка 1: Вода с иконкой капли и процентом выполнения
            HStack(spacing: 4) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("\(Int(snapshot.waterConsumed)) / \(Int(snapshot.waterGoal)) мл")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                Spacer()
                Text("\(waterPct)%")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
            }
            
            // Строка 2: Нативная шкала прогресса без лагов SpringBoard
            ProgressView(value: min(max(0.04, waterRatio), 1.0), total: 1.0)
                .progressViewStyle(LinearProgressViewStyle(tint: .white))
                .background(Color.white.opacity(0.25))
                .cornerRadius(2)
                .frame(height: 3.5)
            
            // Строка 3: Информационная строка без повтора остатка воды!
            // Показываем энергобаланс дня и быструю кнопку добавления +250
            HStack(spacing: 6) {
                if snapshot.energyBalance != 0 {
                    HStack(spacing: 2) {
                        Image(systemName: snapshot.energyBalance < 0 ? "flame.fill" : "bolt.fill")
                            .font(.system(size: 8))
                        Text("\(Int(snapshot.energyBalance)) ккал")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                    }
                } else {
                    HStack(spacing: 2) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 8))
                        Text("\(snapshot.stepsToday) шагов")
                            .font(.system(size: 9, weight: .semibold))
                    }
                }
                
                Spacer()
                
                // Интерактивная кнопка прямо на экране блокировки
                Button(intent: AddWaterWidgetIntent(amountMl: 250)) {
                    HStack(spacing: 2) {
                        Image(systemName: "plus")
                            .font(.system(size: 8, weight: .heavy))
                        Text("250 мл")
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
        Text("💧 \(Int(snapshot.waterConsumed))/\(Int(snapshot.waterGoal)) мл • 🔥 \(Int(snapshot.energyBalance)) ккал")
    }
}
