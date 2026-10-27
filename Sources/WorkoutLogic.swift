import Foundation

// MARK: - Чистая логика тренировки
//
// Здесь нет ни SwiftUI, ни HealthKit: файл проверяется юнит-тестами (Tests/WorkoutLogic)
// без Xcode и устройства. Раньше та же логика жила внутри WorkoutsView и WorkoutTracker
// и содержала ошибки, которые невозможно было поймать без телефона.

// MARK: Часы тренировки

/// Время тренировки по настоящим часам.
///
/// Раньше трекер прибавлял по секунде на каждый тик таймера. Пока телефон заблокирован, iOS
/// усыпляет приложение и тики прекращаются, поэтому бег с телефоном в кармане «замирал».
/// Теперь каждый тик засчитывает реальное время, прошедшее с прошлой отметки, а значит, после
/// пробуждения приложения пропущенный отрезок добавляется целиком.
public struct WorkoutClock: Equatable {
    /// Предохранитель от забытой тренировки: дольше этого времени не засчитываем.
    public static let maxCreditedDuration: TimeInterval = 8 * 3600

    public private(set) var elapsed: TimeInterval = 0
    /// Время «в движении» — без отрезков, когда телефон был неподвижен.
    public private(set) var active: TimeInterval = 0
    public private(set) var isRunning = false

    private var lastMark: Date?

    public init() {}

    public var elapsedSeconds: Int { Int(elapsed) }
    public var activeSeconds: Int { Int(active) }

    public mutating func start(at now: Date) {
        self = WorkoutClock()
        isRunning = true
        lastMark = now
    }

    /// Засчитывает время с прошлой отметки. `isStationary` — был ли телефон неподвижен в этот отрезок.
    public mutating func credit(at now: Date, isStationary: Bool = false) {
        guard isRunning, let last = lastMark else { return }
        let delta = max(0, now.timeIntervalSince(last))
        lastMark = now
        let credited = min(delta, max(0, Self.maxCreditedDuration - elapsed))
        elapsed += credited
        if !isStationary { active += credited }
    }

    /// Пауза: сначала засчитываем время до этой секунды, затем перестаём считать.
    public mutating func pause(at now: Date, isStationary: Bool = false) {
        credit(at: now, isStationary: isStationary)
        isRunning = false
        lastMark = nil
    }

    public mutating func resume(at now: Date) {
        guard !isRunning else { return }
        isRunning = true
        lastMark = now
    }
}

// MARK: Прогресс личной тренировки

/// Что нужно знать о упражнении, чтобы вести подходы.
public struct WorkoutSetPlan: Equatable {
    public var sets: Int
    public var restSeconds: Int

    public init(sets: Int, restSeconds: Int) {
        self.sets = sets
        self.restSeconds = restSeconds
    }
}

/// Машина состояний личной тренировки: упражнение, подход, отдых.
///
/// Была ошибка: при переходе к следующему упражнению подход ставился в 1, а по окончании
/// отдыха к нему прибавлялась ещё единица, поэтому первый подход каждого следующего
/// упражнения пропускался. Теперь «прибавить подход после отдыха» помнится явно
/// и относится только к отдыху между подходами одного упражнения.
public struct CustomWorkoutProgress: Equatable {
    public enum Step: Equatable {
        /// Начался отдых на столько секунд.
        case rest(seconds: Int)
        /// Тренировка закончена.
        case finished
        /// Команда проигнорирована (например, «подход выполнен» нажали во время отдыха).
        case ignored
    }

    public private(set) var exerciseIndex = 0
    public private(set) var setIndex = 1
    public private(set) var isResting = false

    private var advancesSetAfterRest = false

    public init() {}

    public mutating func reset() {
        self = CustomWorkoutProgress()
    }

    public mutating func completeSet(plan: [WorkoutSetPlan]) -> Step {
        guard !isResting else { return .ignored }
        guard plan.indices.contains(exerciseIndex) else { return .finished }

        let current = plan[exerciseIndex]
        if setIndex < current.sets {
            isResting = true
            advancesSetAfterRest = true
            return .rest(seconds: current.restSeconds)
        }

        if exerciseIndex < plan.count - 1 {
            exerciseIndex += 1
            setIndex = 1
            isResting = true
            advancesSetAfterRest = false
            // Как и раньше, пауза перед новым упражнением берётся из настроек этого упражнения
            return .rest(seconds: plan[exerciseIndex].restSeconds)
        }

        return .finished
    }

