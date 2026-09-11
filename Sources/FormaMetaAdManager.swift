import SwiftUI
import Combine

// MARK: - Менеджер видеорекламы Meta Audience Network (Rewarded Video)
@MainActor
public final class FormaMetaAdManager: ObservableObject {
    public static let shared = FormaMetaAdManager()
    
    // Идентификаторы из Meta Monetization Manager (developers.facebook.com)
    @AppStorage("meta_app_id") public var metaAppId: String = "YOUR_META_APP_ID"
    @AppStorage("meta_placement_id") public var metaPlacementId: String = "VID_HD_16_9_46S_APP_INSTALL#YOUR_META_PLACEMENT_ID"
    @AppStorage("meta_test_mode_enabled") public var isTestMode: Bool = true
    
    // Состояния рекламы
    @Published public var isAdLoaded: Bool = true
    @Published public var isShowingAd: Bool = false
    @Published public var isAdLoading: Bool = false
    @Published public var lastEarnedBonusCount: Int = 0
    @Published public var showSuccessToast: Bool = false
    
    // Callback завершения просмотра и начисления
    private var onRewardEarnedCallback: (() -> Void)?
    
    private init() {
        preloadAd()
    }
    
    /// Предварительная загрузка следующего рекламного ролика
    public func preloadAd() {
        self.isAdLoading = true
        // Имитируем фоновый прекэшинг видеоряда Meta Audience Network
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.isAdLoading = false
            self?.isAdLoaded = true
        }
    }
    
    /// Показ видеоролика Meta за вознаграждение (+1 скан)
    public func showRewardedAd(onReward: (() -> Void)? = nil) {
        self.onRewardEarnedCallback = onReward
        HapticManager.shared.impact(.medium)
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
