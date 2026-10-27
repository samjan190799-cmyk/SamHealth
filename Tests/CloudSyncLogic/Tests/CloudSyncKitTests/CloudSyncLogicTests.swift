import XCTest
@testable import CloudSyncKit

// MARK: - Вспомогательное

private func json(_ object: Any) -> Data {
    try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
}

private func entry(_ object: Any, at time: TimeInterval) -> CloudSyncEntry {
    CloudSyncEntry(value: .data(json(object)), modifiedAt: time)
}

private func objects(of value: CloudSyncValue) -> [[String: Any]] {
    guard case .data(let data) = value,
          let array = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else { return [] }
    return array
}

private func strings(of value: CloudSyncValue) -> [String] {
    guard case .data(let data) = value,
          let array = (try? JSONSerialization.jsonObject(with: data)) as? [String] else { return [] }
    return array
}

/// Запись, которую итог применяет на устройстве (для `keep` и `pushLocal` её нет)
private func appliedEntry(_ outcome: CloudSyncOutcome) -> CloudSyncEntry? {
    switch outcome {
    case .adoptRemote(let entry), .merged(let entry): return entry
    case .keep, .pushLocal: return nil
    }
}

private func spec(_ key: String) -> CloudSyncSpec {
    CloudSyncCatalog.specs.first { $0.key == key }!
}

private func habit(_ id: String, title: String = "Вода", done: [String] = [], urge: Int = 0) -> [String: Any] {
    ["id": id, "title": title, "completedDates": done, "urgeResistedCount": urge]
}

private func achievement(_ id: String, unlocked: Bool = false, date: Double? = nil, progress: Double = 0) -> [String: Any] {
    var item: [String: Any] = ["id": id, "title": id, "isUnlocked": unlocked, "currentValue": progress, "targetValue": 10.0]
    if let date = date { item["unlockedDate"] = date }
    return item
}

// MARK: - Последняя запись побеждает

final class LatestPolicyTests: XCTestCase {

    private func resolve(_ local: CloudSyncEntry?, _ remote: CloudSyncEntry?) -> CloudSyncOutcome {
        CloudSyncMerge.resolve(policy: .latest, local: local, remote: remote)
    }

    func testNothingAnywhereKeepsNothing() {
        XCTAssertEqual(resolve(nil, nil), .keep)
    }

    func testNewDeviceTakesCloudValue() {
        // Смена телефона: на новом устройстве ничего нет, в облаке профиль со старого
        let remote = CloudSyncEntry(value: .int(178), modifiedAt: 100)
        XCTAssertEqual(resolve(nil, remote), .adoptRemote(remote))
    }

    func testEmptyCloudReceivesLocalValue() {
        XCTAssertEqual(resolve(CloudSyncEntry(value: .int(178), modifiedAt: 100), nil), .pushLocal)
    }

    func testNewerCloudValueWins() {
        let remote = CloudSyncEntry(value: .int(180), modifiedAt: 200)
        XCTAssertEqual(resolve(CloudSyncEntry(value: .int(178), modifiedAt: 100), remote), .adoptRemote(remote))
    }

    func testNewerLocalValueWins() {
        XCTAssertEqual(resolve(CloudSyncEntry(value: .int(180), modifiedAt: 200),
                               CloudSyncEntry(value: .int(178), modifiedAt: 100)), .pushLocal)
    }

    func testSameValueIsLeftAloneEvenIfTimesDiffer() {
        XCTAssertEqual(resolve(CloudSyncEntry(value: .string("ru"), modifiedAt: 100),
                               CloudSyncEntry(value: .string("ru"), modifiedAt: 999)), .keep)
    }

    func testTieGoesToCloudSoDevicesConverge() {
        let remote = CloudSyncEntry(value: .string("en"), modifiedAt: 100)
        XCTAssertEqual(resolve(CloudSyncEntry(value: .string("ru"), modifiedAt: 100), remote), .adoptRemote(remote))
    }

    func testBooleansAndDoublesAreCompared() {
        let remote = CloudSyncEntry(value: .bool(false), modifiedAt: 50)
        XCTAssertEqual(resolve(CloudSyncEntry(value: .bool(true), modifiedAt: 10), remote), .adoptRemote(remote))
        XCTAssertEqual(resolve(CloudSyncEntry(value: .double(70.5), modifiedAt: 60),
                               CloudSyncEntry(value: .double(72.0), modifiedAt: 50)), .pushLocal)
    }
}

