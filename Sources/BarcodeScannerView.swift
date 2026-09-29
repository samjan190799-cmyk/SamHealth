import SwiftUI
import AVFoundation
import PhotosUI

public enum BarcodeScannerMode: String, CaseIterable, Identifiable {
    case plateAI = "Блюдо 🍽️"
    case barcode = "Штрих-код 🏷️"
    case labelAI = "Этикетка КБЖУ 📋"
    
    public var id: String { rawValue }
}

public struct BarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let onProductScanned: (BarcodeProduct) -> Void
    
    @StateObject private var depthService = PlateDepthService.shared
    @ObservedObject private var coachManager = AICoachManager.shared
    @ObservedObject private var subscription = SubscriptionManager.shared
    
    @State private var mode: BarcodeScannerMode = .plateAI
    @State private var isScanning = true
    @State private var isLoading = false
    @State private var showingPaywall = false
    @State private var loadingStatusText: String = "Анализ блюда через ИИ..."
    @State private var errorMessage: String? = nil
    @State private var notFoundBarcode: String? = nil
    
    @State private var scannedProduct: BarcodeProduct? = nil
    @State private var plateScanResult: FoodScanResult? = nil
    @State private var isTareDeducted: Bool = false
    @State private var isRindDeducted: Bool = true
    @State private var isTorchOn = false
    @State private var laserOffset: CGFloat = -120
    @State private var portionWeight: Double = 350.0
    @State private var userPromptHint: String = ""
    @State private var showingCustomWeightAlert = false
    @State private var customWeightInput: String = ""
    
    // Ручной ввод и выбор фото
    @State private var showingManualEntrySheet = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var capturePhotoTrigger: Int = 0
    
    // Согласие с правилами ИИ и отложенные задачи сканирования
    @AppStorage("user_consented_to_ai_sharing") private var userConsentedToAISharing = false
    @State private var showingAIConsentSheet = false
    @State private var pendingPlateImage: UIImage? = nil
    @State private var pendingPlateDepth: PlateMeasurement? = nil
    @State private var pendingLabelImage: UIImage? = nil
    
    // Состояние разрешений камеры и выбранная категория приема пищи
    @State private var cameraPermissionStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var selectedMealCategory: MealCategory = MealCategory.defaultForCurrentHour()
    
    // Вспышка затвора и управление зумом
    @State private var shutterFlashOpacity: Double = 0.0
    @State private var currentZoomLevel: CGFloat = 1.0
    
    // Синтезатор речи тренера
    @AppStorage("ai_voice_food_scan_enabled") private var isFoodVoiceSpeechEnabled = true
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
                
                // Вычисляем cropRect рамки для обрезки
                let screenW = UIScreen.main.bounds.width
                let screenH = UIScreen.main.bounds.height
                let finderSize = viewfinderSize(for: mode)
                let currentCropRect = CGRect(x: (screenW - finderSize.width) / 2.0, y: (screenH - finderSize.height) / 2.0, width: finderSize.width, height: finderSize.height)
                
                // Камера видоискателя с поддержкой сканирования штрих-кода, зума и захвата фото
                BarcodeCameraPreview(
                    isTorchOn: isTorchOn,
                    captureTrigger: capturePhotoTrigger,
                    zoomLevel: currentZoomLevel,
                    cropRect: currentCropRect,
                    depthEnabled: mode == .plateAI,
                    onBarcodeDetected: { barcode in
                        if mode == .barcode {
                            handleBarcodeDetected(barcode)
                        }
                    },
                    onLiveDepth: { distance in
                        depthService.updateLiveDistance(distance)
                    },
                    onPhotoCaptured: { capturedImage, depthMeasurement in
                        if let img = capturedImage {
                            if mode == .plateAI {
                                processPlateImage(img, depth: depthMeasurement)
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
                                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                                    .frame(width: viewfinderSize(for: mode).width, height: viewfinderSize(for: mode).height)
                                    .blendMode(.destinationOut)
                            )
                    )
                    .compositingGroup()
                    .ignoresSafeArea()
                
                // Белая вспышка спуска затвора (Shutter Flash FX)
                Color.white
                    .opacity(shutterFlashOpacity)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                
                // Рамка видоискателя и элементы управления
                VStack(spacing: 0) {
                    // Кастомный верхний бар
                    customTopBar
                        .padding(.top, 8)
                    
                    // Переключатель 3 режимов
                    modePicker
                        .padding(.top, 8)
                    
                    // LiDAR 3D Live HUD статус
                    if mode == .plateAI && scannedProduct == nil && !isLoading {
                        lidarStatusHUD
                            .padding(.top, 10)
                    }
                    
                    Spacer()
                    
                    // Центральная рамка с подсветкой (скрывается при показе карточки блюда для экономии места)
                    if scannedProduct == nil {
                        viewfinderFrame
                        Spacer()
                    }
                    
                    // Нижняя панель действий (карточка продукта / ошибка / кнопки AI / затвор)
                    bottomContentArea
                }
                
                // Заглушка, если доступ к камере запрещен пользователем
                if cameraPermissionStatus == .denied || cameraPermissionStatus == .restricted {
                    cameraPermissionDeniedView
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarHidden(true)
            .onAppear {
                checkCameraPermission()
                depthService.setActive(mode == .plateAI)
            }
            .onDisappear {
                depthService.setActive(false)
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
            .sheet(isPresented: $showingPaywall) {
                FormaPaywallView()
            }
            .sheet(isPresented: $showingAIConsentSheet) {
                AIConsentSheet(onConsentGiven: {
                    userConsentedToAISharing = true
                    if let img = pendingPlateImage {
                        let depth = pendingPlateDepth
                        pendingPlateImage = nil
                        pendingPlateDepth = nil
                        processPlateImage(img, depth: depth)
                    } else if let img = pendingLabelImage {
                        pendingLabelImage = nil
                        processLabelImage(img, linkedBarcode: notFoundBarcode)
                    }
                })
            }
            .alert("Указать точный вес порции", isPresented: $showingCustomWeightAlert) {
                TextField("Вес в граммах (например: 2000)", text: $customWeightInput)
                    .keyboardType(.numberPad)
                Button("Отмена", role: .cancel) {
                    customWeightInput = ""
                }
                Button("Применить") {
                    let cleaned = customWeightInput.replacingOccurrences(of: ",", with: ".")
                        .components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted)
                        .joined()
                    if let val = Double(cleaned), val > 0 {
                        portionWeight = min(15000.0, max(10.0, val))
                        HapticManager.shared.impact(.medium)
                    }
                    customWeightInput = ""
                }
            } message: {
                Text("Введите реальный вес продукта в граммах (до 15 кг). КБЖУ будут мгновенно пересчитаны.")
            }
            .onChange(of: mode) { _, newMode in
                depthService.setActive(newMode == .plateAI)
            }
        }
    }
    
    /// Размер рамки видоискателя. От него зависит и кадрирование фото, поэтому вычисляется в одном месте.
    /// На узких экранах рамка сужается, чтобы не упираться в края.
    private func viewfinderSize(for mode: BarcodeScannerMode) -> CGSize {
        let available = UIScreen.main.bounds.width - 48
        switch mode {
        case .barcode: return CGSize(width: min(290, available), height: 200)
        case .plateAI:
            let side = min(330, available)
            return CGSize(width: side, height: side)
        case .labelAI: return CGSize(width: min(310, available), height: 280)
        }
    }
    
    // MARK: - Верхняя панель управления
    private var customTopBar: some View {
        HStack(spacing: 12) {
            Button(action: {
                isTorchOn.toggle()
                HapticManager.shared.impact(.light)
            }) {
                ZStack {
                    Circle()
                        .fill(isTorchOn ? Color.yellow.opacity(0.25) : Color.white.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                        .foregroundColor(isTorchOn ? .yellow : .white)
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .accessibilityLabel("Фонарик")
            .accessibilityValue(isTorchOn ? "включён" : "выключен")
            
            // Быстрый переключатель зума (1x / 2x)
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    currentZoomLevel = (currentZoomLevel <= 1.0) ? 2.0 : 1.0
                }
                HapticManager.shared.impact(.light)
            }) {
                ZStack {
                    Circle()
                        .fill(currentZoomLevel > 1.0 ? Color.yellow.opacity(0.3) : Color.white.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Text(currentZoomLevel > 1.0 ? "2×" : "1×")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundColor(currentZoomLevel > 1.0 ? .yellow : .white)
                }
            }
            .accessibilityLabel("Зум")
            .accessibilityValue(currentZoomLevel > 1.0 ? "2 крат" : "1 крат")
            
            Spacer()
            
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "photo.on.rectangle.angled")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .accessibilityLabel("Выбрать фото из галереи")
            
            Button(action: {
                depthService.setActive(false)
                dismiss()
            }) {
                Text("Закрыть")
                    .font(.footnote.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - LiDAR 3D Live HUD статус
    private var lidarStatusHUD: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: depthService.isLiDARAvailable ? "sensor.fill" : "camera.viewfinder")
                    .foregroundColor(depthService.isLiDARAvailable ? Color(red: 0/255, green: 229/255, blue: 255/255) : .white.opacity(0.7))
                    .font(.system(size: 13, weight: .bold))
                
                Text(depthService.statusMessage)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                if depthService.isLiDARAvailable && depthService.targetLockDetected {
                    Text("LiDAR")
                        .font(.caption2.weight(.heavy))
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
            .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .stroke((depthService.targetLockDetected ? Color(red: 0/255, green: 229/255, blue: 255/255) : Color.white).opacity(0.4), lineWidth: 1)
            )
            
            if !subscription.isPro {
                Button(action: {
                    showingPaywall = true
                    HapticManager.shared.selection()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.yellow)
                            .font(.caption2.weight(.bold))
                        Text("Бесплатно сегодня: \(subscription.freeScansRemainingToday)/\(subscription.maxFreeDailyScans)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                        Text("PRO 💎")
                            .font(.caption2.weight(.heavy))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.yellow.opacity(0.25))
                            .foregroundColor(.yellow)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.65))
                    .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
                }
            }
        }
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
                        isTareDeducted = false
                        isScanning = (m == .barcode)
                        
                        depthService.setActive(m == .plateAI)
                    }
                    HapticManager.shared.selection()
                }) {
                    Text(m.rawValue)
                        .font(.caption.weight(isSelected ? .bold : .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 40)
                        .background(
                            isSelected
                                ? (m == .plateAI ? Color(red: 16/255, green: 185/255, blue: 129/255) : (m == .barcode ? Color(red: 0/255, green: 229/255, blue: 255/255) : Theme.aiAccent))
                                : Color.white.opacity(0.08)
                        )
                        .foregroundColor(isSelected ? (m == .barcode ? .black : .white) : .white.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
                }
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Color.black.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
        .opacity(isLoading ? 0.6 : 1.0)
        .disabled(isLoading)
    }
    
    // MARK: - Центральная рамка видоискателя
    
    private var viewfinderFrame: some View {
        VStack(spacing: 12) {
            ZStack {
                let frameWidth: CGFloat = viewfinderSize(for: mode).width
                let frameHeight: CGFloat = viewfinderSize(for: mode).height
                let borderColor: Color = mode == .plateAI ? Color(red: 16/255, green: 185/255, blue: 129/255) : (mode == .barcode ? Color(red: 0/255, green: 229/255, blue: 255/255) : Theme.aiAccent)
                
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .stroke(
                        LinearGradient(colors: [borderColor, borderColor.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 3
                    )
                    .frame(width: frameWidth, height: frameHeight)
                    .shadow(color: borderColor.opacity(0.6), radius: 12)
                    .accessibilityHidden(true)
                
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
                    .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
                    .padding(.horizontal, 20)
                }
            }
            
            Text(mode == .plateAI ? (depthService.isLiDARAvailable ? "Держите блюдо целиком в рамке — LiDAR измерит размер порции" : "Сфотографируйте блюдо целиком — ИИ оценит порцию и КБЖУ") : (mode == .barcode ? "Наведите камеру на штрих-код продукта" : "Сфотографируйте этикетку или таблицу КБЖУ"))
                .font(.footnote.weight(.semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .shadow(color: .black.opacity(0.7), radius: 3, y: 1)
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
                            .font(.footnote)
                            .foregroundColor(.white)
                            .accessibilityLabel("Уточнение к блюду")
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
                    .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
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
                HStack(spacing: 8) {
                    Image(systemName: "square.and.pencil")
                    Text("Ввести продукт вручную")
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.75))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
            }
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Карточка найденного продукта / Блюда
    
    private func productFoundCard(product: BarcodeProduct) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Text(product.emoji)
                    .font(.system(size: 38))
                    .frame(width: 50, height: 50)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(product.name)
                            .font(.headline)
                            .bold()
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        if product.isUserCustom {
                            Text(mode == .plateAI ? "✨ AI-скан" : "✨ Моя база")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.aiAccent.opacity(0.3))
                                .foregroundColor(Theme.aiAccent)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                    }
                    
                    if !product.brand.isEmpty {
                        Text(product.brand)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    HStack(spacing: 8) {
                        let effectiveW = (plateScanResult?.isWatermelonOrMelon == true && isRindDeducted) ? portionWeight * 0.7 : portionWeight
                        let totalCal = Int(product.caloriesPer100g * effectiveW / 100.0)
                        Text("\(totalCal) ккал")
                            .font(.caption.bold())
                            .foregroundColor(Theme.pulseColor)
                        
                        let p = Int(product.proteinPer100g * effectiveW / 100.0)
                        let f = Int(product.fatPer100g * effectiveW / 100.0)
                        let c = Int(product.carbsPer100g * effectiveW / 100.0)
                        Text("• Б: \(p)г Ж: \(f)г У: \(c)г")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.white.opacity(0.8))
                        
                        if let nutri = product.nutriScore {
                            Text(nutri)
                                .font(.caption2.bold())
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(nutriScoreColor(nutri))
                                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                .foregroundColor(.white)
                        }
                    }
                }
                Spacer()
            }
            
            // Выбор категории приема пищи (Завтрак / Обед / Ужин / Перекус)
            HStack(spacing: 8) {
                ForEach(MealCategory.allCases) { cat in
                    Button(action: {
                        selectedMealCategory = cat
                        HapticManager.shared.selection()
                    }) {
                        HStack(spacing: 4) {
                            Text(cat.emoji)
                            Text(cat.title)
                                .font(.caption2.weight(selectedMealCategory == cat ? .bold : .medium))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(selectedMealCategory == cat ? Theme.exerciseColor.opacity(0.3) : Color.white.opacity(0.08))
                        .foregroundColor(selectedMealCategory == cat ? .white : .white.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.chip, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: FormaRadius.chip, style: .continuous)
                                .stroke(selectedMealCategory == cat ? Theme.exerciseColor : Color.clear, lineWidth: 1)
                        )
                    }
                }
            }
            
            // Если есть экспертные маркеры различия блюда от ИИ (например, Самса vs Эчпочмак)
            if let plate = plateScanResult, let notes = plate.visualDistinctionNotes, !notes.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.yellow)
                        .font(.caption)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Кулинарный маркер ИИ:")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.white.opacity(0.7))
                        Text(notes)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.95))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(8)
                .background(Color.purple.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: FormaRadius.chip, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: FormaRadius.chip, style: .continuous)
                        .stroke(Color.purple.opacity(0.4), lineWidth: 1)
                )
            }
            
            // Если есть детализация ингредиентов с блюда
            if let plate = plateScanResult, !plate.ingredients.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
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
                                .clipShape(RoundedRectangle(cornerRadius: FormaRadius.chip, style: .continuous))
                            }
                        }
                    }
                }
            }
            
            // Контроль тары и веса посуды (керамическая тарелка / кухонные весы)
            if let plate = plateScanResult {
                let tare = plate.tareWeightGrams ?? 380.0
                let container = plate.containerType ?? "Керамическая тарелка"
                
                HStack(spacing: 8) {
                    Image(systemName: isTareDeducted ? "tray.and.arrow.down.fill" : "scalemass.fill")
                        .foregroundColor(isTareDeducted ? .green : .orange)
                        .font(.caption)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 4) {
                            Text(container)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                            Text(isTareDeducted ? "Тара вычтена ✓" : "Тара включена")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background((isTareDeducted ? Color.green : Color.orange).opacity(0.25))
                                .foregroundColor(isTareDeducted ? .green : .orange)
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        }
                        Text(isTareDeducted ? "Чистый вес еды: \(Int(portionWeight)) г" : "Посуда: ~\(Int(tare)) г")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        togglePlateTareDeduction(tareGrams: tare)
                    }) {
                        Text(isTareDeducted ? "С тарелкой" : "Вычесть тару")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(isTareDeducted ? Color.white.opacity(0.15) : Color.green)
                            .clipShape(RoundedRectangle(cornerRadius: FormaRadius.chip, style: .continuous))
                    }
                }
                .padding(8)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: FormaRadius.chip, style: .continuous))
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
                        speakAdvice(advice, force: true)
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
                .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
            }
            
            // Контроль корки для арбуза и дыни
            if let plate = plateScanResult, plate.isWatermelonOrMelon {
                Toggle(isOn: $isRindDeducted) {
                    HStack(spacing: 8) {
                        Text("🍉")
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Вычитать корку арбуза (~30%)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                            Text(isRindDeducted ? "Калории считаются за сочную мякоть (~70%): \(Int(portionWeight * 0.7)) г" : "Калории считаются на весь вес брутто: \(Int(portionWeight)) г")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.75))
                        }
                    }
                }
                .tint(Theme.exerciseColor)
                .padding(10)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
            }
            
            // Чипы быстрого выбора порций для арбузов и дынь
            if let plate = plateScanResult, plate.isWatermelonOrMelon {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Быстрый выбор порции:")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            quickPortionChip(title: "200г (ломтик)", weight: 200)
                            quickPortionChip(title: "500г (ломоть)", weight: 500)
                            quickPortionChip(title: "1 кг", weight: 1000)
                            quickPortionChip(title: "2 кг (кусок) 🍉", weight: 2000)
                            quickPortionChip(title: "3 кг (четверть)", weight: 3000)
                            quickPortionChip(title: "4.5 кг (половина)", weight: 4500)
                        }
                    }
                }
            }
            
            // Степпер веса порции и прямой ввод
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Вес порции:")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                    Text("Нажмите для ввода вручную")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                
                Button(action: {
                    customWeightInput = "\(Int(portionWeight))"
                    showingCustomWeightAlert = true
                    HapticManager.shared.impact(.light)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 11, weight: .bold))
                        Text("\(Int(portionWeight)) г")
                            .font(.headline.bold())
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.exerciseColor.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: FormaRadius.chip, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: FormaRadius.chip, style: .continuous)
                            .stroke(Theme.exerciseColor.opacity(0.6), lineWidth: 1)
                    )
                }
                
                Stepper("", value: $portionWeight, in: 10...15000, step: portionWeight >= 1000 ? 100 : 25)
                    .labelsHidden()
            }
            
            // Быстрые шаги изменения веса
            HStack(spacing: 8) {
                quickStepButton(delta: -500, label: "-500г")
                quickStepButton(delta: -100, label: "-100г")
                quickStepButton(delta: 100, label: "+100г")
                quickStepButton(delta: 500, label: "+500г")
                quickStepButton(delta: 1000, label: "+1 кг")
            }
            
            // Кнопки действий
            HStack(spacing: 12) {
                Button(action: {
                    withAnimation {
                        scannedProduct = nil
                        plateScanResult = nil
                        isTareDeducted = false
                        isScanning = (mode == .barcode)
                        laserOffset = -90
                        errorMessage = nil
                        notFoundBarcode = nil
                        if speechSynthesizer.isSpeaking {
                            speechSynthesizer.stopSpeaking(at: .immediate)
                        }
                        FormaVoiceCoachManager.shared.stopSpeaking()
                        isSpeakingCoachAdvice = false
                    }
                }) {
                    Text("Еще скан")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
                }
                
                Button(action: {
                    let effectiveWeight = (plateScanResult?.isWatermelonOrMelon == true && isRindDeducted) ? portionWeight * 0.7 : portionWeight
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
                    
                    // 1. Рассчитываем точные КБЖУ для эффективного съедобного веса
                    let factor = effectiveWeight / 100.0
                    let cals = product.caloriesPer100g * factor
                    let prot = product.proteinPer100g * factor
                    let fat = product.fatPer100g * factor
                    let carbs = product.carbsPer100g * factor
                    let category = selectedMealCategory
                    
                    // 2. Создаем и сохраняем прием пищи в дневник, локальную базу и Apple Health
                    let mealRecord = LoggedMealRecord(
                        name: product.name,
                        calories: cals,
                        protein: prot,
                        fat: fat,
                        carbs: carbs,
                        weightGrams: effectiveWeight,
                        category: category,
                        date: Date(),
                        emoji: product.emoji.isEmpty ? "🍽️" : product.emoji,
                        textureType: plateScanResult?.resolvedTexture
                    )
                    HealthKitManager.shared.addLoggedMeal(mealRecord)
                    
                    // Синхронизация напитка в трекер воды/кофеина без дублирования калорий
                    if let plate = plateScanResult, plate.isDrinkOrBeverage {
                        let bevType = plate.resolvedBeverageType ?? .water
                        let vol = plate.volumeMl ?? effectiveWeight
                        HealthKitManager.shared.logBeverageFluidOnly(type: bevType, volumeMl: vol, customName: product.name)
                    }
                    
                    // 3. Начисляем опыт в геймификацию
                    GamificationManager.shared.addXP(30, reason: "Прием пищи: \(product.name)")
                    
                    onProductScanned(finalProduct)
                    depthService.setActive(false)
                    HapticManager.shared.notification(.success)
                    dismiss()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text("В дневник (+XP)")
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(Color(red: 16/255, green: 185/255, blue: 129/255))
                    .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
                    .shadow(color: Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.4), radius: 8)
                }
            }
        }
        .padding(16)
        }
        .frame(maxHeight: UIScreen.main.bounds.height * 0.55)
        .background(Color(red: 26/255, green: 29/255, blue: 38/255))
        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
        .padding(.horizontal)
        .padding(.bottom, 20)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    private func quickPortionChip(title: String, weight: Double) -> some View {
        Button(action: {
            portionWeight = weight
            HapticManager.shared.impact(.light)
        }) {
            Text(title)
                .font(.system(size: 11, weight: Int(portionWeight) == Int(weight) ? .bold : .medium))
                .foregroundColor(Int(portionWeight) == Int(weight) ? .white : .white.opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Int(portionWeight) == Int(weight) ? Theme.exerciseColor : Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: FormaRadius.chip, style: .continuous))
        }
    }
    
    private func quickStepButton(delta: Double, label: String) -> some View {
        Button(action: {
            portionWeight = min(15000.0, max(10.0, portionWeight + delta))
            HapticManager.shared.impact(.light)
        }) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: FormaRadius.chip, style: .continuous))
        }
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
            
            HStack(spacing: 12) {
                Button(action: {
                    withAnimation {
                        mode = .labelAI
                        errorMessage = nil
                    }
                    HapticManager.shared.impact(.medium)
                }) {
                    HStack(spacing: 8) {
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
                    .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
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
                    .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
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
        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
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
                    .clipShape(RoundedRectangle(cornerRadius: FormaRadius.chip, style: .continuous))
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
        .padding(.bottom, 20)
    }
    
    // MARK: - Кнопка спуска затвора
    
    private var shutterButton: some View {
        Button(action: {
            guard !isLoading else { return }
            triggerShutterFlash()
            capturePhotoTrigger += 1
        }) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(isLoading ? 0.35 : 1.0), lineWidth: 4)
                    .frame(width: 76, height: 76)
                
                let gradientColors: [Color] = mode == .plateAI
                    ? [Color(red: 16/255, green: 185/255, blue: 129/255), Color(red: 5/255, green: 150/255, blue: 105/255)]
                    : [Theme.aiAccent, Color(red: 168/255, green: 85/255, blue: 247/255)]
                
                Circle()
                    .fill(LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 60, height: 60)
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: mode == .plateAI ? "fork.knife" : "sparkles")
                        .foregroundColor(.white)
                        .font(.system(size: 24, weight: .bold))
                }
            }
            .opacity(isLoading ? 0.6 : 1.0)
            .shadow(color: (mode == .plateAI ? Color.green : Theme.aiAccent).opacity(isLoading ? 0.2 : 0.5), radius: 12)
        }
        .disabled(isLoading)
        .accessibilityLabel(mode == .plateAI ? "Сфотографировать блюдо" : "Сфотографировать этикетку")
        .accessibilityHint(isLoading ? "Идёт анализ" : "")
    }
    
    private func triggerShutterFlash() {
        HapticManager.shared.impact(.heavy)
        withAnimation(.easeOut(duration: 0.06)) {
            shutterFlashOpacity = 0.90
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            withAnimation(.easeOut(duration: 0.22)) {
                shutterFlashOpacity = 0.0
            }
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
    
    private func processPlateImage(_ image: UIImage, depth: PlateMeasurement? = nil) {
        if !userConsentedToAISharing {
            pendingPlateImage = image
            pendingPlateDepth = depth
            showingAIConsentSheet = true
            return
        }
        
        let hasCustomKey = !(UserDefaults.standard.string(forKey: "api_key_gemini") ?? "").isEmpty ||
                           !(UserDefaults.standard.string(forKey: "api_key_openai") ?? "").isEmpty ||
                           !(UserDefaults.standard.string(forKey: "api_key_claude") ?? "").isEmpty
        
        if !subscription.canPerformAIScan(hasCustomApiKey: hasCustomKey) {
            showingPaywall = true
            return
        }
        
        isLoading = true
        loadingStatusText = depth != nil ? "Анализ блюда с учётом замера LiDAR..." : "Анализ блюда..."
        errorMessage = nil
        
        Task {
            let lang = UserDefaults.standard.string(forKey: "app_language") ?? "ru"
            let coach = coachManager.currentCoach
            
            var foodResult: FoodScanResult
            
            // Если есть настроенный API-ключ или доступна квота PRO/Daily - пробуем облачный ИИ
            if hasCustomKey || subscription.freeScansRemainingToday > 0 || subscription.isPro {
                do {
                    foodResult = try await GeminiScanService.shared.scanFood(
                        image: image,
                        language: lang,
                        userHint: userPromptHint,
                        depth: depth,
                        coach: coach
                    )
                    await MainActor.run {
                        subscription.consumeAIScan()
                    }
                } catch {
                    // При сетевой ошибке, таймауте или 429 переключаемся на оффлайн машинное зрение без сбоя
                    foodResult = await GeminiScanService.shared.scanFoodOffline(image: image, language: lang)
                }
            } else {
                // Локальный анализ на устройстве через Apple VisionKit
                foodResult = await GeminiScanService.shared.scanFoodOffline(image: image, language: lang)
            }
            
            // Перевод FoodScanResult в формат BarcodeProduct для совместимости
            let totalWeight = foodResult.weight_grams > 0 ? foodResult.weight_grams : 350.0
            let baseWeightForDensity = (foodResult.edibleWeightGrams != nil && foodResult.edibleWeightGrams! > 0) 
                ? foodResult.edibleWeightGrams! 
                : (foodResult.weight_grams > 0 ? foodResult.weight_grams : totalWeight)
            let calsPer100g = baseWeightForDensity > 0 ? (foodResult.calories / baseWeightForDensity) * 100.0 : foodResult.calories
            let pPer100g = baseWeightForDensity > 0 ? (foodResult.protein / baseWeightForDensity) * 100.0 : foodResult.protein
            let fPer100g = baseWeightForDensity > 0 ? (foodResult.fat / baseWeightForDensity) * 100.0 : foodResult.fat
            let cPer100g = baseWeightForDensity > 0 ? (foodResult.carbs / baseWeightForDensity) * 100.0 : foodResult.carbs
            
            let defaultEmoji: String
            if foodResult.isWatermelonOrMelon {
                defaultEmoji = "🍉"
            } else {
                defaultEmoji = foodResult.ingredients.first?.emoji ?? "🍽️"
            }
            
            let product = BarcodeProduct(
                barcode: "PLATE_\(UUID().uuidString.prefix(8))",
                name: foodResult.dish,
                brand: depth != nil ? "ИИ + LiDAR" : "ИИ-скан блюда",
                servingSize: "\(Int(totalWeight)) г",
                servingWeightGrams: totalWeight,
                caloriesPer100g: calsPer100g,
                proteinPer100g: pPer100g,
                fatPer100g: fPer100g,
                carbsPer100g: cPer100g,
                nutriScore: (foodResult.healthScore ?? 8) >= 8 ? "A" : ((foodResult.healthScore ?? 8) >= 6 ? "B" : "C"),
                emoji: defaultEmoji,
                isUserCustom: true
            )
            
            await MainActor.run {
                self.plateScanResult = foodResult
                self.scannedProduct = product
                self.portionWeight = totalWeight
                self.selectedMealCategory = foodResult.resolvedMealCategory
                self.isTareDeducted = foodResult.isTareDeducted ?? false
                self.isLoading = false
                self.errorMessage = nil
                HapticManager.shared.notification(.success)
                
                if isFoodVoiceSpeechEnabled, let adv = foodResult.advice, !adv.isEmpty {
                    speakAdvice(adv, force: false)
                }
            }
        }
    }
    
    private func togglePlateTareDeduction(tareGrams: Double) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            if !isTareDeducted {
                portionWeight = max(30.0, portionWeight - tareGrams)
                isTareDeducted = true
                HapticManager.shared.impact(.medium)
            } else {
                portionWeight = portionWeight + tareGrams
                isTareDeducted = false
                HapticManager.shared.impact(.light)
            }
        }
    }
    
    private func processLabelImage(_ image: UIImage, linkedBarcode: String?) {
        if !userConsentedToAISharing {
            pendingLabelImage = image
            showingAIConsentSheet = true
            return
        }
        
        let hasCustomKey = !(UserDefaults.standard.string(forKey: "api_key_gemini") ?? "").isEmpty ||
                           !(UserDefaults.standard.string(forKey: "api_key_openai") ?? "").isEmpty ||
                           !(UserDefaults.standard.string(forKey: "api_key_claude") ?? "").isEmpty
        if !subscription.canPerformAIScan(hasCustomApiKey: hasCustomKey) {
            showingPaywall = true
            return
        }
        
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
                    subscription.consumeAIScan()
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
    
    private func speakAdvice(_ text: String, force: Bool = true) {
        guard !text.isEmpty else { return }
        if speechSynthesizer.isSpeaking || FormaVoiceCoachManager.shared.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
            FormaVoiceCoachManager.shared.stopSpeaking()
            isSpeakingCoachAdvice = false
            return
        }
        
        let coach = coachManager.currentCoach
        let lang = UserDefaults.standard.string(forKey: "app_language") ?? "ru"
        isSpeakingCoachAdvice = true
        FormaVoiceCoachManager.shared.speakFoodVerdict(text, coach: coach, language: lang, force: force)
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
    
    // MARK: - Проверка прав доступа к камере
    private func checkCameraPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        cameraPermissionStatus = status
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.cameraPermissionStatus = granted ? .authorized : .denied
                }
            }
        }
    }
    
    // MARK: - Баннер запрета доступа к камере (Apple HIG compliant)
    private var cameraPermissionDeniedView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.18))
                    .frame(width: 88, height: 88)
                
                Image(systemName: "camera.fill")
                    .font(.system(size: 38))
                    .foregroundColor(.red)
            }
            
            VStack(spacing: 8) {
                Text("Доступ к камере отключен")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                
                Text("Для сканирования блюд через ИИ и распознавания штрих-кодов Forme требуется доступ к камере вашего iPhone.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
            
            VStack(spacing: 12) {
                Button(action: {
                    if let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "gearshape.fill")
                        Text("Открыть Настройки iPhone")
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(.black)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
                }
                .padding(.horizontal, 32)
                
                Button(action: {
                    dismiss()
                }) {
                    Text("Вернуться")
                        .font(.subheadline.bold())
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.vertical, 8)
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.94))
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
    var zoomLevel: CGFloat
    var cropRect: CGRect?
    /// Запрашивать ли у LiDAR глубину (только режим «Блюдо»).
    var depthEnabled: Bool
    var onBarcodeDetected: (String) -> Void
    /// Расстояние до предмета в центре кадра для HUD (`nil` — данных нет).
    var onLiveDepth: (Double?) -> Void
    /// Кадрированное фото и замер геометрии блюда (`nil`, если датчика нет или замер отклонён).
    var onPhotoCaptured: (UIImage?, PlateMeasurement?) -> Void
    
    func makeUIViewController(context: Context) -> BarcodeCameraViewController {
        let controller = BarcodeCameraViewController()
        controller.onBarcodeDetected = onBarcodeDetected
        controller.onLiveDepth = onLiveDepth
        controller.onPhotoCaptured = onPhotoCaptured
        return controller
    }
    
    func updateUIViewController(_ uiViewController: BarcodeCameraViewController, context: Context) {
        uiViewController.setTorch(isTorchOn)
        uiViewController.setZoom(zoomLevel)
        uiViewController.setDepthEnabled(depthEnabled)
        uiViewController.cropRect = cropRect
        
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
    var onPhotoCaptured: ((UIImage?, PlateMeasurement?) -> Void)?
    var onLiveDepth: ((Double?) -> Void)?
    var cropRect: CGRect?
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var photoOutput: AVCapturePhotoOutput?
    private var isCapturing = false
    
    // Камера, реально стоящая в сессии (на устройствах с LiDAR — LiDAR-камера, иначе стандартная)
    private var videoDevice: AVCaptureDevice?
    private var activeDevice: AVCaptureDevice? { videoDevice ?? AVCaptureDevice.default(for: .video) }
    
    // Глубина: сессия собрана с depth-выходами, режим «Блюдо» включён, фото снято с глубиной
    private var depthOutput: AVCaptureDepthDataOutput?
    private let depthSampler = LiveDepthSampler()
    private let depthQueue = DispatchQueue(label: "forma.plate.depth", qos: .userInitiated)
    private var depthSupported = false
    private var depthWanted = false
    private var depthRequestedForCapture = false
    private var zoomAtCapture: CGFloat = 1.0
    
    private var initialZoomFactor: CGFloat = 1.0
    private var focusIndicatorView: UIView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapToFocus(_:)))
        view.addGestureRecognizer(tapGesture)
        
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchToZoom(_:)))
        view.addGestureRecognizer(pinchGesture)
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
        guard let device = activeDevice, device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
    }
    
    func setZoom(_ factor: CGFloat) {
        guard let device = activeDevice else { return }
        do {
            try device.lockForConfiguration()
            let clamped = min(device.activeFormat.videoMaxZoomFactor, max(1.0, factor))
            device.videoZoomFactor = min(4.0, clamped)
            device.unlockForConfiguration()
        } catch {
            print("[BarcodeCamera] Zoom error: \(error)")
        }
    }
    
    @objc private func handlePinchToZoom(_ gesture: UIPinchGestureRecognizer) {
        guard let device = activeDevice else { return }
        if gesture.state == .began {
            initialZoomFactor = device.videoZoomFactor
        } else if gesture.state == .changed {
            let targetZoom = min(device.activeFormat.videoMaxZoomFactor, max(1.0, initialZoomFactor * gesture.scale))
            try? device.lockForConfiguration()
            device.videoZoomFactor = min(4.0, targetZoom)
            device.unlockForConfiguration()
        }
    }
    
    func capturePhoto() {
        guard let pOutput = photoOutput, !isCapturing else { return }
        isCapturing = true
        let settings = AVCapturePhotoSettings()
        
        // Глубина снимается тем же кадром, что и фото: замер точно соответствует картинке
        depthRequestedForCapture = depthWanted && depthSupported && pOutput.isDepthDataDeliveryEnabled
        if depthRequestedForCapture {
            settings.isDepthDataDeliveryEnabled = true
        }
        zoomAtCapture = currentZoomFactor()
        
        // Гарантируем правильную портретную ориентацию кадра при передаче ИИ
        if let connection = pOutput.connection(with: .video), connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
        
        pOutput.capturePhoto(with: settings, delegate: self)
    }
    
    @objc private func handleTapToFocus(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: view)
        guard let preview = previewLayer,
              let device = activeDevice else { return }
        
        let devicePoint = preview.captureDevicePointConverted(fromLayerPoint: point)
        do {
            try device.lockForConfiguration()
            if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
                device.focusPointOfInterest = devicePoint
                device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.autoExpose) {
                device.exposurePointOfInterest = devicePoint
                device.exposureMode = .autoExpose
            }
            device.unlockForConfiguration()
            
            showFocusIndicator(at: point)
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        } catch {
            print("[BarcodeCamera] Tap to focus error: \(error)")
        }
    }
    
    private func showFocusIndicator(at point: CGPoint) {
        focusIndicatorView?.removeFromSuperview()
        
        let boxSize: CGFloat = 64
        let indicator = UIView(frame: CGRect(x: point.x - boxSize / 2, y: point.y - boxSize / 2, width: boxSize, height: boxSize))
        indicator.backgroundColor = .clear
        indicator.layer.borderColor = UIColor.systemYellow.cgColor
        indicator.layer.borderWidth = 1.8
        indicator.layer.cornerRadius = 10
        indicator.transform = CGAffineTransform(scaleX: 1.35, y: 1.35)
        indicator.alpha = 0.0
        
        view.addSubview(indicator)
        focusIndicatorView = indicator
        
        UIView.animate(withDuration: 0.20, delay: 0, options: .curveEaseOut) {
            indicator.alpha = 1.0
            indicator.transform = .identity
        } completion: { _ in
            UIView.animate(withDuration: 0.35, delay: 0.70, options: .curveEaseIn) {
                indicator.alpha = 0.0
            } completion: { _ in
                indicator.removeFromSuperview()
            }
        }
    }
    
    private func setupCamera() {
        let session = AVCaptureSession()
        session.beginConfiguration()
        
        // На устройствах с LiDAR берём его камеру: только она отдаёт глубину в метрах.
        let lidarDevice = PlateDepthCapture.lidarDevice()
        if lidarDevice != nil, session.canSetSessionPreset(.photo) {
            session.sessionPreset = .photo
        }
        
        guard let videoCaptureDevice = lidarDevice ?? AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else {
            session.commitConfiguration()
            return
        }
        self.videoDevice = videoCaptureDevice
        
        // Включаем непрерывный автофокус и автоэкспозицию для максимальной четкости блюд и штрих-кодов
        do {
            try videoCaptureDevice.lockForConfiguration()
            if videoCaptureDevice.isFocusModeSupported(.continuousAutoFocus) {
                videoCaptureDevice.focusMode = .continuousAutoFocus
            }
            if videoCaptureDevice.isExposureModeSupported(.continuousAutoExposure) {
                videoCaptureDevice.exposureMode = .continuousAutoExposure
            }
            videoCaptureDevice.unlockForConfiguration()
        } catch {
            print("[BarcodeCamera] Auto-focus config error: \(error)")
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
        
        if lidarDevice != nil {
            configureDepth(session: session, device: videoCaptureDevice)
        }
        
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        
        self.previewLayer = preview
        self.captureSession = session
        
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }
    
    // MARK: - Глубина (LiDAR)
    
    /// Вторая фаза настройки — после коммита пресета, когда формат камеры уже выбран.
    /// При любой неудаче сканер продолжает работать по одному фото.
    private func configureDepth(session: AVCaptureSession, device: AVCaptureDevice) {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        
        guard PlateDepthCapture.selectDepthFormat(on: device) else { return }
        
        if let pOutput = photoOutput, pOutput.isDepthDataDeliverySupported {
            pOutput.isDepthDataDeliveryEnabled = true
        }
        
        let dOutput = AVCaptureDepthDataOutput()
        dOutput.isFilteringEnabled = true
        dOutput.alwaysDiscardsLateDepthData = true
        if session.canAddOutput(dOutput) {
            session.addOutput(dOutput)
            depthSampler.onSample = { @Sendable [weak self] distance in
                Task { @MainActor in
                    self?.onLiveDepth?(distance)
                }
            }
            dOutput.setDelegate(depthSampler, callbackQueue: depthQueue)
            // Поток включается только в режиме «Блюдо», чтобы не расходовать батарею на штрих-кодах
            dOutput.connection(with: .depthData)?.isEnabled = depthWanted
            depthOutput = dOutput
        }
        
        depthSupported = photoOutput?.isDepthDataDeliveryEnabled == true
    }
    
    func setDepthEnabled(_ enabled: Bool) {
        depthWanted = enabled
        guard let connection = depthOutput?.connection(with: .depthData),
              connection.isEnabled != enabled else { return }
        connection.isEnabled = enabled
    }
    
    private func currentZoomFactor() -> CGFloat {
        activeDevice?.videoZoomFactor ?? 1.0
    }
    
    /// Считает геометрию блюда по глубине этого же кадра. Рамка съёмки переводится в координаты сенсора
    /// тем же способом, что и кадрирование фото, поэтому замер и картинка описывают одну область.
    private func measurePlate(from photo: AVCapturePhoto) -> PlateMeasurement? {
        guard depthRequestedForCapture else { return nil }
        // При цифровом зуме карта глубины и калибровка перестают соответствовать полному кадру
        guard zoomAtCapture <= 1.05 else {
            print("[BarcodeCamera] Замер глубины пропущен: включён зум ×\(zoomAtCapture)")
            return nil
        }
        guard let depthData = photo.depthData,
              let rect = cropRect, let preview = previewLayer else { return nil }
        
        let normalized = preview.metadataOutputRectConverted(fromLayerRect: rect)
        let fieldOfView = activeDevice.map { Double($0.activeFormat.videoFieldOfView) }
        guard let grid = PlateDepthCapture.grid(from: depthData, fieldOfViewDegrees: fieldOfView) else { return nil }
        
        let region = PlateDepthRegion(
            x0: Double(normalized.minX),
            y0: Double(normalized.minY),
            x1: Double(normalized.maxX),
            y1: Double(normalized.maxY)
        )
        switch PlateDepthAnalyzer.measure(grid: grid, region: region) {
        case .success(let measurement):
            return measurement
        case .failure(let reason):
            print("[BarcodeCamera] Замер глубины отклонён: \(reason)")
            return nil
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
            DispatchQueue.main.async {
                self.onPhotoCaptured?(nil, nil)
            }
            return
        }
        
        let measurement = measurePlate(from: photo)
        
        // Кадрируем изображение (cropping) по зеленой рамке (cropRect), чтобы ИИ видел только еду/этикетку
        let finalImage = cropImage(image, to: cropRect)
        
        DispatchQueue.main.async {
            self.onPhotoCaptured?(finalImage, measurement)
        }
    }
    
    private func cropImage(_ image: UIImage, to rect: CGRect?) -> UIImage {
        guard let rect = rect, let preview = previewLayer, let cgImage = image.cgImage else { return image }
        
        // Конвертируем CGRect из UI (экрана) в нормализованные координаты (0..1) матрицы сенсора.
        // Это магия AVFoundation, которая автоматически учитывает videoGravity = .resizeAspectFill
        let normalizedRect = preview.metadataOutputRectConverted(fromLayerRect: rect)
        
        // Умножаем на сырые (ландшафтные) пиксели cgImage
        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        
        let cropX = normalizedRect.origin.x * imageWidth
        let cropY = normalizedRect.origin.y * imageHeight
        let cropW = normalizedRect.size.width * imageWidth
        let cropH = normalizedRect.size.height * imageHeight
        
        let cropRectFinal = CGRect(x: cropX, y: cropY, width: cropW, height: cropH)
        
        if let croppedCgImage = cgImage.cropping(to: cropRectFinal) {
            return UIImage(cgImage: croppedCgImage, scale: image.scale, orientation: image.imageOrientation)
        }
        
        return image
    }
}
