import SwiftUI

// MARK: - Лента с эффектом «карусели»
//
// Карточки плавно тускнеют и чуть сжимаются, пока уезжают за верхний или нижний край экрана, и
// «собираются» на месте, когда возвращаются. Шапка растворяется при прокрутке вверх.
// Один и тот же приём работает на всех вкладках: достаточно положить карточки в `FormaFeed`
// вместо `LazyVStack`/`VStack` — каждой карточке эффект добавляется автоматически.
//
// Эффект считается от положения карточки в прокрутке (visualEffect), без состояния и перерисовки
// экрана. Длинные блоки, которые не помещаются на экране, не тускнеют, пока читаются: затухание
// начинается только у самого края и не длиннее 220 pt. При включённом «Уменьшении движения»
// эффект отключён.

/// Чистая математика эффекта — отдельно от интерфейса, чтобы её можно было проверить тестами.
enum FormaScrollReveal {
    /// Длина зоны у края экрана, на которой карточка успевает погаснуть
    static let maxRamp: CGFloat = 220
    /// Насколько карточка тускнеет на самом краю (0.5 — вдвое)
    static let edgeDimming: CGFloat = 0.5
    /// Насколько карточка сжимается на самом краю
    static let edgeShrink: CGFloat = 0.03

    /// 1 — карточка в «спокойной зоне» (эффекта нет), 0 — полностью за краем экрана.
    /// Координаты — в системе прокрутки: `viewportMinY...viewportMaxY` — видимая область.
    static func visibility(minY: CGFloat, maxY: CGFloat, viewportMinY: CGFloat, viewportMaxY: CGFloat) -> CGFloat {
        // Нет видимой области (вью вне прокрутки) — эффекта нет
        guard viewportMaxY > viewportMinY else { return 1 }
        let height = max(maxY - minY, 1)
        let ramp = min(height, maxRamp)
        // Уходит вверх: нижний край карточки приближается к верхнему краю экрана
        let top = clamp((maxY - viewportMinY) / ramp)
        // Выезжает снизу: верхний край карточки приближается к нижнему краю экрана
        let bottom = clamp((viewportMaxY - minY) / ramp)
        return min(top, bottom)
    }

    static func opacity(visibility: CGFloat) -> CGFloat {
        1 - edgeDimming * (1 - clamp(visibility))
    }

    static func scale(visibility: CGFloat) -> CGFloat {
        1 - edgeShrink * (1 - clamp(visibility))
    }

    private static func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }
}

extension View {
    /// Карточка тускнеет и сжимается у края экрана при прокрутке.
    func formaCardReveal() -> some View {
        modifier(FormaScrollRevealModifier(isHeader: false))
    }

    /// Шапка экрана растворяется при прокрутке вверх.
    func formaHeaderFade() -> some View {
        modifier(FormaScrollRevealModifier(isHeader: true))
    }
}

private struct FormaScrollRevealModifier: ViewModifier {
    let isHeader: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else if isHeader {
            content.visualEffect { effect, proxy in
                let visibility = FormaScrollRevealModifier.visibility(of: proxy)
                return effect
                    .opacity(1 - 0.9 * (1 - visibility))
                    .scaleEffect(1 - 0.08 * (1 - visibility), anchor: .leading)
                    .blur(radius: 5 * (1 - visibility))
            }
        } else {
            content.visualEffect { effect, proxy in
                let visibility = FormaScrollRevealModifier.visibility(of: proxy)
                return effect
                    .opacity(FormaScrollReveal.opacity(visibility: visibility))
                    .scaleEffect(FormaScrollReveal.scale(visibility: visibility))
            }
        }
    }

    private static func visibility(of proxy: GeometryProxy) -> CGFloat {
        let frame = proxy.frame(in: .scrollView)
        let viewport = proxy.bounds(of: .scrollView) ?? .zero
        return FormaScrollReveal.visibility(
            minY: frame.minY,
            maxY: frame.maxY,
            viewportMinY: viewport.minY,
            viewportMaxY: viewport.maxY
        )
    }
}

/// Вертикальная лента карточек: замена `LazyVStack`/`VStack` на экранах вкладок.
/// Первый элемент считается шапкой экрана (если `collapsesHeader`), остальные — карточками.
struct FormaFeed<Content: View>: View {
    let spacing: CGFloat
    let collapsesHeader: Bool
    private let content: Content

    init(spacing: CGFloat = FormaLayout.sectionSpacing, collapsesHeader: Bool = true, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.collapsesHeader = collapsesHeader
        self.content = content()
    }

    var body: some View {
        if #available(iOS 18.0, *) {
            LazyVStack(spacing: spacing) {
                Group(subviews: content) { subviews in
                    ForEach(Array(subviews.enumerated()), id: \.element.id) { index, subview in
                        if index == 0 && collapsesHeader {
                            subview.formaHeaderFade()
                        } else {
                            subview.formaCardReveal()
                        }
                    }
                }
            }
        } else {
            // iOS 17: тот же вид ленты, но без эффекта прокрутки
            LazyVStack(spacing: spacing) {
                content
            }
        }
    }
}
