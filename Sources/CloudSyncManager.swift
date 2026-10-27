import Foundation
import UIKit

extension Notification.Name {
    /// Данные из iCloud записаны на устройство: менеджеры (привычки, опыт) перечитывают своё состояние.
    static let formaCloudSyncDidApply = Notification.Name("FormaCloudSyncDidApply")
}

/// Запись идентификаторов удалённых привычек. Нужна, чтобы привычка, удалённая на одном устройстве,
/// не вернулась с другого при синхронизации. Пишется всегда, даже если синхронизация выключена.
enum HabitTombstones {
    static func ids(in defaults: UserDefaults = .standard) -> [String] {
        guard let data = defaults.data(forKey: CloudSyncCatalog.deletedHabitsKey),
              let ids = (try? JSONSerialization.jsonObject(with: data)) as? [String] else { return [] }
        return ids
    }

    static func record(_ id: UUID, in defaults: UserDefaults = .standard) {
        var all = Set(ids(in: defaults))
        guard all.insert(id.uuidString).inserted,
              let data = try? JSONSerialization.data(withJSONObject: all.sorted()) else { return }
        defaults.set(data, forKey: CloudSyncCatalog.deletedHabitsKey)
    }
}

/// Синхронизация профиля, прогресса и привычек между устройствами через iCloud (хранилище «ключ — значение»).
/// Правила слияния — в CloudSyncLogic.swift и проверяются тестами; здесь только чтение и запись.
///
/// Принцип работы:
///  • при запуске и возврате в приложение облако сверяется с устройством;
///  • изменения на устройстве замечаются по уведомлению UserDefaults и отправляются через секунду-две;
///  • изменения из облака записываются в UserDefaults, а менеджеры получают `.formaCloudSyncDidApply`.
@MainActor
final class CloudSyncManager: ObservableObject {

    static let shared = CloudSyncManager()
    static let enabledKey = "cloud_sync_enabled"

    private static let metaKey = "forma_cloud_sync_meta_v1"

    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var isICloudAvailable: Bool

    private let defaults = UserDefaults.standard
    private let store = NSUbiquitousKeyValueStore.default
    /// Время последней правки пользователем по каждому ключу. Не синхронизируется: у каждого устройства своё.
    private var meta: [String: Double]
    /// Последние значения, которые мы видели на устройстве: по отличию от них находим правки.
    private var lastKnown: [String: CloudSyncValue] = [:]
    private var started = false
    private var scanTask: Task<Void, Never>?

    private init() {
        meta = (UserDefaults.standard.dictionary(forKey: Self.metaKey) as? [String: Double]) ?? [:]
        isICloudAvailable = FileManager.default.ubiquityIdentityToken != nil
    }

    var isEnabled: Bool {
        (defaults.object(forKey: Self.enabledKey) as? Bool) ?? true
    }

    // MARK: - Запуск

