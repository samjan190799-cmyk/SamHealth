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
    @State private var showingCSVHub = false
    
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
                    HStack(spacing: 12) {
                        AppLogoView(size: 34)
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
                               // 3.5. ЛОКАЛЬНЫЕ ДАННЫЕ И КЭШ
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0/255, green: 229/255, blue: 255/255),
                                                Color(red: 0/255, green: 140/255, blue: 255/255)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 36, height: 36)
                                
                                Image(systemName: "internaldrive.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 18))
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Локальное хранилище")
                                    .font(.headline)
                                    .foregroundColor(Theme.textPrimary)
                                
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 6, height: 6)
                                    
                                    Text("Активно (100% Автономно)")
                                        .font(.caption2)
                                        .bold()
                                        .foregroundColor(.green)
                                }
                            }
                            
                            Spacer()
                        }
                        
                        Text("Все показатели шагов, тренировок, воды и питания сохраняются локально на вашем устройстве с шифрованием.")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                            .lineSpacing(3)
                        
                        Button(action: {
                            health.syncAllWithHaptic()
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Обновить локальные данные")
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
                    
                    // 3.7. LIVE ACTIVITY & DYNAMIC ISLAND
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0/255, green: 229/255, blue: 255/255),
                                                Color(red: 0/255, green: 145/255, blue: 255/255)
                                            ],
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
                                    .font(.caption2)
                                    .bold()
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
                        
                        Text(tr("live_activity_desc"))
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                            .lineSpacing(3)
                        
                        HStack {
                            Label("Синхронизация в реальном времени", systemImage: "bolt.fill")
                                .font(.caption2.bold())
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                            Text(tr("live_activity_status_ready"))
                                .font(.caption2.bold())
                                .foregroundColor(.green)
                        }
                        .padding(10)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(10)
                    }
                    .premiumCard()
                    .padding(.horizontal)
                    
                    // 3.8. ГОЛОСОВОЙ ИИ-ТРЕНЕР (AUDIO COACHING)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 255/255, green: 149/255, blue: 0/255),
                                                Color(red: 255/255, green: 204/255, blue: 0/255)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 36, height: 36)
                                
                                Image(systemName: "waveform.circle.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 18))
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tr("voice_coach_title"))
                                    .font(.headline)
                                    .foregroundColor(Theme.textPrimary)
                                
                                Text("Тренер Алекс • AirPods Audio Ducking")
                                    .font(.caption2)
                                    .bold()
                                    .foregroundColor(.orange)
                            }
                            
                            Spacer()
                        }
                        
                        Text(tr("voice_coach_desc"))
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                            .lineSpacing(3)
                        
                        VStack(spacing: 12) {
                            Toggle(isOn: Binding(
                                get: { FormaVoiceCoachManager.shared.isVoiceCoachEnabled },
                                set: { FormaVoiceCoachManager.shared.isVoiceCoachEnabled = $0 }
                            )) {
                                Text(tr("voice_coach_toggle"))
                                    .font(.subheadline.bold())
                                    .foregroundColor(Theme.textPrimary)
                            }
                            .tint(.green)
                            
                            if FormaVoiceCoachManager.shared.isVoiceCoachEnabled {
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                
                                Toggle(isOn: Binding(
                                    get: { FormaVoiceCoachManager.shared.announceKilometers },
                                    set: { FormaVoiceCoachManager.shared.announceKilometers = $0 }
                                )) {
                                    Text(tr("voice_coach_splits"))
                                        .font(.subheadline)
                                        .foregroundColor(Theme.textPrimary)
                                }
                                .tint(.green)
                                
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                
                                Toggle(isOn: Binding(
                                    get: { FormaVoiceCoachManager.shared.announceTimeIntervals },
                                    set: { FormaVoiceCoachManager.shared.announceTimeIntervals = $0 }
                                )) {
                                    Text(tr("voice_coach_intervals"))
                                        .font(.subheadline)
                                        .foregroundColor(Theme.textPrimary)
                                }
                                .tint(.green)
                                
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                
                                Toggle(isOn: Binding(
                                    get: { FormaVoiceCoachManager.shared.announceHeartRateAlerts },
                                    set: { FormaVoiceCoachManager.shared.announceHeartRateAlerts = $0 }
                                )) {
                                    Text(tr("voice_coach_hr_alerts"))
                                        .font(.subheadline)
                                        .foregroundColor(Theme.textPrimary)
                                }
                                .tint(.green)
                            }
                        }
                        .padding(.top, 4)
                    }
                    .premiumCard()
                    .padding(.horizontal)
                    
                    // 3.8. ИМПОРТ И ЭКСПОРТ CSV (Apple Health / Таблицы)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 50/255, green: 215/255, blue: 75/255),
                                                Color(red: 0/255, green: 175/255, blue: 110/255)
                                            ],
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
                        
                        Text(tr("csv_hub_desc"))
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                            .lineSpacing(3)
                        
                        Button(action: {
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                            showingCSVHub = true
                        }) {
                            HStack {
                                Image(systemName: "folder.fill.badge.plus")
                                    .font(.system(size: 14, weight: .bold))
                                Text("Открыть мастер импорта и экспорта")
                                    .font(.subheadline)
                                    .bold()
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
                    
                    // 4. О ПРИЛОЖЕНИИ
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            AppLogoView(size: 36)
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
                    .padding(.bottom, 100)
                }
            }
            .sheet(isPresented: $showingHealthSyncHub) {
                HealthKitSyncHubView()
                    .environmentObject(health)
            }
            .sheet(isPresented: $showingCSVHub) {
                HealthDataCSVImportSheet()
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
