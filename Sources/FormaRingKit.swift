import SwiftUI

// MARK: - Кольца везде
//
// Кольца на героях экранов понравились больше всего, поэтому любой показатель с целью — шаги, вода, привычка,
// опыт до уровня — рисуется тем же кольцом: градиент вдоль дуги, головка на конце, мягкое свечение.
// Здесь собраны готовые детали для карточек: мини-кольцо с содержимым в центре, плитка показателя
// и неделя из колец по дням (как календарь активности в Apple Fitness).

// MARK: Память о показанных кольцах

/// Какие кольца уже «выезжали» из нуля за этот запуск. Лента ленивая: карточка, уехавшая с экрана, уничтожается,
/// и при возврате её кольца и числа проигрывали заполнение заново — экран «дёргался» при прокрутке вверх-вниз.
/// Теперь заполнение играет один раз за запуск, а вернувшаяся карточка сразу показывает готовые значения.
enum FormaRevealMemory {
    private static let lock = NSLock()
    private static var revealed = Set<String>()

    static func contains(_ key: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return revealed.contains(key)
    }

    static func insert(_ key: String) {
        lock.lock()
        defer { lock.unlock() }
        revealed.insert(key)
    }
}

// MARK: Мини-кольцо

/// Кольцо с произвольным содержимым в центре. Само «выезжает» из нуля при первом появлении.
struct FormaMiniRing<Center: View>: View {
    let progress: Double
    let color: Color
    var size: CGFloat = 48
    /// Толщина дуги; по умолчанию — пятая часть размера, как у колец героев
    var lineWidth: CGFloat? = nil
    let center: () -> Center
    /// Ключ памяти: по умолчанию — место в коде, где кольцо создано
    private let revealKey: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRevealed: Bool

    init(progress: Double, color: Color, size: CGFloat = 48, lineWidth: CGFloat? = nil,
         fileID: String = #fileID, line: Int = #line, @ViewBuilder center: @escaping () -> Center) {
        self.progress = progress
        self.color = color
        self.size = size
        self.lineWidth = lineWidth
        self.center = center
        let key = "\(fileID):\(line)"
        self.revealKey = key
        _isRevealed = State(initialValue: FormaRevealMemory.contains(key))
    }

    private var width: CGFloat { lineWidth ?? max(4, size * 0.2) }

    var body: some View {
        let shown = (isRevealed || reduceMotion) ? progress : 0
        ZStack {
            // Свечение — только у крупных колец героев; у значков в списках и плитках оно незаметно, а стоит дорого
            FormaRing(progress: shown, color: color, lineWidth: width, glow: size >= 90 ? 0.38 : 0)
                .animation(reduceMotion ? nil : FormaMotion.fill, value: shown)
            center()
        }
        .frame(width: size, height: size)
        .task {
            guard !isRevealed else { return }
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            isRevealed = true
            FormaRevealMemory.insert(revealKey)
        }
    }
}

extension FormaMiniRing where Center == EmptyView {
    init(progress: Double, color: Color, size: CGFloat = 48, lineWidth: CGFloat? = nil,
         fileID: String = #fileID, line: Int = #line) {
        self.init(progress: progress, color: color, size: size, lineWidth: lineWidth, fileID: fileID, line: line) { EmptyView() }
    }
}

/// Мини-кольцо со значком в центре
struct FormaIconRing: View {
    let progress: Double
    let color: Color
    let symbol: String
    var size: CGFloat = 48
    private let fileID: String
    private let line: Int

    init(progress: Double, color: Color, symbol: String, size: CGFloat = 48, fileID: String = #fileID, line: Int = #line) {
        self.progress = progress
        self.color = color
        self.symbol = symbol
        self.size = size
        self.fileID = fileID
        self.line = line
    }

    var body: some View {
        FormaMiniRing(progress: progress, color: color, size: size, fileID: fileID, line: line) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.34, weight: .bold))
                .foregroundColor(color)
        }
    }
}

// MARK: Плитка показателя

/// Показатель с кольцом: значок в кольце слева, крупное значение и подпись справа.
/// Для плиток в сетке: `LazyVGrid` из двух колонок.
struct FormaRingTile: View {
    let title: String
    let value: String
    var unit: String = ""
    let progress: Double
    let color: Color
    let symbol: String
    var action: (() -> Void)? = nil

