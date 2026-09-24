import SwiftUI

// MARK: - Интерактивный лист результатов перепроверки норм ИИ
@MainActor
public struct AIBodyCalibrationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var health: HealthKitManager
    
    let result: AIBodyCalibrationResult
    let currentWeight: Double
    let targetWeight: Double
    let somatotype: Somatotype
    let onApply: (Double) -> Void
    
    @State private var isApplied: Bool = false
    
    public init(
        result: AIBodyCalibrationResult,
        currentWeight: Double,
        targetWeight: Double,
        somatotype: Somatotype,
        onApply: @escaping (Double) -> Void
    ) {
        self.result = result
        self.currentWeight = currentWeight
        self.targetWeight = targetWeight
        self.somatotype = somatotype
        self.onApply = onApply
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Верхний статус-баннер ИИ
                        headerCardView
                        
                        // КЛЮЧЕВАЯ КАРТОЧКА: ПЕРЕРАСЧЕТ НОРМЫ ВОДЫ (3.5 л)
                        waterRecalibrationCardView
                        
                        // Карточки BMR, TDEE и целевых калорий
                        caloriesCardView
                        
                        // Карточка БЖУ под соматотип
                        macrosCardView
                        
                        // Рекомендации ИИ по соматотипу
                        adviceCardView
                        
                        // Большая кнопка применения
                        applyButtonView
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Калибровка норм ИИ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Хедер ИИ
    private var headerCardView: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0/255, green: 229/255, blue: 255/255), Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Анализ физиологии завершен")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                    
                    Text("PRO")
                        .font(.system(size: 9, weight: .black))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.2))
                        .foregroundColor(.purple)
                        .cornerRadius(6)
                }
                
                Text("Источник: \(result.provider) • ВОЗ / EFSA")
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    // MARK: - Главная карточка нормы воды
    private var waterRecalibrationCardView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color(red: 0/255, green: 229/255, blue: 255/255))
                    Text("Дневная норма чистой воды")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                }
                
                Spacer()
                
                Text("35 мл / кг")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(red: 0/255, green: 229/255, blue: 255/255).opacity(0.15))
                    .foregroundColor(Color(red: 0/255, green: 229/255, blue: 255/255))
                    .cornerRadius(8)
            }
            
            // Сравнение текущей нормы в приложении и индивидуального расчета ИИ
            let currentGoal = health.waterGoal
            let diffMl = Int(result.waterGoalMl - currentGoal)
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Текущая норма:")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                    Text(String(format: "%.1f л (%d мл)", currentGoal / 1000.0, Int(currentGoal)))
                        .font(.subheadline.bold())
                        .foregroundColor(abs(diffMl) > 50 ? Theme.textSecondary : .green)
                        .strikethrough(abs(diffMl) > 50, color: Theme.textSecondary)
                }
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Расчет ИИ под ваш вес:")
                        .font(.caption2)
                        .foregroundColor(Color(red: 0/255, green: 229/255, blue: 255/255))
                    HStack(spacing: 6) {
                        Text(String(format: "%.1f л (%d мл)", result.waterGoalMl / 1000.0, Int(result.waterGoalMl)))
                            .font(.title3.bold())
                            .foregroundColor(Color(red: 0/255, green: 229/255, blue: 255/255))
                        
                        if diffMl > 50 {
                            Text("+\(diffMl) мл")
                                .font(.system(size: 10, weight: .heavy))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(Color(red: 0/255, green: 229/255, blue: 255/255))
                                .cornerRadius(6)
                        } else if diffMl < -50 {
                            Text("\(diffMl) мл")
                                .font(.system(size: 10, weight: .heavy))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .cornerRadius(6)
                        }
                    }
                }
                Spacer()
            }
            .padding(12)
            .background(Color.white.opacity(0.04))
            .cornerRadius(12)
            
            // Медицинское объяснение от ИИ
            Text(result.waterExplanation)
                .font(.footnote)
                .foregroundColor(Theme.textSecondary)
                .lineSpacing(3)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0/255, green: 229/255, blue: 255/255).opacity(0.10),
                    Color(red: 18/255, green: 20/255, blue: 26/255)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color(red: 0/255, green: 229/255, blue: 255/255).opacity(0.35), lineWidth: 1.5)
        )
    }
    
    // MARK: - Карточка BMR и калорий
    private var caloriesCardView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                Text("Энергетический баланс и BMR")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Text(somatotype.shortTitle)
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(somatotype.accentColor.opacity(0.15))
                    .foregroundColor(somatotype.accentColor)
                    .cornerRadius(8)
            }
            
            HStack(spacing: 8) {
                // BMR
                VStack(spacing: 4) {
                    Text("Базовый BMR")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                    Text("\(result.bmrCalories)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                    Text("ккал в покое")
                        .font(.system(size: 9))
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.04))
                .cornerRadius(12)
                
                // TDEE
                VStack(spacing: 4) {
                    Text("Расход TDEE")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                    Text("\(result.tdeeCalories)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                    Text("с активностью")
                        .font(.system(size: 9))
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.04))
                .cornerRadius(12)
                
                // Target
                VStack(spacing: 4) {
                    Text("Цель питания")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                    Text("\(result.targetCalories)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    Text("для похудения")
                        .font(.system(size: 9))
                        .foregroundColor(.green.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.green.opacity(0.08))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .cornerRadius(18)
    }
    
    // MARK: - Карточка БЖУ
    private var macrosCardView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundColor(Color.cyan)
                Text("Баланс БЖУ под \(somatotype.shortTitle)")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
            }
            
            HStack(spacing: 8) {
                // Белки
                VStack(spacing: 3) {
                    Text("Белки")
                        .font(.caption2.bold())
                        .foregroundColor(Color(red: 255/255, green: 69/255, blue: 58/255))
                    Text("\(result.proteinGrams) г")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                    Text("\(somatotype.recommendedMacros.protein)%")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color(red: 255/255, green: 69/255, blue: 58/255).opacity(0.1))
                .cornerRadius(10)
                
                // Жиры
                VStack(spacing: 3) {
                    Text("Жиры")
                        .font(.caption2.bold())
                        .foregroundColor(.yellow)
                    Text("\(result.fatGrams) г")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                    Text("\(somatotype.recommendedMacros.fat)%")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(10)
                
                // Углеводы
                VStack(spacing: 3) {
                    Text("Углеводы")
                        .font(.caption2.bold())
                        .foregroundColor(.cyan)
                    Text("\(result.carbsGrams) г")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                    Text("\(somatotype.recommendedMacros.carbs)%")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.cyan.opacity(0.1))
                .cornerRadius(10)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .cornerRadius(18)
    }
    
    // MARK: - Советы ИИ
    private var adviceCardView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(Color.purple)
                Text("Совет эндокринолога и нутрициолога")
                    .font(.subheadline.bold())
                    .foregroundColor(Theme.textPrimary)
            }
            
            Text(result.somatotypeAdvice)
                .font(.footnote)
                .foregroundColor(Theme.textSecondary)
                .lineSpacing(3)
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .cornerRadius(18)
    }
    
    // MARK: - Кнопка применения
    private var applyButtonView: some View {
        Button(action: {
            HapticManager.shared.notification(.success)
            onApply(result.waterGoalMl)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                isApplied = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                dismiss()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: isApplied ? "checkmark.circle.fill" : "wand.and.stars")
                    .font(.system(size: 16, weight: .bold))
                Text(isApplied ? "Персональные нормы применены!" : String(format: "Применить нормы (%.1f л воды и %d ккал)", result.waterGoalMl / 1000.0, result.targetCalories))
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: isApplied ? [Color.green, Color.green] : [Color(red: 0/255, green: 229/255, blue: 255/255), Color.blue],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: (isApplied ? Color.green : Color.blue).opacity(0.4), radius: 10, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isApplied)
    }
}
