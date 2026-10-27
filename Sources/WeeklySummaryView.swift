import SwiftUI

// MARK: - Итоги недели: данные, уведомление, экран

extension Notification.Name {
    /// Человек нажал на воскресное уведомление: открыть экран итогов
    static let formaOpenWeeklySummary = Notification.Name("FormaOpenWeeklySummary")
}

/// Идентификаторы воскресного уведомления. Вне классов с изоляцией: делегат уведомлений читает их из фонового потока.
enum WeeklySummaryNotification {
    static let identifier = "forma_weekly_summary"
    /// Холодный запуск по уведомлению: экран ещё не создан, поэтому намерение запоминается и забирается при появлении
    static let pendingKey = "forma_pending_weekly_summary"
    static let enabledKey = "weekly_summary_enabled"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) == nil ? true : UserDefaults.standard.bool(forKey: enabledKey)
    }

    /// Забирает запомненное намерение «открыть итоги» (true один раз)
    static func consumePending() -> Bool {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: pendingKey) else { return false }
        defaults.set(false, forKey: pendingKey)
        return true
    }
}

/// Собирает входные данные расчёта из менеджеров приложения
@MainActor
enum WeeklySummaryProvider {

    static func current(now: Date = Date(), calendar: Calendar = .current) -> WeeklySummary {
        let health = HealthKitManager.shared

        var days = health.dailyActivityHistory.values.map {
            WeeklyDay(date: $0.date, steps: $0.steps, activeCalories: $0.activeCalories)
        }
        // История Apple Health обновляется с задержкой: сегодняшние шаги берём из живых счётчиков
        days.append(WeeklyDay(date: now, steps: max(health.stepsToday, BackgroundStepManager.shared.stepsToday), activeCalories: 0))

        let workouts = health.workoutHistory.map {
            WeeklyWorkout(date: $0.date, durationMinutes: $0.durationMinutes, calories: $0.caloriesBurned)
        }

        let savedGoal = UserDefaults.standard.integer(forKey: "step_goal")
        let (completions, slots) = habitCheckmarks(now: now, calendar: calendar)

        return WeeklySummaryBuilder.make(
            now: now,
            calendar: calendar,
            days: days,
            workouts: workouts,
            stepGoal: savedGoal > 0 ? savedGoal : 10_000,
            habitCompletions: completions,
            habitSlots: slots
        )
    }

    /// Отметки полезных привычек за семь дней. Привычка, заведённая посреди недели, считается только с момента создания,
    /// иначе она занижала бы процент за дни, когда её ещё не было.
    private static func habitCheckmarks(now: Date, calendar: Calendar) -> (completions: Int, slots: Int) {
        let today = calendar.startOfDay(for: now)
        let windowKeys: [(key: String, day: Date)] = (0..<WeeklySummaryBuilder.windowDays).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return (AppDateHelper.dayKey(for: day), day)
        }

        var completions = 0
        var slots = 0
        for habit in HabitsManager.shared.habits where habit.type == .build {
            let created = calendar.startOfDay(for: habit.createdAt)
            let doneKeys = Set(habit.completedDates)
            for (key, day) in windowKeys where day >= created {
                slots += 1
                if doneKeys.contains(key) { completions += 1 }
            }
        }
        return (completions, slots)
    }
}

// MARK: - Экран

