import SwiftUI
import QuartzCore

// MARK: - Лаборатория производительности
//
// Инструмент поиска причины лагов прокрутки на реальном телефоне. Работает только во внутренних сборках
// (DEBUG или FORMA_INTERNAL_TOOLS, см. FormaBuild): в обычной сборке все флаги — константа `false`, счётчика FPS
// и панели настроек нет, а значит, на App Review ничего из этого не попадает.
//
// Как пользоваться: Настройки → «Лаборатория производительности» → включить «Показывать FPS» → листать экран и
// по одному отключать подозреваемых (фон, тени, карточки, графики, реклама, отдельные карточки Главной). Когда FPS
// вырос, виновник найден. Переключатели действуют сразу, перезапуск не нужен.

/// Ключи переключателей в UserDefaults
enum FormaPerfKey {
    static let hud = "perf_hud"
    static let noAds = "perf_no_ads"
    static let noBackdrop = "perf_no_backdrop"
    static let noShadows = "perf_no_shadows"
    static let noLoops = "perf_no_loops"
    /// Карточки Главной, которые спрятаны для эксперимента: идентификаторы через запятую
    static let hiddenCards = "perf_hidden_cards"
}

#if DEBUG || FORMA_INTERNAL_TOOLS

/// Карточка Главной, которую можно спрятать в лаборатории
struct FormaPerfCard: Identifiable {
    let id: String
    let title: String
}

enum FormaPerfCards {
    static let all: [FormaPerfCard] = [
        FormaPerfCard(id: "hero", title: "Кольца «Сегодня»"),
        FormaPerfCard(id: "health", title: "Статус Apple Health"),
        FormaPerfCard(id: "gamif", title: "Уровень и опыт"),
        FormaPerfCard(id: "streak", title: "Ваш импульс"),
        FormaPerfCard(id: "habits", title: "Привычки (сводка)"),
        FormaPerfCard(id: "ai", title: "ИИ-тренер и дефицит"),
        FormaPerfCard(id: "who", title: "Норма активности ВОЗ"),
        FormaPerfCard(id: "water", title: "Вода"),
        FormaPerfCard(id: "nutrition", title: "Питание"),
        FormaPerfCard(id: "pulsesleep", title: "Пульс и сон"),
        FormaPerfCard(id: "recovery", title: "Готовность (HRV)")
    ]
}

#endif

/// Булев флаг эксперимента. Во внутренней сборке читает UserDefaults и сам обновляет экран при изменении,
/// в обычной всегда `false` — код эксперимента там не выполняется.
@propertyWrapper
struct FormaPerfFlag: DynamicProperty {
    #if DEBUG || FORMA_INTERNAL_TOOLS
    @AppStorage private var stored: Bool

    init(_ key: String) {
        _stored = AppStorage(wrappedValue: false, key)
    }

    var wrappedValue: Bool { stored }
    #else
    init(_ key: String) {}

    var wrappedValue: Bool { false }
    #endif
}

extension View {
    /// Только для экспериментов: прячет карточку Главной, если её отметили в лаборатории
    func formaPerfHidden(_ id: String) -> some View {
        modifier(FormaPerfHiddenModifier(id: id))
    }

    /// Тень, которую лаборатория умеет отключить целиком
    func formaPerfShadow(color: Color, radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0) -> some View {
        modifier(FormaPerfShadowModifier(color: color, radius: radius, x: x, y: y))
    }
}

private struct FormaPerfHiddenModifier: ViewModifier {
    let id: String
    #if DEBUG || FORMA_INTERNAL_TOOLS
    @AppStorage(FormaPerfKey.hiddenCards) private var hidden = ""
    private var isHidden: Bool { hidden.split(separator: ",").contains(Substring(id)) }
    #else
    private var isHidden: Bool { false }
    #endif

    @ViewBuilder
    func body(content: Content) -> some View {
        if isHidden {
            EmptyView()
        } else {
            content
        }
    }
}

private struct FormaPerfShadowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
    @FormaPerfFlag(FormaPerfKey.noShadows) private var noShadows

    @ViewBuilder
    func body(content: Content) -> some View {
        if noShadows {
            content
        } else {
            content.shadow(color: color, radius: radius, x: x, y: y)
        }
    }
}

#if DEBUG || FORMA_INTERNAL_TOOLS

// MARK: Счётчик кадров

/// Считает кадры по сигналам экрана (CADisplayLink) и раз в секунду выдаёт: частоту, самый долгий кадр и долю
/// «пропущенных» кадров (дольше 20 мс, то есть реже 50 кадров в секунду).
@MainActor
final class FormaFPSMonitor: NSObject, ObservableObject {
    static let shared = FormaFPSMonitor()

    @Published private(set) var fps = 0
    @Published private(set) var worstMs = 0
    @Published private(set) var slowPercent = 0

    private var link: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var windowStart: CFTimeInterval = 0
    private var frames = 0
    private var slowFrames = 0
    private var worst: CFTimeInterval = 0

    func start() {
        guard link == nil else { return }
        lastTimestamp = 0
        frames = 0
        slowFrames = 0
        worst = 0
        let newLink = CADisplayLink(target: self, selector: #selector(tick(_:)))
        // Просим 60 кадров: так показания сравнимы с привычной планкой «60 FPS» на любом экране
        newLink.preferredFramesPerSecond = 60
        newLink.add(to: .main, forMode: .common)
        link = newLink
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    @objc private func tick(_ sender: CADisplayLink) {
        let now = sender.timestamp
        if lastTimestamp == 0 {
            lastTimestamp = now
            windowStart = now
            return
        }
        let delta = now - lastTimestamp
        lastTimestamp = now
        frames += 1
        if delta > 0.020 { slowFrames += 1 }
        worst = max(worst, delta)

        let elapsed = now - windowStart
        guard elapsed >= 1.0 else { return }
        fps = Int((Double(frames) / elapsed).rounded())
        worstMs = Int((worst * 1000).rounded())
        slowPercent = frames > 0 ? Int((Double(slowFrames) / Double(frames) * 100).rounded()) : 0
        frames = 0
        slowFrames = 0
        worst = 0
        windowStart = now
    }
}

/// Плашка со счётчиком кадров поверх всего приложения
struct FormaFPSOverlay: View {
    @AppStorage(FormaPerfKey.hud) private var enabled = false
    @ObservedObject private var monitor = FormaFPSMonitor.shared

    var body: some View {
        Group {
            if enabled {
                Text("\(monitor.fps) fps · худший \(monitor.worstMs) мс · >20 мс: \(monitor.slowPercent)%")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(monitor.fps >= 55 ? .green : (monitor.fps >= 40 ? .yellow : .red))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.78), in: Capsule())
                    .padding(.top, 4)
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            if enabled { monitor.start() }
        }
        .onChange(of: enabled) { _, isOn in
            if isOn { monitor.start() } else { monitor.stop() }
        }
    }
}

#endif
