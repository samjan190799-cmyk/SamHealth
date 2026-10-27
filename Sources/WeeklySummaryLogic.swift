import Foundation

// MARK: - Итоги недели: чистый расчёт
//
// Неделя — это последние семь дней, включая сегодняшний (а не календарная неделя с понедельника):
// так итоги одинаково осмысленны в любой день, и воскресное уведомление не зависит от того, с какого дня
// человек считает начало недели. Сравнение — с предыдущими семью днями.
// Файл не знает ни про HealthKit, ни про интерфейс: входные данные приводятся к простым структурам,
// поэтому расчёт проверяется обычными тестами (Tests/WeeklySummary).

/// Шаги и активные калории за один день
struct WeeklyDay: Equatable {
    let date: Date
    let steps: Int
    let activeCalories: Double
}

/// Одна тренировка
struct WeeklyWorkout: Equatable {
    let date: Date
    let durationMinutes: Int
    let calories: Double
}

struct WeeklySummary: Equatable {
    /// Шагов за семь дней
    var totalSteps = 0
    /// В среднем в день: делится на семь, а не на число записанных дней, иначе пустые дни завышали бы среднее
    var averageSteps = 0
    /// Дней, в которые выполнена цель по шагам
    var goalDays = 0
    var bestDaySteps = 0
    var bestDayDate: Date?
    var workoutCount = 0
    var workoutMinutes = 0
    var activeCalories = 0
    /// Изменение числа шагов к предыдущим семи дням, %; nil, если сравнивать не с чем
    var stepsChangePercent: Int?
    /// Доля выполненных отметок привычек, %; nil, если привычек нет
    var habitsPercent: Int?

    /// Есть ли что показать: пустую неделю итогами не называем
    var hasData: Bool {
        totalSteps > 0 || workoutCount > 0 || (habitsPercent ?? 0) > 0
    }
}

enum WeeklySummaryBuilder {
    static let windowDays = 7
    /// Предел изменения в процентах: «+4 800 %» после пустой недели ничего не говорит
    static let maxChangePercent = 999

    /// - Parameters:
    ///   - habitCompletions: сколько отметок привычек выполнено за семь дней (привычка × день)
    ///   - habitSlots: сколько отметок можно было сделать (число привычек × 7); 0, если привычек нет
    static func make(now: Date,
                     calendar: Calendar = .current,
                     days: [WeeklyDay],
                     workouts: [WeeklyWorkout],
                     stepGoal: Int,
                     habitCompletions: Int = 0,
                     habitSlots: Int = 0) -> WeeklySummary {
        let today = calendar.startOfDay(for: now)

        /// Сколько дней назад: 0 — сегодня. Будущие даты (часы пойдут вперёд, сдвиг часового пояса) получают минус и отбрасываются.
        func daysAgo(_ date: Date) -> Int {
            calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: today).day ?? Int.max
        }

        // Один день — одна запись: если источник отдал дубль, берём наибольшее значение, а не суммируем
        var stepsByDay: [Int: Int] = [:]
        var caloriesByDay: [Int: Double] = [:]
        for day in days {
            let ago = daysAgo(day.date)
            guard ago >= 0 else { continue }
            stepsByDay[ago] = max(stepsByDay[ago] ?? 0, day.steps)
            caloriesByDay[ago] = max(caloriesByDay[ago] ?? 0, day.activeCalories)
        }

        var summary = WeeklySummary()
        let currentRange = 0..<windowDays
        let previousRange = windowDays..<(windowDays * 2)

        var previousSteps = 0
        // По возрастанию «дней назад»: при равных шагах лучшим днём остаётся более свежий, результат не зависит от порядка словаря
        for (ago, steps) in stepsByDay.sorted(by: { $0.key < $1.key }) {
            if currentRange.contains(ago) {
                summary.totalSteps += steps
                if stepGoal > 0 && steps >= stepGoal { summary.goalDays += 1 }
                if steps > summary.bestDaySteps {
                    summary.bestDaySteps = steps
                    summary.bestDayDate = calendar.date(byAdding: .day, value: -ago, to: today)
                }
            } else if previousRange.contains(ago) {
                previousSteps += steps
            }
        }
        summary.averageSteps = Int((Double(summary.totalSteps) / Double(windowDays)).rounded())
        summary.activeCalories = Int(caloriesByDay.filter { currentRange.contains($0.key) }.values.reduce(0, +).rounded())

        if previousSteps > 0 {
            let change = (Double(summary.totalSteps - previousSteps) / Double(previousSteps) * 100).rounded()
            summary.stepsChangePercent = Int(max(-Double(maxChangePercent), min(Double(maxChangePercent), change)))
        }

        for workout in workouts where currentRange.contains(daysAgo(workout.date)) {
            summary.workoutCount += 1
            summary.workoutMinutes += max(0, workout.durationMinutes)
        }

        if habitSlots > 0 {
            let share = Double(max(0, habitCompletions)) / Double(habitSlots) * 100
            summary.habitsPercent = Int(min(100, share.rounded()))
        }
        return summary
    }
}

enum WeeklySummaryFormat {
    /// Число с неразрывным пробелом между тысячами: «63 400». Не зависит от языка телефона и локали форматтера.
    static func grouped(_ value: Int) -> String {
        let digits = String(abs(value))
        var result = ""
        for (index, character) in digits.reversed().enumerated() {
            if index > 0 && index % 3 == 0 { result.append("\u{00A0}") }
            result.append(character)
        }
        return (value < 0 ? "-" : "") + String(result.reversed())
    }
}
