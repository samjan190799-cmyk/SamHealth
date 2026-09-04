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
    
    // Профиль пользователя из AppStorage
    @AppStorage("user_age") private var userAge = 25
    @AppStorage("user_height") private var userHeight = 175
    @AppStorage("user_weight") private var userWeight = 75.0
    @AppStorage("user_target_weight") private var userTargetWeight = 70.0
    @AppStorage("user_gender") private var userGender = "Мужской"
    @AppStorage("user_activity_level") private var userActivityLevel = "Средняя"
    
    // Состояния для ИИ-Планировщика питания
    @State private var isGeneratingNutritionPlan = false
    @State private var generatedNutritionPlan: String? = nil
    @State private var nutritionPlanError: String? = nil
    
    // --- ПЕРЕМЕННЫЕ ЕДЫ ---
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var isScanning = false
    @State private var scanError: String? = nil
    @State private var scanResult: FoodScanResult? = nil
    @State private var currentIngredients: [FoodIngredient] = []
    @State private var userPromptHint: String = ""
    @State private var adjustedWeight: Double = 100.0
    @State private var showingCamera = false
    @State private var isAnalyzingNutrition = false
    @State private var nutritionAnalysisResult: String? = nil
    @State private var nutritionAnalysisError: String? = nil
    
    // Сканер штрих-кодов и AI-Нутрициолог
    @State private var showingBarcodeScanner = false
    @State private var barcodeScannerMode: BarcodeScannerMode = .plateAI
    @State private var showingNutritionistSheet = false
    @State private var lastScannedBarcodeProduct: BarcodeProduct? = nil
    
    // Добавление кастомного ингредиента и ручной ввод блюда
    @State private var showingAddIngredientSheet = false
    @State private var showingManualAddMealSheet = false
    @State private var showingQuickSoupSheet = false
    @State private var showingAICoachChatFromNutrition = false
    @State private var defaultMealCategoryForManualAdd: MealCategory = .lunch
    
    // --- ПЕРЕМЕННЫЕ ВОДЫ И НАПИТКОВ ---
    @State private var selectedBeverageType: BeverageType = .water
    @State private var showingCustomBeverageSheet = false
    @State private var customWaterInput = ""
    @State private var showingCustomWaterAlert = false
    @State private var animatedProgress: Double = 0.0
    @State private var isAnalyzingWater = false
    @State private var waterAnalysisResult: String? = nil
    @State private var waterAnalysisError: String? = nil
    @State private var showingWaterBreakdown = false
    
    // --- ПЕРЕМЕННЫЕ ВЕСА ---
    @State private var weightInput = ""
    @State private var showingWeightAlert = false
    @State private var showingWeightLogSheet = false
    @State private var showingAICoachChatFromWeight = false
    @State private var isAnalyzingWeight = false
    @State private var weightAnalysisResult: String? = nil
    @State private var weightAnalysisError: String? = nil
    
    @ObservedObject private var coachManager = AICoachManager.shared
    
    private func tr(_ key: String) -> String {
        LocalizationManager.tr(key, lang: appLanguage)
    }
    
    private var hasAnyApiKey: Bool {
        !apiKeyGemini.isEmpty || !apiKeyOpenAI.isEmpty || !apiKeyClaude.isEmpty
    }
    
    // --- ВЫЧИСЛЯЕМЫЕ БЖУ И ИТОГИ ---
    private var totalCalories: Double {
        if !currentIngredients.isEmpty {
            return currentIngredients.reduce(0.0) { $0 + $1.calories }
        }
        guard let result = scanResult, result.weight_grams > 0 else { return 0 }
        return (result.calories / result.weight_grams) * adjustedWeight
    }
    private var totalProtein: Double {
        if !currentIngredients.isEmpty {
            return currentIngredients.reduce(0.0) { $0 + $1.protein }
        }
        guard let result = scanResult, result.weight_grams > 0 else { return 0 }
        return (result.protein / result.weight_grams) * adjustedWeight
    }
    private var totalFat: Double {
        if !currentIngredients.isEmpty {
            return currentIngredients.reduce(0.0) { $0 + $1.fat }
        }
        guard let result = scanResult, result.weight_grams > 0 else { return 0 }
        return (result.fat / result.weight_grams) * adjustedWeight
    }
    private var totalCarbs: Double {
        if !currentIngredients.isEmpty {
            return currentIngredients.reduce(0.0) { $0 + $1.carbs }
        }
        guard let result = scanResult, result.weight_grams > 0 else { return 0 }
        return (result.carbs / result.weight_grams) * adjustedWeight
    }
    private var totalWeight: Double {
        if !currentIngredients.isEmpty {
            return currentIngredients.reduce(0.0) { $0 + $1.weight_grams }
        }
        return adjustedWeight
    }
    
    // --- НОРМА ВОДЫ (УМНАЯ АДАПТИВНАЯ НОРМА) ---
    private var calculatedWaterNorm: Double {
        health.dynamicWaterGoal
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
            text: "1. Держите бутылку с водой всегда под рукой.\n2. Выпивайте стакан воды сразу после пробуждения.\n3. Добавьте в воду ломтик лимона, огурца или мяты для вкуса.\n4. Используйте Forma для отслеживания прогресса!",
            icon: "checkmark.circle.fill"
        )
    ]
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Заголовок
                HStack(spacing: 12) {
                    AppLogoView(size: 34)
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenFoodScanner"))) { _ in
            selectedSubTab = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                barcodeScannerMode = .plateAI
                showingBarcodeScanner = true
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraPicker(selectedImage: $selectedImage)
        }
        .sheet(isPresented: $showingAddIngredientSheet) {
            AddIngredientSheetView { item in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    currentIngredients.append(item)
                }
            }
        }
        .sheet(isPresented: $showingBarcodeScanner) {
            BarcodeScannerView(initialMode: barcodeScannerMode) { product in
                handleScannedBarcode(product)
            }
        }
        .sheet(isPresented: $showingNutritionistSheet) {
            AINutritionistView()
        }
        .sheet(isPresented: $showingCustomBeverageSheet) {
            CustomBeverageSheetView(initialType: selectedBeverageType) { type, volume, cals, name in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    health.addBeverage(type: type, volumeMl: volume, customCalories: cals, customName: name)
                }
            }
        }
        .sheet(isPresented: $showingManualAddMealSheet) {
            ManualAddMealSheetView(initialCategory: defaultMealCategoryForManualAdd) { newMeal in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    health.addLoggedMeal(newMeal)
                    GamificationManager.shared.addXP(30, reason: "Прием пищи: \(newMeal.name)")
                }
            }
        }
        .sheet(isPresented: $showingQuickSoupSheet) {
            QuickSoupBrothSheetView { newSoupMeal in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    health.addLoggedMeal(newSoupMeal)
                    GamificationManager.shared.addXP(35, reason: "Первое блюдо: \(newSoupMeal.name)")
                }
            }
        }
        .sheet(isPresented: $showingAICoachChatFromNutrition) {
            AICoachChatView()
                .environmentObject(health)
        }
        .sheet(isPresented: $showingWeightLogSheet) {
            WeightLogSheetView(initialWeight: health.currentWeight > 0 ? health.currentWeight : userWeight) { weight, date, timeOfDay, note in
                health.addWeight(weightInKg: weight, date: date, timeOfDay: timeOfDay, note: note)
            }
        }
        .sheet(isPresented: $showingAICoachChatFromWeight) {
            AICoachChatView()
                .environmentObject(health)
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
            generatedNutritionPlan = UserDefaults.standard.string(forKey: "generated_nutrition_plan")
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
                    VStack(spacing: 16) {
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
                        
                        // Поле текстового/голосового уточнения к фото
                        if scanResult == nil && !isScanning {
                            HStack {
                                Image(systemName: "text.bubble.fill")
                                    .foregroundColor(Theme.textSecondary)
                                TextField(tr("nutrition_hint_placeholder"), text: $userPromptHint)
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textPrimary)
                                
                                if !userPromptHint.isEmpty {
                                    Button(action: { userPromptHint = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                }
                            }
                            .padding(12)
                            .background(Theme.cardBackground)
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Theme.textSecondary.opacity(0.15), lineWidth: 1)
                            )
                            .padding(.horizontal)
                        }
                        
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
                                // Заголовок блюда и Health Score
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(tr("nutrition_scan_results"))
                                            .font(.caption)
                                            .bold()
                                            .foregroundColor(Theme.textSecondary)
                                        
                                        Text(result.dish)
                                            .font(.title3)
                                            .bold()
                                            .foregroundColor(Theme.textPrimary)
                                    }
                                    
                                    Spacer()
                                    
                                    if let score = result.healthScore {
                                        HStack(spacing: 4) {
                                            Image(systemName: "sparkles")
                                                .font(.caption2)
                                                .foregroundColor(.yellow)
                                            Text("\(score)/10")
                                                .font(.caption)
                                                .bold()
                                                .foregroundColor(score >= 8 ? Color.green : (score >= 6 ? Color.orange : Color.red))
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill((score >= 8 ? Color.green : (score >= 6 ? Color.orange : Color.red)).opacity(0.15))
                                        )
                                    }
                                }
                                
                                // Совет нутрициолога
                                if let advice = result.advice, !advice.isEmpty {
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: "lightbulb.fill")
                                            .font(.caption)
                                            .foregroundColor(.yellow)
                                            .padding(.top, 2)
                                        Text(advice)
                                            .font(.caption)
                                            .foregroundColor(Theme.textPrimary.opacity(0.9))
                                            .lineSpacing(3)
                                    }
                                    .padding(10)
                                    .background(Color.yellow.opacity(0.08))
                                    .cornerRadius(12)
                                }
                                
                                Divider()
                                
                                // Общие макросы
                                HStack(spacing: 8) {
                                    MacroItem(value: "\(Int(totalCalories))", label: tr("kcal"), color: Theme.pulseColor)
                                    MacroItem(value: "\(Int(totalProtein))" + (appLanguage == "en" ? "g" : (appLanguage == "hy" ? "գ" : "г")), label: tr("protein"), color: .green)
                                    MacroItem(value: "\(Int(totalFat))" + (appLanguage == "en" ? "g" : (appLanguage == "hy" ? "գ" : "г")), label: tr("fat"), color: .orange)
                                    MacroItem(value: "\(Int(totalCarbs))" + (appLanguage == "en" ? "g" : (appLanguage == "hy" ? "գ" : "г")), label: tr("carbs"), color: .blue)
                                }
                                
                                Divider()
                                
                                // Секция ингредиентов
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text(tr("nutrition_ingredients_title"))
                                            .font(.subheadline)
                                            .bold()
                                            .foregroundColor(Theme.textPrimary)
                                        
                                        Text("(\(currentIngredients.count))")
                                            .font(.caption)
                                            .foregroundColor(Theme.textSecondary)
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            showingAddIngredientSheet = true
                                        }) {
                                            Text(tr("nutrition_add_ingredient"))
                                                .font(.caption)
                                                .bold()
                                                .foregroundColor(Theme.exerciseColor)
                                        }
                                    }
                                    
                                    ForEach(currentIngredients) { ing in
                                        HStack(spacing: 12) {
                                            Text(ing.emoji)
                                                .font(.title2)
                                                .frame(width: 36, height: 36)
                                                .background(Color.white.opacity(0.06))
                                                .clipShape(Circle())
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(ing.name)
                                                    .font(.subheadline)
                                                    .bold()
                                                    .foregroundColor(Theme.textPrimary)
                                                    .lineLimit(1)
                                                
                                                HStack(spacing: 6) {
                                                    Text("\(Int(ing.calories)) ккал")
                                                        .font(.caption2)
                                                        .bold()
                                                        .foregroundColor(Theme.pulseColor)
                                                    Text("Б:\(Int(ing.protein))")
                                                        .font(.caption2)
                                                        .foregroundColor(.green.opacity(0.8))
                                                    Text("Ж:\(Int(ing.fat))")
                                                        .font(.caption2)
                                                        .foregroundColor(.orange.opacity(0.8))
                                                    Text("У:\(Int(ing.carbs))")
                                                        .font(.caption2)
                                                        .foregroundColor(.blue.opacity(0.8))
                                                }
                                            }
                                            
                                            Spacer()
                                            
                                            // Stepper веса
                                            HStack(spacing: 8) {
                                                Button(action: {
                                                    updateIngredientWeight(id: ing.id, delta: -25)
                                                }) {
                                                    Image(systemName: "minus.circle.fill")
                                                        .foregroundColor(Theme.textSecondary.opacity(0.7))
                                                        .font(.system(size: 20))
                                                }
                                                
                                                Text("\(Int(ing.weight_grams))г")
                                                    .font(.subheadline)
                                                    .bold()
                                                    .foregroundColor(Theme.textPrimary)
                                                    .frame(minWidth: 42)
                                                
                                                Button(action: {
                                                    updateIngredientWeight(id: ing.id, delta: 25)
                                                }) {
                                                    Image(systemName: "plus.circle.fill")
                                                        .foregroundColor(Theme.exerciseColor)
                                                        .font(.system(size: 20))
                                                }
                                            }
                                            
                                            // Кнопка удаления ингредиента
                                            Button(action: {
                                                removeIngredient(id: ing.id)
                                            }) {
                                                Image(systemName: "xmark.circle")
                                                    .foregroundColor(Color.red.opacity(0.6))
                                                    .font(.system(size: 18))
                                            }
                                        }
                                        .padding(10)
                                        .background(Color.white.opacity(0.03))
                                        .cornerRadius(12)
                                    }
                                }
                                
                                // Кнопка добавления в дневник и Apple Health
                                Button(action: {
                                    saveToHealthKit()
                                }) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                        Text("\(tr("nutrition_add_meal")) (\(Int(totalCalories)) \(tr("kcal")))")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Theme.exerciseColor)
                                    .cornerRadius(16)
                                    .shadow(color: Theme.exerciseColor.opacity(0.3), radius: 8)
                                }
                            }
                            .premiumCard()
                            .padding(.horizontal)
                            
                            // Индекс качества еды (Nutri-Score, NOVA, ГИ, Клетчатка, Сахар)
                            FoodQualityCard(
                                healthScore: result.healthScore ?? 8,
                                nutriScore: lastScannedBarcodeProduct?.nutriScore,
                                novaGroup: lastScannedBarcodeProduct?.novaGroup,
                                glycemicIndex: nil,
                                fiberGrams: lastScannedBarcodeProduct?.fiberPer100g,
                                sugarGrams: lastScannedBarcodeProduct?.sugarPer100g,
                                sodiumMg: lastScannedBarcodeProduct?.sodiumPer100g,
                                advice: result.advice
                            )
                            .padding(.horizontal)
                        }
                        
                        // Кнопки управления при наличии изображения
                        VStack(spacing: 12) {
                            if scanError != nil && !isScanning {
                                Button(action: {
                                    runFoodScan(image: img)
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.clockwise")
                                        Text("Повторить сканирование")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Theme.exerciseColor)
                                    .cornerRadius(16)
                                    .shadow(color: Theme.exerciseColor.opacity(0.3), radius: 6)
                                }
                            }
                            
                            Button(action: {
                                resetScanState()
                            }) {
                                HStack {
                                    Image(systemName: "xmark.circle")
                                    Text(tr("cancel"))
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
                            
                            // 3 кнопки: Камера (LiDAR) / Галерея / Штрих-код
                            HStack(spacing: 12) {
                                Button(action: {
                                    barcodeScannerMode = .plateAI
                                    showingBarcodeScanner = true
                                    HapticManager.shared.impact(.light)
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "camera.fill")
                                        Text("AI-Блюдо")
                                    }
                                    .font(.subheadline.bold())
                                    .foregroundColor(Theme.cardBackground)
                                    .padding(.vertical, 14)
                                    .frame(maxWidth: .infinity)
                                    .background(Theme.textPrimary)
                                    .cornerRadius(16)
                                }
                                
                                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "photo.fill")
                                        Text(tr("gallery"))
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textPrimary)
                                    .padding(.vertical, 14)
                                    .frame(maxWidth: .infinity)
                                    .background(Theme.cardBackground)
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Theme.textSecondary.opacity(0.2), lineWidth: 1)
                                    )
                                }
                                
                                Button(action: {
                                    barcodeScannerMode = .barcode
                                    showingBarcodeScanner = true
                                    HapticManager.shared.impact(.light)
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "barcode.viewfinder")
                                        Text(tr("nutrition_barcode_btn"))
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textPrimary)
                                    .padding(.vertical, 14)
                                    .frame(maxWidth: .infinity)
                                    .background(Theme.cardBackground)
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Theme.textSecondary.opacity(0.2), lineWidth: 1)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 4)
                    }
                } else {
                    // 1. ЭНЕРГЕТИЧЕСКИЙ БАЛАНС И ДИНАМИКА ВЕСА
                    FoodDailyEnergyBalanceCard(
                        caloriesConsumed: health.caloriesConsumedToday,
                        protein: health.proteinConsumedToday,
                        fat: health.fatConsumedToday,
                        carbs: health.carbsConsumedToday,
                        activeCaloriesBurned: health.activeEnergyBurned > 0 ? health.activeEnergyBurned : health.calculatedStepCalories,
                        userWeight: health.currentWeight > 0 ? health.currentWeight : userWeight,
                        userTargetWeight: userTargetWeight,
                        userHeight: userHeight,
                        userAge: userAge,
                        userGender: userGender
                    )
                    .padding(.horizontal)
                    
                    // 2. ВЕРДИКТ И СОВЕТ ВЫБРАННОГО AI-ТРЕНЕРА
                    AICoachNutritionCard(
                        coach: coachManager.currentCoach,
                        caloriesConsumed: health.caloriesConsumedToday,
                        calorieBalance: health.calorieBalance,
                        protein: health.proteinConsumedToday,
                        solidStreak: health.solidMealStreak,
                        onAskCoach: {
                            showingAICoachChatFromNutrition = true
                        }
                    )
                    .padding(.horizontal)
                    
                    // 3. БАЛАНС ЖКТ И КОНСИСТЕНЦИЯ РАЦИОНА (СУПЫ / БУЛЬОНЫ VS СУХОМЯТКА)
                    DigestiveBalanceCard(
                        solidStreak: health.solidMealStreak,
                        mealsSinceLastSoup: health.mealsSinceLastLiquidMealCount,
                        hoursSinceLastSoup: health.hoursSinceLastLiquidMeal,
                        lastSoupMeal: health.lastLiquidMeal,
                        status: health.digestiveBalanceStatus,
                        recommendationText: health.digestiveRecommendationText,
                        onOpenSoupCatalog: {
                            showingQuickSoupSheet = true
                        },
                        onAskNutritionist: {
                            showingNutritionistSheet = true
                        }
                    )
                    .padding(.horizontal)
                    
                    // 4. ДНЕВНИК ПРИЕМОВ ПИЩИ ЗА СЕГОДНЯ
                    TodayLoggedMealsDiaryView(
                        meals: health.loggedMealsToday,
                        onAddMeal: { cat in
                            defaultMealCategoryForManualAdd = cat
                            showingManualAddMealSheet = true
                        },
                        onDeleteMeal: { id in
                            health.deleteLoggedMeal(id: id)
                        }
                    )
                    .padding(.horizontal)
                    
                    // 4. ПАНЕЛЬ БЫСТРЫХ ДЕЙСТВИЙ (4 КНОПКИ)
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            Button(action: {
                                barcodeScannerMode = .plateAI
                                showingBarcodeScanner = true
                                HapticManager.shared.impact(.light)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "camera.fill")
                                        .font(.subheadline)
                                    Text("AI-Камера")
                                        .font(.caption)
                                        .bold()
                                }
                                .foregroundColor(Theme.cardBackground)
                                .padding(.vertical, 14)
                                .frame(maxWidth: .infinity)
                                .background(Theme.textPrimary)
                                .cornerRadius(16)
                            }
                            
                            Button(action: {
                                barcodeScannerMode = .barcode
                                showingBarcodeScanner = true
                                HapticManager.shared.impact(.light)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "barcode.viewfinder")
                                        .font(.subheadline)
                                        .foregroundColor(Theme.exerciseColor)
                                    Text("Штрих-код")
                                        .font(.caption)
                                        .bold()
                                }
                                .foregroundColor(Theme.textPrimary)
                                .padding(.vertical, 14)
                                .frame(maxWidth: .infinity)
                                .background(Theme.cardBackground)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Theme.textSecondary.opacity(0.2), lineWidth: 1)
                                )
                            }
                        }
                        
                        HStack(spacing: 10) {
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                HStack(spacing: 6) {
                                    Image(systemName: "photo.fill")
                                        .font(.subheadline)
                                        .foregroundColor(.orange)
                                    Text(tr("gallery"))
                                        .font(.caption)
                                        .bold()
                                }
                                .foregroundColor(Theme.textPrimary)
                                .padding(.vertical, 14)
                                .frame(maxWidth: .infinity)
                                .background(Theme.cardBackground)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Theme.textSecondary.opacity(0.2), lineWidth: 1)
                                )
                            }
                            
                            Button(action: {
                                defaultMealCategoryForManualAdd = MealCategory.defaultForCurrentHour()
                                showingManualAddMealSheet = true
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.subheadline)
                                        .foregroundColor(Color(red: 0/255, green: 229/255, blue: 255/255))
                                    Text("Вручную")
                                        .font(.caption)
                                        .bold()
                                }
                                .foregroundColor(Theme.textPrimary)
                                .padding(.vertical, 14)
                                .frame(maxWidth: .infinity)
                                .background(Theme.cardBackground)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Theme.textSecondary.opacity(0.2), lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // 5. ПЕРСОНАЛЬНЫЙ AI-НУТРИЦИОЛОГ БАННЕР
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: "brain.head.profile")
                                    .font(.title3)
                                    .foregroundColor(Color(red: 0/255, green: 229/255, blue: 255/255))
                                Text(tr("nutrition_ai_coach_title"))
                                    .font(.headline)
                                    .foregroundColor(Theme.textPrimary)
                            }
                            
                            Spacer()
                            
                            Text("Online")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        
                        Text(tr("nutrition_ai_coach_desc"))
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                            .lineSpacing(3)
                        
                        Button(action: {
                            showingNutritionistSheet = true
                        }) {
                            HStack {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                Text(tr("nutrition_ai_coach_btn"))
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0/255, green: 229/255, blue: 255/255), Color(red: 0/255, green: 145/255, blue: 255/255)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: Color(red: 0/255, green: 229/255, blue: 255/255).opacity(0.3), radius: 8)
                        }
                    }
                    .premiumCard()
                    .padding(.horizontal)
                    
                    // 6. ИНДИВИДУАЛЬНЫЙ ПЛАН ПИТАНИЯ
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .foregroundColor(.yellow)
                                .font(.title3)
                            Text("Индивидуальный план питания")
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
                            if let plan = generatedNutritionPlan {
                                ScrollView {
                                    Text(plan)
                                        .font(.subheadline)
                                        .foregroundColor(Theme.textPrimary.opacity(0.9))
                                        .lineSpacing(4)
                                        .multilineTextAlignment(.leading)
                                        .padding(12)
                                }
                                .frame(maxHeight: 220)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(16)
                            } else if let error = nutritionPlanError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(Theme.pulseColor)
                                    .padding()
                                    .background(Theme.pulseColor.opacity(0.08))
                                    .cornerRadius(16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                Text(tr("ai_nutrition_plan_desc"))
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                                    .padding(.vertical, 4)
                            }
                            
                            Button(action: {
                                runGenerateNutritionPlan()
                            }) {
                                HStack {
                                    if isGeneratingNutritionPlan {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .padding(.trailing, 8)
                                    }
                                    Text(isGeneratingNutritionPlan ? tr("ai_nutrition_plan_btn_planning") : tr("ai_nutrition_plan_btn_generate"))
                                        .bold()
                                }
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.white)
                                .padding()
                                .background(isGeneratingNutritionPlan ? Theme.exerciseColor.opacity(0.6) : Theme.exerciseColor)
                                .cornerRadius(16)
                                .shadow(color: Theme.exerciseColor.opacity(0.3), radius: 8)
                            }
                            .disabled(isGeneratingNutritionPlan)
                        }
                    }
                    .premiumCard()
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 120)
        }
    }
    
    // --- СЕКЦИЯ ВОДЫ И НАПИТКОВ ---
    private var waterTrackerSection: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 1. ГЛАВНАЯ КАРТОЧКА ГИДРАТАЦИИ
                VStack(spacing: 14) {
                    let progress = calculatedWaterNorm > 0 ? health.waterConsumed / calculatedWaterNorm : 0.0
                    
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(tr("water_consumed"))
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(.white.opacity(0.75))
                            
                            let consumedStr = LocalizationManager.formatNumber(Int(health.waterConsumed), lang: appLanguage)
                            let normStr = LocalizationManager.formatNumber(Int(calculatedWaterNorm), lang: appLanguage)
                            let unitStr = appLanguage == "en" ? "ml" : (appLanguage == "hy" ? "մլ" : "мл")
                            Text("\(consumedStr) / \(normStr) \(unitStr)")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            if progress >= 1.0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.seal.fill")
                                    Text(tr("water_goal_achieved"))
                                }
                                .font(.caption)
                                .bold()
                                .foregroundColor(.green)
                            } else {
                                Text(String(format: tr("water_completed_percent"), min(progress * 100.0, 100.0)))
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.white.opacity(0.75))
                            }
                            
                            // Интерактивная кнопка-раскрывалка адаптивной нормы
                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    showingWaterBreakdown.toggle()
                                }
                                HapticManager.shared.impact(.light)
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "sparkles")
                                        .font(.caption2)
                                        .foregroundColor(.yellow)
                                    Text("Адаптивная норма")
                                        .font(.caption2)
                                        .bold()
                                        .foregroundColor(.white)
                                    Image(systemName: showingWaterBreakdown ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.14))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 2)
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
                        .frame(width: 95, height: 95)
                    }
                    
                    // Декомпозиция адаптивной нормы (раскрывающийся блок)
                    if showingWaterBreakdown {
                        VStack(spacing: 8) {
                            Divider().background(Color.white.opacity(0.15))
                            
                            HStack {
                                Text("Декомпозиция вашей нормы:")
                                    .font(.caption2)
                                    .bold()
                                    .foregroundColor(.white.opacity(0.9))
                                Spacer()
                            }
                            
                            VStack(spacing: 6) {
                                waterBreakdownRow(
                                    icon: "scalemass.fill",
                                    iconColor: .cyan,
                                    title: "Базовая потребность (\(Int(health.currentWeight)) кг):",
                                    value: "\(Int(health.baseWaterNorm)) мл"
                                )
                                
                                if health.activityHydrationBonus > 0 {
                                    waterBreakdownRow(
                                        icon: "flame.fill",
                                        iconColor: .orange,
                                        title: "Восполнение пота от тренировок:",
                                        value: "+\(Int(health.activityHydrationBonus)) мл"
                                    )
                                }
                                
                                if health.stepHydrationBonus > 0 {
                                    waterBreakdownRow(
                                        icon: "figure.walk",
                                        iconColor: .green,
                                        title: "Активность шагов (\(health.stepsToday) шаг):",
                                        value: "+\(Int(health.stepHydrationBonus)) мл"
                                    )
                                }
                                
                                if health.caffeineAndAlcoholDehydrationCompensation > 0 {
                                    waterBreakdownRow(
                                        icon: "cup.and.saucer.fill",
                                        iconColor: Color(red: 215/255, green: 155/255, blue: 110/255),
                                        title: "Компенсация кофеина/алкоголя:",
                                        value: "+\(Int(health.caffeineAndAlcoholDehydrationCompensation)) мл"
                                    )
                                }
                                
                                if health.soupHydrationVolume > 0 {
                                    waterBreakdownRow(
                                        icon: "fork.knife",
                                        iconColor: Color(red: 0/255, green: 220/255, blue: 255/255),
                                        title: "Жидкость из супов и бульонов:",
                                        value: "+\(Int(health.soupHydrationVolume)) мл"
                                    )
                                }
                            }
                        }
                        .padding(.top, 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(20)
                .background(Theme.waterCardGradient)
                .cornerRadius(24)
                .shadow(color: Color(red: 0/255, green: 122/255, blue: 255/255).opacity(0.15), radius: 10)
                .padding(.horizontal)
                
                // 1.1 ИНТЕРАКТИВНЫЙ СТАКАН С ВОЛНАМИ И ЖЕСТАМИ
                InteractiveLiquidGlassView()
                    .padding(.horizontal)
                
                // 1.2 УМНАЯ ПОДСКАЗКА: КОМПЕНСАЦИЯ КОФЕИНА И ДЕГИДРАТАЦИИ
                if health.needsCaffeineWaterCompensation {
                    HStack(spacing: 12) {
                        Text("☕️")
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Восстановите баланс влаги")
                                .font(.caption)
                                .bold()
                                .foregroundColor(.white)
                            Text("Кофеин выводит жидкость. Рекомендуем выпить 200 мл чистой воды.")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.85))
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                health.addBeverage(type: .water, volumeMl: 200)
                            }
                            HapticManager.shared.impact(.medium)
                        }) {
                            Text("+200 мл")
                                .font(.caption)
                                .bold()
                                .foregroundColor(Color(red: 120/255, green: 70/255, blue: 38/255))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.white)
                                .cornerRadius(12)
                        }
                    }
                    .padding(14)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 165/255, green: 105/255, blue: 65/255), Color(red: 120/255, green: 70/255, blue: 38/255)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(20)
                    .shadow(color: Color(red: 165/255, green: 105/255, blue: 65/255).opacity(0.3), radius: 8)
                    .padding(.horizontal)
                }
                
                // 2. БЛОК ВЫБОРА И ДОБАВЛЕНИЯ НАПИТКОВ
                BeverageTrackerCardView(
                    selectedType: $selectedBeverageType,
                    onSelectPortion: { type, amount in
                        health.addBeverage(type: type, volumeMl: amount)
                    },
                    onOpenCustomSheet: {
                        showingCustomBeverageSheet = true
                    }
                )
                .padding(.horizontal)
                
                // 2.1 ТРЕКЕР КОФЕИНА И ОКНО БЕЗОПАСНОГО СНА
                CaffeineTrackerCardView()
                    .padding(.horizontal)
                
                // 2.2 ПОЧАСОВОЙ ТАЙМЛАЙН ГИДРАТАЦИИ ДНЯ
                HourlyHydrationTimelineView()
                    .padding(.horizontal)
                
                // 3. ЖУРНАЛ ВЫПИТЫХ НАПИТКОВ ЗА СЕГОДНЯ
                TodayLoggedBeveragesDiaryView(
                    beverages: health.loggedBeveragesToday,
                    waterConsumed: health.waterConsumed,
                    onDelete: { id in
                        health.deleteBeverage(id: id)
                    },
                    onReset: {
                        health.resetWater()
                    }
                )
                .padding(.horizontal)
                
                // 4. ИНДИВИДУАЛЬНЫЙ АДАПТИВНЫЙ РАСЧЕТ
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.yellow)
                        Text("Умный расчет потребности в воде")
                            .font(.headline)
                            .foregroundColor(Theme.textPrimary)
                    }
                    
                    Text("Ваша суточная норма рассчитывается динамически по формуле физиологов:")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text("•")
                                .bold()
                                .foregroundColor(Theme.exerciseColor)
                            Text("База: 35 мл на каждый кг веса (\(Int(health.baseWaterNorm)) мл)")
                                .font(.caption)
                                .foregroundColor(Theme.textPrimary)
                        }
                        
                        HStack(spacing: 6) {
                            Text("•")
                                .bold()
                                .foregroundColor(.orange)
                            Text("Тренировки: +0.75 мл на каждую сожженную активную ккал")
                                .font(.caption)
                                .foregroundColor(Theme.textPrimary)
                        }
                        
                        HStack(spacing: 6) {
                            Text("•")
                                .bold()
                                .foregroundColor(Color(red: 215/255, green: 155/255, blue: 110/255))
                            Text("Кофе/Алкоголь: компенсация мочегонного эффекта чистой водой")
                                .font(.caption)
                                .foregroundColor(Theme.textPrimary)
                        }
                        
                        HStack(spacing: 6) {
                            Text("•")
                                .bold()
                                .foregroundColor(Color(red: 0/255, green: 220/255, blue: 255/255))
                            Text("Первые блюда: 80% объема супов и бульонов идут в баланс")
                                .font(.caption)
                                .foregroundColor(Theme.textPrimary)
                        }
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(12)
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
                                Text(isAnalyzingWater ? tr("water_analyzing_btn") : tr("water_analyze_btn"))
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
            }
            .padding(.bottom, 120)
        }
    }
    
    private func waterBreakdownRow(icon: String, iconColor: Color, title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(iconColor)
                .frame(width: 16)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.85))
            
            Spacer()
            
            Text(value)
                .font(.caption2)
                .bold()
                .foregroundColor(.white)
        }
    }
    
    // --- СЕКЦИЯ ВЕСА (ПРОФЕССИОНАЛЬНЫЙ ТРЕКИНГ) ---
    private var weightTrackerSection: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 0. Энергетический баланс сегодня (Съедено vs Сожжено)
                DailyEnergyBalanceCardView(
                    caloriesConsumed: health.caloriesConsumedToday,
                    protein: health.proteinConsumedToday,
                    fat: health.fatConsumedToday,
                    carbs: health.carbsConsumedToday,
                    activeCaloriesBurned: health.activeEnergyBurned,
                    userWeight: health.currentWeight > 0 ? health.currentWeight : userWeight,
                    userHeight: userHeight,
                    userAge: userAge,
                    userGender: userGender
                )
                .padding(.horizontal)
                
                // 1. Карточка прогресса к целевому весу
                WeightGoalProgressCardView(
                    currentWeight: health.currentWeight > 0 ? health.currentWeight : userWeight,
                    targetWeight: userTargetWeight,
                    startWeight: userWeight,
                    weightHistory: health.weightHistory,
                    onOpenLog: {
                        showingWeightLogSheet = true
                    }
                )
                .padding(.horizontal)
                
                // 2. Интерактивный график динамики (Charts)
                WeightDynamicsChartView(
                    weightHistory: health.weightHistory,
                    targetWeight: userTargetWeight
                )
                .padding(.horizontal)
                
                // 3. Калькулятор и шкала ИМТ (BMI)
                BMICalculatorCardView(
                    currentWeight: health.currentWeight > 0 ? health.currentWeight : userWeight,
                    heightCm: userHeight
                )
                .padding(.horizontal)
                
                // 4. Совет и прогноз от выбранного ИИ-тренера
                AICoachWeightForecastCardView(
                    weightHistory: health.weightHistory,
                    targetWeight: userTargetWeight,
                    userHeight: userHeight,
                    onAskCoach: {
                        showingAICoachChatFromWeight = true
                    }
                )
                .padding(.horizontal)
                
                // 5. История всех замеров с возможностью удаления
                WeightLogHistorySection(
                    weightHistory: health.weightHistory,
                    onDelete: { id in
                        health.deleteWeightRecord(id: id)
                    }
                )
                .padding(.horizontal)
            }
            .padding(.top, 4)
            .padding(.bottom, 120)
        }
    }
    
    // --- МЕТОДЫ ЕДЫ ---
    private func resetScanState() {
        selectedImage = nil
        scanResult = nil
        scanError = nil
        selectedPhotoItem = nil
        currentIngredients = []
        userPromptHint = ""
        lastScannedBarcodeProduct = nil
    }
    
    private func updateIngredientWeight(id: String, delta: Double) {
        guard let idx = currentIngredients.firstIndex(where: { $0.id == id }) else { return }
        var item = currentIngredients[idx]
        let oldWeight = item.weight_grams
        let newWeight = max(10.0, oldWeight + delta)
        let ratio = newWeight / max(1.0, oldWeight)
        
        item.weight_grams = newWeight
        item.calories = max(1.0, item.calories * ratio)
        item.protein = max(0.0, item.protein * ratio)
        item.fat = max(0.0, item.fat * ratio)
        item.carbs = max(0.0, item.carbs * ratio)
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            currentIngredients[idx] = item
        }
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    private func removeIngredient(id: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            currentIngredients.removeAll { $0.id == id }
        }
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
    
    private func runFoodScan(image: UIImage) {
        isScanning = true
        scanError = nil
        scanResult = nil
        currentIngredients = []
        
        let hint = userPromptHint.trimmingCharacters(in: .whitespacesAndNewlines)
        
        Task {
            if !hasAnyApiKey {
                let localResult = await GeminiScanService.shared.scanFoodOffline(image: image, language: appLanguage)
                await MainActor.run {
                    self.scanResult = localResult
                    self.currentIngredients = localResult.ingredients
                    self.adjustedWeight = localResult.weight_grams
                    self.isScanning = false
                }
            } else {
                do {
                    let result = try await GeminiScanService.shared.scanFood(image: image, language: appLanguage, userHint: hint.isEmpty ? nil : hint)
                    await MainActor.run {
                        self.scanResult = result
                        self.currentIngredients = result.ingredients
                        self.adjustedWeight = result.weight_grams
                        self.isScanning = false
                    }
                } catch {
                    let offlineResult = await GeminiScanService.shared.scanFoodOffline(image: image, language: appLanguage)
                    await MainActor.run {
                        self.scanResult = offlineResult
                        self.currentIngredients = offlineResult.ingredients
                        self.adjustedWeight = offlineResult.weight_grams
                        self.isScanning = false
                    }
                }
            }
        }
    }
    
    private func saveToHealthKit() {
        let dishName = scanResult?.dish ?? "Прием пищи"
        let category = MealCategory.defaultForCurrentHour()
        let detectedTexture = scanResult?.resolvedTexture ?? MealTextureType.detect(from: dishName)
        let defaultEmoji = detectedTexture == .liquidSoup ? "🍲" : category.emoji
        let mealRecord = LoggedMealRecord(
            name: dishName,
            calories: totalCalories,
            protein: totalProtein,
            fat: totalFat,
            carbs: totalCarbs,
            weightGrams: totalWeight,
            category: category,
            date: Date(),
            emoji: currentIngredients.first?.emoji ?? defaultEmoji,
            textureType: detectedTexture
        )
        health.addLoggedMeal(mealRecord)
        GamificationManager.shared.addXP(30, reason: "Прием пищи: \(dishName)")
        
        selectedImage = nil
        scanResult = nil
        currentIngredients = []
        userPromptHint = ""
        lastScannedBarcodeProduct = nil
        
        let impact = UINotificationFeedbackGenerator()
        impact.notificationOccurred(.success)
    }
    
    private func handleScannedBarcode(_ product: BarcodeProduct) {
        lastScannedBarcodeProduct = product
        let scan = BarcodeScannerService.shared.convertToScanResult(product: product, portionGrams: product.servingWeightGrams)
        self.scanResult = scan
        self.currentIngredients = scan.ingredients
        self.adjustedWeight = product.servingWeightGrams
        let impact = UINotificationFeedbackGenerator()
        impact.notificationOccurred(.success)
    }
    
    private func runGenerateNutritionPlan() {
        guard hasAnyApiKey else { return }
        isGeneratingNutritionPlan = true
        nutritionPlanError = nil
        
        let weight = health.currentWeight > 0 ? health.currentWeight : userWeight
        
        // Сформируем сводку о недавних тренировках
        var workoutsSummary = "Нет недавних тренировок"
        if !health.workoutHistory.isEmpty {
            workoutsSummary = health.workoutHistory.prefix(3).map { workout in
                "- \(workout.type): \(Int(workout.caloriesBurned)) ккал, \(workout.durationMinutes) мин"
            }.joined(separator: "\n")
        }
        
        Task {
            do {
                let plan = try await GeminiScanService.shared.generateNutritionPlan(
                    age: userAge,
                    height: userHeight,
                    weight: weight,
                    gender: userGender,
                    targetWeight: userTargetWeight,
                    activityLevel: userActivityLevel,
                    recentWorkoutsSummary: workoutsSummary,
                    language: appLanguage
                )
                await MainActor.run {
                    self.generatedNutritionPlan = plan
                    UserDefaults.standard.set(plan, forKey: "generated_nutrition_plan")
                    self.isGeneratingNutritionPlan = false
                }
            } catch {
                await MainActor.run {
                    self.nutritionPlanError = "Не удалось составить план: \(error.localizedDescription)"
                    self.isGeneratingNutritionPlan = false
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
                    weight: health.currentWeight,
                    beveragesSummary: health.beveragesSummaryString,
                    language: appLanguage
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
                     nutrition: health.nutritionHistory,
                     language: appLanguage
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

// MARK: - Модальное окно добавления ингредиента
struct AddIngredientSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (FoodIngredient) -> Void
    
    @State private var newIngredientName = ""
    @State private var newIngredientWeight: Double = 100.0
    @State private var newIngredientCalories: Double = 120.0
    @State private var newIngredientProtein: Double = 6.0
    @State private var newIngredientFat: Double = 3.0
    @State private var newIngredientCarbs: Double = 15.0
    @State private var newIngredientEmoji = "🥑"
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Название продукта")
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(Theme.textPrimary)
                        
                        TextField("Например: Авокадо или Соус", text: $newIngredientName)
                            .font(.body)
                            .foregroundColor(Theme.textPrimary)
                            .padding()
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                    }
                    
                    // Выбор Emoji
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Иконка")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(["🥑", "🍗", "🥩", "🐟", "🍚", "🥗", "🍞", "🥚", "🧀", "☕", "🍎", "🥜", "🍝", "🍫"], id: \.self) { em in
                                    Text(em)
                                        .font(.title2)
                                        .padding(10)
                                        .background(newIngredientEmoji == em ? Theme.exerciseColor.opacity(0.35) : Color.white.opacity(0.06))
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(newIngredientEmoji == em ? Theme.exerciseColor : Color.clear, lineWidth: 2)
                                        )
                                        .onTapGesture {
                                            newIngredientEmoji = em
                                            let impact = UIImpactFeedbackGenerator(style: .light)
                                            impact.impactOccurred()
                                        }
                                }
                            }
                        }
                    }
                    
                    // Степперы веса и БЖУ
                    VStack(spacing: 14) {
                        HStack {
                            Text("Вес порции:")
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                            Stepper(value: $newIngredientWeight, in: 5...1500, step: 10) {
                                Text("\(Int(newIngredientWeight)) г")
                                    .bold()
                                    .foregroundColor(Theme.textPrimary)
                            }
                        }
                        
                        HStack {
                            Text("Калории:")
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                            Stepper(value: $newIngredientCalories, in: 0...2000, step: 10) {
                                Text("\(Int(newIngredientCalories)) ккал")
                                    .bold()
                                    .foregroundColor(Theme.pulseColor)
                            }
                        }
                        
                        HStack {
                            Text("Б / Ж / У:")
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                            HStack(spacing: 8) {
                                Text("Б:\(Int(newIngredientProtein))")
                                        .font(.caption).bold().foregroundColor(.green)
                                Text("Ж:\(Int(newIngredientFat))")
                                        .font(.caption).bold().foregroundColor(.orange)
                                Text("У:\(Int(newIngredientCarbs))")
                                        .font(.caption).bold().foregroundColor(.blue)
                            }
                        }
                        
                        HStack(spacing: 12) {
                            Stepper("Б: \(Int(newIngredientProtein))", value: $newIngredientProtein, in: 0...200, step: 1)
                                .font(.caption2)
                            Stepper("Ж: \(Int(newIngredientFat))", value: $newIngredientFat, in: 0...200, step: 1)
                                .font(.caption2)
                            Stepper("У: \(Int(newIngredientCarbs))", value: $newIngredientCarbs, in: 0...200, step: 1)
                                .font(.caption2)
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(16)
                    
                    Spacer()
                    
                    Button(action: {
                        let name = newIngredientName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let finalName = name.isEmpty ? "Ингредиент" : name
                        let item = FoodIngredient(
                            name: finalName,
                            weight_grams: newIngredientWeight,
                            calories: newIngredientCalories,
                            protein: newIngredientProtein,
                            fat: newIngredientFat,
                            carbs: newIngredientCarbs,
                            emoji: newIngredientEmoji
                        )
                        onAdd(item)
                        dismiss()
                        let impact = UINotificationFeedbackGenerator()
                        impact.notificationOccurred(.success)
                    }) {
                        Text("+ Добавить продукт")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.exerciseColor)
                            .cornerRadius(16)
                            .shadow(color: Theme.exerciseColor.opacity(0.3), radius: 8)
                    }
                }
                .padding()
            }
            .navigationTitle("Новый ингредиент")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Карточка Энергетического баланса и прогноза веса
