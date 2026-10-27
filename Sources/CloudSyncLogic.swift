import Foundation

// MARK: - Чистая логика синхронизации через iCloud
//
// Здесь нет ни iCloud, ни UserDefaults: только правила «что делать, если на двух устройствах значения разные».
// Поэтому правила проверяются обычными тестами (Tests/CloudSyncLogic), а менеджер CloudSyncManager только применяет их.

/// Как объединяются версии одного и того же ключа с разных устройств.
enum CloudSyncPolicy: Equatable {
    /// Побеждает более поздняя запись: профиль, настройки, планы, количество щитов.
    case latest
    /// Побеждает большее число: опыт, лучший стрик, потраченный опыт — прогресс не откатывается.
    case maxNumber
    /// Достижения объединяются: открытое на любом устройстве остаётся открытым.
    case achievements
    /// Привычки объединяются по id: отметки выполнения складываются, удалённые не воскресают.
    case habits
    /// Множество строк (идентификаторы удалённых привычек): объединение.
    case stringSet
}

/// Значение ключа. Тип заранее известен из таблицы ключей, поэтому «Any» не нужен.
enum CloudSyncValue: Equatable {
    case int(Int)
    case double(Double)
    case bool(Bool)
    case string(String)
    case data(Data)

    var number: Double? {
        switch self {
        case .int(let value): return Double(value)
        case .double(let value): return value
        default: return nil
        }
    }

    /// Размер значения в байтах: облако принимает до 1 МБ на всё приложение
    var byteCount: Int {
        switch self {
        case .int, .double, .bool: return 8
        case .string(let value): return value.utf8.count
        case .data(let value): return value.count
        }
    }
}

/// Значение вместе с моментом последнего изменения пользователем (секунды с 1970 года).
struct CloudSyncEntry: Equatable {
    var value: CloudSyncValue
    var modifiedAt: TimeInterval
}

/// Что сделать после сравнения локальной и облачной версий.
enum CloudSyncOutcome: Equatable {
    /// Версии совпадают или обновлять нечего
    case keep
    /// Облачная версия новее: записать на устройство
    case adoptRemote(CloudSyncEntry)
    /// Локальная версия новее или облако пусто: отправить в облако
    case pushLocal
    /// Версии объединены в новую: записать и на устройство, и в облако
    case merged(CloudSyncEntry)
}

enum CloudSyncMerge {

    /// Сравнивает локальную и облачную версии ключа.
    /// - Parameters:
    ///   - deletedIDs: идентификаторы удалённых привычек (нужны только для политики `.habits`)
    ///   - base: состояние, с которым устройство и облако сходились в прошлый раз (только для `.habits`).
    ///     По нему отличается «отметку сняли» от «отметку ещё не успели получить»; без него списки отметок объединяются.
    static func resolve(policy: CloudSyncPolicy,
                        local: CloudSyncEntry?,
                        remote: CloudSyncEntry?,
                        deletedIDs: Set<String> = [],
                        base: CloudSyncValue? = nil) -> CloudSyncOutcome {
        guard let local = local else {
            guard let remote = remote else { return .keep }
            return .adoptRemote(remote)
        }
        guard let remote = remote else { return .pushLocal }

        let mergedValue: CloudSyncValue?
        switch policy {
        case .latest:
            return resolveLatest(local: local, remote: remote)
        case .maxNumber:
            guard let localNumber = local.value.number, let remoteNumber = remote.value.number else {
                return resolveLatest(local: local, remote: remote)
            }
            mergedValue = remoteNumber > localNumber ? remote.value : local.value
        case .achievements:
            mergedValue = mergeObjectArrays(local: local.value, remote: remote.value) { mergeAchievements(local: $0, remote: $1) }
        case .habits:
            let baseHabits = base.flatMap { value -> [[String: Any]]? in
                guard case .data(let data) = value else { return nil }
                return decodeArray(data)
            }
            mergedValue = mergeObjectArrays(local: local.value, remote: remote.value) {
                mergeHabits(local: $0, remote: $1, remoteIsNewer: remote.modifiedAt >= local.modifiedAt,
                            deletedIDs: deletedIDs, base: baseHabits)
            }
        case .stringSet:
            mergedValue = mergeStringArrays(local: local.value, remote: remote.value) { mergeStringSets(local: $0, remote: $1) }
        }

        guard let merged = mergedValue else { return resolveLatest(local: local, remote: remote) }
        return outcome(forMerged: merged, local: local, remote: remote)
    }

