import SwiftUI
import UIKit

// MARK: - Карточка «поделиться»
//
// Картинка 4:5 (1080 × 1350) для сторис и мессенджеров: награда, итоги недели, серия дней.
// Карточка всегда тёмная и не зависит от темы телефона и языка системы: она должна выглядеть одинаково
// у того, кто её отправил, и у того, кто получил.

/// Что показать на карточке. Тексты собираются заранее, чтобы их можно было проверить тестами без отрисовки.
struct ShareCardModel {
    var eyebrow: String
    var headline: String
    var metric: String
    var metricCaption: String
    var details: [String] = []
    var symbol: String
    var accent: Color
    var accentDark: Color

    /// Строк подробностей на карточке не больше трёх: больше не помещается без мелкого шрифта
    static let maxDetails = 3

    static func achievement(_ achievement: FormaAchievement, lang: String = "ru") -> ShareCardModel {
        let palette = achievement.category.medalPalette
        return ShareCardModel(
            eyebrow: LocalizationManager.tr("share_eyebrow_achievement", lang: lang),
            headline: achievement.title,
            metric: "+\(achievement.xpReward)",
            metricCaption: "XP",
            details: [achievement.description],
            symbol: achievement.icon,
            accent: palette.mid,
            accentDark: palette.dark
        )
    }

    static func weekly(_ summary: WeeklySummary, period: String, lang: String = "ru") -> ShareCardModel {
        func tr(_ key: String) -> String { LocalizationManager.tr(key, lang: lang) }

        var details: [String] = [
            "\(tr("weekly_summary_workouts")): " + String(format: tr("weekly_summary_workouts_value"), summary.workoutCount, summary.workoutMinutes)
        ]
        if let habits = summary.habitsPercent {
            details.append("\(tr("weekly_summary_habits")): \(habits)%")
        }
        if let change = summary.stepsChangePercent, change != 0 {
            details.append(String(format: tr(change > 0 ? "weekly_summary_trend_up" : "weekly_summary_trend_down"), abs(change)))
        }
        return ShareCardModel(
            eyebrow: tr("weekly_summary_title"),
            headline: period,
            metric: WeeklySummaryFormat.grouped(summary.totalSteps),
            metricCaption: tr("weekly_summary_steps_caption"),
            details: Array(details.prefix(maxDetails)),
            symbol: "figure.walk",
            accent: Theme.exerciseColor,
            accentDark: Color(red: 14 / 255, green: 70 / 255, blue: 32 / 255)
        )
    }

    static func workout(title: String, symbol: String, durationSeconds: Int, calories: Double,
                        distanceMeters: Double, xp: Int, lang: String = "ru") -> ShareCardModel {
        func tr(_ key: String) -> String { LocalizationManager.tr(key, lang: lang) }

        var details = ["\(Int(calories.rounded())) \(tr("kcal"))"]
        if distanceMeters >= 10 {
            details.append(String(format: "%.2f ", distanceMeters / 1000.0) + tr("finish_km"))
        }
        if xp > 0 {
            details.append("+\(xp) XP")
        }
        return ShareCardModel(
            eyebrow: tr("workouts_finished_title"),
            headline: title,
            metric: "\(max(1, Int((Double(durationSeconds) / 60.0).rounded())))",
            metricCaption: tr("min"),
            details: Array(details.prefix(maxDetails)),
            symbol: symbol,
            accent: Theme.exerciseColor,
            accentDark: Color(red: 14 / 255, green: 70 / 255, blue: 32 / 255)
        )
    }

    static func streak(days: Int, lang: String = "ru") -> ShareCardModel {
        ShareCardModel(
            eyebrow: LocalizationManager.tr("share_eyebrow_streak", lang: lang),
            headline: LocalizationManager.tr("share_streak_headline", lang: lang),
            metric: "\(days)",
            metricCaption: LocalizationManager.tr("share_streak_caption", lang: lang),
            symbol: "flame.fill",
            accent: Theme.flameOrange,
            accentDark: Color(red: 92 / 255, green: 34 / 255, blue: 8 / 255)
        )
    }
}

struct ShareCardView: View {
    static let size = CGSize(width: 1080, height: 1350)

    let model: ShareCardModel
    var lang: String = "ru"

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 8 / 255, green: 10 / 255, blue: 18 / 255), model.accentDark.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [model.accent.opacity(0.42), Color.clear],
                center: UnitPoint(x: 0.5, y: 0.36),
                startRadius: 20,
                endRadius: 640
            )

            VStack(spacing: 24) {
                HStack(spacing: 18) {
                    AppLogoView(size: 72)
                    Text("Forma")
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                }

                Spacer(minLength: 0)

                Text(model.eyebrow.uppercased())
                    .font(.system(size: 34, weight: .bold))
                    .tracking(4)
                    .foregroundColor(model.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                ZStack {
                    Circle()
                        .fill(model.accent.opacity(0.16))
                    Circle()
                        .strokeBorder(model.accent.opacity(0.65), lineWidth: 6)
                    Image(systemName: model.symbol)
                        .font(.system(size: 150, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: 330, height: 330)

                Text(model.headline)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)

                VStack(spacing: 4) {
                    Text(model.metric)
                        .font(.system(size: 140, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(model.metricCaption)
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }

                VStack(spacing: 8) {
                    ForEach(Array(model.details.prefix(ShareCardModel.maxDetails).enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 34, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                    }
                }

                Spacer(minLength: 0)

                Text(LocalizationManager.tr("share_footer", lang: lang))
                    .font(.system(size: 30, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
            }
            .padding(72)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }
}

@MainActor
enum ShareCardRenderer {
    /// Рисует карточку в картинку 1080 × 1350 пикселей (масштаб 1, не зависит от экрана устройства)
    static func image(for model: ShareCardModel, lang: String = "ru") -> UIImage? {
        let renderer = ImageRenderer(content: ShareCardView(model: model, lang: lang))
        renderer.scale = 1
        renderer.isOpaque = true
        return renderer.uiImage
    }
}

// MARK: - Системное меню «Поделиться»

struct ShareImageItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct FormaImageShareSheet: UIViewControllerRepresentable {
    let image: UIImage

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
