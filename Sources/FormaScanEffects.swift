import SwiftUI

// MARK: - Эффекты сканера еды
//
// Раньше сканер был статичным: сплошная рамка, чёрная плашка с крутилкой во время анализа и
// результат, который просто появлялся. Теперь: уголки видоискателя, луч, который «ощупывает»
// блюдо, пока идёт анализ, и результат, который выезжает и «накручивается» от нуля.

// MARK: Уголки видоискателя

/// Четыре уголка со скруглением вместо сплошной обводки: рамка не спорит с блюдом внутри.
struct FormaViewfinderBrackets: Shape {
    var cornerRadius: CGFloat
    var armLength: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = min(cornerRadius, min(rect.width, rect.height) / 2)
        let a = max(armLength, r)
        var path = Path()

        // Левый верхний
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + a))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + a, y: rect.minY))

        // Правый верхний
        path.move(to: CGPoint(x: rect.maxX - a, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + a))

        // Правый нижний
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - a))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - a, y: rect.maxY))

        // Левый нижний
        path.move(to: CGPoint(x: rect.minX + a, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - a))

        return path
    }
}

// MARK: Луч анализа

/// Луч с мягким свечением ходит сверху вниз и обратно, пока идёт анализ.
/// Положение считается по времени (`TimelineView`), а не состоянием: ничто не «залипает»,
/// когда вью пересоздаётся. При включённом «Уменьшении движения» луч стоит по центру.
struct FormaScanBeam: View {
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let glowHeight: CGFloat = 96

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: nil, paused: reduceMotion)) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                // Синусоида: луч замедляется у краёв и ускоряется в середине
                let phase = reduceMotion ? 0.5 : (sin(time * 2.2 - Double.pi / 2) + 1) / 2
                let centerY = geo.size.height * CGFloat(phase)

                ZStack {
                    LinearGradient(
                        colors: [color.opacity(0), color.opacity(0.28), color.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0), color, color.opacity(0)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 3)
                        .shadow(color: color.opacity(0.9), radius: 8)
                }
                .frame(width: geo.size.width, height: glowHeight)
                .position(x: geo.size.width / 2, y: centerY)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: Число с накруткой

/// Целое число, которое «накручивается» от нуля при появлении и плавно меняется потом
/// (например, когда пользователь правит вес порции).
struct FormaCountingText: View {
    let value: Int
    var suffix: String = ""

    @State private var isRevealed = false

    var body: some View {
        let shown = isRevealed ? value : 0
        Text("\(shown)\(suffix)")
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(shown)))
            .formaAnimation(FormaMotion.smooth, value: shown)
            .task {
                // Даём карточке выехать, затем считаем
                try? await Task.sleep(nanoseconds: 200_000_000)
                guard !Task.isCancelled else { return }
                isRevealed = true
            }
    }
}

// MARK: Белки, жиры, углеводы одной полосой

/// Полоса «из чего состоят калории»: доли считаются по энергии (белки и углеводы 4 ккал/г, жиры 9),
/// поэтому жиры занимают больше места, чем их масса. Под полосой — граммы каждого вещества.
struct FormaMacroSplitBar: View {
    struct Part: Identifiable {
        let id: String
        let title: String
        let grams: Double
        let kcalPerGram: Double
        let color: Color
    }

    let parts: [Part]

    @State private var reveal: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var totalKcal: Double {
        max(parts.reduce(0) { $0 + $1.grams * $1.kcalPerGram }, 0.0001)
    }

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { geo in
                HStack(spacing: 3) {
                    ForEach(parts) { part in
                        let share = CGFloat(part.grams * part.kcalPerGram / totalKcal)
                        Capsule()
                            .fill(part.color)
                            .frame(width: max(0, (geo.size.width - 6) * share * reveal))
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 8)
            .background(Capsule().fill(Color.white.opacity(0.1)))
            .clipShape(Capsule())

            HStack(spacing: 8) {
                ForEach(parts) { part in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(part.color)
                                .frame(width: 6, height: 6)
                            Text(part.title)
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(.white.opacity(0.7))
                                .lineLimit(1)
                        }
                        FormaCountingText(value: Int(part.grams.rounded()), suffix: " г")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .formaAnimation(FormaMotion.smooth, value: parts.map { $0.grams })
        .task {
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : FormaMotion.fill) {
                reveal = 1
            }
        }
    }
}