    /// Пустое ли значение: пустые значения, которые приложение само записывает при первом запуске,
    /// не считаются правкой пользователя и не должны затирать данные из облака.
    static func isTrivial(_ value: CloudSyncValue, spec: CloudSyncSpec) -> Bool {
        switch value {
        case .int(let number): return spec.zeroIsEmpty && number == 0
        case .double(let number): return spec.zeroIsEmpty && number == 0
        case .bool: return false
        case .string(let text): return text.isEmpty
        case .data(let data):
            guard let array = decodeArray(data) else { return data.isEmpty }
            switch spec.policy {
            case .achievements:
                return array.allSatisfy { ($0["isUnlocked"] as? Bool) != true && (($0["currentValue"] as? Double) ?? 0) == 0 }
            default:
                return array.isEmpty
            }
        }
    }

    // MARK: Последняя запись побеждает

    private static func resolveLatest(local: CloudSyncEntry, remote: CloudSyncEntry) -> CloudSyncOutcome {
        if local.value == remote.value { return .keep }
        // При равенстве времени побеждает облако: оно общее для всех устройств, поэтому они сойдутся
        return local.modifiedAt > remote.modifiedAt ? .pushLocal : .adoptRemote(remote)
    }

    // MARK: Итог слияния

    private static func outcome(forMerged merged: CloudSyncValue,
                                local: CloudSyncEntry,
                                remote: CloudSyncEntry) -> CloudSyncOutcome {
        let sameAsLocal = isEquivalent(merged, local.value)
        let sameAsRemote = isEquivalent(merged, remote.value)
        let stamp = max(local.modifiedAt, remote.modifiedAt)
        switch (sameAsLocal, sameAsRemote) {
        case (true, true): return .keep
        case (false, true): return .adoptRemote(CloudSyncEntry(value: remote.value, modifiedAt: stamp))
        case (true, false): return .pushLocal
        case (false, false): return .merged(CloudSyncEntry(value: merged, modifiedAt: stamp))
        }
    }

    /// Равенство по смыслу, а не по байтам: порядок ключей в JSON и запись числа (5 или 5.0) не важны.
    /// Иначе одинаковые данные считались бы разными и устройства бесконечно обменивались бы ими.
    private static func isEquivalent(_ lhs: CloudSyncValue, _ rhs: CloudSyncValue) -> Bool {
        guard case .data(let left) = lhs, case .data(let right) = rhs else { return lhs == rhs }
        if left == right { return true }
        guard let leftObject = try? JSONSerialization.jsonObject(with: left),
              let rightObject = try? JSONSerialization.jsonObject(with: right) else { return false }
        return (leftObject as AnyObject).isEqual(rightObject as AnyObject)
    }

    // MARK: Достижения

    /// Достижение с одним id: открытое побеждает закрытое, из двух открытых — более раннее по дате; прогресс — максимальный.
    private static func mergeAchievements(local: [[String: Any]], remote: [[String: Any]]) -> [[String: Any]] {
        var result = local
        var indexByID: [String: Int] = [:]
        for (index, item) in result.enumerated() {
            if let id = item["id"] as? String { indexByID[id] = index }
        }
        for item in remote {
            guard let id = item["id"] as? String else { continue }
            guard let index = indexByID[id] else {
                indexByID[id] = result.count
                result.append(item)
                continue
            }
            result[index] = mergeAchievement(result[index], item)
        }
        return result
    }

    private static func mergeAchievement(_ a: [String: Any], _ b: [String: Any]) -> [String: Any] {
        let aUnlocked = (a["isUnlocked"] as? Bool) ?? false
        let bUnlocked = (b["isUnlocked"] as? Bool) ?? false
        var winner = a
        if bUnlocked && !aUnlocked {
            winner = b
        } else if aUnlocked && bUnlocked,
                  let aDate = a["unlockedDate"] as? Double, let bDate = b["unlockedDate"] as? Double, bDate < aDate {
            winner = b
        }
        let progress = max((a["currentValue"] as? Double) ?? 0, (b["currentValue"] as? Double) ?? 0)
        winner["currentValue"] = progress
        return winner
    }

