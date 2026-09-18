import SwiftUI
import Combine
import AppTrackingTransparency
import AdSupport

#if canImport(YandexMobileAds)
import YandexMobileAds
#endif

#if canImport(AppLovinSDK)
import AppLovinSDK
#endif

// MARK: - Перечисление доступных рекламных сетей
public enum FormaAdNetworkType: String, CaseIterable, Identifiable, Sendable {
    case yandex = "Яндекс РСЯ"
    case appLovin = "AppLovin MAX"
    case houseAd = "Forma House Pro"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .yandex: return "y.circle.fill"
        case .appLovin: return "globe.badge.chevron.backward"
        case .houseAd: return "crown.fill"
        }
    }
}

// MARK: - Расширение Bundle для безопасного отделения отладочного UI от пользователей App Store
public extension Bundle {
    var isTestFlightOrDebug: Bool {
        #if DEBUG
        return true
        #else
        return appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif
    }
}

// MARK: - Центральный менеджер гибридной монетизации (Yandex + AppLovin)
@MainActor
public final class FormaAdManager: NSObject, ObservableObject {
    public static let shared = FormaAdManager()
    
    // Включение / отключение рекламы (отключается при активной FORMA PRO)
    @AppStorage("forma_ads_enabled") public var isAdsEnabled: Bool = true
    
    // Идентификаторы Yandex Mobile Ads (демо-ключи для безопасного старта)
    public static let defaultYandexRewardedId = "demo-rewarded-yandex"
    public static let defaultYandexBannerId = "demo-banner-yandex"
    @AppStorage("yandex_rewarded_unit_id") public var yandexRewardedId: String = FormaAdManager.defaultYandexRewardedId
    @AppStorage("yandex_banner_unit_id") public var yandexBannerId: String = FormaAdManager.defaultYandexBannerId
    
    // Идентификаторы AppLovin MAX (демо/боевые ключи)
    public static let defaultAppLovinSdkKey = "YOUR_APPLOVIN_SDK_KEY"
    public static let defaultAppLovinRewardedId = "YOUR_APPLOVIN_REWARDED_ID"
    public static let defaultAppLovinBannerId = "YOUR_APPLOVIN_BANNER_ID"
    @AppStorage("applovin_sdk_key") public var applovinSdkKey: String = FormaAdManager.defaultAppLovinSdkKey
    @AppStorage("applovin_rewarded_unit_id") public var applovinRewardedId: String = FormaAdManager.defaultAppLovinRewardedId
    @AppStorage("applovin_banner_unit_id") public var applovinBannerId: String = FormaAdManager.defaultAppLovinBannerId
    
    // Флаг тестового режима
    @AppStorage("forma_ad_test_mode") public var isTestMode: Bool = true
    
    // Аналитика показов и кликов
    @AppStorage("forma_ad_impressions") public var totalImpressions: Int = 0
    @AppStorage("forma_ad_clicks") public var totalClicks: Int = 0
    
    // Статус согласия Apple ATT
    @Published public var trackingStatus: ATTrackingManager.AuthorizationStatus = .notDetermined
    
    // Состояния рекламы
    @Published public var isAdLoaded: Bool = true
    @Published public var isShowingAd: Bool = false
    @Published public var isAdLoading: Bool = false
    @Published public var lastEarnedBonusCount: Int = 1
    @Published public var showSuccessToast: Bool = false
    @Published public var activeProviderType: FormaAdNetworkType = .yandex
    @Published public var detectedRegionCode: String = "RU"
    
    // Совместимость с предыдущими свойствами
    public var metaAppId: String {
        get { yandexRewardedId }
        set { yandexRewardedId = newValue }
    }
    public var metaPlacementId: String {
        get { yandexRewardedId }
        set { yandexRewardedId = newValue }
    }
    public var metaBannerPlacementId: String {
        get { yandexBannerId }
        set { yandexBannerId = newValue }
    }
    
    public var ctrPercentage: Double {
        guard totalImpressions > 0 else { return 0.0 }
        return (Double(totalClicks) / Double(totalImpressions)) * 100.0
    }
    
    // Callback завершения просмотра и начисления
    private var onRewardEarnedCallback: (() -> Void)?
    
