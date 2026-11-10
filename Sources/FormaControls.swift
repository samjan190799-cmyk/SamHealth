import SwiftUI

// MARK: - Общие детали интерфейса
//
// Один набор на все вкладки: плитка быстрого действия, второстепенная кнопка, бейдж статуса и шапка
// ИИ-карточки. Раньше каждая карточка собирала их по-своему: пять видов кнопок, чипы шрифтом 9–10 pt,
// у ИИ-блоков свой цвет на каждом экране. Правила те же, что у карточек: плоская заливка без теней и
// градиентов, размеры и цвета из токенов, зона нажатия не меньше 44 pt.
// Главная кнопка экрана — `FormaPrimaryButton` (DesignSystem.swift), она на экране одна.

/// Наименьшая сторона зоны нажатия
public enum FormaTouch {
    public static let minTarget: CGFloat = 44
}

// MARK: Плитка быстрого действия

/// Значок над подписью на плоской заливке. Это только внешний вид: плитку оборачивают в `Button`,
/// `PhotosPicker` или `NavigationLink`.
public struct FormaQuickTileLabel: View {
    public var icon: String
    public var tint: Color
    public var title: String

    public init(icon: String, tint: Color, title: String) {
        self.icon = icon
        self.tint = tint
        self.title = title
    }

    public var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(tint)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, FormaSpacing.m)
        .padding(.horizontal, FormaSpacing.xs)
        .frame(maxWidth: .infinity)
        .formaSurface(FormaRadius.control)
    }
}

// MARK: Второстепенная кнопка

/// Плоская заливка оттенком роли, подпись цветом роли. Для действий внутри карточки, которые не
/// являются главным действием экрана.
public struct FormaTintedButton: View {
    public var title: String
    public var icon: String?
    public var tint: Color
    public var action: () -> Void

    public init(title: String, icon: String? = nil, tint: Color, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.tint = tint
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.subheadline.weight(.semibold))
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(tint)
            .padding(.horizontal, FormaSpacing.m)
            .frame(maxWidth: .infinity, minHeight: FormaTouch.minTarget)
            .background(tint.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
        }
        .buttonStyle(SpringPressButtonStyle(scaleAmount: 0.97, hapticStyle: .light))
    }
}

// MARK: Бейдж статуса

/// Короткая подпись на заливке оттенком своего цвета: «Дефицит 300 ккал», «Норма выполнена»
public struct FormaBadge: View {
    public var text: String
    public var tint: Color

    public init(_ text: String, tint: Color) {
        self.text = text
        self.tint = tint
    }

    public var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundColor(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 10)
            .padding(.vertical, FormaSpacing.xs)
            .background(tint.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: FormaRadius.chip, style: .continuous))
    }
}

// MARK: Шапка ИИ-карточки

/// Портрет тренера, заголовок и кнопка чата. Цвет ИИ один на всё приложение — `Theme.aiViolet`:
/// личные цвета тренеров в шапке не используются, иначе ИИ-блоки на разных вкладках выглядят чужими.
public struct FormaAICardHeader: View {
    public var title: String
    public var subtitle: String
    public var avatarAssetName: String
    public var chatTitle: String
    public var onChat: (() -> Void)?

    public init(title: String, subtitle: String, avatarAssetName: String, chatTitle: String = "Чат", onChat: (() -> Void)? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.avatarAssetName = avatarAssetName
        self.chatTitle = chatTitle
        self.onChat = onChat
    }

    public var body: some View {
        HStack(spacing: FormaSpacing.m) {
            Image(avatarAssetName)
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Theme.aiViolet, lineWidth: 1.5))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FormaFont.headline)
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(FormaFont.caption)
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: FormaSpacing.s)

            if let onChat {
                Button(action: onChat) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                        Text(chatTitle)
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Theme.aiViolet)
                    .padding(.horizontal, FormaSpacing.m)
                    .padding(.vertical, FormaSpacing.s)
                    .background(Theme.aiViolet.opacity(0.14))
                    .clipShape(Capsule(style: .continuous))
                    // Видимая «пилюля» ниже 44 pt, а нажимается вся строка шапки по высоте
                    .frame(minHeight: FormaTouch.minTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(SpringPressButtonStyle(scaleAmount: 0.96, hapticStyle: .light))
            }
        }
    }
}
