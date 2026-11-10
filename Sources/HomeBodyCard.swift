import SwiftUI

// MARK: - «Тело»: пульс, сон и готовность
//
// Раньше на Главной это были три карточки: пульс и сон по пол-экрана и отдельная «Готовность (HRV)» с
// чипами шрифтом 9–11 pt и кнопками ниже удобного размера. Теперь одна карточка в виде героя: три
// кольца в ряд, каждое открывает свои подробности. Замер пульса в реальном времени — кнопка полной
// высоты под кольцами. Источники медицинских норм открывает значок «i» (требование App Store 1.4.1).

struct HomeBodyCard: View {
    let heartRate: Double
    /// Цвет пульсовой зоны; пока замера нет — базовый цвет пульса
    let zoneColor: Color
    let isLive: Bool
    let sleepHours: Double
    let recoveryScore: Int
    let hrv: Double
    let vo2Max: Double
    let bloodOxygen: Double
    let language: String
    var onPulse: () -> Void = {}
    var onSleep: () -> Void = {}
    var onToggleLive: () -> Void = {}
    var onSources: () -> Void = {}

    private func tr(_ key: String) -> String {
        LocalizationManager.tr(key, lang: language)
    }

    private var pulseText: String {
        if heartRate > 0 { return "\(Int(heartRate))" }
        return isLive ? "…" : "--"
    }

    private var sleepText: String {
        sleepHours > 0 ? String(format: "%.1f", sleepHours) : "--"
    }

    private var readinessText: String {
        recoveryScore > 0 ? "\(recoveryScore)" : "--"
    }

    private var readinessColor: Color {
        if recoveryScore <= 0 || recoveryScore >= 75 { return Theme.exerciseColor }
        return recoveryScore >= 50 ? Color.orange : Theme.pulseColor
    }

    /// Дополнительные показатели одной строкой; тех, по которым данных нет, в строке нет
    private var vitalsLine: String {
        var parts: [String] = []
        if hrv > 0 { parts.append("HRV \(Int(hrv)) \(tr("home_body_ms"))") }
        if vo2Max > 0 { parts.append("VO₂ " + String(format: "%.1f", vo2Max)) }
        if bloodOxygen > 0 { parts.append("SpO₂ \(Int(bloodOxygen))%") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.l) {
            HStack {
                Text(tr("home_body_title"))
                    .formaEyebrow()
                Spacer()
                // Значок маленький, а зона нажатия 44 pt: отрицательные отступы возвращают строке её высоту
                Button(action: onSources) {
                    Image(systemName: "info.circle")
                        .font(.body)
                        .foregroundColor(Theme.textSecondary)
                        .frame(width: FormaTouch.minTarget, height: FormaTouch.minTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, -FormaSpacing.m)
                .padding(.trailing, -FormaSpacing.m)
                .accessibilityLabel(tr("home_body_sources"))
            }

            HStack(alignment: .top, spacing: FormaSpacing.s) {
                HomeBodyRing(
                    title: tr("pulse_title"),
                    value: pulseText,
                    unit: tr("pulse_bpm"),
                    progress: heartRate / 200.0,
                    color: zoneColor,
                    isPulsing: isLive,
                    action: onPulse
                )
                HomeBodyRing(
                    title: tr("sleep_title"),
                    value: sleepText,
                    unit: tr("hrs"),
                    progress: sleepHours / 8.0,
                    color: Theme.sleepColor,
                    action: onSleep
                )
                HomeBodyRing(
                    title: tr("home_body_readiness"),
                    value: readinessText,
                    unit: "%",
                    progress: Double(recoveryScore) / 100.0,
                    color: readinessColor,
                    action: onPulse
                )
            }

            if !vitalsLine.isEmpty {
                Text(vitalsLine)
                    .font(FormaFont.caption)
                    .foregroundColor(Theme.textSecondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            FormaTintedButton(
                title: isLive ? tr("pulse_stop") : tr("home_body_measure"),
                icon: isLive ? "stop.fill" : "waveform.path.ecg",
                tint: Theme.pulseColor,
                action: onToggleLive
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .premiumCard()
    }
}

// MARK: - Кольцо показателя

/// Одно кольцо «Тела»: значение в центре, подпись под кольцом; всё вместе — кнопка
private struct HomeBodyRing: View {
    let title: String
    let value: String
    let unit: String
    let progress: Double
    let color: Color
    var isPulsing: Bool = false
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var pulses: Bool { isPulsing && !reduceMotion }

    var body: some View {
        Button(action: action) {
            VStack(spacing: FormaSpacing.s) {
                FormaMiniRing(progress: progress, color: color, size: 80, lineWidth: 9) {
                    VStack(spacing: 0) {
                        Text(value)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            // Во время замера число «бьётся»; повторяющаяся анимация только пока идёт замер
                            .scaleEffect(pulses ? 1.06 : 1.0)
                            .animation(
                                pulses
                                    ? Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true)
                                    : Animation.default,
                                value: pulses
                            )
                        Text(unit)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Theme.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .padding(.horizontal, FormaSpacing.m)
                }
                Text(title)
                    .font(FormaFont.caption)
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(SpringPressButtonStyle(scaleAmount: 0.97, hapticStyle: .light))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(value) \(unit)")
    }
}
