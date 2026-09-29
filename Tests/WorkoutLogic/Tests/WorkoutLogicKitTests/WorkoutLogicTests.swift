import XCTest
@testable import WorkoutLogicKit

final class WorkoutClockTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    func testCountsRealTimeAcrossSuspension() {
        // Регрессия: телефон заблокировали на 5 минут, тики таймера не шли.
        // Старый счётчик тиков показал бы 2 секунды, часы показывают 301.
        var clock = WorkoutClock()
        clock.start(at: t0)
        clock.credit(at: t0.addingTimeInterval(1))
        clock.credit(at: t0.addingTimeInterval(2))
        clock.credit(at: t0.addingTimeInterval(301))
        XCTAssertEqual(clock.elapsedSeconds, 301)
    }

    func testPauseStopsCountingAndResumeContinues() {
        var clock = WorkoutClock()
        clock.start(at: t0)
        clock.pause(at: t0.addingTimeInterval(60))
        clock.credit(at: t0.addingTimeInterval(100))          // на паузе — не считается
        XCTAssertEqual(clock.elapsedSeconds, 60)
        clock.resume(at: t0.addingTimeInterval(120))
        clock.credit(at: t0.addingTimeInterval(150))
        XCTAssertEqual(clock.elapsedSeconds, 90)              // 60 до паузы + 30 после
    }

    func testPauseCreditsTimeUpToTheMoment() {
        var clock = WorkoutClock()
        clock.start(at: t0)
        clock.credit(at: t0.addingTimeInterval(10))
        clock.pause(at: t0.addingTimeInterval(17))            // 7 с между тиками не теряются
        XCTAssertEqual(clock.elapsedSeconds, 17)
    }

    func testStationaryTimeIsSeparatedFromActive() {
        var clock = WorkoutClock()
        clock.start(at: t0)
        clock.credit(at: t0.addingTimeInterval(10), isStationary: false)
        clock.credit(at: t0.addingTimeInterval(20), isStationary: true)
        XCTAssertEqual(clock.elapsedSeconds, 20)
        XCTAssertEqual(clock.activeSeconds, 10)
    }

    func testForgottenWorkoutIsCapped() {
        var clock = WorkoutClock()
        clock.start(at: t0)
        clock.credit(at: t0.addingTimeInterval(20 * 3600))
        XCTAssertEqual(clock.elapsed, WorkoutClock.maxCreditedDuration)
    }

    func testResumeWhileRunningDoesNotLoseTime() {
        var clock = WorkoutClock()
        clock.start(at: t0)
        clock.resume(at: t0.addingTimeInterval(30))           // уже идёт — отметку не сбрасываем
        clock.credit(at: t0.addingTimeInterval(40))
        XCTAssertEqual(clock.elapsedSeconds, 40)
    }

    func testNothingCountsBeforeStartAndClockNeverGoesBackwards() {
        var clock = WorkoutClock()
        clock.credit(at: t0.addingTimeInterval(50))
        XCTAssertEqual(clock.elapsedSeconds, 0)
        clock.start(at: t0)
        clock.credit(at: t0.addingTimeInterval(10))
        clock.credit(at: t0.addingTimeInterval(5))            // часы перевели назад
        XCTAssertEqual(clock.elapsedSeconds, 10)
    }

    func testStartResetsPreviousWorkout() {
        var clock = WorkoutClock()
        clock.start(at: t0)
        clock.credit(at: t0.addingTimeInterval(100))
        clock.start(at: t0.addingTimeInterval(500))
        XCTAssertEqual(clock.elapsedSeconds, 0)
    }
}

final class CustomWorkoutProgressTests: XCTestCase {
    private let plan = [
        WorkoutSetPlan(sets: 3, restSeconds: 20),
        WorkoutSetPlan(sets: 2, restSeconds: 30)
    ]

