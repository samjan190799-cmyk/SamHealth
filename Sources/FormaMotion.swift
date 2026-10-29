import SwiftUI

// MARK: - Движение Forma
//
// Раньше анимации были разбросаны по коду: 96 вызовов withAnimation с разными параметрами, ни одной
// проверки «Уменьшение движения». Теперь у интерфейса четыре скорости и готовые приёмы.
// Эффект «карусели» при прокрутке (карточки тускнеют у края, шапка растворяется) живёт в FormaFeed.swift.
// Правило: одно движение на одно действие, не длиннее полусекунды (кроме заполнения колец).

public enum FormaMotion {
    /// Отклик на касание: переключатели, выбор, нажатия.
    public static let quick = Animation.snappy(duration: 0.28)
    /// Основное движение интерфейса: появление, перестановка, раскрытие.
    public static let smooth = Animation.smooth(duration: 0.5)
    /// Награда и успех: чуть живее, с лёгким перелётом.
    public static let bounce = Animation.bouncy(duration: 0.55, extraBounce: 0.12)
    /// Заполнение колец и шкал: единственное «длинное» движение, оно главное на экране.
    public static let fill = Animation.smooth(duration: 1.1)

    /// Задержка между соседними элементами каскада.
    public static let staggerStep: Double = 0.06
    /// В каскаде участвуют только первые элементы, иначе экран «собирается» слишком долго.
    public static let staggerLimit = 6
}

extension View {
    /// Мягкое появление при первом показе: прозрачность и сдвиг на 14 pt вверх.
    /// `index` задаёт очередь в каскаде. Играет один раз за запуск приложения: лента ленивая, и карточка,
    /// вернувшаяся после прокрутки, раньше «выезжала» заново, из-за чего экран дёргался. При включённом
    /// «Уменьшении движения» элемент просто виден сразу.
    func formaAppear(index: Int = 0, fileID: String = #fileID, line: Int = #line) -> some View {
        modifier(FormaAppearModifier(index: index, key: "appear:\(fileID):\(line)"))
    }

    /// Как `.animation(_:value:)`, но без анимации при включённом «Уменьшении движения».
    func formaAnimation<V: Equatable>(_ animation: Animation = FormaMotion.smooth, value: V) -> some View {
        modifier(FormaAnimationModifier(animation: animation, value: value))
    }
}

private struct FormaAppearModifier: ViewModifier {
    let index: Int
    let key: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Bool

    init(index: Int, key: String) {
        self.index = index
        self.key = key
        _shown = State(initialValue: FormaRevealMemory.contains(key))
    }

    func body(content: Content) -> some View {
        let visible = shown || reduceMotion
        content
            .opacity(visible ? 1.0 : 0.0)
            .offset(y: visible ? 0 : 14)
            .onAppear {
                guard !shown else { return }
                let delay = Double(min(index, FormaMotion.staggerLimit)) * FormaMotion.staggerStep
                withAnimation(FormaMotion.smooth.delay(delay)) {
                    shown = true
                }
                FormaRevealMemory.insert(key)
            }
    }
}

private struct FormaAnimationModifier<V: Equatable>: ViewModifier {
    let animation: Animation
    let value: V
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}
