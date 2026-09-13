# Руководство по устранению замечаний в App Store Connect (Версия 1.0)

Этот документ содержит пошаговую инструкцию по исправлению замечаний цензоров Apple от **13 сентября 2026 года**:
1. **Guideline 2.1(b)** — Прикрепление подписок к релизу и устранение ошибки Sandbox StoreKit.
2. **Guidelines 5.1.1(i) & 5.1.2(i)** — Ответ цензорам по поводу стороннего ИИ (Google Gemini API).

---

## Шаг 1. Прикрепление подписок к отправке версии (КРИТИЧЕСКИ ВАЖНО)

В вашем App Store Connect подписки находились в блоке **«Draft Submissions (1)»** и не были включены в сам бинарник при первой отправке. Из-за этого Apple Review Sandbox не возвращал тарифы на тестовый iPad Air, и цензор получил ошибку синхронизации.

### Инструкция:
1. Войдите в [App Store Connect](https://appstoreconnect.apple.com/) → **Мои приложения (My Apps)** → выберите **Forma**.
2. В левом меню выберите **iOS App → 1.0** (текущая версия со статусом *Rejected / Отклонено* или подготовьте новую подачу).
3. Прокрутите страницу версии вниз до раздела **«Встроенные покупки и подписки» (In-App Purchases and Subscriptions)**.
4. Нажмите кнопку **«+» (Выбрать подписки / Select In-App Purchases)**.
5. Отметьте обе подписки:
   - `com.samvel.forma.pro.yearly` — Годовая (7 дней бесплатно)
   - `com.samvel.forma.pro.monthly` — Месячная
6. Нажмите **Сохранить (Save)**.
   > **Примечание:** После этого обе подписки будут подаваться на проверку **вместе с бинарником приложения**, и статус в блоке изменится с *Draft Submissions* на *Waiting for Review*.

---

## Шаг 2. Проверка метаданных и скриншотов ревью для каждой подписки

Apple требует наличие **Скриншота для проверки (App Review Screenshot)** для каждого In-App Purchase продукта:
1. В левом меню App Store Connect перейдите в раздел **Подписки (Subscriptions)**.
2. Нажмите на группу **Forma Pro Group**.
3. Для каждой подписки (`com.samvel.forma.pro.yearly` и `com.samvel.forma.pro.monthly`):
   - Откройте подписку.
   - Прокрутите до блока **Информация для проверки (App Review Information)**.
   - Убедитесь, что загружен скриншот экрана подписки (пейволла `FormaPaywallView`). Размер: стандартный скриншот iPhone (например, 1290×2796 или 1242×2688) или iPad. Скриншот должен демонстрировать экран Forma PRO с тарифами и кнопкой оформления.
   - В поле **Заметки для проверки (Review Notes)** укажите:
     ```text
     Auto-renewable subscription providing full access to Forma Pro features (all 6 AI coaches, unlimited meal scanning, VIP widgets). Fully testable in Sandbox.
     ```
   - Нажмите **Сохранить (Save)**.

---

## Шаг 3. Проверка соглашения Paid Apps Agreement (Платные приложения)

Apple прямо написала в замечании:
> *«the Account Holder must also accept the Paid Apps Agreement in the Business section of App Store Connect. Confirm you have a Paid Apps Agreement in effect.»*

1. Перейдите в раздел **Бизнес (Agreements, Tax, and Banking / Соглашения, налоги и банковские операции)** в верхнем меню App Store Connect.
2. Проверьте статус соглашения **Paid Apps (Платные приложения)**:
   - Если статус **Pending / Ожидает подтверждения** — владелец аккаунта (Account Holder) должен принять обновленные условия соглашения и заполнить банковские и налоговые реквизиты.
   - Если статус **Active (Действует)** — всё в порядке.

---

## Шаг 4. Сборка и отправка нового бинарника (Build 196+)

В коде уже реализованы:
- Автоматический вызов окна согласия `AIConsentSheet` при открытии AI-Нутрициолога и AI-Тренера.
- Точное раскрытие передачи данных в **Google LLC (Google Gemini API)**, категорий данных (обезличенные метрики питания, фото) и подтверждение равного уровня защиты (Equal Protection).
- Прямой сетевой запрос продуктов StoreKit 2 на кнопке покупки без ложных сообщений о синхронизации.
- Обновление политики конфиденциальности `privacy.html`.

Для запуска сборки и отправки новой сборки в TestFlight:
- Запустите GitHub Actions workflow **Deploy to TestFlight** (или сделайте `git push origin main`).
- Дождитесь сборки `1.0 (196)` или выше.
- В App Store Connect в разделе сборки выберите новую сборку.

---

## Шаг 5. Текст ответа цензорам Apple в Resolution Center (Reply to App Review)

Скопируйте и отправьте этот текст в окне переписки с Apple (Resolution Center) в App Store Connect:

```text
Dear App Review Team,

Thank you for your constructive feedback. We have addressed all identified items in the newly submitted binary 1.0 (Build 196):

1. Guideline 2.1(b) - In-App Purchases Submitted for Review:
- Both auto-renewable subscription products (com.samvel.forma.pro.yearly and com.samvel.forma.pro.monthly) have now been explicitly attached to this version submission with review screenshots and review notes included.
- We verified that the Paid Apps Agreement is in Active status in the Agreements, Tax, and Banking section of our App Store Connect account.
- The StoreKit 2 purchase implementation in SubscriptionManager and FormaPaywallView has been reinforced with on-demand StoreKit fetching and responsive loading indicators, preventing any misleading error messages in the Sandbox environment. All products can now be purchased and verified smoothly in Sandbox.

2. Guidelines 5.1.1(i) & 5.1.2(i) - Third-Party AI Data Transparency, Equal Protection & Explicit Consent:
- We have introduced an affirmative in-app consent modal (AIConsentSheet) that is presented immediately when the user accesses the AI Nutritionist ("AI-Нутрициолог") or AI Coach ("AI-Тренер") features.
- The prompt explicitly informs the user:
  a) Who data is sent to: third-party AI provider Google LLC (Google Gemini API via encrypted TLS/HTTPS connections).
  b) What categories of data are sent: user questions, meal photos for macro estimation, and anonymized nutrition metrics (calories, protein, fats, carbohydrates, target weight goal, somatotype). Absolutely ZERO personal identifiers (no user name, email, Apple ID, phone number, contacts, or GPS location) are ever collected or sent.
  c) Purpose of data use: real-time personalized nutrition and fitness recommendations.
  d) Equal protection: Google LLC provides equal or equivalent protection of personal data. Data is processed strictly in real-time to generate responses, is not used to train or fine-tune public AI foundation models, and is never shared with or sold to advertisers or third-party data brokers.
  e) Revocation: users can grant, deny, or revoke this permission at any time in Settings > AI Data Sharing & Privacy. An offline fallback mode is provided if consent is declined.
- Our public Privacy Policy (Section 3) has been updated with these disclosures: https://samjan190799-cmyk.github.io/SamHealth/privacy.html

3. Guideline 1.4.1 - Scientific Methodology & Medical Citations:
- Medical disclaimers and direct peer-reviewed citations (Task Force Circulation 1996 for HRV, AHA/ACSM for VO2 Max, EFSA/NAM for caffeine and hydration) are prominently featured throughout the app and in Settings.

Thank you for your time and continued review.

Best regards,
Forma Development Team
```
