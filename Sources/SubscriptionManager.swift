import Foundation
import SwiftUI
import StoreKit

// MARK: - Идентификаторы продуктов подписки в App Store Connect
public enum FormaSubscriptionPlan: String, CaseIterable, Identifiable {
    case yearly = "com.samvel.forma.pro.yearly"
    case monthly = "com.samvel.forma.pro.monthly"
    case lifetime = "com.samvel.forma.pro.lifetime"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .yearly: return "Годовая (7 дней бесплатно)"
        case .monthly: return "Месячная"
        case .lifetime: return "Пожизненный доступ (PRO Навсегда)"
        }
    }
    
    public var badge: String? {
        switch self {
        case .yearly: return "СКИДКА 50% 🔥"
        case .lifetime: return "1 ПЛАТЕЖ 💎"
        case .monthly: return nil
        }
    }
    
    public var pricePlaceholder: String {
        switch self {
        case .yearly: return "2 990 ₽ / год (249 ₽/мес)"
        case .monthly: return "499 ₽ / месяц"
        case .lifetime: return "6 990 ₽ разово"
        }
    }
}

// MARK: - Центральный менеджер подписки и лимитов (Subscription & Quotas Manager)
@MainActor
public final class SubscriptionManager: ObservableObject {
    public static let shared = SubscriptionManager()
    
    // Флаг постоянного статуса PRO (оплата или мастер-ключ)
    @AppStorage("forma_is_pro_user") public var isPaidPro: Bool = false
    
    // Временный подарочный PRO-доступ за дисциплину (таймштамп истечения)
    @AppStorage("forma_pro_reward_expires_at") public var proRewardExpiresAt: Double = 0
    
    // Бонусные AI-сканирования за привычки
    @AppStorage("forma_bonus_ai_scans") public var bonusAIScans: Int = 0
    
    // Центральное свойство статуса PRO (учитывает и оплату, и активную награду)
    public var isPro: Bool {
        get {
            if isPaidPro { return true }
            if isProRewardActive { return true }
            return false
        }
        set {
            isPaidPro = newValue
        }
    }
    
    public var isProRewardActive: Bool {
        proRewardExpiresAt > Date().timeIntervalSince1970
    }
    
    public var rewardTimeRemainingString: String? {
        guard isProRewardActive else { return nil }
        let remainingSeconds = Int(proRewardExpiresAt - Date().timeIntervalSince1970)
        let hours = remainingSeconds / 3600
        let minutes = (remainingSeconds % 3600) / 60
        if hours > 24 {
            let days = hours / 24
            return "\(days) дн. \(hours % 24) ч"
        } else if hours > 0 {
            return "\(hours) ч \(minutes) мин"
        } else {
            return "\(max(1, minutes)) мин"
        }
    }
    
    public func grantTemporaryPro(hours: Int) {
        let currentExpiry = max(Date().timeIntervalSince1970, proRewardExpiresAt)
        proRewardExpiresAt = currentExpiry + Double(hours * 3600)
        objectWillChange.send()
        HapticManager.shared.notification(.success)
    }
    
    public func grantBonusAIScans(count: Int) {
        bonusAIScans += count
        objectWillChange.send()
        HapticManager.shared.notification(.success)
    }
    
    // Лимиты бесплатной версии
    public let maxFreeDailyScans: Int = 3
    public let maxFreeHabitsCount: Int = 3
    public let freeCoachIds: Set<String> = ["mark", "elena"]
    
    // Хранилище StoreKit продуктов
    @Published public var availableProducts: [Product] = []
    @Published public var isLoadingProducts: Bool = false
    @Published public var isPurchasing: Bool = false
    @Published public var purchaseErrorMessage: String? = nil
    
    // Дневной счетчик сканирований еды
    @AppStorage("daily_ai_scans_date") private var lastScanDateKey: String = ""
    @AppStorage("daily_ai_scans_count") private var scansCountToday: Int = 0
    
    private var updatesTask: Task<Void, Never>?
    
    private init() {
        resetDailyCountersIfNeeded()
        updatesTask = listenForTransactions()
        Task {
            await fetchStoreKitProducts()
            await checkCurrentEntitlements()
        }
    }
    
    deinit {
        updatesTask?.cancel()
    }
    
    // MARK: - Проверка и сброс дневного счетчика
    private var todayDateKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    public func resetDailyCountersIfNeeded() {
        if lastScanDateKey != todayDateKey {
            lastScanDateKey = todayDateKey
            scansCountToday = 0
        }
    }
    
