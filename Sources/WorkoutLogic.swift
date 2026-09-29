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
