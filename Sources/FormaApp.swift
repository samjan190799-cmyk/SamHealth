import SwiftUI

/// Локаль SwiftUI берётся из языка приложения, а не из языка телефона: иначе оси графиков и даты
/// выходят на английском («Aug 26») в русском интерфейсе.
private struct AppLocaleRoot<Content: View>: View {
    @AppStorage("app_language") private var appLanguage = "ru"
    let content: Content

    var body: some View {
        content.environment(\.locale, Locale(identifier: appLanguage))
    }
}

@main
struct FormaApp: App {

    init() {
        // iOS запускает приложение в фоне ради доставки новых данных HealthKit (например, шагов) без интерфейса.
        // Раньше менеджеры создавались только вместе с главным экраном, которого в фоновом запуске нет,
        // и события шагов никто не принимал: уведомления о целях приходили лишь после открытия приложения.
        // Инициализация здесь регистрирует наблюдатели при КАЖДОМ запуске процесса.
        MainActor.assumeIsolated {
            _ = HealthKitManager.shared
            _ = BackgroundStepManager.shared
        }
    }

    var body: some Scene {
        WindowGroup {
            AppLocaleRoot(content: MainTabView())
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
