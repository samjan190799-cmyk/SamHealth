import SwiftUI
import Combine
import AppTrackingTransparency
import AdSupport
#if canImport(FBAudienceNetwork)
import FBAudienceNetwork
#endif

// MARK: - Центральный менеджер рекламы Meta Audience Network & ATT
@MainActor
public final class FormaMetaAdManager: ObservableObject {
    public static let shared = FormaMetaAdManager()
    
    // Включение/отключение показа рекламы
    @AppStorage("meta_ads_enabled") public var isAdsEnabled: Bool = true
    
    // Идентификаторы из Meta Monetization Manager (developers.facebook.com)
    public static let liveMetaAppId = "1593548892174613"
    public static let liveRewardedPlacementId = "1593548892174613_1593557975507038"
    public static let liveBannerPlacementId = "1593548892174613_1593557642173738"
    
    @AppStorage("meta_app_id") public var metaAppId: String = FormaMetaAdManager.liveMetaAppId
    @AppStorage("meta_placement_id") public var metaPlacementId: String = FormaMetaAdManager.liveRewardedPlacementId
    @AppStorage("meta_banner_placement_id") public var metaBannerPlacementId: String = FormaMetaAdManager.liveBannerPlacementId
    @AppStorage("meta_test_mode_enabled") public var isTestMode: Bool = false
    
    // Аналитика показов и кликов (Impressions & Clicks)
    @AppStorage("meta_total_impressions") public var totalImpressions: Int = 0
    @AppStorage("meta_total_clicks") public var totalClicks: Int = 0
    
    // Текущий статус разрешения App Tracking Transparency
    @Published public var trackingStatus: ATTrackingManager.AuthorizationStatus = .notDetermined
    
    // Состояния рекламы
    @Published public var isAdLoaded: Bool = true
    @Published public var isShowingAd: Bool = false
    @Published public var isAdLoading: Bool = false
    @Published public var lastEarnedBonusCount: Int = 0
    @Published public var showSuccessToast: Bool = false
    
    // Callback завершения просмотра и начисления
    private var onRewardEarnedCallback: (() -> Void)?
    
    #if canImport(FBAudienceNetwork)
    private var rewardedCoordinator: FormaMetaRewardedVideoCoordinator?
    #endif
    
    private init() {
        // Гарантируем замену старых плейсхолдеров на боевые боевые ключи
        if metaAppId.contains("YOUR_META") || metaAppId.isEmpty {
            metaAppId = Self.liveMetaAppId
        }
        if metaPlacementId.contains("YOUR_META") || metaPlacementId.contains("VID_HD") || metaPlacementId.isEmpty {
            metaPlacementId = Self.liveRewardedPlacementId
        }
        if metaBannerPlacementId.contains("YOUR_META") || metaBannerPlacementId.contains("IMG_16") || metaBannerPlacementId.isEmpty {
            metaBannerPlacementId = Self.liveBannerPlacementId
        }
        
        self.trackingStatus = ATTrackingManager.trackingAuthorizationStatus
        #if canImport(FBAudienceNetwork)
        FBAudienceNetworkAds.initialize(with: nil, completionHandler: nil)
        if isTestMode {
            FBAdSettings.addTestDevice(FBAdSettings.testDeviceHash())
        }
        self.rewardedCoordinator = FormaMetaRewardedVideoCoordinator(manager: self)
        #endif
        preloadAd()
    }
    
