import SwiftUI

@main
struct FormaApp: App {

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .task {
                    // Запрос разрешения App Tracking Transparency (ATT) от Meta
                    // 1 секунда задержки: Apple требует показывать диалог после
                    // полной загрузки интерфейса, не в момент запуска
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    await FormaMetaAdManager.shared.requestTrackingAuthorization()
                }
        }
    }
}