struct FoodDailyEnergyBalanceCard: View {
    let caloriesConsumed: Double
    let protein: Double
    let fat: Double
    let carbs: Double
    let activeCaloriesBurned: Double
    let userWeight: Double
    let userTargetWeight: Double
    let userHeight: Int
    let userAge: Int
    let userGender: String
    
    // BMR по формуле Миффлина-Сан Жеора с калибровкой соматотипа
    private var somatotype: Somatotype {
        let raw = UserDefaults.standard.string(forKey: "user_somatotype") ?? "mesomorph"
        return Somatotype(rawValue: raw) ?? .mesomorph
    }
    
    private var bmrCalories: Double {
        let w = max(30.0, userWeight)
        let h = Double(max(100, userHeight))
        let a = Double(max(14, userAge))
        let isMale = userGender.lowercased().contains("муж") || userGender.lowercased() == "male"
        
        let baseBmr: Double
        if isMale {
            baseBmr = (10.0 * w) + (6.25 * h) - (5.0 * a) + 5.0
        } else {
            baseBmr = (10.0 * w) + (6.25 * h) - (5.0 * a) - 161.0
        }
        return baseBmr * somatotype.metabolismMultiplier
    }
    
    private var totalCaloriesBurned: Double {
        bmrCalories + activeCaloriesBurned
    }
    
