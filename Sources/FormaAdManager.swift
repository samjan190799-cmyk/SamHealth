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

// MARK: - Расширение UIApplication для показа объявлений из верхнего UIViewController
public extension UIApplication {
    var firstKeyWindowRootViewController: UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}

// MARK: - Центральный менеджер гибридной монетизации (Yandex + AppLovin)
@MainActor
public final class FormaAdManager: NSObject, ObservableObject {
    public static let shared = FormaAdManager()
    
    // Включение / отключение рекламы (отключается при активной FORMA PRO)
    @AppStorage("forma_ads_enabled") public var isAdsEnabled: Bool = true
    
    // Идентификаторы Yandex Mobile Ads (боевые блоки РСЯ)
    public static let defaultYandexRewardedId = "R-M-20070273-2"
    public static let defaultYandexBannerId = "R-M-20070273-1"
    @AppStorage("yandex_rewarded_unit_id") public var yandexRewardedId: String = FormaAdManager.defaultYandexRewardedId
    @AppStorage("yandex_banner_unit_id") public var yandexBannerId: String = FormaAdManager.defaultYandexBannerId
    
    // Индивидуальные блоки РСЯ для разделов (для максимальной заполняемости и раздельной статистики)
    @AppStorage("yandex_banner_workouts_id") public var yandexBannerWorkoutsId: String = "R-M-20070273-1"
    @AppStorage("yandex_banner_nutrition_id") public var yandexBannerNutritionId: String = "R-M-20070273-3"
    @AppStorage("yandex_banner_dashboard_id") public var yandexBannerDashboardId: String = "R-M-20070273-4"
    @AppStorage("yandex_banner_habits_id") public var yandexBannerHabitsId: String = "R-M-20070273-5"
    
    public func bannerId(for placement: FormaBannerPlacement) -> String {
        switch placement {
        case .workouts:
            return !yandexBannerWorkoutsId.isEmpty ? yandexBannerWorkoutsId : yandexBannerId
        case .nutrition:
            return !yandexBannerNutritionId.isEmpty ? yandexBannerNutritionId : yandexBannerId
        case .dashboard:
            return !yandexBannerDashboardId.isEmpty ? yandexBannerDashboardId : yandexBannerId
        case .habits:
            return !yandexBannerHabitsId.isEmpty ? yandexBannerHabitsId : yandexBannerId
        }
    }
    
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
    private var currentlyShowingYandexRewardedAd: RewardedAd?
    #endif
    
    #if canImport(AppLovinSDK)
    private var appLovinRewardedAd: MARewardedAd?
    #endif
    
    private override init() {
        super.init()
        if yandexRewardedId == "demo-rewarded-yandex" || yandexRewardedId.isEmpty {
            yandexRewardedId = FormaAdManager.defaultYandexRewardedId
        }
        if yandexBannerId == "demo-banner-yandex" || yandexBannerId.isEmpty {
            yandexBannerId = FormaAdManager.defaultYandexBannerId
        }
        if yandexBannerNutritionId.isEmpty {
            yandexBannerNutritionId = "R-M-20070273-3"
        }
        if yandexBannerDashboardId.isEmpty {
            yandexBannerDashboardId = "R-M-20070273-4"
        }
        if yandexBannerWorkoutsId.isEmpty {
            yandexBannerWorkoutsId = "R-M-20070273-1"
        }
        if yandexBannerHabitsId.isEmpty {
            yandexBannerHabitsId = "R-M-20070273-5"
        }
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
        Task {
            await YandexAds.initializeSDK()
            await MainActor.run {
                self.preloadYandexRewarded()
            }
        }
        #endif
        
        #if canImport(AppLovinSDK)
        let initConfig = ALSdkInitializationConfiguration(sdkKey: applovinSdkKey) { builder in
            builder.mediationProvider = ALMediationProviderMAX
        }
        
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
        self.yandexRewardedLoader = loader
        let request = AdRequest(adUnitID: yandexRewardedId)
        Task {
            do {
                let ad = try await loader.loadAd(with: request)
                self.yandexRewardedAd = ad
                ad.delegate = self
                self.isAdLoaded = true
            } catch {
                self.isAdLoaded = false
            }
        }
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
            self.currentlyShowingYandexRewardedAd = yandexAd
            self.yandexRewardedAd = nil
            yandexAd.show(from: rootVC)
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
    
    public func cancelAd() {
        self.isShowingAd = false
        self.onRewardEarnedCallback = nil
    }
    
    public func resetStats() {
        totalImpressions = 0
        totalClicks = 0
    }
}

// MARK: - Делегаты Yandex Mobile Ads
#if canImport(YandexMobileAds)
extension FormaAdManager: RewardedAdDelegate {
    nonisolated public func rewardedAd(_ rewardedAd: RewardedAd, didReward reward: Reward) {
        Task { @MainActor in
            FormaAdManager.shared.completeAdAndGrantReward()
        }
    }
    
