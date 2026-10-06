import SwiftUI

// MARK: - Типографика Forma
//
// В проекте 795 шрифтов, заданных размером вручную: они не растут вместе с настройкой «Размер текста»
// и не складываются в единую иерархию. Здесь — шкала на системных стилях текста (они масштабируются
// сами). Цифры — округлые, с моноширинными знаками, чтобы значения не «дрожали» при обновлении;
// текст — обычный SF. Новые экраны берут шрифт отсюда; старые переносим постепенно.

public enum FormaFont {
    /// Крупные числа на героях экрана.
    public static let largeMetric = Font.system(.largeTitle, design: .rounded, weight: .semibold)
    /// Числа в строках показателей.
    public static let metric = Font.system(.title2, design: .rounded, weight: .semibold)
    /// Заголовок блока.
    public static let title = Font.system(.title3, weight: .semibold)
    /// Заголовок внутри карточки.
    public static let headline = Font.system(.headline)
    /// Основной текст.
    public static let body = Font.system(.body)
    /// Единицы измерения и пояснения к числам.
    public static let unit = Font.system(.footnote, design: .rounded, weight: .medium)
    /// Подписи.
    public static let caption = Font.system(.caption)
    /// Надстрочная метка капителью: «СЕГОДНЯ», «ЦЕЛЬ».
    public static let overline = Font.system(.caption2, weight: .semibold)
}

extension Text {
    /// Надстрочная метка: мелкий полужирный шрифт с разрядкой, вторичный цвет.
    /// Регистр задаёт вызывающий код (`.uppercased()` у строки).
    func formaOverline() -> Text {
        self.font(FormaFont.overline)
            .tracking(0.8)
            .foregroundColor(Theme.textSecondary)
    }
}