    /// Предварительная загрузка следующего рекламного ролика
    public func preloadAd() {
        self.isAdLoading = true
        #if canImport(FBAudienceNetwork)
        if !metaPlacementId.isEmpty && isAdsEnabled {
            rewardedCoordinator?.loadAd(placementID: metaPlacementId)
        }
        #endif
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.isAdLoading = false
            self?.isAdLoaded = true
        }
    }
    
    /// Показ видеоролика Meta за вознаграждение (+1 скан)
    public func showRewardedAd(onReward: (() -> Void)? = nil) {
        self.onRewardEarnedCallback = onReward
        HapticManager.shared.impact(.medium)
        
        #if canImport(FBAudienceNetwork)
        if let coordinator = self.rewardedCoordinator, coordinator.isAdValid {
            let rootVC = UIApplication.shared.firstKeyWindowRootViewController
            if coordinator.show(from: rootVC) {
                return
            }
        }
        #endif
        
        // Graceful Fallback: интерактивный плеер со спонсорскими креативами
        self.isShowingAd = true
    }
    
    /// Фиксация успешного полного просмотра ролика Meta
    public func completeAdAndGrantReward() {
        self.isShowingAd = false
        
        // 1. Начисляем +1 скан в бессрочную копилку
        SubscriptionManager.shared.grantBonusAIScans(count: 1)
        self.lastEarnedBonusCount = 1
        
        // 2. Тактильный отклик успеха
        HapticManager.shared.notification(.success)
        
        // 3. Показываем всплывающее уведомление
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            self.showSuccessToast = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            withAnimation {
                self?.showSuccessToast = false
            }
        }
        
        // 4. Вызываем внешний коллбэк
        self.onRewardEarnedCallback?()
        self.onRewardEarnedCallback = nil
        
        // 5. Загружаем следующий ролик в фоне
        preloadAd()
    }
    
    /// Закрытие рекламы без начисления (если пользователь закрыл до завершения)
    public func cancelAd() {
        self.isShowingAd = false
        self.onRewardEarnedCallback = nil
        HapticManager.shared.impact(.light)
        preloadAd()
    }
    
    // MARK: - Запрос разрешения ATT (App Tracking Transparency)
    public func requestTrackingAuthorization() async -> ATTrackingManager.AuthorizationStatus {
        let status = await ATTrackingManager.requestTrackingAuthorization()
        self.trackingStatus = status
        #if canImport(FBAudienceNetwork)
        FBAdSettings.setAdvertiserTrackingEnabled(status == .authorized)
        #endif
        return status
    }
    
    // Разрешено ли отслеживание пользователем
    public var isTrackingAuthorized: Bool {
        trackingStatus == .authorized
    }
    
    // IDFA устройства (доступен только при согласии пользователя)
    public var idfaString: String? {
        guard isTrackingAuthorized else { return nil }
        return ASIdentifierManager.shared().advertisingIdentifier.uuidString
    }
    
    // MARK: - Учет показов (Impressions) и переходов (Clicks)
    public func logImpression() {
        totalImpressions += 1
    }
    
    public func logClick() {
        totalClicks += 1
        HapticManager.shared.impact(.light)
    }
    
    public func resetStats() {
        totalImpressions = 0
        totalClicks = 0
        HapticManager.shared.notification(.warning)
    }
    
    // Вычисляемый CTR (процент кликабельности)
    public var ctrPercentage: Double {
        guard totalImpressions > 0 else { return 0.0 }
        return (Double(totalClicks) / Double(totalImpressions)) * 100.0
    }
}

// MARK: - Интерактивный плеер видеорекламы Meta Audience Network
public struct MetaAdVideoPlayerSheet: View {
    @ObservedObject var adManager = FormaMetaAdManager.shared
    
    @State private var timeRemaining: Int = 15
    @State private var canSkip: Bool = false
    @State private var isPlaying: Bool = true
    @State private var progress: Double = 0.0
    
    // Спонсорские креативы в стиле Meta/Instagram
    private let sponsorBrands = [
        ("GymShark Activewear", "Скидка 20% на новую спортивную коллекцию", "tshirt.fill", Color.blue),
        ("MyProtein Nutrition", "Изолят сывороточного протеина и витамины", "flame.fill", Color.orange),
        ("Whoop Fitness Band", "Умный трекер восстановления и сна", "heart.circle.fill", Color.green),
        ("Nike Run Club", "Новая пара беговых кроссовок с амортизацией", "figure.run", Color.purple)
    ]
    
