#if DEBUG
import SwiftUI
import UIKit

/// Режим съёмки скриншотов для CI (scripts/ios_tab_screenshots.sh, scripts/ios_achievement_preview.sh).
/// Включается аргументами запуска и существует только в DEBUG-сборке:
///   -FormaScreenshotScene tab:<0-4>      открыть приложение сразу на вкладке
///   -FormaScreenshotScene achievement:…  показать только экран награды (см. FormaApp)
///   -FormaScreenshotPage <n>             прокрутить экран на n «страниц» вниз
/// В этом режиме не показываются системные запросы (ATT), которые перекрыли бы интерфейс.
enum FormaScreenshotMode {
    static var scene: String? {
        UserDefaults.standard.string(forKey: "FormaScreenshotScene")
    }

    static var isActive: Bool {
        scene != nil
    }

    /// Вкладка из `tab:<n>`; для сцен `celebration:*` открываются «Тренировки» — награда должна
    /// появиться не на Главной, а поверх другой вкладки.
    static var initialTab: Int? {
        guard let scene else { return nil }
        if scene.hasPrefix("celebration:") { return 1 }
        // Листы открываются поверх Главной
        if scene.hasPrefix("sheet:") { return 0 }
        guard scene.hasPrefix("tab:") else { return nil }
        return Int(scene.dropFirst(4))
    }

    /// Лист из сцены `sheet:<steps|water|nutrition|pulse|sleep|hub|deficit|paywall|profile|weekly>`: открывается поверх Главной
    static var sheet: String? {
        guard let scene, scene.hasPrefix("sheet:") else { return nil }
        return String(scene.dropFirst("sheet:".count))
    }

    /// Страница онбординга из сцены `onboarding:<0-3>` (для скриншотов на CI)
    static var onboardingPage: Int? {
        guard let scene, scene.hasPrefix("onboarding:") else { return nil }
        return Int(scene.dropFirst("onboarding:".count))
    }

    /// `celebration:live` — награды появляются поверх вкладки; `celebration:sheet` — поверх открытого листа
    static var celebrationMode: String? {
        guard let scene, scene.hasPrefix("celebration:") else { return nil }
        return String(scene.dropFirst("celebration:".count))
    }

    /// Через 2,5 с кладёт в очередь две награды (как при реальной разблокировке), на 8-й секунде
    /// закрывает первую — видно, что вторая показывается следом, а на 13-й закрывает и вторую.
    @MainActor
    static func runCelebrationDemoIfNeeded() {
        guard celebrationMode != nil else { return }
        func sample(_ id: String, _ title: String, _ icon: String, _ category: FormaAchievement.AchievementCategory, _ xp: Int) -> FormaAchievement {
            FormaAchievement(
                id: id, title: title, description: "Демонстрационная награда для проверки анимации",
                icon: icon, category: category, xpReward: xp, targetValue: 1, currentValue: 1,
                isUnlocked: true, unlockedDate: Date()
            )
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            let manager = GamificationManager.shared
            manager.enqueueCelebration(sample("demo_a", "Золотая десятка", "medal.fill", .steps, 200))
            manager.enqueueCelebration(sample("demo_b", "Огонёк (3 дня)", "flame.fill", .streaks, 150))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
            GamificationManager.shared.dismissCurrentCelebration()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 13.0) {
            GamificationManager.shared.dismissCurrentCelebration()
        }
    }

    static var page: Int {
        UserDefaults.standard.integer(forKey: "FormaScreenshotPage")
    }

