import Foundation
import HealthKit
import Combine
import WatchKit

@MainActor
public class WatchWorkoutSessionManager: NSObject, ObservableObject {
    public static let shared = WatchWorkoutSessionManager()
    
    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    
    @Published public var isSessionActive = false
    @Published public var isPaused = false
    @Published public var currentHeartRate: Int = 0
    @Published public var activeCalories: Double = 0.0
    @Published public var elapsedSeconds: Int = 0
    
    // Метрики для плавания
    @Published public var swimmingDistance: Double = 0.0
    @Published public var swimmingStrokes: Int = 0
    
    private var timer: AnyCancellable?
    private var startDate: Date?
    /// Время тренировки считается по часам: если приложение было приостановлено (опущенное запястье, экран),
    /// пропущенные секунды засчитываются при следующем тике, а не теряются.
    private var clock = WorkoutClock()
    
    private override init() {
        super.init()
    }
    
    // MARK: - Запрос разрешений
    public func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false)
            return
        }
        
        var readTypes: Set<HKObjectType> = []
        var shareTypes: Set<HKSampleType> = []
        
        if let hr = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            readTypes.insert(hr)
        }
        if let cal = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            readTypes.insert(cal)
            shareTypes.insert(cal)
        }
        if let dist = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            readTypes.insert(dist)
            shareTypes.insert(dist)
        }
        if let swimDist = HKQuantityType.quantityType(forIdentifier: .distanceSwimming) {
            readTypes.insert(swimDist)
            shareTypes.insert(swimDist)
        }
        if let strokes = HKQuantityType.quantityType(forIdentifier: .swimmingStrokeCount) {
            readTypes.insert(strokes)
            shareTypes.insert(strokes)
        }
        
        let workoutType = HKWorkoutType.workoutType()
        readTypes.insert(workoutType)
        shareTypes.insert(workoutType)
        
        healthStore.requestAuthorization(toShare: shareTypes, read: readTypes) { success, _ in
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }
    
    // MARK: - Запуск тренировочной сессии на часах
    public func startWorkout(name: String) {
        guard !isSessionActive else { return }
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = mapWorkoutNameToActivityType(name)
        configuration.locationType = mapWorkoutNameToLocationType(name)
        if let swimmingLocation = WatchWorkoutMapping.swimmingLocation(for: name) {
            configuration.swimmingLocationType = swimmingLocation
            if swimmingLocation == .pool {
                configuration.lapLength = HKQuantity(unit: .meter(), doubleValue: WatchWorkoutMapping.defaultPoolLengthMeters)
            }
        }
        
        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            
            self.session = session
            self.builder = builder
            
            session.delegate = self
            builder.delegate = self
            
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            
            let now = Date()
            self.startDate = now
            self.clock.start(at: now)
            self.isSessionActive = true
            self.isPaused = false
            self.elapsedSeconds = 0
            self.activeCalories = 0.0
            self.currentHeartRate = 0
            
            session.startActivity(with: now)
            builder.beginCollection(withStart: now) { success, error in
                if let error = error {
                    print("[WatchWorkoutManager] Error beginning collection: \(error.localizedDescription)")
                }
            }
            
            startTimer()
            print("[WatchWorkoutManager] HKWorkoutSession успешно запущена: \(name)")
        } catch {
            print("[WatchWorkoutManager] Ошибка запуска HKWorkoutSession: \(error.localizedDescription)")
            // Фолбек: просто активируем локальный таймер
            self.isSessionActive = true
            self.startDate = Date()
            self.clock.start(at: Date())
            startTimer()
        }
    }
    
    // MARK: - Пауза и возобновление
    public func pauseWorkout() {
        guard isSessionActive, !isPaused else { return }
        session?.pause()
        clock.pause(at: Date())
        elapsedSeconds = clock.elapsedSeconds
        isPaused = true
    }
    
    public func resumeWorkout() {
        guard isSessionActive, isPaused else { return }
        session?.resume()
        clock.resume(at: Date())
        isPaused = false
    }
    
    // MARK: - Завершение тренировки
    public func endWorkout(completion: @escaping (HKWorkout?, Double, Int) -> Void) {
        guard isSessionActive else {
            completion(nil, activeCalories, elapsedSeconds)
            return
        }
        
        stopTimer()
        let now = Date()
        clock.credit(at: now)
        elapsedSeconds = clock.elapsedSeconds
        let finalCalories = self.activeCalories
        let finalSeconds = self.elapsedSeconds
        
        self.isSessionActive = false
        self.isPaused = false
        
        if let session = self.session, let builder = self.builder {
            session.end()
            builder.endCollection(withEnd: now) { [weak self] success, error in
                builder.finishWorkout { workout, error in
                    DispatchQueue.main.async {
                        self?.session = nil
                        self?.builder = nil
                        completion(workout, finalCalories, finalSeconds)
                    }
                }
            }
        } else {
            completion(nil, finalCalories, finalSeconds)
        }
    }
    
    // MARK: - Таймер
    private func startTimer() {
        timer?.cancel()
        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.isSessionActive, !self.isPaused else { return }
                self.clock.credit(at: Date())
                self.elapsedSeconds = self.clock.elapsedSeconds
            }
    }
    
    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }
    
    public func mapWorkoutNameToActivityType(_ name: String) -> HKWorkoutActivityType {
        WatchWorkoutMapping.activityType(for: name)
    }

    public func mapWorkoutNameToLocationType(_ name: String) -> HKWorkoutSessionLocationType {
        WatchWorkoutMapping.locationType(for: name)
    }
}