    /// Отдых закончился (по таймеру или его пропустили). Повторный вызов безопасен.
    public mutating func endRest() {
        guard isResting else { return }
        if advancesSetAfterRest { setIndex += 1 }
        advancesSetAfterRest = false
        isResting = false
    }
}

// MARK: Что считать тренировкой

public enum WorkoutRecordingPolicy {
    /// Тренировка короче этого не пишется в «Здоровье» и историю и не даёт XP.
    /// Раньше старт и мгновенное «Завершить» сохраняли минутную тренировку и начисляли награду.
    public static let minimumRecordableSeconds = 60

    public static func isRecordable(durationSeconds: Int) -> Bool {
        durationSeconds >= minimumRecordableSeconds
    }
}

// MARK: Дубликаты тренировок

/// Всё, что нужно, чтобы понять, что две записи — одно и то же занятие.
public struct WorkoutIdentity: Equatable {
    public var id: UUID
    public var type: String
    public var start: Date
    public var durationMinutes: Int

    public init(id: UUID, type: String, start: Date, durationMinutes: Int) {
        self.id = id
        self.type = type
        self.start = start
        self.durationMinutes = durationMinutes
    }
}

/// Когда две записи считаются одной тренировкой. Правило вынесено из HealthKitManager без изменений,
/// чтобы его можно было проверить тестами и использовать и для очистки истории, и для отсева повторов.
public enum WorkoutDuplicateRule {
    /// Запись с часов и такая же запись из Здоровья начинаются почти одновременно: разрешаем разницу
    /// старта до 90 секунд и длительности до двух минут.
    public static let maxStartDifference: TimeInterval = 90
    public static let maxDurationDifferenceMinutes = 2

    public static func isSame(_ a: WorkoutIdentity, _ b: WorkoutIdentity) -> Bool {
        // 1. Прямое совпадение по UUID
        if a.id == b.id { return true }

        // 2. Совпадение по времени старта, длительности и типу
        let startDiff = abs(a.start.timeIntervalSince(b.start))
        let durationDiff = abs(a.durationMinutes - b.durationMinutes)
        return startDiff < maxStartDifference
            && durationDiff <= maxDurationDifferenceMinutes
            && areCompatibleTypes(a.type, b.type)
    }

    /// Типы совпадают или это один вид занятия, названный по-разному на часах и в приложении.
    /// Регистр не учитывается: «Спортивная ходьба» и «Ходьба» — одно и то же (раньше сравнивалось с учётом регистра).
    public static func areCompatibleTypes(_ a: String, _ b: String) -> Bool {
        let x = a.lowercased()
        let y = b.lowercased()
        if x == y { return true }
        return (x.contains("силов") && y.contains("силов"))
            || (x.contains("бег") && y.contains("бег"))
            || (x.contains("ходьб") && y.contains("ходьб"))
    }

    /// Есть ли среди `existing` то же занятие, что и `candidate`.
    public static func isDuplicate(_ candidate: WorkoutIdentity, of existing: [WorkoutIdentity]) -> Bool {
        existing.contains { isSame($0, candidate) }
    }
}

// MARK: Награда за тренировку

/// Опыт за тренировку начисляется ровно один раз, в одном месте (`HealthKitManager.saveWorkout`).
/// Раньше он начислялся дважды: 100 внутри сохранения и ещё 150 на экране тренировок — 250 за занятие,
/// а импорт из файла давал по 100 за каждую историческую запись.
public enum WorkoutRewardPolicy {
    public static let completionXP = 150

    /// `awardsXP` — вызывающий код считает это завершённым занятием (экран тренировок, часы);
    /// `isNewRecord` — такой записи ещё не было (повторное сообщение с часов не должно платить снова).
    public static func xp(awardsXP: Bool, isNewRecord: Bool) -> Int {
        (awardsXP && isNewRecord) ? completionXP : 0
    }
}
