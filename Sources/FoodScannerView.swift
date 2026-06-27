import SwiftUI
import PhotosUI
import GoogleGenerativeAI

struct FoodScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var health: HealthKitManager
    
    @AppStorage("api_key_gemini") private var apiKeyGemini: String = ""
    @AppStorage("api_key_openai") private var apiKeyOpenAI: String = ""
    @AppStorage("api_key_claude") private var apiKeyClaude: String = ""
    
    private var hasAnyApiKey: Bool {
        !apiKeyGemini.isEmpty || !apiKeyOpenAI.isEmpty || !apiKeyClaude.isEmpty
    }
    
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    
    @State private var isScanning = false
    @State private var scanError: String? = nil
    
    // Результаты распознавания
    @State private var scanResult: FoodScanResult? = nil
    @State private var adjustedWeight: Double = 100.0
    
    // Камера через UIKit
    @State private var showingCamera = false
    
    // Состояние ИИ-анализа питания
    @State private var isAnalyzingNutrition = false
    @State private var nutritionAnalysisResult: String? = nil
    @State private var nutritionAnalysisError: String? = nil
    
    // Вычисляемые пропорционально БЖУ и Калории
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
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                // Заголовок
                HStack {
                    Text("Питание")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 12)
                
                // 1. Поле ввода API ключа, если ни один не задан
                if !hasAnyApiKey {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Требуется настроить API-ключ")
                            .font(.headline)
                            .foregroundColor(Theme.textPrimary)
                        Text("Для работы ИИ-сканера перейдите на вкладку 'Настройки' и укажите хотя бы один API-ключ (Gemini, ChatGPT или Claude).")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                    .premiumCard()
                    .padding(.horizontal)
                }
                
                if let img = selectedImage {
                    // Превью выбранного изображения и результаты сканирования
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
                        
                        // Процесс сканирования
                        if isScanning {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .tint(Theme.textPrimary)
                                Text("Диетолог анализирует блюдо...")
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
                        
                        // Вывод результатов и подтверждение
                        if let result = scanResult {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Результаты сканирования")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(Theme.textSecondary)
                                
                                Text(result.dish)
                                    .font(.title3)
                                    .bold()
                                    .foregroundColor(Theme.textPrimary)
                                
                                Divider()
                                
                                // Вес с шагом
                                HStack {
                                    Text("Вес порции:")
                                        .foregroundColor(Theme.textSecondary)
                                        .bold()
                                    Spacer()
                                    Stepper(value: $adjustedWeight, in: 10...2000, step: 10) {
                                        Text("\(Int(adjustedWeight)) г")
                                            .font(.headline)
                                            .foregroundColor(Theme.textPrimary)
                                    }
                                }
                                
                                Divider()
                                
                                // Калории и БЖУ
                                HStack(spacing: 12) {
                                    MacroItem(value: "\(Int(scaledCalories))", label: "ккал", color: Theme.pulseColor)
                                    MacroItem(value: "\(Int(scaledProtein))г", label: "белки", color: .green)
                                    MacroItem(value: "\(Int(scaledFat))г", label: "жиры", color: .orange)
                                    MacroItem(value: "\(Int(scaledCarbs))г", label: "углеводы", color: .blue)
                                }
                                
                                // Кнопка добавления в HealthKit
                                Button(action: {
                                    saveToHealthKit()
                                }) {
                                    Text("Добавить прием пищи")
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
                                    Text("Отмена")
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
                    // Карточка ИИ-анализа питания (СВЕРХУ!)
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .foregroundColor(.yellow)
                                .font(.title3)
                            Text("Советы по питанию от ИИ")
                                .font(.headline)
                                .foregroundColor(Theme.textPrimary)
                            Spacer()
                        }
                        
                        if !hasAnyApiKey {
                            Text("Укажите хотя бы один API-ключ в настройках, чтобы активировать советы ИИ по питанию.")
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
                                Text("ИИ проанализирует вашу калорийность и рацион за последние дни и даст полезные рекомендации по диете.")
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
                                    Text(isAnalyzingNutrition ? "Анализирую..." : "Анализировать рацион")
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
                    
                    // Кнопки выбора/съемки (под советами)
                    HStack(spacing: 16) {
                        Button(action: {
                            showingCamera = true
                        }) {
                            HStack {
                                Image(systemName: "camera.fill")
                                Text("Камера")
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
                                Text("Галерея")
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
        .background(Theme.background.ignoresSafeArea())
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
    }
    
    private func runFoodScan(image: UIImage) {
        isScanning = true
        scanError = nil
        scanResult = nil
        
        Task {
            if !hasAnyApiKey {
                // Если API ключ не задан, симулируем сканирование и возвращаем яблоко
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await MainActor.run {
                    self.scanResult = FoodScanResult(
                        dish: "Зеленое яблоко 🍏 (Демо)",
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
}

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
