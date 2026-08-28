import SwiftUI
import StoreKit

public struct FormaPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var subscription = SubscriptionManager.shared
    
    @State private var selectedPlan: FormaSubscriptionPlan = .yearly
    @State private var isAnimatingGlow: Bool = false
    
    public init() { }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                // Декоративный фон с неоновым свечением
                VStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(red: 168/255, green: 85/255, blue: 247/255).opacity(0.35), Color.clear],
                                center: .center,
                                startRadius: 10,
                                endRadius: 200
                            )
                        )
                        .frame(width: 350, height: 350)
                        .offset(y: -140)
                        .scaleEffect(isAnimatingGlow ? 1.15 : 0.95)
                        .animation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true), value: isAnimatingGlow)
                    Spacer()
                }
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 22) {
                        
                        // Кнопка закрытия
                        HStack {
                            Spacer()
                            Button(action: {
                                dismiss()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 26))
                                    .foregroundColor(Theme.textSecondary.opacity(0.7))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        
                        // ШАПКА PAYWALL
                        VStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.yellow)
                                Text("FORMA PRO")
                                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                                    .foregroundColor(.yellow)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color.yellow.opacity(0.16))
                            .clipShape(Capsule())
                            
                            Text("Интеллект твоего тела\nбез ограничений")
                                .font(.system(size: 28, weight: .heavy, design: .rounded))
                                .multilineTextAlignment(.center)
                                .foregroundColor(Theme.textPrimary)
                                .lineSpacing(2)
                            
                            Text("Раскрой полный потенциал ИИ-тренеров, 3D LiDAR сканера питания и неограниченной дисциплины.")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                        }
                        
                        // СПИСОК ПРЕИМУЩЕСТВ PRO
                        VStack(spacing: 14) {
                            ProFeatureRow(
                                icon: "camera.viewfinder",
                                color: Color(red: 16/255, green: 185/255, blue: 129/255),
                                title: "Безлимитный AI & LiDAR 3D скан еды",
                                subtitle: "Мгновенный расчет КБЖУ, веса и объема порций без ограничений в день"
                            )
                            
                            ProFeatureRow(
                                icon: "person.3.sequence.fill",
                                color: Color(red: 0/255, green: 229/255, blue: 255/255),
                                title: "Все 6 ИИ-Тренеров и Голосовой разбор",
                                subtitle: "Доступ к премиум-коучам, голосовым советам и жесткой мотивации"
                            )
                            
                            ProFeatureRow(
                                icon: "sparkles",
                                color: Color(red: 168/255, green: 85/255, blue: 247/255),
                                title: "Безлимит привычек и SOS-Психолог",
                                subtitle: "Создавайте сколько угодно привычек с целями, календарем и защитой от срывов"
                            )
                            
                            ProFeatureRow(
                                icon: "chart.xyaxis.line",
                                color: .orange,
                                title: "Глубокая ИИ-аналитика здоровья",
                                subtitle: "Анализ вариабельности пульса (HRV), восстановления, сна и метаболизма"
                            )
                            
                            ProFeatureRow(
                                icon: "applewatch",
                                color: .pink,
                                title: "VIP виджеты и Apple Watch App",
                                subtitle: "Эксклюзивные циферблаты, Live Activities и расширения для экрана"
                            )
                        }
                        .padding(.horizontal, 20)
                        
                        // ВЫБОР ТАРИФНОГО ПЛАНА
                        VStack(spacing: 10) {
                            ForEach(FormaSubscriptionPlan.allCases) { plan in
                                let isSelected = selectedPlan == plan
                                Button(action: {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                        selectedPlan = plan
                                    }
                                    HapticManager.shared.selection()
                                }) {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .stroke(isSelected ? Color(red: 168/255, green: 85/255, blue: 247/255) : Color.primary.opacity(0.2), lineWidth: 2)
                                                .frame(width: 22, height: 22)
                                            if isSelected {
                                                Circle()
                                                    .fill(Color(red: 168/255, green: 85/255, blue: 247/255))
                                                    .frame(width: 12, height: 12)
                                            }
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 6) {
                                                Text(plan.title)
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(Theme.textPrimary)
                                                
                                                if let badge = plan.badge {
                                                    Text(badge)
                                                        .font(.system(size: 9, weight: .heavy))
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(Color.green.opacity(0.18))
                                                        .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                                                        .clipShape(Capsule())
                                                }
                                            }
                                            
                                            // Цена
                                            if let product = subscription.availableProducts.first(where: { $0.id == plan.rawValue }) {
                                                Text(product.displayPrice)
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundColor(Theme.textSecondary)
                                            } else {
                                                Text(plan.pricePlaceholder)
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundColor(Theme.textSecondary)
                                            }
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding(14)
                                    .background(isSelected ? Color(red: 168/255, green: 85/255, blue: 247/255).opacity(0.12) : Theme.cardBackground)
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(isSelected ? Color(red: 168/255, green: 85/255, blue: 247/255) : Color.primary.opacity(0.08), lineWidth: isSelected ? 2 : 1)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        if let err = subscription.purchaseErrorMessage {
                            Text(err)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        
                        // ГЛАВНАЯ КНОПКА ПОДПИСКИ (CTA)
                        Button(action: {
                            Task {
                                let success = await subscription.purchase(plan: selectedPlan)
                                if success {
                                    dismiss()
                                }
                            }
                        }) {
                            HStack(spacing: 8) {
                                if subscription.isPurchasing {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "sparkles")
                                    Text(selectedPlan == .yearly ? "Попробовать 7 дней бесплатно" : "Оформить подписку")
                                        .font(.system(size: 16, weight: .bold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .foregroundColor(.white)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 168/255, green: 85/255, blue: 247/255), Color(red: 236/255, green: 72/255, blue: 153/255)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(18)
                            .shadow(color: Color(red: 168/255, green: 85/255, blue: 247/255).opacity(0.35), radius: 10, y: 4)
                        }
                        .buttonStyle(AppleDesignAwardsButtonStyle(scaleAmount: 0.96))
                        .disabled(subscription.isPurchasing)
                        .padding(.horizontal, 20)
                        
                        // КНОПКА ВОССТАНОВЛЕНИЯ ПОКУПОК И ПРАВОВЫЕ ССЫЛКИ
                        VStack(spacing: 8) {
                            Button(action: {
                                Task {
                                    let restored = await subscription.restorePurchases()
                                    if restored {
                                        dismiss()
                                    }
                                }
                            }) {
                                Text("Восстановить покупки (Restore)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Theme.textSecondary)
                            }
                            
                            HStack(spacing: 12) {
                                Link("Условия использования (EULA)", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                                Text("•")
                                Link("Политика конфиденциальности", destination: URL(string: "https://samjan190799-cmyk.github.io/privacy.html") ?? URL(string: "https://apple.com")!)
                            }
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textSecondary.opacity(0.7))
                        }
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                isAnimatingGlow = true
            }
        }
    }
}

// Вспомогательная строка фичи PRO
struct ProFeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.16))
                    .frame(width: 42, height: 42)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
    }
}
