#if DEBUG
import SwiftUI
import UIKit

/// Режим съёмки скриншотов для CI (scripts/ios_tab_screenshots.sh, scripts/ios_achievement_preview.sh).
/// Включается аргументами запуска и существует только в DEBUG-сборке:
///   -FormaScreenshotScene tab:<0-4>      открыть приложение сразу на вкладке
///   -FormaScreenshotScene achievement:…  показать только экран награды (см. FormaApp)
///   -FormaScreenshotPage <n>             прокрутить экран на n «страниц» вниз
/// В этом режиме не показываются системные запросы (ATT), которые перекрыли бы интерфейс.
enum FormaScreenshotMode {
    static var scene: String? {
        UserDefaults.standard.string(forKey: "FormaScreenshotScene")
    }

    static var isActive: Bool {
        scene != nil
    }

    /// Вкладка из `tab:<n>`; для сцен `celebration:*` открываются «Тренировки» — награда должна
    /// появиться не на Главной, а поверх другой вкладки.
    static var initialTab: Int? {
        guard let scene else { return nil }
        if scene.hasPrefix("celebration:") { return 1 }
        guard scene.hasPrefix("tab:") else { return nil }
        return Int(scene.dropFirst(4))
    }

    /// Страница онбординга из сцены `onboarding:<0-3>` (для скриншотов на CI)
    static var onboardingPage: Int? {
        guard let scene, scene.hasPrefix("onboarding:") else { return nil }
        return Int(scene.dropFirst("onboarding:".count))
    }

    /// `celebration:live` — награды появляются поверх вкладки; `celebration:sheet` — поверх открытого листа
    static var celebrationMode: String? {
        guard let scene, scene.hasPrefix("celebration:") else { return nil }
        return String(scene.dropFirst("celebration:".count))
    }

    /// Через 2,5 с кладёт в очередь две награды (как при реальной разблокировке), на 8-й секунде
    /// закрывает первую — видно, что вторая показывается следом, а на 13-й закрывает и вторую.
    @MainActor
    static func runCelebrationDemoIfNeeded() {
        guard celebrationMode != nil else { return }
        func sample(_ id: String, _ title: String, _ icon: String, _ category: FormaAchievement.AchievementCategory, _ xp: Int) -> FormaAchievement {
            FormaAchievement(
                id: id, title: title, description: "Демонстрационная награда для проверки анимации",
                icon: icon, category: category, xpReward: xp, targetValue: 1, currentValue: 1,
                isUnlocked: true, unlockedDate: Date()
            )
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            let manager = GamificationManager.shared
            manager.enqueueCelebration(sample("demo_a", "Золотая десятка", "medal.fill", .steps, 200))
            manager.enqueueCelebration(sample("demo_b", "Огонёк (3 дня)", "flame.fill", .streaks, 150))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
            GamificationManager.shared.dismissCurrentCelebration()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 13.0) {
            GamificationManager.shared.dismissCurrentCelebration()
        }
    }

    static var page: Int {
        UserDefaults.standard.integer(forKey: "FormaScreenshotPage")
    }

    /// Через 2 секунды после появления прокручивает самый длинный вертикальный скролл экрана
    /// на `page` экранов вниз (с перекрытием, чтобы между снимками не терялись блоки).
    @MainActor
    static func scrollToRequestedPage() {
        let page = self.page
        guard page > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let windows = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
            guard let window = windows.first(where: { $0.isKeyWindow }) ?? windows.first else { return }

            var best: UIScrollView?
            func visit(_ view: UIView) {
                if let scroll = view as? UIScrollView,
                   !scroll.isHidden,
                   scroll.window != nil,
                   scroll.bounds.width > window.bounds.width * 0.8,
                   scroll.contentSize.height > scroll.bounds.height + 40 {
                    if let current = best {
                        if scroll.contentSize.height > current.contentSize.height {
                            best = scroll
                        }
                    } else {
                        best = scroll
                    }
                }
                for subview in view.subviews {
                    visit(subview)
                }
            }
            visit(window)

            guard let scroll = best else { return }
            let step = scroll.bounds.height - 220
            let maxY = max(0, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
            let y = min(CGFloat(page) * step, maxY) - scroll.adjustedContentInset.top
            scroll.setContentOffset(CGPoint(x: 0, y: y), animated: false)
        }
    }
}
#endif
