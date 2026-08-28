import SwiftUI
import AVFoundation
import PhotosUI

public enum BarcodeScannerMode: String, CaseIterable, Identifiable {
    case plateAI = "Блюдо & LiDAR 🍽️"
    case barcode = "Штрих-код 🏷️"
    case labelAI = "Этикетка КБЖУ 📋"
    
    public var id: String { rawValue }
}

public struct BarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let onProductScanned: (BarcodeProduct) -> Void
    
    @StateObject private var lidarService = LiDARPlateScannerService.shared
    @ObservedObject private var coachManager = AICoachManager.shared
    
    @State private var mode: BarcodeScannerMode = .plateAI
    @State private var isScanning = true
    @State private var isLoading = false
    @State private var loadingStatusText: String = "Анализ блюда через ИИ..."
    @State private var errorMessage: String? = nil
    @State private var notFoundBarcode: String? = nil
    
    @State private var scannedProduct: BarcodeProduct? = nil
    @State private var plateScanResult: FoodScanResult? = nil
    @State private var isTorchOn = false
    @State private var laserOffset: CGFloat = -120
    @State private var portionWeight: Double = 350.0
    @State private var userPromptHint: String = ""
    
    // Ручной ввод и выбор фото
    @State private var showingManualEntrySheet = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var capturePhotoTrigger: Int = 0
    
    // Синтезатор речи тренера
    @State private var speechSynthesizer = AVSpeechSynthesizer()
    @State private var isSpeakingCoachAdvice: Bool = false
    
    public init(initialMode: BarcodeScannerMode = .plateAI, onProductScanned: @escaping (BarcodeProduct) -> Void) {
        self._mode = State(initialValue: initialMode)
        self._isScanning = State(initialValue: initialMode == .barcode)
        self.onProductScanned = onProductScanned
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                // Камера видоискателя с поддержкой сканирования штрих-кода и захвата фото
                BarcodeCameraPreview(
                    isTorchOn: isTorchOn,
                    captureTrigger: capturePhotoTrigger,
                    onBarcodeDetected: { barcode in
                        if mode == .barcode {
                            handleBarcodeDetected(barcode)
                        }
                    },
                    onPhotoCaptured: { capturedImage in
                        if let img = capturedImage {
                            if mode == .plateAI {
                                processPlateImage(img)
                            } else if mode == .labelAI {
                                processLabelImage(img, linkedBarcode: notFoundBarcode)
                            }
                        }
                    }
                )
                .ignoresSafeArea()
                
                // Затемнение вокруг видоискателя
                Color.black.opacity(0.38)
                    .mask(
                        Rectangle()
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .frame(
                                        width: mode == .barcode ? 290 : (mode == .plateAI ? 330 : 310),
                                        height: mode == .barcode ? 200 : (mode == .plateAI ? 330 : 280)
                                    )
                                    .blendMode(.destinationOut)
                            )
                    )
                    .compositingGroup()
                    .ignoresSafeArea()
                
                // Рамка видоискателя и элементы управления
                VStack(spacing: 0) {
                    // Переключатель 3 режимов
                    modePicker
                        .padding(.top, 10)
                    
                    // LiDAR 3D Live HUD статус
                    if mode == .plateAI && scannedProduct == nil && !isLoading {
                        lidarStatusHUD
                            .padding(.top, 10)
                    }
                    
                    Spacer()
                    
                    // Центральная рамка с подсветкой
                    viewfinderFrame
                    
                    Spacer()
                    
                    // Нижняя панель действий (карточка продукта / ошибка / кнопки AI / затвор)
                    bottomContentArea
                }
            }
            .navigationTitle(LocalizationManager.tr("barcode_scanner_title", lang: UserDefaults.standard.string(forKey: "app_language") ?? "ru"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        isTorchOn.toggle()
                        HapticManager.shared.impact(.light)
                    }) {
                        Image(systemName: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                            .foregroundColor(isTorchOn ? .yellow : .white)
                            .font(.system(size: 17, weight: .bold))
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .foregroundColor(.white)
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        lidarService.stopLiveDepthEstimation()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.6), for: .navigationBar)
            .onAppear {
                if mode == .plateAI {
                    lidarService.startLiveDepthEstimation()
                }
            }
            .onDisappear {
                lidarService.stopLiveDepthEstimation()
                if speechSynthesizer.isSpeaking {
                    speechSynthesizer.stopSpeaking(at: .immediate)
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                handleGalleryPhotoSelected(newItem)
            }
            .sheet(isPresented: $showingManualEntrySheet) {
                BarcodeManualProductSheet(initialBarcode: notFoundBarcode ?? "") { newProduct in
                    BarcodeScannerService.shared.saveCustomProduct(newProduct)
                    self.scannedProduct = newProduct
                    self.portionWeight = newProduct.servingWeightGrams
                    self.errorMessage = nil
                    self.notFoundBarcode = nil
                    HapticManager.shared.notification(.success)
                }
            }
        }
    }
    
    // MARK: - LiDAR 3D Live HUD статус
    private var lidarStatusHUD: some View {
        HStack(spacing: 8) {
            Image(systemName: lidarService.isLiDARAvailable ? "sensor.fill" : "point.3.filled.connected.trianglepath.dotted")
                .foregroundColor(lidarService.isLiDARAvailable ? Color(red: 0/255, green: 229/255, blue: 255/255) : .green)
                .font(.system(size: 13, weight: .bold))
            
            Text(lidarService.currentEstimate.statusMessage)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            
            if lidarService.isLiDARAvailable {
                Text("LiDAR Pro")
                    .font(.system(size: 9, weight: .heavy))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color(red: 0/255, green: 229/255, blue: 255/255).opacity(0.3))
                    .foregroundColor(Color(red: 0/255, green: 229/255, blue: 255/255))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.75))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke((lidarService.isLiDARAvailable ? Color(red: 0/255, green: 229/255, blue: 255/255) : Color.green).opacity(0.4), lineWidth: 1)
        )
    }
    
    // MARK: - Переключатель режимов
    
    private var modePicker: some View {
        HStack(spacing: 4) {
            ForEach(BarcodeScannerMode.allCases) { m in
                let isSelected = mode == m
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        mode = m
                        errorMessage = nil
                        notFoundBarcode = nil
                        scannedProduct = nil
                        plateScanResult = nil
                        isScanning = (m == .barcode)
                        
                        if m == .plateAI {
                            lidarService.startLiveDepthEstimation()
                        } else {
                            lidarService.stopLiveDepthEstimation()
                        }
                    }
                    HapticManager.shared.selection()
                }) {
                    Text(m.rawValue)
                        .font(.system(size: 12, weight: isSelected ? .bold : .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            isSelected
                                ? (m == .plateAI ? Color(red: 16/255, green: 185/255, blue: 129/255) : (m == .barcode ? Color(red: 0/255, green: 229/255, blue: 255/255) : Theme.aiAccent))
                                : Color.white.opacity(0.08)
                        )
                        .foregroundColor(isSelected ? (m == .barcode ? .black : .white) : .white.opacity(0.85))
                        .cornerRadius(16)
                }
            }
        }
        .padding(4)
        .background(Color.black.opacity(0.7))
        .cornerRadius(20)
    }
    
    // MARK: - Центральная рамка видоискателя
    
    private var viewfinderFrame: some View {
        VStack(spacing: 12) {
            ZStack {
                let frameWidth: CGFloat = mode == .barcode ? 290 : (mode == .plateAI ? 330 : 310)
                let frameHeight: CGFloat = mode == .barcode ? 200 : (mode == .plateAI ? 330 : 280)
                let borderColor: Color = mode == .plateAI ? Color(red: 16/255, green: 185/255, blue: 129/255) : (mode == .barcode ? Color(red: 0/255, green: 229/255, blue: 255/255) : Theme.aiAccent)
                
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(colors: [borderColor, borderColor.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 3
                    )
                    .frame(width: frameWidth, height: frameHeight)
                    .shadow(color: borderColor.opacity(0.6), radius: 12)
                
                // Лазерная линия для штрих-кода
                if mode == .barcode && isScanning && !isLoading && scannedProduct == nil {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.clear, Color(red: 0/255, green: 229/255, blue: 255/255), Color.clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 270, height: 3)
                        .offset(y: laserOffset)
                        .onAppear {
                            withAnimation(
                                .easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true)
                            ) {
                                laserOffset = 90
                            }
                        }
                }
                
                // Пространственный фокус тарелки (Plate AI HUD)
                if mode == .plateAI && !isLoading && scannedProduct == nil {
                    VStack {
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: "fork.knife.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                            Text("Поместите тарелку с едой в центр кадра")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white.opacity(0.95))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.75))
                        .cornerRadius(14)
                        .padding(.bottom, 12)
                    }
                }
                
                // Индикатор съемки этикетки
                if mode == .labelAI && !isLoading && scannedProduct == nil {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "viewfinder")
                                .font(.system(size: 20))
                                .foregroundColor(Theme.aiAccent)
                            Text("Поместите таблицу КБЖУ в рамку")
                                .font(.caption2)
                                .bold()
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                        .padding(.bottom, 12)
                    }
                }
                
                // Лоадер поиска / ИИ-распознавания
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.4)
                        Text(loadingStatusText)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding(20)
                    .background(Color.black.opacity(0.85))
                    .cornerRadius(20)
                    .padding(.horizontal, 20)
                }
            }
            
            Text(mode == .plateAI ? "LiDAR 3D замер объема и расчет КБЖУ в реальном времени" : (mode == .barcode ? "Наведите камеру на штрих-код продукта" : "Сфотографируйте этикетку или таблицу КБЖУ"))
                .font(.caption)
                .bold()
                .foregroundColor(.white.opacity(0.85))
        }
    }
    
    // MARK: - Нижняя панель контента
    
    @ViewBuilder
    private var bottomContentArea: some View {
        if let product = scannedProduct {
            productFoundCard(product: product)
        } else if let notFound = notFoundBarcode, errorMessage != nil {
            barcodeNotFoundCard(barcode: notFound)
        } else if let error = errorMessage {
            genericErrorCard(error: error)
        } else if mode == .plateAI || mode == .labelAI {
            VStack(spacing: 12) {
                // Поле текстовой подсказки для блюда
                if mode == .plateAI {
                    HStack {
                        Image(systemName: "text.bubble.fill")
                            .foregroundColor(.white.opacity(0.6))
                        TextField("Уточнение (например: без соуса, 2 яйца)", text: $userPromptHint)
                            .font(.caption)
                            .foregroundColor(.white)
                        if !userPromptHint.isEmpty {
                            Button(action: { userPromptHint = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(12)
                    .padding(.horizontal, 24)
                }
                
                // Кнопка спуска затвора
                shutterButton
                    .padding(.bottom, 20)
            }
        } else {
            // Кнопка ручного ввода в стандартном режиме
            Button(action: {
                showingManualEntrySheet = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.pencil")
                    Text("Ввести продукт вручную")
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.75))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.12))
                .cornerRadius(14)
            }
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Карточка найденного продукта / Блюда
    
    private func productFoundCard(product: BarcodeProduct) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Text(product.emoji)
                    .font(.system(size: 38))
                    .frame(width: 50, height: 50)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(product.name)
                            .font(.headline)
                            .bold()
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        if product.isUserCustom {
                            Text(mode == .plateAI ? "✨ LiDAR AI" : "✨ Моя база")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.aiAccent.opacity(0.3))
                                .foregroundColor(Theme.aiAccent)
                                .cornerRadius(6)
                        }
                    }
                    
                    if !product.brand.isEmpty {
                        Text(product.brand)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    HStack(spacing: 6) {
                        let totalCal = Int(product.caloriesPer100g * portionWeight / 100.0)
                        Text("\(totalCal) ккал")
                            .font(.caption.bold())
                            .foregroundColor(Theme.pulseColor)
                        
                        let p = Int(product.proteinPer100g * portionWeight / 100.0)
                        let f = Int(product.fatPer100g * portionWeight / 100.0)
                        let c = Int(product.carbsPer100g * portionWeight / 100.0)
                        Text("• Б: \(p)г Ж: \(f)г У: \(c)г")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                        
                        if let nutri = product.nutriScore {
                            Text(nutri)
                                .font(.caption2.bold())
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(nutriScoreColor(nutri))
                                .cornerRadius(5)
                                .foregroundColor(.white)
                        }
                    }
                }
                Spacer()
            }
            
            // Если есть детализация ингредиентов с блюда
            if let plate = plateScanResult, !plate.ingredients.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Состав порции:")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.7))
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(plate.ingredients) { ing in
                                HStack(spacing: 4) {
                                    Text(ing.emoji)
                                    Text("\(ing.name): \(Int(ing.calories)) ккал")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
            }
            
            // Совет тренера + кнопка озвучки
            if let plate = plateScanResult, let advice = plate.advice, !advice.isEmpty {
                HStack(spacing: 8) {
                    AITrainerAvatarView(coachState: .idle, size: 28)
                    
                    Text(advice)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(2)
                    
                    Spacer()
                    
                    Button(action: {
                        speakAdvice(advice)
                    }) {
                        Image(systemName: isSpeakingCoachAdvice ? "speaker.wave.3.fill" : "speaker.wave.2")
                            .font(.system(size: 15))
                            .foregroundColor(coachManager.currentCoach.accentColor)
                            .padding(8)
                            .background(coachManager.currentCoach.accentColor.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
                .padding(8)
                .background(Color.white.opacity(0.06))
                .cornerRadius(12)
            }
            
            // Степпер веса порции
            HStack {
                Text("Вес порции:")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                Stepper(value: $portionWeight, in: 20...1500, step: 25) {
                    Text("\(Int(portionWeight)) г")
                        .font(.headline.bold())
                        .foregroundColor(.white)
                }
            }
            
            // Кнопки действий
            HStack(spacing: 10) {
                Button(action: {
                    withAnimation {
                        scannedProduct = nil
                        plateScanResult = nil
                        isScanning = (mode == .barcode)
                        laserOffset = -90
                        errorMessage = nil
                        notFoundBarcode = nil
                        if speechSynthesizer.isSpeaking {
                            speechSynthesizer.stopSpeaking(at: .immediate)
                        }
                    }
                }) {
                    Text("Еще скан")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(14)
                }
                
                Button(action: {
                    let finalProduct = BarcodeProduct(
                        barcode: product.barcode,
                        name: product.name,
                        brand: product.brand,
                        servingSize: "\(Int(portionWeight)) г",
                        servingWeightGrams: portionWeight,
                        caloriesPer100g: product.caloriesPer100g,
                        proteinPer100g: product.proteinPer100g,
                        fatPer100g: product.fatPer100g,
                        carbsPer100g: product.carbsPer100g,
                        sugarPer100g: product.sugarPer100g,
                        fiberPer100g: product.fiberPer100g,
                        sodiumPer100g: product.sodiumPer100g,
                        nutriScore: product.nutriScore,
                        novaGroup: product.novaGroup,
                        imageUrl: product.imageUrl,
                        emoji: product.emoji,
                        isUserCustom: product.isUserCustom
                    )
                    onProductScanned(finalProduct)
                    lidarService.stopLiveDepthEstimation()
                    dismiss()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("В дневник (+XP)")
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(Color(red: 16/255, green: 185/255, blue: 129/255))
                    .cornerRadius(14)
                    .shadow(color: Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.4), radius: 8)
                }
            }
        }
        .padding(16)
        .background(Color(red: 26/255, green: 29/255, blue: 38/255))
        .cornerRadius(24)
        .padding(.horizontal)
        .padding(.bottom, 20)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    // MARK: - Карточка ненайденного штрих-кода
    
    private func barcodeNotFoundCard(barcode: String) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 20))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Штрих-код \(barcode) не найден")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Text("Сфотографируйте этикетку КБЖУ или введите данные — они сохранятся в вашу базу.")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.75))
                }
                Spacer()
            }
            
            HStack(spacing: 10) {
                Button(action: {
                    withAnimation {
                        mode = .labelAI
                        errorMessage = nil
                    }
                    HapticManager.shared.impact(.medium)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.viewfinder")
                        Text("Снять этикетку (ИИ)")
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [Theme.aiAccent, Color(red: 168/255, green: 85/255, blue: 247/255)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(14)
                }
                
                Button(action: {
                    showingManualEntrySheet = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                        Text("Вручную")
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(Color.white.opacity(0.18))
                    .cornerRadius(14)
                }
            }
            
            Button(action: {
                withAnimation {
                    errorMessage = nil
                    notFoundBarcode = nil
                    isScanning = true
                    laserOffset = -90
                }
            }) {
                Text("Попробовать другой штрих-код")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .underline()
            }
            .padding(.top, 2)
        }
        .padding(16)
        .background(Color(red: 28/255, green: 30/255, blue: 40/255))
        .cornerRadius(22)
        .padding(.horizontal)
        .padding(.bottom, 20)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    // MARK: - Общая карточка ошибки
    
    private func genericErrorCard(error: String) -> some View {
        VStack(spacing: 8) {
            Text(error)
                .font(.caption)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
            
            Button(action: {
                errorMessage = nil
                isScanning = (mode == .barcode)
                laserOffset = -90
            }) {
                Text("Попробовать снова")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(10)
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.8))
        .cornerRadius(14)
        .padding(.bottom, 20)
    }
    
    // MARK: - Кнопка спуска затвора
    
    private var shutterButton: some View {
        Button(action: {
            capturePhotoTrigger += 1
            HapticManager.shared.impact(.heavy)
        }) {
            ZStack {
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 76, height: 76)
                
                let gradientColors: [Color] = mode == .plateAI
                    ? [Color(red: 16/255, green: 185/255, blue: 129/255), Color(red: 5/255, green: 150/255, blue: 105/255)]
                    : [Theme.aiAccent, Color(red: 168/255, green: 85/255, blue: 247/255)]
                
                Circle()
                    .fill(LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 60, height: 60)
                
                Image(systemName: mode == .plateAI ? "fork.knife" : "sparkles")
                    .foregroundColor(.white)
                    .font(.system(size: 24, weight: .bold))
            }
            .shadow(color: (mode == .plateAI ? Color.green : Theme.aiAccent).opacity(0.5), radius: 12)
        }
    }
    
    // MARK: - Обработка событий сканера
    
    private func handleBarcodeDetected(_ barcode: String) {
        guard isScanning, !isLoading else { return }
        isScanning = false
        isLoading = true
        loadingStatusText = LocalizationManager.tr("barcode_searching", lang: UserDefaults.standard.string(forKey: "app_language") ?? "ru")
        errorMessage = nil
        notFoundBarcode = nil
        
        HapticManager.shared.impact(.heavy)
        
        Task {
            do {
                let product = try await BarcodeScannerService.shared.fetchProduct(barcode: barcode)
                await MainActor.run {
                    self.scannedProduct = product
                    self.portionWeight = product.servingWeightGrams
                    self.isLoading = false
                    HapticManager.shared.notification(.success)
                }
            } catch {
                await MainActor.run {
                    self.notFoundBarcode = barcode
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    HapticManager.shared.notification(.error)
                }
            }
        }
    }
    
    private func processPlateImage(_ image: UIImage) {
        isLoading = true
        loadingStatusText = "3D LiDAR оценка объема и сегментация блюда..."
        errorMessage = nil
        
        Task {
            do {
                let lang = UserDefaults.standard.string(forKey: "app_language") ?? "ru"
                let coach = coachManager.currentCoach
                let lidarEstimate = lidarService.currentEstimate
                
                let foodResult = try await GeminiScanService.shared.scanFood(
                    image: image,
                    language: lang,
                    userHint: userPromptHint,
                    lidarEstimate: lidarEstimate,
                    coach: coach
                )
                
                // Перевод FoodScanResult в формат BarcodeProduct для совместимости
                let totalWeight = foodResult.weight_grams > 0 ? foodResult.weight_grams : (lidarEstimate.estimatedWeightGrams > 0 ? lidarEstimate.estimatedWeightGrams : 350.0)
                let calsPer100g = totalWeight > 0 ? (foodResult.calories / totalWeight) * 100.0 : foodResult.calories
                let pPer100g = totalWeight > 0 ? (foodResult.protein / totalWeight) * 100.0 : foodResult.protein
                let fPer100g = totalWeight > 0 ? (foodResult.fat / totalWeight) * 100.0 : foodResult.fat
                let cPer100g = totalWeight > 0 ? (foodResult.carbs / totalWeight) * 100.0 : foodResult.carbs
                
                let product = BarcodeProduct(
                    barcode: "PLATE_\(UUID().uuidString.prefix(8))",
                    name: foodResult.dish,
                    brand: "LiDAR 3D Scan",
                    servingSize: "\(Int(totalWeight)) г",
                    servingWeightGrams: totalWeight,
                    caloriesPer100g: calsPer100g,
                    proteinPer100g: pPer100g,
                    fatPer100g: fPer100g,
                    carbsPer100g: cPer100g,
                    nutriScore: (foodResult.healthScore ?? 8) >= 8 ? "A" : ((foodResult.healthScore ?? 8) >= 6 ? "B" : "C"),
                    emoji: foodResult.ingredients.first?.emoji ?? "🍽️",
                    isUserCustom: true
                )
                
                await MainActor.run {
                    self.plateScanResult = foodResult
                    self.scannedProduct = product
                    self.portionWeight = totalWeight
                    self.isLoading = false
                    self.errorMessage = nil
                    HapticManager.shared.notification(.success)
                    
                    if let adv = foodResult.advice, !adv.isEmpty {
                        speakAdvice(adv)
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Не удалось распознать блюдо: \(error.localizedDescription)"
                    self.isLoading = false
                    HapticManager.shared.notification(.error)
                }
            }
        }
    }
    
    private func processLabelImage(_ image: UIImage, linkedBarcode: String?) {
        isLoading = true
        loadingStatusText = LocalizationManager.tr("barcode_ai_analyzing", lang: UserDefaults.standard.string(forKey: "app_language") ?? "ru")
        errorMessage = nil
        
        Task {
            do {
                let lang = UserDefaults.standard.string(forKey: "app_language") ?? "ru"
                var product = try await GeminiScanService.shared.scanNutritionLabel(image: image, barcode: linkedBarcode, language: lang)
                product.isUserCustom = true
                
                BarcodeScannerService.shared.saveCustomProduct(product)
                
                await MainActor.run {
                    self.scannedProduct = product
                    self.portionWeight = product.servingWeightGrams
                    self.isLoading = false
                    self.notFoundBarcode = nil
                    self.errorMessage = nil
                    HapticManager.shared.notification(.success)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    HapticManager.shared.notification(.error)
                }
            }
        }
    }
    
    private func handleGalleryPhotoSelected(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    if mode == .plateAI {
                        processPlateImage(image)
                    } else {
                        processLabelImage(image, linkedBarcode: notFoundBarcode)
                    }
                }
            }
        }
    }
    
    private func speakAdvice(_ text: String) {
        guard !text.isEmpty else { return }
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ru-RU")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.05
        isSpeakingCoachAdvice = true
        speechSynthesizer.speak(utterance)
    }
    
    private func nutriScoreColor(_ grade: String) -> Color {
        switch grade.uppercased() {
        case "A": return Color(red: 3/255, green: 129/255, blue: 66/255)
        case "B": return Color(red: 133/255, green: 187/255, blue: 46/255)
        case "C": return Color(red: 254/255, green: 203/255, blue: 3/255)
        case "D": return Color(red: 238/255, green: 129/255, blue: 34/255)
        case "E": return Color(red: 230/255, green: 62/255, blue: 17/255)
        default: return Color.gray
        }
    }
}

