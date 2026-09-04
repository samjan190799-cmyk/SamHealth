import SwiftUI

public struct DigestiveBalanceCard: View {
    let solidStreak: Int
    let mealsSinceLastSoup: Int
    let hoursSinceLastSoup: Double?
    let lastSoupMeal: LoggedMealRecord?
    let status: DigestiveBalanceStatus
    let recommendationText: String
    let onOpenSoupCatalog: () -> Void
    let onAskNutritionist: () -> Void
    
    public init(
        solidStreak: Int,
        mealsSinceLastSoup: Int,
        hoursSinceLastSoup: Double?,
        lastSoupMeal: LoggedMealRecord?,
        status: DigestiveBalanceStatus,
        recommendationText: String,
        onOpenSoupCatalog: @escaping () -> Void,
        onAskNutritionist: @escaping () -> Void
    ) {
        self.solidStreak = solidStreak
        self.mealsSinceLastSoup = mealsSinceLastSoup
        self.hoursSinceLastSoup = hoursSinceLastSoup
        self.lastSoupMeal = lastSoupMeal
        self.status = status
        self.recommendationText = recommendationText
        self.onOpenSoupCatalog = onOpenSoupCatalog
        self.onAskNutritionist = onAskNutritionist
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Верхний ряд: Заголовок и статус ЖКТ
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "cup.and.saucer.fill")
                        .foregroundColor(Color(red: 0/255, green: 210/255, blue: 255/255))
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Баланс ЖКТ и консистенция")
                            .font(.headline)
                            .foregroundColor(Theme.textPrimary)
                        Text("Жидкая пища vs «сухомятка»")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                
                Spacer()
                
                // Бейдж статуса ЖКТ
                HStack(spacing: 4) {
                    Image(systemName: status.icon)
                        .font(.system(size: 11, weight: .bold))
                    Text(status.shortBadge)
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(status.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(status.color.opacity(0.15))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(status.color.opacity(0.3), lineWidth: 1)
                )
            }
            
            // Метрические пилюли: стрик плотной пищи и время с последнего супа
            HStack(spacing: 10) {
                // 1. Стрик плотной пищи
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Text("Плотных блюд подряд")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Theme.textSecondary)
                    }
                    
                    Text("\(solidStreak) \(streakMealsWord(for: solidStreak))")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(solidStreak >= 3 ? .orange : Theme.textPrimary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.04))
                .cornerRadius(14)
                
                // 2. Последний суп или бульон
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption2)
                            .foregroundColor(Color(red: 0/255, green: 210/255, blue: 255/255))
                        Text("Последнее жидкое")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Theme.textSecondary)
                    }
                    
                    Text(lastSoupTimeString)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(hoursSinceLastSoup != nil && hoursSinceLastSoup! > 24 ? .orange : Theme.textPrimary)
                        .lineLimit(1)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.04))
                .cornerRadius(14)
            }
            
            // Клинический совет и вердикт ИИ-диетолога
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundColor(status.color)
                    Text("Вердикт нутрициолога:")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                }
                
                Text(recommendationText)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textPrimary.opacity(0.9))
                    .lineSpacing(3)
                    .multilineTextAlignment(.leading)
            }
            .padding(12)
            .background(status.color.opacity(0.08))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(status.color.opacity(0.2), lineWidth: 1)
            )
            
            // Кнопки быстрых действий
            HStack(spacing: 10) {
                // Кнопка быстрого добавления супа/бульона
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    onOpenSoupCatalog()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Выбрать суп / бульон")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0/255, green: 210/255, blue: 255/255), Color(red: 0/255, green: 145/255, blue: 255/255)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(14)
                    .shadow(color: Color(red: 0/255, green: 210/255, blue: 255/255).opacity(0.3), radius: 6)
                }
                
                // Кнопка консультации с нутрициологом
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    onAskNutritionist()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                        Text("AI-Совет")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
            }
        }
        .premiumCard()
    }
    
    private var lastSoupTimeString: String {
        guard let hours = hoursSinceLastSoup else {
            return "Не зафиксирован"
        }
        if hours < 1 {
            return "Только что"
        } else if hours < 24 {
            return "\(Int(hours)) ч назад"
        } else {
            let days = Int(hours / 24.0)
            return "\(days) дн назад"
        }
    }
    
    private func streakMealsWord(for count: Int) -> String {
        let mod10 = count % 10
        let mod100 = count % 100
        if mod100 >= 11 && mod100 <= 19 {
            return "приемов"
        }
        switch mod10 {
        case 1: return "прием"
        case 2, 3, 4: return "приема"
        default: return "приемов"
        }
    }
}
