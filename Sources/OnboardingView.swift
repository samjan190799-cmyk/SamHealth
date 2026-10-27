import SwiftUI

// MARK: - Состояние онбординга

/// Онбординг показывается только новому пользователю: до него приложение не показывает системные
/// запросы (Apple Health, трекинг), а предлагает подключить данные само, с объяснением зачем.
enum FormaOnboarding {
    static let doneKey = "forma_onboarding_done_v1"
    /// Тот же флаг, что использует HealthKitManager: «Apple Health уже предлагали»
    private static let healthPromptedKey = "healthkit_auto_prompted_v3"

    static var isDone: Bool {
        #if DEBUG
        if FormaScreenshotMode.isActive {
            // В режиме скриншотов онбординг нужен только для сцены `onboarding:<страница>`
            return FormaScreenshotMode.onboardingPage == nil
        }
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return true
        }
        #endif
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: doneKey) {
            return true
        }
        // Пользователь, которому Apple Health уже предлагали (запуск старой версии), онбординг не видит
        if defaults.bool(forKey: healthPromptedKey) {
            defaults.set(true, forKey: doneKey)
            return true
        }
        return false
    }

    /// Помечает онбординг пройденным. Пока человек сам не нажал «Подключить», Apple Health не
    /// запрашивается повторно «из ниоткуда» — подключить можно с Главной или из Настроек.
    static func markDone() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: doneKey)
        defaults.set(true, forKey: healthPromptedKey)
    }
}

// MARK: - Экран онбординга

struct FormaOnboardingView: View {
    var onFinish: () -> Void

    @State private var page: Int
    @State private var healthRequested = false
    @State private var notificationsRequested = false
    @ObservedObject private var health = HealthKitManager.shared
    @ObservedObject private var notifications = FormaNotificationManager.shared

    private let lastPage = 2

    init(startPage: Int = 0, onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        _page = State(initialValue: min(max(startPage, 0), 2))
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    if page < lastPage {
                        Button("Пропустить") {
                            finish()
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                    }
                }
                .frame(height: 44)
                .padding(.horizontal, 20)

                TabView(selection: $page) {
                    welcomePage.tag(0)
                    featuresPage.tag(1)
                    permissionsPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                pageDots
                    .padding(.top, 8)

                FormaPrimaryButton(title: page == lastPage ? "Начать" : "Дальше") {
                    if page == lastPage {
                        finish()
                    } else {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            page += 1
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
        }
        .interactiveDismissDisabled()
    }

    private func finish() {
        HapticManager.shared.impact(.light)
        FormaOnboarding.markDone()
        onFinish()
    }

    // MARK: Страницы

    private var welcomePage: some View {
        VStack(spacing: 20) {
            Spacer()
            AppLogoView(size: 96)
            Text("Добро пожаловать\nв Forma")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text("Шаги, тренировки, питание и привычки в одном месте — с ИИ-коучем и Apple Watch.")
                .font(.system(size: 16))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
            Spacer()
            Spacer()
        }
    }

    private var featuresPage: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("Всё для вашей формы")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 4)

            featureCard(icon: "figure.run", tint: Theme.exerciseColor,
                        title: "Тренировки и шаги",
                        subtitle: "35 видов тренировок, фоновый шагомер и синхронизация с Apple Watch")
            featureCard(icon: "leaf.fill", tint: .orange,
                        title: "Питание и вода",
                        subtitle: "Учёт еды по фото, штрих-коду и умная норма воды на каждый день")
            featureCard(icon: "sparkles", tint: Theme.aiViolet,
                        title: "ИИ-коуч",
                        subtitle: "Советы по питанию, восстановлению и режиму тренировок")
            featureCard(icon: "checkmark.seal.fill", tint: Theme.flameOrange,
                        title: "Привычки и награды",
                        subtitle: "Серии, уровни и достижения помогают не бросать начатое")
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private var permissionsPage: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("Подключите данные")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text("Это необязательно: всё можно сделать позже на Главной или в Настройках.")
                .font(.system(size: 15))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.bottom, 4)

            permissionCard(
                icon: "heart.fill", tint: Theme.pulseColor,
                title: "Apple Health",
                subtitle: "Шаги, пульс, сон и тренировки подтянутся автоматически. Данные остаются на вашем устройстве.",
                buttonTitle: "Подключить",
                isDone: health.isAuthorized || healthRequested
            ) {
                healthRequested = true
                UserDefaults.standard.set(true, forKey: "healthkit_auto_prompted_v3")
                health.requestAuthorization()
            }

            permissionCard(
                icon: "bell.badge.fill", tint: .orange,
                title: "Напоминания",
                subtitle: "О воде, еде и активности — в удобное время. Настроить можно в любой момент.",
                buttonTitle: "Включить",
                isDone: notifications.isAuthorized || notificationsRequested
            ) {
                notificationsRequested = true
                notifications.requestPermission()
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    // MARK: Компоненты

    private func featureCard(icon: String, tint: Color, title: String, subtitle: String) -> some View {
        FormaCardHeader(icon: icon, tint: tint, title: title, subtitle: subtitle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .premiumCard()
    }

    private func permissionCard(
        icon: String,
        tint: Color,
        title: String,
        subtitle: String,
        buttonTitle: String,
        isDone: Bool,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            FormaCardHeader(icon: icon, tint: tint, title: title, subtitle: subtitle)

            Button(action: {
                HapticManager.shared.impact(.medium)
                action()
            }) {
                HStack(spacing: 6) {
                    if isDone {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    Text(isDone ? "Готово" : buttonTitle)
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(isDone ? Color.green : tint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background((isDone ? Color.green : tint).opacity(0.12))
                .cornerRadius(FormaLayout.chipRadius)
            }
            .buttonStyle(.plain)
            .disabled(isDone)
        }
        .premiumCard()
    }

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(0...lastPage, id: \.self) { index in
                Capsule()
                    .fill(index == page ? Theme.tabBarTint : Color.primary.opacity(0.15))
                    .frame(width: index == page ? 22 : 7, height: 7)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: page)
    }
}