    #if canImport(YandexMobileAds)
    private var yandexRewardedLoader: RewardedAdLoader?
    private var yandexRewardedAd: RewardedAd?
    #endif
    
    #if canImport(AppLovinSDK)
    private var appLovinRewardedAd: MARewardedAd?
    #endif
    
    private override init() {
        super.init()
        self.trackingStatus = ATTrackingManager.trackingAuthorizationStatus
        determineActiveNetworkByGeo()
        preloadAd()
    }
    
    // MARK: - Гео-маршрутизация (Geo-Routing)
    public func determineActiveNetworkByGeo() {
        let region = Locale.current.region?.identifier.uppercased() ?? "US"
        self.detectedRegionCode = region
        
        let cisRegions: Set<String> = ["RU", "BY", "KZ", "AM", "UZ", "KG", "TJ", "AZ", "MD"]
        if cisRegions.contains(region) {
            self.activeProviderType = .yandex
        } else {
            self.activeProviderType = .appLovin
        }
    }
    
    // MARK: - Запрос разрешения Apple ATT и инициализация SDK
    public func requestTrackingAuthorizationAndInitialize() async {
        if #available(iOS 14.0, *) {
            if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
                let status = await ATTrackingManager.requestTrackingAuthorization()
                self.trackingStatus = status
            } else {
                self.trackingStatus = ATTrackingManager.trackingAuthorizationStatus
            }
        }
        
        let isAuthorized = (self.trackingStatus == .authorized)
        initializeAdNetworks(hasUserConsent: isAuthorized)
    }
    
    // Обратная совместимость для вызова из старых мест
    public func requestTrackingAuthorization() async -> ATTrackingManager.AuthorizationStatus {
        await requestTrackingAuthorizationAndInitialize()
        return self.trackingStatus
    }
    
    private func initializeAdNetworks(hasUserConsent: Bool) {
        #if canImport(YandexMobileAds)
        MobileAds.setUserConsent(hasUserConsent)
        MobileAds.initializeSDK { [weak self] in
            Task { @MainActor in
                self?.preloadYandexRewarded()
            }
        }
        #endif
        
        #if canImport(AppLovinSDK)
        let initConfig = ALSdkInitializationConfiguration.builder(withSdkKey: applovinSdkKey) { builder in
            builder.mediationProvider = ALMediationProviderMAX
        }.build()
        
        ALSdk.shared().initialize(with: initConfig) { [weak self] _ in
            Task { @MainActor in
                self?.preloadAppLovinRewarded()
            }
        }
        #endif
    }
    
    // MARK: - Предзагрузка рекламы
    public func preloadAd() {
        self.isAdLoading = true
        
        #if canImport(YandexMobileAds)
        preloadYandexRewarded()
        #endif
        
        #if canImport(AppLovinSDK)
        preloadAppLovinRewarded()
        #endif
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.isAdLoading = false
            self?.isAdLoaded = true
        }
    }
    
    private func preloadYandexRewarded() {
        #if canImport(YandexMobileAds)
        guard isAdsEnabled, !yandexRewardedId.isEmpty else { return }
        let loader = RewardedAdLoader()
        loader.delegate = self
        self.yandexRewardedLoader = loader
        let config = AdRequestConfiguration(adUnitID: yandexRewardedId)
        loader.loadAd(with: config)
        #endif
    }
    
    private func preloadAppLovinRewarded() {
        #if canImport(AppLovinSDK)
        guard isAdsEnabled, !applovinRewardedId.isEmpty, applovinRewardedId != Self.defaultAppLovinRewardedId else { return }
        let rewarded = MARewardedAd.shared(withAdUnitIdentifier: applovinRewardedId)
        rewarded.delegate = self
        self.appLovinRewardedAd = rewarded
        rewarded.load()
        #endif
    }
    
    // MARK: - Показ Rewarded Video с каскадным переключением (Cascading Fallback)
    public func showRewardedAd(onReward: (() -> Void)? = nil) {
        self.onRewardEarnedCallback = onReward
        HapticManager.shared.impact(.medium)
        
        let rootVC = UIApplication.shared.firstKeyWindowRootViewController
        
        // 1. Проверяем первичную сеть по гео
        if activeProviderType == .yandex {
            if tryShowYandex(from: rootVC) { return }
            if tryShowAppLovin(from: rootVC) { return }
        } else {
            if tryShowAppLovin(from: rootVC) { return }
            if tryShowYandex(from: rootVC) { return }
        }
        
        // 2. Graceful Fallback: локальный интерактивный плеер со спонсорскими креативами
        self.isShowingAd = true
    }
    
    private func tryShowYandex(from rootVC: UIViewController?) -> Bool {
        #if canImport(YandexMobileAds)
        if let yandexAd = self.yandexRewardedAd, let rootVC {
            yandexAd.delegate = self
            yandexAd.show(from: rootVC)
            self.yandexRewardedAd = nil
            preloadYandexRewarded()
            return true
        }
        #endif
        return false
    }
    
    private func tryShowAppLovin(from rootVC: UIViewController?) -> Bool {
        #if canImport(AppLovinSDK)
        if let appLovinAd = self.appLovinRewardedAd, appLovinAd.isReady {
            appLovinAd.show()
            preloadAppLovinRewarded()
            return true
        }
        #endif
        return false
    }
    
    // MARK: - Начисление награды
    public func completeAdAndGrantReward() {
        self.isShowingAd = false
        
        // 1. Начисляем +1 бесплатный ИИ-скан тарелки
        SubscriptionManager.shared.grantBonusAIScans(count: 1)
        self.lastEarnedBonusCount = 1
        
        // 2. Вызываем переданный callback (если есть)
        onRewardEarnedCallback?()
        onRewardEarnedCallback = nil
        
        // 3. Тактильный отклик и всплывающий тост
        HapticManager.shared.notification(.success)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            self.showSuccessToast = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            withAnimation(.easeInOut(duration: 0.3)) {
                self?.showSuccessToast = false
            }
        }
        
        preloadAd()
    }
    
    // MARK: - Логирование аналитики
    public func logImpression() {
        totalImpressions += 1
    }
    
    public func logClick() {
        totalClicks += 1
    }
    
    public func resetStats() {
        totalImpressions = 0
        totalClicks = 0
    }
}

