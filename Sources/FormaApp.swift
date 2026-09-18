import SwiftUI

@main
struct FormaApp: App {

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .task {
                    // Запрос разрешения App Tracking Transparency (ATT) для Яндекс и AppLovin
                    // Задержка 1.2 секунды: Apple требует показывать диалог после
                    // полной загрузки главного экрана, а не в момент холодного запуска
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                    await FormaAdManager.shared.requestTrackingAuthorizationAndInitialize()
                }
        }
    }
}