    private var energyBalance: Double {
        caloriesConsumed - totalCaloriesBurned
    }
    
    private var estimatedFatChangeGrams: Double {
        (energyBalance / 7700.0) * 1000.0
    }
    
    private var statusInfo: (title: String, color: Color, icon: String) {
        if energyBalance < -150 {
            return ("Дефицит", .green, "flame.fill")
        } else if energyBalance > 150 {
            return ("Профицит", .orange, "bolt.fill")
        } else {
            return ("Энергобаланс", Theme.standColor, "equal.circle.fill")
        }
    }
    
    private var daysToGoalString: String {
        let diffKg = userWeight - userTargetWeight
        if diffKg <= 0 {
            return "Целевой вес достигнут! Отличная форма 🔥"
        }
        if energyBalance < -100 {
            let dailyDeficit = abs(energyBalance)
            let totalDeficitNeeded = diffKg * 7700.0
            let days = Int(ceil(totalDeficitNeeded / dailyDeficit))
            return "При текущем дефиците до цели ~\(days) дн. (\(String(format: "%.0f", userTargetWeight)) кг)"
        } else {
            return "Для активного снижения держи дефицит 300–500 ккал/день"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Верхняя плашка статуса
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: statusInfo.icon)
                        .foregroundColor(statusInfo.color)
                    Text("Энергобаланс и прогноз веса")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                }
                Spacer()
                
