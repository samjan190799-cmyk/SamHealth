import SwiftUI

// MARK: - Итог тренировки
//
// Раньше конец тренировки — главный момент награды — показывался системным окошком с одной строкой
// текста. Теперь это экран: кольцо «минуты активности за день» заполняется на глазах, под ним
// калории, дистанция и полученный опыт. Кольцо и числа используют те же приёмы, что и главная.

struct WorkoutFinishSummaryView: View {
    let title: String
    let symbol: String
    let durationSeconds: Int
    let calories: Double
    let distanceMeters: Double
    let xpEarned: Int
    let language: String
    let onDone: () -> Void

    /// Суточная норма активности по рекомендации ВОЗ (150 минут в неделю ≈ 30 минут в день).
    private static let dailyGoalMinutes = 30

    @State private var isRevealed = false

    private func tr(_ key: String) -> String {
        LocalizationManager.tr(key, lang: language)
    }

    private var minutes: Int {
        max(1, Int((Double(durationSeconds) / 60.0).rounded()))
    }

    private var progress: Double {
        Double(durationSeconds) / 60.0 / Double(Self.dailyGoalMinutes)
    }

    var body: some View {
        VStack(spacing: FormaSpacing.xl) {
            Spacer(minLength: FormaSpacing.l)

            VStack(spacing: FormaSpacing.xs) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 40))
                    .foregroundColor(Theme.cyberLime)
                    .symbolEffect(.bounce, value: isRevealed)
                Text(tr("workouts_finished_title"))
                    .font(FormaFont.title)
                    .foregroundColor(Theme.textPrimary)
                Text(title)
                    .font(FormaFont.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            .formaAppear(index: 0)

            ZStack {
                FormaRingStack(
                    rings: [
                        FormaRingSpec(id: "minutes", progress: progress, color: Theme.exerciseColor, symbol: symbol)
                    ],
                    isRevealed: isRevealed,
                    lineWidth: 24
                )
                VStack(spacing: 0) {
                    FormaCountingText(value: minutes)
                        .font(.system(size: 60, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                    Text(tr("finish_minutes"))
                        .font(FormaFont.unit)
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .frame(width: 250, height: 250)
            .formaAppear(index: 1)

            Text(String(format: tr("finish_goal"), Self.dailyGoalMinutes))
                .font(FormaFont.caption)
                .foregroundColor(Theme.textSecondary)
                .formaAppear(index: 2)

            HStack(spacing: FormaSpacing.m) {
                statTile(title: tr("finish_calories")) {
                    FormaCountingText(value: Int(calories.rounded()))
                } unit: {
                    tr("kcal")
                }
                if distanceMeters >= 10 {
                    statTile(title: tr("finish_distance")) {
                        Text(String(format: "%.2f", distanceMeters / 1000.0))
                            .monospacedDigit()
                    } unit: {
                        tr("finish_km")
                    }
                }
                if xpEarned > 0 {
                    statTile(title: tr("finish_xp")) {
                        FormaCountingText(value: xpEarned, prefix: "+")
                    } unit: {
                        "XP"
                    }
                }
            }
            .formaAppear(index: 3)

            Spacer(minLength: FormaSpacing.l)

            Button(action: onDone) {
                Text(tr("finish_done"))
                    .font(FormaFont.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FormaSpacing.l)
                    .background(Theme.cyberLime)
                    .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
            }
            .buttonStyle(SpringPressButtonStyle(scaleAmount: 0.97, hapticStyle: .medium))
            .formaAppear(index: 4)
        }
        .padding(.horizontal, FormaSpacing.screenMargin)
        .padding(.bottom, FormaSpacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .sensoryFeedback(.success, trigger: isRevealed)
        .task {
            // Даём экрану выехать, затем запускаем кольцо и числа
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            isRevealed = true
        }
    }

    private func statTile<Value: View>(
        title: String,
        @ViewBuilder value: () -> Value,
        unit: () -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(FormaFont.caption)
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                value()
                    .font(FormaFont.metric)
                    .foregroundColor(Theme.textPrimary)
                Text(unit())
                    .font(FormaFont.unit)
                    .foregroundColor(Theme.textSecondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .padding(FormaSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .formaSurface(FormaRadius.control)
    }
}
