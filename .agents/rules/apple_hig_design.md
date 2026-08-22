# Apple Human Interface Guidelines (HIG) — Стандарт дизайна проекта Forma

Этот документ устанавливает обязательные правила проектирования и разработки интерфейсов в проекте **Forma** на основе официального руководства Apple [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/).

Любые задачи по изменению или созданию UI/UX, экранов, компонентов, виджетов и анимаций ДОЛЖНЫ строго следовать этим правилам:

---

## 1. Типографика и шрифтовая иерархия
* **Шрифтовая система:** Использовать системные шрифты Apple (`Font.system(...)` с округлым стилем `.design: .rounded` или стандартным SF Pro / SF Pro Display).
* **Иерархия:** Четкое разделение стилей (`.largeTitle`, `.title`, `.title2`, `.title3`, `.headline`, `.subheadline`, `.body`, `.callout`, `.footnote`, `.caption`, `.caption2`).
* **Адаптивность (Dynamic Type):** Все тексты должны поддерживать масштабирование без обрезания контента.

## 2. Цветовая модель и темная тема (Colors & Dark Mode)
* **Семантические цвета:** Использовать семантические цвета Apple (`Color(uiColor: .systemBackground)`, `Color(uiColor: .label)`, `Color(uiColor: .secondaryLabel)`, `Color(uiColor: .separator)`).
* **Контрастность:** Тексты и иконки должны строго соответствовать коэффициентам контрастности WCAG / Apple HIG (не менее 4.5:1 для обычного текста).
* **Стекломорфизм и материалы:** Использовать системные материалы SwiftUI (`.ultraThinMaterial`, `.thinMaterial`, `.regularMaterial`) для плашек, карточек и навигационных панелей.

## 3. Тактильная отдача (Haptic Feedback)
* Любое интерактивное действие пользователя (нажатие кнопки, переключение тумблера, успешное сохранение, выполнение цели, перетаскивание ползунка) ОБЯЗАНО сопровождаться тактильным откликом:
  * Легкое касание / выбор: `UIImpactFeedbackGenerator(style: .light).impactOccurred()`
  * Основное действие / кнопка: `UIImpactFeedbackGenerator(style: .medium).impactOccurred()`
  * Успех / завершение: `UINotificationFeedbackGenerator().notificationOccurred(.success)`
  * Ошибка / предупреждение: `UINotificationFeedbackGenerator().notificationOccurred(.error)`

## 4. Анимации и микровзаимодействия
* **Фирменная плавность Apple:** Использовать пружинные анимации `.spring(response: 0.35, dampingFraction: 0.8)` или `.interactiveSpring()`.
* **Переходы:** Плавные переходы экранов, плавное появление карточек и колец активности. Избегать резких скачков UI.

## 5. Паттерны взаимодействия и модальности
* **Шторки (Sheets):** Использовать нативные шторки `.sheet` с `.presentationDetents([.medium, .large])` и `.presentationDragIndicator(.visible)`.
* **Запросы разрешений (Apple Health, Уведомления):**
  * Четко объяснять пользователю ценность до показа системного диалога (Context-First).
  * Не блокировать приложение при отказе — предоставлять понятный путь в Системные Настройки.
* **Таб-бар и навигация:** Стандартный `TabView` с иконками SF Symbols и заголовками, полупрозрачный блюр при прокрутке.

## 6. Виджеты и Live Activities (Dynamic Island)
* Лаконичный информационный дизайн.
* Четкая читаемость на Always-On дисплее и экране блокировки.
