# Apple Human Interface Guidelines (HIG) — Стандарт дизайна проекта Forma

Этот документ устанавливает обязательные правила проектирования и разработки интерфейсов в проекте **Forma** на основе официального руководства Apple [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/).

Любые задачи по изменению или созданию UI/UX, экранов, компонентов, виджетов и анимаций ДОЛЖНЫ строго следовать этим правилам:

---

## 1. Типографика и шрифтовая иерархия (SF Pro / Rounded)
* **Иерархия:** `.largeTitle` (34pt), `.title` / `.title2` / `.title3`, `.headline`, `.subheadline`, `.body`, `.callout`, `.footnote`, `.caption`.
* **Dynamic Type:** Все тексты должны поддерживать масштабирование без жестких `frame(height:)`.

## 2. Цвета, материалы и Dark Mode
* **Семантические цвета:** `Color(uiColor: .systemBackground)`, `Color(uiColor: .secondarySystemBackground)`, `Color(uiColor: .label)`, `Color(uiColor: .secondaryLabel)`, `Color(uiColor: .separator)`.
* **Стекломорфизм:** `.ultraThinMaterial` / `.thinMaterial` с тонкой гранью `.stroke(.white.opacity(0.12), lineWidth: 1)`.

## 3. Тактильная отдача (Haptic Feedback)
* Любое интерактивное действие пользователя ОБЯЗАНО сопровождаться тактильным откликом:
  * Легкий выбор / переключение таба: `UIImpactFeedbackGenerator(style: .light)`
  * Основная кнопка: `UIImpactFeedbackGenerator(style: .medium)`
  * Успех / завершение цели: `UINotificationFeedbackGenerator().notificationOccurred(.success)`
  * Ошибка / отказ: `UINotificationFeedbackGenerator().notificationOccurred(.error)`

## 4. Пружинные анимации (Spring Physics)
* Использовать `.spring(response: 0.35, dampingFraction: 0.78)` или `.interactiveSpring()`.
* Эффект нажатия на кнопку: `.scaleEffect(configuration.isPressed ? 0.96 : 1.0)`.

## 5. SF Symbols и Symbol Effects
* Использовать системные иконки SF Symbols с `.symbolRenderingMode(.hierarchical)` и живыми системными эффектами (`.symbolEffect(.bounce)`).

## 6. Эргономика и область нажатия (Thumb Zone)
* Минимальная интерактивная область: не менее **44 × 44 pt**.
* Главные кнопки действий размещать в нижней трети экрана для удобства работы одной рукой.

## 7. Пустые состояния и скелетоны
* При отсутствии данных показывать эстетичный Empty State (крупная иконка, понятное описание, кнопка действия).
* При загрузке использовать `.redacted(reason: .placeholder)`.

## 8. Dynamic Island и Live Activities
* Четкие 4 режима: Compact Leading/Trailing, Minimal, Expanded и Lock Screen Banner.

## 9. Защита от случайного закрытия
* Использовать `.interactiveDismissDisabled` при наличии несохраненных данных с подтверждающим диалогом.
