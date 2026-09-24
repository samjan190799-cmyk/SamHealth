import SwiftUI

struct SettingsView: View {
    @AppStorage("app_language") private var appLanguage = "ru"
    @AppStorage("app_theme") private var appTheme = "system"
    
    // API ключи в AppStorage
    @AppStorage("api_key_gemini") private var apiKeyGemini = ""
    @AppStorage("api_key_openai") private var apiKeyOpenAI = ""
    @AppStorage("api_key_claude") private var apiKeyClaude = ""
    
    // Локальные переменные для ввода API ключей
    @State private var localGeminiKey = ""
    @State private var localOpenAIKey = ""
    @State private var localClaudeKey = ""
    
    // Данные профиля в AppStorage
    @AppStorage("user_age") private var userAge = 25
    @AppStorage("user_height") private var userHeight = 175
    @AppStorage("user_weight") private var userWeight = 75.0
    @AppStorage("user_target_weight") private var userTargetWeight = 70.0
    @AppStorage("user_gender") private var userGender = "Мужской"
    @AppStorage("user_activity_level") private var userActivityLevel = "Средняя"
    @AppStorage("user_somatotype") private var userSomatotype = "mesomorph"
    @AppStorage("user_metabolism_speed") private var userMetabolismSpeed = "normal"
    @State private var showingSomatotypeQuiz = false
    @State private var coachGenderFilter: String = "all"
    
    // Согласие на использование стороннего ИИ (Guidelines 5.1.1(i) & 5.1.2(i))
    @AppStorage("user_consented_to_ai_sharing") private var userConsentedToAISharing = false
    @State private var showingMedicalSources = false
    @State private var showingAIConsentSheet = false
    
    // Умные напоминания от ИИ-тренера
    @AppStorage("notifications_meal_enabled") private var notificationsMealEnabled = true
    @AppStorage("notifications_water_enabled") private var notificationsWaterEnabled = true
    @AppStorage("notifications_activity_enabled") private var notificationsActivityEnabled = true
    @AppStorage("ai_deficit_notifications_enabled") private var aiDeficitNotificationsEnabled = true
    @AppStorage("notifications_random_time_enabled") private var notificationsRandomTimeEnabled = true
    @AppStorage("notifications_start_hour") private var notificationsStartHour = 9
    @AppStorage("notifications_end_hour") private var notificationsEndHour = 21
    @AppStorage("notifications_frequency_per_day") private var notificationsFrequencyPerDay = 5
    @State private var showingTestNotificationBanner = false
    @State private var testNotificationBannerText = ""
    
    // Live Activity и Dynamic Island (управление показом виджета воды)
    @AppStorage("enable_hydration_live_activity") private var enableHydrationLiveActivity = true
    @ObservedObject private var liveActivityManager = HydrationLiveActivityManager.shared
    
    // Локальные переменные для ввода профиля
    @State private var localAge = ""
    @State private var localHeight = ""
    @State private var localWeight = ""
    @State private var localTargetWeight = ""
    @State private var showingHealthSyncHub = false
    @State private var showingCSVHub = false
    @State private var showingResetDataAlert = false
    @State private var isCheckingModels = false
    @State private var modelCheckStatusMessage: String? = nil
    @State private var showingWidgetSyncedToast = false
    
    // Перепроверка норм через ИИ
    @State private var isRunningAICalibration = false
    @State private var aiCalibrationResult: AIBodyCalibrationResult? = nil
    @State private var showingAICalibrationSheet = false
    @State private var aiCalibrationError: String? = nil
    @State private var showingAICalibrationError = false
    
    @ObservedObject private var watchManager = WatchConnectivityManager.shared
    @ObservedObject private var coachManager = AICoachManager.shared
    @ObservedObject private var subscription = SubscriptionManager.shared
    @ObservedObject private var adManager = FormaAdManager.shared
    @State private var showingPaywall = false
    
    // 🔐 Скрытый Easter Egg «Сейф-маршрут»: последовательное нажатие 4 элементов:
    // Шаг 1: Логотип Forma -> Шаг 2: Версия -> Шаг 3: Цитата -> Шаг 4: Разработчик Samvel
    @State private var secretSafeStep = 0
    @State private var secretSafeLastTime = Date.distantPast
    @State private var secretUnlockToast = false
    
    // 🔑 Ввод пароля для переключения PRO в TestFlight (Пароль 1907)
    @State private var showingPasswordPrompt = false
    @State private var enteredPassword = ""
    @State private var showingPasswordFeedback = false
    @State private var passwordFeedbackTitle = ""
    @State private var passwordFeedbackMessage = ""
    
    @EnvironmentObject var health: HealthKitManager
    @EnvironmentObject var stepManager: BackgroundStepManager
    
    // Вспомогательный перевод для локальных строк настроек
    private func tr(_ key: String) -> String {
        LocalizationManager.tr(key, lang: appLanguage)
    }
    
    private func formatSyncTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    private func saveGeminiKey() {
        let trimmed = localGeminiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if apiKeyGemini != trimmed {
            apiKeyGemini = trimmed
        }
    }
    
    private func saveOpenAIKey() {
        let trimmed = localOpenAIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if apiKeyOpenAI != trimmed {
            apiKeyOpenAI = trimmed
        }
    }
    
    private func saveClaudeKey() {
        let trimmed = localClaudeKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if apiKeyClaude != trimmed {
            apiKeyClaude = trimmed
        }
    }
    
    private func saveProfile() {
        if let age = Int(localAge), age != userAge {
            userAge = age
        }
        if let height = Int(localHeight), height != userHeight {
            userHeight = height
        }
        if let targetW = Double(localTargetWeight.replacingOccurrences(of: ",", with: ".")), abs(targetW - userTargetWeight) > 0.05 {
            userTargetWeight = targetW
        }
        if let w = Double(localWeight.replacingOccurrences(of: ",", with: ".")), abs(w - userWeight) > 0.05 {
            userWeight = w
            health.addWeight(weight: w)
        }
    }
    
    private func runAIBodyCalibration() {
        HapticManager.shared.impact(.medium)
        saveProfile()
        
        // Безопасная валидация физиологических границ для расчета ИИ (международный стандарт ВОЗ)
        let parsedHeight = userHeight >= 100 ? userHeight : 170
        let parsedAge = userAge >= 14 ? userAge : 25
        let parsedWeight = userWeight >= 35.0 ? userWeight : 70.0
        
        // Согласие пользователя на использование ИИ (Apple Guidelines)
        if !userConsentedToAISharing {
            userConsentedToAISharing = true
            UserDefaults.standard.set(true, forKey: "user_consented_to_ai_sharing")
        }
        
        isRunningAICalibration = true
        
        Task {
            do {
                let res = try await GeminiScanService.shared.auditAndCalibrateProfile(
                    gender: userGender,
                    age: parsedAge,
                    height: parsedHeight,
                    weight: parsedWeight,
                    targetWeight: max(35.0, userTargetWeight),
                    activityLevel: userActivityLevel,
                    somatotype: userSomatotype,
                    metabolismSpeed: userMetabolismSpeed,
                    language: appLanguage
                )
                
                await MainActor.run {
                    self.aiCalibrationResult = res
                    self.isRunningAICalibration = false
                    self.showingAICalibrationSheet = true
                    HapticManager.shared.notification(.success)
                }
            } catch {
                await MainActor.run {
                    self.isRunningAICalibration = false
                    self.aiCalibrationError = error.localizedDescription
                    self.showingAICalibrationError = true
                    HapticManager.shared.notification(.error)
                }
            }
        }
    }
    
