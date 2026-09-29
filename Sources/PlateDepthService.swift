import Foundation
import SwiftUI
import Combine
import AVFoundation
import CoreMedia
import CoreVideo
import QuartzCore

// MARK: - Датчик глубины для режима «Блюдо»
//
// Абсолютные метры даёт только камера LiDAR (`builtInLiDARDepthCamera`). На остальных
// устройствах замер объёма недоступен — сканер работает по одному фото, и интерфейс
// прямо об этом говорит. Геометрию считает `PlateDepthAnalyzer`, здесь — состояние для HUD
// и чтение AVDepthData.

/// Состояние датчика для живого HUD над видоискателем.
@MainActor
public final class PlateDepthService: ObservableObject {
    public static let shared = PlateDepthService()

    /// Диапазон расстояний, в котором LiDAR даёт устойчивую глубину и блюдо помещается в рамку.
    public static let comfortableRange: ClosedRange<Double> = 0.25...0.70

    @Published public private(set) var isLiDARAvailable: Bool
    @Published public private(set) var isActive: Bool = false
    /// Расстояние до предмета в центре кадра, м. `nil` — свежих данных нет.
    @Published public private(set) var liveDistanceMeters: Double?

    private init() {
        isLiDARAvailable = PlateDepthCapture.lidarDevice() != nil
    }

    public func setActive(_ active: Bool) {
        isActive = active && isLiDARAvailable
        if !isActive { liveDistanceMeters = nil }
    }

    public func updateLiveDistance(_ meters: Double?) {
        guard isActive else { return }
        liveDistanceMeters = meters
    }

    public var targetLockDetected: Bool {
        guard let d = liveDistanceMeters else { return false }
        return Self.comfortableRange.contains(d)
    }

    public var statusMessage: String {
        guard isLiDARAvailable else {
            return "Нет LiDAR • объём оценивается по фото"
        }
        guard let d = liveDistanceMeters else {
            return "LiDAR: наведите камеру на блюдо"
        }
        let dist = String(format: "%.2f", d)
        if d < Self.comfortableRange.lowerBound {
            return "LiDAR: слишком близко (\(dist) м) • отодвиньте камеру"
        }
        if d > Self.comfortableRange.upperBound {
            return "LiDAR: слишком далеко (\(dist) м) • приблизьте к блюду"
        }
        return "LiDAR: \(dist) м • можно снимать"
    }
}

// MARK: - Чтение AVDepthData

enum PlateDepthCapture {

