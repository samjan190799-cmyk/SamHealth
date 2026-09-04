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
    
    // Флаг статуса PRO
    @AppStorage("forma_is_pro_user") public var isPro: Bool = false
    
    // Лимиты бесплатной версии
    public let maxFreeDailyScans: Int = 3
    public let maxFreeHabitsCount: Int = 3
    public let freeCoachIds: Set<String> = ["mark", "elena"]
    
    // Хранилище StoreKit продуктов
    @Published public var availableProducts: [Product] = []
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
        do {
            let productIds = FormaSubscriptionPlan.allCases.map { $0.rawValue }
            let products = try await Product.products(for: productIds)
            self.availableProducts = products
        } catch {
            print("StoreKit: Ошибка загрузки продуктов: \(error.localizedDescription)")
        }
    }
    
    // MARK: - StoreKit 2: Покупка подписки
    public func purchase(plan: FormaSubscriptionPlan) async -> Bool {
        guard let product = availableProducts.first(where: { $0.id == plan.rawValue }) else {
            // Если тестовый режим без App Store StoreKit файла — симулируем покупку для отладки
            #if DEBUG
            self.isPro = true
            return true
            #else
            self.purchaseErrorMessage = "Продукт временно недоступен в App Store."
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

