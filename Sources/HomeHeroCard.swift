import SwiftUI

// MARK: - Герой главного экрана
//
// Раньше главная начиналась со статусной строки и карточки ранга: глаз не знал, куда смотреть,
// а главное — сколько сделано за сегодня — приходилось искать в пяти разных карточках.
// Теперь сверху одна карточка с тремя кольцами: шаги, питание, вода. Она отвечает на вопрос
// «как у меня день?» за секунду. Каждая строка открывает свою подробную шторку.

struct HomeHeroCard: View {
    let steps: Int
    let stepGoal: Int
    let calories: Double
    let calorieGoal: Double
    let waterMl: Double
    let waterGoalMl: Double
    let language: String
    var onSteps: () -> Void = {}
    var onNutrition: () -> Void = {}
    var onWater: () -> Void = {}

    /// Становится истиной через долю секунды после появления карточки: тогда кольца и числа
    /// «выезжают» из нуля. Пока карточка не показана, всё стоит на нуле.
    @State private var isRevealed = false

    private var stepsFraction: Double { fraction(Double(steps), Double(stepGoal)) }
    private var caloriesFraction: Double { fraction(calories, calorieGoal) }
    private var waterFraction: Double { fraction(waterMl, waterGoalMl) }

    private func fraction(_ value: Double, _ goal: Double) -> Double {
        goal > 0 ? max(0, value) / goal : 0
    }

    private func tr(_ key: String) -> String {
        LocalizationManager.tr(key, lang: language)
    }

    private var dateText: String {
        let text = Date().formatted(
            .dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: language))
        )
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    private func grouped(_ value: Double) -> String {
        LocalizationManager.formatNumber(Int(value.rounded()), lang: language)
    }

    private func liters(_ ml: Double) -> String {
        String(format: "%.1f", ml / 1000.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.l) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tr("hero_today"))
                    .font(FormaFont.title)
                    .foregroundColor(Theme.textPrimary)
                Text(dateText)
                    .font(FormaFont.caption)
                    .foregroundColor(Theme.textSecondary)
            }

            HStack(spacing: FormaSpacing.xl) {
                FormaRingStack(
                    rings: [
                        FormaRingSpec(id: "steps", progress: stepsFraction, color: Theme.moveColor, symbol: "figure.walk"),
                        FormaRingSpec(id: "nutrition", progress: caloriesFraction, color: Theme.exerciseColor, symbol: "fork.knife"),
                        FormaRingSpec(id: "water", progress: waterFraction, color: Theme.standColor, symbol: "drop.fill")
                    ],
                    isRevealed: isRevealed
                )
                .frame(width: 144, height: 144)

                VStack(alignment: .leading, spacing: FormaSpacing.m) {
                    HeroMetricRow(
                        title: tr("hero_steps"),
                        color: Theme.moveColor,
                        value: isRevealed ? grouped(Double(steps)) : "0",
                        numeric: isRevealed ? Double(steps) : 0,
                        detail: "/ " + grouped(Double(stepGoal)),
                        percent: Int(stepsFraction * 100),
                        action: onSteps
                    )
                    HeroMetricRow(
                        title: tr("nutrition_title"),
                        color: Theme.exerciseColor,
                        value: isRevealed ? grouped(calories) : "0",
                        numeric: isRevealed ? calories : 0,
                        detail: "/ " + grouped(calorieGoal) + " " + tr("kcal"),
                        percent: Int(caloriesFraction * 100),
                        action: onNutrition
                    )
                    HeroMetricRow(
                        title: tr("tab_water"),
                        color: Theme.standColor,
                        value: isRevealed ? liters(waterMl) : "0.0",
                        numeric: isRevealed ? waterMl : 0,
                        detail: "/ " + liters(waterGoalMl) + " " + tr("hero_unit_liter"),
                        percent: Int(waterFraction * 100),
                        action: onWater
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(FormaSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .formaSurface()
        .task {
            // Даём карточке проявиться, затем запускаем заполнение
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            isRevealed = true
        }
    }
}

// MARK: - Строка показателя

struct HeroMetricRow: View {
    let title: String
    let color: Color
    let value: String
    let numeric: Double
    let detail: String
    let percent: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                    Text(title)
                        .font(FormaFont.caption)
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(FormaFont.metric)
                        .monospacedDigit()
                        .foregroundColor(Theme.textPrimary)
                        .contentTransition(.numericText(value: numeric))
                        .formaAnimation(FormaMotion.fill, value: numeric)
                    Text(detail)
                        .font(FormaFont.unit)
                        .foregroundColor(Theme.textSecondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(SpringPressButtonStyle(scaleAmount: 0.97, hapticStyle: .light))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(value) \(detail), \(percent)%")
    }
}