    // MARK: - Лимиты на AI-Сканирование еды
    public var freeScansRemainingToday: Int {
        resetDailyCountersIfNeeded()
        if isPro { return 9999 }
        return max(0, maxFreeDailyScans - scansCountToday)
    }
    
    public func canPerformAIScan(hasCustomApiKey: Bool = false) -> Bool {
        if isPro || hasCustomApiKey { return true }
        resetDailyCountersIfNeeded()
        return scansCountToday < maxFreeDailyScans
    }
    
    public func consumeAIScan() {
        if !isPro {
            resetDailyCountersIfNeeded()
            scansCountToday += 1
        }
    }
    
    // MARK: - Лимиты на Привычки
    public func canCreateHabit(currentHabitsCount: Int) -> Bool {
        if isPro { return true }
        return currentHabitsCount < maxFreeHabitsCount
    }
    
    // MARK: - Доступ к ИИ-Тренерам
    public func isCoachAvailable(coachId: String) -> Bool {
        if isPro { return true }
        return freeCoachIds.contains(coachId.lowercased())
    }
    
    public func isCoachAvailable(coachId: AICoachID) -> Bool {
        if isPro { return true }
        return freeCoachIds.contains(coachId.rawValue.lowercased())
    }
    
    // MARK: - StoreKit 2: Загрузка продуктов
    public func fetchStoreKitProducts() async {
        isLoadingProducts = true
        do {
            let productIds = FormaSubscriptionPlan.allCases.map { $0.rawValue }
            let products = try await Product.products(for: productIds)
            self.availableProducts = products
            self.isLoadingProducts = false
        } catch {
            print("StoreKit: Ошибка загрузки продуктов: \(error.localizedDescription)")
            self.isLoadingProducts = false
        }
    }
    
    // MARK: - StoreKit 2: Покупка подписки
    public func purchase(plan: FormaSubscriptionPlan) async -> Bool {
        if availableProducts.isEmpty {
            await fetchStoreKitProducts()
        }
        
        guard let product = availableProducts.first(where: { $0.id == plan.rawValue }) else {
            // Если тестовый режим без App Store StoreKit файла — симулируем покупку для отладки
            #if DEBUG
            self.isPro = true
            return true
            #else
            self.purchaseErrorMessage = "Тариф временно недоступен. Проверьте интернет-соединение или повторите попытку."
            return false
            #endif
        }
        
        isPurchasing = true
        purchaseErrorMessage = nil
        
        do {
            let result = try await product.purchase()
            isPurchasing = false
            
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    self.isPro = true
                    HapticManager.shared.notification(.success)
                    return true
                case .unverified(_, let error):
                    self.purchaseErrorMessage = "Не удалось верифицировать транзакцию: \(error.localizedDescription)"
                    return false
                }
            case .userCancelled:
                return false
            case .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            isPurchasing = false
            self.purchaseErrorMessage = error.localizedDescription
            return false
        }
    }
    
    // MARK: - StoreKit 2: Восстановление покупок
    public func restorePurchases() async -> Bool {
        isPurchasing = true
        purchaseErrorMessage = nil
        do {
            try await AppStore.sync()
            await checkCurrentEntitlements()
            isPurchasing = false
            HapticManager.shared.notification(.success)
            return isPro
        } catch {
            isPurchasing = false
            self.purchaseErrorMessage = "Ошибка восстановления покупок: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Проверка активных прав (Entitlements)
    public func checkCurrentEntitlements() async {
        var hasActiveSubscription = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.revocationDate == nil {
                    hasActiveSubscription = true
                }
            }
        }
        let isDebugUnlocked = UserDefaults.standard.bool(forKey: "forma_debug_premium_unlocked") ||
                              KeychainHelper.shared.getBool(forKey: "forma_master_pro_unlocked")
        if isDebugUnlocked {
            hasActiveSubscription = true
            UserDefaults.standard.set(true, forKey: "forma_debug_premium_unlocked")
            KeychainHelper.shared.setBool(true, forKey: "forma_master_pro_unlocked")
        }
        self.isPro = hasActiveSubscription
    }
    
    // MARK: - Слушатель транзакций
    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await MainActor.run {
                        SubscriptionManager.shared.isPro = true
                    }
                }
            }
        }
    }
    
    // MARK: - Пасхалка / Developer Easter Egg Unlock
    public func setDebugPremium(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "forma_debug_premium_unlocked")
        KeychainHelper.shared.setBool(enabled, forKey: "forma_master_pro_unlocked")
        self.isPro = enabled
        HapticManager.shared.notification(.success)
    }
}

