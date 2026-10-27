import SwiftUI

// MARK: - Раздел тренировок в новом стиле
//
// Те же приёмы, что на главной: один герой экрана с кольцами, плоские карточки, лаймовый акцент
// только на главном действии и выбранном состоянии, плавное движение. Логику тренировок
// (старт, пауза, подходы, сохранение) эти компоненты не трогают: они только показывают данные,
// которые им передаёт `WorkoutsView`.

// MARK: Показатели дня

/// Что человек сделал за выбранный день. Формулы расчёта остались в `WorkoutsView.dayMetrics(for:)`
/// ровно такими же, как были в старой карточке дня.
struct WorkoutDayMetrics: Equatable {
    var steps: Int
    var distanceKm: Double
    var activeCalories: Double
    var workoutMinutes: Int
    var workoutCount: Int
}

/// Отметка под числом в ленте недели.
enum WorkoutDayMarker {
    case none
    case steps
    case workout
}

// MARK: Герой: кольца дня и лента недели

struct WorkoutsHeroCard: View {
    let days: [Date]
    let selectedDate: Date
    let metrics: WorkoutDayMetrics
    let stepGoal: Int
    let calorieGoal: Double
    let minutesGoal: Int
    let language: String
    let marker: (Date) -> WorkoutDayMarker
    let onSelect: (Date) -> Void
    let onOpenHistory: () -> Void

    /// Становится истиной через долю секунды после появления карточки: кольца и числа «выезжают» из нуля.
    @State private var isRevealed = false

    private func tr(_ key: String) -> String {
        LocalizationManager.tr(key, lang: language)
    }

    private var locale: Locale { Locale(identifier: language) }
    private var isToday: Bool { Calendar.current.isDateInToday(selectedDate) }

    private func capitalized(_ text: String) -> String {
        text.prefix(1).uppercased() + text.dropFirst()
    }

    private var titleText: String {
        if isToday { return tr("today") }
        return capitalized(selectedDate.formatted(.dateTime.weekday(.wide).locale(locale)))
    }

