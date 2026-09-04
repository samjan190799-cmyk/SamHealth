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
    
    private var timer: AnyCancellable?
    private var startDate: Date?
    
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
            startTimer()
        }
    }
    
    // MARK: - Пауза и возобновление
    public func pauseWorkout() {
        guard isSessionActive, !isPaused else { return }
        session?.pause()
        isPaused = true
    }
    
    public func resumeWorkout() {
        guard isSessionActive, isPaused else { return }
        session?.resume()
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
                self.elapsedSeconds += 1
            }
    }
    
    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }
    
    public func mapWorkoutNameToActivityType(_ name: String) -> HKWorkoutActivityType {
        let n = name.lowercased()
        if n.contains("бег на улице") || n == "бег" {
            return .running
        } else if n.contains("дорожка") {
            return .running
        } else if n.contains("ходьба") {
            return .walking
        } else if n.contains("хайкинг") || n.contains("горы") {
            return .hiking
        } else if n.contains("велоспорт") || n == "велосипед" {
            return .cycling
        } else if n.contains("велотренажер") || n.contains("спиннинг") {
            return .cycling
        } else if n.contains("плавание") || n.contains("вода") || n.contains("бассейн") {
            return .swimming
        } else if n.contains("скакалка") {
            return .jumpRope
        } else if n.contains("гребн") || n.contains("гребля") {
            return .rowing
        } else if n.contains("эллипс") {
            return .elliptical
        } else if n.contains("степпер") {
            return .stairClimber
        } else if n.contains("силов") || n.contains("гантели") || n.contains("штанга") {
            return .traditionalStrengthTraining
        } else if n.contains("калистеника") || n.contains("турник") {
            return .crossTraining
        } else if n.contains("hiit") || n.contains("интервальн") {
            return .highIntensityIntervalTraining
        } else if n.contains("кроссфит") {
            return .crossTraining
        } else if n.contains("бокс") || n.contains("кикбоксинг") {
            return .boxing
        } else if n.contains("единоборства") || n.contains("мма") {
            return .martialArts
        } else if n.contains("йога") {
            return .yoga
        } else if n.contains("пилатес") {
            return .pilates
        } else if n.contains("растяжка") || n.contains("гибкость") {
            return .flexibility
        } else if n.contains("кор") || n.contains("планка") {
            return .coreTraining
        } else if n.contains("дыхан") {
            return .mindAndBody
        } else if n.contains("футбол") {
            return .soccer
        } else if n.contains("баскетбол") {
            return .basketball
        } else if n.contains("теннис") && !n.contains("настольный") && !n.contains("падел") {
            return .tennis
        } else if n.contains("падел") || n.contains("настольный") {
            return .tableTennis
        } else if n.contains("бадминтон") {
            return .badminton
        } else if n.contains("лыжи") || n.contains("сноуборд") {
            return .downhillSkiing
        } else if n.contains("отжимания") || n.contains("приседания") || n.contains("подтягивания") || n.contains("берпи") {
            return .traditionalStrengthTraining
        }
        return .functionalStrengthTraining
    }
    
    public func mapWorkoutNameToLocationType(_ name: String) -> HKWorkoutSessionLocationType {
        let n = name.lowercased()
        if n.contains("на улице") || n.contains("хайкинг") || n.contains("открытая вода") || n.contains("лыжи") || n.contains("сноуборд") {
            return .outdoor
        }
        if n == "бег" || n == "ходьба" || n == "велоспорт" || n == "футбол" {
            return .outdoor
        }
        return .indoor
    }
}

// MARK: - HKWorkoutSessionDelegate
extension WatchWorkoutSessionManager: HKWorkoutSessionDelegate {
    public func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        DispatchQueue.main.async {
            switch toState {
            case .running:
                self.isPaused = false
            case .paused:
                self.isPaused = true
            case .ended:
                self.isSessionActive = false
            default:
                break
            }
        }
    }
    
    public func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("[WatchWorkoutManager] HKWorkoutSession didFailWithError: \(error.localizedDescription)")
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate
extension WatchWorkoutSessionManager: HKLiveWorkoutBuilderDelegate {
    public func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            
            if quantityType == HKQuantityType.quantityType(forIdentifier: .heartRate) {
                let statistics = workoutBuilder.statistics(for: quantityType)
                if let bpm = statistics?.mostRecentQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) {
                    DispatchQueue.main.async {
                        if bpm >= 35 && bpm <= 230 {
                            self.currentHeartRate = Int(bpm)
                        }
                    }
                }
            } else if quantityType == HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
                let statistics = workoutBuilder.statistics(for: quantityType)
                if let cal = statistics?.sumQuantity()?.doubleValue(for: .kilocalorie()) {
                    DispatchQueue.main.async {
                        if cal > 0 {
                            self.activeCalories = cal
                        }
                    }
                }
            }
        }
    }
    
    public func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // События (пауза, сегмент)
    }
}
