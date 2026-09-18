import SwiftUI
import StoreKit

public struct FormaPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var subscription = SubscriptionManager.shared
    
    @State private var selectedPlan: FormaSubscriptionPlan = .yearly
    @State private var isAnimatingGlow: Bool = false
    @State private var showingMedicalSources: Bool = false
    @State private var showErrorAlert: Bool = false
    
    public init() { }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                backgroundGlow
                
                ScrollView {
                    VStack(spacing: 22) {
                        closeButton
                        headerSection
                        featuresSection
                        plansSection
                        ctaSection
                        legalSection
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingMedicalSources) {
                MedicalSourcesAndCitationsView()
            }
            .alert("Уведомление", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {
                    subscription.purchaseErrorMessage = nil
                }
            } message: {
                Text(subscription.purchaseErrorMessage ?? "Произошла ошибка при обработке запроса. Пожалуйста, повторите попытку позже.")
            }
            .onAppear {
                isAnimatingGlow = true
                Task {
                    await subscription.fetchStoreKitProducts()
                }
            }
        }
    }
    
    // MARK: - Подкомпоненты экрана
    private var backgroundGlow: some View {
        VStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Theme.flameOrange.opacity(0.35),
                            Color(red: 236/255, green: 72/255, blue: 153/255).opacity(0.18),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 220
                    )
                )
                .frame(width: 360, height: 360)
                .offset(y: -140)
                .scaleEffect(isAnimatingGlow ? 1.15 : 0.95)
                .animation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true), value: isAnimatingGlow)
            Spacer()
        }
        .ignoresSafeArea()
    }
    
    private var closeButton: some View {
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
    }
    
    private var headerSection: some View {
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
    }
    
    private var featuresSection: some View {
        VStack(spacing: 14) {
            ProFeatureRow(
                icon: "camera.viewfinder",
                color: Color(red: 16/255, green: 185/255, blue: 129/255),
                title: "Безлимитный 3D AI & LiDAR анализ еды",
                subtitle: "Мгновенное сканирование калорий, БЖУ, микроэлементов и скрытых сахаров"
            )
            ProFeatureRow(
                icon: "person.2.wave.2.fill",
                color: Color(red: 168/255, green: 85/255, blue: 247/255),
                title: "Все 6 персональных ИИ-тренеров",
                subtitle: "Доступ к Виктору, Елене, Софии, Сьюзи, Марку и спортивным психологам"
            )
            ProFeatureRow(
                icon: "chart.line.uptrend.xyaxis",
                color: Color(red: 245/255, green: 158/255, blue: 11/255),
                title: "Углубленная аналитика здоровья",
                subtitle: "Прогнозирование соматотипа, метаболический баланс и трекинг веса"
            )
            ProFeatureRow(
                icon: "applewatch.radiowaves.left.and.right",
                color: Color(red: 59/255, green: 130/255, blue: 246/255),
                title: "Полная интеграция с Apple Watch & iOS 18+",
                subtitle: "Эксклюзивные циферблаты, Live Activities и расширения для экрана"
            )
        }
        .padding(.horizontal, 20)
    }
    
    private var plansSection: some View {
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
                                .stroke(isSelected ? Theme.flameOrange : Color.primary.opacity(0.2), lineWidth: 2)
                                .frame(width: 22, height: 22)
                            if isSelected {
                                Circle()
                                    .fill(Theme.flameOrange)
                                    .frame(width: 12, height: 12)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(plan.title)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                                
                                if let badge = plan.badge {
                                    Text(badge)
                                        .font(.system(size: 9, weight: .heavy))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Theme.flameOrange.opacity(0.2))
                                        .foregroundColor(Theme.flameOrange)
                                        .clipShape(Capsule())
                                }
                            }
                            
                            // Цена
                            if let product = subscription.availableProducts.first(where: { $0.id == plan.rawValue }) {
                                Text(product.displayPrice)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(Theme.textSecondary)
                            } else {
                                Text(plan.pricePlaceholder)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .formaGlassCard(cornerRadius: 18, padding: 14, borderColor: isSelected ? Theme.flameOrange : nil)
                }
            }
            
            if subscription.isLoadingProducts {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(Theme.flameOrange)
                    Text("Синхронизация тарифов с App Store...")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(.vertical, 4)
            } else if subscription.availableProducts.isEmpty && !subscription.isPro {
                Button(action: {
                    Task {
                        await subscription.fetchStoreKitProducts()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("Обновить тарифы из App Store")
                    }
                    .font(.caption)
                    .foregroundColor(Theme.flameOrange)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var ctaSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                guard !subscription.isPurchasing && !subscription.isLoadingProducts else { return }
                Task {
                    let success = await subscription.purchase(plan: selectedPlan)
                    if success {
                        dismiss()
                    } else if subscription.purchaseErrorMessage != nil {
                        showErrorAlert = true
                    }
                }
            }) {
                HStack(spacing: 8) {
                    if subscription.isPurchasing || subscription.isLoadingProducts {
                        ProgressView()
                            .tint(.black)
                        Text(subscription.isPurchasing ? "Оформление покупки..." : "Синхронизация тарифов...")
                            .font(.system(size: 15, weight: .bold))
                    } else {
                        Image(systemName: "sparkles")
                        Text(selectedPlan == .yearly ? "Попробовать 7 дней бесплатно" : "Оформить подписку")
                            .font(.system(size: 16, weight: .bold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .foregroundColor(.black)
                .background(
                    LinearGradient(
                        colors: [Theme.flameOrange, Color(red: 255/255, green: 140/255, blue: 0/255)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(18)
                .shadow(color: Color(red: 168/255, green: 85/255, blue: 247/255).opacity(0.35), radius: 10, y: 4)
            }
            .buttonStyle(AppleDesignAwardsButtonStyle(scaleAmount: 0.96))
            .disabled(subscription.isPurchasing || subscription.isLoadingProducts)
            .padding(.horizontal, 20)
            
            // Восстановление покупок
            Button(action: {
                Task {
                    let restored = await subscription.restorePurchases()
                    if restored {
                        dismiss()
                    } else if subscription.purchaseErrorMessage != nil {
                        showErrorAlert = true
                    }
                }
            }) {
                Text("Восстановить покупки (Restore)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
            }
        }
    }
    
    private var legalSection: some View {
        VStack(spacing: 10) {
            // Информация о подписке (Guideline 3.1.2)
            VStack(spacing: 6) {
                Text("Информация о подписке:")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                
                Text("Оплата списывается с вашей учетной записи Apple ID после подтверждения покупки. Подписка продлевается автоматически, если автопродление не отключено как минимум за 24 часа до окончания текущего расчетного периода. Списание средств за продление происходит в течение 24 часов до завершения текущего периода. Вы можете управлять подпиской и отключить автопродление в любое время в настройках своей учетной записи App Store. Неиспользованная часть бесплатного пробного периода аннулируется при покупке подписки.")
                    .font(.system(size: 9.5))
                    .foregroundColor(Theme.textSecondary.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 16)
            }
            .padding(.top, 4)
            
            // Медицинский дисклеймер (Guideline 1.4.1)
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "cross.case.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.blue)
                Text("Медицинский дисклеймер: Forma не является медицинским изделием и не заменяет консультацию врача. Перед изменением рациона или началом тренировок проконсультируйтесь с квалифицированным специалистом.")
                    .font(.system(size: 9))
                    .foregroundColor(Theme.textSecondary.opacity(0.7))
                    .lineSpacing(1.5)
            }
            .padding(.horizontal, 20)
            
            // Ссылки EULA, Privacy, Citations
            VStack(spacing: 6) {
                HStack(spacing: 10) {
                    Link("Условия использования (EULA)", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    Text("•")
                    Link("Политика конфиденциальности", destination: URL(string: "https://samjan190799-cmyk.github.io/SamHealth/privacy.html")!)
                }
                .font(.system(size: 10))
                .foregroundColor(Theme.textSecondary.opacity(0.85))
                
                Button(action: {
                    showingMedicalSources = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "book.pages.fill")
                        Text("Научные источники и методология (Citations)")
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.accent)
                }
            }
            .padding(.bottom, 24)
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
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                
                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(12)
        .background(Theme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
