import SwiftUI

@main
struct FormaWatchApp: App {
    @SceneBuilder var body: some Scene {
        WindowGroup {
            NavigationView {
                WorkoutWatchView()
            }
        }
    }
}
