import SwiftUI
import PhotosUI
import GoogleGenerativeAI

struct NutritionView: View {
    @EnvironmentObject var health: HealthKitManager
    @State private var selectedSubTab = 0
    
    @AppStorage("app_language") private var appLanguage = "ru"
    @AppStorage("api_key_gemini") private var apiKeyGemini = ""
    @AppStorage("api_key_openai") private var apiKeyOpenAI = ""
    @AppStorage("api_key_claude") private var apiKeyClaude = ""
    
    // --- ПЕРЕМЕННЫЕ ЕДЫ ---
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var isScanning = false
    @State private var scanError: String? = nil
    @State private var scanResult: FoodScanResult? = nil
    @State private var adjustedWeight: Double = 100.0
    @State private var showingCamera = false
    @State private var isAnalyzingNutrition = false
    @State private var nutritionAnalysisResult: String? = nil
    @State private var nutritionAnalysisError: String? = nil
    
    // --- ПЕРЕМЕННЫЕ ВОДЫ ---
    @State private var customWaterInput = ""
    @State private var showingCustomWaterAlert = false
    @State private var animatedProgress: Double = 0.0
    @State private var isAnalyzingWater = false
    @State private var waterAnalysisResult: String? = nil
    @State private var waterAnalysisError: String? = nil
    
    // --- ПЕРЕМЕННЫЕ ВЕСА ---
    @State private var weightInput = ""
    @State private var showingWeightAlert = false
    @State private var isAnalyzingWeight = false
    @State private var weightAnalysisResult: String? = nil
    @State private var weightAnalysisError: String? = nil
    
    private func tr(_ key: String) -> String {
        LocalizationManager.tr(key, lang: appLanguage)
    }
    
    private var hasAnyApiKey: Bool {
        !apiKeyGemini.isEmpty || !apiKeyOpenAI.isEmpty || !apiKeyClaude.isEmpty
    }
    
    // --- ВЫЧИСЛЯЕМЫЕ БЖУ ---
    private var scaledCalories: Double {
        guard let result = scanResult, result.weight_grams > 0 else { return 0 }
        return (result.calories / result.weight_grams) * adjustedWeight
    }
    private var scaledProtein: Double {
        guard let result = scanResult, result.weight_grams > 0 else { return 0 }
        return (result.protein / result.weight_grams) * adjustedWeight
    }
    private var scaledFat: Double {
        guard let result = scanResult, result.weight_grams > 0 else { return 0 }
        return (result.fat / result.weight_grams) * adjustedWeight
    }
    private var scaledCarbs: Double {
        guard let result = scanResult, result.weight_grams > 0 else { return 0 }
        return (result.carbs / result.weight_grams) * adjustedWeight
    }
    
    // --- НОРМА ВОДЫ ---
    private var calculatedWaterNorm: Double {
        if health.currentWeight > 0 {
            return health.currentWeight * 35.0
        } else {
            return 2500.0
        }
    }
    
    // --- СОВЕТЫ О ВОДЕ ---
    private let waterTips = [
        WaterTip(
            title: "Зачем организму вода?",
            text: "Вода составляет около 60% массы тела взрослого человека. Она доставляет питательные вещества к клеткам, выводит токсины, поддерживает нормальную температуру тела и смазывает суставы. Недостаток воды замедляет метаболизм.",
            icon: "info.circle.fill"
        ),
        WaterTip(
            title: "Вода и спортивные результаты",
            text: "Обезвоживание всего на 2% снижает физическую выносливость на 10-20%. Во время интенсивных тренировок пейте воду каждые 15-20 минут небольшими глотками, чтобы избежать спазмов и перегрева.",
            icon: "figure.run.circle.fill"
        ),
        WaterTip(
            title: "Как узнать, что воды не хватает?",
            text: "Первые признаки обезвоживания — это сухость во рту, легкое головокружение, чувство усталости, головная боль и темный цвет мочи. Не ждите появления жажды — это уже сигнал о начавшемся дефиците воды.",
            icon: "exclamationmark.triangle.fill"
        ),
        WaterTip(
            title: "Как выработать привычку пить воду?",
            text: "1. Держите бутылку с водой всегда под рукой.\n2. Выпивайте стакан воды сразу после пробуждения.\n3. Добавьте в воду ломтик лимона, огурца или мяты для вкуса.\n4. Используйте Nano Health для отслеживания прогресса!",
            icon: "checkmark.circle.fill"
        )
    ]
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Заголовок
                HStack {
                    Text(tr("nutrition_title"))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 12)
                