                HStack(spacing: 4) {
                    Text(statusInfo.title)
                    Text("\(energyBalance > 0 ? "+" : "")\(Int(energyBalance)) ккал")
                        .bold()
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(statusInfo.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(statusInfo.color.opacity(0.14))
                .cornerRadius(10)
            }
            
            // Две карточки: Поступило vs Сожжено
            HStack(spacing: 12) {
                // Поступило
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Image(systemName: "fork.knife")
                            .font(.caption2)
                            .foregroundColor(.green)
                        Text("Поступило")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                    Text("\(Int(caloriesConsumed)) ккал")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                    
                    HStack(spacing: 6) {
                        Text("Б:\(Int(protein))г").foregroundColor(.green)
                        Text("Ж:\(Int(fat))г").foregroundColor(.orange)
                        Text("У:\(Int(carbs))г").foregroundColor(.blue)
                    }
                    .font(.system(size: 9, weight: .bold))
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.04))
                .cornerRadius(14)
                
                // Сожжено (BMR + Активность)
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                            .foregroundColor(Theme.moveColor)
                        Text("Сожжено")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                    Text("\(Int(totalCaloriesBurned)) ккал")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                    
                    HStack(spacing: 4) {
                        Text("\(somatotype.emoji) BMR: \(Int(bmrCalories))")
                        Text("+ Акт: \(Int(activeCaloriesBurned))")
                    }
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.04))
                .cornerRadius(14)
            }
            
            Divider()
                .background(Color.white.opacity(0.06))
            
            // Теоретическое изменение жировой массы за сегодня
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(statusInfo.color.opacity(0.15))
                        .frame(width: 42, height: 42)
                    Image(systemName: energyBalance <= 0 ? "arrow.down.right" : "arrow.up.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(statusInfo.color)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    let grams = abs(estimatedFatChangeGrams)
                    if energyBalance < -50 {
                        Text("Теоретически сожжено: **~\(String(format: "%.0f", grams)) г жира**")
                            .font(.subheadline)
                            .foregroundColor(Theme.textPrimary)
                    } else if energyBalance > 50 {
                        Text("Теоретический прирост: **+\(String(format: "%.0f", grams)) г**")
                            .font(.subheadline)
                            .foregroundColor(Theme.textPrimary)
                    } else {
                        Text("Вес в стабильном балансе (**0 г**)")
                            .font(.subheadline)
                            .foregroundColor(Theme.textPrimary)
                    }
                    
                    Text(daysToGoalString)
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer()
            }
        }
        .premiumCard()
    }
}

