import SwiftUI
import WidgetKit
import ActivityKit

public struct FormaWorkoutLiveActivityWidget: Widget {
    public init() {}
    
    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: FormaWorkoutActivityAttributes.self) { context in
            // MARK: - Баннер на экране блокировки (Lock Screen / StandBy)
            LockScreenLiveActivityView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            // MARK: - Dynamic Island (iPhone 14 Pro / 15 / 16 / 17)
            DynamicIsland {
                // Expanded Leading
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        Image(systemName: context.attributes.workoutIcon)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(red: 0/255, green: 229/255, blue: 255/255))
                            .padding(6)
                            .background(Color(red: 0/255, green: 229/255, blue: 255/255).opacity(0.15))
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.state.exerciseName ?? context.attributes.workoutType)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            if context.state.isPaused {
                                Text("ПАУЗА")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundColor(.orange)
                            } else {
                                Text(timerInterval: context.attributes.startDate...Date.distantFuture, countsDown: false)
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundColor(Color.white.opacity(0.8))
                            }
                        }
                    }
                    .padding(.leading, 4)
                }
                
                // Expanded Trailing
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 12))
                                .foregroundColor(pulseColor(for: context.state.heartRate))
                            
                            Text(context.state.heartRate > 0 ? "\(context.state.heartRate)" : "--")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("BPM")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        if context.state.totalSets > 0 {
                            Text("Сет \(context.state.currentSet)/\(context.state.totalSets)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(red: 0/255, green: 229/255, blue: 255/255))
                        }
                    }
                    .padding(.trailing, 4)
                }
                
                // Expanded Bottom: 3-column stats
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        // Калории
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                                .font(.caption2)
                            Text("\(context.state.calories) ккал")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(10)
                        
                        // Дистанция
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .foregroundColor(Color(red: 0/255, green: 229/255, blue: 255/255))
                                .font(.caption2)
                            let km = context.state.distanceMeters / 1000.0
                            Text(String(format: "%.2f км", km))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(10)
                        
                        // Шаги
                        HStack(spacing: 4) {
                            Image(systemName: "figure.walk")
                                .foregroundColor(.green)
                                .font(.caption2)
                            Text("\(context.state.steps)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(10)
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                // Compact Leading: Иконка тренировки с неоновым акцентом
                HStack(spacing: 4) {
                    Image(systemName: context.attributes.workoutIcon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(red: 0/255, green: 229/255, blue: 255/255))
                }
            } compactTrailing: {
                // Compact Trailing: Таймер активности или пульс
                if context.state.isPaused {
                    Text("⏸")
                        .font(.system(size: 11))
                } else if context.state.heartRate > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 9))
                            .foregroundColor(pulseColor(for: context.state.heartRate))
                        Text("\(context.state.heartRate)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                } else {
                    Text(timerInterval: context.attributes.startDate...Date.distantFuture, countsDown: false)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 44)
                }
            } minimal: {
                // Minimal: Пульсирующая иконка активности
                Image(systemName: context.attributes.workoutIcon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(red: 0/255, green: 229/255, blue: 255/255))
            }
        }
    }
    
    private func pulseColor(for bpm: Int) -> Color {
        if bpm >= 160 { return .red }
        if bpm >= 135 { return .orange }
        if bpm >= 100 { return .green }
        return Color(red: 0/255, green: 229/255, blue: 255/255)
    }
}

// MARK: - Lock Screen / StandBy View
private struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<FormaWorkoutActivityAttributes>
    
    var body: some View {
        VStack(spacing: 12) {
            // Верхняя строка: Логотип, название активности и статус
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0/255, green: 229/255, blue: 255/255).opacity(0.2))
                        .frame(width: 38, height: 38)
                    
                    Image(systemName: context.attributes.workoutIcon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(red: 0/255, green: 229/255, blue: 255/255))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Forma • \(context.state.exerciseName ?? context.attributes.workoutType)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    
                    if context.state.isPaused {
                        Text("На паузе")
                            .font(.caption2.bold())
                            .foregroundColor(.orange)
                    } else {
                        Text(timerInterval: context.attributes.startDate...Date.distantFuture, countsDown: false)
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.85))
                    }
                }
                
                Spacer()
                
                // Пульс
                if context.state.heartRate > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                        Text("\(context.state.heartRate)")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("BPM")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.12))
            
            // Нижняя строка метрик
            HStack(spacing: 16) {
                // Калории
                VStack(alignment: .leading, spacing: 2) {
                    Text("Калории")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                        Text("\(context.state.calories) ккал")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Дистанция
                VStack(alignment: .leading, spacing: 2) {
                    Text("Дистанция")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    HStack(spacing: 3) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(red: 0/255, green: 229/255, blue: 255/255))
                        let km = context.state.distanceMeters / 1000.0
                        Text(String(format: "%.2f км", km))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Шаги
                VStack(alignment: .leading, spacing: 2) {
                    Text("Шаги")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    HStack(spacing: 3) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 11))
                            .foregroundColor(.green)
                        Text("\(context.state.steps)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(
            ZStack {
                Color(red: 18/255, green: 20/255, blue: 26/255)
                LinearGradient(
                    colors: [
                        Color(red: 0/255, green: 229/255, blue: 255/255).opacity(0.08),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
    }
}