    nonisolated public func rewardedAdDidShow(_ rewardedAd: RewardedAd) {
        Task { @MainActor in
            FormaAdManager.shared.logImpression()
        }
    }
    
    nonisolated public func rewardedAd(_ rewardedAd: RewardedAd, didTrackImpression impressionData: (any ImpressionData)?) {
        Task { @MainActor in
            FormaAdManager.shared.logImpression()
        }
    }
    
    nonisolated public func rewardedAdDidClick(_ rewardedAd: RewardedAd) {
        Task { @MainActor in
            FormaAdManager.shared.logClick()
        }
    }
    
    nonisolated public func rewardedAdDidDismiss(_ rewardedAd: RewardedAd) {
        Task { @MainActor in
            FormaAdManager.shared.currentlyShowingYandexRewardedAd = nil
            FormaAdManager.shared.isShowingAd = false
            FormaAdManager.shared.preloadYandexRewarded()
        }
    }
    
    nonisolated public func rewardedAd(_ rewardedAd: RewardedAd, didFailToShow error: any Error) {
        Task { @MainActor in
            FormaAdManager.shared.currentlyShowingYandexRewardedAd = nil
            FormaAdManager.shared.isShowingAd = false
        }
    }
}
#endif

// MARK: - Делегаты AppLovin MAX
#if canImport(AppLovinSDK)
extension FormaAdManager: MARewardedAdDelegate {
    nonisolated public func didLoad(_ ad: MAAd) {
        Task { @MainActor in
            FormaAdManager.shared.isAdLoaded = true
        }
    }
    
    nonisolated public func didFailToLoadAd(forAdUnitIdentifier adUnitIdentifier: String, withError error: MAError) {
        Task { @MainActor in
            FormaAdManager.shared.isAdLoaded = false
        }
    }
    
    nonisolated public func didDisplay(_ ad: MAAd) {
        Task { @MainActor in
            FormaAdManager.shared.logImpression()
        }
    }
    
    nonisolated public func didHide(_ ad: MAAd) {
        Task { @MainActor in
            FormaAdManager.shared.isShowingAd = false
            FormaAdManager.shared.preloadAppLovinRewarded()
        }
    }
    
    nonisolated public func didClick(_ ad: MAAd) {
        Task { @MainActor in
            FormaAdManager.shared.logClick()
        }
    }
    
    nonisolated public func didFail(toDisplay ad: MAAd, withError error: MAError) {
        Task { @MainActor in
            FormaAdManager.shared.isShowingAd = false
        }
    }
    
    nonisolated public func didRewardUser(for ad: MAAd, with reward: MAReward) {
        Task { @MainActor in
            FormaAdManager.shared.completeAdAndGrantReward()
        }
    }
}
#endif

// MARK: - Алиас обратной совместимости
public typealias FormaMetaAdManager = FormaAdManager

// MARK: - Нативный контейнер баннера Яндекс Mobile Ads (UIViewRepresentable)
#if canImport(YandexMobileAds)
public struct YandexBannerContainerView: UIViewRepresentable {
    public let adUnitID: String
    public var isVisible: Bool
    public var onAdLoaded: ((CGFloat) -> Void)?
    public var onAdFailed: ((any Error) -> Void)?
    
