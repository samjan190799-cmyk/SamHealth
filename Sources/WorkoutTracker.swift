import SwiftUI
import CoreMotion
import Combine

public class WorkoutTracker: ObservableObject {
    private let pedometer = CMPedometer()
    private let motionManager = CMMotionManager()
    
    @Published public var isTracking = false
    @Published public var elapsedSeconds = 0
    @Published public var activeSeconds = 0
    @Published public var steps = 0
    @Published public var distance: Double = 0.0 // в метрах
    @Published public var isStationary = false
    
    private var timer: AnyCancellable?
    private var startTime: Date?
    private var lastAcceleration: CMAcceleration?
    
    public init() {}
    
    public func startTracking() {
        guard !isTracking else { return }
        
        isTracking = true
        elapsedSeconds = 0
        activeSeconds = 0
        steps = 0
        distance = 0.0
        isStationary = false
        startTime = Date()
        lastAcceleration = nil
        
        // Запуск таймера
        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
        
        // Запуск отслеживания шагов и дистанции (CoreMotion)
        if CMPedometer.isStepCountingAvailable() {
            pedometer.startUpdates(from: Date()) { [weak self] data, error in
                guard let self = self, let data = data, error == nil else { return }
                DispatchQueue.main.async {
                    // Если телефон неподвижен, не обновляем шаги и дистанцию
                    if !self.isStationary {
                        self.steps = data.numberOfSteps.intValue
                        if let dist = data.distance?.doubleValue {
                            self.distance = dist
                        }
                    }
                }
            }
        }
        
        // Запуск акселерометра
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 1.0
            motionManager.startAccelerometerUpdates()
        }
    }
    
    private func tick() {
        elapsedSeconds += 1
        
        #if targetEnvironment(simulator)
        // В симуляторе считаем, что движение есть всегда
        isStationary = false
        activeSeconds += 1
        #else
        if motionManager.isAccelerometerAvailable, let accelData = motionManager.accelerometerData {
            let accel = accelData.acceleration
            if let last = lastAcceleration {
                let deltaX = accel.x - last.x
                let deltaY = accel.y - last.y
                let deltaZ = accel.z - last.z
                let movement = sqrt(deltaX * deltaX + deltaY * deltaY + deltaZ * deltaZ)
                
                // Чувствительность к движению в g
                if movement > 0.05 {
                    isStationary = false
                    activeSeconds += 1
                } else {
                    isStationary = true
                }
            } else {
                isStationary = false
                activeSeconds += 1
            }
            lastAcceleration = accel
        } else {
            // Если датчик недоступен, считаем активным
            isStationary = false
            activeSeconds += 1
        }
        #endif
    }
    
    public func stopTracking() -> WorkoutSummary {
        guard isTracking else {
            return WorkoutSummary(duration: 0, activeDuration: 0, steps: 0, distance: 0, startDate: Date(), endDate: Date())
        }
        
        isTracking = false
        timer?.cancel()
        timer = nil
        
        pedometer.stopUpdates()
        motionManager.stopAccelerometerUpdates()
        
        let summary = WorkoutSummary(
            duration: elapsedSeconds,
            activeDuration: activeSeconds,
            steps: steps,
            distance: distance,
            startDate: startTime ?? Date(),
            endDate: Date()
        )
        
        startTime = nil
        lastAcceleration = nil
        return summary
    }
}

public struct WorkoutSummary {
    public let duration: Int // секунды
    public let activeDuration: Int // секунды
    public let steps: Int
    public let distance: Double // метры
    public let startDate: Date
    public let endDate: Date
}