    @State private var currentSponsorIndex: Int = 0
    
    public var body: some View {
        let sponsor = sponsorBrands[currentSponsorIndex]
        
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Фоновое динамическое видео/градиент
            LinearGradient(
                colors: [sponsor.3.opacity(0.35), Color.black, Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Верхний бар с таймером и логотипом Meta
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "globe")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                        Text("Реклама от Meta")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Capsule())
                    
                    Spacer()
                    
                    if canSkip {
                        Button(action: {
                            adManager.completeAdAndGrantReward()
                        }) {
                            HStack(spacing: 4) {
                                Text("Награда получена 🎁")
                                    .font(.system(size: 12, weight: .bold))
                                Image(systemName: "xmark.circle.fill")
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.8))
                            .clipShape(Capsule())
                        }
                    } else {
                        HStack(spacing: 4) {
                            Text("Награда через: \(timeRemaining)с")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                // Прогресс-бар просмотра
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: canSkip ? Color.green : Color.blue))
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                
                Spacer()
                
                // Центральная видео-карточка креатива Meta
                VStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 220)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(sponsor.3.opacity(0.4), lineWidth: 1)
                            )
                        
                        VStack(spacing: 12) {
                            Image(systemName: sponsor.2)
                                .font(.system(size: 56))
                                .foregroundColor(sponsor.3)
                                .scaleEffect(isPlaying ? 1.08 : 0.95)
                                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isPlaying)
                            
                            Text(sponsor.0)
                                .font(.title3.bold())
                                .foregroundColor(.white)
                            
                            Text(sponsor.1)
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.white.opacity(0.75))
                                .padding(.horizontal, 24)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer()
                
                // Нижняя панель действий и призыв Meta
                VStack(spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Forma • Бонус за рекламу")
                                .font(.caption.bold())
                                .foregroundColor(.white.opacity(0.5))
                            Text("+1 ИИ-анализ блюда в копилку")
                                .font(.headline.bold())
                                .foregroundColor(.white)
                        }
                        Spacer()
                        Text("🎁")
                            .font(.title)
                    }
                    .padding(.horizontal, 24)
                    
                    if canSkip {
                        Button(action: {
                            adManager.completeAdAndGrantReward()
                        }) {
                            Text("Забрать 1 анализ и продолжить")
                                .font(.headline.bold())
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.green)
                                .cornerRadius(16)
                                .shadow(color: Color.green.opacity(0.4), radius: 10, y: 3)
                        }
                        .padding(.horizontal, 20)
                    } else {
                        Button(action: {
                            adManager.cancelAd()
                        }) {
                            Text("Пропустить (награда не будет начислена)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .padding(.bottom, 6)
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            currentSponsorIndex = Int.random(in: 0..<sponsorBrands.count)
            startAdCountdown()
        }
    }
    
    private func startAdCountdown() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if timeRemaining > 1 {
                timeRemaining -= 1
                progress = Double(15 - timeRemaining) / 15.0
            } else {
                timer.invalidate()
                timeRemaining = 0
                progress = 1.0
                canSkip = true
                HapticManager.shared.notification(.success)
            }
        }
    }
}

// MARK: - Виджет-карточка накопления бонусов Meta в разделе Питание
public struct MetaRewardedScanCard: View {
    @ObservedObject var adManager = FormaMetaAdManager.shared
    @ObservedObject var subscription = SubscriptionManager.shared
    
    public init() {}
    
