import SwiftUI

struct SettingsView: View {
    @AppStorage("app_language") private var appLanguage = "ru"
    @AppStorage("app_theme") private var appTheme = "system"
    
    // API ключи
    @AppStorage("api_key_gemini") private var apiKeyGemini = ""
    @AppStorage("api_key_openai") private var apiKeyOpenAI = ""
    @AppStorage("api_key_claude") private var apiKeyClaude = ""
    
    @EnvironmentObject var health: HealthKitManager
    
    // Свойства для ввода веса
    @State private var showingWeightAlert = false
    @State private var weightInput = ""
    
    // Свойства для ИИ-анализа веса
    @State private var isAnalyzingWeight = false
    @State private var weightAnalysisResult: String? = nil
    @State private var weightAnalysisError: String? = nil
    
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
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    
                    // 1. КОНТРОЛЬ ВЕСА
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(appLanguage == "en" ? "Weight Tracker" : (appLanguage == "hy" ? "Քաշի վերահսկում" : "Контроль веса"))
                                .font(.headline)
                                .foregroundColor(Theme.textPrimary)
                            Spacer()
                            Button(action: {
                                weightInput = health.currentWeight > 0 ? String(format: "%.1f", health.currentWeight) : ""
                                showingWeightAlert = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                    Text(appLanguage == "en" ? "Add" : (appLanguage == "hy" ? "Ավելացնել" : "Внести"))
                                }
                                .font(.caption)
                                .bold()
                                .foregroundColor(.white)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .background(Theme.exerciseColor)
                                .cornerRadius(12)
                            }
                        }
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(appLanguage == "en" ? "Current Weight" : (appLanguage == "hy" ? "Ընթացիկ քաշը" : "Текущий вес"))
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                                Text(health.currentWeight > 0 ? String(format: "%.1f кг", health.currentWeight) : "-- кг")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                            }
                            
                            Spacer()
                            
                            // Тренд
                            HStack(spacing: 8) {
                                Image(systemName: health.weightTrend.arrow)
                                    .font(.system(size: 20, weight: .bold))
                                Text(trendLabel(health.weightTrend))
                                    .font(.subheadline)
                                    .bold()
                            }
                            .foregroundColor(health.weightTrend.color)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(health.weightTrend.color.opacity(0.08))
                            .cornerRadius(20)
                        }
                    }
                    .premiumCard()
                    .padding(.horizontal)
                    
                    // 2. ИИ-АНАЛИЗ ДИНАМИКИ ВЕСА
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .foregroundColor(.yellow)
                                .font(.title3)
                            Text(appLanguage == "en" ? "AI Weight Analysis" : (appLanguage == "hy" ? "ԻԻ քաշի վերլուծություն" : "Анализ динамики от ИИ"))
                                .font(.headline)
                                .foregroundColor(Theme.textPrimary)
                            Spacer()
                        }
                        
                        let hasAnyKey = !apiKeyGemini.isEmpty || !apiKeyOpenAI.isEmpty || !apiKeyClaude.isEmpty
                        
                        if !hasAnyKey {
                            Text(appLanguage == "en" ? "Please configure at least one API key below to activate AI." : (appLanguage == "hy" ? "Խնդրում ենք մուտքագրել առնվազն մեկ API բանալի ստորև՝ ԻԻ-ն ակտիվացնելու համար:" : "Пожалуйста, настройте хотя бы один API-ключ ниже для активации ИИ."))
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 8)
                        } else {
                            if let analysis = weightAnalysisResult {
                                ScrollView {
                                    Text(analysis)
                                        .font(.subheadline)
                                        .foregroundColor(Theme.textPrimary.opacity(0.9))
                                        .lineSpacing(4)
                                        .multilineTextAlignment(.leading)
                                        .padding(12)
                                }
                                .frame(maxHeight: 180)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(16)
                            } else if let error = weightAnalysisError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(Theme.pulseColor)
                                    .padding()
                                    .background(Theme.pulseColor.opacity(0.08))
                                    .cornerRadius(16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                Text(appLanguage == "en" ? "AI will analyze your weight history, workouts, and nutrition to provide insights." : (appLanguage == "hy" ? "ԻԻ-ն կվերլուծի ձեր քաշի պատմությունը, մարզումները և սնունդը՝ եզրակացություն տալու համար:" : "ИИ проанализирует вашу историю веса, тренировок и питания, чтобы дать рекомендации."))
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            
                            Button(action: {
                                runWeightAnalysis()
                            }) {
                                HStack {
                                    if isAnalyzingWeight {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .padding(.trailing, 8)
                                    }
                                    Text(isAnalyzingWeight ? (appLanguage == "en" ? "Analyzing..." : (appLanguage == "hy" ? "Վերլուծվում է..." : "Анализирую...")) : (appLanguage == "en" ? "Analyze Trend" : (appLanguage == "hy" ? "Վերլուծել քաշի միտումը" : "Анализировать динамику")))
                                        .bold()
                                }
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.white)
                                .padding()
                                .background(isAnalyzingWeight ? Theme.exerciseColor.opacity(0.6) : Theme.exerciseColor)
                                .cornerRadius(16)
                                .shadow(color: Theme.exerciseColor.opacity(0.3), radius: 8)
                            }
                            .disabled(isAnalyzingWeight)
                        }
                    }
                    .premiumCard()
                    .padding(.horizontal)
                    
                    // 3. НАСТРОЙКИ API КЛЮЧЕЙ
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "key.fill")
                                .foregroundColor(.yellow)
                            Text(appLanguage == "en" ? "API Configurations" : (appLanguage == "hy" ? "API Կարգավորումներ" : "Настройка API-ключей"))
                                .font(.headline)
                                .foregroundColor(Theme.textPrimary)
                        }
                        
                        Text(appLanguage == "en" ? "Add multiple keys. The app automatically rotates keys if one hits usage limits." : (appLanguage == "hy" ? "Ավելացրեք մի քանի բանալի. Հավելվածն ավտոմատ կերպով կփոխի բանալիները, եթե մեկի լիմիտը սպառվի:" : "Вы можете ввести несколько ключей. Приложение автоматически переключается между ними при достижении лимитов."))
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
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(Theme.sleepColor)
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
                        
                        Text("Nano Health — ваш персональный ИИ-ассистент для контроля здоровья, тренировок, водного баланса и распознавания еды с помощью моделей Google Gemini, OpenAI ChatGPT и Anthropic Claude.")
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
        .alert(appLanguage == "en" ? "Log Weight" : (appLanguage == "hy" ? "Մուտքագրել քաշը" : "Ввести вес"), isPresented: $showingWeightAlert) {
            TextField(appLanguage == "en" ? "Weight (kg)" : (appLanguage == "hy" ? "Քաշ (կգ)" : "Вес (кг)"), text: $weightInput)
                .keyboardType(.decimalPad)
            Button(appLanguage == "en" ? "Cancel" : (appLanguage == "hy" ? "Չեղարկել" : "Отмена"), role: .cancel) {
                weightInput = ""
            }
            Button(appLanguage == "en" ? "Save" : (appLanguage == "hy" ? "Պահպանել" : "Сохранить")) {
                if let weight = Double(weightInput.replacingOccurrences(of: ",", with: ".")) {
                    health.addWeight(weight: weight)
                }
                weightInput = ""
            }
        } message: {
            Text(appLanguage == "en" ? "Enter your current body weight in kilograms." : (appLanguage == "hy" ? "Մուտքագրեք ձեր ընթացիկ քաշը կիլոգրամներով:" : "Укажите ваш текущий вес в килограммах."))
        }
    }
    
    private func runWeightAnalysis() {
        isAnalyzingWeight = true
        weightAnalysisError = nil
        weightAnalysisResult = nil
        
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        Task {
            do {
                let result = try await GeminiScanService.shared.analyzeWeightTrend(
                    weightHistory: health.weightHistory,
                    workouts: health.workoutHistory,
                    nutrition: health.nutritionHistory
                )
                await MainActor.run {
                    self.weightAnalysisResult = result
                    self.isAnalyzingWeight = false
                }
            } catch {
                await MainActor.run {
                    self.weightAnalysisError = "Ошибка анализа: \(error.localizedDescription)"
                    self.isAnalyzingWeight = false
                }
            }
        }
    }
    
    private func trendLabel(_ trend: WeightTrendType) -> String {
        switch trend {
        case .up:
            return appLanguage == "en" ? "Gaining" : (appLanguage == "hy" ? "Աճ" : "Набор")
        case .down:
            return appLanguage == "en" ? "Losing" : (appLanguage == "hy" ? "Նվազում" : "Снижение")
        case .stable:
            return appLanguage == "en" ? "Stable" : (appLanguage == "hy" ? "Կայուն" : "Стабилен")
        }
    }
}
