import SwiftUI
import PhotosUI

struct FoodScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var health: HealthKitManager
    
    @AppStorage("api_key_gemini") private var apiKeyGemini: String = ""
    
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    
    @State private var isScanning = false
    @State private var scanError: String? = nil
    
    // Результаты распознавания
    @State private var scanResult: FoodScanResult? = nil
    @State private var adjustedWeight: Double = 100.0
    
    // Камера через UIKit
    @State private var showingCamera = false
    
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
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Поле ввода API ключа, если он не задан
                        if apiKeyGemini.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Требуется API-ключ Gemini")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("Для работы ИИ-сканера введите свой API-ключ Google AI Studio.")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                                
                                SecureField("Ключ API...", text: $apiKeyGemini)
                                    .textFieldStyle(.plain)
                                    .padding(12)
                                    .background(Color.black.opacity(0.3))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                    )
                                    .foregroundColor(.white)
                                    .textInputAutocapitalization(.never)
                                    .disableAutocorrection(true)
                            }
                            .padding()
                            .premiumCard()
                            .padding(.horizontal)
                        }
                        
                        // Превью выбранного изображения
                        if let img = selectedImage {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 250)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                )
                                .padding(.horizontal)
                        } else {
                            // Заглушка выбора фото
                            VStack(spacing: 16) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 48))
                                    .foregroundColor(Theme.textSecondary)
                                Text("Сфотографируйте еду или выберите снимок из галереи")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                            .frame(height: 250)
                            .frame(maxWidth: .infinity)
                            .premiumCard()
                            .padding(.horizontal)
                        }
                        
                        // Кнопки выбора/съемки
                        HStack(spacing: 16) {
                            Button(action: {
                                showingCamera = true
                            }) {
                                HStack {
                                    Image(systemName: "camera.fill")
                                    Text("Камера")
                                }
                                .foregroundColor(.black)
                                .bold()
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.white)
                                .cornerRadius(12)
                            }
                            
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                HStack {
                                    Image(systemName: "photo.fill")
                                    Text("Галерея")
                                }
                                .foregroundColor(.white)
                                .bold()
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal)
                        
                        // Процесс сканирования
                        if isScanning {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .tint(.white)
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
                                Text("Распознано:")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                                
                                Text(result.dish)
                                    .font(.title3)
                                    .bold()
                                    .foregroundColor(.white)
                                
                                Divider().background(Color.white.opacity(0.1))
                                
                                // Вес с шагом
                                HStack {
                                    Text("Вес порции:")
                                        .foregroundColor(Theme.textSecondary)
                                    Spacer()
                                    Stepper(value: $adjustedWeight, in: 10...2000, step: 10) {
                                        Text("\(Int(adjustedWeight)) г")
                                            .foregroundColor(.white)
                                            .bold()
                                    }
                                }
                                
                                Divider().background(Color.white.opacity(0.1))
                                
                                // Калории и БЖУ
                                HStack(spacing: 16) {
                                    MacroItem(value: "\(Int(scaledCalories))", label: "ккал", color: Theme.pulseColor)
                                    MacroItem(value: "\(Int(scaledProtein))г", label: "белки", color: .green)
                                    MacroItem(value: "\(Int(scaledFat))г", label: "жиры", color: .yellow)
                                    MacroItem(value: "\(Int(scaledCarbs))г", label: "углеводы", color: .orange)
                                }
                                
                                // Кнопка добавления в HealthKit
                                Button(action: {
                                    saveToHealthKit()
                                }) {
                                    Text("Записать в Apple Health")
                                        .font(.headline)
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.white)
                                        .cornerRadius(12)
                                        .shadow(color: Color.white.opacity(0.2), radius: 8)
                                }
                                .padding(.top, 8)
                            }
                            .premiumCard()
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .navigationTitle("ИИ Сканер Еды")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .sheet(isPresented: $showingCamera) {
                CameraPicker(selectedImage: $selectedImage)
            }
            .onChange(of: selectedPhotoItem) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        selectedImage = uiImage
                        runFoodScan(image: uiImage)
                    }
                }
            }
        }
    }
    
    private func runFoodScan(image: UIImage) {
        isScanning = true
        scanError = nil
        scanResult = nil
        
        Task {
            do {
                let result = try await GeminiScanService.shared.scanFood(image: image, apiKey: apiKeyGemini)
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
    
    private func saveToHealthKit() {
        // Пишем калории
        health.addDietaryEnergy(calories: scaledCalories)
        dismiss()
    }
}

struct MacroItem: View {
    var value: String
    var label: String
    var color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
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