    public var body: some View {
        if !subscription.isPaidPro {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "play.rectangle.fill")
                            .foregroundColor(.blue)
                        Text("META ADS • БОНУСЫ")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.12))
                    .cornerRadius(8)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text("🎁 В копилке:")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        Text("\(subscription.bonusAIScans)")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundColor(Theme.exerciseColor)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.cardBackground)
                    .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Копите бесплатные ИИ-анализы еды")
                        .font(.subheadline.bold())
                        .foregroundColor(Theme.textPrimary)
                    Text("1 короткий ролик от Meta = +1 анализ тарелки в копилку. Сканы не сгорают в полночь и копятся без ограничений!")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Button(action: {
                    adManager.showRewardedAd()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.circle.fill")
                            .font(.headline)
                        Text("Смотреть ролик Meta (+1 скан)")
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color(red: 0/255, green: 135/255, blue: 255/255)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: Color.blue.opacity(0.25), radius: 6, y: 2)
                }
            }
            .padding(14)
            .background(Theme.cardBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.blue.opacity(0.18), lineWidth: 1)
            )
            .sheet(isPresented: $adManager.isShowingAd) {
                MetaAdVideoPlayerSheet()
            }
        }
    }
}

// MARK: - Вспомогательное расширение для корневого контроллера
extension UIApplication {
    public var firstKeyWindowRootViewController: UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}

#if canImport(FBAudienceNetwork)
// MARK: - Официальный координатор видеорекламы Meta за вознаграждение (FBRewardedVideoAd)
public final class FormaMetaRewardedVideoCoordinator: NSObject, FBRewardedVideoAdDelegate {
    public weak var manager: FormaMetaAdManager?
    private var rewardedVideoAd: FBRewardedVideoAd?
    
    public init(manager: FormaMetaAdManager) {
        self.manager = manager
        super.init()
    }
    
    public func loadAd(placementID: String) {
        guard !placementID.isEmpty else { return }
        let ad = FBRewardedVideoAd(placementID: placementID)
        ad.delegate = self
        self.rewardedVideoAd = ad
        ad.load()
    }
    
    public var isAdValid: Bool {
        rewardedVideoAd?.isAdValid == true
    }
    
    public func show(from rootVC: UIViewController?) -> Bool {
        guard let ad = rewardedVideoAd, ad.isAdValid else { return false }
        if let vc = rootVC {
            return ad.show(fromRootViewController: vc)
        }
        return false
    }
    
    // MARK: - FBRewardedVideoAdDelegate
    public func rewardedVideoAdDidLoad(_ rewardedVideoAd: FBRewardedVideoAd) {
        Task { @MainActor in
            self.manager?.isAdLoaded = true
            self.manager?.isAdLoading = false
        }
    }
    
    public func rewardedVideoAd(_ rewardedVideoAd: FBRewardedVideoAd, didFailWithError error: Error) {
        Task { @MainActor in
            self.manager?.isAdLoading = false
            print("Meta Audience Network Rewarded Ad didFailWithError: \(error.localizedDescription)")
        }
    }
    
    public func rewardedVideoAdVideoComplete(_ rewardedVideoAd: FBRewardedVideoAd) {
        Task { @MainActor in
            self.manager?.completeAdAndGrantReward()
        }
    }
    
    public func rewardedVideoAdDidClose(_ rewardedVideoAd: FBRewardedVideoAd) {
        Task { @MainActor in
            self.manager?.preloadAd()
        }
    }
    
    public func rewardedVideoAdDidClick(_ rewardedVideoAd: FBRewardedVideoAd) {
        Task { @MainActor in
            self.manager?.logClick()
        }
    }
    
    public func rewardedVideoAdWillLogImpression(_ rewardedVideoAd: FBRewardedVideoAd) {
        Task { @MainActor in
            self.manager?.logImpression()
        }
    }
}

// MARK: - Официальный баннер Meta Audience Network (FBAdView)
public struct MetaLiveAudienceBannerRepresentable: UIViewRepresentable {
    public let placementID: String
    public var onAdLoaded: (() -> Void)?
    public var onAdFailed: ((Error) -> Void)?
    
    public init(placementID: String, onAdLoaded: (() -> Void)? = nil, onAdFailed: ((Error) -> Void)? = nil) {
        self.placementID = placementID
        self.onAdLoaded = onAdLoaded
        self.onAdFailed = onAdFailed
    }
    
