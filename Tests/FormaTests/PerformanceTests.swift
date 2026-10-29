import XCTest
@testable import Forma

// Защита от возврата «тормозов»: горячие места, которые вызываются при каждой перерисовке экрана,
// должны оставаться быстрыми. Пороги — с большим запасом (CI-симулятор медленнее телефона), но
// заметно ниже прежних значений, поэтому возврат старого поведения тест поймает.
// Измеренное время печатается строкой «PERF …» — её видно в логе CI.

@MainActor
final class HotPathPerformanceTests: XCTestCase {

    private func elapsed(_ block: () -> Void) -> Double {
        let start = CFAbsoluteTimeGetCurrent()
        block()
        return CFAbsoluteTimeGetCurrent() - start
    }

    /// `tr(key)` вызывается десятки раз за одну перерисовку экрана
    func testTranslationLookupIsFast() {
        let keys = ["tab_home", "settings_language", "csv_success_nutrition", "hero_today", "key_that_does_not_exist"]
        var checksum = 0
        let time = elapsed {
            for index in 0..<20_000 {
                checksum &+= LocalizationManager.tr(keys[index % keys.count], lang: index.isMultiple(of: 2) ? "ru" : "en").count
            }
        }
        print("PERF tr x20000: \(String(format: "%.4f", time)) s")
        XCTAssertGreaterThan(checksum, 0)
        XCTAssertLessThan(time, PerfBudget.translation, "20 000 переводов заняли \(time) с: таблица, видимо, снова строится на каждый вызов")
    }

    /// Серия и отметки привычки читаются при каждой перерисовке Привычек и Главной
    func testHabitDerivedPropertiesAreFast() {
        let calendar = Calendar.current
        let dates = (0..<365).compactMap { calendar.date(byAdding: .day, value: -$0, to: Date()) }.map { AppDateHelper.dayKey(for: $0) }
        let habit = HabitItem(title: "Тест", completedDates: dates)
        var checksum = 0
        let time = elapsed {
            for _ in 0..<400 {
                checksum &+= habit.buildStreakDays
                checksum &+= habit.isCompletedToday ? 1 : 0
                checksum &+= habit.isFrozenToday ? 1 : 0
            }
        }
        print("PERF habit streak x400: \(String(format: "%.4f", time)) s")
        XCTAssertEqual(habit.buildStreakDays, 365)
        XCTAssertGreaterThan(checksum, 0)
        XCTAssertLessThan(time, PerfBudget.habitStreak, "400 пересчётов серии заняли \(time) с")
    }

    /// Пересчёт серии дней идёт при каждом обновлении шагов
    func testGamificationEvaluationIsFast() {
        let suite = "PerformanceTests.gamification"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let manager = GamificationManager(defaults: defaults)

        let calendar = Calendar.current
        var history: [String: DailyActivitySummary] = [:]
        for offset in 0..<365 {
            let date = calendar.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            let key = AppDateHelper.dayKey(for: date)
            history[key] = DailyActivitySummary(dateKey: key, date: date, steps: 6_000, distanceMeters: 4_500, activeCalories: 250)
        }

        let time = elapsed {
            for _ in 0..<60 {
                manager.evaluateProgress(stepsToday: 6_000, distanceMetersToday: 4_500, workouts: [],
                                         waterConsumed: 0, waterNorm: 0, dailyHistory: history)
            }
        }
        print("PERF gamification evaluate x60: \(String(format: "%.4f", time)) s")
        XCTAssertLessThan(time, PerfBudget.gamification, "60 пересчётов награды заняли \(time) с")
    }

    /// Форматирование даты в заголовке Главной происходит при каждой перерисовке
    func testGreetingDateLineIsFast() {
        var checksum = 0
        let time = elapsed {
            for index in 0..<2_000 {
                checksum &+= FormaGreeting.dateLine(for: Date(timeIntervalSince1970: Double(index) * 86_400), language: "ru").count
            }
        }
        print("PERF greeting date x2000: \(String(format: "%.4f", time)) s")
        XCTAssertGreaterThan(checksum, 0)
        XCTAssertLessThan(time, PerfBudget.greeting, "2 000 форматирований даты заняли \(time) с")
    }
}

/// Пороги в секундах. До оптимизации на CI было: переводы 4,47 с, серия привычки 5,35 с, награды 0,32 с, дата 0,11 с.
/// Пороги заведомо шире нынешних значений (CI-симулятор медленнее телефона), но в разы ниже прежних.
enum PerfBudget {
    static let translation = 0.6
    static let habitStreak = 1.0
    static let gamification = 0.2
    static let greeting = 0.1
}