// MARK: - Карточка вердикта AI-Тренера по питанию
struct AICoachNutritionCard: View {
    let coach: AICoachPersona
    let caloriesConsumed: Double
    let calorieBalance: Double
    let protein: Double
    var solidStreak: Int = 0
    let onAskCoach: () -> Void
    
    private var coachVerdict: String {
        if solidStreak >= 3 {
            return "Внимание: ты ешь плотную пищу уже \(solidStreak)-й прием подряд («сухомятка»)! Чтобы ЖКТ не перегружался и не было тяжести, обязательно добавь в рацион горячий бульон или крем-суп."
        } else if caloriesConsumed == 0 {
            return "Зафиксируй первый прием пищи сегодня, чтобы я рассчитал точный баланс калорий и динамику веса!"
        } else if calorieBalance < -300 {
            if protein >= 80 {
                return "Отличный темп дефицита! Белка достаточно для защиты мышечной массы. Форма прогрессирует!"
            } else {
                return "Хороший дефицит калорий, но добавь порцию белка (курица, рыба, творог), чтобы не терять мышцы."
            }
        } else if calorieBalance > 200 {
            return "Сейчас профицит калорий (+\(Int(calorieBalance)) ккал). Добавь 15 минут кардио или снизь углеводы на ужин."
        } else {
            return "Рацион близок к поддержанию веса. Для активного сброса веса держи легкий дефицит ~300-500 ккал."
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                AITrainerAvatarView(coachState: .idle, size: 48, customCoach: coach)
                    .frame(width: 48, height: 48)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Тренер \(coach.name)")
                            .font(.headline)
                            .foregroundColor(Theme.textPrimary)
                        Text(coach.badgeEmoji)
                    }
                    Text(coach.specialty)
                        .font(.caption2)
                        .foregroundColor(coach.accentColor)
                }
                Spacer()
            }
            
            Text("«\(coachVerdict)»")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.textPrimary.opacity(0.95))
                .lineSpacing(3)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(coach.accentColor.opacity(0.08))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(coach.accentColor.opacity(0.2), lineWidth: 1)
                )
            
            Button(action: onAskCoach) {
                HStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                    Text("Спросить тренера \(coach.name) о рационе")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [coach.accentColor, coach.accentColor.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(14)
                .shadow(color: coach.accentColor.opacity(0.3), radius: 6)
            }
        }
        .premiumCard()
    }
}

