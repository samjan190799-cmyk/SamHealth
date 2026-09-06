import Foundation
import SwiftUI
import AppTrackingTransparency
import AdSupport
import Combine

// MARK: - Центральный менеджер рекламы Meta Audience Network & ATT
@MainActor
public final class MetaAdManager: ObservableObject {
    public static let shared = MetaAdManager()
    
    // Включение/отключение показа рекламы
    @AppStorage("meta_ads_enabled") public var isAdsEnabled: Bool = true
    
    // Placement ID из панели Meta Audience Network (Business Suite)
    // Формат в Meta: <PLACEMENT_ID> (например: 123456789012345_678901234567890)
    @AppStorage("meta_placement_id") public var placementId: String = ""
    
    // Тестовый режим (показ тестовых объявлений Meta)
    @AppStorage("meta_test_mode") public var isTestMode: Bool = true
    
    // Аналитика показов и кликов (Impressions & Clicks)
    @AppStorage("meta_total_impressions") public var totalImpressions: Int = 0
    @AppStorage("meta_total_clicks") public var totalClicks: Int = 0
    
    // Текущий статус разрешения App Tracking Transparency
    @Published public var trackingStatus: ATTrackingManager.AuthorizationStatus = .notDetermined
    
    private init() {
        self.trackingStatus = ATTrackingManager.trackingAuthorizationStatus
    }
    
    // MARK: - Запрос разрешения ATT (App Tracking Transparency)
    public func requestTrackingAuthorization() async -> ATTrackingManager.AuthorizationStatus {
        let status = await ATTrackingManager.requestTrackingAuthorization()
        self.trackingStatus = status
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
    
    // Проверка активности рекламных блоков Meta
    public var hasActivePlacement: Bool {
        isAdsEnabled && !placementId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Виджет нативного баннера Meta Audience Network
public struct MetaNativeBannerAdView: View {
    public let placementTitle: String
    
    @ObservedObject private var adManager = MetaAdManager.shared
    @State private var hasLoggedThisSession: Bool = false
    
    public init(placementTitle: String = "Рекомендация") {
        self.placementTitle = placementTitle
    }
    
    public var body: some View {
        Button(action: {
            adManager.logClick()
            // Открытие целевой ссылки рекламодателя (или тестовой страницы Meta)
            if let url = URL(string: "https://facebook.com") {
                UIApplication.shared.open(url)
            }
        }) {
            HStack(spacing: 12) {
                // Иконка спонсора / Meta
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 24/255, green: 119/255, blue: 242/255), Color(red: 0/255, green: 98/255, blue: 219/255)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "app.badge.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("РЕКЛАМА META")
                            .font(.system(size: 9, weight: .heavy))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .foregroundColor(Color.blue)
                            .clipShape(Capsule())
                        
                        if adManager.isTestMode {
                            Text("TEST")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(Color.orange)
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text("Спонсорский контент Meta Network")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                    
                    Text("Нажмите для перехода на страницу предложения рекламодателя")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 4)
                
                Image(systemName: "arrow.up.right.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color.blue)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.blue.opacity(0.25), lineWidth: 1)
                    )
            )
            .shadow(color: Color.blue.opacity(0.06), radius: 8, y: 3)
        }
        .buttonStyle(AppleDesignAwardsButtonStyle(scaleAmount: 0.98))
        .onAppear {
            if !hasLoggedThisSession {
                hasLoggedThisSession = true
                adManager.logImpression()
            }
        }
    }
}
