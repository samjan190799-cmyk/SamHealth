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

    private let lastPage = 3
    /// Страница профиля: без него неточны калории, норма воды и нагрузка, поэтому «Пропустить» её не перепрыгивает
    private let profilePage = 2

    init(startPage: Int = 0, onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        _page = State(initialValue: min(max(startPage, 0), 3))
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    if page < lastPage {
                        Button("Пропустить") {
                            if page < profilePage {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                    page = profilePage
                                }
                            } else {
                                finish()
                            }
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
                    profileStep.tag(profilePage)
                    permissionsPage.tag(3)
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

    private var profileStep: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Расскажите о себе")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Так точнее считаются калории, норма воды и нагрузка. Это можно изменить в Настройках в любой момент.")
                    .font(.system(size: 15))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)

                FormaProfileForm()
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 12)
        }
        .scrollBounceBehavior(.basedOnSize)
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

// MARK: - Профиль: общая форма для онбординга и Главной

enum FormaProfile {
    /// Профиль не заполнен: человек пропустил онбординг или поставил приложение заново без iCloud.
    /// Вес не учитывается — его может подставить Apple Health.
    static var isMissing: Bool {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: "user_age") == nil && defaults.object(forKey: "user_height") == nil
    }
}

/// Пол, возраст, рост, вес и цель. Поля берут сохранённое значение (например, из iCloud) или значение по умолчанию,
/// как в Настройках. В хранилище пишется только то, что человек изменил сам: нетронутые поля остаются «по умолчанию»,
/// и на новом телефоне они не затрут профиль, пришедший из iCloud.
struct FormaProfileForm: View {
    @State private var gender: String
    @State private var age: Int
    @State private var height: Int
    @State private var weight: Double
    @State private var targetWeight: Double

    init() {
        let defaults = UserDefaults.standard
        _gender = State(initialValue: defaults.string(forKey: "user_gender") ?? "Мужской")
        _age = State(initialValue: defaults.object(forKey: "user_age") != nil ? defaults.integer(forKey: "user_age") : 25)
        _height = State(initialValue: defaults.object(forKey: "user_height") != nil ? defaults.integer(forKey: "user_height") : 175)
        _weight = State(initialValue: defaults.object(forKey: "user_weight") != nil ? defaults.double(forKey: "user_weight") : 75.0)
        _targetWeight = State(initialValue: defaults.object(forKey: "user_target_weight") != nil ? defaults.double(forKey: "user_target_weight") : 70.0)
    }

    /// Записывает всё, что показано, — в том числе нетронутые значения. Для кнопки «Готово»: человек подтвердил профиль.
    static func confirmDefaultsIfMissing() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "user_gender") == nil { defaults.set("Мужской", forKey: "user_gender") }
        if defaults.object(forKey: "user_age") == nil { defaults.set(25, forKey: "user_age") }
        if defaults.object(forKey: "user_height") == nil { defaults.set(175, forKey: "user_height") }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Пол")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Picker("Пол", selection: $gender) {
                    Text("Мужской").tag("Мужской")
                    Text("Женский").tag("Женский")
                }
                .pickerStyle(.segmented)
                .frame(width: 170)
            }
            Divider()
            Stepper(value: $age, in: 10...100) {
                valueRow(title: "Возраст", value: "\(age)")
            }
            Divider()
            Stepper(value: $height, in: 120...230) {
                valueRow(title: "Рост", value: "\(height) см")
            }
            Divider()
            Stepper(value: $weight, in: 30...250, step: 0.5) {
                valueRow(title: "Вес", value: String(format: "%.1f кг", weight))
            }
            Divider()
            Stepper(value: $targetWeight, in: 30...250, step: 0.5) {
                valueRow(title: "Цель по весу", value: String(format: "%.1f кг", targetWeight))
            }
        }
        .premiumCard()
        .onChange(of: gender) { _, value in UserDefaults.standard.set(value, forKey: "user_gender") }
        .onChange(of: age) { _, value in UserDefaults.standard.set(value, forKey: "user_age") }
        .onChange(of: height) { _, value in UserDefaults.standard.set(value, forKey: "user_height") }
        .onChange(of: weight) { _, value in UserDefaults.standard.set(value, forKey: "user_weight") }
        .onChange(of: targetWeight) { _, value in UserDefaults.standard.set(value, forKey: "user_target_weight") }
    }

    private func valueRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(Theme.textPrimary)
                .monospacedDigit()
        }
    }
}

/// Лист с профилем для тех, кто его пропустил: открывается с карточки на Главной
struct FormaProfileSetupSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        Text("Расскажите о себе")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                            .multilineTextAlignment(.center)
                        Text("Так точнее считаются калории, норма воды и нагрузка.")
                            .font(.system(size: 15))
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                        FormaProfileForm()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 32)
                }
                FormaPrimaryButton(title: "Готово") {
                    FormaProfileForm.confirmDefaultsIfMissing()
                    HapticManager.shared.notification(.success)
                    dismiss()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }
}
