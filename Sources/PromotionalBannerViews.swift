import SwiftUI

// MARK: - Места размещения промо-баннеров (Placements)
public enum FormaBannerPlacement: String, Sendable, CaseIterable {
    case dashboard
    case nutrition
    case habits
    case workouts
    
    public var badge: String {
        switch self {
        case .dashboard: return "FORMA PRO 💎"
        case .nutrition: return "AI ПИТАНИЕ 🥗"
        case .habits: return "СТРИК & НАГРАДЫ 🏆"
        case .workouts: return "PRO ТРЕНИРОВКИ ⚡"
        }
    }
    
    public var title: String {
        switch self {
        case .dashboard: return "Раскройте весь потенциал FORMA PRO"
        case .nutrition: return "Безлимитный ИИ-сканер блюд"
        case .habits: return "Получайте PRO за привычки"
        case .workouts: return "Все ИИ-тренеры и аудио-коучинг"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .dashboard: return "Все 4 ИИ-наставника, безлимитные сканы тарелок, глубокая аналитика и умные планы"
        case .nutrition: return "Сканируйте любые блюда по фото без ограничений: расчет БЖУ, калорий и гликемического индекса"
        case .habits: return "Держите стрик 3+ дня и открывайте FORMA PRO бесплатно в награду за дисциплину"
        case .workouts: return "Персональные тренировки, аналитика зон пульса и голосовые подсказки в наушники"
        }
    }
    
    public var callToAction: String {
        switch self {
        case .dashboard: return "Попробовать PRO"
        case .nutrition: return "Снять лимиты"
        case .habits: return "Узнать о наградах"
        case .workouts: return "Открыть всё"
        }
    }
    
    public var icon: String {
        switch self {
        case .dashboard: return "crown.fill"
        case .nutrition: return "camera.viewfinder"
        case .habits: return "flame.fill"
        case .workouts: return "figure.run.square.stack.fill"
        }
    }
    
    public var gradientColors: [Color] {
        switch self {
        case .dashboard:
            return [Color(red: 139/255, green: 92/255, blue: 246/255), Color(red: 59/255, green: 130/255, blue: 246/255)]
        case .nutrition:
            return [Color(red: 16/255, green: 185/255, blue: 129/255), Color(red: 5/255, green: 150/255, blue: 105/255)]
        case .habits:
            return [Color(red: 245/255, green: 158/255, blue: 11/255), Color(red: 239/255, green: 68/255, blue: 68/255)]
        case .workouts:
            return [Color(red: 236/255, green: 72/255, blue: 153/255), Color(red: 139/255, green: 92/255, blue: 246/255)]
        }
    }
}

// MARK: - Нативный интерактивный промо-баннер FORMA PRO
public struct FormaPromotionalBannerView: View {
    public let placement: FormaBannerPlacement
    
    @ObservedObject private var subscription = SubscriptionManager.shared
    @ObservedObject private var metaAdManager = MetaAdManager.shared
    @State private var showingPaywall: Bool = false
    @State private var showingRewardsInfo: Bool = false
    
    public init(placement: FormaBannerPlacement) {
        self.placement = placement
    }
    
    public var body: some View {
        // Если у пользователя уже оплачена постоянная подписка — скрываем рекламу, чтобы не перегружать интерфейс
        if subscription.isPaidPro {
            EmptyView()
        } else if subscription.isProRewardActive {
            // Если активен подарочный PRO за стрик — показываем таймер и статус
            activeRewardBanner
        } else if metaAdManager.hasActivePlacement {
            // Если в настройках активирован Placement ID от Meta Audience Network — показываем рекламу Meta
            MetaNativeBannerAdView(placementTitle: placement.badge)
        } else {
            // Стандартный промо-баннер для каждого раздела
            standardPromoBanner
        }
    }
    
