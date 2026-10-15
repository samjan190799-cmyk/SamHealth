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

    /// Вкладка из `tab:<n>`
    static var initialTab: Int? {
        guard let scene, scene.hasPrefix("tab:") else { return nil }
        return Int(scene.dropFirst(4))
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
