import SwiftUI

// MARK: - Привычки компактными строками
//
// Раньше каждая привычка была карточкой высотой в пол-экрана: кольцо, бейджи, цель, 14 точек, большая кнопка
// «Выполнить» и кнопка совета. Пять привычек занимали три экрана прокрутки, а отметить день можно было только
// большой кнопкой внизу карточки. Теперь привычка — строка: нажатие на кольцо отмечает день, нажатие на строку
// раскрывает подробности (цель, две недели, совет ИИ, действия). Правила те же, что у остальных карточек:
// плоская заливка, размеры и цвета из токенов, зоны нажатия не меньше 44 pt.

// MARK: Общие части строки

/// Стрелка раскрытия в конце строки
private struct HabitRowChevron: View {
    let isExpanded: Bool

    var body: some View {
        Image(systemName: "chevron.down")
            .font(.footnote.weight(.semibold))
            .foregroundColor(Theme.textSecondary)
            .rotationEffect(.degrees(isExpanded ? 180 : 0))
            .accessibilityHidden(true)
    }
}

/// Название привычки и строка статуса под ним: серия и одно уточнение
private struct HabitRowTitle: View {
    let title: String
    let streakText: String
    let detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.xs) {
            Text(title)
                .font(FormaFont.headline)
                .foregroundColor(Theme.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.leading)
            HStack(spacing: FormaSpacing.xs) {
                Image(systemName: "flame.fill")
                    .font(.caption)
                    .foregroundColor(Theme.flameOrange)
                Text(streakText)
                    .font(FormaFont.caption)
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
                if let detail {
                    Text("· \(detail)")
                        .font(FormaFont.caption)
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Путь к цели: «9 из 30 дн.» и тонкая плоская полоса
private struct HabitGoalLine: View {
    let title: String
    let current: Int
    let total: Int
    let progress: Double
    let remaining: Int?
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.s) {
            HStack {
                Text("\(title): \(current) из \(total) дн.")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: FormaSpacing.s)
                if let remaining {
                    Text("Осталось \(remaining) дн.")
                        .font(FormaFont.caption)
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(tint)
                        .frame(width: max(6, geo.size.width * CGFloat(min(1, max(0, progress)))))
                }
            }
            .frame(height: 6)
        }
    }
}

/// Две недели точками: слева «две недели назад», справа «сегодня»
private struct HabitTwoWeekDots: View {
    enum DotState {
        case empty, done, frozen
    }

    let states: [DotState]
    let tint: Color
    let todayText: String
    let todayTint: Color

