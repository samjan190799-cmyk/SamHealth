import SwiftUI

public struct FoodQualityCard: View {
    let healthScore: Int
    let nutriScore: String?
    let novaGroup: Int?
    let glycemicIndex: String? // "Низкий", "Средний", "Высокий"
    let fiberGrams: Double?
    let sugarGrams: Double?
    let sodiumMg: Double?
    let advice: String?
    
    public init(
        healthScore: Int = 8,
        nutriScore: String? = nil,
        novaGroup: Int? = nil,
        glycemicIndex: String? = nil,
        fiberGrams: Double? = nil,
        sugarGrams: Double? = nil,
        sodiumMg: Double? = nil,
        advice: String? = nil
    ) {
        self.healthScore = healthScore
        self.nutriScore = nutriScore
        self.novaGroup = novaGroup
        self.glycemicIndex = glycemicIndex
        self.fiberGrams = fiberGrams
        self.sugarGrams = sugarGrams
        self.sodiumMg = sodiumMg
        self.advice = advice
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Заголовок карточки
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .foregroundColor(.yellow)
                    Text("Индекс качества еды")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                }
                
                Spacer()
                
                // Главный скор (1-10)
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundColor(scoreColor)
                    Text("\(healthScore)/10")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(scoreColor)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(scoreColor.opacity(0.15))
                )
            }
            
            // Вердикт качества
            Text(qualityVerdict)
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
            
            Divider()
            
            // Метки Nutri-Score, NOVA и Гликемического Индекса
            HStack(spacing: 10) {
                // 1. Nutri-Score
                VStack(alignment: .leading, spacing: 4) {
                    Text("Nutri-Score")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                    
                    let grade = nutriScore ?? derivedNutriScore
                    HStack(spacing: 3) {
                        ForEach(["A", "B", "C", "D", "E"], id: \.self) { letter in
                            Text(letter)
                                .font(.system(size: 11, weight: .black))
                                .foregroundColor(.white)
                                .frame(width: grade == letter ? 22 : 16, height: grade == letter ? 22 : 16)
                                .background(nutriScoreBg(letter: letter, isSelected: grade == letter))
                                .cornerRadius(5)
                                .scaleEffect(grade == letter ? 1.1 : 0.9)
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.04))
                .cornerRadius(12)
                
                // 2. NOVA Group (Степень ультра-обработки)
                VStack(alignment: .leading, spacing: 4) {
                    Text("NOVA (обработка)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                    
                    let nova = novaGroup ?? derivedNovaGroup
                    HStack(spacing: 6) {
                        Text("Группа \(nova)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(novaColor(nova))
                        
                        Text(novaLabel(nova))
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textSecondary)
                            .lineLimit(1)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.04))
                .cornerRadius(12)
            }
            
            // Дополнительные индикаторы (ГИ, клетчатка, сахар)
            HStack(spacing: 8) {
                // ГИ
                MiniNutriChip(
                    icon: "waveform.path.ecg",
                    title: "ГИ (инсулин)",
                    value: glycemicIndex ?? derivedGI,
                    color: giColor(glycemicIndex ?? derivedGI)
                )
                
                // Клетчатка
                if let fiber = fiberGrams {
                    MiniNutriChip(
                        icon: "leaf.fill",
                        title: "Клетчатка",
                        value: "\(Int(fiber)) г",
                        color: fiber >= 5 ? .green : .orange
                    )
                }
                
                // Сахар
                if let sugar = sugarGrams {
                    MiniNutriChip(
                        icon: "cube.fill",
                        title: "Сахар",
                        value: "\(Int(sugar)) г",
                        color: sugar <= 5 ? .green : (sugar <= 15 ? .orange : .red)
                    )
                }
            }
            
            // Персональный совет AI-нутрициолога
            if let tip = advice, !tip.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(Color(red: 0/255, green: 229/255, blue: 255/255))
                        .font(.title3)
                        .padding(.top, 2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Совет нутрициолога:")
                            .font(.caption)
                            .bold()
                            .foregroundColor(Color(red: 0/255, green: 229/255, blue: 255/255))
                        
                        Text(tip)
                            .font(.caption)
                            .foregroundColor(Theme.textPrimary.opacity(0.9))
                            .lineSpacing(3)
                    }
                }
                .padding(12)
                .background(Color(red: 0/255, green: 229/255, blue: 255/255).opacity(0.08))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(red: 0/255, green: 229/255, blue: 255/255).opacity(0.2), lineWidth: 1)
                )
            }
        }
        .premiumCard()
    }
    
    // Вспомогательные вычисления
    private var scoreColor: Color {
        if healthScore >= 8 { return Color.green }
        if healthScore >= 6 { return Color.orange }
        return Color.red
    }
    
    private var qualityVerdict: String {
        switch healthScore {
        case 9...10: return "✨ Эталонное качество: цельные продукты с максимумом нутриентов"
        case 7...8: return "🥗 Сбалансированный прием пищи с хорошим содержанием белка и нутриентов"
        case 5...6: return "⚖️ Умеренное качество: допустимо, но добавьте свежей клетчатки"
        default: return "⚠️ Продукт высокой степени переработки. Контролируйте сахар и соль"
        }
    }
    
    private var derivedNutriScore: String {
        switch healthScore {
        case 9...10: return "A"
        case 7...8: return "B"
        case 5...6: return "C"
        case 3...4: return "D"
        default: return "E"
        }
    }
    
    private var derivedNovaGroup: Int {
        switch healthScore {
        case 8...10: return 1 // Натуральные цельные продукты
        case 6...7: return 2 // Кулинарная обработка
        case 4...5: return 3 // Обработанные продукты
        default: return 4 // Ультра-обработанные
        }
    }
    
    private var derivedGI: String {
        if healthScore >= 8 { return "Низкий" }
        if healthScore >= 5 { return "Средний" }
        return "Высокий"
    }
    
    private func nutriScoreBg(letter: String, isSelected: Bool) -> Color {
        guard isSelected else { return Color.white.opacity(0.12) }
        switch letter {
        case "A": return Color(red: 3/255, green: 129/255, blue: 66/255)
        case "B": return Color(red: 133/255, green: 187/255, blue: 46/255)
        case "C": return Color(red: 254/255, green: 203/255, blue: 3/255)
        case "D": return Color(red: 238/255, green: 129/255, blue: 34/255)
        case "E": return Color(red: 230/255, green: 62/255, blue: 17/255)
        default: return Color.gray
        }
    }
    
    private func novaColor(_ group: Int) -> Color {
        switch group {
        case 1: return Color.green
        case 2: return Color.blue
        case 3: return Color.orange
        default: return Color.red
        }
    }
    
    private func novaLabel(_ group: Int) -> String {
        switch group {
        case 1: return "Цельный"
        case 2: return "Кулинарный"
        case 3: return "Обработанный"
        default: return "Ультра-продукт"
        }
    }
    
    private func giColor(_ gi: String) -> Color {
        if gi.contains("Низк") || gi.contains("Low") { return .green }
        if gi.contains("Сред") || gi.contains("Med") { return .orange }
        return .red
    }
}

// Мини-чип микронутриента
struct MiniNutriChip: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 9))
                    .foregroundColor(Theme.textSecondary)
                Text(value)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .cornerRadius(10)
    }
}