    // MARK: Привычки

    /// Привычки склеиваются по id. Привычки, которые есть только на одном устройстве, сохраняются, кроме удалённых.
    /// Одна и та же привычка сливается по полям, с учётом базового состояния (см. `mergeHabit`).
    private static func mergeHabits(local: [[String: Any]], remote: [[String: Any]],
                                    remoteIsNewer: Bool, deletedIDs: Set<String>,
                                    base: [[String: Any]]?) -> [[String: Any]] {
        let newer = remoteIsNewer ? remote : local

        func index(_ items: [[String: Any]]) -> [String: [String: Any]] {
            var byID: [String: [String: Any]] = [:]
            for item in items {
                if let id = item["id"] as? String { byID[id] = item }
            }
            return byID
        }
        let localByID = index(local)
        let remoteByID = index(remote)
        let baseByID = index(base ?? [])

        // Порядок берётся у более новой версии, затем добавляются привычки, которых в ней нет
        var orderedIDs: [String] = []
        var seen = Set<String>()
        for item in newer + (remoteIsNewer ? local : remote) {
            guard let id = item["id"] as? String else { continue }
            if deletedIDs.contains(id) || !seen.insert(id).inserted { continue }
            orderedIDs.append(id)
        }

        return orderedIDs.compactMap { id -> [String: Any]? in
            let localHabit = localByID[id]
            let remoteHabit = remoteByID[id]
            if let localHabit = localHabit, let remoteHabit = remoteHabit {
                return mergeHabit(local: localHabit, remote: remoteHabit, base: baseByID[id], remoteIsNewer: remoteIsNewer)
            }
            return localHabit ?? remoteHabit
        }
    }

    /// Поля-множества: отметки выполнения, заморозки, срывы
    private static let habitSetFields: Set<String> = ["completedDates", "frozenDates", "relapseDates"]

    /// Одна привычка на двух сторонах. Если известно базовое состояние, слияние трёхстороннее:
    ///  • поле изменила только одна сторона — берётся её значение, даже если версия старее;
    ///  • отметку выполнения сняли на одной стороне — она снимается и на другой, а не возвращается объединением;
    ///  • отметки, добавленные на разных устройствах, обе сохраняются;
    ///  • оба изменили одно поле по-разному — побеждает более новая версия (счётчик — большее значение).
    /// Без базы (первая синхронизация) списки отметок просто объединяются, остальное берётся у более новой версии.
    private static func mergeHabit(local: [String: Any], remote: [String: Any],
                                   base: [String: Any]?, remoteIsNewer: Bool) -> [String: Any] {
        var merged: [String: Any] = [:]
        for key in Set(local.keys).union(remote.keys) {
            let localValue = local[key]
            let remoteValue = remote[key]

            if habitSetFields.contains(key) {
                let combined = mergeSetField(localValue as? [Any], remoteValue as? [Any], base: base.map { ($0[key] as? [Any]) ?? [] })
                if let combined = combined { merged[key] = combined }
                continue
            }
            if jsonEqual(localValue, remoteValue) {
                if let value = localValue ?? remoteValue { merged[key] = value }
                continue
            }
            let chosen: Any?
            if let base = base, jsonEqual(localValue, base[key]) {
                chosen = remoteValue
            } else if let base = base, jsonEqual(remoteValue, base[key]) {
                chosen = localValue
            } else if key == "urgeResistedCount" {
                chosen = max((localValue as? Int) ?? 0, (remoteValue as? Int) ?? 0)
            } else {
                chosen = remoteIsNewer ? remoteValue : localValue
            }
            if let chosen = chosen { merged[key] = chosen }
        }
        return merged
    }