// MARK: - Дневник приемов пищи за сегодня
struct TodayLoggedMealsDiaryView: View {
    let meals: [LoggedMealRecord]
    let onAddMeal: (MealCategory) -> Void
    let onDeleteMeal: (UUID) -> Void
    
    private func meals(for category: MealCategory) -> [LoggedMealRecord] {
        meals.filter { $0.category == category }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "list.bullet.clipboard.fill")
                        .foregroundColor(Theme.exerciseColor)
                    Text("Дневник питания за сегодня")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                }
                Spacer()
                
                Text("(\(meals.count))")
                    .font(.caption)
                    .bold()
                    .foregroundColor(Theme.textSecondary)
            }
            
            if meals.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "fork.knife.circle")
                        .font(.system(size: 36))
                        .foregroundColor(Theme.textSecondary.opacity(0.35))
                    Text("За сегодня еще нет записей о еде")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                    Text("Сфотографируй блюдо, отсканируй штрих-код или нажми «Вручную»")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.02))
                .cornerRadius(14)
            } else {
                VStack(spacing: 12) {
                    ForEach(MealCategory.allCases) { cat in
                        let catMeals = meals(for: cat)
                        if !catMeals.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("\(cat.emoji) \(cat.title)")
                                        .font(.subheadline)
                                        .bold()
                                        .foregroundColor(Theme.textPrimary)
                                    Spacer()
                                    let catCal = catMeals.reduce(0.0) { $0 + $1.calories }
                                    Text("\(Int(catCal)) ккал")
                                        .font(.caption)
                                        .bold()
                                        .foregroundColor(Theme.pulseColor)
                                }
                                
                                ForEach(catMeals) { meal in
                                    HStack(spacing: 10) {
                                        Text(meal.emoji)
                                            .font(.title3)
                                            .frame(width: 32, height: 32)
                                            .background(Color.white.opacity(0.05))
                                            .clipShape(Circle())
                                        
                                        VStack(alignment: .leading, spacing: 3) {
                                            HStack(spacing: 6) {
                                                Text(meal.name)
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundColor(Theme.textPrimary)
                                                
                                                Text(meal.resolvedTexture.shortBadge)
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundColor(meal.resolvedTexture.color)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(meal.resolvedTexture.color.opacity(0.12))
                                                    .clipShape(Capsule())
                                            }
                                            
                                            HStack(spacing: 6) {
                                                if meal.weightGrams > 0 {
                                                    Text("\(Int(meal.weightGrams)) г •")
                                                        .foregroundColor(Theme.textSecondary)
                                                }
                                                Text("Б:\(Int(meal.protein))г").foregroundColor(.green)
                                                Text("Ж:\(Int(meal.fat))г").foregroundColor(.orange)
                                                Text("У:\(Int(meal.carbs))г").foregroundColor(.blue)
                                            }
                                            .font(.system(size: 10, weight: .bold))
                                        }
                                        
                                        Spacer()
                                        
                                        Text("\(Int(meal.calories)) ккал")
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundColor(Theme.textPrimary)
                                        
                                        Button(action: {
                                            let impact = UIImpactFeedbackGenerator(style: .light)
                                            impact.impactOccurred()
                                            onDeleteMeal(meal.id)
                                        }) {
                                            Image(systemName: "trash")
                                                .font(.caption)
                                                .foregroundColor(Theme.textSecondary.opacity(0.5))
                                                .padding(6)
                                        }
                                    }
                                    .padding(10)
                                    .background(Color.white.opacity(0.04))
                                    .cornerRadius(12)
                                }
                            }
                            .padding(10)
                            .background(Color.white.opacity(0.02))
                            .cornerRadius(14)
                        }
                    }
                }
            }
        }
        .premiumCard()
    }
}