// MARK: - Большее число побеждает

final class MaxNumberPolicyTests: XCTestCase {

    private func resolve(_ local: CloudSyncValue, _ localTime: TimeInterval,
                         _ remote: CloudSyncValue, _ remoteTime: TimeInterval) -> CloudSyncOutcome {
        CloudSyncMerge.resolve(policy: .maxNumber,
                               local: CloudSyncEntry(value: local, modifiedAt: localTime),
                               remote: CloudSyncEntry(value: remote, modifiedAt: remoteTime))
    }

    func testProgressNeverGoesBackwards() {
        // Облако старее, но опыта в нём больше — побеждает большее
        XCTAssertEqual(resolve(.int(500), 200, .int(900), 100), .adoptRemote(CloudSyncEntry(value: .int(900), modifiedAt: 200)))
        XCTAssertEqual(resolve(.int(900), 100, .int(500), 200), .pushLocal)
    }

    func testEqualNumbersKeep() {
        XCTAssertEqual(resolve(.int(500), 1, .int(500), 2), .keep)
    }

    func testIntegersAndDoublesAreComparedTogether() {
        XCTAssertEqual(resolve(.int(100), 1, .double(150.5), 1), .adoptRemote(CloudSyncEntry(value: .double(150.5), modifiedAt: 1)))
    }

    func testNonNumbersFallBackToLatest() {
        XCTAssertEqual(resolve(.string("a"), 5, .string("b"), 1), .pushLocal)
    }
}

// MARK: - Достижения

final class AchievementsPolicyTests: XCTestCase {

    private func resolve(_ local: [[String: Any]], _ remote: [[String: Any]],
                         localTime: TimeInterval = 10, remoteTime: TimeInterval = 20) -> CloudSyncOutcome {
        CloudSyncMerge.resolve(policy: .achievements,
                               local: entry(local, at: localTime), remote: entry(remote, at: remoteTime))
    }

    func testAchievementUnlockedOnOtherDeviceCarriesOver() {
        let outcome = resolve([achievement("a", progress: 3), achievement("b")],
                              [achievement("a", unlocked: true, date: 100, progress: 5), achievement("b")])
        guard let applied = appliedEntry(outcome) else { return XCTFail("Ожидалась запись на устройство: \(outcome)") }
        let items = objects(of: applied.value)
        XCTAssertEqual(items.first { $0["id"] as? String == "a" }?["isUnlocked"] as? Bool, true)
        XCTAssertEqual(items.first { $0["id"] as? String == "a" }?["currentValue"] as? Double, 5)
    }

    func testUnlocksFromBothDevicesAreCombined() {
        let outcome = resolve([achievement("a", unlocked: true, date: 100), achievement("b")],
                              [achievement("a"), achievement("b", unlocked: true, date: 200)])
        guard case .merged(let merged) = outcome else { return XCTFail("Ожидалось слияние: \(outcome)") }
        let items = objects(of: merged.value)
        XCTAssertEqual(items.count, 2)
        XCTAssertTrue(items.allSatisfy { ($0["isUnlocked"] as? Bool) == true }, "Открытое на любом устройстве должно остаться открытым")
    }

    func testEarlierUnlockDateIsKept() {
        let outcome = resolve([achievement("a", unlocked: true, date: 200)],
                              [achievement("a", unlocked: true, date: 100)])
        guard let applied = appliedEntry(outcome) else { return XCTFail("Ожидалась запись на устройство: \(outcome)") }
        XCTAssertEqual(objects(of: applied.value).first?["unlockedDate"] as? Double, 100)
    }

    func testAchievementKnownOnlyToOtherDeviceIsAdded() {
        let outcome = resolve([achievement("a")], [achievement("a"), achievement("new_in_next_version", unlocked: true, date: 5)])
        guard let applied = appliedEntry(outcome) else { return XCTFail("Ожидалась запись на устройство: \(outcome)") }
        XCTAssertEqual(objects(of: applied.value).count, 2)
    }

    func testProgressTakesTheHigherValue() {
        // Локальный прогресс выше облачного: облако нужно обновить, устройство не меняется
        XCTAssertEqual(resolve([achievement("a", progress: 7)], [achievement("a", progress: 3)]), .pushLocal)
    }