    // MARK: - Баннер активной награды за стрики
    private var activeRewardBanner: some View {
        Button(action: {
            HapticManager.shared.impact(.light)
            showingPaywall = true
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 245/255, green: 158/255, blue: 11/255), Color(red: 239/255, green: 68/255, blue: 68/255)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "crown.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("PRO НАГРАДА АКТИВНА")
                            .font(.system(size: 10, weight: .heavy))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.yellow.opacity(0.2))
                            .foregroundColor(Color.yellow)
                            .clipShape(Capsule())
                        
                        if let remaining = subscription.rewardTimeRemainingString {
                            Text(remaining)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    
                    Text("Все PRO-функции разблокированы за дисциплину")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.yellow.opacity(0.4), Color.orange.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.2
                            )
                    )
            )
            .shadow(color: Color.yellow.opacity(0.12), radius: 8, y: 3)
        }
        .buttonStyle(AppleDesignAwardsButtonStyle(scaleAmount: 0.98))
        .sheet(isPresented: $showingPaywall) {
            FormaPaywallView()
        }
    }
    
    // MARK: - Стандартный промо-баннер раздела
    private var standardPromoBanner: some View {
        Button(action: {
            HapticManager.shared.impact(.light)
            if placement == .habits {
                showingRewardsInfo = true
            } else {
                showingPaywall = true
            }
        }) {
            HStack(spacing: 14) {
                // Иконка в градиентной капсуле
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: placement.gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .shadow(color: placement.gradientColors[0].opacity(0.35), radius: 6, y: 2)
                    
                    Image(systemName: placement.icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // Текстовый блок
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(placement.badge)
                            .font(.system(size: 9, weight: .heavy))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(placement.gradientColors[0].opacity(0.15))
                            .foregroundColor(placement.gradientColors[0])
                            .clipShape(Capsule())
                    }
                    
                    Text(placement.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                    
                    Text(placement.subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer(minLength: 4)
                
                // Кнопка действия / стрелка
                VStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(placement.gradientColors[0])
                    
                    Text(placement.callToAction)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(placement.gradientColors[0])
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(placement.gradientColors[0].opacity(0.1))
                .cornerRadius(12)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(
                                LinearGradient(
                                    colors: [placement.gradientColors[0].opacity(0.3), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(color: placement.gradientColors[0].opacity(0.08), radius: 10, y: 4)
        }
        .buttonStyle(AppleDesignAwardsButtonStyle(scaleAmount: 0.98))
        .sheet(isPresented: $showingPaywall) {
            FormaPaywallView()
        }
        .sheet(isPresented: $showingRewardsInfo) {
            HabitsRewardInfoSheet(onOpenPaywall: {
                showingRewardsInfo = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showingPaywall = true
                }
            })
        }
    }
}

// MARK: - Праздничный модальный экран начисления награды за привычки (Celebration Sheet)
public struct HabitRewardCelebrationSheet: View {
    @Environment(\.dismiss) private var dismiss
    public let reward: HabitRewardItem
    
    @State private var isAnimating = false
    
    public init(reward: HabitRewardItem) {
        self.reward = reward
    }
    
    public var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            // Фоновое сияние
            Circle()
                .fill(Color(red: 245/255, green: 158/255, blue: 11/255).opacity(0.18))
                .frame(width: 320, height: 320)
                .blur(radius: 80)
                .offset(y: -100)
            
            VStack(spacing: 24) {
                // Декоративная полоска шторки
                Capsule()
                    .fill(Color.primary.opacity(0.15))
                    .frame(width: 36, height: 5)
                    .padding(.top, 10)
                
                Spacer()
                
                // Анимированная иконка триумфа
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 245/255, green: 158/255, blue: 11/255), Color(red: 239/255, green: 68/255, blue: 68/255)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .scaleEffect(isAnimating ? 1.05 : 0.95)
                        .shadow(color: Color.orange.opacity(0.4), radius: 20, y: 8)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
                    
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 46, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // Текстовые поздравления
                VStack(spacing: 8) {
                    Text("ПОБЕДА ДИСЦИПЛИНЫ! 🎉")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(Color.orange)
                        .tracking(1.2)
                    
                    Text("Стрик \(reward.streakDays) дней подряд!")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                    
                    Text("В привычке «\(reward.habitTitle)»")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                }
                
                // Карточка открытой награды
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 16))
                        Text(reward.rewardTitle)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Theme.textPrimary)
                    }
                    
                    Divider()
                        .background(Color.primary.opacity(0.08))
                    
                    VStack(alignment: .leading, spacing: 10) {
                        rewardFeatureRow(icon: "camera.viewfinder", title: "Безлимитный ИИ-сканер тарелок", desc: "Точный расчет калорий и нутриентов")
                        rewardFeatureRow(icon: "brain.head.profile", title: "Все 4 персонажа ИИ-тренеров", desc: "Марк, Елена, Макс и София")
                        rewardFeatureRow(icon: "checklist.checked", title: "Неограниченные привычки", desc: "Умные напоминания и адаптивные советы")
                    }
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Theme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.orange.opacity(0.25), lineWidth: 1.2)
                        )
                )
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Главная кнопка закрытия
                Button(action: {
                    HapticManager.shared.notification(.success)
                    dismiss()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                        Text("Активировать & Начать 🚀")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .foregroundColor(.white)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 245/255, green: 158/255, blue: 11/255), Color(red: 239/255, green: 68/255, blue: 68/255)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(18)
                    .shadow(color: Color.orange.opacity(0.35), radius: 10, y: 4)
                }
                .buttonStyle(AppleDesignAwardsButtonStyle(scaleAmount: 0.97))
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            isAnimating = true
            HapticManager.shared.notification(.success)
        }
    }
    
    private func rewardFeatureRow(icon: String, title: String, desc: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color.orange)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
            }
        }
    }
}