    /// Слияние списка-множества. Элемент остаётся, если он есть с обеих сторон либо добавлен хотя бы на одной
    /// (его не было в базе). Элемент, который был в базе, но пропал на одной стороне, считается снятым.
    /// Без базы (`nil`) — обычное объединение.
    private static func mergeSetField(_ first: [Any]?, _ second: [Any]?, base: [Any]?) -> [Any]? {
        guard first != nil || second != nil else { return nil }
        func keys(_ items: [Any]?) -> Set<String> { Set((items ?? []).map { String(describing: $0) }) }
        let firstKeys = keys(first)
        let secondKeys = keys(second)
        let baseKeys = keys(base)

        var result: [Any] = []
        var seen = Set<String>()
        for item in (first ?? []) + (second ?? []) {
            let key = String(describing: item)
            guard seen.insert(key).inserted else { continue }
            let inFirst = firstKeys.contains(key)
            let inSecond = secondKeys.contains(key)
            let wasInBase = base != nil && baseKeys.contains(key)
            if (inFirst && inSecond) || !wasInBase {
                result.append(item)
            }
        }
        return result
    }

    /// Равенство значений JSON по смыслу: число 5 и 5.0 одинаковы, отсутствие значения равно только отсутствию
    private static func jsonEqual(_ lhs: Any?, _ rhs: Any?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil): return true
        case let (left?, right?): return (left as AnyObject).isEqual(right as AnyObject)
        default: return false
        }
    }

    // MARK: Множество строк

    private static func mergeStringSets(local: [String], remote: [String]) -> [String] {
        Array(Set(local).union(remote)).sorted()
    }

    // MARK: JSON-вспомогательные

    private static func decodeArray(_ data: Data) -> [[String: Any]]? {
        (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]]
    }

    private static func encode(_ object: Any) -> Data? {
        try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    private static func mergeObjectArrays(local: CloudSyncValue, remote: CloudSyncValue,
                                          using merge: ([[String: Any]], [[String: Any]]) -> [[String: Any]]) -> CloudSyncValue? {
        guard case .data(let localData) = local, case .data(let remoteData) = remote,
              let localArray = decodeArray(localData), let remoteArray = decodeArray(remoteData),
              let data = encode(merge(localArray, remoteArray)) else { return nil }
        return .data(data)
    }

    private static func mergeStringArrays(local: CloudSyncValue, remote: CloudSyncValue,
                                          using merge: ([String], [String]) -> [String]) -> CloudSyncValue? {
        guard case .data(let localData) = local, case .data(let remoteData) = remote,
              let localArray = (try? JSONSerialization.jsonObject(with: localData)) as? [String],
              let remoteArray = (try? JSONSerialization.jsonObject(with: remoteData)) as? [String],
              let data = encode(merge(localArray, remoteArray)) else { return nil }
        return .data(data)
    }
}

// MARK: - Таблица синхронизируемых ключей

/// Тип значения ключа в UserDefaults
enum CloudSyncKind: Equatable {
    case int, double, bool, string, data
}

struct CloudSyncSpec: Equatable {
    let key: String
    let kind: CloudSyncKind
    let policy: CloudSyncPolicy
    /// Нуль — «ещё ничего нет» (опыт, возраст). Для щитов стрика нуль — настоящее значение: щиты потрачены.
    var zeroIsEmpty: Bool = true
}

/// Белый список: в облако уходит только то, что перечислено здесь. Ключи API, рекламная статистика, отладочные
/// флаги, согласия и данные Apple Health (они и так синхронизируются через iCloud Health) сюда не попадают.
enum CloudSyncCatalog {

    /// Ключ-«виртуальный»: заработанный опыт = текущий опыт + потраченный. Потраченный опыт только растёт,
    /// поэтому покупка щита на одном устройстве не «возвращается» синхронизацией с другого.
    static let earnedXPKey = "forma_xp_earned_v1"
    static let spentXPKey = "forma_xp_spent_v1"
    static let deletedHabitsKey = "forma_habits_deleted_v1"
    static let habitsKey = "forma_habits_v1"

