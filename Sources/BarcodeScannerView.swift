import SwiftUI
import AVFoundation
import PhotosUI

public enum BarcodeScannerMode: String, CaseIterable, Identifiable {
    case barcode = "Штрих-код"
    case labelAI = "Этикетка (ИИ)"
    
    public var id: String { rawValue }
}

public struct BarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let onProductScanned: (BarcodeProduct) -> Void
    
    @State private var mode: BarcodeScannerMode = .barcode
    @State private var isScanning = true
    @State private var isLoading = false
    @State private var loadingStatusText: String = "Поиск в базе продуктов..."
    @State private var errorMessage: String? = nil
    @State private var notFoundBarcode: String? = nil
    
    @State private var scannedProduct: BarcodeProduct? = nil
    @State private var isTorchOn = false
    @State private var laserOffset: CGFloat = -120
    @State private var portionWeight: Double = 100.0
    
    // Ручной ввод и выбор фото
    @State private var showingManualEntrySheet = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var capturePhotoTrigger: Int = 0
    
    public init(onProductScanned: @escaping (BarcodeProduct) -> Void) {
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
                            processLabelImage(img, linkedBarcode: notFoundBarcode)
                        }
                    }
                )
                .ignoresSafeArea()
                
                // Затемнение вокруг видоискателя
                Color.black.opacity(0.42)
                    .mask(
                        Rectangle()
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .frame(
                                        width: mode == .barcode ? 290 : 310,
                                        height: mode == .barcode ? 200 : 280
                                    )
                                    .blendMode(.destinationOut)
                            )
                    )
                    .compositingGroup()
                    .ignoresSafeArea()
                
                // Рамка видоискателя и элементы управления
                VStack(spacing: 0) {
                    // Переключатель режимов
                    modePicker
                        .padding(.top, 10)
                    
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
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
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
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.6), for: .navigationBar)
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
                    let successImpact = UINotificationFeedbackGenerator()
                    successImpact.notificationOccurred(.success)
                }
            }
        }
    }
    
    // MARK: - Переключатель режимов
    
    private var modePicker: some View {
        HStack(spacing: 6) {
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    mode = .barcode
                    isScanning = true
                    errorMessage = nil
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "barcode.viewfinder")
                    Text("Штрих-код")
                }
                .font(.caption)
                .bold()
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(mode == .barcode ? Color(red: 0/255, green: 229/255, blue: 255/255) : Color.white.opacity(0.12))
                .foregroundColor(mode == .barcode ? .black : .white)
                .cornerRadius(20)
            }
            
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    mode = .labelAI
                    isScanning = false
                    errorMessage = nil
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                    Text("Этикетка КБЖУ (ИИ)")
                }
                .font(.caption)
                .bold()
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(mode == .labelAI ? LinearGradient(colors: [Theme.aiAccent, Color(red: 168/255, green: 85/255, blue: 247/255)], startPoint: .leading, endPoint: .trailing) : LinearGradient(colors: [Color.white.opacity(0.12), Color.white.opacity(0.12)], startPoint: .leading, endPoint: .trailing))
                .foregroundColor(.white)
                .cornerRadius(20)
            }
        }
        .padding(4)
        .background(Color.black.opacity(0.6))
        .cornerRadius(24)
    }
    
    // MARK: - Центральная рамка видоискателя
    
    private var viewfinderFrame: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        mode == .barcode
                            ? LinearGradient(colors: [Color(red: 0/255, green: 229/255, blue: 255/255), Color(red: 0/255, green: 145/255, blue: 255/255)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [Theme.aiAccent, Color(red: 236/255, green: 72/255, blue: 153/255)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 3
                    )
                    .frame(
                        width: mode == .barcode ? 290 : 310,
                        height: mode == .barcode ? 200 : 280
                    )
                    .shadow(
                        color: (mode == .barcode ? Color(red: 0/255, green: 229/255, blue: 255/255) : Theme.aiAccent).opacity(0.6),
                        radius: 10
                    )
                
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
                    VStack(spacing: 10) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.3)
                        Text(loadingStatusText)
                            .font(.caption)
                            .bold()
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding(18)
                    .background(Color.black.opacity(0.85))
                    .cornerRadius(18)
                    .padding(.horizontal, 20)
                }
            }
            
            Text(mode == .barcode ? "Наведите камеру на штрих-код продукта" : "Сфотографируйте этикетку или таблицу КБЖУ")
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
        } else if mode == .labelAI {
            labelAIShutterButton
                .padding(.bottom, 24)
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
    
    // MARK: - Карточка найденного продукта
    
    private func productFoundCard(product: BarcodeProduct) -> some View {
        VStack(spacing: 12) {
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
                            Text("✨ Моя база")
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
                        Text("\(Int(product.caloriesPer100g * portionWeight / 100.0)) ккал")
                            .font(.caption)
                            .bold()
                            .foregroundColor(Theme.pulseColor)
                        
                        if let nutri = product.nutriScore {
                            Text("Nutri-Score: \(nutri)")
                                .font(.caption2)
                                .bold()
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(nutriScoreColor(nutri))
                                .cornerRadius(6)
                                .foregroundColor(.white)
                        }
                    }
                }
                
                Spacer()
            }
            
            // Степпер веса порции
            HStack {
                Text("Порция:")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                Stepper(value: $portionWeight, in: 10...1000, step: 25) {
                    Text("\(Int(portionWeight)) г")
                        .font(.headline)
                        .bold()
                        .foregroundColor(.white)
                }
            }
            
            HStack(spacing: 12) {
                Button(action: {
                    withAnimation {
                        scannedProduct = nil
                        isScanning = true
                        laserOffset = -90
                        errorMessage = nil
                        notFoundBarcode = nil
                    }
                }) {
                    Text("Сканировать еще")
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(.white)
                        .padding()
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
                    dismiss()
                }) {
                    Text("Добавить в блюдо")
                        .font(.headline)
                        .bold()
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Theme.exerciseColor)
                        .cornerRadius(14)
                        .shadow(color: Theme.exerciseColor.opacity(0.4), radius: 8)
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
    
    // MARK: - Карточка ненайденного штрих-кода (Умный ИИ фолбек + ручной ввод)
    
    private func barcodeNotFoundCard(barcode: String) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 20))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Штрих-код \(barcode) не найден")
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(.white)
                    Text("Сфотографируйте этикетку КБЖУ или введите данные — они сохранятся в вашу базу.")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.75))
                }
                Spacer()
            }
            
            HStack(spacing: 10) {
                // Кнопка переключения в режим ИИ-этикетки
                Button(action: {
                    withAnimation {
                        mode = .labelAI
                        errorMessage = nil
                    }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.viewfinder")
                        Text("Снять этикетку (ИИ)")
                    }
                    .font(.subheadline)
                    .bold()
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
                
                // Кнопка ручного ввода
                Button(action: {
                    showingManualEntrySheet = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                        Text("Вручную")
                    }
                    .font(.subheadline)
                    .bold()
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
                isScanning = true
                laserOffset = -90
            }) {
                Text("Попробовать снова")
                    .font(.caption)
                    .bold()
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
    
    // MARK: - Кнопка спуска затвора для этикетки КБЖУ
    
    private var labelAIShutterButton: some View {
        Button(action: {
            capturePhotoTrigger += 1
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
        }) {
            ZStack {
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 72, height: 72)
                Circle()
                    .fill(LinearGradient(colors: [Theme.aiAccent, Color(red: 168/255, green: 85/255, blue: 247/255)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 58, height: 58)
                Image(systemName: "sparkles")
                    .foregroundColor(.white)
                    .font(.system(size: 22, weight: .bold))
            }
            .shadow(color: Theme.aiAccent.opacity(0.5), radius: 10)
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
        
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()
        
        Task {
            do {
                let product = try await BarcodeScannerService.shared.fetchProduct(barcode: barcode)
                await MainActor.run {
                    self.scannedProduct = product
                    self.portionWeight = product.servingWeightGrams
                    self.isLoading = false
                    let successImpact = UINotificationFeedbackGenerator()
                    successImpact.notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    self.notFoundBarcode = barcode
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    let errorImpact = UINotificationFeedbackGenerator()
                    errorImpact.notificationOccurred(.error)
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
                
                // Сохраняем распознанный продукт в локальную базу пользователя
                BarcodeScannerService.shared.saveCustomProduct(product)
                
                await MainActor.run {
                    self.scannedProduct = product
                    self.portionWeight = product.servingWeightGrams
                    self.isLoading = false
                    self.notFoundBarcode = nil
                    self.errorMessage = nil
                    let successImpact = UINotificationFeedbackGenerator()
                    successImpact.notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    let errorImpact = UINotificationFeedbackGenerator()
                    errorImpact.notificationOccurred(.error)
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
                    processLabelImage(image, linkedBarcode: notFoundBarcode)
                }
            }
        }
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
                    
                    HStack {
                        Text("Стандартная порция (г)")
                        Spacer()
                        TextField("100", text: $portionGramsStr)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                    }
                }
            }
            .navigationTitle("Новый продукт")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        saveProduct()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func saveProduct() {
        let cleanCode = barcode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "USER_\(UUID().uuidString.prefix(8))" : barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBrand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let cal = Double(caloriesStr.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        let p = Double(proteinStr.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        let f = Double(fatStr.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        let c = Double(carbsStr.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        let serving = Double(portionGramsStr) ?? 100.0
        
        let product = BarcodeProduct(
            barcode: cleanCode,
            name: cleanName,
            brand: cleanBrand,
            servingSize: "\(Int(serving)) г",
            servingWeightGrams: serving,
            caloriesPer100g: max(0, cal),
            proteinPer100g: max(0, p),
            fatPer100g: max(0, f),
            carbsPer100g: max(0, c),
            isUserCustom: true
        )
        
        onSave(product)
        dismiss()
    }
}

// MARK: - Camera Preview с распознаванием штрих-кодов и захватом фото

struct BarcodeCameraPreview: UIViewControllerRepresentable {
    var isTorchOn: Bool
    var captureTrigger: Int
    var onBarcodeDetected: (String) -> Void
    var onPhotoCaptured: (UIImage?) -> Void
    
    func makeUIViewController(context: Context) -> BarcodeCameraViewController {
        let vc = BarcodeCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }
    
    func updateUIViewController(_ uiViewController: BarcodeCameraViewController, context: Context) {
        uiViewController.setTorch(on: isTorchOn)
        if context.coordinator.lastTrigger != captureTrigger {
            context.coordinator.lastTrigger = captureTrigger
            if captureTrigger > 0 {
                uiViewController.capturePhoto()
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, BarcodeCameraViewControllerDelegate {
        let parent: BarcodeCameraPreview
        var lastTrigger: Int = 0
        
        init(_ parent: BarcodeCameraPreview) {
            self.parent = parent
        }
        
        func didFindBarcode(_ barcode: String) {
            parent.onBarcodeDetected(barcode)
        }
        
        func didCapturePhoto(_ image: UIImage?) {
            parent.onPhotoCaptured(image)
        }
    }
}

protocol BarcodeCameraViewControllerDelegate: AnyObject {
    func didFindBarcode(_ barcode: String)
    func didCapturePhoto(_ image: UIImage?)
}

final class BarcodeCameraViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate, AVCapturePhotoCaptureDelegate {
    weak var delegate: BarcodeCameraViewControllerDelegate?
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var photoOutput: AVCapturePhotoOutput?
    
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
        if captureSession?.isRunning == false {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession?.startRunning()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession?.isRunning == true {
            captureSession?.stopRunning()
        }
    }
    
    func setTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
    }
    
    func capturePhoto() {
        guard let photoOutput = photoOutput else { return }
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    private func setupCamera() {
        let session = AVCaptureSession()
        captureSession = session
        session.sessionPreset = .photo
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else {
            return
        }
        
        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        } else {
            return
        }
        
        // Добавляем MetadataOutput для распознавания штрих-кодов
        let metadataOutput = AVCaptureMetadataOutput()
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [
                .ean13, .ean8, .upce, .qr, .code128, .code39
            ]
        }
        
        // Добавляем PhotoOutput для фотосъемки этикеток
        let pOutput = AVCapturePhotoOutput()
        if session.canAddOutput(pOutput) {
            session.addOutput(pOutput)
            self.photoOutput = pOutput
        }
        
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.layer.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        previewLayer = preview
        
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }
    
    // MARK: - AVCaptureMetadataOutputObjectsDelegate
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first,
           let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
           let stringValue = readableObject.stringValue {
            delegate?.didFindBarcode(stringValue)
        }
    }
    
    // MARK: - AVCapturePhotoCaptureDelegate
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let fileData = photo.fileDataRepresentation(), let image = UIImage(data: fileData) else {
            delegate?.didCapturePhoto(nil)
            return
        }
        delegate?.didCapturePhoto(image)
    }
}

