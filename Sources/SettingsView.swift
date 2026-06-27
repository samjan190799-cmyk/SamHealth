import SwiftUI

struct SettingsView: View {
    @AppStorage("app_language") private var appLanguage = "ru"
    @AppStorage("app_theme") private var appTheme = "system"
    @AppStorage("api_key_gemini") private var apiKeyGemini = ""
    @EnvironmentObject var health: HealthKitManager
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Заголовок
                    HStack {
                        Text(LocalizationManager.tr("settings_title", lang: appLanguage))
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    
                    // 1. ЯЗЫК ИНТЕРФЕЙСА
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(Theme.exerciseColor)
                            Text(LocalizationManager.tr("settings_language", lang: appLanguage))
                                .font(.headline)
                                .foregroundColor(Theme.textPrimary)
                        }
                        
                        Picker(LocalizationManager.tr("settings_language", lang: appLanguage), selection: $appLanguage) {
                            ForEach(AppLanguage.allCases) { lang in
                                Text(lang.title).tag(lang.rawValue)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    .premiumCard()
                    .padding(.horizontal)
                    
                    // 2. ТЕМА ОФОРМЛЕНИЯ
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Image(systemName: "paintpalette.fill")
                                .foregroundColor(Theme.pulseColor)
                            Text(LocalizationManager.tr("settings_theme", lang: appLanguage))
                                .font(.headline)
                                .foregroundColor(Theme.textPrimary)
                        }
                        
                        Picker(LocalizationManager.tr("settings_theme", lang: appLanguage), selection: $appTheme) {
                            Text(LocalizationManager.tr("theme_system", lang: appLanguage)).tag("system")
                            Text(LocalizationManager.tr("theme_light", lang: appLanguage)).tag("light")
                            Text(LocalizationManager.tr("theme_dark", lang: appLanguage)).tag("dark")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    .premiumCard()
                    .padding(.horizontal)
                    
                    // 3. СБРОС КЛЮЧА GEMINI API
                    if !apiKeyGemini.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Image(systemName: "key.fill")
                                    .foregroundColor(.yellow)
                                Text("Gemini API")
                                    .font(.headline)
                                    .foregroundColor(Theme.textPrimary)
                            }
                            
                            Button(action: {
                                let impact = UIImpactFeedbackGenerator(style: .heavy)
                                impact.impactOccurred()
                                apiKeyGemini = ""
                            }) {
                                Text(LocalizationManager.tr("settings_reset_api", lang: appLanguage))
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Theme.pulseColor)
                                    .cornerRadius(16)
                                    .shadow(color: Theme.pulseColor.opacity(0.3), radius: 6)
                            }
                        }
                        .premiumCard()
                        .padding(.horizontal)
                    }
                    
                    // 4. О ПРИЛОЖЕНИИ
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(Theme.sleepColor)
                            Text(LocalizationManager.tr("settings_about", lang: appLanguage))
                                .font(.headline)
                                .foregroundColor(Theme.textPrimary)
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.vertical, 4)
                        
                        Text(LocalizationManager.tr("settings_developer", lang: appLanguage))
                            .font(.subheadline)
                            .foregroundColor(Theme.textPrimary.opacity(0.8))
                        
                        Text("Версия: 2.1.0")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        
                        Text("Nano Health — ваш персональный ИИ-ассистент для контроля здоровья, тренировок, водного баланса и распознавания еды с помощью моделей Google Gemini.")
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