struct WeeklySummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("app_language") private var appLanguage = "ru"

    private let summary: WeeklySummary
    private let now: Date
    @State private var shareItem: ShareImageItem?

    init(now: Date = Date()) {
        self.now = now
        self.summary = WeeklySummaryProvider.current(now: now)
    }

    private func tr(_ key: String) -> String {
        LocalizationManager.tr(key, lang: appLanguage)
    }

    private var periodText: String {
        let calendar = Calendar.current
        guard let start = calendar.date(byAdding: .day, value: -(WeeklySummaryBuilder.windowDays - 1), to: now) else { return "" }
        let style = Date.FormatStyle().day().month(.abbreviated).locale(Locale(identifier: appLanguage))
        return "\(start.formatted(style)) – \(now.formatted(style))"
    }

    var body: some View {
        ZStack {
            FormaBackdrop()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        if summary.hasData {
                            heroCard
                            statGrid
                            if let habits = summary.habitsPercent {
                                habitsCard(percent: habits)
                            }
                            if let bestDay = bestDayText {
                                Text(bestDay)
                                    .font(.footnote)
                                    .foregroundColor(Theme.textSecondary)
                                    .padding(.horizontal, 4)
                            }
                        } else {
                            emptyState
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 16)
                }

                FormaPrimaryButton(title: tr("weekly_summary_close")) {
                    dismiss()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .sheet(item: $shareItem) { item in
            FormaImageShareSheet(image: item.image)
        }
    }

    // MARK: Части экрана

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(tr("weekly_summary_title"))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                Text(periodText)
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
            if summary.hasData {
                Button(action: share) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Theme.flameOrange)
                        .frame(width: 40, height: 40)
                        .background(Theme.flameOrange.opacity(0.12))
                        .clipShape(Circle())
                }
                .accessibilityLabel(tr("share_button"))
            }
        }
    }

    private func share() {
        HapticManager.shared.impact(.light)
        let model = ShareCardModel.weekly(summary, period: periodText, lang: appLanguage)
        if let image = ShareCardRenderer.image(for: model, lang: appLanguage) {
            shareItem = ShareImageItem(image: image)
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                FormaCardIcon(systemName: "figure.walk", tint: Theme.exerciseColor)
                Text(tr("weekly_summary_steps_caption"))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
            }
            Text(WeeklySummaryFormat.grouped(summary.totalSteps))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textPrimary)
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if let trend = trendText {
                Label(trend.text, systemImage: trend.isUp ? "arrow.up.right" : "arrow.down.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(trend.isUp ? .green : .orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .premiumCard()
    }

    private var statGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return LazyVGrid(columns: columns, spacing: 12) {
            statCard(icon: "chart.bar.fill", tint: Theme.exerciseColor,
                     title: tr("weekly_summary_average"),
                     value: WeeklySummaryFormat.grouped(summary.averageSteps))
            statCard(icon: "target", tint: Theme.flameOrange,
                     title: tr("weekly_summary_goal_days"),
                     value: String(format: tr("weekly_summary_goal_days_value"), summary.goalDays))
            statCard(icon: "figure.strengthtraining.traditional", tint: Theme.aiViolet,
                     title: tr("weekly_summary_workouts"),
                     value: String(format: tr("weekly_summary_workouts_value"), summary.workoutCount, summary.workoutMinutes))
            statCard(icon: "flame.fill", tint: Theme.pulseColor,
                     title: tr("weekly_summary_calories"),
                     value: WeeklySummaryFormat.grouped(summary.activeCalories))
        }
    }

    private func statCard(icon: String, tint: Color, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            FormaCardIcon(systemName: icon, tint: tint)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textPrimary)
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(title)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .premiumCard()
    }

    private func habitsCard(percent: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                FormaCardIcon(systemName: "checkmark.seal.fill", tint: Theme.flameOrange)
                Text(tr("weekly_summary_habits"))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Text("\(percent)%")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                    .monospacedDigit()
            }
            ProgressView(value: Double(percent), total: 100)
                .tint(Theme.flameOrange)
        }
        .premiumCard()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 40))
                .foregroundColor(Theme.textSecondary)
            Text(tr("weekly_summary_empty"))
                .font(.system(size: 15))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .premiumCard()
    }

    // MARK: Тексты

    private var trendText: (text: String, isUp: Bool)? {
        guard let change = summary.stepsChangePercent, change != 0 else { return nil }
        let key = change > 0 ? "weekly_summary_trend_up" : "weekly_summary_trend_down"
        return (String(format: tr(key), abs(change)), change > 0)
    }

    private var bestDayText: String? {
        guard let date = summary.bestDayDate, summary.bestDaySteps > 0 else { return nil }
        let style = Date.FormatStyle().weekday(.wide).day().month(.abbreviated).locale(Locale(identifier: appLanguage))
        return String(format: tr("weekly_summary_best_day"), date.formatted(style), WeeklySummaryFormat.grouped(summary.bestDaySteps))
    }
}