    public func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        
        let rootVC = UIApplication.shared.firstKeyWindowRootViewController
        let adView = FBAdView(
            placementID: placementID,
            adSize: kFBAdSizeHeight50Banner,
            rootViewController: rootVC
        )
        adView.delegate = context.coordinator
        adView.loadAd()
        
        adView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(adView)
        NSLayoutConstraint.activate([
            adView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            adView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            adView.widthAnchor.constraint(equalTo: container.widthAnchor),
            adView.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        context.coordinator.adView = adView
        return container
    }
    
    public func updateUIView(_ uiView: UIView, context: Context) {}
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(onLoaded: onAdLoaded, onFailed: onAdFailed)
    }
    
    public class Coordinator: NSObject, FBAdViewDelegate {
        var adView: FBAdView?
        var onLoaded: (() -> Void)?
        var onFailed: ((Error) -> Void)?
        
        init(onLoaded: (() -> Void)?, onFailed: ((Error) -> Void)?) {
            self.onLoaded = onLoaded
            self.onFailed = onFailed
        }
        
        public func adViewDidLoad(_ adView: FBAdView) {
            Task { @MainActor in
                self.onLoaded?()
                FormaMetaAdManager.shared.logImpression()
            }
        }
        
        public func adView(_ adView: FBAdView, didFailWithError error: Error) {
            Task { @MainActor in
                self.onFailed?(error)
            }
        }
        
        public func adViewDidClick(_ adView: FBAdView) {
            Task { @MainActor in
                FormaMetaAdManager.shared.logClick()
            }
        }
    }
}
#endif

// MARK: - Нативный баннер Meta Audience Network для бесплатных пользователей
public struct MetaNativeBannerAdView: View {
    public let placementTitle: String
    
    @ObservedObject private var adManager = FormaMetaAdManager.shared
    @ObservedObject private var subscription = SubscriptionManager.shared
    @State private var hasLoggedThisSession: Bool = false
    @State private var showingPaywall: Bool = false
    @State private var isLiveAdLoaded: Bool = false
    
    // Спонсорские креативы Meta Audience Network (для резерва и тестового режима)
    private let adCreatives: [(brand: String, tag: String, text: String, icon: String, color: Color, url: String)] = [
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
        let creative = adCreatives[currentCreativeIndex]
        
        VStack(spacing: 8) {
            #if canImport(FBAudienceNetwork)
            if !adManager.metaBannerPlacementId.isEmpty && !adManager.isTestMode {
                ZStack {
                    if !isLiveAdLoaded {
                        fallbackSponsorBanner(creative: creative)
                    }
                    MetaLiveAudienceBannerRepresentable(
                        placementID: adManager.metaBannerPlacementId,
                        onAdLoaded: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                isLiveAdLoaded = true
                            }
                        },
                        onAdFailed: { _ in
                            isLiveAdLoaded = false
                        }
                    )
                    .frame(height: 50)
                    .opacity(isLiveAdLoaded ? 1 : 0)
                }
            } else {
                fallbackSponsorBanner(creative: creative)
            }
            #else
            fallbackSponsorBanner(creative: creative)
            #endif
            
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
            currentCreativeIndex = Int.random(in: 0..<adCreatives.count)
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
                            Image(systemName: "globe")
                                .font(.system(size: 8))
                            Text("META ADS")
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
                            .background(creative.color.opacity(0.12))
                            .foregroundColor(creative.color)
                            .clipShape(Capsule())
                        
                        if adManager.isTestMode {
                            Text("TEST")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text(creative.brand)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                    
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
                            .stroke(creative.color.opacity(0.25), lineWidth: 1)
                    )
            )
            .shadow(color: creative.color.opacity(0.08), radius: 8, y: 3)
        }
        .buttonStyle(AppleDesignAwardsButtonStyle(scaleAmount: 0.98))
    }
}

