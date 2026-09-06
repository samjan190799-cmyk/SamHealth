import SwiftUI

// MARK: - Карточка трекера кофеина и окна сна (Caffeine Safety & Sleep Window)
@MainActor
public struct CaffeineTrackerCardView: View {
    @ObservedObject var health = HealthKitManager.shared
    @State private var showingInfoSheet = false
    
    private var progressToLimit: Double {
        min(1.0, health.caffeineConsumedTodayMg / health.caffeineSafeDailyLimitMg)
    }
    
    private var progressColor: Color {
        if health.caffeineConsumedTodayMg > health.caffeineSafeDailyLimitMg {
            return .red
        } else if health.caffeineConsumedTodayMg >= 300 {
            return .orange
        } else {
            return Color(red: 215/255, green: 155/255, blue: 110/255)
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Заголовок карточки
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "cup.and.saucer.fill")
                        .foregroundColor(Color(red: 215/255, green: 155/255, blue: 110/255))
                    Text("Кофеин и Окно сна")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                }
                
                Spacer()
                
                let status = health.caffeineSleepImpactStatus
                HStack(spacing: 4) {
                    Text(status.emoji)
                    Text(status.title)
                        .font(.caption2)
                        .bold()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(status.badgeColor.opacity(0.15))
                .foregroundColor(status.badgeColor)
                .cornerRadius(10)
            }
            
            // Дневная шкала кофеина
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Выпито сегодня:")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    
                    Spacer()
                    
                    Text("\(Int(health.caffeineConsumedTodayMg)) / \(Int(health.caffeineSafeDailyLimitMg)) мг")
                        .font(.caption)
                        .bold()
                        .foregroundColor(progressColor)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(progressColor)
                            .frame(width: geo.size.width * CGFloat(progressToLimit), height: 8)
                    }
                }
                .frame(height: 8)
            }
            
            // 2 ключевых показателя: В крови сейчас и Время сна
            HStack(spacing: 10) {
                // Показатель 1: В крови сейчас
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.heart.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Text("В крови сейчас")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                    
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(Int(health.caffeineActiveInBloodMg))")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                        Text("мг")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.white.opacity(0.04))
                .cornerRadius(14)
                
                // Показатель 2: Окно глубокого сна
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "moon.stars.fill")
                            .font(.caption2)
                            .foregroundColor(.indigo)
                        Text("Окно сна")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                    
                    if let cutoff = health.caffeineSleepCutoffDate {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("После \(formatTime(cutoff))")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(health.caffeineSleepImpactStatus.badgeColor)
                        }
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("Сон защищен")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(.green)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.white.opacity(0.04))
                .cornerRadius(14)
            }
            
            // Подсказка о качестве сна
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.caption)
                    .foregroundColor(health.caffeineSleepImpactStatus.badgeColor)
                    .padding(.top, 1)
                
                Text(health.caffeineSleepImpactStatus.recommendation)
                    .font(.caption2)
                    .foregroundColor(Theme.textPrimary.opacity(0.85))
                    .lineSpacing(2)
            }
            .padding(10)
            .background(health.caffeineSleepImpactStatus.badgeColor.opacity(0.08))
            .cornerRadius(12)
        }
        .premiumCard()
    }
}