    public init(adUnitID: String, isVisible: Bool = true, onAdLoaded: ((CGFloat) -> Void)? = nil, onAdFailed: ((any Error) -> Void)? = nil) {
        self.adUnitID = adUnitID
        self.isVisible = isVisible
        self.onAdLoaded = onAdLoaded
        self.onAdFailed = onAdFailed
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        
        let screenWidth = max(320, UIScreen.main.bounds.width - 32)
        let adSize = BannerAdSize.sticky(containerWidth: screenWidth)
        let bannerView = BannerAdView(adSize: adSize)
        bannerView.delegate = context.coordinator
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        bannerView.layer.cornerRadius = 16
        bannerView.clipsToBounds = true
        
        container.addSubview(bannerView)
        NSLayoutConstraint.activate([
            bannerView.topAnchor.constraint(equalTo: container.topAnchor),
            bannerView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            bannerView.centerXAnchor.constraint(equalTo: container.centerXAnchor)
        ])
        
        context.coordinator.bannerView = bannerView
        
        if isVisible {
            context.coordinator.loadBanner(adUnitID: adUnitID)
        }
        
        return container
    }
    
    public func updateUIView(_ uiView: UIView, context: Context) {
        if isVisible && !context.coordinator.isLoaded {
            if Date().timeIntervalSince(context.coordinator.lastAttemptDate) > 20 {
                context.coordinator.loadBanner(adUnitID: adUnitID)
            }
        }
    }
    
    public final class Coordinator: NSObject, BannerAdViewDelegate {
        let parent: YandexBannerContainerView
        var bannerView: BannerAdView?
        var isLoaded: Bool = false
        var lastAttemptDate: Date = .distantPast
        
        init(_ parent: YandexBannerContainerView) {
            self.parent = parent
        }
        
        func loadBanner(adUnitID: String) {
            guard let bannerView, !adUnitID.isEmpty else { return }
            lastAttemptDate = Date()
            let request = AdRequest(adUnitID: adUnitID)
            bannerView.loadAd(with: request)
        }
        
        nonisolated public func bannerAdViewDidLoad(_ bannerAdView: BannerAdView) {
            Task { @MainActor in
                self.isLoaded = true
                let height = bannerAdView.intrinsicContentSize.height
                self.parent.onAdLoaded?(height > 0 ? height : 60)
                FormaAdManager.shared.logImpression()
            }
        }
        
        nonisolated public func bannerAdViewDidFailLoading(_ bannerAdView: BannerAdView, error: any Error) {
            Task { @MainActor in
                self.isLoaded = false
                self.parent.onAdFailed?(error)
            }
        }
        
        nonisolated public func bannerAdViewDidClick(_ bannerAdView: BannerAdView) {
            Task { @MainActor in
                FormaAdManager.shared.logClick()
            }
        }
        
        nonisolated public func bannerAdView(_ bannerAdView: BannerAdView, didTrackImpression impressionData: (any ImpressionData)?) {
            Task { @MainActor in
                FormaAdManager.shared.logImpression()
            }
        }
    }
}
#endif

// MARK: - Универсальный гибридный баннер Forma (Yandex / AppLovin / House Ad)
public struct FormaHybridBannerView: View {
    public let placement: FormaBannerPlacement
    public var placementTitle: String { placement.badge }
    
    @ObservedObject private var adManager = FormaAdManager.shared
    @ObservedObject private var subscription = SubscriptionManager.shared
    @State private var hasLoggedThisSession: Bool = false
    @State private var showingPaywall: Bool = false
    @State private var isLiveAdLoaded: Bool = false
    @State private var liveBannerHeight: CGFloat = 60
    @State private var isVisibleOnScreen: Bool = false
    
    // Спонсорские креативы для резервного показа (Graceful Fallback)
    private let sponsorCreatives: [(brand: String, tag: String, text: String, icon: String, color: Color, url: String)] = [
        ("Gymshark Pro", "ЭКИПИРОВКА", "Спортивная одежда и экипировка со скидкой до 30%", "tshirt.fill", Color.blue, "https://gymshark.com"),
        ("MyProtein Ultra", "СПОРТПИТ", "Сывороточный протеин, витамины и добавки для ваших целей", "flame.fill", Color.orange, "https://myprotein.com"),
        ("WHOOP 4.0", "БИОХАКИНГ", "Круглосуточный трекер восстановления, сна и кардионагрузки", "heart.circle.fill", Color.green, "https://whoop.com"),
        ("Nike Run Club", "ОБУВЬ & БЕГ", "Новая линейка беговых кроссовок с амортизацией стопы", "figure.run", Color.purple, "https://nike.com")
    ]
    