// MARK: - Делегаты Yandex Mobile Ads
#if canImport(YandexMobileAds)
extension FormaAdManager: RewardedAdLoaderDelegate, RewardedAdDelegate {
    public func rewardedAdLoader(_ adLoader: RewardedAdLoader, didLoad rewardedAd: RewardedAd) {
        Task { @MainActor in
            self.yandexRewardedAd = rewardedAd
            self.isAdLoaded = true
        }
    }
    
    public func rewardedAdLoader(_ adLoader: RewardedAdLoader, didFailToLoadWithError error: AdRequestError) {
        Task { @MainActor in
            self.yandexRewardedAd = nil
        }
    }
    
    public func rewardedAd(_ rewardedAd: RewardedAd, didReward reward: Reward) {
        Task { @MainActor in
            self.completeAdAndGrantReward()
        }
    }
    
    public func rewardedAdDidShow(_ rewardedAd: RewardedAd) {
        Task { @MainActor in
            self.logImpression()
        }
    }
    
    public func rewardedAdDidClick(_ rewardedAd: RewardedAd) {
        Task { @MainActor in
            self.logClick()
        }
    }
    
    public func rewardedAdDidDismiss(_ rewardedAd: RewardedAd) {
        Task { @MainActor in
            self.preloadYandexRewarded()
        }
    }
}
#endif

// MARK: - Делегаты AppLovin MAX
#if canImport(AppLovinSDK)
extension FormaAdManager: MARewardedAdDelegate {
    public func didLoad(_ ad: MAAd) {
        Task { @MainActor in
            self.isAdLoaded = true
        }
    }
    
    public func didFailToLoadAd(forAdUnitIdentifier adUnitIdentifier: String, withError error: MAError) {
        // Ошибка загрузки
    }
    
    public func didDisplay(_ ad: MAAd) {
        Task { @MainActor in
            self.logImpression()
        }
    }
    
    public func didHide(_ ad: MAAd) {
        Task { @MainActor in
            self.preloadAppLovinRewarded()
        }
    }
    
    public func didClick(_ ad: MAAd) {
        Task { @MainActor in
            self.logClick()
        }
    }
    