// MARK: - Модальное окно добавления приема пищи (Гибридный каталог + Свой ввод)
struct ManualAddMealSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let initialCategory: MealCategory
    let onSave: (LoggedMealRecord) -> Void
    
    enum AddMealTab: String, CaseIterable, Identifiable {
        case catalog = "База продуктов"
        case custom = "Свой ввод"
        var id: String { rawValue }
    }
    
    @ObservedObject private var catalogService = FoodCatalogService.shared
    @State private var activeTab: AddMealTab = .catalog
    
    // --- Поиск по каталогу ---
    @State private var searchText: String = ""
    @State private var selectedCatalogCategory: FoodGroupCategory = .all
    @State private var selectedItemForPortion: FoodCatalogItem? = nil
    @State private var portionGrams: Double = 100.0
    
    // --- Ручной ввод ---
    @State private var mealName: String = ""
    @State private var category: MealCategory = .lunch
    @State private var calories: Double = 350.0
    @State private var protein: Double = 25.0
    @State private var fat: Double = 12.0
    @State private var carbs: Double = 35.0
    @State private var weightGrams: Double = 250.0
    @State private var selectedEmoji: String = "🍽️"
    @State private var selectedTexture: MealTextureType = .solidDense
    @State private var saveToCustomCatalog: Bool = false
    
    init(initialCategory: MealCategory = .lunch, onSave: @escaping (LoggedMealRecord) -> Void) {
        self.initialCategory = initialCategory
        self.onSave = onSave
        _category = State(initialValue: initialCategory)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Переключатель режимов: База vs Свой ввод
                    Picker("Режим", selection: $activeTab) {
                        ForEach(AddMealTab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    
                    if activeTab == .catalog {
                        catalogBrowserView
                    } else {
                        customEntryScrollView
                    }
                }
            }
            .navigationTitle(activeTab == .catalog ? "База продуктов" : "Свой прием пищи")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedItemForPortion) { item in
                PortionSelectionSheetView(
                    item: item,
                    initialCategory: category,
                    onConfirm: { chosenRecord in
                        catalogService.recordUsage(item: item)
                        onSave(chosenRecord)
                        selectedItemForPortion = nil
                        dismiss()
                    }
                )
            }
        }
    }
    
    // MARK: - Вкладка: Каталог и поиск продуктов
    private var catalogBrowserView: some View {
        VStack(spacing: 10) {
            // Строка поиска
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Theme.textSecondary)
                
                TextField("Поиск: гречка, яйцо, курица, борщ...", text: $searchText)
                    .font(.body)
                    .foregroundColor(Theme.textPrimary)
                    .autocorrectionDisabled()
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        HapticManager.shared.impact(.light)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.06))
            .cornerRadius(14)
            .padding(.horizontal)
            
            // Лента категорий (горизонтальный скролл)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(FoodGroupCategory.allCases) { cat in
                        Button(action: {
                            selectedCatalogCategory = cat
                            HapticManager.shared.impact(.light)
                        }) {
                            HStack(spacing: 5) {
                                Text(cat.emoji)
                                    .font(.caption)
                                Text(cat.title)
                                    .font(.caption)
                                    .bold()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                selectedCatalogCategory == cat
                                ? Theme.exerciseColor
                                : Color.white.opacity(0.06)
                            )
                            .foregroundColor(selectedCatalogCategory == cat ? .white : Theme.textPrimary)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedCatalogCategory == cat ? Theme.exerciseColor : Color.clear, lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
            
            // Список продуктов
            let searchResults = catalogService.search(query: searchText, category: selectedCatalogCategory)
            
            if searchResults.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 44))
                        .foregroundColor(Theme.textSecondary.opacity(0.6))
                    Text("Ничего не найдено")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                    Text("Попробуйте другой запрос или перейдите на вкладку «Свой ввод», чтобы добавить блюдо вручную.")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    Button(action: {
                        mealName = searchText
                        activeTab = .custom
                        HapticManager.shared.impact(.light)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("Добавить «\(searchText.isEmpty ? "свое блюдо" : searchText)»")
                        }
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(Theme.exerciseColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Theme.exerciseColor.opacity(0.12))
                        .cornerRadius(12)
                    }
                    .padding(.top, 8)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(searchResults) { item in
                            catalogItemRow(item)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
        }
    }
    
    // MARK: - Строка продукта в каталоге
    private func catalogItemRow(_ item: FoodCatalogItem) -> some View {
        Button(action: {
            portionGrams = item.defaultPortionGrams
            selectedItemForPortion = item
            HapticManager.shared.impact(.light)
        }) {
            HStack(spacing: 12) {
                // Иконка
                Text(item.emoji)
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
                
                // Название и БЖУ
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(item.name)
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(Theme.textPrimary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Кнопка избранного
                        Button(action: {
                            catalogService.toggleFavorite(item: item)
                            HapticManager.shared.impact(.light)
                        }) {
                            Image(systemName: catalogService.isFavorite(itemId: item.id) ? "star.fill" : "star")
                                .font(.caption)
                                .foregroundColor(catalogService.isFavorite(itemId: item.id) ? .yellow : Theme.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    HStack(spacing: 8) {
                        Text("\(Int(item.caloriesPer100g)) ккал/100г")
                            .font(.caption2)
                            .bold()
                            .foregroundColor(Theme.pulseColor)
                        
                        Text("Б: \(String(format: "%.1f", item.proteinPer100g))г")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                        
                        Text("Ж: \(String(format: "%.1f", item.fatPer100g))г")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                        
                        Text("У: \(String(format: "%.1f", item.carbsPer100g))г")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                    
                    // Бейджи категории и текстуры ЖКТ
                    HStack(spacing: 6) {
                        HStack(spacing: 3) {
                            Text(item.textureType.emoji)
                            Text(item.textureType.shortBadge)
                        }
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(item.textureType.color.opacity(0.15))
                        .foregroundColor(item.textureType.color)
                        .cornerRadius(6)
                        
                        Text(item.portionName)
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.04))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Вкладка: Ручной ввод блюда (Custom Entry)
    private var customEntryScrollView: some View {
        ScrollView {
            VStack(spacing: 20) {
                mealCategoryPickerSection
                mealNameInputSection
                mealTextureSection
                mealEmojiPickerSection
                mealMacrosSteppersSection
                mealSaveOptionsSection
                mealSubmitButton
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }
    
    private var mealCategoryPickerSection: some View {
        Picker("Категория", selection: $category) {
            ForEach(MealCategory.allCases) { cat in
                Text("\(cat.emoji) \(cat.title)").tag(cat)
            }
        }
        .pickerStyle(.segmented)
        .padding(.top, 4)
    }
    
    private var mealNameInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Название блюда или продукта")
                .font(.subheadline)
                .bold()
                .foregroundColor(Theme.textPrimary)
            
            TextField("Например: Куриный бульон с зеленью", text: $mealName)
                .font(.body)
                .foregroundColor(Theme.textPrimary)
                .padding()
                .background(Color.white.opacity(0.06))
                .cornerRadius(14)
                .onChange(of: mealName) { _, newName in
                    let detected = MealTextureType.detect(from: newName, emoji: selectedEmoji)
                    selectedTexture = detected
                    if detected == .liquidSoup && (selectedEmoji == "🍽️" || selectedEmoji == "🥗") {
                        selectedEmoji = "🍲"
                    }
                }
        }
    }
    
    private var mealTextureSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Консистенция для ЖКТ")
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Text(selectedTexture.digestionTimeEstimate)
                    .font(.caption2)
                    .foregroundColor(selectedTexture.color)
            }
            
            Picker("Консистенция", selection: $selectedTexture) {
                ForEach(MealTextureType.allCases) { tex in
                    Text("\(tex.emoji) \(tex.shortBadge)").tag(tex)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    private var mealEmojiPickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Иконка")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(["🍲", "🥣", "🍜", "🍳", "🥗", "🍗", "🥩", "🐟", "🍚", "🥑", "🍞", "🥚", "🧀", "🍎", "🍌", "🥜", "🍫", "☕", "🍽️"], id: \.self) { em in
                        Text(em)
                            .font(.title2)
                            .padding(10)
                            .background(selectedEmoji == em ? Theme.exerciseColor.opacity(0.35) : Color.white.opacity(0.06))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(selectedEmoji == em ? Theme.exerciseColor : Color.clear, lineWidth: 2)
                            )
                            .onTapGesture {
                                selectedEmoji = em
                                if em == "🍲" || em == "🥣" || em == "🍜" {
                                    selectedTexture = .liquidSoup
                                }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                    }
                }
            }
        }
    }
    
    private var mealMacrosSteppersSection: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Вес порции:")
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Stepper(value: $weightGrams, in: 10...2000, step: 25) {
                    Text("\(Int(weightGrams)) г")
                        .bold()
                        .foregroundColor(Theme.textPrimary)
                }
            }
            
            HStack {
                Text("Калории:")
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Stepper(value: $calories, in: 0...3000, step: 25) {
                    Text("\(Int(calories)) ккал")
                        .bold()
                        .foregroundColor(Theme.pulseColor)
                }
            }
            
            HStack(spacing: 8) {
                Stepper("Б: \(Int(protein))г", value: $protein, in: 0...250, step: 1)
                    .font(.caption)
                Stepper("Ж: \(Int(fat))г", value: $fat, in: 0...250, step: 1)
                    .font(.caption)
                Stepper("У: \(Int(carbs))г", value: $carbs, in: 0...350, step: 1)
                    .font(.caption)
            }
        }
        .padding()
        .background(Color.white.opacity(0.04))
        .cornerRadius(16)
    }
    
    private var mealSaveOptionsSection: some View {
        Toggle(isOn: $saveToCustomCatalog) {
            HStack(spacing: 6) {
                Image(systemName: "square.and.arrow.down.on.square.fill")
                    .foregroundColor(Theme.exerciseColor)
                Text("Сохранить в мою базу продуктов")
                    .font(.subheadline)
                    .foregroundColor(Theme.textPrimary)
            }
        }
        .padding(.horizontal, 4)
    }
    
    private var mealSubmitButton: some View {
        Button(action: submitManualMeal) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Сохранить в дневник")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Theme.exerciseColor)
            .cornerRadius(16)
            .shadow(color: Theme.exerciseColor.opacity(0.3), radius: 8)
        }
    }
    
    private func submitManualMeal() {
        let name = mealName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = name.isEmpty ? "\(category.title)" : name
        let record = LoggedMealRecord(
            name: finalName,
            calories: calories,
            protein: protein,
            fat: fat,
            carbs: carbs,
            weightGrams: weightGrams,
            category: category,
            date: Date(),
            emoji: selectedEmoji,
            textureType: selectedTexture
        )
        
        if saveToCustomCatalog {
            let ratio = weightGrams > 0 ? (100.0 / weightGrams) : 1.0
            let customItem = FoodCatalogItem(
                name: finalName,
                category: selectedTexture == .liquidSoup ? .soups : .meat,
                caloriesPer100g: calories * ratio,
                proteinPer100g: protein * ratio,
                fatPer100g: fat * ratio,
                carbsPer100g: carbs * ratio,
                defaultPortionGrams: weightGrams,
                portionName: "\(Int(weightGrams)) г",
                textureType: selectedTexture,
                emoji: selectedEmoji,
                aliases: [finalName],
                isUserCustom: true
            )
            catalogService.addCustomItem(item: customItem)
        }
        
        onSave(record)
        dismiss()
        let impact = UINotificationFeedbackGenerator()
        impact.notificationOccurred(.success)
    }
}

