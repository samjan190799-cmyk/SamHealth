import Foundation
import CoreMotion
import SwiftUI
import Combine

/// Менеджер аппаратного отслеживания наклона устройства через CoreMotion
@MainActor
public final class DeviceTiltManager: ObservableObject {
    public static let shared = DeviceTiltManager()
    
    private let motionManager = CMMotionManager()
    
    /// Наклон по горизонтали влево/вправо: от -1.0 (сильный наклон влево) до +1.0 (сильный наклон вправо)
    @Published public var tiltX: Double = 0.0
    
    /// Наклон по вертикали вперед/назад: от -1.0 (на себя) до +1.0 (от себя)
    @Published public var tiltY: Double = 0.0
    
    /// Доступен ли аппаратный гироскоп/акселерометр
    @Published public var isMotionAvailable: Bool = false
    
    /// Активен ли мониторинг
    @Published public var isMonitoring: Bool = false
    
    private var subscribersCount: Int = 0
    
    private init() {
        self.isMotionAvailable = motionManager.isDeviceMotionAvailable
    }
    
    /// Запуск отслеживания наклона с плавным демпфированием
    public func startMonitoring() {
        subscribersCount += 1
        guard subscribersCount == 1 else { return }
        
        guard motionManager.isDeviceMotionAvailable else {
            isMotionAvailable = false
            return
        }
        
        isMotionAvailable = true
        isMonitoring = true
        
        motionManager.deviceMotionUpdateInterval = 0.033 // ~30 FPS оптимально для CoreMotion и сбережения батареи
        motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            
            // attitude.roll: поворот вокруг продольной оси (-pi ... pi)
            // gravity.x: проекция силы тяжести по оси X (-1.0 ... 1.0)
            let rawRoll = motion.attitude.roll
            let gravityX = motion.gravity.x
            
            // Комбинируем roll и gravity для мгновенной реакции на наклон в руках
            let targetTiltX: Double
            if abs(gravityX) > 0.05 {
                targetTiltX = (gravityX * 1.2).clamped(to: -1.2...1.2)
            } else {
                targetTiltX = (rawRoll / (.pi / 3.0)).clamped(to: -1.2...1.2)
            }
            
            let targetTiltY = (motion.gravity.y * 1.2).clamped(to: -1.2...1.2)
            
            // Плавный экспоненциальный фильтр (LERP) без тяжелых солверов withAnimation
            let newX = self.tiltX * 0.75 + targetTiltX * 0.25
            let newY = self.tiltY * 0.75 + targetTiltY * 0.25
            
            // Порог нечувствительности (Deadband): не дергаем SwiftUI если телефон неподвижен
            if abs(newX - self.tiltX) > 0.006 || abs(newY - self.tiltY) > 0.006 {
                self.tiltX = newX
                self.tiltY = newY
            }
        }
    }
    
    /// Остановка для сбережения аккумулятора при сворачивании или уходе с вкладки
    public func stopMonitoring() {
        subscribersCount = max(0, subscribersCount - 1)
        guard subscribersCount == 0 else { return }
        
        motionManager.stopDeviceMotionUpdates()
        isMonitoring = false
        self.tiltX = 0.0
        self.tiltY = 0.0
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