    static func lidarDevice() -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInLiDARDepthCamera, for: .video, position: .back)
    }

    /// Выбирает у камеры формат с картой глубины в метрах (Float16/Float32) максимального разрешения.
    /// Возвращает `false`, если такого формата нет — тогда глубину не запрашиваем.
    static func selectDepthFormat(on device: AVCaptureDevice) -> Bool {
        func pixelCount(_ format: AVCaptureDevice.Format) -> Int {
            let d = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            return Int(d.width) * Int(d.height)
        }
        func depthFormats(of format: AVCaptureDevice.Format) -> [AVCaptureDevice.Format] {
            format.supportedDepthDataFormats.filter {
                let type = CMFormatDescriptionGetMediaSubType($0.formatDescription)
                return type == kCVPixelFormatType_DepthFloat16 || type == kCVPixelFormatType_DepthFloat32
            }
        }

        var videoFormat = device.activeFormat
        var candidates = depthFormats(of: videoFormat)
        if candidates.isEmpty {
            guard let alternative = device.formats
                .filter({ !depthFormats(of: $0).isEmpty })
                .max(by: { pixelCount($0) < pixelCount($1) }) else { return false }
            videoFormat = alternative
            candidates = depthFormats(of: alternative)
        }
        guard let depthFormat = candidates.max(by: { pixelCount($0) < pixelCount($1) }) else { return false }

        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if videoFormat !== device.activeFormat {
                device.activeFormat = videoFormat
            }
            device.activeDepthDataFormat = depthFormat
            return true
        } catch {
            print("[PlateDepth] Не удалось выбрать формат глубины: \(error)")
            return false
        }
    }

    private static func float32(_ depthData: AVDepthData) -> AVDepthData {
        depthData.depthDataType == kCVPixelFormatType_DepthFloat32
            ? depthData
            : depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
    }

    /// Переводит снимок глубины в сетку для `PlateDepthAnalyzer`. Внутренние параметры камеры берутся
    /// из калибровки кадра; если её нет — из горизонтального угла обзора формата (главная точка в центре).
    static func grid(from depthData: AVDepthData, fieldOfViewDegrees: Double?) -> PlateDepthGrid? {
        let depth = float32(depthData)
        let map = depth.depthDataMap

        CVPixelBufferLockBaseAddress(map, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(map, .readOnly) }

        let width = CVPixelBufferGetWidth(map)
        let height = CVPixelBufferGetHeight(map)
        guard width >= 16, height >= 16, let base = CVPixelBufferGetBaseAddress(map) else { return nil }

        let rowStride = CVPixelBufferGetBytesPerRow(map) / MemoryLayout<Float32>.stride
        let pointer = base.assumingMemoryBound(to: Float32.self)
        var values = [Float](repeating: .nan, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                values[y * width + x] = pointer[y * rowStride + x]
            }
        }

        let fx: Double, fy: Double, cx: Double, cy: Double
        if let calibration = depth.cameraCalibrationData,
           calibration.intrinsicMatrixReferenceDimensions.width > 0,
           calibration.intrinsicMatrixReferenceDimensions.height > 0 {
            let reference = calibration.intrinsicMatrixReferenceDimensions
            let scaleX = Double(width) / Double(reference.width)
            let scaleY = Double(height) / Double(reference.height)
            let k = calibration.intrinsicMatrix
            fx = Double(k.columns.0.x) * scaleX
            fy = Double(k.columns.1.y) * scaleY
            cx = Double(k.columns.2.x) * scaleX
            cy = Double(k.columns.2.y) * scaleY
        } else if let fov = fieldOfViewDegrees, fov > 20, fov < 140 {
            let focal = (Double(width) / 2.0) / tan(fov * Double.pi / 360.0)
            fx = focal
            fy = focal
            cx = Double(width) / 2.0
            cy = Double(height) / 2.0
        } else {
            return nil
        }

        return PlateDepthGrid(
            width: width,
            height: height,
            meters: values,
            fx: fx,
            fy: fy,
            cx: cx,
            cy: cy,
            hasAbsoluteScale: depth.depthDataAccuracy == .absolute,
            isHighQuality: depth.depthDataQuality == .high
        )
    }

    /// Медианная глубина в центре кадра для живого HUD. Читает только маленькое окно буфера.
    static func centerDistance(of depthData: AVDepthData) -> Double? {
        guard depthData.depthDataAccuracy == .absolute else { return nil }
        let map = float32(depthData).depthDataMap

        CVPixelBufferLockBaseAddress(map, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(map, .readOnly) }

        let width = CVPixelBufferGetWidth(map)
        let height = CVPixelBufferGetHeight(map)
        guard width >= 16, height >= 16, let base = CVPixelBufferGetBaseAddress(map) else { return nil }

        let rowStride = CVPixelBufferGetBytesPerRow(map) / MemoryLayout<Float32>.stride
        let pointer = base.assumingMemoryBound(to: Float32.self)

        var samples: [Float] = []
        for y in Swift.stride(from: height * 2 / 5, to: height * 3 / 5, by: 2) {
            for x in Swift.stride(from: width * 2 / 5, to: width * 3 / 5, by: 2) {
                let z = pointer[y * rowStride + x]
                if z.isFinite && z > 0.10 && z < 3.0 { samples.append(z) }
            }
        }
        guard samples.count >= 10 else { return nil }
        samples.sort()
        return Double(samples[samples.count / 2])
    }
}

/// Получатель потока глубины. Отдельный объект без привязки к главному актору: колбэк приходит
/// на служебной очереди, и не нужно трогать состояние контроллера камеры вне главного потока.
final class LiveDepthSampler: NSObject, AVCaptureDepthDataOutputDelegate {
    var onSample: (@Sendable (Double?) -> Void)?
    private var lastSampleTime: CFTimeInterval = 0

    func depthDataOutput(
        _ output: AVCaptureDepthDataOutput,
        didOutput depthData: AVDepthData,
        timestamp: CMTime,
        connection: AVCaptureConnection
    ) {
        let now = CACurrentMediaTime()
        guard now - lastSampleTime >= 0.25 else { return }
        lastSampleTime = now
        onSample?(PlateDepthCapture.centerDistance(of: depthData))
    }
}
