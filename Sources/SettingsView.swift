import SwiftUI

struct SettingsView: View {
    @AppStorage("app_language") private var appLanguage = "ru"
    @AppStorage("app_theme") private var appTheme = "system"
    
    // API ключи
    @AppStorage("api_key_gemini") private var apiKeyGemini = ""
    @AppStorage("api_key_openai") private var apiKeyOpenAI = ""
    @AppStorage("api_key_claude") private var apiKeyClaude = ""
    
    @EnvironmentObject var health: HealthKitManager
    
    // Вспомогательный перевод для локальных строк настроек
    private func tr(_ key: String) -> String {
        LocalizationManager.tr(key, lang: appLanguage)
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

                    
                    // 3. НАСТРОЙКИ API КЛЮЧЕЙ
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
                            // Gemini
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Google Gemini Key")
                                    .font(.caption2)
                                    .bold()
                                    .foregroundColor(Theme.textSecondary)
                                SecureField("AIzaSy...", text: $apiKeyGemini)
                                    .padding()
                                    .background(Color.primary.opacity(0.06))
                                    .cornerRadius(12)
                                    .foregroundColor(Theme.textPrimary)
                            }
                            
                            // OpenAI
                            VStack(alignment: .leading, spacing: 6) {
                                Text("OpenAI ChatGPT Key")
                                    .font(.caption2)
                                    .bold()
                                    .foregroundColor(Theme.textSecondary)
                                SecureField("sk-proj-...", text: $apiKeyOpenAI)
                                    .padding()
                                    .background(Color.primary.opacity(0.06))
                                    .cornerRadius(12)
                                    .foregroundColor(Theme.textPrimary)
                            }
                            
                            // Claude
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Anthropic Claude Key")
                                    .font(.caption2)
                                    .bold()
                                    .foregroundColor(Theme.textSecondary)
                                SecureField("sk-ant-...", text: $apiKeyClaude)
                                    .padding()
                                    .background(Color.primary.opacity(0.06))
                                    .cornerRadius(12)
                                    .foregroundColor(Theme.textPrimary)
                            }
                        }
                    }
                    .premiumCard()
                    .padding(.horizontal)
                    
                    // 4. ЯЗЫК И ТЕМА
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
                    
                    // 5. О ПРИЛОЖЕНИИ
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
    }
}