// MARK: - HKWorkoutSessionDelegate
extension WatchWorkoutSessionManager: HKWorkoutSessionDelegate {
    nonisolated public func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        Task { @MainActor in
            switch toState {
            case .running:
                self.clock.resume(at: date)
                self.isPaused = false
            case .paused:
                self.clock.pause(at: date)
                self.isPaused = true
            case .ended:
                self.isSessionActive = false
            default:
                break
            }
        }
    }
    
    nonisolated public func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("[WatchWorkoutManager] HKWorkoutSession didFailWithError: \(error.localizedDescription)")
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate
extension WatchWorkoutSessionManager: HKLiveWorkoutBuilderDelegate {
    nonisolated public func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            
            if quantityType == HKQuantityType.quantityType(forIdentifier: .heartRate) {
                let statistics = workoutBuilder.statistics(for: quantityType)
                if let bpm = statistics?.mostRecentQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) {
                    Task { @MainActor in
                        if bpm >= 35 && bpm <= 230 {
                            self.currentHeartRate = Int(bpm)
                        }
                    }
                }
            } else if quantityType == HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
                let statistics = workoutBuilder.statistics(for: quantityType)
                if let cal = statistics?.sumQuantity()?.doubleValue(for: .kilocalorie()) {
                    Task { @MainActor in
                        if cal > 0 {
                            self.activeCalories = cal
                        }
                    }
                }
            } else if quantityType == HKQuantityType.quantityType(forIdentifier: .distanceSwimming) {
                let statistics = workoutBuilder.statistics(for: quantityType)
                if let dist = statistics?.sumQuantity()?.doubleValue(for: HKUnit.meter()) {
                    Task { @MainActor in
                        self.swimmingDistance = dist
                    }
                }
            } else if quantityType == HKQuantityType.quantityType(forIdentifier: .swimmingStrokeCount) {
                let statistics = workoutBuilder.statistics(for: quantityType)
                if let strokes = statistics?.sumQuantity()?.doubleValue(for: HKUnit.count()) {
                    Task { @MainActor in
                        self.swimmingStrokes = Int(strokes)
                    }
                }
            }
        }
    }
    
    nonisolated public func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // События (пауза, сегмент)
    }
}