    /// `-FormaDemoData 1`: заполняет приложение правдоподобными данными, чтобы на скриншотах CI были видны
    /// заполненные кольца, графики и привычки, а не пустой экран новичка. Только DEBUG, на устройствах не попадает.
    @MainActor
    static func applyDemoDataIfNeeded() {
        guard UserDefaults.standard.bool(forKey: "FormaDemoData") else { return }
        // Приложение при активации перечитывает часть значений из хранилища — применяем данные дважды
        for delay in [1.5, 4.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { seedDemoData() }
        }
        // Награды за демо-данные («Первые 5 000» и др.) закрывают экран на снимках — гасим очередь
        for step in 0..<12 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2 + Double(step) * 0.35) {
                GamificationManager.shared.dismissCurrentCelebration()
            }
        }
    }

    @MainActor
    private static func seedDemoData() {
        do {
            let calendar = Calendar.current
            let now = Date()
            func daysAgo(_ n: Int) -> Date { calendar.date(byAdding: .day, value: -n, to: now) ?? now }

            let health = HealthKitManager.shared
            health.stepsToday = 7_420
            health.stepDistanceKm = 5.6
            health.todayFloors = 9
            health.activeEnergyBurned = 412
            health.appleExerciseTimeMinutes = 24
            health.caloriesConsumedToday = 1_640
            health.proteinConsumedToday = 96
            health.fatConsumedToday = 52
            health.carbsConsumedToday = 188
            health.waterConsumedToday = 1_650
            health.todaySleepHours = 7.3
            health.latestHeartRate = 72
            health.restingHeartRate = 58
            health.recoveryScore = 82
            health.currentWeight = 74.5
            BackgroundStepManager.shared.stepsToday = 7_420

            health.workoutHistory = [
                WorkoutRecord(type: "Бег на улице", date: daysAgo(0), durationMinutes: 32, caloriesBurned: 310),
                WorkoutRecord(type: "Силовая тренировка", date: daysAgo(1), durationMinutes: 48, caloriesBurned: 280),
                WorkoutRecord(type: "Йога", date: daysAgo(3), durationMinutes: 40, caloriesBurned: 150),
                WorkoutRecord(type: "Велоспорт", date: daysAgo(5), durationMinutes: 55, caloriesBurned: 420)
            ]

            var activity: [String: DailyActivitySummary] = [:]
            let steps = [7_420, 11_250, 8_900, 12_400, 6_100, 9_800, 14_200, 5_300, 10_100, 8_200, 9_400, 11_800, 7_000, 9_900]
            for (offset, value) in steps.enumerated() {
                let date = daysAgo(offset)
                let key = AppDateHelper.dayKey(for: date)
                activity[key] = DailyActivitySummary(dateKey: key, date: date, steps: value, distanceMeters: Double(value) * 0.75, activeCalories: Double(value) * 0.045)
            }
            health.dailyActivityHistory = activity

            health.weightHistory = (0..<8).map { index in
                WeightRecord(date: daysAgo((7 - index) * 4), weight: 78.4 - Double(index) * 0.55)
            }

            let water = HabitItem(title: "Пить воду", icon: "drop.fill", colorHex: "#38BDF8",
                                 completedDates: (0..<9).map { AppDateHelper.dayKey(for: daysAgo($0)) }, goalTargetDays: 30)
            let stretch = HabitItem(title: "Растяжка 15 минут", icon: "figure.flexibility", colorHex: "#A78BFA",
                                    completedDates: [1, 2, 3, 5, 6].map { AppDateHelper.dayKey(for: daysAgo($0)) })
            let read = HabitItem(title: "Чтение 20 минут", icon: "book.fill", colorHex: "#F59E0B",
                                 completedDates: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11].map { AppDateHelper.dayKey(for: daysAgo($0)) })
            let sugar = HabitItem(title: "Без сахара", type: .quit, icon: "nosign", colorHex: "#EF4444",
                                  quitStartDate: daysAgo(12), urgeResistedCount: 7, goalTargetDays: 30)
            HabitsManager.shared.habits = [water, stretch, read, sugar]
            HabitsManager.shared.saveHabits()

            let gamification = GamificationManager.shared
            gamification.totalXP = 1_480
            gamification.currentStreak = 12
            gamification.bestStreak = 21
        }
    }

    /// Через 2 секунды после появления прокручивает самый длинный вертикальный скролл экрана
    /// на `page` экранов вниз (с перекрытием, чтобы между снимками не терялись блоки).
    @MainActor
    static func scrollToRequestedPage() {
        let page = self.page
        guard page > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let windows = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
            guard let window = windows.first(where: { $0.isKeyWindow }) ?? windows.first else { return }

            var best: UIScrollView?
            func visit(_ view: UIView) {
                if let scroll = view as? UIScrollView,
                   !scroll.isHidden,
                   scroll.window != nil,
                   scroll.bounds.width > window.bounds.width * 0.8,
                   scroll.contentSize.height > scroll.bounds.height + 40 {
                    if let current = best {
                        if scroll.contentSize.height > current.contentSize.height {
                            best = scroll
                        }
                    } else {
                        best = scroll
                    }
                }
                for subview in view.subviews {
                    visit(subview)
                }
            }
            visit(window)

            guard let scroll = best else { return }
            let step = scroll.bounds.height - 220
            let maxY = max(0, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
            let y = min(CGFloat(page) * step, maxY) - scroll.adjustedContentInset.top
            scroll.setContentOffset(CGPoint(x: 0, y: y), animated: false)
        }
    }
}
#endif