// MARK: - Лист ручного добавления продукта по штрих-коду

public struct BarcodeManualProductSheet: View {
    @Environment(\.dismiss) private var dismiss
    let initialBarcode: String
    let onSave: (BarcodeProduct) -> Void
    
    @State private var barcode: String = ""
    @State private var name: String = ""
    @State private var brand: String = ""
    @State private var portionGramsStr: String = "100"
    @State private var caloriesStr: String = ""
    @State private var proteinStr: String = ""
    @State private var fatStr: String = ""
    @State private var carbsStr: String = ""
    
    public init(initialBarcode: String, onSave: @escaping (BarcodeProduct) -> Void) {
        self.initialBarcode = initialBarcode
        self.onSave = onSave
        _barcode = State(initialValue: initialBarcode)
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Штрих-код и Название")) {
                    HStack {
                        Text("Штрих-код")
                            .foregroundColor(.secondary)
                        Spacer()
                        TextField("Например, 4607004891234", text: $barcode)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.asciiCapableNumberPad)
                    }
                    
                    HStack {
                        Text("Название")
                            .foregroundColor(.secondary)
                        Spacer()
                        TextField("Например, Творог 5%", text: $name)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Бренд / Производитель")
                            .foregroundColor(.secondary)
                        Spacer()
                        TextField("Необязательно", text: $brand)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section(header: Text("Пищевая ценность (на 100 г)"), footer: Text("Эти данные сохранятся в вашей локальной базе и будут мгновенно находиться при повторном сканировании.")) {
                    HStack {
                        Text("Калории (ккал)")
                        Spacer()
                        TextField("0", text: $caloriesStr)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                    
                    HStack {
                        Text("Белки (г)")
                        Spacer()
                        TextField("0", text: $proteinStr)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                    
                    HStack {
                        Text("Жиры (г)")
                        Spacer()
                        TextField("0", text: $fatStr)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                    
                    HStack {
                        Text("Углеводы (г)")
                        Spacer()
                        TextField("0", text: $carbsStr)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                }
            }
            .navigationTitle("Новый продукт")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        saveProduct()
                    }
                    .bold()
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    private func saveProduct() {
        let cal = Double(caloriesStr.replacingOccurrences(of: ",", with: ".")) ?? 0
        let p = Double(proteinStr.replacingOccurrences(of: ",", with: ".")) ?? 0
        let f = Double(fatStr.replacingOccurrences(of: ",", with: ".")) ?? 0
        let c = Double(carbsStr.replacingOccurrences(of: ",", with: ".")) ?? 0
        let weight = Double(portionGramsStr.replacingOccurrences(of: ",", with: ".")) ?? 100.0
        
        let product = BarcodeProduct(
            barcode: barcode.isEmpty ? "MANUAL_\(UUID().uuidString.prefix(8))" : barcode,
            name: name.trimmingCharacters(in: .whitespaces),
            brand: brand.trimmingCharacters(in: .whitespaces),
            servingSize: "\(Int(weight)) г",
            servingWeightGrams: weight,
            caloriesPer100g: cal,
            proteinPer100g: p,
            fatPer100g: f,
            carbsPer100g: c,
            isUserCustom: true
        )
        onSave(product)
        dismiss()
    }
}

// MARK: - Предпросмотр камеры AVCapture (Barcode & Photo Capture)

struct BarcodeCameraPreview: UIViewControllerRepresentable {
    var isTorchOn: Bool
    var captureTrigger: Int
    var onBarcodeDetected: (String) -> Void
    var onPhotoCaptured: (UIImage?) -> Void
    
    func makeUIViewController(context: Context) -> BarcodeCameraViewController {
        let controller = BarcodeCameraViewController()
        controller.onBarcodeDetected = onBarcodeDetected
        controller.onPhotoCaptured = onPhotoCaptured
        return controller
    }
    
    func updateUIViewController(_ uiViewController: BarcodeCameraViewController, context: Context) {
        uiViewController.setTorch(isTorchOn)
        if context.coordinator.lastTrigger != captureTrigger && captureTrigger > 0 {
            context.coordinator.lastTrigger = captureTrigger
            uiViewController.capturePhoto()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var lastTrigger: Int = 0
    }
}

final class BarcodeCameraViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate, AVCapturePhotoCaptureDelegate {
    var onBarcodeDetected: ((String) -> Void)?
    var onPhotoCaptured: ((UIImage?) -> Void)?
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var photoOutput: AVCapturePhotoOutput?
    private var isCapturing = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let session = captureSession, !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let session = captureSession, session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                session.stopRunning()
            }
        }
    }
    
    func setTorch(_ on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
    }
    
    func capturePhoto() {
        guard let pOutput = photoOutput, !isCapturing else { return }
        isCapturing = true
        let settings = AVCapturePhotoSettings()
        pOutput.capturePhoto(with: settings, delegate: self)
    }
    
    private func setupCamera() {
        let session = AVCaptureSession()
        session.beginConfiguration()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else {
            session.commitConfiguration()
            return
        }
        
        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        } else {
            session.commitConfiguration()
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [
                .ean8, .ean13, .pdf417, .qr, .code128, .code39, .upce
            ]
        }
        
        let pOutput = AVCapturePhotoOutput()
        if session.canAddOutput(pOutput) {
            session.addOutput(pOutput)
            self.photoOutput = pOutput
        }
        
        session.commitConfiguration()
        
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        
        self.previewLayer = preview
        self.captureSession = session
        
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }
    
    // MARK: - AVCaptureMetadataOutputObjectsDelegate
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue else {
            return
        }
        onBarcodeDetected?(stringValue)
    }
    
    // MARK: - AVCapturePhotoCaptureDelegate
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        isCapturing = false
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            onPhotoCaptured?(nil)
            return
        }
        onPhotoCaptured?(image)
    }
}
