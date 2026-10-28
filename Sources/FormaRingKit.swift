import SwiftUI

// MARK: - Кольца везде
//
// Кольца на героях экранов понравились больше всего, поэтому любой показатель с целью — шаги, вода, привычка,
// опыт до уровня — рисуется тем же кольцом: градиент вдоль дуги, головка на конце, мягкое свечение.
// Здесь собраны готовые детали для карточек: мини-кольцо с содержимым в центре, плитка показателя
// и неделя из колец по дням (как календарь активности в Apple Fitness).

// MARK: Мини-кольцо

/// Кольцо с произвольным содержимым в центре. Само «выезжает» из нуля при появлении.
struct FormaMiniRing<Center: View>: View {
    let progress: Double
    let color: Color
    var size: CGFloat = 48
    /// Толщина дуги; по умолчанию — пятая часть размера, как у колец героев
    var lineWidth: CGFloat? = nil
    @ViewBuilder var center: () -> Center

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRevealed = false

    private var width: CGFloat { lineWidth ?? max(4, size * 0.2) }

    var body: some View {
        let shown = (isRevealed || reduceMotion) ? progress : 0
        ZStack {
            FormaRing(progress: shown, color: color, lineWidth: width)
                .animation(reduceMotion ? nil : FormaMotion.fill, value: shown)
            center()
        }
        .frame(width: size, height: size)
        .task {
            guard !isRevealed else { return }
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            isRevealed = true
        }
    }
}

extension FormaMiniRing where Center == EmptyView {
    init(progress: Double, color: Color, size: CGFloat = 48, lineWidth: CGFloat? = nil) {
        self.init(progress: progress, color: color, size: size, lineWidth: lineWidth) { EmptyView() }
    }
}

/// Мини-кольцо со значком в центре
struct FormaIconRing: View {
    let progress: Double
    let color: Color
    let symbol: String
    var size: CGFloat = 48

    var body: some View {
        FormaMiniRing(progress: progress, color: color, size: size) {
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

    private func letter(_ date: Date) -> String {
        let text = date.formatted(.dateTime.weekday(.abbreviated).locale(Locale(identifier: language)))
        return String(text.prefix(2)).uppercased()
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
                .accessibilityLabel(day.date.formatted(.dateTime.weekday(.wide).day().month().locale(Locale(identifier: language))))
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