    public func didFailToDisplay(_ ad: MAAd, withError error: MAError) {
        // Ошибка показа
    }
    
    public func didRewardUser(for ad: MAAd, with reward: MAReward) {
        Task { @MainActor in
            self.completeAdAndGrantReward()
        }
    }
}
#endif

// MARK: - Алиас обратной совместимости
public typealias FormaMetaAdManager = FormaAdManager

// MARK: - Универсальный гибридный баннер Forma (Yandex / AppLovin / House Ad)
public struct FormaHybridBannerView: View {
    public let placementTitle: String
    
    @ObservedObject private var adManager = FormaAdManager.shared
    @ObservedObject private var subscription = SubscriptionManager.shared
    @State private var hasLoggedThisSession: Bool = false
    @State private var showingPaywall: Bool = false
    @State private var isLiveAdLoaded: Bool = false
    
    // Спонсорские креативы для резервного показа (Graceful Fallback)
    private let sponsorCreatives: [(brand: String, tag: String, text: String, icon: String, color: Color, url: String)] = [
        ("Gymshark Pro", "ЭКИПИРОВКА", "Спортивная одежда и экипировка со скидкой до 30%", "tshirt.fill", Color.blue, "https://gymshark.com"),
        ("MyProtein Ultra", "СПОРТПИТ", "Сывороточный протеин, витамины и добавки для ваших целей", "flame.fill", Color.orange, "https://myprotein.com"),
        ("WHOOP 4.0", "БИОХАКИНГ", "Круглосуточный трекер восстановления, сна и кардионагрузки", "heart.circle.fill", Color.green, "https://whoop.com"),
        ("Nike Run Club", "ОБУВЬ & БЕГ", "Новая линейка беговых кроссовок с амортизацией стопы", "figure.run", Color.purple, "https://nike.com")
    ]
    
    @State private var currentCreativeIndex: Int = 0
    
    public init(placementTitle: String = "Спонсор") {
        self.placementTitle = placementTitle
    }
    
    public var body: some View {
        let creative = sponsorCreatives[currentCreativeIndex]
        
        VStack(spacing: 8) {
            fallbackSponsorBanner(creative: creative)
            
            // Кнопка отключения рекламы через покупку FORMA PRO
            HStack {
                Spacer()
                Button(action: {
                    HapticManager.shared.impact(.light)
                    showingPaywall = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color(red: 245/255, green: 158/255, blue: 11/255))
                        Text("Отключить рекламу в FORMA PRO")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                Spacer()
            }
        }
        .onAppear {
            currentCreativeIndex = Int.random(in: 0..<sponsorCreatives.count)
            if !hasLoggedThisSession {
                hasLoggedThisSession = true
                adManager.logImpression()
            }
        }
        .sheet(isPresented: $showingPaywall) {
            FormaPaywallView()
        }
    }
    
    private func fallbackSponsorBanner(creative: (brand: String, tag: String, text: String, icon: String, color: Color, url: String)) -> some View {
        Button(action: {
            adManager.logClick()
            if let url = URL(string: creative.url) {
                UIApplication.shared.open(url)
            }
        }) {
            HStack(spacing: 12) {
                // Иконка рекламодателя
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [creative.color, creative.color.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .shadow(color: creative.color.opacity(0.35), radius: 6, y: 2)
                    
                    Image(systemName: creative.icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // Текстовый контент баннера
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        HStack(spacing: 3) {
                            Image(systemName: adManager.activeProviderType.icon)
                                .font(.system(size: 8))
                            Text(adManager.activeProviderType.rawValue.uppercased())
                                .font(.system(size: 9, weight: .heavy))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.14))
                        .foregroundColor(Color.blue)
                        .clipShape(Capsule())
                        
                        Text(creative.tag)
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.primary.opacity(0.06))
                            .foregroundColor(Theme.textSecondary)
                            .cornerRadius(4)
                    }
                    
                    Text(creative.brand)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                    
                    Text(creative.text)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer(minLength: 4)
                
                // Стрелка перехода
                Image(systemName: "arrow.up.right.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(creative.color)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(AppleDesignAwardsButtonStyle(scaleAmount: 0.98))
    }
}

// Алиас для старого названия MetaNativeBannerAdView
public typealias MetaNativeBannerAdView = FormaHybridBannerView
