import SwiftUI

// MARK: - «Дорогой» слой дизайн-системы
//
// Глубина вместо плоскости: фон — не чистый чёрный, а тёмный градиент с мягким цветным свечением
// в цвет раздела; карточки — «стекло»: полупрозрачная заливка с вертикальным градиентом, светлая
// грань по верхнему краю и мягкая тень. Тот же язык, что у колец активности: насыщенный цвет на тёмном.
// Всё собрано здесь, а старые модификаторы (premiumCard, formaSurface) просто рисуют эти поверхности.

// MARK: Атмосфера экрана

/// Цветовое настроение вкладки: от него зависит свечение фона
public enum FormaAmbience {
    case home, workouts, nutrition, habits, settings, neutral

    struct Glow {
        let color: Color
        let center: UnitPoint
        /// Радиус в долях большей стороны экрана
        let radius: CGFloat
        /// Яркость в тёмной теме; в светлой — вдвое тише
        let intensity: Double
    }

    var glows: [Glow] {
        switch self {
        case .home:
            return [Glow(color: Theme.moveColor, center: UnitPoint(x: 0.08, y: 0.0), radius: 0.62, intensity: 0.26),
                    Glow(color: Theme.standColor, center: UnitPoint(x: 1.0, y: 0.06), radius: 0.55, intensity: 0.18)]
        case .workouts:
            return [Glow(color: Theme.exerciseColor, center: UnitPoint(x: 0.1, y: 0.0), radius: 0.62, intensity: 0.24),
                    Glow(color: Theme.cyberLime, center: UnitPoint(x: 1.0, y: 0.08), radius: 0.5, intensity: 0.12)]
        case .nutrition:
            return [Glow(color: Color(red: 1.0, green: 0.55, blue: 0.12), center: UnitPoint(x: 0.08, y: 0.0), radius: 0.62, intensity: 0.24),
                    Glow(color: Color(red: 1.0, green: 0.82, blue: 0.2), center: UnitPoint(x: 1.0, y: 0.08), radius: 0.5, intensity: 0.13)]
        case .habits:
            return [Glow(color: Theme.aiViolet, center: UnitPoint(x: 0.08, y: 0.0), radius: 0.62, intensity: 0.26),
                    Glow(color: Theme.flameOrange, center: UnitPoint(x: 1.0, y: 0.08), radius: 0.5, intensity: 0.14)]
        case .settings:
            return [Glow(color: Color(red: 0.25, green: 0.45, blue: 1.0), center: UnitPoint(x: 0.08, y: 0.0), radius: 0.6, intensity: 0.18),
                    Glow(color: Theme.aiViolet, center: UnitPoint(x: 1.0, y: 0.08), radius: 0.5, intensity: 0.12)]
        case .neutral:
            return [Glow(color: Theme.aiViolet, center: UnitPoint(x: 0.1, y: 0.0), radius: 0.6, intensity: 0.14),
                    Glow(color: Theme.standColor, center: UnitPoint(x: 1.0, y: 0.08), radius: 0.5, intensity: 0.09)]
        }
    }
}

/// Фон экрана: тёмный градиент и цветное свечение сверху. Неподвижен — контент прокручивается поверх.
public struct FormaBackdrop: View {
    public var ambience: FormaAmbience
    @Environment(\.colorScheme) private var colorScheme

    public init(_ ambience: FormaAmbience = .neutral) {
        self.ambience = ambience
    }

