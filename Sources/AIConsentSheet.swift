import SwiftUI

// MARK: - Модальный экран запроса согласия на обработку данных ИИ (Guidelines 5.1.1(i) & 5.1.2(i))
public struct AIConsentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("user_consented_to_ai_sharing") private var userConsentedToAISharing: Bool = false
    
    var onConsentGiven: (() -> Void)? = nil
    var onDismiss: (() -> Void)? = nil
    
    public init(onConsentGiven: (() -> Void)? = nil, onDismiss: (() -> Void)? = nil) {
        self.onConsentGiven = onConsentGiven
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 22) {
                        
                        // Иконка и заголовок
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(red: 168/255, green: 85/255, blue: 247/255).opacity(0.25), Color(red: 0/255, green: 229/255, blue: 255/255).opacity(0.25)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 72, height: 72)
                                
                                Image(systemName: "sparkles")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color(red: 168/255, green: 85/255, blue: 247/255), Color(red: 0/255, green: 229/255, blue: 255/255)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            
                            Text("Использование ИИ-функций\nи конфиденциальность")
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .multilineTextAlignment(.center)
                                .foregroundColor(Theme.textPrimary)
                            
                            Text("В соответствии с правилами безопасности Apple, мы просим ваше явное согласие перед отправкой запросов в сторонний ИИ-сервис.")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                        }
                        .padding(.top, 10)
                        
                        // Пункты раскрытия (Transparency cards)
                        VStack(spacing: 14) {
                            
                            // 1. Кому отправляются данные
                            AIDataPointRow(
                                icon: "building.2.fill",
                                color: .blue,
                                title: "Кому передаются данные:",
                                description: "Провайдеру ИИ-моделей Google LLC (Google Gemini API) через защищенное шифрованное соединение TLS/HTTPS."
                            )
                            
                            // 2. Какие именно данные отправляются
                            AIDataPointRow(
                                icon: "photo.badge.checkmark.fill",
                                color: Color(red: 16/255, green: 185/255, blue: 129/255),
                                title: "Какие данные передаются:",
                                description: "Исключительно выбранные вами фотографии блюд для анализа КБЖУ или текст заданного вами вопроса фитнес-тренеру. Никакие системные файлы или контакты не передаются."
                            )
                            
                            // 3. Полная анонимность
                            AIDataPointRow(
                                icon: "person.crop.circle.badge.xmark",
                                color: .purple,
                                title: "Персональная защита:",
                                description: "Ваше имя, Apple ID, email, номер телефона, геолокация и биометрические данные НИКОГДА не передаются в ИИ. Запросы полностью обезличены."
                            )
                            
                            // 4. Без рекламы и без трекинга
                            AIDataPointRow(
                                icon: "lock.shield.fill",
                                color: .orange,
                                title: "Использование данных:",
                                description: "Данные обрабатываются в реальном времени исключительно для генерации ответа. Google LLC обеспечивает равный уровень защиты и не использует ваши данные для обучения публичных моделей или таргетинга рекламы."
                            )
                        }
                        .padding(.horizontal, 20)
                        
                        // Ссылки на политику
                        HStack(spacing: 12) {
                            Link("Политика конфиденциальности", destination: URL(string: "https://samjan190799-cmyk.github.io/SamHealth/privacy.html")!)
                            Text("•")
                            Link("Google API Privacy", destination: URL(string: "https://ai.google.dev/terms")!)
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.textSecondary.opacity(0.8))
                        
                        // Кнопки согласия / отказа
                        VStack(spacing: 10) {
                            Button(action: {
                                userConsentedToAISharing = true
                                HapticManager.shared.notification(.success)
                                dismiss()
                                onConsentGiven?()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Разрешить и продолжить")
                                        .font(.system(size: 16, weight: .bold))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .foregroundColor(.white)
                                .background(
                                    LinearGradient(
                                        colors: [Color(red: 168/255, green: 85/255, blue: 247/255), Color(red: 0/255, green: 229/255, blue: 255/255)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(16)
                                .shadow(color: Color(red: 168/255, green: 85/255, blue: 247/255).opacity(0.35), radius: 8, y: 4)
                            }
                            .buttonStyle(AppleDesignAwardsButtonStyle(scaleAmount: 0.96))
                            
                            Button(action: {
                                userConsentedToAISharing = false
                                dismiss()
                                onDismiss?()
                            }) {
                                Text("Отклонить (Базовый офлайн-режим)")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Theme.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 6)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Строка пункта данных ИИ
private struct AIDataPointRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.14))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
                    .lineSpacing(2)
            }
            
            Spacer()
        }
        .padding(12)
        .background(Theme.cardBackground)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