    /// Порядок важен: сначала то, от чего зависят другие ключи (потраченный опыт, удалённые привычки).
    static let specs: [CloudSyncSpec] = [
        CloudSyncSpec(key: spentXPKey, kind: .int, policy: .maxNumber),
        CloudSyncSpec(key: earnedXPKey, kind: .int, policy: .maxNumber),
        CloudSyncSpec(key: "forma_best_streak", kind: .int, policy: .maxNumber),
        CloudSyncSpec(key: "forma_streak_freezes_v1", kind: .int, policy: .latest, zeroIsEmpty: false),
        CloudSyncSpec(key: "forma_achievements_v1", kind: .data, policy: .achievements),
        CloudSyncSpec(key: deletedHabitsKey, kind: .data, policy: .stringSet),
        CloudSyncSpec(key: habitsKey, kind: .data, policy: .habits),
        CloudSyncSpec(key: "custom_workouts", kind: .data, policy: .latest),
        CloudSyncSpec(key: "generated_workout_plan", kind: .string, policy: .latest),
        CloudSyncSpec(key: "generated_nutrition_plan", kind: .string, policy: .latest),
        CloudSyncSpec(key: "user_age", kind: .int, policy: .latest),
        CloudSyncSpec(key: "user_height", kind: .int, policy: .latest),
        CloudSyncSpec(key: "user_weight", kind: .double, policy: .latest),
        CloudSyncSpec(key: "user_target_weight", kind: .double, policy: .latest),
        CloudSyncSpec(key: "user_gender", kind: .string, policy: .latest),
        CloudSyncSpec(key: "user_somatotype", kind: .string, policy: .latest),
        CloudSyncSpec(key: "user_metabolism_speed", kind: .string, policy: .latest),
        CloudSyncSpec(key: "user_activity_level", kind: .string, policy: .latest),
        CloudSyncSpec(key: "step_goal", kind: .int, policy: .latest),
        CloudSyncSpec(key: "app_language", kind: .string, policy: .latest),
        CloudSyncSpec(key: "app_theme", kind: .string, policy: .latest),
        CloudSyncSpec(key: "selected_coach_id", kind: .string, policy: .latest),
        CloudSyncSpec(key: "voice_coach_enabled", kind: .bool, policy: .latest),
        CloudSyncSpec(key: "voice_coach_splits_enabled", kind: .bool, policy: .latest),
        CloudSyncSpec(key: "voice_coach_intervals_enabled", kind: .bool, policy: .latest),
        CloudSyncSpec(key: "voice_coach_hr_alerts_enabled", kind: .bool, policy: .latest)
    ]

    /// Предел размера одного значения; облако принимает 1 МБ на всё приложение и 1 МБ на ключ
    static let maxValueBytes = 200_000
    /// Предел суммы всех значений, оставляет запас до лимита облака
    static let maxTotalBytes = 700_000

    /// Префикс ключей в облаке: версия формата позволит позже поменять схему, не смешивая её со старой
    static let cloudKeyPrefix = "sync.v1."
}

// MARK: - Упаковка значения для облака

/// Значение в облаке — словарь `{v: значение, t: время}`: так значение и время приходят вместе и не расходятся.
enum CloudSyncEnvelope {

    static func pack(_ entry: CloudSyncEntry) -> [String: Any] {
        let raw: Any
        switch entry.value {
        case .int(let value): raw = value
        case .double(let value): raw = value
        case .bool(let value): raw = value
        case .string(let value): raw = value
        case .data(let value): raw = value
        }
        return ["v": raw, "t": entry.modifiedAt]
    }

    static func unpack(_ envelope: [String: Any]?, kind: CloudSyncKind) -> CloudSyncEntry? {
        guard let envelope = envelope, let time = (envelope["t"] as? NSNumber)?.doubleValue,
              let raw = envelope["v"] else { return nil }
        let value: CloudSyncValue?
        switch kind {
        case .int: value = (raw as? NSNumber).map { .int($0.intValue) }
        case .double: value = (raw as? NSNumber).map { .double($0.doubleValue) }
        case .bool: value = (raw as? NSNumber).map { .bool($0.boolValue) }
        case .string: value = (raw as? String).map { .string($0) }
        case .data: value = (raw as? Data).map { .data($0) }
        }
        return value.map { CloudSyncEntry(value: $0, modifiedAt: time) }
    }
}
