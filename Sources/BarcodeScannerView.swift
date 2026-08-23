import SwiftUI
import AVFoundation

public struct BarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let onProductScanned: (BarcodeProduct) -> Void
    
    @State private var isScanning = true
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var scannedProduct: BarcodeProduct? = nil
    @State private var isTorchOn = false
    @State private var laserOffset: CGFloat = -120
    @State private var portionWeight: Double = 100.0
    
    public init(onProductScanned: @escaping (BarcodeProduct) -> Void) {
        self.onProductScanned = onProductScanned
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                // Камера видоискателя
                BarcodeCameraPreview(isTorchOn: isTorchOn) { barcode in
                    handleBarcodeDetected(barcode)
                }
                .ignoresSafeArea()
                
                // Затемнение вокруг видоискателя
                Color.black.opacity(0.4)
                    .mask(
                        Rectangle()
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .frame(width: 280, height: 200)
                                    .blendMode(.destinationOut)
                            )
                    )
                    .compositingGroup()
                    .ignoresSafeArea()
                
                // Рамка видоискателя с неоновой подсветкой
                VStack {
                    Spacer()
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                LinearGradient(
                                    colors: [Color(red: 0/255, green: 229/255, blue: 255/255), Color(red: 0/255, green: 145/255, blue: 255/255)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                            .frame(width: 280, height: 200)
                            .shadow(color: Color(red: 0/255, green: 229/255, blue: 255/255).opacity(0.6), radius: 8)
                        
                        // Лазерная линия сканирования
                        if isScanning && !isLoading && scannedProduct == nil {
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.clear, Color(red: 0/255, green: 229/255, blue: 255/255), Color.clear],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 260, height: 3)
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
                        
                        // Лоадер поиска в OpenFoodFacts
                        if isLoading {
                            VStack(spacing: 8) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.3)
                                Text("Поиск в базе продуктов...")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.white)
                            }
                            .padding(16)
                            .background(Color.black.opacity(0.75))
                            .cornerRadius(16)
                        }
                    }
                    
                    Text("Наведите камеру на штрих-код продукта")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.top, 16)
                    
                    Spacer()
                    
                    // Нижняя карточка найденного продукта
                    if let product = scannedProduct {
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                Text(product.emoji)
                                    .font(.system(size: 38))
                                    .frame(width: 50, height: 50)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(Circle())
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(product.name)
                                        .font(.headline)
                                        .bold()
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    
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
                                    scannedProduct = nil
                                    isScanning = true
                                    laserOffset = -90
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
                                        emoji: product.emoji
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
                    } else if let error = errorMessage {
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
                }
            }
            .navigationTitle("Сканер штрих-кода")
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
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.6), for: .navigationBar)
        }
    }
    
    private func handleBarcodeDetected(_ barcode: String) {
        guard isScanning, !isLoading else { return }
        isScanning = false
        isLoading = true
        errorMessage = nil
        
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
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
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

// Camera Preview с распознаванием штрих-кодов
struct BarcodeCameraPreview: UIViewControllerRepresentable {
    var isTorchOn: Bool
    var onBarcodeDetected: (String) -> Void
    
    func makeUIViewController(context: Context) -> BarcodeCameraViewController {
        let vc = BarcodeCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }
    
    func updateUIViewController(_ uiViewController: BarcodeCameraViewController, context: Context) {
        uiViewController.setTorch(on: isTorchOn)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, BarcodeCameraViewControllerDelegate {
        let parent: BarcodeCameraPreview
        
        init(_ parent: BarcodeCameraPreview) {
            self.parent = parent
        }
        
        func didFindBarcode(_ barcode: String) {
            parent.onBarcodeDetected(barcode)
        }
    }
}

protocol BarcodeCameraViewControllerDelegate: AnyObject {
    func didFindBarcode(_ barcode: String)
}

final class BarcodeCameraViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: BarcodeCameraViewControllerDelegate?
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
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
    
    private func setupCamera() {
        let session = AVCaptureSession()
        captureSession = session
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else {
            return
        }
        
        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        } else {
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [
                .ean13, .ean8, .upce, .qr, .code128, .code39
            ]
        } else {
            return
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
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first,
           let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
           let stringValue = readableObject.stringValue {
            delegate?.didFindBarcode(stringValue)
        }
    }
}