    public var body: some View {
        GeometryReader { proxy in
            let longSide = max(proxy.size.width, proxy.size.height)
            ZStack {
                LinearGradient(colors: [Theme.background, Theme.backgroundDeep], startPoint: .top, endPoint: .bottom)
                ForEach(Array(ambience.glows.enumerated()), id: \.offset) { _, glow in
                    RadialGradient(
                        colors: [glow.color.opacity(colorScheme == .dark ? glow.intensity : glow.intensity * 0.5), glow.color.opacity(0)],
                        center: glow.center,
                        startRadius: 0,
                        endRadius: longSide * glow.radius
                    )
                }
            }
            // Фон неподвижен: одной текстурой он не пересчитывается, пока экран прокручивается и обновляются данные
            .drawingGroup()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: Поверхности

/// Подложка карточки: «стекло» с вертикальным градиентом, светлой гранью сверху и (для приподнятых) тенью.
public struct FormaSurfaceBackground: View {
    public var cornerRadius: CGFloat
    public var elevated: Bool
    public var tint: Color?
    @Environment(\.colorScheme) private var colorScheme

    public init(cornerRadius: CGFloat = FormaRadius.card, elevated: Bool = true, tint: Color? = nil) {
        self.cornerRadius = cornerRadius
        self.elevated = elevated
        self.tint = tint
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let isDark = colorScheme == .dark
        shape
            .fill(
                LinearGradient(
                    colors: isDark
                        ? [Color(red: 30 / 255, green: 31 / 255, blue: 38 / 255).opacity(0.9),
                           Color(red: 18 / 255, green: 19 / 255, blue: 24 / 255).opacity(0.9)]
                        : [Color.white, Color(red: 252 / 255, green: 251 / 255, blue: 249 / 255)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay {
                if let tint {
                    // Цветной оттенок для «героев» и выделенных карточек: свечение из верхнего угла
                    shape.fill(
                        RadialGradient(colors: [tint.opacity(isDark ? 0.22 : 0.12), tint.opacity(0)],
                                       center: .topLeading, startRadius: 0, endRadius: 320)
                    )
                }
            }
            .overlay(
                shape.strokeBorder(
                    LinearGradient(
                        colors: isDark
                            ? [Color.white.opacity(0.16), Color.white.opacity(0.05), Color.white.opacity(0.02)]
                            : [Color.black.opacity(0.05), Color.black.opacity(0.04)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.8
                )
            )
            .modifier(FormaCardShadow(isEnabled: elevated && !isDark))
    }
}

/// Мягкая тень приподнятой карточки. Тень требует отдельного прохода отрисовки на каждую карточку, поэтому она
/// рисуется только там, где видна: в светлой теме. В тёмной теме чёрная тень на почти чёрном фоне незаметна.
private struct FormaCardShadow: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content.shadow(color: Color(red: 0.32, green: 0.24, blue: 0.12).opacity(0.09), radius: 12, x: 0, y: 6)
        } else {
            content
        }
    }
}

extension View {
    /// Карточка-«герой» с цветным свечением в углу: главный блок экрана
    public func formaHeroCard(tint: Color, padding: CGFloat = FormaSpacing.xl) -> some View {
        self
            .padding(padding)
            .background(FormaSurfaceBackground(cornerRadius: FormaRadius.hero, elevated: true, tint: tint))
    }

    /// Надпись-«бровь» над заголовком: мелкие прописные с разрядкой
    public func formaEyebrow(_ color: Color = Theme.textSecondary) -> some View {
        self
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .textCase(.uppercase)
            .kerning(1.2)
            .foregroundColor(color)
    }
}

// MARK: Приветствие

public enum FormaGreeting {
    /// «Доброе утро» и т. д. по времени суток
    public static func title(for date: Date = Date(), calendar: Calendar = .current) -> String {
        switch calendar.component(.hour, from: date) {
        case 5..<12: return "Доброе утро"
        case 12..<17: return "Добрый день"
        case 17..<23: return "Добрый вечер"
        default: return "Доброй ночи"
        }
    }

    /// Форматтеры по языкам: создание DateFormatter стоит дорого, а строка пересчитывается при каждой перерисовке Главной
    private static let formatterLock = NSLock()
    private static var formatters: [String: DateFormatter] = [:]

    private static func formatter(for language: String) -> DateFormatter {
        formatterLock.lock()
        defer { formatterLock.unlock() }
        if let cached = formatters[language] { return cached }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language)
        formatter.timeZone = TimeZone.autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("EEEEdMMMM")
        formatters[language] = formatter
        return formatter
    }

    /// «Вторник, 27 октября»
    public static func dateLine(for date: Date = Date(), language: String = "ru") -> String {
        let text = formatter(for: language).string(from: date)
        return text.prefix(1).uppercased() + text.dropFirst()
    }
}
