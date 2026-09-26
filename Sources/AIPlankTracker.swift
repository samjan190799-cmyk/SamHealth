import SwiftUI
import AVFoundation
import Vision

public enum AIPoseWorkoutType {
    case plank
    case squats
    case pushups
    case none
}

// MARK: - Core Logic Tracker
public class AIPoseTracker: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published public var isPerfectPosture: Bool = false
    @Published public var feedbackMessage: String = "Наведите камеру так, чтобы было видно все тело"
    @Published public var hasWarning: Bool = false
    @Published public var repsCount: Int = 0
    
    public var currentWorkoutType: AIPoseWorkoutType = .none
    
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var lastWarningTime: Date = Date()
    
    // State variables for rep counting
    private var isSquattingDown = false
    private var isPushingDown = false
    
    public override init() {
        super.init()
        setupCamera()
    }
    
    private func setupCamera() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
            
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            if captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
            }
            
            if let connection = videoOutput.connection(with: .video) {
                connection.videoRotationAngle = 90
            }
        } catch {
            print("Ошибка камеры: \(error)")
        }
    }
    
    public func startSession(type: AIPoseWorkoutType) {
        self.currentWorkoutType = type
        self.repsCount = 0
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    public func stopSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }
    
    public func getCaptureSession() -> AVCaptureSession {
        return captureSession
    }
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard currentWorkoutType != .none else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        let request = VNDetectHumanBodyPoseRequest(completionHandler: bodyPoseHandler)
        
        do {
            try requestHandler.perform([request])
        } catch {
            print("Vision error: \(error)")
        }
    }
    
    private func bodyPoseHandler(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNHumanBodyPoseObservation], let observation = observations.first else {
            DispatchQueue.main.async {
                self.hasWarning = true
                self.isPerfectPosture = false
                self.feedbackMessage = "Не вижу вас в кадре. Отойдите подальше."
            }
            return
        }
        
        do {
            let recognizedPoints = try observation.recognizedPoints(.all)
            
            DispatchQueue.main.async {
                self.analyzePose(points: recognizedPoints)
            }
        } catch {
            print("Points error: \(error)")
        }
    }
    
    private func analyzePose(points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]) {
        switch currentWorkoutType {
        case .plank:
            analyzePlank(points: points)
        case .squats:
            analyzeSquats(points: points)
        case .pushups:
            analyzePushups(points: points)
        case .none:
            break
        }
    }
    
    private func analyzePlank(points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]) {
        guard let shoulder = points[.leftShoulder], shoulder.confidence > 0.3,
              let hip = points[.leftHip], hip.confidence > 0.3,
              let ankle = points[.leftAnkle], ankle.confidence > 0.3 else {
            self.hasWarning = true
            self.feedbackMessage = "Встаньте боком к камере. Не вижу спину."
            return
        }
        
        let angle = angleBetween(p1: CGPoint(x: shoulder.location.x, y: shoulder.location.y),
                                 p2: CGPoint(x: hip.location.x, y: hip.location.y),
                                 p3: CGPoint(x: ankle.location.x, y: ankle.location.y))
        
        if angle > 165 {
            self.isPerfectPosture = true
            self.feedbackMessage = "Отличная планка! Держим!"
            self.hasWarning = false
        } else if angle <= 155 {
            self.isPerfectPosture = false
            self.feedbackMessage = "Вы слишком низко опустили таз! Поднимите!"
            self.hasWarning = true
            self.triggerWarningVoice("Поднимите таз, вы провисаете!")
        } else {
            self.isPerfectPosture = false
            self.feedbackMessage = "Держите спину ровно!"
            self.hasWarning = true
        }
    }
    
    private func analyzeSquats(points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]) {
        guard let hip = points[.leftHip], hip.confidence > 0.4,
              let knee = points[.leftKnee], knee.confidence > 0.4,
              let ankle = points[.leftAnkle], ankle.confidence > 0.4 else {
            self.hasWarning = true
            self.feedbackMessage = "Встаньте боком, чтобы было видно ноги полностью."
            return
        }
        
        let kneeAngle = angleBetween(p1: CGPoint(x: hip.location.x, y: hip.location.y),
                                     p2: CGPoint(x: knee.location.x, y: knee.location.y),
                                     p3: CGPoint(x: ankle.location.x, y: ankle.location.y))
        
        if kneeAngle < 100 { // Глубокий присед
            if !isSquattingDown {
                isSquattingDown = true
                self.feedbackMessage = "Хорошая глубина. Теперь вверх!"
                self.isPerfectPosture = true
                self.hasWarning = false
            }
        } else if kneeAngle > 160 { // Стоит прямо
            if isSquattingDown {
                repsCount += 1
                isSquattingDown = false
                self.feedbackMessage = "Приседание засчитано! (\(repsCount))"
                Task { @MainActor in
                    FormaVoiceCoachManager.shared.speak("\(repsCount)")
                    HapticManager.shared.notification(.success)
                }
            } else {
                self.feedbackMessage = "Приседайте ниже 90 градусов."
                self.isPerfectPosture = false
                self.hasWarning = false
            }
        }
    }
    
    private func analyzePushups(points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]) {
        guard let shoulder = points[.leftShoulder], shoulder.confidence > 0.4,
              let elbow = points[.leftElbow], elbow.confidence > 0.4,
              let wrist = points[.leftWrist], wrist.confidence > 0.4 else {
            self.hasWarning = true
            self.feedbackMessage = "Встаньте так, чтобы было видно ваши руки."
            return
        }
        
        let elbowAngle = angleBetween(p1: CGPoint(x: shoulder.location.x, y: shoulder.location.y),
                                      p2: CGPoint(x: elbow.location.x, y: elbow.location.y),
                                      p3: CGPoint(x: wrist.location.x, y: wrist.location.y))
        
        if elbowAngle < 90 { // Внизу
            if !isPushingDown {
                isPushingDown = true
                self.feedbackMessage = "Вниз. Теперь жмите вверх!"
                self.isPerfectPosture = true
                self.hasWarning = false
            }
        } else if elbowAngle > 160 { // Вверху
            if isPushingDown {
                repsCount += 1
                isPushingDown = false
                self.feedbackMessage = "Отжимание засчитано! (\(repsCount))"
                Task { @MainActor in
                    FormaVoiceCoachManager.shared.speak("\(repsCount)")
                    HapticManager.shared.notification(.success)
                }
            } else {
                self.feedbackMessage = "Опускайтесь ниже, чтобы локти согнулись на 90 градусов."
                self.isPerfectPosture = false
                self.hasWarning = false
            }
        }
    }
    
    private func triggerWarningVoice(_ message: String) {
        guard Date().timeIntervalSince(lastWarningTime) > 5.0 else { return }
        lastWarningTime = Date()
        
        Task { @MainActor in
            FormaVoiceCoachManager.shared.speak(message)
            HapticManager.shared.notification(.error)
        }
    }
    
    private func angleBetween(p1: CGPoint, p2: CGPoint, p3: CGPoint) -> CGFloat {
        let a = pow(p2.x - p1.x, 2) + pow(p2.y - p1.y, 2)
        let b = pow(p2.x - p3.x, 2) + pow(p2.y - p3.y, 2)
        let c = pow(p3.x - p1.x, 2) + pow(p3.y - p1.y, 2)
        
        let cosAngle = (a + b - c) / (2 * sqrt(a) * sqrt(b))
        let angle = acos(max(-1.0, min(1.0, cosAngle)))
        return angle * 180 / .pi
    }
}

// MARK: - UI Layer
public struct AIPoseCameraView: UIViewControllerRepresentable {
    let captureSession: AVCaptureSession
    
    public func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = UIScreen.main.bounds
        viewController.view.layer.addSublayer(previewLayer)
        
        let focusFrame = CAShapeLayer()
        let rect = CGRect(x: UIScreen.main.bounds.width * 0.1, y: UIScreen.main.bounds.height * 0.2, width: UIScreen.main.bounds.width * 0.8, height: UIScreen.main.bounds.height * 0.6)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 10)
        focusFrame.path = path.cgPath
        focusFrame.fillColor = UIColor.clear.cgColor
        focusFrame.strokeColor = UIColor.green.withAlphaComponent(0.5).cgColor
        focusFrame.lineWidth = 4
        focusFrame.lineDashPattern = [10, 5]
        viewController.view.layer.addSublayer(focusFrame)
        
        return viewController
    }
    
    public func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
