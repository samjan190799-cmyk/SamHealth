import SwiftUI

@main
struct SamHealthWatchApp: App {
    @SceneBuilder var body: some Scene {
        WindowGroup {
            NavigationView {
                WorkoutWatchView()
            }
        }
    }
}