// MARK: - Информационный экран наград за привычки (Habits Reward Info Sheet)
public struct HabitsRewardInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    public let onOpenPaywall: () -> Void
    
    public var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 22) {
                    Capsule()
                        .fill(Color.primary.opacity(0.15))
                        .frame(width: 36, height: 5)
                        .padding(.top, 10)
                    
                    // Шапка
                    VStack(spacing: 8) {
                        Image(systemName: "gift.fill")
                            .font(.system(size: 40))
                            .foregroundColor(Color.orange)
                            .padding(.bottom, 4)
                        
                        Text("Награды за дисциплину")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                        
                        Text("Формируйте полезные привычки или преодолевайте слабости — получайте полный FORMA PRO бесплатно!")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Майлстоуны наград
                    VStack(spacing: 12) {
                        rewardMilestoneCard(
                            days: "3 ДНЯ",
                            title: "24 часа FORMA PRO + 5 AI-сканов",
                            desc: "Первый шаг к победе. Открывает полный доступ на сутки.",
                            icon: "flame.fill",
                            color: Color.orange
                        )
                        rewardMilestoneCard(
                            days: "7 ДНЕЙ",
                            title: "48 часов FORMA PRO + 10 AI-сканов",
                            desc: "Неделя триумфа! 2 полных дня премиум-функций.",
                            icon: "star.fill",
                            color: Color.purple
                        )
                        rewardMilestoneCard(
                            days: "21 ДЕНЬ",
                            title: "7 дней FORMA PRO + 25 AI-сканов",
                            desc: "Нейро-перестройка! Целая неделя неограниченного PRO в подарок.",
                            icon: "crown.fill",
                            color: Color.yellow
                        )
                    }
                    .padding(.horizontal)
                    
                    // Кнопка перехода к подписке
                    VStack(spacing: 12) {
                        Button(action: {
                            dismiss()
                            onOpenPaywall()
                        }) {
                            Text("Оформить постоянную подписку")
                                .font(.system(size: 15, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .foregroundColor(.white)
                                .background(LinearGradient(colors: [Color.blue, Color.purple], startPoint: .leading, endPoint: .trailing))
                                .cornerRadius(16)
                        }
                        
                        Button(action: {
                            dismiss()
                        }) {
                            Text("Понятно, буду держать стрик!")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                }
                .padding(.bottom, 30)
            }
        }
    }
    
    private func rewardMilestoneCard(days: String, title: String, desc: String, icon: String, color: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(days)
                        .font(.system(size: 10, weight: .heavy))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(color.opacity(0.2))
                        .foregroundColor(color)
                        .clipShape(Capsule())
                }
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
            }
            
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}