// MARK: - Модальное окно выбора порции продукта из каталога
struct PortionSelectionSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let item: FoodCatalogItem
    let initialCategory: MealCategory
    let onConfirm: (LoggedMealRecord) -> Void
    
    @State private var mealCategory: MealCategory
    @State private var portionGrams: Double
    
    init(item: FoodCatalogItem, initialCategory: MealCategory, onConfirm: @escaping (LoggedMealRecord) -> Void) {
        self.item = item
        self.initialCategory = initialCategory
        self.onConfirm = onConfirm
        _mealCategory = State(initialValue: initialCategory)
        _portionGrams = State(initialValue: item.defaultPortionGrams)
    }
    
    private var computedMacros: (calories: Double, protein: Double, fat: Double, carbs: Double) {
        item.macros(for: portionGrams)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Карточка продукта в шапке
                    HStack(spacing: 14) {
                        Text(item.emoji)
                            .font(.system(size: 40))
                            .frame(width: 60, height: 60)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .font(.headline)
                                .bold()
                                .foregroundColor(Theme.textPrimary)
                            
                            HStack(spacing: 6) {
                                HStack(spacing: 3) {
                                    Text(item.textureType.emoji)
                                    Text(item.textureType.shortBadge)
                                }
                                .font(.caption2)
                                .bold()
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(item.textureType.color.opacity(0.18))
                                .foregroundColor(item.textureType.color)
                                .cornerRadius(6)
                                
                                Text(item.category.title)
                                    .font(.caption2)
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(18)
                    
                    // Выбор категории приема пищи
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Прием пищи")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        
                        Picker("Прием пищи", selection: $mealCategory) {
                            ForEach(MealCategory.allCases) { cat in
                                Text("\(cat.emoji) \(cat.title)").tag(cat)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    // Быстрые пресеты веса
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Быстрый выбор порции")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        
                        let presets: [Double] = Array(Set([50.0, 100.0, 150.0, 200.0, 250.0, 300.0, item.defaultPortionGrams])).sorted()
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(presets, id: \.self) { grams in
                                    Button(action: {
                                        portionGrams = grams
                                        HapticManager.shared.impact(.light)
                                    }) {
                                        Text("\(Int(grams)) г")
                                            .font(.caption)
                                            .bold()
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(portionGrams == grams ? Theme.exerciseColor : Color.white.opacity(0.06))
                                            .foregroundColor(portionGrams == grams ? .white : Theme.textPrimary)
                                            .cornerRadius(10)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Точный степпер
                    HStack {
                        Text("Точный вес:")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                        Spacer()
                        Stepper(value: $portionGrams, in: 10...1500, step: 10) {
                            Text("\(Int(portionGrams)) г")
                                .font(.title3)
                                .bold()
                                .foregroundColor(Theme.textPrimary)
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(16)
                    
                    // Итоговый расчет БЖУ
                    let m = computedMacros
                    VStack(spacing: 8) {
                        HStack {
                            Text("Итого:")
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                            Text("\(Int(m.calories)) ккал")
                                .font(.title2)
                                .bold()
                                .foregroundColor(Theme.pulseColor)
                        }
                        
                        Divider().background(Color.white.opacity(0.08))
                        
                        HStack(spacing: 12) {
                            macroPill(title: "Белки", value: m.protein, color: .orange)
                            macroPill(title: "Жиры", value: m.fat, color: .yellow)
                            macroPill(title: "Углеводы", value: m.carbs, color: .cyan)
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                    
                    Spacer()
                    
                    // Кнопка добавления
                    Button(action: {
                        let record = item.toLoggedMealRecord(weightGrams: portionGrams, category: mealCategory)
                        onConfirm(record)
                        dismiss()
                        let impact = UINotificationFeedbackGenerator()
                        impact.notificationOccurred(.success)
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                            Text("Добавить в \(mealCategory.title) • \(Int(m.calories)) ккал")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.exerciseColor)
                        .cornerRadius(16)
                        .shadow(color: Theme.exerciseColor.opacity(0.35), radius: 10)
                    }
                }
                .padding()
            }
            .navigationTitle("Порция продукта")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private func macroPill(title: String, value: Double, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
            Text("\(String(format: "%.1f", value))г")
                .font(.subheadline)
                .bold()
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
}


// MARK: - Карточка выбора и добавления напитков
struct BeverageTrackerCardView: View {
    @Binding var selectedType: BeverageType
    let onSelectPortion: (BeverageType, Double) -> Void
    let onOpenCustomSheet: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "cup.and.saucer.fill")
                        .foregroundColor(selectedType.accentColor)
                    Text("Выбрать напиток")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                }
                Spacer()
                
                Text(selectedType.title)
                    .font(.caption)
                    .bold()
                    .foregroundColor(selectedType.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(selectedType.accentColor.opacity(0.12))
                    .cornerRadius(10)
            }
            
            // Горизонтальный ряд пилюль выбора напитка
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(BeverageType.allCases) { type in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                selectedType = type
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }) {
                            HStack(spacing: 6) {
                                Text(type.emoji)
                                    .font(.subheadline)
                                Text(type.title)
                                    .font(.caption)
                                    .bold()
                            }
                            .foregroundColor(selectedType == type ? .white : Theme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                selectedType == type
                                    ? type.accentColor
                                    : Color.white.opacity(0.06)
                            )
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(selectedType == type ? type.accentColor : Color.white.opacity(0.08), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            
            // Детали выбранного напитка: Индекс гидратации и калории
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "drop.fill")
                        .font(.caption2)
                        .foregroundColor(.cyan)
                    Text("Гидратация: \(Int(selectedType.hydrationFactor * 100))%")
                        .font(.caption)
                        .bold()
                        .foregroundColor(Theme.textPrimary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.cyan.opacity(0.1))
                .cornerRadius(10)
                
                if selectedType.defaultCaloriesPer100ml > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                            .foregroundColor(Theme.pulseColor)
                        Text("~\(Int(selectedType.defaultCaloriesPer100ml)) ккал / 100 мл")
                            .font(.caption)
                            .bold()
                            .foregroundColor(Theme.textPrimary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.pulseColor.opacity(0.1))
                    .cornerRadius(10)
                }
                
                Spacer()
            }
            
            // Кнопки быстрых порций для выбранного напитка
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    ForEach(selectedType.quickPortions.prefix(4), id: \.self) { amount in
                        Button(action: {
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                            onSelectPortion(selectedType, amount)
                        }) {
                            VStack(spacing: 4) {
                                HStack(spacing: 2) {
                                    Text(selectedType.emoji)
                                        .font(.caption2)
                                    Text("+\(Int(amount)) мл")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(Theme.textPrimary)
                                
                                if selectedType.defaultCaloriesPer100ml > 0 {
                                    let cals = (amount / 100.0) * selectedType.defaultCaloriesPer100ml
                                    Text("+\(Int(cals)) ккал")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(Theme.pulseColor)
                                } else {
                                    Text("0 ккал")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(Theme.textSecondary)
                                }
                            }
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(selectedType.accentColor.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                }
                
                // Кнопка своего объема
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    onOpenCustomSheet()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "pencil.line")
                        Text("Ввести другой объем / калории")
                    }
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [selectedType.accentColor, selectedType.accentColor.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(14)
                    .shadow(color: selectedType.accentColor.opacity(0.3), radius: 6)
                }
            }
        }
        .premiumCard()
    }
}

// MARK: - Журнал выпитых напитков за сегодня
struct TodayLoggedBeveragesDiaryView: View {
    let beverages: [LoggedBeverageRecord]
    let waterConsumed: Double
    let onDelete: (UUID) -> Void
    let onReset: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "drop.triangle.fill")
                        .foregroundColor(Color(red: 0/255, green: 145/255, blue: 255/255))
                    Text("Выпито сегодня")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                }
                Spacer()
                
                if waterConsumed > 0 || !beverages.isEmpty {
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .heavy)
                        impact.impactOccurred()
                        onReset()
                    }) {
                        Text("Сбросить")
                            .font(.caption)
                            .bold()
                            .foregroundColor(Theme.pulseColor)
                    }
                }
            }
            
            if beverages.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "drop.circle")
                        .font(.system(size: 36))
                        .foregroundColor(Theme.textSecondary.opacity(0.35))
                    Text("За сегодня еще нет записей о напитках")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                    Text("Выберите воду, кофе, чай или колу выше для точного учета")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.02))
                .cornerRadius(14)
            } else {
                VStack(spacing: 8) {
                    ForEach(beverages.reversed()) { item in
                        HStack(spacing: 12) {
                            Text(item.beverageType.emoji)
                                .font(.title3)
                                .frame(width: 34, height: 34)
                                .background(item.beverageType.accentColor.opacity(0.15))
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.displayName)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Theme.textPrimary)
                                
                                HStack(spacing: 6) {
                                    Text("\(Int(item.volumeMl)) мл")
                                        .font(.caption2)
                                        .bold()
                                        .foregroundColor(Theme.textSecondary)
                                    
                                    Text("• +\(Int(item.effectiveHydrationMl)) мл воды")
                                        .font(.caption2)
                                        .foregroundColor(.cyan)
                                    
                                    if item.calories > 0 {
                                        Text("• +\(Int(item.calories)) ккал")
                                            .font(.caption2)
                                            .bold()
                                            .foregroundColor(Theme.pulseColor)
                                    }
                                    
                                    if item.caffeineMg > 0 {
                                        Text("• ⚡️\(Int(item.caffeineMg)) мг")
                                            .font(.caption2)
                                            .bold()
                                            .foregroundColor(Color(red: 255/255, green: 185/255, blue: 70/255))
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            let formatter = DateFormatter()
                            let _ = formatter.dateFormat = "HH:mm"
                            Text(formatter.string(from: item.date))
                                .font(.caption2)
                                .foregroundColor(Theme.textSecondary.opacity(0.7))
                            
                            Button(action: {
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                                onDelete(item.id)
                            }) {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary.opacity(0.5))
                                    .padding(6)
                            }
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(12)
                    }
                }
            }
        }
        .premiumCard()
    }
}

// MARK: - Модальное окно кастомного напитка и объема
struct CustomBeverageSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let initialType: BeverageType
    let onSave: (BeverageType, Double, Double?, String?) -> Void
    
    @State private var beverageType: BeverageType
    @State private var volumeMl: Double = 250.0
    @State private var customName: String = ""
    @State private var customCalories: Double = 0.0
    @State private var useCustomCalories: Bool = false
    
    init(initialType: BeverageType = .coffee, onSave: @escaping (BeverageType, Double, Double?, String?) -> Void) {
        self.initialType = initialType
        self.onSave = onSave
        _beverageType = State(initialValue: initialType)
        _customCalories = State(initialValue: (250.0 / 100.0) * initialType.defaultCaloriesPer100ml)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Выбор типа напитка
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Выберите тип напитка")
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(Theme.textPrimary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(BeverageType.allCases) { type in
                                        Button(action: {
                                            beverageType = type
                                            if !useCustomCalories {
                                                customCalories = (volumeMl / 100.0) * type.defaultCaloriesPer100ml
                                            }
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        }) {
                                            HStack(spacing: 6) {
                                                Text(type.emoji)
                                                Text(type.title)
                                                    .font(.caption)
                                                    .bold()
                                            }
                                            .foregroundColor(beverageType == type ? .white : Theme.textPrimary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(beverageType == type ? type.accentColor : Color.white.opacity(0.06))
                                            .cornerRadius(18)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 18)
                                                    .stroke(beverageType == type ? type.accentColor : Color.white.opacity(0.1), lineWidth: 1)
                                            )
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Кастомное название
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Уточнение названия (необязательно)")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                            TextField("Например: Латте с карамелью / Свежевыжатый сок", text: $customName)
                                .font(.subheadline)
                                .foregroundColor(Theme.textPrimary)
                                .padding()
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(14)
                        }
                        
                        // Степперы объема и калорий
                        VStack(spacing: 16) {
                            HStack {
                                Text("Объем порции:")
                                    .foregroundColor(Theme.textSecondary)
                                Spacer()
                                Stepper(value: $volumeMl, in: 25...2000, step: 25) {
                                    Text("\(Int(volumeMl)) мл")
                                        .bold()
                                        .foregroundColor(beverageType.accentColor)
                                }
                                .onChange(of: volumeMl) { _, newVol in
                                    if !useCustomCalories {
                                        customCalories = (newVol / 100.0) * beverageType.defaultCaloriesPer100ml
                                    }
                                }
                            }
                            
                            HStack {
                                Text("Эффективная гидратация:")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                                Spacer()
                                Text("~\(Int(volumeMl * beverageType.hydrationFactor)) мл чистой воды")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.cyan)
                            }
                            
                            Divider().background(Color.white.opacity(0.06))
                            
                            Toggle(isOn: $useCustomCalories) {
                                Text("Указать свои калории")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textPrimary)
                            }
                            .tint(beverageType.accentColor)
                            
                            if useCustomCalories {
                                HStack {
                                    Text("Калорийность:")
                                        .foregroundColor(Theme.textSecondary)
                                    Spacer()
                                    Stepper(value: $customCalories, in: 0...1500, step: 10) {
                                        Text("\(Int(customCalories)) ккал")
                                            .bold()
                                            .foregroundColor(Theme.pulseColor)
                                    }
                                }
                            } else if beverageType.defaultCaloriesPer100ml > 0 {
                                HStack {
                                    Text("Примерная калорийность:")
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                    Spacer()
                                    Text("~\(Int((volumeMl / 100.0) * beverageType.defaultCaloriesPer100ml)) ккал")
                                        .font(.caption)
                                        .bold()
                                        .foregroundColor(Theme.pulseColor)
                                }
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(16)
                        
                        Button(action: {
                            let name = customName.trimmingCharacters(in: .whitespacesAndNewlines)
                            let cals = useCustomCalories ? customCalories : ((volumeMl / 100.0) * beverageType.defaultCaloriesPer100ml)
                            onSave(beverageType, volumeMl, cals, name.isEmpty ? nil : name)
                            dismiss()
                            let impact = UINotificationFeedbackGenerator()
                            impact.notificationOccurred(.success)
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Добавить в журнал")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(beverageType.accentColor)
                            .cornerRadius(16)
                            .shadow(color: beverageType.accentColor.opacity(0.35), radius: 8)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Добавить напиток")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}