    /// Вызывается при старте процесса, до создания менеджеров: так облачные данные успевают попасть на устройство
    /// раньше, чем менеджеры прочитают состояние.
    func start() {
        guard !started else { return }
        started = true
        #if DEBUG
        // Юнит-тесты запускают приложение как хост и не должны трогать облако
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil { return }
        #endif

        for spec in CloudSyncCatalog.specs {
            if let value = readLocal(spec) { lastKnown[spec.key] = value }
        }

        let center = NotificationCenter.default
        center.addObserver(forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: store, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.reconcile() }
        }
        center.addObserver(forName: UserDefaults.didChangeNotification, object: defaults, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.scheduleLocalScan() }
        }
        center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.syncNow() }
        }
        center.addObserver(forName: NSNotification.Name.NSUbiquityIdentityDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.isICloudAvailable = FileManager.default.ubiquityIdentityToken != nil
                self.syncNow()
            }
        }

        store.synchronize()
        reconcile()
    }

    /// Ручная синхронизация и синхронизация при возврате в приложение
    func syncNow() {
        guard isEnabled else { return }
        isICloudAvailable = FileManager.default.ubiquityIdentityToken != nil
        store.synchronize()
        reconcile()
    }

    // MARK: - Правки на устройстве

    private func scheduleLocalScan() {
        guard isEnabled else { return }
        scanTask?.cancel()
        scanTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            self?.scanLocalChanges()
        }
    }

    /// Находит ключи, изменённые пользователем, запоминает время правки и сверяет их с облаком
    private func scanLocalChanges() {
        let now = Date().timeIntervalSince1970
        var changedKeys = Set<String>()
        for spec in CloudSyncCatalog.specs {
            guard let value = readLocal(spec) else {
                lastKnown[spec.key] = nil
                continue
            }
            guard lastKnown[spec.key] != value else { continue }
            lastKnown[spec.key] = value
            // Заглушки первого запуска (нулевой опыт, пустой список) — не правка пользователя
            if meta[spec.key] == nil && CloudSyncMerge.isTrivial(value, spec: spec) { continue }
            meta[spec.key] = now
            changedKeys.insert(spec.key)
        }
        guard !changedKeys.isEmpty else { return }
        saveMeta()
        reconcile(only: changedKeys)
    }

    // MARK: - Сверка с облаком

    private func reconcile(only keys: Set<String>? = nil) {
        guard isEnabled else { return }
        let deletedHabits = Set(HabitTombstones.ids(in: defaults)).union(remoteTombstones())
        var applied: [String] = []
        var pushed = false

        for spec in CloudSyncCatalog.specs where keys?.contains(spec.key) ?? true {
            let local = localEntry(for: spec)
            let remote = CloudSyncEnvelope.unpack(store.dictionary(forKey: CloudSyncCatalog.cloudKeyPrefix + spec.key), kind: spec.kind)
            let deleted = spec.policy == .habits ? deletedHabits : []

            switch CloudSyncMerge.resolve(policy: spec.policy, local: local, remote: remote, deletedIDs: deleted) {
            case .keep:
                break
            case .adoptRemote(let entry):
                writeLocal(entry, for: spec)
                applied.append(spec.key)
            case .pushLocal:
                if let local = local, push(local, for: spec) { pushed = true }
            case .merged(let entry):
                writeLocal(entry, for: spec)
                applied.append(spec.key)
                if push(entry, for: spec) { pushed = true }
            }
        }

        saveMeta()
        if pushed { store.synchronize() }
        lastSyncDate = Date()
        if !applied.isEmpty {
            NotificationCenter.default.post(name: .formaCloudSyncDidApply, object: nil, userInfo: ["keys": applied])
        }
    }

    private func remoteTombstones() -> [String] {
        guard let spec = CloudSyncCatalog.specs.first(where: { $0.key == CloudSyncCatalog.deletedHabitsKey }),
              let entry = CloudSyncEnvelope.unpack(store.dictionary(forKey: CloudSyncCatalog.cloudKeyPrefix + spec.key), kind: spec.kind),
              case .data(let data) = entry.value,
              let ids = (try? JSONSerialization.jsonObject(with: data)) as? [String] else { return [] }
        return ids
    }

    private func localEntry(for spec: CloudSyncSpec) -> CloudSyncEntry? {
        guard let value = readLocal(spec) else { return nil }
        let time = meta[spec.key]
        // Значение, которое пользователь не менял и которое пусто, не должно затирать облако
        if time == nil && CloudSyncMerge.isTrivial(value, spec: spec) { return nil }
        return CloudSyncEntry(value: value, modifiedAt: time ?? 0)
    }

    /// Отправляет значение в облако, если оно укладывается в лимиты. Возвращает true, если отправлено.
    private func push(_ entry: CloudSyncEntry, for spec: CloudSyncSpec) -> Bool {
        guard entry.value.byteCount <= CloudSyncCatalog.maxValueBytes else {
            print("☁️ iCloud: «\(spec.key)» слишком велик (\(entry.value.byteCount) байт), не отправляется")
            return false
        }
        let others = CloudSyncCatalog.specs.filter { $0.key != spec.key }.reduce(0) { total, other in
            let stored = CloudSyncEnvelope.unpack(store.dictionary(forKey: CloudSyncCatalog.cloudKeyPrefix + other.key), kind: other.kind)
            return total + (stored?.value.byteCount ?? 0)
        }
        guard others + entry.value.byteCount <= CloudSyncCatalog.maxTotalBytes else {
            print("☁️ iCloud: превышен общий лимит, «\(spec.key)» не отправляется")
            return false
        }
        store.set(CloudSyncEnvelope.pack(entry), forKey: CloudSyncCatalog.cloudKeyPrefix + spec.key)
        return true
    }

    // MARK: - Чтение и запись значений устройства

    private func readLocal(_ spec: CloudSyncSpec) -> CloudSyncValue? {
        if spec.key == CloudSyncCatalog.earnedXPKey {
            // Заработанный опыт = текущий + потраченный. Обычный опыт при покупке падает, заработанный — только растёт.
            guard defaults.object(forKey: GamificationStorage.xpKey) != nil || defaults.object(forKey: CloudSyncCatalog.spentXPKey) != nil else { return nil }
            return .int(defaults.integer(forKey: GamificationStorage.xpKey) + defaults.integer(forKey: CloudSyncCatalog.spentXPKey))
        }
        guard let raw = defaults.object(forKey: spec.key) else { return nil }
        switch spec.kind {
        case .int: return (raw as? NSNumber).map { .int($0.intValue) }
        case .double: return (raw as? NSNumber).map { .double($0.doubleValue) }
        case .bool: return (raw as? NSNumber).map { .bool($0.boolValue) }
        case .string: return (raw as? String).map { .string($0) }
        case .data: return (raw as? Data).map { .data($0) }
        }
    }

    private func writeLocal(_ entry: CloudSyncEntry, for spec: CloudSyncSpec) {
        if spec.key == CloudSyncCatalog.earnedXPKey {
            if case .int(let earned) = entry.value {
                let spent = defaults.integer(forKey: CloudSyncCatalog.spentXPKey)
                defaults.set(max(0, earned - spent), forKey: GamificationStorage.xpKey)
            }
        } else {
            switch entry.value {
            case .int(let value): defaults.set(value, forKey: spec.key)
            case .double(let value): defaults.set(value, forKey: spec.key)
            case .bool(let value): defaults.set(value, forKey: spec.key)
            case .string(let value): defaults.set(value, forKey: spec.key)
            case .data(let value): defaults.set(value, forKey: spec.key)
            }
        }
        meta[spec.key] = entry.modifiedAt
        // Запоминаем прочитанное после записи: следующее сканирование не примет её за правку пользователя
        lastKnown[spec.key] = readLocal(spec)
    }

    private func saveMeta() {
        defaults.set(meta, forKey: Self.metaKey)
    }
}

/// Ключи хранилища опыта, общие для менеджера опыта и синхронизации
enum GamificationStorage {
    static let xpKey = "forma_user_xp"
}
