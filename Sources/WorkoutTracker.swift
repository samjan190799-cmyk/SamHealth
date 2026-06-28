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
    @Published public var routeCoordinates: [CLLocationCoordinate2D] = []
    
    private var timer: AnyCancellable?
    private var startTime: Date?
    private var lastAcceleration: CMAcceleration?
    
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
        isPaused = true
        
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
        isPaused = false
        
        // Перезапускаем считывания со свежей даты
        startPedometerUpdates()
        if gpsTrackingEnabled {
            locationManager.startUpdatingLocation()
        }
    }
    
    private func tick() {
        guard !isPaused else { return }
        elapsedSeconds += 1
        
        #if targetEnvironment(simulator)
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
        isPaused = false
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
