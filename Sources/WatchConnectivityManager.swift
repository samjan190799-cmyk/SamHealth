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
    
    public func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        DispatchQueue.main.async {
            self.receivedMessages.append(message)
            self.onMessageReceived?(message)
            replyHandler(["status": "success"])
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
        
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("Error sending workout to watch: \(error.localizedDescription)")
        }
    }
    
    // Синхронизация статуса активной тренировки (время, калории, текущее упражнение)
    public func sendActiveStateToWatch(elapsedSeconds: Int, calories: Double, exerciseName: String, currentSet: Int, totalSets: Int) {
        guard WCSession.default.activationState == .activated else { return }
        let message: [String: Any] = [
            "command": "sync_active_state",
            "elapsedSeconds": elapsedSeconds,
            "calories": calories,
            "exerciseName": exerciseName,
            "currentSet": currentSet,
            "totalSets": totalSets
        ]
        WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: nil)
    }
    
    // Отправка команды окончания тренировки
    public func sendFinishToWatch() {
        guard WCSession.default.activationState == .activated else { return }
        WCSession.default.sendMessage(["command": "finish_workout"], replyHandler: nil, errorHandler: nil)
    }
}
