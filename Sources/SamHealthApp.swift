import SwiftUI
import BackgroundTasks

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        // Регистрация фоновой задачи до завершения запуска приложения
        BackgroundStepManager.registerBackgroundTasks()
        return true
    }
}

@main
struct SamHealthApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var stepManager = BackgroundStepManager.shared
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(stepManager)
        }
        .onChange(of: scenePhase) { _, newPhase in
            stepManager.handleScenePhaseChange(to: newPhase)
        }
    }
}
