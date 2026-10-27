import XCTest
@testable import Forma

// MARK: - Вспомогательные фабрики

private func makeAchievement(
    _ id: String,
    category: FormaAchievement.AchievementCategory = .steps
) -> FormaAchievement {
    FormaAchievement(
        id: id,
        title: "Награда \(id)",
        description: "Описание \(id)",
        icon: "star.fill",
        category: category,
        xpReward: 10,
        targetValue: 1,
        currentValue: 1,
        isUnlocked: true
    )
}

// MARK: - Очередь праздничных экранов

final class AchievementCelebrationQueueTests: XCTestCase {

    func testEmptyQueueHasNothingToShow() {
        let queue = AchievementCelebrationQueue()
        XCTAssertTrue(queue.isEmpty)
        XCTAssertNil(queue.current)
        XCTAssertEqual(queue.remainingAfterCurrent, 0)
    }

    func testFirstEnqueuedBecomesCurrentAndOrderIsKept() {
        var queue = AchievementCelebrationQueue()
        queue.enqueue(makeAchievement("a"))
        queue.enqueue(makeAchievement("b"))
        queue.enqueue(makeAchievement("c"))

        XCTAssertEqual(queue.current?.id, "a")
        XCTAssertEqual(queue.remainingAfterCurrent, 2)
        XCTAssertEqual(queue.items.map(\.id), ["a", "b", "c"])
    }

    func testDuplicateIdIsIgnored() {
        var queue = AchievementCelebrationQueue()
        XCTAssertTrue(queue.enqueue(makeAchievement("a")))
        XCTAssertFalse(queue.enqueue(makeAchievement("a")))
        XCTAssertEqual(queue.items.count, 1)
    }

    func testDismissAdvancesToNextAndFinallyEmpties() {
        var queue = AchievementCelebrationQueue()
        queue.enqueue(makeAchievement("a"))
        queue.enqueue(makeAchievement("b"))

        queue.dismissCurrent()
        XCTAssertEqual(queue.current?.id, "b")
        XCTAssertEqual(queue.remainingAfterCurrent, 0)

        queue.dismissCurrent()
        XCTAssertNil(queue.current)
        XCTAssertTrue(queue.isEmpty)
    }

    func testDismissOnEmptyQueueIsSafe() {
        var queue = AchievementCelebrationQueue()
        queue.dismissCurrent()
        XCTAssertTrue(queue.isEmpty)
    }
}

// MARK: - Менеджер геймификации: награды попадают в очередь

@MainActor
final class GamificationCelebrationTests: XCTestCase {

    private func makeDefaults() -> UserDefaults {
        let suite = "FormaTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private func evaluate(_ manager: GamificationManager, steps: Int) {
        manager.evaluateProgress(
            stepsToday: steps,
            distanceMetersToday: 0,
            workouts: [],
            waterConsumed: 0,
            waterNorm: 0,
            dailyHistory: [:]
        )
    }

    func testBigStepDayQueuesAllUnlockedAchievementsInOrder() {
        let manager = GamificationManager(defaults: makeDefaults())
        XCTAssertNil(manager.newlyUnlockedAchievement)

        evaluate(manager, steps: 25_000)

        XCTAssertEqual(
            manager.celebrationQueue.items.map(\.id),
            ["first_5k", "step_master_10k", "step_super_20k"],
            "Все три награды за шаги должны встать в очередь, а не затереть друг друга"
        )
        XCTAssertEqual(manager.newlyUnlockedAchievement?.id, "first_5k")
    }

    func testRepeatedEvaluationDoesNotQueueSameAchievementAgain() {
        let manager = GamificationManager(defaults: makeDefaults())
        evaluate(manager, steps: 25_000)
        evaluate(manager, steps: 26_000)
        evaluate(manager, steps: 30_000)

        XCTAssertEqual(manager.celebrationQueue.items.count, 3)
    }

    func testDismissingShowsNextAchievementThenNothing() {
        let manager = GamificationManager(defaults: makeDefaults())
        evaluate(manager, steps: 12_000)
        XCTAssertEqual(manager.celebrationQueue.items.map(\.id), ["first_5k", "step_master_10k"])

        manager.dismissCurrentCelebration()
        XCTAssertEqual(manager.newlyUnlockedAchievement?.id, "step_master_10k")

        manager.dismissCurrentCelebration()
        XCTAssertNil(manager.newlyUnlockedAchievement)
    }

