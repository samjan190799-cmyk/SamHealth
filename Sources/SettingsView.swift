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
    
    @EnvironmentObject var health: HealthKitManager
    
    // Вспомогательный перевод для локальных строк настроек
    private func tr(_ key: String) -> String {
        LocalizationManager.tr(key, lang: appLanguage)
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
