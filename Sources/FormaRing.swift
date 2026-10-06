import SwiftUI

// MARK: - Кольца прогресса
//
// Старое `ActivityRing` отличалось от колец Apple Fitness тремя вещами: градиент был почти плоским,
// выше 100% прогресс обрезался, а заполнение играло только при смене значения, но не при появлении.
// Здесь кольцо ведёт себя как настоящее: полоса светлеет от начала к концу, после 100% идёт
// второй круг поверх первого, а на конце — головка с тенью, которая «ложится» на начало полосы.

/// Одно кольцо. Прогресс может быть больше 1: до 2 рисуется второй круг.
///
/// Вью сама анимируема (`Animatable`): при смене `progress` внутри `.animation` система
/// пересчитывает кольцо на каждом кадре, поэтому второй круг начинает расти ровно тогда,
/// когда первый замкнулся, а не одновременно с ним.
struct FormaRing: View, Animatable {
    var progress: Double
    let color: Color
    let lineWidth: CGFloat
    var symbol: String? = nil

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let radius = (side - lineWidth) / 2
            let clamped = min(max(progress, 0), 2)
            let firstLap = min(clamped, 1)
            let overflow = max(clamped - 1, 0)

            ZStack {
                Circle()
                    .stroke(color.opacity(0.16), lineWidth: lineWidth)

                Circle()
                    .trim(from: 0, to: firstLap)
                    .stroke(
                        sweep(for: firstLap),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .opacity(firstLap > 0.002 ? 1 : 0)

                // Второй круг поверх первого
                Circle()
                    .trim(from: 0, to: overflow)
                    .stroke(
                        sweep(for: overflow),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .opacity(overflow > 0.002 ? 1 : 0)

                // Головка второго круга: тень падает вперёд, на начало первого
                Circle()
                    .fill(color)
                    .frame(width: lineWidth, height: lineWidth)
                    .shadow(color: Color.black.opacity(0.45), radius: lineWidth * 0.22, x: lineWidth * 0.2, y: 0)
                    .offset(y: -radius)
                    .rotationEffect(.degrees(360 * overflow))
                    .opacity(overflow > 0.002 ? 1 : 0)

                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: lineWidth * 0.55, weight: .heavy))
                        .foregroundColor(Color.black.opacity(0.62))
                        .offset(y: -radius)
                        .opacity(firstLap > 0.05 ? 1 : 0)
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    /// Градиент вдоль дуги: от тёмного оттенка в начале до чистого цвета на конце.
    /// Растягивается на фактическую длину дуги, поэтому конец всегда совпадает с цветом головки.
    private func sweep(for lap: Double) -> AngularGradient {
        AngularGradient(
            colors: [color.formaShade(0.68), color],
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(max(360 * lap, 1))
        )
    }
}

private extension Color {
    /// Тот же цвет, но темнее: яркость умножается на `factor`.
    func formaShade(_ factor: CGFloat) -> Color {
        let base = UIColor(self)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard base.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return self
        }
        return Color(
            hue: Double(hue),
            saturation: Double(saturation),
            brightness: Double(brightness * factor),
            opacity: Double(alpha)
        )
    }
}

// MARK: - Вложенные кольца

struct FormaRingSpec: Identifiable {
    let id: String
    let progress: Double
    let color: Color
    let symbol: String
}

/// Несколько колец одно в другом, внешнее — первое в списке.
/// Заполнение запускает родитель: пока `isRevealed == false`, кольца пустые.
/// Так герой экрана сам решает, когда начать (после появления карточки).
struct FormaRingStack: View {
    let rings: [FormaRingSpec]
    var isRevealed: Bool
    var lineWidth: CGFloat = 14
    var gap: CGFloat = 3

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ForEach(Array(rings.enumerated()), id: \.element.id) { index, ring in
                let shown = isRevealed ? ring.progress : 0
                FormaRing(
                    progress: shown,
                    color: ring.color,
                    lineWidth: lineWidth,
                    symbol: ring.symbol
                )
                .padding(CGFloat(index) * (lineWidth + gap))
                .animation(
                    reduceMotion ? nil : FormaMotion.fill.delay(Double(index) * 0.12),
                    value: shown
                )
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
