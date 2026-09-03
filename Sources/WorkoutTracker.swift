import SwiftUI
import CoreMotion
import Combine
import CoreLocation
import MapKit

public class WorkoutTracker: NSObject, ObservableObject {
    private let pedometer = CMPedometer()
    private let motionManager = CMMotionManager()
    private let locationManager = CLLocationManager()
    
    @Published public var isTracking = false
    @Published public var isPaused = false
    @Published public var elapsedSeconds = 0
    @Published public var activeSeconds = 0
    @Published public var steps = 0
    @Published public var distance: Double = 0.0 // в метрах
    @Published public var isStationary = false
    @Published public var isAutoPauseEnabled: Bool = true
    @Published public var isAutoPaused: Bool = false
    @Published public var routeCoordinates: [CLLocationCoordinate2D] = []
    
    private var timer: AnyCancellable?
    private var startTime: Date?
    private var lastAcceleration: CMAcceleration?
    private var stationaryCount: Int = 0
    
    // Переменные для накопления шагов/дистанции при паузе
    private var accumulatedSteps = 0
    private var accumulatedDistance = 0.0
    private var lastStoredLocation: CLLocation?
    private var gpsTrackingEnabled = false
    
    public override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 2.0 // Обновлять при перемещении на 2 метра
    }
    
    public func startTracking(gpsTrackingEnabled: Bool = false) {
        guard !isTracking else { return }
        
        isTracking = true
        isPaused = false
        isAutoPaused = false
        stationaryCount = 0
        elapsedSeconds = 0
        activeSeconds = 0
        steps = 0
        distance = 0.0
        isStationary = false
        routeCoordinates = []
        accumulatedSteps = 0
        accumulatedDistance = 0.0
        lastStoredLocation = nil
        self.gpsTrackingEnabled = gpsTrackingEnabled
        startTime = Date()
        lastAcceleration = nil
        
        // Запуск таймера
        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
        
        // Запуск шагомера
        startPedometerUpdates()
        
        // Запуск GPS
        if gpsTrackingEnabled {
            locationManager.requestWhenInUseAuthorization()
            locationManager.startUpdatingLocation()
        }
        
        // Запуск акселерометра
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 1.0
            motionManager.startAccelerometerUpdates()
        }
    }
    
    private func startPedometerUpdates() {
        guard CMPedometer.isStepCountingAvailable() else { return }
        pedometer.startUpdates(from: Date()) { [weak self] data, error in
            guard let self = self, let data = data, error == nil else { return }
            DispatchQueue.main.async {
                guard !self.isPaused else { return }
                if !self.isStationary {
                    self.steps = self.accumulatedSteps + data.numberOfSteps.intValue
                    // Если включен GPS, мы не берем расстояние из шагомера
                    if !self.gpsTrackingEnabled, let dist = data.distance?.doubleValue {
                        self.distance = self.accumulatedDistance + dist
                    }
                }
            }
        }
    }
    
    public func pauseTracking() {
        guard isTracking && !isPaused else { return }
        isAutoPaused = false
        isPaused = true
        stationaryCount = 0
        
        // Накапливаем шаги и дистанцию от текущего отрезка
        accumulatedSteps = steps
        if !gpsTrackingEnabled {
            accumulatedDistance = distance
        }
        
        // Останавливаем обновления
        pedometer.stopUpdates()
        if gpsTrackingEnabled {
            locationManager.stopUpdatingLocation()
        }
        lastStoredLocation = nil
    }
    
    public func resumeTracking() {
        guard isTracking && isPaused else { return }
        isAutoPaused = false
        isPaused = false
        stationaryCount = 0
        
        // Перезапускаем считывания со свежей даты
        startPedometerUpdates()
        if gpsTrackingEnabled {
            locationManager.startUpdatingLocation()
        }
    }
    
    public func triggerAutoPause() {
        guard isTracking && !isPaused && !isAutoPaused else { return }
        isAutoPaused = true
        isPaused = true
        HapticManager.shared.notification(.warning)
        accumulatedSteps = steps
        if !gpsTrackingEnabled {
            accumulatedDistance = distance
        }
        pedometer.stopUpdates()
        if gpsTrackingEnabled {
            locationManager.stopUpdatingLocation()
        }
        lastStoredLocation = nil
    }
    
    public func triggerAutoResume() {
        guard isTracking && isAutoPaused else { return }
        isAutoPaused = false
        isPaused = false
        stationaryCount = 0
        HapticManager.shared.notification(.success)
        startPedometerUpdates()
        if gpsTrackingEnabled {
            locationManager.startUpdatingLocation()
        }
    }
    
    private func tick() {
        // Если ручная пауза — ничего не тикает
        guard isTracking && (!isPaused || isAutoPaused) else { return }
        
        #if targetEnvironment(simulator)
        isStationary = false
        if isAutoPaused {
            triggerAutoResume()
        }
        elapsedSeconds += 1
        activeSeconds += 1
        #else
        if motionManager.isAccelerometerAvailable, let accelData = motionManager.accelerometerData {
            let accel = accelData.acceleration
            if let last = lastAcceleration {
                let deltaX = accel.x - last.x
                let deltaY = accel.y - last.y
                let deltaZ = accel.z - last.z
                let movement = sqrt(deltaX * deltaX + deltaY * deltaY + deltaZ * deltaZ)
                
                if movement > 0.05 {
                    isStationary = false
                } else {
                    isStationary = true
                }
            } else {
                isStationary = false
            }
            lastAcceleration = accel
        } else {
            isStationary = false
        }
        
        // Умная авто-пауза при остановке
        if isAutoPauseEnabled {
            if isStationary {
                stationaryCount += 1
                if stationaryCount >= 3 && !isAutoPaused {
                    triggerAutoPause()
                    return
                }
            } else {
                stationaryCount = 0
                if isAutoPaused {
                    triggerAutoResume()
                }
            }
        }
        
        // Если авто-пауза активна, таймер времени не накручиваем
        guard !isPaused else { return }
        
        elapsedSeconds += 1
        if !isStationary {
            activeSeconds += 1
        }
        #endif
    }
    
    public func stopTracking() -> WorkoutSummary {
        guard isTracking else {
            return WorkoutSummary(duration: 0, activeDuration: 0, steps: 0, distance: 0, startDate: Date(), endDate: Date())
        }
        
        isTracking = false
        isPaused = false
        isAutoPaused = false
        stationaryCount = 0
        timer?.cancel()
        timer = nil
        
        pedometer.stopUpdates()
        if gpsTrackingEnabled {
            locationManager.stopUpdatingLocation()
        }
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
        lastStoredLocation = nil
        routeCoordinates = []
        return summary
    }
}

extension WorkoutTracker: CLLocationManagerDelegate {
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isTracking && !isPaused && gpsTrackingEnabled else { return }
        
        for location in locations {
            // Фильтруем координаты с плохой точностью (> 20 метров)
            guard location.horizontalAccuracy >= 0 && location.horizontalAccuracy < 20 else { continue }
            
            let coordinate = location.coordinate
            
            DispatchQueue.main.async {
                self.routeCoordinates.append(coordinate)
            }
            
            if let last = lastStoredLocation {
                let delta = location.distance(from: last)
                // Игнорируем выбросы GPS
                if delta < 50.0 {
                    DispatchQueue.main.async {
                        self.distance += delta
                    }
                }
            }
            lastStoredLocation = location
        }
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
