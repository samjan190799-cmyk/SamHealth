import SwiftUI

// MARK: - Быстрые действия Главной
//
// Три действия, которые делают чаще всего, стоят сразу под кольцами героя: стакан воды, ИИ-скан еды,
// начать тренировку. Раньше ради «+250 мл» на Главной была отдельная большая карточка воды, а скан
// был мелкой кнопкой внутри карточки питания; обе карточки повторяли кольца героя.

struct HomeQuickActions: View {
    let language: String
    var onAddWater: () -> Void = {}
    var onScanFood: () -> Void = {}
    var onStartWorkout: () -> Void = {}

    private func tr(_ key: String) -> String {
        LocalizationManager.tr(key, lang: language)
    }

    var body: some View {
        HStack(spacing: FormaSpacing.m) {
            // Цвета значков повторяют кольца героя: вода — голубой, питание — зелёный
            tile(
                icon: "drop.fill",
                tint: Theme.standColor,
                title: tr("home_quick_water"),
                spokenTitle: tr("home_quick_water_hint"),
                haptic: .medium,
                action: onAddWater
            )
            tile(
                icon: "camera.viewfinder",
                tint: Theme.exerciseColor,
                title: tr("home_quick_scan"),
                spokenTitle: tr("home_quick_scan"),
                haptic: .light,
                action: onScanFood
            )
            tile(
                icon: "figure.run",
                tint: Theme.flameOrange,
                title: tr("home_quick_workout"),
                spokenTitle: tr("home_quick_workout"),
                haptic: .light,
                action: onStartWorkout
            )
        }
    }

    private func tile(
        icon: String,
        tint: Color,
        title: String,
        spokenTitle: String,
        haptic: UIImpactFeedbackGenerator.FeedbackStyle,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            FormaQuickTileLabel(icon: icon, tint: tint, title: title)
        }
        .buttonStyle(SpringPressButtonStyle(scaleAmount: 0.96, hapticStyle: haptic))
        .accessibilityLabel(spokenTitle)
    }
}
