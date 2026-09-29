import SwiftUI

// MARK: - Токены дизайн-системы Forma
//
// Ориентир — Apple Fitness: плоские карточки на сгруппированном фоне, скругления «сплайном»
// (`.continuous`), почти без обводок и теней. Раньше в проекте было 17 разных радиусов, десятки
// значений отступов и несколько параллельных реализаций карточки; всё сведено к этим токенам.
// Правило: новое значение в вёрстку не вводим — берём ближайший токен.

/// Радиусы скругления. Три ступени вместо семнадцати.
public enum FormaRadius {
    /// Плашки, бейджи, мелкие кнопки.
    public static let chip: CGFloat = 10
    /// Кнопки, поля ввода, вложенные блоки внутри карточки.
    public static let control: CGFloat = 14
    /// Карточки, панели, крупные контейнеры.
    public static let card: CGFloat = 20
}

/// Шкала отступов с шагом 4 pt.
public enum FormaSpacing {
    public static let xs: CGFloat = 4
    public static let s: CGFloat = 8
    public static let m: CGFloat = 12
    public static let l: CGFloat = 16
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32

    /// Поля экрана слева и справа.
    public static let screenMargin: CGFloat = 16
}

extension View {
    /// Плоская поверхность в стиле Apple Fitness: заливка цвета карточки на непрерывной форме.
    /// Содержимое обрезается по форме — так же, как это делал `.cornerRadius`.
    public func formaSurface(_ radius: CGFloat = FormaRadius.card) -> some View {
        self
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// Единственная тень в системе — для элементов, которые парят над контентом
    /// (плавающие кнопки, панели поверх камеры). Обычные карточки плоские, без тени.
    public func formaFloatingShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.14), radius: 16, x: 0, y: 6)
    }
}
