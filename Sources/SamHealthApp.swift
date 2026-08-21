import SwiftUI

@main
struct SamHealthApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var stepManager = BackgroundStepManager.shared
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(healthKitManager)
                .environmentObject(stepManager)
        }
        .onChange(of: scenePhase) { _, newPhase in
            stepManager.handleScenePhaseChange(to: newPhase)
        }
    }
}