                // Сегментированный переключатель разделов
                Picker("", selection: $selectedSubTab) {
                    Text(tr("nutrition_tab_food")).tag(0)
                    Text(tr("nutrition_tab_water")).tag(1)
                    Text(tr("nutrition_tab_weight")).tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                // Содержимое выбранной вкладки
                if selectedSubTab == 0 {
                    foodScannerSection
                } else if selectedSubTab == 1 {
                    waterTrackerSection
                } else {
                    weightTrackerSection
                }
            }
        }
        // --- АЛЕРТЫ И МОДИФИКАТОРЫ ---
        .sheet(isPresented: $showingCamera) {
            CameraPicker(selectedImage: $selectedImage)
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    selectedImage = uiImage
                }
            }
        }
        .onChange(of: selectedImage) { _, newImage in
            if let img = newImage {
                runFoodScan(image: img)
            }
        }
        .alert(tr("water_custom_alert_title"), isPresented: $showingCustomWaterAlert) {
            TextField(tr("water_custom_alert_placeholder"), text: $customWaterInput)
                .keyboardType(.numberPad)
            Button(tr("cancel"), role: .cancel) {
                customWaterInput = ""
            }
            Button(tr("water_add")) {
                if let amount = Double(customWaterInput) {
                    health.addWater(amount: amount)
                }
                customWaterInput = ""
            }
        } message: {
            Text(tr("water_custom_alert_desc"))
        }
        .alert(tr("settings_weight_log_title"), isPresented: $showingWeightAlert) {
            TextField(tr("settings_weight_log_placeholder"), text: $weightInput)
                .keyboardType(.decimalPad)
            Button(tr("cancel"), role: .cancel) {
                weightInput = ""
            }
            Button(tr("save")) {
                if let weight = Double(weightInput.replacingOccurrences(of: ",", with: ".")) {
                    health.addWeight(weight: weight)
                }
                weightInput = ""
            }
        } message: {
            Text(tr("settings_weight_log_desc"))
        }
        .onAppear {
            animatedProgress = calculatedWaterNorm > 0 ? health.waterConsumed / calculatedWaterNorm : 0.0
        }
        .onChange(of: health.waterConsumed) { _, newValue in
            let newProgress = calculatedWaterNorm > 0 ? newValue / calculatedWaterNorm : 0.0
            withAnimation(.easeInOut(duration: 0.8)) {
                animatedProgress = newProgress
            }
        }
    }
    
    // --- СЕКЦИЯ ЕДЫ ---
    private var foodScannerSection: some View {
        ScrollView {
            VStack(spacing: 20) {
                if !hasAnyApiKey {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(tr("nutrition_api_required_title"))
                            .font(.headline)
                            .foregroundColor(Theme.textPrimary)
                        Text(tr("nutrition_api_required_desc"))
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                    .premiumCard()
                    .padding(.horizontal)
                }
                
                if let img = selectedImage {
                    VStack(spacing: 20) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                            )
                            .padding(.horizontal)
                        
                        if isScanning {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .tint(Theme.textPrimary)
                                Text(tr("nutrition_scanning"))
                                    .foregroundColor(Theme.textSecondary)
                                    .font(.subheadline)
                            }
                            .padding()
                        }
                        
                        if let error = scanError {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        if let result = scanResult {
                            VStack(alignment: .leading, spacing: 16) {
                                Text(tr("nutrition_scan_results"))
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(Theme.textSecondary)
                                
                                Text(result.dish)
                                    .font(.title3)
                                    .bold()
                                    .foregroundColor(Theme.textPrimary)
                                
                                Divider()
                                
                                HStack {
                                    Text(tr("nutrition_serving_weight"))
                                        .foregroundColor(Theme.textSecondary)
                                        .bold()
                                    Spacer()
                                    Stepper(value: $adjustedWeight, in: 10...2000, step: 10) {
                                        Text(String(format: "%d %@", Int(adjustedWeight), appLanguage == "en" ? "g" : (appLanguage == "hy" ? "գ" : "г")))
                                            .font(.headline)
                                            .foregroundColor(Theme.textPrimary)
                                    }
                                }
                                
                                Divider()
                                
                                HStack(spacing: 12) {
                                    MacroItem(value: "\(Int(scaledCalories))", label: tr("kcal"), color: Theme.pulseColor)
                                    MacroItem(value: "\(Int(scaledProtein))" + (appLanguage == "en" ? "g" : (appLanguage == "hy" ? "գ" : "г")), label: tr("protein"), color: .green)
                                    MacroItem(value: "\(Int(scaledFat))" + (appLanguage == "en" ? "g" : (appLanguage == "hy" ? "գ" : "г")), label: tr("fat"), color: .orange)
                                    MacroItem(value: "\(Int(scaledCarbs))" + (appLanguage == "en" ? "g" : (appLanguage == "hy" ? "գ" : "г")), label: tr("carbs"), color: .blue)
                                }
                                
                                Button(action: {
                                    saveToHealthKit()
                                }) {
                                    Text(tr("nutrition_add_meal"))
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Theme.exerciseColor)
                                        .cornerRadius(16)
                                        .shadow(color: Theme.exerciseColor.opacity(0.3), radius: 8)
                                }
                                
                                Button(action: {
                                    selectedImage = nil
                                    scanResult = nil
                                    scanError = nil
                                }) {
                                    Text(tr("cancel"))
                                        .font(.subheadline)
                                        .foregroundColor(Theme.textSecondary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                }
                            }
                            .premiumCard()
                            .padding(.horizontal)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .foregroundColor(.yellow)
                                .font(.title3)
                            Text(tr("nutrition_ai_tips"))
                                .font(.headline)
                                .foregroundColor(Theme.textPrimary)
                            Spacer()
                        }
                        
                        if !hasAnyApiKey {
                            Text(tr("nutrition_ai_key_warning"))
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 8)
                        } else {
                            if let analysis = nutritionAnalysisResult {
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
                            } else if let error = nutritionAnalysisError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(Theme.pulseColor)
                                    .padding()
                                    .background(Theme.pulseColor.opacity(0.08))
                                    .cornerRadius(16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                Text(tr("nutrition_ai_desc"))
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                                    .padding(.vertical, 4)
                            }
                            
                            Button(action: {
                                runNutritionAnalysis()
                            }) {
                                HStack {
                                    if isAnalyzingNutrition {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .padding(.trailing, 8)
                                    }
                                    Text(isAnalyzingNutrition ? tr("nutrition_analyzing") : tr("nutrition_analyze_btn"))
                                        .bold()
                                }
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.white)
                                .padding()
                                .background(isAnalyzingNutrition ? Theme.exerciseColor.opacity(0.6) : Theme.exerciseColor)
                                .cornerRadius(16)
                                .shadow(color: Theme.exerciseColor.opacity(0.3), radius: 8)
                            }
                            .disabled(isAnalyzingNutrition)
                        }
                    }
                    .premiumCard()
                    .padding(.horizontal)
                    
                    HStack(spacing: 16) {
                        Button(action: {
                            showingCamera = true
                        }) {
                            HStack {
                                Image(systemName: "camera.fill")
                                Text(tr("camera"))
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Theme.textPrimary)
                            .cornerRadius(16)
                        }
                        
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            HStack {
                                Image(systemName: "photo.fill")
                                Text(tr("gallery"))
                            }
                            .font(.headline)
                            .foregroundColor(Theme.textPrimary)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Theme.cardBackground)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Theme.textSecondary.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 24)
        }
    }
    
    // --- СЕКЦИЯ ВОДЫ ---
    private var waterTrackerSection: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    let progress = calculatedWaterNorm > 0 ? health.waterConsumed / calculatedWaterNorm : 0.0
                    
                    HStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(tr("water_consumed"))
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(.white.opacity(0.7))
                            
                            Text(String(format: "%.0f / %.0f %@", health.waterConsumed, calculatedWaterNorm, appLanguage == "en" ? "ml" : (appLanguage == "hy" ? "մլ" : "мл")))
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text(String(format: tr("water_add_success"), min(progress * 100.0, 100.0)))
                                .font(.caption)
                                .bold()
                                .foregroundColor(progress >= 1.0 ? .green : .white.opacity(0.6))
                        }
                        
                        Spacer()
                        
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.1), lineWidth: 8)
                            
                            Circle()
                                .trim(from: 0.0, to: CGFloat(min(animatedProgress, 1.0)))
                                .stroke(
                                    LinearGradient(
                                        colors: [Color(red: 0/255, green: 229/255, blue: 255/255), Color(red: 0/255, green: 145/255, blue: 255/255)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                )
                                .rotationEffect(Angle(degrees: -90))
                                .neonShadow(color: Color(red: 0/255, green: 229/255, blue: 255/255), radius: 4)
                            
                            GlassWaterView(progress: progress)
                        }
                        .frame(width: 100, height: 100)
                    }
                }
                .padding(20)
                .background(Theme.waterCardGradient)
                .cornerRadius(24)
                .shadow(color: Color(red: 0/255, green: 122/255, blue: 255/255).opacity(0.15), radius: 10)
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(tr("water_add"))
                            .font(.headline)
                            .foregroundColor(Theme.textPrimary)
                        Spacer()
                        if health.waterConsumed > 0 {
                            Button(action: {
                                let impact = UIImpactFeedbackGenerator(style: .heavy)
                                impact.impactOccurred()
                                health.resetWater()
                            }) {
                                Text(tr("water_reset"))
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(Theme.pulseColor)
                            }
                        }
                    }
                    
                    HStack(spacing: 12) {
                        WaterButton(amount: 200, icon: "drop") {
                            health.addWater(amount: 200)
                        }
                        WaterButton(amount: 250, icon: "drop.fill") {
                            health.addWater(amount: 250)
                        }
                        WaterButton(amount: 500, icon: "drop.circle.fill") {
                            health.addWater(amount: 500)
                        }
                    }
                    
                    Button(action: {
                        showingCustomWaterAlert = true
                    }) {
                        HStack {
                            Image(systemName: "pencil.line")
                            Text(tr("water_custom_volume"))
                        }
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(red: 0/255, green: 122/255, blue: 255/255))
                        .cornerRadius(16)
                        .shadow(color: Color(red: 0/255, green: 122/255, blue: 255/255).opacity(0.3), radius: 6)
                    }
                }
                .premiumCard()
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "calculator.fill")
                            .foregroundColor(Theme.exerciseColor)
                        Text(tr("water_individual_calc"))
                            .font(.headline)
                            .foregroundColor(Theme.textPrimary)
                    }
                    
                    if health.currentWeight > 0 {
                        Text(String(format: tr("water_calc_desc_with_weight"), health.currentWeight, calculatedWaterNorm))
                            .font(.subheadline)
                            .foregroundColor(Theme.textPrimary.opacity(0.8))
                            .lineSpacing(3)
                    } else {
                        Text(tr("water_calc_desc_no_weight"))
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                            .lineSpacing(3)
                    }
                }
                .premiumCard()
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.yellow)
                            .font(.title3)
                        Text(tr("water_ai_tips"))
                            .font(.headline)
                            .foregroundColor(Theme.textPrimary)
                        Spacer()
                    }
                    
                    if !hasAnyApiKey {
                        Text(tr("water_ai_key_warning"))
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    } else {
                        if let analysis = waterAnalysisResult {
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
                        } else if let error = waterAnalysisError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(Theme.pulseColor)
                                .padding()
                                .background(Theme.pulseColor.opacity(0.08))
                                .cornerRadius(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text(tr("water_ai_desc"))
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                                .padding(.vertical, 4)
                        }
                        
                        Button(action: {
                            runWaterAnalysis()
                        }) {
                            HStack {
                                if isAnalyzingWater {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .padding(.trailing, 8)
                                }
                                Text(isAnalyzingWater ? "Анализирую..." : "Анализировать питьевой режим")
                                    .bold()
                            }
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                            .padding()
                            .background(isAnalyzingWater ? Theme.exerciseColor.opacity(0.6) : Theme.exerciseColor)
                            .cornerRadius(16)
                            .shadow(color: Theme.exerciseColor.opacity(0.3), radius: 8)
                        }
                        .disabled(isAnalyzingWater)
                    }
                }
                .premiumCard()
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text(tr("water_tips"))
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                    
                    ForEach(waterTips) { tip in
                        DisclosureGroup(
                            content: {
                                Text(tip.text)
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textPrimary.opacity(0.8))
                                    .padding(.vertical, 8)
                                    .lineSpacing(3)
                            },
                            label: {
                                HStack(spacing: 12) {
                                    Image(systemName: tip.icon)
                                        .foregroundColor(Color(red: 0/255, green: 145/255, blue: 255/255))
                                        .font(.headline)
                                    Text(tip.title)
                                        .font(.subheadline)
                                        .bold()
                                        .foregroundColor(Theme.textPrimary)
                                }
                            }
                        )
                        .padding()
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(12)
                    }
                }
                .premiumCard()
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
    }
    
    // --- СЕКЦИЯ ВЕСА ---
    private var weightTrackerSection: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(tr("settings_weight_tracker"))
                            .font(.headline)
                            .foregroundColor(Theme.textPrimary)
                        Spacer()
                        Button(action: {
                            weightInput = health.currentWeight > 0 ? String(format: "%.1f", health.currentWeight) : ""
                            showingWeightAlert = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                Text(tr("settings_weight_add"))
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
                            Text(tr("settings_weight_current"))
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                            Text(health.currentWeight > 0 ? String(format: "%.1f %@", health.currentWeight, appLanguage == "en" ? "kg" : (appLanguage == "hy" ? "կգ" : "кг")) : "-- " + (appLanguage == "en" ? "kg" : (appLanguage == "hy" ? "կգ" : "кг")))
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.textPrimary)
                        }
                        
                        Spacer()
                        
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
                
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.yellow)
                            .font(.title3)
                        Text(tr("settings_weight_ai_title"))
                            .font(.headline)
                            .foregroundColor(Theme.textPrimary)
                        Spacer()
                    }
                    
                    if !hasAnyApiKey {
                        Text(tr("settings_weight_ai_key_warning"))
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
                            Text(tr("settings_weight_ai_desc"))
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
                                Text(isAnalyzingWeight ? tr("settings_weight_ai_analyzing") : tr("settings_weight_ai_btn"))
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
                .padding(.bottom, 24)
            }
        }
    }
    
    // --- МЕТОДЫ ЕДЫ ---
    private func runFoodScan(image: UIImage) {
        isScanning = true
        scanError = nil
        scanResult = nil
        
        Task {
            if !hasAnyApiKey {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await MainActor.run {
                    self.scanResult = FoodScanResult(
                        dish: tr("demo_apple"),
                        weight_grams: 150.0,
                        calories: 78.0,
                        protein: 0.6,
                        fat: 0.3,
                        carbs: 19.0
                    )
                    self.adjustedWeight = 150.0
                    self.isScanning = false
                }
            } else {
                do {
                    let result = try await GeminiScanService.shared.scanFood(image: image)
                    await MainActor.run {
                        self.scanResult = result
                        self.adjustedWeight = result.weight_grams
                        self.isScanning = false
                    }
                } catch {
                    await MainActor.run {
                        self.scanError = error.localizedDescription
                        self.isScanning = false
                    }
                }
            }
        }
    }
    
    private func saveToHealthKit() {
        health.addDietaryEnergy(calories: scaledCalories)
        selectedImage = nil
        scanResult = nil
    }
    
    private func runNutritionAnalysis() {
        guard hasAnyApiKey else { return }
        isAnalyzingNutrition = true
        nutritionAnalysisError = nil
        nutritionAnalysisResult = nil
        
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        Task {
            do {
                let result = try await GeminiScanService.shared.analyzeNutrition(
                    nutritionHistory: health.nutritionHistory
                )
                await MainActor.run {
                    self.nutritionAnalysisResult = result
                    self.isAnalyzingNutrition = false
                }
            } catch {
                await MainActor.run {
                    self.nutritionAnalysisError = "Ошибка анализа: \(error.localizedDescription)"
                    self.isAnalyzingNutrition = false
                }
            }
        }
    }
    
    // --- МЕТОДЫ ВОДЫ ---
    private func runWaterAnalysis() {
        guard hasAnyApiKey else { return }
        isAnalyzingWater = true
        waterAnalysisError = nil
        waterAnalysisResult = nil
        
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        Task {
            do {
                let result = try await GeminiScanService.shared.analyzeWaterIntake(
                    consumed: health.waterConsumed,
                    goal: calculatedWaterNorm,
                    weight: health.currentWeight
                )
                await MainActor.run {
                    self.waterAnalysisResult = result
                    self.isAnalyzingWater = false
                }
            } catch {
                await MainActor.run {
                    self.waterAnalysisError = "Ошибка анализа: \(error.localizedDescription)"
                    self.isAnalyzingWater = false
                }
            }
        }
    }
    
    // --- МЕТОДЫ ВЕСА ---
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
            return tr("settings_weight_trend_gaining")
        case .down:
            return tr("settings_weight_trend_losing")
        case .stable:
            return tr("settings_weight_trend_stable")
        }
    }
}

// Модель подсказок по питьевому режиму
struct WaterTip: Identifiable {
    let id = UUID()
    let title: String
    let text: String
    let icon: String
}

// Кнопка быстрого добавления воды
struct WaterButton: View {
    let amount: Int
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            action()
        }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(Color(red: 0/255, green: 145/255, blue: 255/255))
                
                Text("+\(amount) мл")
                    .font(.caption)
                    .bold()
                    .foregroundColor(Theme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
        }
    }
}

// Отображение макронутриента
struct MacroItem: View {
    var value: String
    var label: String
    var color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .bold()
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// Representable для Камеры
struct CameraPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
        } else {
            picker.sourceType = .photoLibrary
        }
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        
        init(_ parent: CameraPicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
