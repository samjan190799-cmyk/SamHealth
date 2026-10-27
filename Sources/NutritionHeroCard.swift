import SwiftUI

// MARK: - Герой вкладки «Питание»
//
// Тот же язык, что у колец на Главной: большое кольцо калорий с остатком на день в центре
// и три кольца поменьше — белки, жиры, углеводы. Цифры «выезжают» из нуля после появления карточки.

struct NutritionHeroCard: View {
    let calories: Double
    let calorieGoal: Int
    let protein: Double
    let fat: Double
    let carbs: Double
    let goals: (protein: Int, fat: Int, carbs: Int)
    let language: String

    @State private var isRevealed = false

    static let calorieColor = Color(red: 1.0, green: 0.58, blue: 0.16)
    static let proteinColor = Color(red: 0.36, green: 0.62, blue: 1.0)
    static let fatColor = Color(red: 1.0, green: 0.78, blue: 0.22)
    static let carbsColor = Color(red: 0.32, green: 0.86, blue: 0.56)

    private func tr(_ key: String) -> String {
        LocalizationManager.tr(key, lang: language)
    }

    private func fraction(_ value: Double, _ goal: Int) -> Double {
        goal > 0 ? max(0, value) / Double(goal) : 0
    }

    private var remaining: Int {
        Int((Double(calorieGoal) - calories).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.l) {
            Text(tr("nutrition_hero_title"))
                .formaEyebrow()

            HStack(spacing: FormaSpacing.xl) {
                ZStack {
                    FormaRingStack(
                        rings: [FormaRingSpec(id: "kcal", progress: fraction(calories, calorieGoal), color: Self.calorieColor, symbol: "flame.fill")],
                        isRevealed: isRevealed,
                        lineWidth: 18
                    )
                    VStack(spacing: 0) {
                        Text(LocalizationManager.formatNumber(isRevealed ? abs(remaining) : calorieGoal, lang: language))
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                            .monospacedDigit()
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            .contentTransition(.numericText(value: Double(remaining)))
                            .formaAnimation(FormaMotion.fill, value: isRevealed)
                        Text(remaining >= 0 ? tr("nutrition_hero_left") : tr("nutrition_hero_over"))
                            .font(FormaFont.unit)
                            .foregroundColor(remaining >= 0 ? Theme.textSecondary : Self.calorieColor)
                    }
                    .padding(.horizontal, 30)
                }
                .frame(width: 150, height: 150)

                VStack(alignment: .leading, spacing: FormaSpacing.m) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(LocalizationManager.formatNumber(Int(calories.rounded()), lang: language))
                                .font(FormaFont.metric)
                                .foregroundColor(Theme.textPrimary)
                                .monospacedDigit()
                            Text("/ " + LocalizationManager.formatNumber(calorieGoal, lang: language) + " " + tr("kcal"))
                                .font(FormaFont.unit)
                                .foregroundColor(Theme.textSecondary)
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        Text(tr("nutrition_hero_eaten"))
                            .font(FormaFont.caption)
                            .foregroundColor(Theme.textSecondary)
                    }

                    HStack(spacing: FormaSpacing.m) {
                        macro(title: tr("nutrition_hero_protein"), value: protein, goal: goals.protein, color: Self.proteinColor)
                        macro(title: tr("nutrition_hero_fat"), value: fat, goal: goals.fat, color: Self.fatColor)
                        macro(title: tr("nutrition_hero_carbs"), value: carbs, goal: goals.carbs, color: Self.carbsColor)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .formaHeroCard(tint: Self.calorieColor, padding: FormaSpacing.xl - 4)
        .task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            isRevealed = true
        }
        .accessibilityElement(children: .combine)
    }

    private func macro(title: String, value: Double, goal: Int, color: Color) -> some View {
        VStack(spacing: 6) {
            FormaRingStack(
                rings: [FormaRingSpec(id: title, progress: fraction(value, goal), color: color, symbol: "")],
                isRevealed: isRevealed,
                lineWidth: 6
            )
            .frame(width: 40, height: 40)
            Text("\(Int(value.rounded()))/\(goal)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(Theme.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}
