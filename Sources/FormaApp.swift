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
            rootView
        }
    }

    @ViewBuilder
    private var rootView: some View {
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            // Юнит-тесты запускают приложение как хост: интерфейс, реклама и системные запросы не нужны
            Color.clear
        } else if let category = Self.demoAchievementCategory {
            // Режим превью для CI (scripts/ios_achievement_preview.sh):
            // `-FormaScreenshotScene achievement:<steps|workouts|water|streaks|master>` показывает
            // только анимацию награды, без онбординга и системных окон. В Release не попадает.
            AchievementDemoHost(category: category)
        } else {
            mainContent
        }
        #else
        mainContent
        #endif
    }

    private var mainContent: some View {
        AppLocaleRoot(content: MainTabView())
            .task {
                #if DEBUG
                // В режиме скриншотов системный диалог ATT перекрыл бы интерфейс
                if FormaScreenshotMode.isActive { return }
                #endif
                // Новичку сначала показывается онбординг: системные запросы не должны накладываться на него
                while !FormaOnboarding.isDone {
                    do {
                        try await Task.sleep(nanoseconds: 500_000_000)
                    } catch {
                        return
                    }
                }
                // Запрос разрешения App Tracking Transparency (ATT) для Яндекс и AppLovin
                // Задержка 1.2 секунды: Apple требует показывать диалог после
                // полной загрузки главного экрана, а не в момент холодного запуска
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                await FormaAdManager.shared.requestTrackingAuthorizationAndInitialize()
            }
    }

    #if DEBUG
    private static var demoAchievementCategory: FormaAchievement.AchievementCategory? {
        guard let scene = FormaScreenshotMode.scene, scene.hasPrefix("achievement") else { return nil }
        let parts = scene.split(separator: ":")
        let name = parts.count > 1 ? String(parts[1]) : "steps"
        switch name {
        case "workouts": return .workouts
        case "water": return .water
        case "streaks": return .streaks
        case "master": return .master
        default: return .steps
        }
    }
    #endif
}

#if DEBUG
/// Показывает праздничный экран награды на чёрном фоне. Тап по фону/кнопке перезапускает анимацию.
private struct AchievementDemoHost: View {
    let category: FormaAchievement.AchievementCategory
    @State private var run = 0

    var body: some View {
        AchievementCelebrationOverlay(
            achievement: FormaAchievement(
                id: "demo_\(category.rawValue)",
                title: "Золотая десятка",
                description: "Выполнить дневную норму 10 000 шагов",
                icon: category == .water ? "drop.fill" : (category == .streaks ? "flame.fill" : "medal.fill"),
                category: category,
                xpReward: 200,
                targetValue: 10000,
                currentValue: 10000,
                isUnlocked: true,
                unlockedDate: Date()
            ),
            onDismiss: { run += 1 }
        )
        .id(run)
        .background(Color.black.ignoresSafeArea())
    }
}
#endif