    var body: some View {
        let content = HStack(spacing: FormaSpacing.m) {
            FormaIconRing(progress: progress, color: color, symbol: symbol, size: 46)
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(FormaFont.unit)
                            .foregroundColor(Theme.textSecondary)
                            .lineLimit(1)
                    }
                }
                Text(title)
                    .font(FormaFont.caption)
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(FormaSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FormaSurfaceBackground(cornerRadius: FormaRadius.control, elevated: false, tint: color.opacity(0.9)))

        if let action {
            Button(action: {
                HapticManager.shared.impact(.light)
                action()
            }) { content }
                .buttonStyle(SpringPressButtonStyle(scaleAmount: 0.97, hapticStyle: nil))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(title)
                .accessibilityValue("\(value) \(unit), \(Int((progress * 100).rounded()))%")
        } else {
            content
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(title)
                .accessibilityValue("\(value) \(unit), \(Int((progress * 100).rounded()))%")
        }
    }
}

// MARK: Неделя из колец

/// Один день недели в полосе колец
struct FormaWeekRingDay: Identifiable, Equatable {
    let date: Date
    /// 0…1 (и больше): доля цели дня
    let progress: Double
    var id: Date { date }
}

/// Семь дней: буква дня, кольцо с числом внутри. Выбранный день подсвечен, сегодняшний подписан цветом.
struct FormaWeekRings: View {
    let days: [FormaWeekRingDay]
    let selected: Date?
    let color: Color
    var language: String = "ru"
    var onSelect: ((Date) -> Void)? = nil

    private var calendar: Calendar { .current }

    /// Форматтеры дня недели по языкам: создание форматтера дорого, а лента пересчитывается при каждой перерисовке
    private static let weekdayLock = NSLock()
    private static var weekdayFormatters: [String: DateFormatter] = [:]

    private static func weekdayFormatter(_ language: String) -> DateFormatter {
        weekdayLock.lock()
        defer { weekdayLock.unlock() }
        if let cached = weekdayFormatters[language] { return cached }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language)
        formatter.timeZone = TimeZone.autoupdatingCurrent
        formatter.dateFormat = "EE"
        weekdayFormatters[language] = formatter
        return formatter
    }

    private func letter(_ date: Date) -> String {
        String(Self.weekdayFormatter(language).string(from: date).prefix(2)).uppercased()
    }

    private func spokenLabel(_ day: FormaWeekRingDay) -> String {
        // Полная подпись нужна только VoiceOver; без него форматировать дату семь раз на кадр незачем
        guard UIAccessibility.isVoiceOverRunning else { return "" }
        return day.date.formatted(.dateTime.weekday(.wide).day().month().locale(Locale(identifier: language)))
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(days) { day in
                let isSelected = selected.map { calendar.isDate($0, inSameDayAs: day.date) } ?? false
                let isToday = calendar.isDateInToday(day.date)
                let isFuture = day.date > Date() && !isToday
                Button(action: {
                    guard let onSelect else { return }
                    HapticManager.shared.selection()
                    onSelect(day.date)
                }) {
                    VStack(spacing: 6) {
                        Text(letter(day.date))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(isToday ? color : Theme.textSecondary)
                        FormaMiniRing(progress: isFuture ? 0 : day.progress, color: color, size: 38, lineWidth: 5) {
                            Text("\(calendar.component(.day, from: day.date))")
                                .font(.system(size: 13, weight: isSelected ? .bold : .medium, design: .rounded))
                                .foregroundColor(isSelected || isToday ? Theme.textPrimary : Theme.textSecondary)
                        }
                        .padding(3)
                        .background(
                            Circle().fill(isSelected ? color.opacity(0.18) : Color.clear)
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(onSelect == nil)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(spokenLabel(day))
                .accessibilityValue("\(Int((day.progress * 100).rounded()))%")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}

// MARK: Процент в центре кольца

/// Число процентов в центре мини-кольца
struct FormaPercentCenter: View {
    let percent: Int
    var color: Color = Theme.textPrimary
    var size: CGFloat = 13

    var body: some View {
        VStack(spacing: 0) {
            Text("\(percent)")
                .font(.system(size: size + 3, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .monospacedDigit()
            Text("%")
                .font(.system(size: max(8, size - 4), weight: .semibold, design: .rounded))
                .foregroundColor(Theme.textSecondary)
        }
    }
}