    private var subtitleText: String {
        if isToday {
            return capitalized(selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(locale)))
        }
        return selectedDate.formatted(.dateTime.day().month(.wide).locale(locale))
    }

    private func fraction(_ value: Double, _ goal: Double) -> Double {
        goal > 0 ? max(0, value) / goal : 0
    }

    private var minutesFraction: Double { fraction(Double(metrics.workoutMinutes), Double(minutesGoal)) }
    private var caloriesFraction: Double { fraction(metrics.activeCalories, calorieGoal) }
    private var stepsFraction: Double { fraction(Double(metrics.steps), Double(stepGoal)) }

    private func grouped(_ value: Double) -> String {
        LocalizationManager.formatNumber(Int(value.rounded()), lang: language)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.l) {
            header

            HStack(spacing: 2) {
                ForEach(days, id: \.self) { date in
                    dayChip(date)
                }
            }

            HStack(spacing: FormaSpacing.xl) {
                FormaRingStack(
                    rings: [
                        FormaRingSpec(id: "minutes", progress: minutesFraction, color: Theme.exerciseColor, symbol: "figure.run"),
                        FormaRingSpec(id: "calories", progress: caloriesFraction, color: Theme.flameOrange, symbol: "flame.fill"),
                        FormaRingSpec(id: "steps", progress: stepsFraction, color: Theme.moveColor, symbol: "figure.walk")
                    ],
                    isRevealed: isRevealed
                )
                .frame(width: 144, height: 144)

                VStack(alignment: .leading, spacing: FormaSpacing.m) {
                    HeroMetricRow(
                        title: tr("wk_hero_minutes"),
                        color: Theme.exerciseColor,
                        value: isRevealed ? "\(metrics.workoutMinutes)" : "0",
                        numeric: isRevealed ? Double(metrics.workoutMinutes) : 0,
                        detail: "/ \(minutesGoal) " + tr("wk_minutes_unit"),
                        percent: Int(minutesFraction * 100),
                        action: onOpenHistory
                    )
                    HeroMetricRow(
                        title: tr("wk_hero_energy"),
                        color: Theme.flameOrange,
                        value: isRevealed ? grouped(metrics.activeCalories) : "0",
                        numeric: isRevealed ? metrics.activeCalories : 0,
                        detail: "/ " + grouped(calorieGoal) + " " + tr("kcal"),
                        percent: Int(caloriesFraction * 100),
                        action: onOpenHistory
                    )
                    HeroMetricRow(
                        title: tr("hero_steps"),
                        color: Theme.moveColor,
                        value: isRevealed ? grouped(Double(metrics.steps)) : "0",
                        numeric: isRevealed ? Double(metrics.steps) : 0,
                        detail: "/ " + grouped(Double(stepGoal)),
                        percent: Int(stepsFraction * 100),
                        action: onOpenHistory
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(FormaSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .formaSurface()
        .task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            isRevealed = true
        }
    }

    private var header: some View {
        Button(action: onOpenHistory) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(titleText)
                        .font(FormaFont.title)
                        .foregroundColor(Theme.textPrimary)
                    Text(subtitleText)
                        .font(FormaFont.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Text(tr("workouts_activity_history"))
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                }
                .font(FormaFont.caption)
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tr("workouts_activity_history"))
    }

    private func markerColor(_ marker: WorkoutDayMarker) -> Color {
        switch marker {
        case .none: return Color.clear
        case .steps: return Color.orange
        case .workout: return Theme.exerciseColor
        }
    }

    private func dayChip(_ date: Date) -> some View {
        let calendar = Calendar.current
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isDayToday = calendar.isDateInToday(date)
        let dayMarker = marker(date)
        let weekday = date.formatted(.dateTime.weekday(.abbreviated).locale(locale))
        let fullDate = date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(locale))

        return Button(action: {
            HapticManager.shared.selection()
            onSelect(date)
        }) {
            VStack(spacing: 6) {
                Text(weekday)
                    .font(FormaFont.overline)
                    .foregroundColor(isSelected ? Theme.textPrimary : Theme.textSecondary)
                    .lineLimit(1)

                ZStack {
                    Circle()
                        .fill(isSelected ? Theme.cyberLime : (isDayToday ? Theme.textPrimary.opacity(0.08) : Color.clear))
                        .frame(width: 34, height: 34)
                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundColor(isSelected ? Color.black : Theme.textPrimary)
                }

                Circle()
                    .fill(markerColor(dayMarker))
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .formaAnimation(FormaMotion.quick, value: isSelected)
        .accessibilityLabel(fullDate)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: Тренировки выбранного дня

struct WorkoutDayListCard: View {
    let workouts: [WorkoutRecord]
    let metrics: WorkoutDayMetrics
    let language: String

    private func tr(_ key: String) -> String {
        LocalizationManager.tr(key, lang: language)
    }

    /// Раньше тип показывался как есть («OutdoorRun»), а значок угадывался только для «Бег» и «Ходьба».
    private func resolve(_ record: WorkoutRecord) -> (title: String, icon: String) {
        if let type = WorkoutsView.WorkoutType.allCases.first(where: { $0.typeId == record.type || $0.rawValue == record.type }) {
            return (type.localizedTitle(lang: language), type.icon)
        }
        return (record.type, "dumbbell.fill")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.m) {
            if workouts.isEmpty {
                emptyState
            } else {
                ForEach(workouts) { workout in
                    row(workout)
                }
                Divider().opacity(0.4)
                HStack {
                    Text(tr("workouts_time_label"))
                        .font(FormaFont.caption)
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Text("\(metrics.workoutMinutes) \(tr("wk_minutes_unit"))")
                        .font(FormaFont.unit)
                        .foregroundColor(Theme.textPrimary)
                    if metrics.distanceKm > 0 {
                        Text(String(format: "· %.2f %@", metrics.distanceKm, tr("finish_km")))
                            .font(FormaFont.unit)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
        }
        .padding(FormaSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .formaSurface()
    }

    private var emptyState: some View {
        HStack(spacing: FormaSpacing.m) {
            Image(systemName: metrics.steps > 0 ? "figure.walk" : "figure.run")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(metrics.steps > 0 ? Color.orange : Theme.textSecondary)
                .frame(width: 40, height: 40)
                .background((metrics.steps > 0 ? Color.orange : Theme.textSecondary).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: FormaRadius.chip, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(metrics.steps > 0 ? tr("workouts_no_workouts_activity") : tr("workouts_no_workouts_empty"))
                    .font(.system(.subheadline).weight(.semibold))
                    .foregroundColor(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(metrics.steps > 0 ? tr("workouts_steps_calories_source") : tr("workouts_sensors_empty"))
                    .font(FormaFont.caption)
                    .foregroundColor(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private func row(_ workout: WorkoutRecord) -> some View {
        let resolved = resolve(workout)
        return HStack(spacing: FormaSpacing.m) {
            Image(systemName: resolved.icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Theme.exerciseColor)
                .frame(width: 40, height: 40)
                .background(Theme.exerciseColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: FormaRadius.chip, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(resolved.title)
                    .font(.system(.subheadline).weight(.semibold))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(AppDateHelper.time(from: workout.date))
                    .font(FormaFont.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(workout.durationMinutes) \(tr("wk_minutes_unit"))")
                    .font(FormaFont.unit)
                    .foregroundColor(Theme.textPrimary)
                Text(String(format: "%.0f %@", workout.caloriesBurned, tr("kcal")))
                    .font(FormaFont.caption)
                    .foregroundColor(Theme.flameOrange)
            }
        }
    }
}

// MARK: Сегментный переключатель

struct FormaSegmentOption<Value: Hashable>: Identifiable {
    let value: Value
    let title: String
    var id: Value { value }
}

/// Переключатель на двух-трёх вкладок: лаймовая плашка «переезжает» под выбранный пункт.
struct FormaSegmentedControl<Value: Hashable>: View {
    let options: [FormaSegmentOption<Value>]
    @Binding var selection: Value
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options) { option in
                let isSelected = option.value == selection
                Button(action: {
                    guard !isSelected else { return }
                    HapticManager.shared.selection()
                    withAnimation(FormaMotion.quick) {
                        selection = option.value
                    }
                }) {
                    Text(option.title)
                        .font(.system(.subheadline).weight(.semibold))
                        .foregroundColor(isSelected ? Color.black : Theme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: FormaRadius.chip + 2, style: .continuous)
                                    .fill(Theme.cyberLime)
                                    .matchedGeometryEffect(id: "segment", in: namespace)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
    }
}

// MARK: Выбранное занятие и кнопка «Старт»

/// Выбранное занятие наверху экрана: раньше кнопка «Начать» лежала в самом низу, после 35 карточек и плеера.
struct WorkoutQuickStartCard: View {
    let icon: String
    let title: String
    let intensityTitle: String
    let intensityColor: Color
    let isGPS: Bool
    let kcalPer30Min: Int
    let language: String
    let onStart: () -> Void

    private func tr(_ key: String) -> String {
        LocalizationManager.tr(key, lang: language)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.m) {
            HStack(spacing: FormaSpacing.m) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                    .frame(width: 56, height: 56)
                    .background(Theme.cyberLime.opacity(0.22))
                    .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(tr("wk_selected").uppercased())
                        .formaOverline()
                    Text(title)
                        .font(FormaFont.title)
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: FormaSpacing.s) {
                Text(intensityTitle)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(intensityColor)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(intensityColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                if isGPS {
                    HStack(spacing: 3) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 9))
                        Text("GPS")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(Theme.standColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Theme.standColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }

                Text("~\(kcalPer30Min) \(tr("kcal")) / 30 \(tr("wk_minutes_unit"))")
                    .font(FormaFont.caption)
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }

            Button(action: {
                HapticManager.shared.impact(.medium)
                onStart()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text(tr("workout_card_start"))
                }
                .font(FormaFont.headline)
                .foregroundColor(Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Theme.cyberLime)
                .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
            }
            .buttonStyle(SpringPressButtonStyle(scaleAmount: 0.97, hapticStyle: nil))
        }
        .padding(FormaSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .formaSurface()
    }
}