    @State private var currentCreativeIndex: Int = 0
    
    public init(placement: FormaBannerPlacement = .workouts) {
        self.placement = placement
    }
    
    public init(placementTitle: String) {
        self.placement = .workouts
    }
    
    public var body: some View {
        if !subscription.isPaidPro && adManager.isAdsEnabled {
            let creative = sponsorCreatives[currentCreativeIndex]
            let adUnitId = adManager.bannerId(for: placement)
            
            VStack(spacing: 8) {
                #if canImport(YandexMobileAds)
                if adManager.activeProviderType == .yandex && !adUnitId.isEmpty {
                    YandexBannerContainerView(
                        adUnitID: adUnitId,
                        isVisible: isVisibleOnScreen,
                        onAdLoaded: { height in
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                liveBannerHeight = height
                                isLiveAdLoaded = true
                            }
                        },
                        onAdFailed: { _ in
                            withAnimation {
                                isLiveAdLoaded = false
                            }
                        }
                    )
                    .frame(height: isLiveAdLoaded ? liveBannerHeight : 0)
                    .opacity(isLiveAdLoaded ? 1 : 0)
                }
                #endif
                
                // Если живой баннер еще загружается или в сети No-Fill — показываем резервный спонсорский баннер
                if !isLiveAdLoaded {
                    fallbackSponsorBanner(creative: creative)
                }
                
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
                isVisibleOnScreen = true
                currentCreativeIndex = Int.random(in: 0..<sponsorCreatives.count)
                if !hasLoggedThisSession {
                    hasLoggedThisSession = true
                    adManager.logImpression()
                }
            }
            .onDisappear {
                isVisibleOnScreen = false
            }
            .sheet(isPresented: $showingPaywall) {
                FormaPaywallView()
            }
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

// MARK: - Карточка накопления бесплатных ИИ-сканов от рекламы
public struct FormaRewardedScanCard: View {
    @ObservedObject var adManager = FormaAdManager.shared
    @ObservedObject var subscription = SubscriptionManager.shared
    
    public init() {}
    
    public var body: some View {
        if !subscription.isPaidPro {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "gift.fill")
                            .foregroundColor(Theme.flameOrange)
                        Text("БОНУСЫ ЗА РЕКЛАМУ")
                            .formaMetricLabel()
                            .foregroundColor(Theme.flameOrange)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.flameOrange.opacity(0.12))
                    .cornerRadius(8)
                    
                    Spacer()
                    
                    HStack(spacing: 5) {
                        Text("🎁 В копилке:")
                            .font(.caption.weight(.medium))
                            .foregroundColor(Theme.textSecondary)
                        Text("\(subscription.bonusAIScans)")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundColor(Theme.flameOrange)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Копите бесплатные ИИ-анализы еды")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                    Text("1 короткий ролик = +1 скан в копилку. Сканы не сгорают в полночь и копятся без ограничений!")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                if adManager.showSuccessToast {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(Theme.cyberLime)
                        Text("+1 анализ успешно добавлен в копилку! 🎉")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Theme.cyberLime.opacity(0.18))
                    .cornerRadius(10)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                
                Button(action: {
                    adManager.showRewardedAd()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.circle.fill")
                            .font(.headline)
                        Text("Смотреть ролик (+1 скан)")
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Theme.cyberLime, Color(red: 180/255, green: 240/255, blue: 0/255)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(14)
                    .shadow(color: Theme.cyberLime.opacity(0.3), radius: 8, y: 3)
                }
                .buttonStyle(AppleDesignAwardsButtonStyle(scaleAmount: 0.97, hapticStyle: .medium))
            }
            .formaGlassCard(cornerRadius: 22, padding: 16, borderColor: Theme.flameOrange)
            .sheet(isPresented: $adManager.isShowingAd) {
                FormaAdVideoPlayerSheet()
            }
        }
    }
}

public typealias MetaRewardedScanCard = FormaRewardedScanCard

// MARK: - Интерактивный резервный плеер со спонсорскими креативами
public struct FormaAdVideoPlayerSheet: View {
    @ObservedObject var adManager = FormaAdManager.shared
    @State private var timeRemaining: Int = 15
    @State private var progress: Double = 0.0
    @State private var canSkip: Bool = false
    
