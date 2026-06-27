import SwiftUI

struct TrendsView: View {
    @EnvironmentObject var health: HealthKitManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                // Заголовок
                HStack {
                    Text("Trends")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 12)
                
                // 1. График шагов за неделю
                VStack(alignment: .leading, spacing: 16) {
                    Text("Шаги за неделю")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                    
                    if health.weeklySteps.isEmpty {
                        Text("Нет данных о шагах за эту неделю")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
                    } else {
                        // Кастомный график шагов
                        HStack(alignment: .bottom, spacing: 12) {
                            let maxSteps = Double(health.weeklySteps.map { $0.steps }.max() ?? 1)
                            
                            ForEach(health.weeklySteps) { dayData in
                                VStack(spacing: 8) {
                                    Text("\(dayData.steps)")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(Theme.textPrimary)
                                    
                                    // Столбец
                                    let heightPercent = maxSteps > 0 ? Double(dayData.steps) / maxSteps : 0.0
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [Theme.exerciseColor, Theme.exerciseColor.opacity(0.6)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .frame(height: CGFloat(heightPercent * 100 + 10))
                                    
                                    Text(dayData.day)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(Theme.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                .premiumCard()
                .padding(.horizontal)
                
                // 2. Карточка веса и тренда
                VStack(alignment: .leading, spacing: 16) {
                    Text("Контроль веса")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Текущий вес")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                            Text(health.currentWeight > 0 ? String(format: "%.1f кг", health.currentWeight) : "-- кг")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.textPrimary)
                        }
                        
                        Spacer()
                        
                        // Иконка тренда
                        HStack(spacing: 8) {
                            Image(systemName: health.weightTrend.arrow)
                                .font(.system(size: 20, weight: .bold))
                            Text(trendLabel(health.weightTrend))
                                .font(.subheadline)
                                .bold()
                        }
                        .foregroundColor(health.weightTrend.color)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(health.weightTrend.color.opacity(0.08))
                        .cornerRadius(20)
                    }
                }
                .premiumCard()
                .padding(.horizontal)
                
                // 3. Дополнительные инсайты
                VStack(alignment: .leading, spacing: 16) {
                    Text("Инсайты здоровья")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                    
                    HStack(spacing: 16) {
                        // Сон за сутки
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "moon.stars.fill")
                                    .foregroundColor(Theme.sleepColor)
                                Text("Сон")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(Theme.textSecondary)
                            }
                            Text(String(format: "%.1f ч", health.sleepDuration))
                                .font(.title2)
                                .bold()
                                .foregroundColor(Theme.textPrimary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Theme.background)
                        .cornerRadius(16)
                        
                        // Пульс
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "heart.fill")
                                    .foregroundColor(Theme.pulseColor)
                                Text("Пульс")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(Theme.textSecondary)
                            }
                            Text(health.heartRate > 0 ? "\(health.heartRate) bpm" : "-- bpm")
                                .font(.title2)
                                .bold()
                                .foregroundColor(Theme.textPrimary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Theme.background)
                        .cornerRadius(16)
                    }
                }
                .premiumCard()
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
        .background(Theme.background.ignoresSafeArea())
    }
    
    private func trendLabel(_ trend: WeightTrendType) -> String {
        switch trend {
        case .up: return "Набор"
        case .down: return "Снижение"
        case .stable: return "Стабилен"
        }
    }
}
