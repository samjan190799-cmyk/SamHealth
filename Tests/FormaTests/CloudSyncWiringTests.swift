import XCTest
@testable import Forma

// Подключение синхронизации к менеджерам: правила слияния проверяются отдельно (Tests/CloudSyncLogic),
// здесь — то, как опыт, щиты, достижения и привычки читают и пишут своё состояние.

@MainActor
final class CloudSyncWiringTests: XCTestCase {

    private func makeDefaults(_ name: String = #function) -> UserDefaults {
        let suite = "CloudSyncWiringTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    // MARK: Щиты и опыт

    func testFirstLaunchDoesNotStoreDefaultStreakShield() {
        // Иначе значение по умолчанию на новом телефоне затёрло бы щиты, сохранённые в iCloud
        let defaults = makeDefaults()
        let manager = GamificationManager(defaults: defaults)

        XCTAssertEqual(manager.streakFreezesCount, 1, "Новичку положен один бесплатный щит")
        XCTAssertNil(defaults.object(forKey: "forma_streak_freezes_v1"), "Значение по умолчанию не должно попадать в хранилище")
    }

    func testBuyingShieldRecordsSpentExperience() {
        let defaults = makeDefaults()
        defaults.set(500, forKey: "forma_user_xp")
        let manager = GamificationManager(defaults: defaults)

        XCTAssertTrue(manager.buyStreakFreezeWithXP(cost: 200))

        XCTAssertEqual(manager.totalXP, 300)
        XCTAssertEqual(defaults.integer(forKey: CloudSyncCatalog.spentXPKey), 200)
        XCTAssertEqual(defaults.integer(forKey: "forma_streak_freezes_v1"), 2)
    }

    func testSpentExperienceAccumulatesAcrossPurchases() {
        let defaults = makeDefaults()
        defaults.set(1_000, forKey: "forma_user_xp")
        let manager = GamificationManager(defaults: defaults)

        XCTAssertTrue(manager.buyStreakFreezeWithXP(cost: 200))
        XCTAssertTrue(manager.buyStreakFreezeWithXP(cost: 200))

        XCTAssertEqual(defaults.integer(forKey: CloudSyncCatalog.spentXPKey), 400)
    }

    func testFailedPurchaseDoesNotChangeSpentExperience() {
        let defaults = makeDefaults()
        defaults.set(50, forKey: "forma_user_xp")
        let manager = GamificationManager(defaults: defaults)

        XCTAssertFalse(manager.buyStreakFreezeWithXP(cost: 200))

        XCTAssertEqual(defaults.integer(forKey: CloudSyncCatalog.spentXPKey), 0)
        XCTAssertEqual(manager.totalXP, 50)
    }

    // MARK: Приход данных из iCloud

    func testReloadFromCloudPicksUpExperienceShieldsAndBestStreak() {
        let defaults = makeDefaults()
        let manager = GamificationManager(defaults: defaults)

        defaults.set(1_250, forKey: "forma_user_xp")
        defaults.set(3, forKey: "forma_streak_freezes_v1")
        defaults.set(21, forKey: "forma_best_streak")
        manager.reloadFromCloud()

        XCTAssertEqual(manager.totalXP, 1_250)
        XCTAssertEqual(manager.streakFreezesCount, 3)
        XCTAssertEqual(manager.bestStreak, 21)
    }

    func testReloadFromCloudKeepsBetterLocalBestStreak() {
        let defaults = makeDefaults()
        defaults.set(30, forKey: "forma_best_streak")
        let manager = GamificationManager(defaults: defaults)

        defaults.set(12, forKey: "forma_best_streak")
        manager.reloadFromCloud()

        XCTAssertEqual(manager.bestStreak, 30, "Лучший стрик не должен уменьшаться")
    }

    func testReloadFromCloudShowsAchievementsUnlockedElsewhereWithoutCelebration() throws {
        let defaults = makeDefaults()
        let manager = GamificationManager(defaults: defaults)
        var unlocked = try XCTUnwrap(manager.achievements.first)
        unlocked.isUnlocked = true
        unlocked.currentValue = unlocked.targetValue
        unlocked.unlockedDate = Date()
        defaults.set(try JSONEncoder().encode([unlocked]), forKey: "forma_achievements_v1")

        manager.reloadFromCloud()

        XCTAssertEqual(manager.achievements.first(where: { $0.id == unlocked.id })?.isUnlocked, true)
        XCTAssertNil(manager.newlyUnlockedAchievement, "Награда, открытая на другом устройстве, там уже отпразднована")
    }

    func testReloadFromCloudWithoutShieldKeyKeepsFreeShield() {
        let defaults = makeDefaults()
        let manager = GamificationManager(defaults: defaults)

        manager.reloadFromCloud()

        XCTAssertEqual(manager.streakFreezesCount, 1)
    }
}

// MARK: - Метки удалённых привычек

final class HabitTombstonesTests: XCTestCase {

    private func makeDefaults(_ name: String = #function) -> UserDefaults {
        let suite = "HabitTombstonesTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    func testNothingRecordedByDefault() {
        XCTAssertEqual(HabitTombstones.ids(in: makeDefaults()), [])
    }

    func testRecordedIdIsReadBack() {
        let defaults = makeDefaults()
        let id = UUID()
        HabitTombstones.record(id, in: defaults)
        XCTAssertEqual(HabitTombstones.ids(in: defaults), [id.uuidString])
    }

    func testRecordingTwiceKeepsOneEntry() {
        let defaults = makeDefaults()
        let id = UUID()
        HabitTombstones.record(id, in: defaults)
        HabitTombstones.record(id, in: defaults)
        XCTAssertEqual(HabitTombstones.ids(in: defaults).count, 1)
    }

    func testSeveralDeletionsAreAllKept() {
        let defaults = makeDefaults()
        let first = UUID()
        let second = UUID()
        HabitTombstones.record(first, in: defaults)
        HabitTombstones.record(second, in: defaults)
        XCTAssertEqual(Set(HabitTombstones.ids(in: defaults)), [first.uuidString, second.uuidString])
    }

    func testStorageFormatMatchesWhatTheSyncRulesExpect() throws {
        // Правила слияния читают это значение как JSON-массив строк
        let defaults = makeDefaults()
        let id = UUID()
        HabitTombstones.record(id, in: defaults)

        let data = try XCTUnwrap(defaults.data(forKey: CloudSyncCatalog.deletedHabitsKey))
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String]
        XCTAssertEqual(decoded, [id.uuidString])
    }
}
