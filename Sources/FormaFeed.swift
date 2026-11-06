import SwiftUI

// MARK: - Лента карточек
//
// Вертикальная лента экрана вкладки: ленивый стек с общим промежутком между карточками.
//
// Раньше каждая карточка ещё тускнела и сжималась у края экрана, а шапка растворялась при прокрутке («карусель»).
// Эффект пересчитывался на каждом кадре прокрутки для каждой карточки и делал её частично прозрачной, а это
// отдельный проход отрисовки на каждую, поэтому лента «тяжелела». Эффект убран ради плавной прокрутки.

/// Вертикальная лента карточек: замена `LazyVStack`/`VStack` на экранах вкладок.
struct FormaFeed<Content: View>: View {
    let spacing: CGFloat
    private let content: Content

    init(spacing: CGFloat = FormaLayout.sectionSpacing, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        LazyVStack(spacing: spacing) {
            content
        }
    }
}