    private func rescheduleSmartNotifications() {
        FormaNotificationManager.shared.scheduleSmartReminders(
            mealEnabled: notificationsMealEnabled,
            waterEnabled: notificationsWaterEnabled,
            activityEnabled: notificationsActivityEnabled,
            isRandomTime: notificationsRandomTimeEnabled,
            startHour: notificationsStartHour,
            endHour: notificationsEndHour,
            frequencyPerDay: notificationsFrequencyPerDay,
            coach: coachManager.currentCoach
        )
    }
    
    private func sendTestReminder(type: FormaNotificationManager.ReminderType) {
        FormaNotificationManager.shared.requestPermission { granted in
            if granted {
                FormaNotificationManager.shared.sendTestNotification(type: type, coach: coachManager.currentCoach)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    testNotificationBannerText = "Уведомление отправлено! Придет через 3 секунды 🔔"
                    showingTestNotificationBanner = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    withAnimation {
                        showingTestNotificationBanner = false
                    }
                }
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    testNotificationBannerText = "Разрешите уведомления в настройках iOS ⚙️"
                    showingTestNotificationBanner = true
                }
            }
        }
    }
    
    private func sendTestAIDeficitPush() {
        FormaNotificationManager.shared.requestPermission { granted in
            if granted {
                FormaNotificationManager.shared.sendTestAIDeficitNotification(coach: coachManager.currentCoach)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    testNotificationBannerText = "AI-уведомление дефицита отправлено! Придет через 1.5 сек 🔔"
                    showingTestNotificationBanner = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    withAnimation {
                        showingTestNotificationBanner = false
                    }
                }
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    testNotificationBannerText = "Разрешите уведомления в настройках iOS ⚙️"
                    showingTestNotificationBanner = true
                }
            }
        }
    }
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    headerView
                    
                    // --- 1. ПРОФИЛЬ И ПОДПИСКА ---
                    formaProBannerView
                    profileCardView
                    
                    // --- 2. УВЕДОМЛЕНИЯ И ЭКРАН (друг за другом) ---
                    sectionHeader(title: "Уведомления и экран", icon: "bell.badge.fill", color: Theme.exerciseColor)
                    notificationsCardView
                    liveActivityCardView
                    waterSettingsCardView
                    
                    // --- 3. УСТРОЙСТВА: APPLE WATCH И AIRPODS (друг за другом) ---
                    sectionHeader(title: "Устройства: Apple Watch и AirPods", icon: "applewatch.side.right", color: Color(red: 255/255, green: 45/255, blue: 85/255))
                    appleWatchCardView
                    heartRateCardView
                    voiceCoachCardView
                    
                    // --- 4. ИИ-КОУЧИНГ И МОДЕЛИ ---
                    sectionHeader(title: "ИИ-коучинг и нейросети", icon: "sparkles", color: Theme.aiAccent)
                    coachSelectorCardView
                    apiKeyCardView
                    
                    // --- 5. ЗДОРОВЬЕ И ЭКСПОРТ ДАННЫХ ---
                    sectionHeader(title: "Здоровье и экспорт данных", icon: "heart.text.square.fill", color: Theme.pulseColor)
                    appleHealthCardView
                    csvHubCardView
                    
                    // --- 6. ИНТЕРФЕЙС И БЕЗОПАСНОСТЬ ---
                    sectionHeader(title: "Интерфейс и безопасность", icon: "slider.horizontal.3", color: Theme.textSecondary)
                    languageAndThemeCardView
                    missionAndStoryCardView
                    complianceAndLegalCardView
                    
                    // Панель управления гибридной монетизацией (доступна только в TestFlight/Debug разработчику)
                    if Bundle.main.isTestFlightOrDebug {
                        hybridAdDeveloperCardView
                    }
                }
                .padding(.bottom, 24)
            }
            .alert("Удалить все данные приложения?", isPresented: $showingResetDataAlert) {
                Button("Отмена", role: .cancel) { }
                Button("Удалить всё", role: .destructive) {
                    if let domain = Bundle.main.bundleIdentifier {
                        UserDefaults.standard.removePersistentDomain(forName: domain)
                    }
                    if let sharedDefaults = UserDefaults(suiteName: "group.com.samvel.forma") {
                        sharedDefaults.removePersistentDomain(forName: "group.com.samvel.forma")
                    }
                    UserDefaults.standard.synchronize()
                    HapticManager.shared.notification(.success)
                }
            } message: {
                Text("Все локальные настройки, профиль, история и кэш будут безвозвратно удалены. Записи в Apple Health останутся в системном приложении Здоровье.")
            }
            .alert("Доступ к FORMA PRO (TestFlight)", isPresented: $showingPasswordPrompt) {
                TextField("Пароль", text: $enteredPassword)
                    .keyboardType(.numberPad)
                Button("Применить") {
                    handleTestFlightPassword()
                }
                Button("Отмена", role: .cancel) {
                    enteredPassword = ""
                }
            } message: {
                Text("Текущий статус: \(subscription.isPro ? "PRO АКТИВЕН 💎" : "Freemium (Базовый)")\n\nВведите пароль, чтобы \(subscription.isPro ? "ОТКЛЮЧИТЬ" : "ВКЛЮЧИТЬ") премиум-подписку:")
            }
            .alert(passwordFeedbackTitle, isPresented: $showingPasswordFeedback) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(passwordFeedbackMessage)
            }
            .sheet(isPresented: $showingHealthSyncHub) {
                HealthKitSyncHubView()
                    .environmentObject(health)
            }
            .sheet(isPresented: $showingCSVHub) {
                HealthDataCSVImportSheet()
                    .environmentObject(health)
            }
            .sheet(isPresented: $showingPaywall) {
                FormaPaywallView()
            }
            .sheet(isPresented: $showingSomatotypeQuiz) {
                SomatotypeQuizSheet(userSomatotype: $userSomatotype, userMetabolismSpeed: $userMetabolismSpeed)
            }
            .sheet(isPresented: $showingAICalibrationSheet) {
                if let result = aiCalibrationResult {
                    let somato = Somatotype(rawValue: userSomatotype) ?? .mesomorph
                    AIBodyCalibrationSheet(
                        result: result,
                        currentWeight: userWeight,
                        targetWeight: userTargetWeight,
                        somatotype: somato,
                        onApply: { newWaterGoal in
                            health.setWaterGoal(newWaterGoal, isAdaptive: true)
                            health.saveLocalData()
                            health.syncWidgetsData()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                showingWidgetSyncedToast = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                withAnimation {
                                    showingWidgetSyncedToast = false
                                }
                            }
                        }
                    )
                }
            }
            .alert("Калибровка норм ИИ", isPresented: $showingAICalibrationError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(aiCalibrationError ?? "Ошибка калибровки")
            }
            
            // ─── Всплывающий тост пасхалки (Easter Egg) ───
            if secretUnlockToast {
                VStack {
                    secretUnlockToastView
                        .padding(.top, 12)
                        .padding(.horizontal)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(999)
            }
        }
        .onAppear {
            localGeminiKey = apiKeyGemini
            localOpenAIKey = apiKeyOpenAI
            localClaudeKey = apiKeyClaude
            
            localAge = String(userAge)
            localHeight = String(userHeight)
            localWeight = health.currentWeight > 0 ? String(format: "%.1f", health.currentWeight) : String(format: "%.1f", userWeight)
            localTargetWeight = String(format: "%.1f", userTargetWeight)
        }
        .onDisappear {
            Task(priority: .utility) {
                await MainActor.run {
                    saveGeminiKey()
                    saveOpenAIKey()
                    saveClaudeKey()
                    saveProfile()
                }
            }
        }
        .sheet(isPresented: $showingMedicalSources) {
            MedicalSourcesAndCitationsView()
        }
        .sheet(isPresented: $showingAIConsentSheet) {
            AIConsentSheet()
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var headerView: some View {
        HStack(spacing: 12) {
            AppLogoView(size: 34)
            Text(tr("settings_title"))
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textPrimary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 12)
    }
    
    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textSecondary)
                .textCase(.uppercase)
                .kerning(0.8)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    @ViewBuilder
    private var formaProBannerView: some View {
        if subscription.isPro {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(red: 168/255, green: 85/255, blue: 247/255).opacity(0.18))
                        .frame(width: 46, height: 46)
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 20))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("FORMA PRO")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                        Text("АКТИВЕН 💎")
                            .font(.system(size: 10, weight: .heavy))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.18))
                            .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                            .clipShape(Capsule())
                    }
                    Text("Безлимитный AI & LiDAR скан, все 6 тренеров и полный доступ.")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer()
            }
            .premiumCard()
            .padding(.horizontal)
        } else {
            Button(action: {
                showingPaywall = true
                HapticManager.shared.selection()
            }) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 168/255, green: 85/255, blue: 247/255), Color(red: 236/255, green: 72/255, blue: 153/255)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 46, height: 46)
                        Image(systemName: "crown.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 20))
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("Перейти на FORMA PRO")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.textPrimary)
                            Text("7 ДНЕЙ 0 ₽")
                                .font(.system(size: 9, weight: .heavy))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.yellow.opacity(0.25))
                                .foregroundColor(.yellow)
                                .clipShape(Capsule())
                        }
                        Text("Безлимит AI & LiDAR 3D сканов еды, все 6 тренеров и привычки.")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .premiumCard()
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private var profileCardView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "person.fill")
                    .foregroundColor(Theme.exerciseColor)
                Text("Личный профиль")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
            }
            
            VStack(spacing: 12) {
                HStack {
                    Text("Пол")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Picker("Пол", selection: $userGender) {
                        Text("Мужской").tag("Мужской")
                        Text("Женский").tag("Женский")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 150)
                }
                
                Divider()
                
                HStack {
                    Text("Возраст")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    TextField("25", text: $localAge, onCommit: {
                        saveProfile()
                    })
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .foregroundColor(Theme.textPrimary)
                }
                
                Divider()
                
                HStack {
                    Text("Рост (см)")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    TextField("175", text: $localHeight, onCommit: {
                        saveProfile()
                    })
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .foregroundColor(Theme.textPrimary)
                }
                
                Divider()
                
                HStack {
                    Text("Текущий вес (кг)")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    TextField("75.0", text: $localWeight, onCommit: {
                        saveProfile()
                    })
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .foregroundColor(Theme.textPrimary)
                    .onChange(of: localWeight) { _, _ in saveProfile() }
                }
                
                Divider()
                
                HStack {
                    Text("Целевой вес (кг)")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    TextField("70.0", text: $localTargetWeight, onCommit: {
                        saveProfile()
                    })
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .foregroundColor(Theme.textPrimary)
                    .onChange(of: localTargetWeight) { _, _ in saveProfile() }
                }
                
                Divider()
                
                HStack {
                    Text("Активность")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Picker("Активность", selection: $userActivityLevel) {
                        Text("Низкая").tag("Низкая")
                        Text("Средняя").tag("Средняя")
                        Text("Высокая").tag("Высокая")
                    }
                    .pickerStyle(MenuPickerStyle())
                    .foregroundColor(Theme.textPrimary)
                }
                
                Divider()
                
                // MARK: - Соматотип и метаболизм
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Тип телосложения (Соматотип)")
                                .font(.subheadline.bold())
                                .foregroundColor(Theme.textPrimary)
                            Text("Калибрует BMR, формулы калорий и советы ИИ")
                                .font(.caption2)
                                .foregroundColor(Theme.textSecondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            showingSomatotypeQuiz = true
                            HapticManager.shared.selection()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                Text("Пройти тест")
                            }
                            .font(.caption2.bold())
                            .foregroundColor(Theme.exerciseColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Theme.exerciseColor.opacity(0.12))
                            .clipShape(Capsule())
                        }
                    }
                    
                    // 3 Карточки выбора соматотипа
                    HStack(spacing: 8) {
                        ForEach(Somatotype.allCases) { somato in
                            let isSelected = userSomatotype == somato.rawValue
                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    userSomatotype = somato.rawValue
                                }
                                HapticManager.shared.impact(.light)
                            }) {
                                VStack(spacing: 4) {
                                    Text(somato.emoji)
                                        .font(.system(size: 20))
                                    Text(somato.shortTitle)
                                        .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                        .foregroundColor(isSelected ? .white : Theme.textPrimary)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(isSelected ? somato.accentColor : Color.primary.opacity(0.05))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isSelected ? somato.accentColor : Color.clear, lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    // Текущий выбранный соматотип — подсказка
                    let currentSomato = Somatotype(rawValue: userSomatotype) ?? .mesomorph
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(currentSomato.title)
                                .font(.caption.bold())
                                .foregroundColor(currentSomato.accentColor)
                            
                            Spacer()
                            
                            // Множитель BMR
                            let pct = Int((currentSomato.metabolismMultiplier - 1.0) * 100.0)
                            let pctStr = pct > 0 ? "BMR +\(pct)%" : (pct < 0 ? "BMR \(pct)%" : "BMR норма")
                            Text(pctStr)
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(currentSomato.accentColor.opacity(0.15))
                                .foregroundColor(currentSomato.accentColor)
                                .cornerRadius(6)
                        }
                        
                        Text(currentSomato.shortDescription)
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                            .lineSpacing(2)
                        
                        HStack(spacing: 12) {
                            Text("Целевой баланс: Углеводы \(currentSomato.recommendedMacros.carbs)% • Белки \(currentSomato.recommendedMacros.protein)% • Жиры \(currentSomato.recommendedMacros.fat)%")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(12)
                }
                
                Divider()
                
                // Скорость метаболизма
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Скорость метаболизма")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                        Text("Ощущение скорости усвоения пищи")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary.opacity(0.7))
                    }
                    Spacer()
                    Picker("Метаболизм", selection: $userMetabolismSpeed) {
                        ForEach(MetabolismSpeed.allCases) { m in
                            Text(m.shortTitle).tag(m.rawValue)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .foregroundColor(Theme.textPrimary)
                }
                
                Divider()
                
                // MARK: - Кнопка ИИ-перепроверки норм (Вода 3.5 л, Калории, БЖУ)
                Button(action: {
                    runAIBodyCalibration()
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0/255, green: 229/255, blue: 255/255),
                                            Color(red: 168/255, green: 85/255, blue: 247/255)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 40, height: 40)
                            
                            if isRunningAICalibration {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.85)
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text("Перепроверить все нормы с ИИ")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Theme.textPrimary)
                                
                                Text("AI")
                                    .font(.system(size: 9, weight: .black))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.purple.opacity(0.2))
                                    .foregroundColor(.purple)
                                    .cornerRadius(6)
                            }
                            
                            Text("Индивидуальный расчет нормы воды, калорий и БЖУ под ваше тело")
                                .font(.caption2)
                                .foregroundColor(Theme.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding(10)
                    .background(Color(red: 0/255, green: 229/255, blue: 255/255).opacity(0.06))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0/255, green: 229/255, blue: 255/255).opacity(0.4),
                                        Color.purple.opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isRunningAICalibration)
            }
        }
        .premiumCard()
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var apiKeyCardView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "key.fill")
                    .foregroundColor(.yellow)
                Text(tr("settings_api_title"))
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
            }
            
            Text(tr("settings_api_desc"))
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .lineSpacing(3)
            
            VStack(spacing: 12) {
                APIKeyField(label: "Google Gemini Key (Flash 3.7 / 3.6 / 3.5)", placeholder: "AIzaSy...", text: $localGeminiKey) {
                    saveGeminiKey()
                }
                .onChange(of: localGeminiKey) { _, _ in saveGeminiKey() }
                
                APIKeyField(label: "OpenAI ChatGPT Key (GPT-5 / 4o)", placeholder: "sk-proj-...", text: $localOpenAIKey) {
                    saveOpenAIKey()
                }
                .onChange(of: localOpenAIKey) { _, _ in saveOpenAIKey() }
                
                APIKeyField(label: "Anthropic Claude Key (Sonnet 5 / 3.7)", placeholder: "sk-ant-...", text: $localClaudeKey) {
                    saveClaudeKey()
                }
                .onChange(of: localClaudeKey) { _, _ in saveClaudeKey() }
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.purple)
                    Text("Авто-повышение до новейших моделей")
                        .font(.caption.bold())
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                    Text("Auto")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.2))
                        .foregroundColor(.purple)
                        .cornerRadius(6)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    if !apiKeyGemini.isEmpty {
                        HStack {
                            Text("Gemini:")
                                .font(.caption2.bold())
                                .foregroundColor(Theme.textSecondary)
                            Text(GeminiScanService.shared.activeGeminiModel)
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                    if !apiKeyOpenAI.isEmpty {
                        HStack {
                            Text("OpenAI:")
                                .font(.caption2.bold())
                                .foregroundColor(Theme.textSecondary)
                            Text("GPT-4o / GPT-5 (Auto)")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                    if !apiKeyClaude.isEmpty {
                        HStack {
                            Text("Claude:")
                                .font(.caption2.bold())
                                .foregroundColor(Theme.textSecondary)
                            Text("Claude 3.7 / 3.5 Sonnet (Auto)")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
        }
        .premiumCard()
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var notificationsCardView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.orange, Color.red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    Image(systemName: "bell.badge.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 18))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Умные напоминания тренера")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                    Text("Персонализированные пуши от \(coachManager.currentCoach.name)")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer()
            }
            
            VStack(spacing: 12) {
                Toggle(isOn: Binding(
                    get: { notificationsMealEnabled },
                    set: {
                        notificationsMealEnabled = $0
                        rescheduleSmartNotifications()
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Напоминания о приеме пищи")
                            .font(.subheadline.bold())
                            .foregroundColor(Theme.textPrimary)
                        Text("Уведомления о завтраке, обеде и ужине")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .tint(.orange)
                
                Divider().background(Color.white.opacity(0.08))
                
                Toggle(isOn: Binding(
                    get: { notificationsWaterEnabled },
                    set: {
                        notificationsWaterEnabled = $0
                        rescheduleSmartNotifications()
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Контроль водного баланса")
                            .font(.subheadline.bold())
                            .foregroundColor(Theme.textPrimary)
                        Text("Напоминание выпить стакан воды")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .tint(.blue)
                
                Divider().background(Color.white.opacity(0.08))
                
                Toggle(isOn: Binding(
                    get: { notificationsActivityEnabled },
                    set: {
                        notificationsActivityEnabled = $0
                        rescheduleSmartNotifications()
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Дневная активность и шаги")
                            .font(.subheadline.bold())
                            .foregroundColor(Theme.textPrimary)
                        Text("Мотивация размяться и добрать норму шагов")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .tint(.green)
                
                Divider().background(Color.white.opacity(0.08))
                
                Toggle(isOn: Binding(
                    get: { aiDeficitNotificationsEnabled },
                    set: {
                        aiDeficitNotificationsEnabled = $0
                        if $0 {
                            FormaNotificationManager.shared.scheduleAIDeficitNotifications(coach: coachManager.currentCoach)
                        } else {
                            FormaNotificationManager.shared.removeAIDeficitNotifications()
                        }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text("AI-дефицит и срез активности")
                                .font(.subheadline.bold())
                                .foregroundColor(Theme.textPrimary)
                            Image(systemName: "sparkles")
                                .font(.system(size: 11))
                                .foregroundColor(.purple)
                        }
                        Text("Дневной срез в 14:00 и вечерний итог дефицита в 20:30")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .tint(.purple)
            }
            
            Divider().background(Color.white.opacity(0.08))
            
            VStack(alignment: .leading, spacing: 8) {
                Text("ПРОВЕРКА РАБОТЫ")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(Theme.textSecondary)
                
                HStack(spacing: 8) {
                    Button(action: {
                        sendTestReminder(type: .meal)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "fork.knife")
                            Text("Еда")
                        }
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.8))
                        .cornerRadius(10)
                    }
                    
                    Button(action: {
                        sendTestReminder(type: .water)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "drop.fill")
                            Text("Вода")
                        }
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.8))
                        .cornerRadius(10)
                    }
                    
                    Button(action: {
                        sendTestAIDeficitPush()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                            Text("AI-Дефицит")
                        }
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color.purple.opacity(0.85))
                        .cornerRadius(10)
                    }
                }
                
                if showingTestNotificationBanner {
                    Text(testNotificationBannerText)
                        .font(.caption.bold())
                        .foregroundColor(.yellow)
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .background(Color.yellow.opacity(0.12))
                        .cornerRadius(8)
                        .transition(.opacity)
                }
            }
        }
        .premiumCard()
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var languageAndThemeCardView: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "globe")
                        .foregroundColor(Theme.exerciseColor)
                    Text(tr("settings_language"))
                        .font(.subheadline.bold())
                        .foregroundColor(Theme.textPrimary)
                }
                Picker(tr("settings_language"), selection: $appLanguage) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.title).tag(lang.rawValue)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.vertical, 4)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "paintpalette.fill")
                        .foregroundColor(Theme.pulseColor)
                    Text(tr("settings_theme"))
                        .font(.subheadline.bold())
                        .foregroundColor(Theme.textPrimary)
                }
                Picker(tr("settings_theme"), selection: $appTheme) {
                    Text(tr("theme_system")).tag("system")
                    Text(tr("theme_light")).tag("light")
                    Text(tr("theme_dark")).tag("dark")
                }
                .pickerStyle(SegmentedPickerStyle())
            }
        }
        .premiumCard()
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var appleHealthCardView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 255/255, green: 45/255, blue: 85/255), Color(red: 255/255, green: 110/255, blue: 140/255)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    Image(systemName: "heart.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 18))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple Health")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(health.isAuthorized ? Color.green : Color.orange)
                            .frame(width: 6, height: 6)
                        Text(health.isAuthorized ? "Подключено (365 дней авто-синхронизации)" : "Требуется подключение")
                            .font(.caption2.bold())
                            .foregroundColor(health.isAuthorized ? .green : .orange)
                    }
                }
                Spacer()
            }
            
            Text("Автоматическое считывание и запись шагов, активных калорий, пульса, сна, тренировок, воды и веса.")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .lineSpacing(3)
            
            HStack(spacing: 10) {
                Button(action: {
                    if !health.isAuthorized {
                        health.requestAuthorization()
                    } else {
                        health.syncAllWithHaptic()
                    }
                }) {
                    HStack {
                        Image(systemName: health.isAuthorized ? "arrow.clockwise" : "link")
                        Text(health.isAuthorized ? "Синхронизировать" : "Подключить")
                            .font(.subheadline.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .background(Color(red: 255/255, green: 45/255, blue: 85/255))
                    .cornerRadius(14)
                }
                
                Button(action: {
                    health.openSystemSettings()
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.subheadline)
                        .foregroundColor(Theme.textPrimary)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(Theme.cardBackground)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                }
            }
        }
        .premiumCard()
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var appleWatchCardView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 255/255, green: 45/255, blue: 85/255), Color(red: 255/255, green: 94/255, blue: 58/255)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    Image(systemName: "applewatch")
                        .foregroundColor(.white)
                        .font(.system(size: 20))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple Watch")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                    Text("WatchConnectivity • Синхронизация тренировок")
                        .font(.caption2.bold())
                        .foregroundColor(Color(red: 255/255, green: 45/255, blue: 85/255))
                }
                Spacer()
                
                if watchManager.isReachable {
                    Text("НА СВЯЗИ")
                        .font(.caption2.bold())
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.15))
                        .clipShape(Capsule())
                } else if watchManager.isWatchAppInstalled {
                    Text("УСТАНОВЛЕНО")
                        .font(.caption2.bold())
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.cyan.opacity(0.15))
                        .clipShape(Capsule())
                } else {
                    Text("НЕ НАЙДЕНО")
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                }
            }
            
            Text("Приложение Forma для watchOS синхронизирует запуск тренировок, пульс высокой точности, кольца активности и подробные фазы сна (REM, Deep, Core).")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "figure.run.circle.fill")
                        .foregroundColor(.green)
                    Text("Тренировки на часах")
                        .font(.caption2.bold())
                        .foregroundColor(Theme.textPrimary)
                }
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "bed.double.circle.fill")
                        .foregroundColor(.indigo)
                    Text("Фазы сна REM / Deep")
                        .font(.caption2.bold())
                        .foregroundColor(Theme.textPrimary)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(Color.white.opacity(0.04))
            .cornerRadius(10)
        }
        .premiumCard()
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var heartRateCardView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 255/255, green: 59/255, blue: 48/255), Color(red: 255/255, green: 149/255, blue: 0/255)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    Image(systemName: "waveform.path.ecg")
                        .foregroundColor(.white)
                        .font(.system(size: 18))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("hr_monitoring_title"))
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                    Text("AirPods Pro • Bluetooth • HealthKit")
                        .font(.caption2.bold())
                        .foregroundColor(Theme.pulseColor)
                }
                Spacer()
            }
            
            Toggle(isOn: Binding(
                get: { health.isHeartRateMonitoringEnabled },
                set: {
                    health.isHeartRateMonitoringEnabled = $0
                    health.saveLocalData()
                    if $0 { health.setupHeartRateObserver() }
                }
            )) {
                Text(tr("hr_bg_toggle"))
                    .font(.subheadline.bold())
                    .foregroundColor(Theme.textPrimary)
            }
            .tint(.green)
        }
        .premiumCard()
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var liveActivityCardView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0/255, green: 229/255, blue: 255/255), Color(red: 0/255, green: 145/255, blue: 255/255)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    Image(systemName: "circle.circle.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 18))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("live_activity_title"))
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                    Text("Dynamic Island • Lock Screen • StandBy")
                        .font(.caption2.bold())
                        .foregroundColor(Color(red: 0/255, green: 229/255, blue: 255/255))
                }
                
                Spacer()
                
                Toggle("", isOn: $enableHydrationLiveActivity)
                    .labelsHidden()
                    .tint(Color(red: 0/255, green: 229/255, blue: 255/255))
                    .onChange(of: enableHydrationLiveActivity) { _, newValue in
                        HapticManager.shared.impact(.medium)
                        HydrationLiveActivityManager.shared.setLiveActivityEnabled(newValue)
                        if newValue && health.waterConsumed > 0 {
                            HydrationLiveActivityManager.shared.syncHydrationLiveActivity(
                                consumed: health.waterConsumed,
                                goal: health.dynamicWaterGoal,
                                lastBeverage: health.loggedBeveragesToday.last,
                                activeCaffeineMg: health.caffeineActiveInBloodMg,
                                sleepCutoffDate: health.caffeineSleepCutoffDate,
                                needsCaffeineCompensation: health.needsCaffeineWaterCompensation
                            )
                        }
                    }
            }
            
            Text("Автоматически отображать виджет водного баланса и кофеина в Dynamic Island и на экране блокировки после сворачивания приложения.")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .lineSpacing(2)
            
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(enableHydrationLiveActivity ? (liveActivityManager.isLiveActivityActive ? Color.green : Color.cyan) : Color.gray.opacity(0.5))
                        .frame(width: 8, height: 8)
                    
                    Text(enableHydrationLiveActivity ? (liveActivityManager.isLiveActivityActive ? "Активно на экране и в Dynamic Island" : "Включено (активируется при сворачивании)") : "Выключено (островок свободен)")
                        .font(.caption2.bold())
                        .foregroundColor(enableHydrationLiveActivity ? (liveActivityManager.isLiveActivityActive ? .green : .cyan) : Theme.textSecondary)
                }
                
                Spacer()
                
                if liveActivityManager.isLiveActivityActive {
                    Button(action: {
                        HapticManager.shared.impact(.light)
                        HydrationLiveActivityManager.shared.endLiveActivity()
                    }) {
                        Text("Скрыть сейчас")
                            .font(.caption2.bold())
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(6)
                    }
                }
            }
            .padding(.top, 2)
        }
        .premiumCard()
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var waterSettingsCardView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0/255, green: 229/255, blue: 255/255), Color(red: 0/255, green: 122/255, blue: 255/255)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    Image(systemName: "drop.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 18))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Водный баланс и виджеты")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                    Text("Цель на сегодня: \(String(format: "%.1f л", health.effectiveWaterGoal / 1000.0)) • Выпито: \(Int(health.waterConsumed)) мл")
                        .font(.caption2.bold())
                        .foregroundColor(Color(red: 0/255, green: 229/255, blue: 255/255))
                }
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Персональная дневная норма воды:")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                
                HStack(spacing: 8) {
                    ForEach([2000.0, 2500.0, 3000.0, 3500.0, 4000.0], id: \.self) { goal in
                        Button(action: {
                            HapticManager.shared.impact(.medium)
                            health.setWaterGoal(goal)
                        }) {
                            Text(String(format: "%.1fл", goal / 1000.0))
                                .font(.system(size: 13, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(health.waterGoal == goal ? Color(red: 0/255, green: 122/255, blue: 255/255) : Color.primary.opacity(0.06))
                                .foregroundColor(health.waterGoal == goal ? .white : Theme.textPrimary)
                                .cornerRadius(12)
                        }
                    }
                }
            }
            
            Divider().background(Color.white.opacity(0.08))
            
            Toggle(isOn: Binding(
                get: { health.isAdaptiveWaterGoalEnabled },
                set: { health.setWaterGoal(health.waterGoal, isAdaptive: $0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Умная адаптивная норма")
                        .font(.subheadline.bold())
                        .foregroundColor(Theme.textPrimary)
                    Text("Автоматически добавляет норму воды при тренировках, повышенных шагах и компенсирует кофеин.")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .tint(Color(red: 0/255, green: 229/255, blue: 255/255))
            
            Divider().background(Color.white.opacity(0.08))
            
            // Кнопка принудительного обновления виджетов
            Button(action: {
                HapticManager.shared.notification(.success)
                health.saveLocalData()
                health.syncWidgetsData()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    showingWidgetSyncedToast = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation {
                        showingWidgetSyncedToast = false
                    }
                }
            }) {
                HStack {
                    Image(systemName: showingWidgetSyncedToast ? "checkmark.circle.fill" : "arrow.clockwise")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(showingWidgetSyncedToast ? .green : .cyan)
                    Text(showingWidgetSyncedToast ? "Виджеты экрана блокировки синхронизированы!" : "Обновить виджеты экрана блокировки сейчас")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(showingWidgetSyncedToast ? .green : Theme.textPrimary)
                    Spacer()
                }
                .padding(.vertical, 6)
            }
        }
        .premiumCard()
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var coachSelectorCardView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Theme.exerciseColor, Color(red: 0/255, green: 229/255, blue: 255/255)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .foregroundColor(.white)
                        .font(.system(size: 18))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Персональный ИИ-Тренер")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                    Text("Выбран: \(coachManager.currentCoach.badgeEmoji) \(coachManager.currentCoach.name)")
                        .font(.caption2.bold())
                        .foregroundColor(coachManager.currentCoach.accentColor)
                }
                Spacer()
            }
            
            Picker("Категория", selection: $coachGenderFilter) {
                Text("Все (6)").tag("all")
                Text("Мужчины (3)").tag("male")
                Text("Женщины (3)").tag("female")
            }
            .pickerStyle(SegmentedPickerStyle())
            
            let filteredCoaches = coachManager.allCoaches.filter { coach in
                if coachGenderFilter == "male" { return coach.gender == .male }
                if coachGenderFilter == "female" { return coach.gender == .female }
                return true
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(filteredCoaches) { coach in
                        let isSelected = coach.id == coachManager.currentCoach.id
                        let isUnlocked = subscription.isCoachAvailable(coachId: coach.id)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top, spacing: 12) {
                                AITrainerAvatarView(coachState: isSelected ? .exercising : .idle, size: 58, customCoach: coach)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(coach.name)
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(Theme.textPrimary)
                                        Text(coach.badgeEmoji)
                                    }
                                    Text(coach.specialty)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(coach.accentColor)
                                        .lineLimit(1)
                                }
                                Spacer()
                                if !isUnlocked {
                                    HStack(spacing: 2) {
                                        Image(systemName: "crown.fill")
                                            .font(.system(size: 9))
                                        Text("PRO")
                                            .font(.system(size: 9, weight: .heavy))
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.yellow.opacity(0.2))
                                    .foregroundColor(.yellow)
                                    .clipShape(Capsule())
                                } else if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(coach.accentColor)
                                }
                            }
                            
                            Text(coach.shortBio)
                                .font(.system(size: 12))
                                .foregroundColor(Theme.textSecondary)
                                .lineLimit(3)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Text(coach.tagline)
                                .font(.system(size: 11, weight: .semibold))
                                .italic()
                                .foregroundColor(coach.accentColor.opacity(0.9))
                                .lineLimit(1)
                            
                            Divider().background(Color.white.opacity(0.08))
                            
                            HStack(spacing: 8) {
                                Button(action: {
                                    if !isUnlocked {
                                        showingPaywall = true
                                        HapticManager.shared.notification(.warning)
                                    } else {
                                        coachManager.selectCoach(coach)
                                        HapticManager.shared.selection()
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        if !isUnlocked {
                                            Image(systemName: "crown.fill")
                                                .font(.system(size: 11))
                                            Text("PRO 👑")
                                        } else if isSelected {
                                            Image(systemName: "checkmark")
                                            Text("Выбран")
                                        } else {
                                            Text("Выбрать")
                                        }
                                    }
                                    .font(.system(size: 12, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .foregroundColor(isSelected ? .white : (isUnlocked ? coach.accentColor : .yellow))
                                    .background(isSelected ? coach.accentColor : (isUnlocked ? coach.accentColor.opacity(0.12) : Color.yellow.opacity(0.2)))
                                    .cornerRadius(10)
                                }
                                
                                Button(action: {
                                    coachManager.previewCoachVoice(coach, language: appLanguage)
                                }) {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .font(.system(size: 12, weight: .bold))
                                        .padding(8)
                                        .foregroundColor(Theme.textPrimary)
                                        .background(Color.white.opacity(0.08))
                                        .cornerRadius(10)
                                }
                            }
                        }
                        .padding(14)
                        .frame(width: 280)
                        .background(isSelected ? coach.accentColor.opacity(0.08) : Theme.cardBackground)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(isSelected ? coach.accentColor : Color.primary.opacity(0.08), lineWidth: isSelected ? 2 : 1)
                        )
                    }
                }
                .padding(.vertical, 4)
            }
            
            Divider()
                .background(Color.white.opacity(0.08))
            
            // Переключатель озвучки сфотографированной еды голосом тренера
            Toggle(isOn: Binding(
                get: { FormaVoiceCoachManager.shared.isFoodVoiceSpeechEnabled },
                set: { FormaVoiceCoachManager.shared.isFoodVoiceSpeechEnabled = $0 }
            )) {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.and.mic")
                        .foregroundColor(coachManager.currentCoach.accentColor)
                        .font(.subheadline)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Озвучивать блюда голосом \(coachManager.currentCoach.name)")
                            .font(.subheadline.bold())
                            .foregroundColor(Theme.textPrimary)
                        Text("Голосовой вердикт и рекомендации сразу после фото")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
            .tint(coachManager.currentCoach.accentColor)
        }
        .premiumCard()
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var voiceCoachCardView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 255/255, green: 149/255, blue: 0/255), Color(red: 255/255, green: 94/255, blue: 58/255)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    Image(systemName: "headphones")
                        .foregroundColor(.white)
                        .font(.system(size: 18))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("voice_coach_title"))
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                    Text("Голосовые подсказки и озвучка ИИ")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer()
            }
            
            // Голосовой тренер на тренировках
            Toggle(isOn: Binding(
                get: { FormaVoiceCoachManager.shared.isVoiceCoachEnabled },
                set: { FormaVoiceCoachManager.shared.isVoiceCoachEnabled = $0 }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("voice_coach_toggle"))
                        .font(.subheadline.bold())
                        .foregroundColor(Theme.textPrimary)
                    Text("Подсказки темпа, пульса и дистанции во время активности")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .tint(.green)
            
            Divider()
                .background(Color.white.opacity(0.08))
            
            // Озвучка сфотографированной еды ИИ-камерой
            Toggle(isOn: Binding(
                get: { FormaVoiceCoachManager.shared.isFoodVoiceSpeechEnabled },
                set: { FormaVoiceCoachManager.shared.isFoodVoiceSpeechEnabled = $0 }
            )) {
                HStack(spacing: 10) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 18))
                        .foregroundColor(Theme.exerciseColor)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Озвучка распознанной еды")
                            .font(.subheadline.bold())
                            .foregroundColor(Theme.textPrimary)
                        Text("ИИ голосом комментирует блюдо и советы после фото")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
            .tint(Theme.exerciseColor)
        }
        .premiumCard()
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var csvHubCardView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 50/255, green: 215/255, blue: 75/255), Color(red: 0/255, green: 175/255, blue: 110/255)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    Image(systemName: "doc.badge.arrow.up.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 18))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("csv_hub_title"))
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                    Text("Тренировки, Вес, Активность, Питание")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer()
            }
            
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                showingCSVHub = true
            }) {
                HStack {
                    Image(systemName: "folder.fill.badge.plus")
                        .font(.system(size: 14, weight: .bold))
                    Text("Открыть мастер импорта и экспорта")
                        .font(.subheadline.bold())
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                }
                .foregroundColor(Color.green)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(Color.green.opacity(0.12))
                .cornerRadius(12)
            }
        }
        .premiumCard()
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var missionAndStoryCardView: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Шапка: Логотип, Forma и Версия
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    AppLogoView(size: 38)
                    Text("Forma")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                }
                
                Text("Версия 2.5.0 • 2026")
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                
                Spacer()
                
                // ТОЛЬКО ЭТА ОБЛАСТЬ PRO КЛИКАБЕЛЬНА ДЛЯ ВВОДА ПАРОЛЯ 1907
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .foregroundColor(Color(red: 245/255, green: 158/255, blue: 11/255))
                        .font(.system(size: 10))
                    Text("PRO")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(red: 245/255, green: 158/255, blue: 11/255))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(red: 245/255, green: 158/255, blue: 11/255).opacity(0.18))
                .cornerRadius(8)
                .contentShape(Rectangle())
                .onTapGesture {
                    // Окно ввода пароля активно только в TestFlight или DEBUG
                    guard Bundle.main.isTestFlightOrDebug else { return }
                    HapticManager.shared.impact(.medium)
                    enteredPassword = ""
                    showingPasswordPrompt = true
                }
            }
            
            HStack(spacing: 8) {
                // КЛИКАБЕЛЬНЫЙ ЧИП СТАТУСА PRO
                HStack(spacing: 4) {
                    Image(systemName: subscription.isPro ? "crown.fill" : "sparkles")
                        .foregroundColor(subscription.isPro ? .yellow : .purple)
                        .font(.system(size: 10))
                    Text(subscription.isPro ? "PRO Активен" : "Freemium")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(subscription.isPro ? Color.yellow.opacity(0.15) : Color.purple.opacity(0.12))
                .cornerRadius(8)
                .contentShape(Rectangle())
                .onTapGesture {
                    // Окно ввода пароля активно только в TestFlight или DEBUG
                    guard Bundle.main.isTestFlightOrDebug else { return }
                    HapticManager.shared.impact(.medium)
                    enteredPassword = ""
                    showingPasswordPrompt = true
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "hand.raised.slash.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 10))
                    Text("Без рекламы")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.12))
                .cornerRadius(8)
                
                HStack(spacing: 4) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 10))
                    Text("Приватно")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.12))
                .cornerRadius(8)
            }
            
            // Строка разработчика (Samvel)
            HStack {
                Text(appLanguage == "hy" ? "Մշակող" : (appLanguage == "en" ? "Developer" : "Разработчик"))
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Text("Samvel")
                    .font(.caption)
                    .bold()
                    .foregroundColor(Theme.textPrimary)
            }
            
            // Цитата
            Text("«Здоровье и дисциплина — это путь каждого дня. Forma создана, чтобы быть вашим надежным партнером в фитнесе, питании и формировании здоровых привычек.»")
                .font(.caption)
                .italic()
                .foregroundColor(Theme.textSecondary)
                .lineSpacing(3)
                .padding(10)
                .background(Color.white.opacity(0.04))
                .cornerRadius(10)
        }
        .premiumCard()
        .padding(.horizontal)
    }
    
    // MARK: - Обработчик пасхалки «Сейф-маршрут» (Safe Sequence Combination)
    private func handleSafeSequenceStep(_ step: Int) {
        let now = Date()
        // Тайм-аут между шагами: 6 секунд. Если прошло больше — тихий сброс
        if now.timeIntervalSince(secretSafeLastTime) > 6.0 {
            secretSafeStep = 0
        }
        
        if step == secretSafeStep + 1 {
            secretSafeStep = step
            secretSafeLastTime = now
            
            switch step {
            case 1:
                // Шаг 1: мягкий тактильный щелчок поворотного диска
                let g = UIImpactFeedbackGenerator(style: .rigid)
                g.prepare()
                g.impactOccurred(intensity: 0.6)
            case 2:
                // Шаг 2: второй щелчок диска сейфа
                let g = UIImpactFeedbackGenerator(style: .rigid)
                g.prepare()
                g.impactOccurred(intensity: 0.8)
            case 3:
                // Шаг 3: отчетливый щелчок фиксатора замка
                let g = UIImpactFeedbackGenerator(style: .rigid)
                g.prepare()
                g.impactOccurred(intensity: 1.0)
            case 4:
                // Шаг 4: Сейф открыт! Полная разблокировка
                secretSafeStep = 0
                subscription.setDebugPremium(true)
                
                let h = UIImpactFeedbackGenerator(style: .heavy)
                h.prepare()
                h.impactOccurred()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    let n = UINotificationFeedbackGenerator()
                    n.prepare()
                    n.notificationOccurred(.success)
                }
                
                withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                    secretUnlockToast = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    withAnimation {
                        secretUnlockToast = false
                    }
                }
            default:
                break
            }
        } else if step == 1 {
            // Если повторно нажат шаг 1 (Forma) — начинаем новый цикл
            secretSafeStep = 1
            secretSafeLastTime = now
            let g = UIImpactFeedbackGenerator(style: .rigid)
            g.prepare()
            g.impactOccurred(intensity: 0.6)
        } else {
            // Неверный порядок — тихий сброс
            secretSafeStep = 0
        }
    }
    
    // MARK: - Обработчик пароля 1907 для TestFlight
    private func handleTestFlightPassword() {
        guard Bundle.main.isTestFlightOrDebug else {
            enteredPassword = ""
            return
        }
        let clean = enteredPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean == "1907" {
            let newStatus = !subscription.isPro
            subscription.setDebugPremium(newStatus)
            passwordFeedbackTitle = newStatus ? "💎 FORMA PRO Включен" : "🔒 FORMA PRO Отключен"
            passwordFeedbackMessage = newStatus
                ? "Премиум-подписка успешно включена (TestFlight)! Доступны все функции, ИИ-тренеры, безлимитные сканы и неограниченные привычки."
                : "Премиум-подписка отключена. Приложение переведено в базовый режим Freemium."
            HapticManager.shared.notification(.success)
            showingPasswordFeedback = true
        } else {
            passwordFeedbackTitle = "Ошибка доступа"
            passwordFeedbackMessage = "Введен неверный пароль. Доступ к переключению подписки отклонен."
            HapticManager.shared.notification(.error)
            showingPasswordFeedback = true
        }
        enteredPassword = ""
    }
    
    // MARK: - Тост разблокировки PRO («Сейф Forma открыт»)
    private var secretUnlockToastView: some View {
        HStack(spacing: 12) {
            Text("👑")
                .font(.system(size: 26))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(appLanguage == "hy" ? "Forma-ի գաղտնիքը բացված է!" : (appLanguage == "en" ? "Forma Safe Secret Unlocked!" : "Секрет сейфа Forma раскрыт!"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                
                Text(appLanguage == "hy" ? "Դուք գտաք հեղինակի գաղտնիքը: Ցմահ PRO ակտիվ է ✓" : (appLanguage == "en" ? "You cracked the creator's secret. Lifetime PRO active ✓" : "Вы разгадали пасхалку создателя. Пожизненный PRO активен ✓"))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.9))
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 245/255, green: 158/255, blue: 11/255), Color(red: 217/255, green: 119/255, blue: 6/255)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: Color(red: 245/255, green: 158/255, blue: 11/255).opacity(0.45), radius: 10)
        )
    }
    
    @ViewBuilder
    private var complianceAndLegalCardView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "hand.raised.square.on.square.fill")
                    .foregroundColor(.blue)
                Text("Управление данными и безопасность")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
            }
            
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.subheadline)
                Text("Медицинский дисклеймер: Приложение Forma не является медицинским изделием и не заменяет консультацию квалифицированного врача. Все советы ИИ носят исключительно информационно-мотивационный характер. Всегда консультируйтесь с врачом перед началом новых тренировок или изменением диеты.")
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
                    .lineSpacing(2)
            }
            .padding(10)
            .background(Color.orange.opacity(0.08))
            .cornerRadius(10)
            
            // Раскрытие обработки данных ИИ и согласие (Guidelines 5.1.1(i) & 5.1.2(i))
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundColor(Theme.aiAccent)
                        .font(.caption)
                    Text("Сторонний ИИ (Google Gemini API)")
                        .font(.caption.bold())
                        .foregroundColor(Theme.textPrimary)
                }
                
                Text("Запросы анализа питания и диалоги с тренером передаются в Google LLC через защищенный протокол TLS/HTTPS без персональных идентификаторов (без имени, email и геолокации).")
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
                    .lineSpacing(2)
                
                Toggle(isOn: $userConsentedToAISharing) {
                    Text("Разрешить анализ данных через ИИ")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                }
                .tint(Theme.aiAccent)
                
                Button(action: {
                    showingAIConsentSheet = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                        Text("Подробнее о безопасности и передаче данных")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.aiAccent)
                }
            }
            .padding(12)
            .background(Theme.aiAccent.opacity(0.08))
            .cornerRadius(12)
            
            // Конфиденциальность Apple Health
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(Theme.pulseColor)
                        .font(.caption)
                    Text("Конфиденциальность Apple HealthKit")
                        .font(.caption.bold())
                        .foregroundColor(Theme.textPrimary)
                }
                Text("Данные здоровья хранятся локально на устройстве и в вашем iCloud. Данные HealthKit никогда не используются для рекламы или data mining.")
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
                    .lineSpacing(2)
            }
            .padding(10)
            .background(Theme.pulseColor.opacity(0.06))
            .cornerRadius(10)
            
            VStack(spacing: 8) {
                // Научные источники и цитаты (Guideline 1.4.1)
                Button(action: {
                    showingMedicalSources = true
                }) {
                    HStack {
                        Image(systemName: "cross.case.fill")
                            .foregroundColor(.blue)
                        Text("Научные источники и методология (Citations)")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                    .font(.subheadline)
                    .foregroundColor(Theme.textPrimary)
                    .padding(12)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(10)
                }
                
                Link(destination: URL(string: "https://samjan190799-cmyk.github.io/SamHealth/privacy.html") ?? URL(string: "https://apple.com")!) {
                    HStack {
                        Image(systemName: "lock.doc.fill")
                        Text("Политика конфиденциальности (Privacy Policy)")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                    }
                    .font(.subheadline)
                    .foregroundColor(Theme.textPrimary)
                    .padding(12)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(10)
                }
                
                Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                        Text("Условия использования (EULA)")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                    }
                    .font(.subheadline)
                    .foregroundColor(Theme.textPrimary)
                    .padding(12)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(10)
                }
            }
            
            // Кнопка удаления всех данных (Apple Guideline 5.1.1)
            Button(action: {
                showingResetDataAlert = true
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "trash.fill")
                        .foregroundColor(.red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Удалить все данные приложения (Data Deletion)")
                            .font(.subheadline.bold())
                            .foregroundColor(.red)
                        Text("Безвозвратное удаление локального профиля, журнала и кэша")
                            .font(.caption2)
                            .foregroundColor(.red.opacity(0.8))
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color.red.opacity(0.08))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.25), lineWidth: 1)
                )
            }
        }
        .premiumCard()
        .padding(.horizontal)
        .padding(.bottom, 100)
    }
    
    // MARK: - Инженерная панель монетизации (Яндекс РСЯ + AppLovin MAX) (TestFlight / Debug)
    @ViewBuilder
    private var hybridAdDeveloperCardView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(colors: [Color.blue, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 32, height: 32)
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Гибридная реклама (Ads Hub)")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Theme.textPrimary)
                        
                        Text("DEV")
                            .font(.system(size: 9, weight: .heavy))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .clipShape(Capsule())
                    }
                    Text("Панель разработчика: Яндекс РСЯ + AppLovin")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $adManager.isAdsEnabled)
                    .labelsHidden()
            }
            
            Divider()
                .background(Color.primary.opacity(0.06))
            
            // Гео-маршрутизация и активная сеть
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Гео-маршрутизация:")
                        .font(.caption.bold())
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                    Text("Регион: \(adManager.detectedRegionCode)")
                        .font(.caption.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.12))
                        .foregroundColor(.blue)
                        .cornerRadius(6)
                }
                
                HStack {
                    Text("Активная сеть:")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: adManager.activeProviderType.icon)
                        Text(adManager.activeProviderType.rawValue)
                    }
                    .font(.caption.bold())
                    .foregroundColor(adManager.activeProviderType == .yandex ? .orange : .green)
                }
            }
            
            Divider()
                .background(Color.primary.opacity(0.06))
            
            // Статус Apple ATT
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Статус Apple ATT:")
                        .font(.caption.bold())
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                    switch adManager.trackingStatus {
                    case .authorized:
                        Text("Разрешено ✅")
                            .font(.caption.bold())
                            .foregroundColor(.green)
                    case .denied, .restricted:
                        Text("Запрещено ❌")
                            .font(.caption.bold())
                            .foregroundColor(.red)
                    case .notDetermined:
                        Text("Не запрошено ⏳")
                            .font(.caption.bold())
                            .foregroundColor(.orange)
                    @unknown default:
                        Text("Неизвестно")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                
                if adManager.trackingStatus == .notDetermined {
                    Button(action: {
                        Task {
                            await adManager.requestTrackingAuthorizationAndInitialize()
                        }
                    }) {
                        HStack {
                            Image(systemName: "hand.raised.fill")
                            Text("Запросить согласие на отслеживание (ATT)")
                        }
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.12))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    }
                }
            }
            
            // Переключатель тестового режима
            Toggle("Тестовый режим (Test Mode)", isOn: $adManager.isTestMode)
                .font(.caption)
            
            // Аналитика показов и кликов
            VStack(spacing: 8) {
                HStack {
                    Text("Аналитика показов в приложении:")
                        .font(.caption.bold())
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                    Button("Сбросить") {
                        adManager.resetStats()
                    }
                    .font(.caption2)
                    .foregroundColor(.red)
                }
                
                HStack(spacing: 8) {
                    adStatMiniCard(title: "Показов", value: "\(adManager.totalImpressions)", icon: "eye.fill", color: .blue)
                    adStatMiniCard(title: "Кликов", value: "\(adManager.totalClicks)", icon: "hand.tap.fill", color: .green)
                    adStatMiniCard(title: "CTR", value: String(format: "%.1f%%", adManager.ctrPercentage), icon: "chart.line.uptrend.xyaxis", color: .orange)
                }
            }
        }
        .premiumCard()
        .padding(.horizontal)
    }
    
    private func adStatMiniCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textSecondary)
            }
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(10)
    }
}

// Компонент поля ввода API ключа с кнопкой показать/скрыть
struct APIKeyField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    @State private var showKey = false
    var onCommit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption2.bold())
                .foregroundColor(Theme.textSecondary)
            
            HStack {
                if showKey {
                    TextField(placeholder, text: $text, onCommit: onCommit)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.none)
                } else {
                    SecureField(placeholder, text: $text, onCommit: onCommit)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.none)
                }
                
                Button(action: {
                    showKey.toggle()
                }) {
                    Image(systemName: showKey ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .padding()
            .background(Color.primary.opacity(0.06))
            .cornerRadius(12)
            .foregroundColor(Theme.textPrimary)
        }
    }
}
