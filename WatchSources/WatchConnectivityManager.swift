import Foundation
import WatchConnectivity
import Combine
import HealthKit

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
    
    private override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("Watch WCSession activated")
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
    
    private func handleMessage(_ message: [String: Any]) {
        guard let command = message["command"] as? String else { return }
        
        switch command {
        case "sync_workout":
            self.activeWorkoutName = message["name"] as? String
            self.activeExercises = (message["exercises"] as? [[String: Any]]) ?? []
            self.isWorkoutActive = true
            self.elapsedSeconds = 0
            self.calories = 0
            
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
            self.isWorkoutActive = true
            
        case "finish_workout":
            self.isWorkoutActive = false
            self.activeWorkoutName = nil
            self.activeExercises = []
            
        default:
            break
        }
    }
    
    // Отправка команд на телефон
    public func sendPauseToPhone() {
        sendMessageToPhone(["action": "pause"])
    }
    
    public func sendResumeToPhone() {
        sendMessageToPhone(["action": "resume"])
    }
    
    public func sendFinishToPhone() {
        sendMessageToPhone(["action": "finish"])
        self.isWorkoutActive = false
    }
    
    public func sendCompleteSetToPhone() {
        sendMessageToPhone(["action": "complete_set"])
    }
    
    public func sendSkipRestToPhone() {
        sendMessageToPhone(["action": "skip_rest"])
    }
    
    private func sendMessageToPhone(_ message: [String: Any]) {
        guard WCSession.default.activationState == .activated else { return }
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("Error sending message to phone: \(error.localizedDescription)")
        }
    }
}