    func testUnlockedAchievementIsPersistedAndNotCelebratedTwice() {
        let defaults = makeDefaults()
        let first = GamificationManager(defaults: defaults)
        evaluate(first, steps: 6_000)
        XCTAssertEqual(first.celebrationQueue.items.map(\.id), ["first_5k"])

        // «Перезапуск приложения»: тот же набор UserDefaults, новый менеджер
        let second = GamificationManager(defaults: defaults)
        XCTAssertTrue(second.achievements.first(where: { $0.id == "first_5k" })?.isUnlocked ?? false)
        evaluate(second, steps: 6_000)
        XCTAssertTrue(second.celebrationQueue.isEmpty, "Уже полученная награда не должна праздноваться снова")
    }

    func testUnlockAwardsExperience() {
        let manager = GamificationManager(defaults: makeDefaults())
        evaluate(manager, steps: 6_000)
        XCTAssertGreaterThanOrEqual(manager.totalXP, 100, "За награду «Первые 5 000» положено минимум 100 XP")
    }

    func testBelowThresholdQueuesNothing() {
        let manager = GamificationManager(defaults: makeDefaults())
        evaluate(manager, steps: 1_000)
        XCTAssertTrue(manager.celebrationQueue.isEmpty)
    }
}

// MARK: - Математика анимации

final class MedalAnimationMathTests: XCTestCase {

    func testClamp01() {
        XCTAssertEqual(medalClamp01(-3), 0)
        XCTAssertEqual(medalClamp01(0.4), 0.4, accuracy: 1e-9)
        XCTAssertEqual(medalClamp01(7), 1)
    }

    func testEaseOutCubicEndpointsAndMonotonicity() {
        XCTAssertEqual(medalEaseOutCubic(0), 0, accuracy: 1e-9)
        XCTAssertEqual(medalEaseOutCubic(1), 1, accuracy: 1e-9)
        var previous = -1.0
        for step in stride(from: 0.0, through: 1.0, by: 0.05) {
            let value = medalEaseOutCubic(step)
            XCTAssertGreaterThanOrEqual(value, previous)
            previous = value
        }
    }

    func testEaseOutBackStartsAtZeroEndsAtOneAndOvershoots() {
        XCTAssertEqual(medalEaseOutBack(0), 0, accuracy: 1e-9)
        XCTAssertEqual(medalEaseOutBack(1), 1, accuracy: 1e-9)
        let peak = stride(from: 0.0, through: 1.0, by: 0.01).map(medalEaseOutBack).max() ?? 0
        XCTAssertGreaterThan(peak, 1.0, "Пружинка должна слегка «перелетать» цель")
        XCTAssertLessThan(peak, 1.2, "Но не слишком сильно")
    }
}

// MARK: - Салют и палитра

final class BurstParticleTests: XCTestCase {

    func testGenerationIsDeterministicForSameSeed() {
        let a = AchievementBurstParticle.generate(seed: 42)
        let b = AchievementBurstParticle.generate(seed: 42)
        XCTAssertEqual(a.map(\.angle), b.map(\.angle))
        XCTAssertEqual(a.map(\.speed), b.map(\.speed))
    }

    func testDifferentSeedsGiveDifferentBursts() {
        let a = AchievementBurstParticle.generate(seed: 1)
        let b = AchievementBurstParticle.generate(seed: 2)
        XCTAssertNotEqual(a.map(\.speed), b.map(\.speed))
    }

    func testThreeWavesWithExpectedParticleCount() {
        let particles = AchievementBurstParticle.generate(seed: 7)
        XCTAssertEqual(particles.count, 64 + 48 + 36)
        XCTAssertEqual(Set(particles.map(\.delay)), [0.0, 0.35, 0.70])
    }

    func testParticlesAreWellFormed() {
        for particle in AchievementBurstParticle.generate(seed: 99) {
            XCTAssertTrue((0..<4).contains(particle.colorIndex), "У палитры четыре цвета частиц")
            XCTAssertGreaterThan(particle.life, 0)
            XCTAssertGreaterThan(particle.speed, 0)
            XCTAssertGreaterThan(particle.size, 0)
        }
    }

    func testFirstWaveFormsEvenRing() {
        // Первая волна — 64 частицы ровным кольцом, поэтому салют получается круглым
        let wave = AchievementBurstParticle.generate(seed: 5).prefix(64).map(\.angle)
        let step = 2 * Double.pi / 64
        for index in 1..<wave.count {
            XCTAssertEqual(wave[index] - wave[index - 1], step, accuracy: 0.1)
        }
    }
}

final class MedalPaletteTests: XCTestCase {

    func testEveryCategoryHasFourBurstColors() {
        for category in FormaAchievement.AchievementCategory.allCases {
            XCTAssertEqual(category.medalPalette.burst.count, 4, "Категория \(category.rawValue)")
        }
    }
}