    private let sponsorBrands: [(String, String, Color, String)] = [
        ("Gymshark Performance", "Премиальная экипировка для фитнеса и силовых тренировок со скидкой 20% по промокоду FORMA.", Color.blue, "tshirt.fill"),
        ("MyProtein Impact Whey", "Европейское спортивное питание №1. Изолят протеина, креатин и витамины для максимального прогресса.", Color.orange, "flame.fill"),
        ("WHOOP Recovery 4.0", "Интеллектуальный браслет для анализа фаз глубокого сна, вариабельности сердечного ритма (HRV) и уровня стресса.", Color.green, "heart.fill"),
        ("Nike Invincible 3", "Максимальная амортизация ZoomX для защиты суставов во время бега и длинных пеших прогулок.", Color.purple, "figure.run")
    ]
    
    @State private var currentSponsorIndex: Int = 0
    
    public init() {}
    
    public var body: some View {
        let sponsor = sponsorBrands[currentSponsorIndex]
        
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 24) {
                // Верхний бар с таймером и прогресс-баром
                VStack(spacing: 8) {
                    HStack {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("Спонсорский показ")
                                .font(.caption.bold())
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Spacer()
                        
                        Text(canSkip ? "Готово! 🎉" : "Награда через: \(timeRemaining) сек")
                            .font(.caption.bold())
                            .foregroundColor(canSkip ? Theme.cyberLime : .white.opacity(0.7))
                        
                        Button(action: {
                            if canSkip {
                                adManager.completeAdAndGrantReward()
                            } else {
                                adManager.cancelAd()
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(canSkip ? .white : .white.opacity(0.35))
                        }
                        .padding(.leading, 6)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                    ProgressView(value: progress, total: 1.0)
                        .tint(canSkip ? Theme.cyberLime : Color.blue)
                        .padding(.horizontal, 20)
                }
                
                Spacer()
                
                // Центр: брендированная витрина
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(sponsor.2.opacity(0.15))
                            .frame(width: 140, height: 140)
                        
                        Circle()
                            .stroke(sponsor.2.opacity(0.4), lineWidth: 2)
                            .frame(width: 110, height: 110)
                        
                        Image(systemName: sponsor.3)
                            .font(.system(size: 54, weight: .bold))
                            .foregroundColor(sponsor.2)
                    }
                    
                    VStack(spacing: 8) {
                        Text(sponsor.0)
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        
                        Text(sponsor.1)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white.opacity(0.75))
                            .padding(.horizontal, 24)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Нижняя кнопка завершения
                VStack(spacing: 14) {
                    if canSkip {
                        Button(action: {
                            adManager.completeAdAndGrantReward()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.headline)
                                Text("Забрать +1 анализ тарелки")
                                    .font(.headline.bold())
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Theme.cyberLime)
                            .cornerRadius(18)
                            .shadow(color: Theme.cyberLime.opacity(0.4), radius: 12, y: 3)
                        }
                        .buttonStyle(AppleDesignAwardsButtonStyle(scaleAmount: 0.96, hapticStyle: .medium))
                        .padding(.horizontal, 20)
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        Button(action: {
                            adManager.cancelAd()
                        }) {
                            Text("Закрыть (награда не будет начислена)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .padding(.bottom, 6)
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .interactiveDismissDisabled(!canSkip)
        .onAppear {
            currentSponsorIndex = Int.random(in: 0..<sponsorBrands.count)
            startCountdown()
        }
    }
    
    private func startCountdown() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if timeRemaining > 1 {
                timeRemaining -= 1
                progress = Double(15 - timeRemaining) / 15.0
            } else {
                timer.invalidate()
                timeRemaining = 0
                progress = 1.0
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    canSkip = true
                }
                HapticManager.shared.notification(.success)
                
                // Автоматически начисляем и закрываем через 4 секунды, если пользователь не нажал кнопку сам
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    if self.adManager.isShowingAd {
                        self.adManager.completeAdAndGrantReward()
                    }
                }
            }
        }
    }
}
