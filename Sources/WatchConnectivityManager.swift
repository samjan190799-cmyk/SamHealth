import Foundation
import WatchConnectivity
import Combine

public class WatchConnectivityManager: NSObject, WCSessionDelegate, ObservableObject {
    public static let shared = WatchConnectivityManager()
    
    @Published public var isWatchAppInstalled = false
    @Published public var isReachable = false
    @Published public var receivedMessages: [[String: Any]] = []
    
    // Передаем сюда события об активной тренировке из iOS-приложения
    public var onMessageReceived: (([String: Any]) -> Void)?
    
    private override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isReachable = session.isReachable
        }
    }
    
    #if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) {}
    public func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    #endif
    
    public func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }
    
    public func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            self.receivedMessages.append(message)
            self.handleIncomingPayload(message)
            self.onMessageReceived?(message)
        }
    }
    
    public func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        DispatchQueue.main.async {
            self.receivedMessages.append(message)
            self.handleIncomingPayload(message)
            self.onMessageReceived?(message)
            replyHandler(["status": "success"])
        }
    }
    
    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        DispatchQueue.main.async {
            self.receivedMessages.append(userInfo)
            self.handleIncomingPayload(userInfo)
            self.onMessageReceived?(userInfo)
        }
    }
    
    private func handleIncomingPayload(_ payload: [String: Any]) {
        guard let action = payload["action"] as? String else { return }
        
        if action == "save_standalone_workout" {
            let name = (payload["name"] as? String) ?? "Тренировка"
            let durationSeconds = (payload["duration"] as? Int) ?? 0
            let calories = (payload["calories"] as? Double) ?? 0.0
            
            let start: Date
            if let startSec = payload["startDate"] as? TimeInterval {
                start = Date(timeIntervalSince1970: startSec)
            } else {
                start = Date().addingTimeInterval(-Double(max(1, durationSeconds)))
            }
            
            let end: Date
            if let endSec = payload["endDate"] as? TimeInterval {
                end = Date(timeIntervalSince1970: endSec)
            } else {
                end = Date()
            }
            
            // Сохраняем тренировку с дедупликацией в HealthKit и историю
            Task { @MainActor in
                HealthKitManager.shared.saveWorkout(
                    activityType: name,
                    startDate: start,
                    endDate: end,
                    activeEnergyBurned: calories,
                    distance: 0.0
                )
                print("[WatchConnectivity] Автономная тренировка с Apple Watch успешно сохранена на iPhone: \(name), \(durationSeconds) сек, \(calories) ккал")
            }
        } else if action == "update_heart_rate" {
            if let bpm = payload["bpm"] as? Int, bpm > 0 {
                Task { @MainActor in
                    HealthKitManager.shared.latestHeartRate = Double(bpm)
                }
            }
        }
    }
    
    // Отправка программы тренировок на часы
    public func sendWorkoutToWatch(name: String, exercises: [[String: Any]]) {
        guard WCSession.default.activationState == .activated else { return }
        let message: [String: Any] = [
            "command": "sync_workout",
            "name": name,
            "exercises": exercises
        ]
        
        WCSession.default.sendMessage(message, replyHandler: nil) { _ in }
        try? WCSession.default.updateApplicationContext(message)
    }
    
    // Синхронизация статуса активной тренировки (время, калории, пульс, текущее упражнение, повторения, фаза отдыха)
    public func sendActiveStateToWatch(elapsedSeconds: Int, calories: Double, heartRate: Int = 0, exerciseName: String, currentSet: Int, totalSets: Int, reps: Int, isTimeBased: Bool, isResting: Bool, restSecondsRemaining: Int) {
        guard WCSession.default.activationState == .activated else { return }
        let message: [String: Any] = [
            "command": "sync_active_state",
            "elapsedSeconds": elapsedSeconds,
            "calories": calories,
            "heartRate": heartRate,
            "exerciseName": exerciseName,
            "currentSet": currentSet,
            "totalSets": totalSets,
            "reps": reps,
            "isTimeBased": isTimeBased,
            "isResting": isResting,
            "restSecondsRemaining": restSecondsRemaining
        ]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: nil)
        } else if elapsedSeconds % 5 == 0 {
            try? WCSession.default.updateApplicationContext(message)
        }
    }
    
    // Отправка команды окончания тренировки
    public func sendFinishToWatch() {
        guard WCSession.default.activationState == .activated else { return }
        let message = ["command": "finish_workout"]
        WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: nil)
        try? WCSession.default.updateApplicationContext(message)
    }
}
