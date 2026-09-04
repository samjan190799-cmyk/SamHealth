import Foundation
import WatchConnectivity
import Combine

public class WatchConnectivityManager: NSObject, WCSessionDelegate, ObservableObject {
    public static let shared = WatchConnectivityManager()
    
    @Published public var activeWorkoutName: String? = nil
    @Published public var activeExercises: [[String: Any]] = []
    
    // Активное состояние тренировки (синхронизированное с телефона)
    @Published public var elapsedSeconds = 0
    @Published public var calories = 0.0
    @Published public var currentExerciseName = ""
    @Published public var currentSet = 0
    @Published public var totalSets = 0
    @Published public var isWorkoutActive = false
    @Published public var reps = 0
    @Published public var isTimeBased = false
    @Published public var isResting = false
    @Published public var restSecondsRemaining = 0
    @Published public var heartRate = 0
    
    private override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("Watch WCSession activated with state: \(activationState.rawValue)")
    }
    
    public func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            self.handleMessage(message)
        }
    }
    
    public func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        DispatchQueue.main.async {
            self.handleMessage(message)
            replyHandler(["status": "success"])
        }
    }
    
    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        DispatchQueue.main.async {
            self.handleMessage(userInfo)
        }
    }
    
    public func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        DispatchQueue.main.async {
            self.handleMessage(applicationContext)
        }
    }
    
    private func handleMessage(_ message: [String: Any]) {
        guard let command = message["command"] as? String else { return }
        
        switch command {
        case "sync_workout":
            self.activeWorkoutName = message["name"] as? String
            self.activeExercises = (message["exercises"] as? [[String: Any]]) ?? []
            self.isWorkoutActive = true
            self.elapsedSeconds = 0
            self.calories = 0
            
            // Запуск фоновой тренировочной сессии на часах
            Task { @MainActor in
                let wName = self.activeWorkoutName ?? "Тренировка"
                WatchWorkoutSessionManager.shared.startWorkout(name: wName)
            }
            
        case "sync_active_state":
            self.elapsedSeconds = (message["elapsedSeconds"] as? Int) ?? 0
            self.calories = (message["calories"] as? Double) ?? 0.0
            self.currentExerciseName = (message["exerciseName"] as? String) ?? ""
            self.currentSet = (message["currentSet"] as? Int) ?? 0
            self.totalSets = (message["totalSets"] as? Int) ?? 0
            self.reps = (message["reps"] as? Int) ?? 0
            self.isTimeBased = (message["isTimeBased"] as? Bool) ?? false
            self.isResting = (message["isResting"] as? Bool) ?? false
            self.restSecondsRemaining = (message["restSecondsRemaining"] as? Int) ?? 0
            if let hr = message["heartRate"] as? Int, hr > 0 {
                self.heartRate = hr
            }
            self.isWorkoutActive = true
            
            // Если сессия еще не активна, запускаем ее для поддержания работы экрана и пульсометра
            Task { @MainActor in
                if !WatchWorkoutSessionManager.shared.isSessionActive {
                    let wName = self.activeWorkoutName ?? (self.currentExerciseName.isEmpty ? "Тренировка" : self.currentExerciseName)
                    WatchWorkoutSessionManager.shared.startWorkout(name: wName)
                }
            }
            
        case "finish_workout":
            self.isWorkoutActive = false
            self.activeWorkoutName = nil
            self.activeExercises = []
            Task { @MainActor in
                WatchWorkoutSessionManager.shared.endWorkout { _, _, _ in }
            }
            
        default:
            break
        }
    }
    
    // MARK: - Отправка команд на телефон
    public func sendPauseToPhone() {
        sendMessageToPhone(["action": "pause"])
        Task { @MainActor in
            WatchWorkoutSessionManager.shared.pauseWorkout()
        }
    }
    
    public func sendResumeToPhone() {
        sendMessageToPhone(["action": "resume"])
        Task { @MainActor in
            WatchWorkoutSessionManager.shared.resumeWorkout()
        }
    }
    
    public func sendFinishToPhone() {
        sendMessageToPhone(["action": "finish"])
        self.isWorkoutActive = false
        Task { @MainActor in
            WatchWorkoutSessionManager.shared.endWorkout { _, _, _ in }
        }
    }
    
    public func sendCompleteSetToPhone() {
        sendMessageToPhone(["action": "complete_set"])
    }
    
    public func sendSkipRestToPhone() {
        sendMessageToPhone(["action": "skip_rest"])
    }
    
    public func sendHeartRateToPhone(_ bpm: Int) {
        guard bpm > 0 else { return }
        sendMessageToPhone(["action": "update_heart_rate", "bpm": bpm])
    }
    
    public func sendStandaloneWorkoutToPhone(name: String, durationSeconds: Int, calories: Double, startDate: Date, endDate: Date) {
        let payload: [String: Any] = [
            "action": "save_standalone_workout",
            "name": name,
            "duration": durationSeconds,
            "calories": calories,
            "startDate": startDate.timeIntervalSince1970,
            "endDate": endDate.timeIntervalSince1970
        ]
        guard WCSession.default.activationState == .activated else { return }
        
        // 1. Гарантированная передача через transferUserInfo (работает даже если телефон спит)
        WCSession.default.transferUserInfo(payload)
        
        // 2. Мгновенная отправка, если телефон на связи
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        }
    }
    
    private func sendMessageToPhone(_ message: [String: Any]) {
        guard WCSession.default.activationState == .activated else { return }
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("Error sending message to phone: \(error.localizedDescription)")
        }
    }
}
