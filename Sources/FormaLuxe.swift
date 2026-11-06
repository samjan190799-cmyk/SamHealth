import SwiftUI

// MARK: - «Дорогой» слой дизайн-системы
//
// Фон — не чистый чёрный, а тёмный градиент с мягким цветным свечением в цвет раздела, нарисованный один раз
// в картинку; карточки — плоские сплошные плашки, как в приложении «Здоровье». Тот же язык, что у колец
// активности: насыщенный цвет на тёмном. Стеклянные карточки с градиентами, рамкой и тенью и живой градиентный фон
// убраны: на устройстве они роняли частоту кадров при прокрутке.
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
///
/// Рисунок (градиент и свечения) строится один раз на каждое сочетание «атмосфера + тема» и дальше показывается как
/// готовая картинка. Раньше он собирался из градиентов и `drawingGroup()` прямо на экране, и на устройстве это
/// заметно роняло частоту кадров при прокрутке на всех вкладках (замеры «Лаборатории производительности»).
public struct FormaBackdrop: View {
    public var ambience: FormaAmbience
    @Environment(\.colorScheme) private var colorScheme
    @FormaPerfFlag(FormaPerfKey.noBackdrop) private var perfNoBackdrop

    public init(_ ambience: FormaAmbience = .neutral) {
        self.ambience = ambience
    }

    public var body: some View {
        Group {
            if !perfNoBackdrop, let image = FormaBackdropImage.image(for: ambience, scheme: colorScheme) {
                Image(uiImage: image)
                    .resizable()
            } else {
                // Сплошной фон: запасной вариант, если картинку построить не удалось (и эксперимент лаборатории)
                Theme.background
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Готовые картинки фона: по одной на сочетание «атмосфера + светлая/тёмная тема»
@MainActor
enum FormaBackdropImage {
    private static var cache: [String: UIImage] = [:]

    static func image(for ambience: FormaAmbience, scheme: ColorScheme) -> UIImage? {
        let key = "\(ambience)-\(scheme == .dark ? "dark" : "light")"
        if let cached = cache[key] { return cached }

        // Градиенты плавные, поэтому размер «телефонный» с запасом по пропорциям: на экране картинка растягивается
        let size = CGSize(width: 390, height: 844)
        let renderer = ImageRenderer(content: FormaBackdropArt(ambience: ambience, scheme: scheme, size: size))
        renderer.scale = 1
        renderer.isOpaque = true
        guard let image = renderer.uiImage else { return nil }
        cache[key] = image
        return image
    }
}

/// Рисунок фона для картинки: градиент сверху вниз и цветные свечения
private struct FormaBackdropArt: View {
    let ambience: FormaAmbience
    let scheme: ColorScheme
    let size: CGSize

    var body: some View {
        let longSide = max(size.width, size.height)
        ZStack {
            LinearGradient(colors: [Theme.background, Theme.backgroundDeep], startPoint: .top, endPoint: .bottom)
            ForEach(Array(ambience.glows.enumerated()), id: \.offset) { _, glow in
                RadialGradient(
                    colors: [glow.color.opacity(scheme == .dark ? glow.intensity : glow.intensity * 0.5), glow.color.opacity(0)],
                    center: glow.center,
                    startRadius: 0,
                    endRadius: longSide * glow.radius
                )
            }
        }
        .frame(width: size.width, height: size.height)
        // ImageRenderer не наследует окружение приложения: тему для динамических цветов задаём явно
        .environment(\.colorScheme, scheme)
    }
}

// MARK: Поверхности

/// Подложка карточки: сплошная заливка на непрерывной форме, как у карточек в приложении «Здоровье».
///
/// Раньше это было «стекло»: вертикальный градиент с прозрачностью, градиентная рамка, радиальное свечение у «героев»
/// и тень. На десятках карточек это сильно роняло частоту кадров при прокрутке (замеры «Лаборатории производительности»
/// на устройстве), поэтому подложка стала плоской. Цвет остаётся: у «героев» и выделенных карточек сверху лежит
/// сплошной оттенок.
public struct FormaSurfaceBackground: View {
    public var cornerRadius: CGFloat
    /// Сохранён, чтобы не менять вызовы: тени у карточек больше нет
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
            .fill(isDark ? Color(red: 28 / 255, green: 29 / 255, blue: 35 / 255) : Color.white)
            .overlay {
                if let tint {
                    shape.fill(tint.opacity(isDark ? 0.12 : 0.07))
                }
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
