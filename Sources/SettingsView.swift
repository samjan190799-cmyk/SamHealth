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
    
    // Умные напоминания от ИИ-тренера
    @AppStorage("notifications_meal_enabled") private var notificationsMealEnabled = true
    @AppStorage("notifications_water_enabled") private var notificationsWaterEnabled = true
    @AppStorage("notifications_activity_enabled") private var notificationsActivityEnabled = true
    @AppStorage("notifications_random_time_enabled") private var notificationsRandomTimeEnabled = true
    @AppStorage("notifications_start_hour") private var notificationsStartHour = 9
    @AppStorage("notifications_end_hour") private var notificationsEndHour = 21
    @AppStorage("notifications_frequency_per_day") private var notificationsFrequencyPerDay = 5
    @State private var showingTestNotificationBanner = false
    @State private var testNotificationBannerText = ""
    
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
    
    @ObservedObject private var coachManager = AICoachManager.shared
    @ObservedObject private var subscription = SubscriptionManager.shared
    @State private var showingPaywall = false
    @State private var coachGenderFilter: String = "all"
    
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
        if let age = Int(localAge) {
            userAge = age
        }
        if let height = Int(localHeight) {
            userHeight = height
        }
        if let targetW = Double(localTargetWeight.replacingOccurrences(of: ",", with: ".")) {
            userTargetWeight = targetW
        }
        if let w = Double(localWeight.replacingOccurrences(of: ",", with: ".")) {
            userWeight = w
            health.addWeight(weight: w)
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
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    headerView
                    formaProBannerView
                    profileCardView
                    apiKeyCardView
                    notificationsCardView
                    languageAndThemeCardView
                    appleHealthCardView
                    heartRateCardView
                    liveActivityCardView
                    coachSelectorCardView
                    voiceCoachCardView
                    csvHubCardView
                    missionAndStoryCardView
                    complianceAndLegalCardView
                }
            }
            .alert("Очистить все данные?", isPresented: $showingResetDataAlert) {
                Button("Отмена", role: .cancel) { }
                Button("Очистить", role: .destructive) {
                    UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
                    HapticManager.shared.notification(.success)
                }
            } message: {
                Text("Все локальные настройки, кэш и журнал привычек будут сброшены. Данные в Apple Health останутся нетронутыми.")
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
            saveGeminiKey()
            saveOpenAIKey()
            saveClaudeKey()
            saveProfile()
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
                            Text(OpenAIScanService.shared.activeOpenAIModel)
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                    if !apiKeyClaude.isEmpty {
                        HStack {
                            Text("Claude:")
                                .font(.caption2.bold())
                                .foregroundColor(Theme.textSecondary)
                            Text(ClaudeScanService.shared.activeClaudeModel)
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
                            Text("Тест: Еда")
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
                            Text("Тест: Вода")
                        }
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.8))
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
                Text("ВКЛ")
                    .font(.caption.bold())
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.12))
                    .cornerRadius(8)
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
                    Text("Голосовые подсказки во время тренировок")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer()
            }
            
            Toggle(isOn: Binding(
                get: { FormaVoiceCoachManager.shared.isVoiceCoachEnabled },
                set: { FormaVoiceCoachManager.shared.isVoiceCoachEnabled = $0 }
            )) {
                Text(tr("voice_coach_toggle"))
                    .font(.subheadline.bold())
                    .foregroundColor(Theme.textPrimary)
            }
            .tint(.green)
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
            HStack(spacing: 12) {
                AppLogoView(size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Forma")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                    Text("Версия 2.5.0 • 2026")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer()
            }
            
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.purple)
                        .font(.system(size: 10))
                    Text("Freemium")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.purple.opacity(0.12))
                .cornerRadius(8)
                
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
    
    @ViewBuilder
    private var complianceAndLegalCardView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "hand.raised.square.on.square.fill")
                    .foregroundColor(.blue)
                Text("Правовая информация и безопасность")
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
            
            VStack(spacing: 8) {
                Link(destination: URL(string: "https://samjan190799-cmyk.github.io/privacy.html") ?? URL(string: "https://apple.com")!) {
                    HStack {
                        Image(systemName: "lock.doc.fill")
                        Text("Политика конфиденциальности")
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
            
            Button(action: {
                showingResetDataAlert = true
            }) {
                HStack {
                    Image(systemName: "trash.fill")
                        .foregroundColor(.red)
                    Text("Очистить все локальные данные")
                        .foregroundColor(.red)
                    Spacer()
                }
                .font(.subheadline.bold())
                .padding(12)
                .background(Color.red.opacity(0.08))
                .cornerRadius(10)
            }
        }
        .premiumCard()
        .padding(.horizontal)
        .padding(.bottom, 100)
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
