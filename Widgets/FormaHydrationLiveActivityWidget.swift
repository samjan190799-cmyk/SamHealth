import SwiftUI
import WidgetKit
import ActivityKit

public struct FormaHydrationLiveActivityWidget: Widget {
    public init() {}
    
    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: FormaHydrationActivityAttributes.self) { context in
            // MARK: - Lock Screen & StandBy View
            LockScreenHydrationLiveActivityView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            // MARK: - Dynamic Island View
            DynamicIsland {
                // Expanded Leading
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Text(context.state.lastBeverageEmoji)
                            .font(.system(size: 16))
                            .padding(5)
                            .background(Color.cyan.opacity(0.15))
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(context.state.lastBeverageName)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                            
                            let formatter = DateFormatter()
                            let _ = formatter.dateFormat = "HH:mm"
                            Text("Выпито в \(formatter.string(from: context.state.lastLogDate))")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.65))
                        }
                    }
                    .padding(.leading, 4)
                }
                
                // Expanded Trailing
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 1) {
                        HStack(spacing: 3) {
                            Text("\(Int(context.state.waterConsumedMl))")
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                                .foregroundColor(.cyan)
                            Text("/ \(Int(context.state.waterGoalMl)) мл")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Text("\(context.state.progressPercent)% от нормы")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(context.state.progressPercent >= 100 ? .green : .white.opacity(0.6))
                    }
                    .padding(.trailing, 4)
                }
                
                // Expanded Bottom
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        // Полоса прогресса
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.12))
                                    .frame(height: 6)
                                
                                let fillW = geo.size.width * CGFloat(min(Double(context.state.progressPercent) / 100.0, 1.0))
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(red: 0/255, green: 229/255, blue: 255/255), Color(red: 0/255, green: 135/255, blue: 255/255)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(fillW, 8), height: 6)
                            }
                        }
                        .frame(height: 6)
                        
                        HStack(spacing: 10) {
                            // Окно сна / Кофеин
                            if !context.state.sleepCutoffStr.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "moon.stars.fill")
                                        .foregroundColor(Color(red: 160/255, green: 130/255, blue: 255/255))
                                        .font(.system(size: 9))
                                    Text("Сон: \(context.state.sleepCutoffStr)")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                            
                            Spacer()
                            
                            // Быстрая кнопка налива +250 мл прямо с острова
                            Link(destination: URL(string: "forma://water?amount=250")!) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 10))
                                    Text("+250 мл")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(.black)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.cyan)
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                // Компактный вид слева: Капля и процент
                HStack(spacing: 3) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color(red: 0/255, green: 220/255, blue: 255/255))
                    Text("\(context.state.progressPercent)%")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.leading, 4)
            } compactTrailing: {
                // Компактный вид справа: Объем
                Text("\(Int(context.state.waterConsumedMl)) мл")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0/255, green: 220/255, blue: 255/255))
                    .padding(.trailing, 4)
            } minimal: {
                // Минимальный значок капли
                Image(systemName: "drop.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0/255, green: 220/255, blue: 255/255))
            }
        }
    }
}

// MARK: - Lock Screen Виджет Живой Активности
private struct LockScreenHydrationLiveActivityView: View {
    let context: ActivityViewContext<FormaHydrationActivityAttributes>
    
    var body: some View {
        VStack(spacing: 12) {
            // Верхняя плашка
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0/255, green: 180/255, blue: 255/255).opacity(0.2))
                            .frame(width: 32, height: 32)
                        Image(systemName: "drop.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color(red: 0/255, green: 220/255, blue: 255/255))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Баланс воды и кофеина")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Последний: \(context.state.lastBeverageEmoji) \(context.state.lastBeverageName)")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.65))
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(Int(context.state.waterConsumedMl))")
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .foregroundColor(.cyan)
                        Text("/ \(Int(context.state.waterGoalMl)) мл")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Text("\(context.state.progressPercent)% нормы")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(context.state.progressPercent >= 100 ? .green : .white.opacity(0.6))
                }
            }
            
            // Прогресс бар
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 8)
                    
                    let fillW = geo.size.width * CGFloat(min(Double(context.state.progressPercent) / 100.0, 1.0))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0/255, green: 229/255, blue: 255/255), Color(red: 0/255, green: 135/255, blue: 255/255)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(fillW, 10), height: 8)
                }
            }
            .frame(height: 8)
            
            // Нижняя панель действий
            HStack {
                if !context.state.sleepCutoffStr.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: "moon.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(red: 170/255, green: 140/255, blue: 255/255))
                        Text("Окно сна: \(context.state.sleepCutoffStr)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                } else {
                    Text("Поддерживайте баланс в течение дня")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.55))
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Link(destination: URL(string: "forma://water?amount=150")!) {
                        Text("+150")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(10)
                    }
                    
                    Link(destination: URL(string: "forma://water?amount=250")!) {
                        HStack(spacing: 3) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .black))
                            Text("250 мл")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.cyan)
                        .cornerRadius(10)
                    }
                }
            }
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color(red: 15/255, green: 22/255, blue: 35/255), Color(red: 8/255, green: 12/255, blue: 22/255)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