    func testFirstSetOfNextExerciseIsNotSkipped() {
        // Регрессия: после последнего подхода первого упражнения второе начиналось с подхода 2.
        var p = CustomWorkoutProgress()
        XCTAssertEqual(p.completeSet(plan: plan), .rest(seconds: 20))
        p.endRest()
        XCTAssertEqual([p.exerciseIndex, p.setIndex], [0, 2])

        XCTAssertEqual(p.completeSet(plan: plan), .rest(seconds: 20))
        p.endRest()
        XCTAssertEqual([p.exerciseIndex, p.setIndex], [0, 3])

        XCTAssertEqual(p.completeSet(plan: plan), .rest(seconds: 30))   // переход ко второму упражнению
        p.endRest()
        XCTAssertEqual([p.exerciseIndex, p.setIndex], [1, 1])           // раньше было [1, 2]

        XCTAssertEqual(p.completeSet(plan: plan), .rest(seconds: 30))
        p.endRest()
        XCTAssertEqual([p.exerciseIndex, p.setIndex], [1, 2])

        XCTAssertEqual(p.completeSet(plan: plan), .finished)
    }

    func testEveryPlannedSetIsVisitedExactlyOnce() {
        let bigPlan = [
            WorkoutSetPlan(sets: 4, restSeconds: 10),
            WorkoutSetPlan(sets: 1, restSeconds: 10),
            WorkoutSetPlan(sets: 3, restSeconds: 10)
        ]
        var p = CustomWorkoutProgress()
        var visited: [[Int]] = [[p.exerciseIndex, p.setIndex]]
        while true {
            let step = p.completeSet(plan: bigPlan)
            if step == .finished { break }
            p.endRest()
            visited.append([p.exerciseIndex, p.setIndex])
        }
        XCTAssertEqual(visited, [[0, 1], [0, 2], [0, 3], [0, 4], [1, 1], [2, 1], [2, 2], [2, 3]])
    }

    func testEndRestIsSafeToCallTwice() {
        // Таймер и кнопка «Пропустить» могут сработать почти одновременно.
        var p = CustomWorkoutProgress()
        _ = p.completeSet(plan: plan)
        p.endRest()
        p.endRest()
        XCTAssertEqual(p.setIndex, 2)
        XCTAssertFalse(p.isResting)
    }

    func testSetCompletedDuringRestIsIgnored() {
        // Например, лишнее нажатие «подход выполнен» на часах во время отдыха.
        var p = CustomWorkoutProgress()
        _ = p.completeSet(plan: plan)
        XCTAssertEqual(p.completeSet(plan: plan), .ignored)
        XCTAssertEqual([p.exerciseIndex, p.setIndex], [0, 1])
        XCTAssertTrue(p.isResting)
    }

    func testSingleSetSingleExerciseFinishesImmediately() {
        var p = CustomWorkoutProgress()
        XCTAssertEqual(p.completeSet(plan: [WorkoutSetPlan(sets: 1, restSeconds: 30)]), .finished)
    }

    func testEmptyPlanFinishes() {
        var p = CustomWorkoutProgress()
        XCTAssertEqual(p.completeSet(plan: []), .finished)
    }

    func testResetStartsOver() {
        var p = CustomWorkoutProgress()
        _ = p.completeSet(plan: plan)
        p.reset()
        XCTAssertEqual([p.exerciseIndex, p.setIndex], [0, 1])
        XCTAssertFalse(p.isResting)
    }
}

final class WorkoutRecordingPolicyTests: XCTestCase {
    func testTooShortWorkoutIsNotRecorded() {
        XCTAssertFalse(WorkoutRecordingPolicy.isRecordable(durationSeconds: 0))
        XCTAssertFalse(WorkoutRecordingPolicy.isRecordable(durationSeconds: 59))
    }

    func testMinuteOrLongerIsRecorded() {
        XCTAssertTrue(WorkoutRecordingPolicy.isRecordable(durationSeconds: 60))
        XCTAssertTrue(WorkoutRecordingPolicy.isRecordable(durationSeconds: 1800))
    }
}