    private func color(for state: DotState) -> Color {
        switch state {
        case .empty: return Color.primary.opacity(0.1)
        case .done: return tint
        case .frozen: return Theme.waterColor
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.s) {
            // Точки делят ширину поровну: на узком экране ряд не вылезает за карточку
            HStack(spacing: 0) {
                ForEach(Array(states.enumerated()), id: \.offset) { _, state in
                    ZStack {
                        Circle()
                            .fill(color(for: state))
                            .frame(width: 12, height: 12)
                        if state == .frozen {
                            Image(systemName: "snowflake")
                                .font(.system(size: 6, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            HStack {
                Text("2 недели назад")
                    .font(FormaFont.caption)
                    .foregroundColor(Theme.textSecondary)
                Spacer(minLength: FormaSpacing.s)
                Text(todayText)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(todayTint)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(todayText)
    }
}

/// Совет ИИ по одной привычке
private struct HabitAdviceBlock: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.s) {
            Text("Совет ИИ")
                .formaEyebrow(Theme.aiViolet)
            Text(text)
                .font(.subheadline)
                .foregroundColor(Theme.textPrimary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(FormaSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.aiViolet.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
    }
}

/// Действия в раскрытой строке: совет ИИ и меню с редкими действиями
private struct HabitRowActions<MenuItems: View>: View {
    let isLoadingAdvice: Bool
    let onFetchAdvice: () -> Void
    private let menuItems: MenuItems

    init(isLoadingAdvice: Bool, onFetchAdvice: @escaping () -> Void, @ViewBuilder menuItems: () -> MenuItems) {
        self.isLoadingAdvice = isLoadingAdvice
        self.onFetchAdvice = onFetchAdvice
        self.menuItems = menuItems()
    }

    var body: some View {
        HStack(spacing: FormaSpacing.s) {
            FormaTintedButton(title: isLoadingAdvice ? "Думаю…" : "Совет ИИ", icon: "sparkles", tint: Theme.aiViolet, action: onFetchAdvice)
                .disabled(isLoadingAdvice)
                .opacity(isLoadingAdvice ? 0.6 : 1)

            Menu {
                menuItems
            } label: {
                Label("Ещё", systemImage: "ellipsis")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Theme.textPrimary)
                    .padding(.horizontal, FormaSpacing.l)
                    .frame(minHeight: FormaTouch.minTarget)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
            }
        }
    }
}

// MARK: Полезная привычка

struct HabitBuildRow: View {
    let habit: HabitItem
    let isCompletedToday: Bool
    var onToggleCompletion: () -> Void
    var onFetchAdvice: () -> Void
    var onDelete: () -> Void

    @ObservedObject private var habitsManager = HabitsManager.shared
    @State private var isExpanded = false

    private var isFrozen: Bool { habit.isFrozenToday }

    private var ringColor: Color {
        isFrozen ? Theme.waterColor : habit.color
    }

    private var ringSymbol: String {
        if isFrozen { return "snowflake" }
        return isCompletedToday ? "checkmark" : habit.icon
    }

    /// Одно уточнение рядом с серией: самое важное на сегодня
    private var detail: String {
        if isFrozen { return "серия под щитом" }
        if habit.isHealthKitAutoCompletedToday { return "зачтено из «Здоровья»" }
        if let total = habit.targetGoalTotalDays { return "\(habit.currentDaysTowardsGoal) из \(total) дн." }
        return habit.effectiveTimeOfDay.badgeTitle
    }

    private var ringAccessibilityLabel: String {
        if isFrozen { return "Снять защиту серии: \(habit.title)" }
        return isCompletedToday ? "Отменить выполнение: \(habit.title)" : "Отметить выполненной: \(habit.title)"
    }

    private var todayText: String {
        if isFrozen { return "Сегодня: под щитом" }
        return isCompletedToday ? "Сегодня: выполнено" : "Сегодня: не отмечено"
    }

    private var dotStates: [HabitTwoWeekDots.DotState] {
        (0..<14).map { dayOffset in
            let date = Calendar.current.date(byAdding: .day, value: -(13 - dayOffset), to: Date()) ?? Date()
            let key = AppDateHelper.dayKey(for: date)
            if habit.effectiveFrozenDates.contains(key) { return .frozen }
            return habit.completedDates.contains(key) ? .done : .empty
        }
    }

    /// Нажатие на кольцо: отметить день. У замороженной привычки снимает щит, как раньше делала главная кнопка
    private func ringTapped() {
        if isFrozen {
            _ = habitsManager.unfreezeHabit(id: habit.id)
        } else {
            onToggleCompletion()
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.m) {
            HStack(spacing: FormaSpacing.m) {
                Button(action: ringTapped) {
                    // Кольцо показывает сегодняшний день: пустое до отметки, полное после
                    FormaMiniRing(progress: (isCompletedToday || isFrozen) ? 1 : 0, color: ringColor, size: 48, lineWidth: 6) {
                        Image(systemName: ringSymbol)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(ringColor)
                    }
                    .frame(width: 52, height: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(SpringPressButtonStyle(scaleAmount: 0.9, hapticStyle: .medium))
                .accessibilityLabel(ringAccessibilityLabel)

                HabitRowTitle(title: habit.title, streakText: "\(habit.buildStreakDays) дн.", detail: detail)

                HabitRowChevron(isExpanded: isExpanded)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(FormaMotion.smooth) {
                    isExpanded.toggle()
                }
            }

            if isExpanded {
                if let total = habit.targetGoalTotalDays, let progress = habit.goalProgressFraction {
                    HabitGoalLine(
                        title: "Цель",
                        current: habit.currentDaysTowardsGoal,
                        total: total,
                        progress: progress,
                        remaining: habit.goalRemainingDays,
                        tint: habit.color
                    )
                }

                HabitTwoWeekDots(
                    states: dotStates,
                    tint: habit.color,
                    todayText: todayText,
                    todayTint: isCompletedToday && !isFrozen ? Theme.exerciseColor : Theme.textSecondary
                )

                if !habit.subtitle.isEmpty {
                    Text(habit.subtitle)
                        .font(FormaFont.caption)
                        .foregroundColor(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HabitRowActions(
                    isLoadingAdvice: habitsManager.loadingAdviceHabitId == habit.id,
                    onFetchAdvice: onFetchAdvice
                ) {
                    if isFrozen {
                        Button {
                            _ = habitsManager.unfreezeHabit(id: habit.id)
                        } label: {
                            Label("Снять защиту (вернуть щит)", systemImage: "flame")
                        }
                    } else if !isCompletedToday {
                        Button {
                            _ = habitsManager.freezeHabit(id: habit.id)
                        } label: {
                            Label("Защитить серию щитом", systemImage: "snowflake")
                        }
                    }
                    Divider()
                    Button(role: .destructive, action: onDelete) {
                        Label("Удалить привычку", systemImage: "trash")
                    }
                }

                if let advice = habitsManager.habitSpecificAdvice[habit.id] {
                    HabitAdviceBlock(text: advice)
                }
            }
        }
        .premiumCard()
    }
}

// MARK: Отказ от вредной привычки

struct HabitQuitRow: View {
    let habit: HabitItem
    let isMarkedToday: Bool
    var onMarkTodayResisted: () -> Void
    var onMarkTodayRelapse: () -> Void
    var onSOS: () -> Void
    var onFetchAdvice: () -> Void
    var onDelete: () -> Void

    @ObservedObject private var habitsManager = HabitsManager.shared
    @State private var isExpanded = false

    private var isFrozen: Bool { habit.isFrozenToday }

    private var ringColor: Color {
        isFrozen ? Theme.waterColor : habit.color
    }

    private var ringSymbol: String {
        if isFrozen { return "snowflake" }
        return isMarkedToday ? "checkmark" : habit.icon
    }

    /// Кольцо: путь к цели, если задан срок, иначе дни без срыва из ближайших 30
    private var ringProgress: Double {
        habit.goalProgressFraction ?? min(1, Double(habit.cleanStreakDays) / 30.0)
    }

    private var detail: String? {
        if isFrozen { return "серия под щитом" }
        if habit.totalMoneySaved > 0 { return "\(Int(habit.totalMoneySaved)) ₽ сбережено" }
        if habit.urgeResistedCount > 0 { return "выдержек: \(habit.urgeResistedCount)" }
        return nil
    }

    private var todayText: String {
        isMarkedToday ? "Сегодня: чисто" : "Сегодня: не отмечено"
    }

    /// Чистые дни идут от сегодняшнего дня назад, поэтому закрашиваются точки справа
    private var dotStates: [HabitTwoWeekDots.DotState] {
        let cleanDays = min(14, max(0, habit.cleanStreakDays))
        return (0..<14).map { $0 >= 14 - cleanDays ? .done : .empty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.m) {
            HStack(spacing: FormaSpacing.m) {
                Button(action: onMarkTodayResisted) {
                    FormaMiniRing(progress: ringProgress, color: ringColor, size: 48, lineWidth: 6) {
                        Image(systemName: ringSymbol)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(ringColor)
                    }
                    .frame(width: 52, height: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(SpringPressButtonStyle(scaleAmount: 0.9, hapticStyle: .medium))
                .accessibilityLabel(isMarkedToday ? "Сегодня отмечено: \(habit.title)" : "Отметить, что сдержался: \(habit.title)")

                HabitRowTitle(title: habit.title, streakText: "\(habit.cleanStreakDays) дн. чисто", detail: detail)

                // Дыхание при тяге нужно сразу, без раскрытия строки
                Button(action: onSOS) {
                    Text("SOS")
                        .font(.footnote.weight(.bold))
                        .foregroundColor(Theme.moveColor)
                        .padding(.horizontal, FormaSpacing.m)
                        .frame(minHeight: 32)
                        .background(Theme.moveColor.opacity(0.14))
                        .clipShape(Capsule(style: .continuous))
                        .frame(minHeight: FormaTouch.minTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(SpringPressButtonStyle(scaleAmount: 0.94, hapticStyle: .medium))
                .accessibilityLabel("SOS-дыхание: \(habit.title)")

                HabitRowChevron(isExpanded: isExpanded)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(FormaMotion.smooth) {
                    isExpanded.toggle()
                }
            }

            if isExpanded {
                if let total = habit.targetGoalTotalDays, let progress = habit.goalProgressFraction {
                    HabitGoalLine(
                        title: "Цель воздержания",
                        current: habit.cleanStreakDays,
                        total: total,
                        progress: progress,
                        remaining: habit.goalRemainingDays,
                        tint: habit.color
                    )
                }

                if let milestone = habit.currentActiveMilestone {
                    HStack(spacing: FormaSpacing.s) {
                        Image(systemName: milestone.badgeIcon)
                            .font(.subheadline)
                            .foregroundColor(Theme.flameOrange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Майлстоун: \(milestone.title)")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(Theme.textPrimary)
                            if let next = habit.nextMilestone {
                                Text("Следующая цель: \(next.title) (\(max(0, next.days - habit.cleanStreakDays)) дн.)")
                                    .font(FormaFont.caption)
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }

                HabitTwoWeekDots(
                    states: dotStates,
                    tint: habit.color,
                    todayText: todayText,
                    todayTint: isMarkedToday ? Theme.exerciseColor : Theme.textSecondary
                )

                HabitRowActions(
                    isLoadingAdvice: habitsManager.loadingAdviceHabitId == habit.id,
                    onFetchAdvice: onFetchAdvice
                ) {
                    if isFrozen {
                        Button {
                            _ = habitsManager.unfreezeHabit(id: habit.id)
                        } label: {
                            Label("Снять защиту (вернуть щит)", systemImage: "flame")
                        }
                    } else {
                        Button {
                            _ = habitsManager.freezeHabit(id: habit.id)
                        } label: {
                            Label("Защитить серию щитом", systemImage: "snowflake")
                        }
                    }
                    Button(role: .destructive, action: onMarkTodayRelapse) {
                        Label("Зафиксировать срыв", systemImage: "arrow.counterclockwise")
                    }
                    Divider()
                    Button(role: .destructive, action: onDelete) {
                        Label("Удалить привычку", systemImage: "trash")
                    }
                }

                if let advice = habitsManager.habitSpecificAdvice[habit.id] {
                    HabitAdviceBlock(text: advice)
                }
            }
        }
        .premiumCard()
    }
}

// MARK: - ИИ-коуч по привычкам
//
// Раньше на двух вкладках стояли два самодельных ИИ-блока в личном цвете тренера. Теперь один блок в общем
// виде ИИ-карточек: шапка с портретом, текст, одна второстепенная кнопка фиолетового цвета.
struct HabitsAICoachCard: View {
    let title: String
    let placeholder: String
    let actionTitle: String
    let onAnalyze: () -> Void

    @ObservedObject private var habitsManager = HabitsManager.shared
    @ObservedObject private var coachManager = AICoachManager.shared

    var body: some View {
        let coach = coachManager.currentCoach
        VStack(alignment: .leading, spacing: FormaSpacing.m) {
            FormaAICardHeader(
                title: title,
                subtitle: "\(coach.name) · \(coach.specialty)",
                avatarAssetName: coach.avatarAssetName
            )

            if let advice = habitsManager.aiDisciplineAdvice {
                Text(advice)
                    .font(.subheadline)
                    .foregroundColor(Theme.textPrimary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(placeholder)
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            FormaTintedButton(
                title: habitsManager.isAnalyzingWithAI ? "Анализ…" : actionTitle,
                icon: "sparkles",
                tint: Theme.aiViolet,
                action: onAnalyze
            )
            .disabled(habitsManager.isAnalyzingWithAI)
            .opacity(habitsManager.isAnalyzingWithAI ? 0.6 : 1)
        }
        .premiumCard()
    }
}