    func testIdenticalDataKeepsEvenWithDifferentKeyOrder() {
        let local = CloudSyncEntry(value: .data(Data(#"[{"id":"a","isUnlocked":true,"currentValue":5}]"#.utf8)), modifiedAt: 1)
        let remote = CloudSyncEntry(value: .data(Data(#"[{"currentValue":5.0,"isUnlocked":true,"id":"a"}]"#.utf8)), modifiedAt: 2)
        XCTAssertEqual(CloudSyncMerge.resolve(policy: .achievements, local: local, remote: remote), .keep,
                       "Порядок ключей и запись числа не должны считаться отличием: иначе устройства будут бесконечно обмениваться данными")
    }

    func testBrokenDataFallsBackToLatest() {
        let local = CloudSyncEntry(value: .data(Data("не json".utf8)), modifiedAt: 5)
        let remote = entry([achievement("a")], at: 9)
        XCTAssertEqual(CloudSyncMerge.resolve(policy: .achievements, local: local, remote: remote), .adoptRemote(remote))
    }
}

// MARK: - Привычки

final class HabitsPolicyTests: XCTestCase {

    private func resolve(_ local: [[String: Any]], _ remote: [[String: Any]],
                         localTime: TimeInterval = 10, remoteTime: TimeInterval = 20,
                         deleted: Set<String> = [], base: [[String: Any]]? = nil) -> CloudSyncOutcome {
        CloudSyncMerge.resolve(policy: .habits, local: entry(local, at: localTime), remote: entry(remote, at: remoteTime),
                               deletedIDs: deleted, base: base.map { CloudSyncValue.data(json($0)) })
    }

    private func dates(_ outcome: CloudSyncOutcome, habit index: Int = 0) -> Set<String> {
        guard let applied = appliedEntry(outcome) else { return [] }
        return Set(objects(of: applied.value)[index]["completedDates"] as? [String] ?? [])
    }

    // MARK: Трёхстороннее слияние (с базовым состоянием)

    func testUncheckedDayStaysUncheckedInsteadOfComingBackFromCloud() {
        // Отметку 02 сняли на этом устройстве; облако ещё хранит её. Без базы объединение вернуло бы отметку.
        let base = [habit("A", done: ["2026-01-01", "2026-01-02"])]
        let outcome = resolve([habit("A", done: ["2026-01-01"])], base, localTime: 30, remoteTime: 20, base: base)
        XCTAssertEqual(outcome, .pushLocal, "Облако нужно обновить, а устройство оставить как есть")
    }

    func testUncheckMadeOnOtherDeviceReachesThisOne() {
        let base = [habit("A", done: ["2026-01-01", "2026-01-02"])]
        let outcome = resolve(base, [habit("A", done: ["2026-01-01"])], localTime: 10, remoteTime: 20, base: base)
        XCTAssertEqual(dates(outcome), ["2026-01-01"])
    }

    func testChecksAddedOnDifferentDevicesAreBothKept() {
        let base = [habit("A", done: ["2026-01-01"])]
        let outcome = resolve([habit("A", done: ["2026-01-01", "2026-01-02"])],
                              [habit("A", done: ["2026-01-01", "2026-01-03"])], base: base)
        XCTAssertEqual(dates(outcome), ["2026-01-01", "2026-01-02", "2026-01-03"])
    }

    func testRemovalOnOneSideAndAdditionOnTheOtherAreBothApplied() {
        let base = [habit("A", done: ["2026-01-01", "2026-01-02"])]
        let outcome = resolve([habit("A", done: ["2026-01-01"])],
                              [habit("A", done: ["2026-01-01", "2026-01-02", "2026-01-03"])], base: base)
        XCTAssertEqual(dates(outcome), ["2026-01-01", "2026-01-03"])
    }

    func testFieldChangedOnlyHereSurvivesEvenWhenCloudVersionIsNewer() {
        // Название переименовали на этом устройстве, на другом отметили день (облако новее): нужно и то и другое
        let base = [habit("A", title: "Вода")]
        let outcome = resolve([habit("A", title: "Вода 2 л")],
                              [habit("A", title: "Вода", done: ["2026-01-05"])],
                              localTime: 10, remoteTime: 20, base: base)
        guard let applied = appliedEntry(outcome) else { return XCTFail("Ожидалось слияние: \(outcome)") }
        let merged = objects(of: applied.value)[0]
        XCTAssertEqual(merged["title"] as? String, "Вода 2 л")
        XCTAssertEqual(merged["completedDates"] as? [String], ["2026-01-05"])
    }

    func testConflictingEditsOfOneFieldTakeTheNewerVersion() {
        let base = [habit("A", title: "Вода")]
        let outcome = resolve([habit("A", title: "Своё")], [habit("A", title: "Чужое")], localTime: 30, remoteTime: 20, base: base)
        XCTAssertEqual(outcome, .pushLocal)
    }

    func testCounterConflictTakesTheHigherValueEvenWithBase() {
        let base = [habit("A", urge: 1)]
        let outcome = resolve([habit("A", urge: 3)], [habit("A", urge: 5)], localTime: 30, remoteTime: 20, base: base)
        XCTAssertEqual(objects(of: appliedEntry(outcome)!.value).first?["urgeResistedCount"] as? Int, 5)
    }

    func testMergeWithBaseIsStable() {
        let base = [habit("A", done: ["2026-01-01"])]
        let first = resolve([habit("A", done: ["2026-01-01", "2026-01-02"])],
                            [habit("A", done: ["2026-01-01", "2026-01-03"])], base: base)
        guard case .merged(let merged) = first else { return XCTFail("Ожидалось слияние: \(first)") }
        XCTAssertEqual(CloudSyncMerge.resolve(policy: .habits, local: merged, remote: merged, base: merged.value), .keep)
    }

    func testWithoutBaseChecksAreCombined() {
        // Первая синхронизация: базы нет, поэтому лучше лишняя отметка, чем потерянная
        let outcome = resolve([habit("A", done: ["2026-01-01"])], [habit("A", done: ["2026-01-02"])])
        XCTAssertEqual(dates(outcome), ["2026-01-01", "2026-01-02"])
    }

    func testBrokenBaseIsIgnored() {
        let outcome = CloudSyncMerge.resolve(policy: .habits,
                                             local: entry([habit("A", done: ["2026-01-01"])], at: 10),
                                             remote: entry([habit("A", done: ["2026-01-02"])], at: 20),
                                             base: .data(Data("не json".utf8)))
        XCTAssertEqual(dates(outcome), ["2026-01-01", "2026-01-02"])
    }

    func testCompletionsFromBothDevicesAreCombined() {
        let outcome = resolve([habit("A", done: ["2026-01-01", "2026-01-02"])],
                              [habit("A", done: ["2026-01-02", "2026-01-03"])])
        guard case .merged(let merged) = outcome else { return XCTFail("Ожидалось слияние: \(outcome)") }
        let items = objects(of: merged.value)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(Set(items[0]["completedDates"] as? [String] ?? []), ["2026-01-01", "2026-01-02", "2026-01-03"],
                       "Отметки с обоих устройств не должны теряться")
    }

    func testOtherFieldsComeFromTheNewerVersion() {
        // Облачная версия новее: название берётся из неё
        let newerRemote = resolve([habit("A", title: "Старое")], [habit("A", title: "Новое")], localTime: 10, remoteTime: 20)
        XCTAssertEqual(objects(of: appliedEntry(newerRemote)!.value).first?["title"] as? String, "Новое")
        // Локальная версия новее: название остаётся своим, облако обновляется
        XCTAssertEqual(resolve([habit("A", title: "Старое")], [habit("A", title: "Новое")], localTime: 30, remoteTime: 20), .pushLocal)
    }

    func testCounterTakesTheHigherValue() {
        let outcome = resolve([habit("A", title: "Своё", urge: 2)], [habit("A", title: "Чужое", urge: 5)], localTime: 30, remoteTime: 20)
        guard case .merged(let merged) = outcome else { return XCTFail("Ожидалось слияние: \(outcome)") }
        XCTAssertEqual(objects(of: merged.value).first?["urgeResistedCount"] as? Int, 5)
        XCTAssertEqual(objects(of: merged.value).first?["title"] as? String, "Своё")
    }

    func testHabitsOfEachDeviceAreKept() {
        let outcome = resolve([habit("A")], [habit("B")])
        guard case .merged(let merged) = outcome else { return XCTFail("Ожидалось слияние: \(outcome)") }
        XCTAssertEqual(Set(objects(of: merged.value).compactMap { $0["id"] as? String }), ["A", "B"])
    }

    func testDeletedHabitDoesNotComeBack() {
        // Привычку B удалили на одном устройстве; на другом она ещё есть
        let outcome = resolve([habit("A"), habit("B")], [habit("A")], deleted: ["B"])
        guard let applied = appliedEntry(outcome) else { return XCTFail("Ожидалась запись на устройство: \(outcome)") }
        XCTAssertEqual(objects(of: applied.value).compactMap { $0["id"] as? String }, ["A"])
    }

    func testDeletionAlsoClearsTheCloudCopy() {
        // Облако тоже содержит удалённую привычку: слияние должно очистить обе стороны
        let outcome = resolve([habit("A")], [habit("A"), habit("B")], deleted: ["B"])
        XCTAssertEqual(outcome, .pushLocal)
    }

    func testOrderFollowsTheNewerVersion() {
        let outcome = resolve([habit("A"), habit("B")], [habit("B"), habit("A")], localTime: 10, remoteTime: 20)
        guard let applied = appliedEntry(outcome) else { return XCTFail("Ожидалась запись на устройство: \(outcome)") }
        XCTAssertEqual(objects(of: applied.value).compactMap { $0["id"] as? String }, ["B", "A"])
    }

    func testRepeatedMergeIsStable() {
        // Слияние уже слитого ничего не меняет: устройства не будут бесконечно переписывать друг друга
        let first = resolve([habit("A", done: ["2026-01-01"])], [habit("A", done: ["2026-01-02"])])
        guard case .merged(let merged) = first else { return XCTFail("Ожидалось слияние: \(first)") }
        let second = CloudSyncMerge.resolve(policy: .habits, local: merged, remote: merged)
        XCTAssertEqual(second, .keep)
    }
}

// MARK: - Множество строк

final class StringSetPolicyTests: XCTestCase {

    func testUnionWithoutDuplicatesInStableOrder() {
        let outcome = CloudSyncMerge.resolve(policy: .stringSet, local: entry(["b", "a"], at: 1), remote: entry(["c", "a"], at: 2))
        guard case .merged(let merged) = outcome else { return XCTFail("Ожидалось слияние: \(outcome)") }
        XCTAssertEqual(strings(of: merged.value), ["a", "b", "c"])
    }

    func testSameSetInDifferentOrderConverges() {
        let outcome = CloudSyncMerge.resolve(policy: .stringSet, local: entry(["b", "a"], at: 1), remote: entry(["a", "b"], at: 2))
        XCTAssertEqual(strings(of: appliedEntry(outcome)?.value ?? .data(Data())), ["a", "b"])
    }
}

// MARK: - Пустые значения первого запуска

final class TrivialValueTests: XCTestCase {

    func testZeroExperienceIsNotAUserEdit() {
        XCTAssertTrue(CloudSyncMerge.isTrivial(.int(0), spec: spec(CloudSyncCatalog.earnedXPKey)))
        XCTAssertFalse(CloudSyncMerge.isTrivial(.int(5), spec: spec(CloudSyncCatalog.earnedXPKey)))
    }

    func testZeroStreakShieldsIsARealValue() {
        // Потратил последний щит — это правка, она должна дойти до других устройств
        XCTAssertFalse(CloudSyncMerge.isTrivial(.int(0), spec: spec("forma_streak_freezes_v1")))
    }

    func testBooleansAreNeverTrivial() {
        XCTAssertFalse(CloudSyncMerge.isTrivial(.bool(false), spec: spec("voice_coach_enabled")))
    }

    func testEmptyListsAndStringsAreTrivial() {
        XCTAssertTrue(CloudSyncMerge.isTrivial(.data(json([Any]())), spec: spec(CloudSyncCatalog.habitsKey)))
        XCTAssertFalse(CloudSyncMerge.isTrivial(.data(json([habit("A")])), spec: spec(CloudSyncCatalog.habitsKey)))
        XCTAssertTrue(CloudSyncMerge.isTrivial(.string(""), spec: spec("generated_workout_plan")))
        XCTAssertFalse(CloudSyncMerge.isTrivial(.string("План"), spec: spec("generated_workout_plan")))
    }

    func testFreshAchievementCatalogIsTrivial() {
        // Список закрытых достижений без прогресса приложение создаёт само при первом запуске
        let fresh = CloudSyncValue.data(json([achievement("a"), achievement("b")]))
        XCTAssertTrue(CloudSyncMerge.isTrivial(fresh, spec: spec("forma_achievements_v1")))
        XCTAssertFalse(CloudSyncMerge.isTrivial(.data(json([achievement("a", unlocked: true, date: 1)])), spec: spec("forma_achievements_v1")))
        XCTAssertFalse(CloudSyncMerge.isTrivial(.data(json([achievement("a", progress: 2)])), spec: spec("forma_achievements_v1")))
    }
}

// MARK: - Конверт для облака

final class EnvelopeTests: XCTestCase {

    func testEveryKindSurvivesPackingAndUnpacking() {
        let cases: [(CloudSyncValue, CloudSyncKind)] = [
            (.int(178), .int), (.double(72.5), .double), (.bool(true), .bool),
            (.string("Мужской"), .string), (.data(Data([1, 2, 3])), .data)
        ]
        for (value, kind) in cases {
            let source = CloudSyncEntry(value: value, modifiedAt: 1_800_000_000.5)
            XCTAssertEqual(CloudSyncEnvelope.unpack(CloudSyncEnvelope.pack(source), kind: kind), source, "\(kind)")
        }
    }

    func testFalseBooleanSurvives() {
        let source = CloudSyncEntry(value: .bool(false), modifiedAt: 5)
        XCTAssertEqual(CloudSyncEnvelope.unpack(CloudSyncEnvelope.pack(source), kind: .bool), source)
    }

    func testValueOfAnotherTypeIsRejected() {
        let packed = CloudSyncEnvelope.pack(CloudSyncEntry(value: .string("текст"), modifiedAt: 5))
        XCTAssertNil(CloudSyncEnvelope.unpack(packed, kind: .int))
        XCTAssertNil(CloudSyncEnvelope.unpack(packed, kind: .data))
    }

    func testIncompleteEnvelopeIsRejected() {
        XCTAssertNil(CloudSyncEnvelope.unpack(nil, kind: .int))
        XCTAssertNil(CloudSyncEnvelope.unpack(["v": 5], kind: .int), "Без времени изменения значение использовать нельзя")
        XCTAssertNil(CloudSyncEnvelope.unpack(["t": 5.0], kind: .int))
    }
}

// MARK: - Таблица ключей

final class CatalogTests: XCTestCase {

    private var keys: [String] { CloudSyncCatalog.specs.map(\.key) }

    func testKeysAreUnique() {
        XCTAssertEqual(Set(keys).count, keys.count)
    }

    func testDependenciesComeFirst() {
        // Потраченный опыт нужен, чтобы пересчитать текущий; удалённые привычки — чтобы отфильтровать список
        XCTAssertLessThan(keys.firstIndex(of: CloudSyncCatalog.spentXPKey)!, keys.firstIndex(of: CloudSyncCatalog.earnedXPKey)!)
        XCTAssertLessThan(keys.firstIndex(of: CloudSyncCatalog.deletedHabitsKey)!, keys.firstIndex(of: CloudSyncCatalog.habitsKey)!)
    }

    func testNoSecretsOrHealthDataGoToTheCloud() {
        for key in keys {
            XCTAssertFalse(key.hasPrefix("api_key"), "\(key): ключи API нельзя хранить в облаке")
            XCTAssertFalse(key.hasPrefix("health_"), "\(key): данные Apple Health синхронизирует сам iCloud Health")
            XCTAssertFalse(key.contains("debug"), "\(key): отладочные флаги не синхронизируются")
            XCTAssertFalse(key.contains("consent"), "\(key): согласия даются на каждом устройстве отдельно")
            XCTAssertFalse(key.contains("premium"), "\(key): подписка проверяется через App Store, а не облако")
        }
    }

    func testPoliciesMatchTheStoredShape() {
        for spec in CloudSyncCatalog.specs {
            switch spec.policy {
            case .achievements, .habits, .stringSet: XCTAssertEqual(spec.kind, .data, spec.key)
            case .maxNumber: XCTAssertTrue(spec.kind == .int || spec.kind == .double, spec.key)
            case .latest: break
            }
        }
    }

    func testLimitsLeaveRoomInsideTheCloudQuota() {
        XCTAssertLessThan(CloudSyncCatalog.maxValueBytes, CloudSyncCatalog.maxTotalBytes)
        XCTAssertLessThan(CloudSyncCatalog.maxTotalBytes, 1_000_000)
    }
}
