import SwiftUI
import CoreMotion
import Combine

public class WorkoutTracker: ObservableObject {
    private let pedometer = CMPedometer()
    
    @Published public var isTracking = false
    @Published public var elapsedSeconds = 0
    @Published public var steps = 0
    @Published public var distance: Double = 0.0 // в метрах
    
    private var timer: AnyCancellable?
    private var startTime: Date?
    
    public init() {}
    
    public func startTracking() {
        guard !isTracking else { return }
        
        isTracking = true
        elapsedSeconds = 0
        steps = 0
        distance = 0.0
        startTime = Date()
        
        // Запуск таймера
        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.elapsedSeconds += 1
            }
        
        // Запуск отслеживания шагов и дистанции (CoreMotion)
        if CMPedometer.isStepCountingAvailable() {
            pedometer.startUpdates(from: Date()) { [weak self] data, error in
                guard let self = self, let data = data, error == nil else { return }
                DispatchQueue.main.async {
                    self.steps = data.numberOfSteps.intValue
                    if let dist = data.distance?.doubleValue {
                        self.distance = dist
                    }
                }
            }
        }
    }
    
    public func stopTracking() -> WorkoutSummary {
        guard isTracking else {
            return WorkoutSummary(duration: 0, steps: 0, distance: 0, startDate: Date(), endDate: Date())
        }
        
        isTracking = false
        timer?.cancel()
        timer = nil
        
        pedometer.stopUpdates()
        
        let summary = WorkoutSummary(
            duration: elapsedSeconds,
            steps: steps,
            distance: distance,
            startDate: startTime ?? Date(),
            endDate: Date()
        )
        
        startTime = nil
        return summary
    }
}

public struct WorkoutSummary {
    public let duration: Int // секунды
    public let steps: Int
    public let distance: Double // метры
    public let startDate: Date
    public let endDate: Date
}
