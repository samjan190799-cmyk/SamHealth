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
    
    // Локальные переменные для ввода профиля
    @State private var localAge = ""
    @State private var localHeight = ""
    @State private var localWeight = ""
    @State private var localTargetWeight = ""
    @State private var showingHealthSyncHub = false
    
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
            // Сохраняем вес также в историю здоровья
            health.addWeight(weight: w)
        }
    }
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Заголовок
                    HStack {
                        Text(tr("settings_title"))
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    
                    // 1. КАРТОЧКА МОЙ ПРОФИЛЬ
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundColor(Theme.exerciseColor)
                            Text("Личный профиль")
                                .font(.headline)
                                .foregroundColor(Theme.textPrimary)
                        }
                        
                        VStack(spacing: 12) {
                            // Пол
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
                            
                            // Возраст
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
                            
                            // Рост
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
                            
                            // Текущий вес
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
                            }
                            
                            Divider()
                            
                            // Целевой вес
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
                            }
                            
                            Divider()
                            
                            // Активность
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
                    
                    // 2. НАСТРОЙКИ API КЛЮЧЕЙ
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
                            APIKeyField(label: "Google Gemini Key", placeholder: "AIzaSy...", text: $localGeminiKey) {
                                saveGeminiKey()
                            }
                            .onChange(of: localGeminiKey) { _, _ in saveGeminiKey() }
                            
                            APIKeyField(label: "OpenAI ChatGPT Key", placeholder: "sk-proj-...", text: $localOpenAIKey) {
                                saveOpenAIKey()
                            }
                            .onChange(of: localOpenAIKey) { _, _ in saveOpenAIKey() }
                            
                            APIKeyField(label: "Anthropic Claude Key", placeholder: "sk-ant-...", text: $localClaudeKey) {
                                saveClaudeKey()
                            }
                            .onChange(of: localClaudeKey) { _, _ in saveClaudeKey() }
                        }
                    }
                    .premiumCard()
                    .padding(.horizontal)
                    
                    // 2.5. ФОНОВЫЙ ШАГОМЕР И ЦЕЛИ
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "figure.walk.motion")
                                .foregroundColor(Color(red: 255/255, green: 149/255, blue: 0/255))
                                .font(.headline)
                            Text(tr("settings_step_section"))
                                .font(.headline)
                                .foregroundColor(Theme.textPrimary)
                        }
                        
                        // Выбор дневной цели шагов
                        VStack(alignment: .leading, spacing: 8) {
                            Text(tr("settings_step_goal"))
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(Theme.textPrimary)
                            
                            Picker(tr("settings_step_goal"), selection: Binding(
                                get: { stepManager.stepGoal },
                                set: { stepManager.setStepGoal($0) }
                            )) {
                                Text("6 000").tag(6000)
                                Text("8 000").tag(8000)
                                Text("10 000").tag(10000)
                                Text("12 000").tag(12000)
                                Text("15 000").tag(15000)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.vertical, 2)
                        
                        // Тумблер фонового трекинга
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle(isOn: Binding(
                                get: { stepManager.isBackgroundTrackingEnabled },
                                set: { stepManager.toggleBackgroundTracking($0) }
                            )) {
                                Text(tr("settings_step_bg_toggle"))
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundColor(Theme.textPrimary)
                            }
                            .tint(.green)
                            
                            Text(tr("settings_step_bg_desc"))
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                                .lineSpacing(2)
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.vertical, 2)
                        
                        // Тумблер мотивационных уведомлений
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle(isOn: Binding(
                                get: { stepManager.notificationsEnabled },
                                set: { stepManager.toggleNotifications($0) }
                            )) {
                                Text(tr("settings_step_notif_toggle"))
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundColor(Theme.textPrimary)
                            }
                            .tint(.green)
                            
                            Text(tr("settings_step_notif_desc"))
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                                .lineSpacing(2)
                        }
                        
                        if let lastSync = stepManager.lastSyncTime {
                            Text(String(format: tr("settings_step_last_sync"), formatSyncTime(lastSync)))
                                .font(.caption2)
                                .foregroundColor(Theme.textSecondary.opacity(0.8))
                                .padding(.top, 2)
                        }
                    }
                    .premiumCard()
                    .padding(.horizontal)
                    
                    // 3. ЯЗЫК И ТЕМА
                    VStack(alignment: .leading, spacing: 16) {
                        // Язык
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "globe")
                                    .foregroundColor(Theme.exerciseColor)
                                Text(tr("settings_language"))
                                    .font(.subheadline)
                                    .bold()
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
                        
                        // Тема
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "paintpalette.fill")
                                    .foregroundColor(Theme.pulseColor)
                                Text(tr("settings_theme"))
                                    .font(.subheadline)
                                    .bold()
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
                    // 3.5. СИНХРОНИЗАЦИЯ С APPLE HEALTH
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 255/255, green: 45/255, blue: 85/255),
                                                Color(red: 255/255, green: 90/255, blue: 120/255)
                                            ],
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
                                Text(tr("health_kit_title"))
                                    .font(.headline)
                                    .foregroundColor(Theme.textPrimary)
                                
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(health.isAuthorized ? Color.green : Color.orange)
                                        .frame(width: 6, height: 6)
                                    
                                    Text(health.isAuthorized ? tr("health_kit_connected") : tr("health_kit_connect_banner_title"))
                                        .font(.caption2)
                                        .bold()
                                        .foregroundColor(health.isAuthorized ? .green : .orange)
                                }
                            }
                            
                            Spacer()
                        }
                        
                        Text(tr("health_kit_connect_banner_desc"))
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                            .lineSpacing(3)
                        
                        if health.isAuthorized {
                            VStack(spacing: 10) {
                                Button(action: {
                                    let impact = UIImpactFeedbackGenerator(style: .medium)
                                    impact.impactOccurred()
                                    showingHealthSyncHub = true
                                }) {
                                    HStack {
                                        Image(systemName: "slider.horizontal.3")
                                        Text(tr("health_kit_sync_hub"))
                                            .bold()
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .foregroundColor(.white)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 16)
                                    .background(Color.green)
                                    .cornerRadius(14)
                                    .shadow(color: Color.green.opacity(0.3), radius: 6)
                                }
                                
                                Button(action: {
                                    health.syncAllWithHaptic()
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                        Text(health.isSyncing ? tr("health_kit_syncing") : tr("health_kit_sync_now"))
                                            .font(.subheadline)
                                            .bold()
                                    }
                                    .frame(maxWidth: .infinity)
                                    .foregroundColor(Theme.textPrimary)
                                    .padding(.vertical, 10)
                                    .background(Theme.cardBackground)
                                    .cornerRadius(14)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                    )
                                }
                                .disabled(health.isSyncing)
                            }
                        } else {
                            Button(action: {
                                let impact = UIImpactFeedbackGenerator(style: .medium)
                                impact.impactOccurred()
                                health.requestAuthorization()
                            }) {
                                HStack {
                                    Image(systemName: "heart.fill")
                                    Text(tr("health_kit_connect_btn"))
                                        .bold()
                                }
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.white)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 255/255, green: 45/255, blue: 85/255),
                                            Color(red: 255/255, green: 80/255, blue: 110/255)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(16)
                                .shadow(color: Color(red: 255/255, green: 45/255, blue: 85/255).opacity(0.3), radius: 8)
                            }
                        }
                        
                        if let error = health.authorizationError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(Theme.pulseColor)
                                .padding(.top, 4)
                        }
                    }
                    .premiumCard()
                    .padding(.horizontal)
                    
                    // 3.6. МОНИТОРИНГ ПУЛЬСА (AIRPODS PRO / ДАТЧИКИ)
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 255/255, green: 59/255, blue: 48/255),
                                                Color(red: 255/255, green: 149/255, blue: 0/255)
                                            ],
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
                                
                                Text("AirPods Pro 3 • Bluetooth • HealthKit")
                                    .font(.caption2)
                                    .bold()
                                    .foregroundColor(Theme.pulseColor)
                            }
                            
                            Spacer()
                        }
                        
                        Text(tr("hr_monitoring_desc"))
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                            .lineSpacing(3)
                        
                        // Текущий статус пульса
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Текущий пульс")
                                    .font(.caption2)
                                    .foregroundColor(Theme.textSecondary)
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text(health.heartRate > 0 ? "\(health.heartRate)" : "70")
                                        .font(.system(size: 24, weight: .bold, design: .rounded))
                                        .foregroundColor(Theme.textPrimary)
                                    Text("уд/мин")
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                }
                            }
                            
                            Spacer()
                            
                            // Зона пульса
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Пульсовая зона")
                                    .font(.caption2)
                                    .foregroundColor(Theme.textSecondary)
                                Text(health.heartRateZone.rawValue)
                                    .font(.system(size: 13, weight: .bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(health.heartRateZone.color.opacity(0.15))
                                    .foregroundColor(health.heartRateZone.color)
                                    .cornerRadius(8)
                            }
                        }
                        .padding(12)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(14)
                        
                        Divider()
                            .background(Color.white.opacity(0.1))
                        
                        // Тумблер фонового мониторинга
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle(isOn: Binding(
                                get: { health.isHeartRateMonitoringEnabled },
                                set: { 
                                    health.isHeartRateMonitoringEnabled = $0
                                    health.saveLocalData()
                                    if $0 { health.setupHeartRateObserver() }
                                }
                            )) {
                                Text(tr("hr_bg_toggle"))
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundColor(Theme.textPrimary)
                            }
                            .tint(.green)
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.1))
                        
                        // Оповещения о высоком пульсе в покое
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle(isOn: Binding(
                                get: { health.heartRateAlertsEnabled },
                                set: {
                                    health.heartRateAlertsEnabled = $0
                                    health.saveLocalData()
                                }
                            )) {
                                Text(tr("hr_high_alert_toggle"))
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundColor(Theme.textPrimary)
                            }
                            .tint(.red)
                            
                            if health.heartRateAlertsEnabled {
                                HStack {
                                    Text(tr("hr_high_threshold"))
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                    Spacer()
                                    Picker(tr("hr_high_threshold"), selection: Binding(
                                        get: { health.highHeartRateThreshold },
                                        set: {
                                            health.highHeartRateThreshold = $0
                                            health.saveLocalData()
                                        }
                                    )) {
                                        Text("> 100").tag(100)
                                        Text("> 105").tag(105)
                                        Text("> 110").tag(110)
                                        Text("> 115").tag(115)
                                        Text("> 120").tag(120)
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                }
                                .padding(.horizontal, 4)
                            }
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.1))
                        
                        // Уведомления о восстановлении
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle(isOn: Binding(
                                get: { health.recoveryAlertsEnabled },
                                set: {
                                    health.recoveryAlertsEnabled = $0
                                    health.saveLocalData()
                                }
                            )) {
                                Text(tr("hr_recovery_toggle"))
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundColor(Theme.textPrimary)
                            }
                            .tint(.green)
                        }
                    }
                    .premiumCard()
                    .padding(.horizontal)
                    
                    // 4. О ПРИЛОЖЕНИИ
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            AppLogoView(size: 28)
                            Text(tr("settings_about"))
                                .font(.headline)
                                .foregroundColor(Theme.textPrimary)
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.vertical, 4)
                        
                        Text(tr("settings_developer"))
                            .font(.subheadline)
                            .foregroundColor(Theme.textPrimary.opacity(0.8))
                        
                        Text("Версия: 2.5.0")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        
                        Text(tr("settings_about_desc"))
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                            .lineSpacing(3)
                            .padding(.top, 4)
                    }
                    .premiumCard()
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .sheet(isPresented: $showingHealthSyncHub) {
                HealthKitSyncHubView()
                    .environmentObject(health)
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
                .font(.caption2)
                .bold()
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
