import SwiftUI

public struct AICoachChatMessage: Identifiable, Equatable {
    public let id: String = UUID().uuidString
    public let isUser: Bool
    public let text: String
    public let provider: String?
    public let timestamp: Date = Date()
}

public struct AICoachChatView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var health: HealthKitManager
    
    @AppStorage("app_language") private var appLanguage = "ru"
    @AppStorage("user_weight") private var userWeight = 75.0
    @AppStorage("user_target_weight") private var userTargetWeight = 70.0
    @AppStorage("user_activity_level") private var userActivityLevel = "Средняя"
    @AppStorage("voice_coach_enabled") private var voiceCoachEnabled = true
    
    @ObservedObject private var coachManager = AICoachManager.shared
    
    @State private var messages: [AICoachChatMessage] = []
    @State private var inputText: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var isSpeakingMessageId: String? = nil
    
    private var coach: AICoachPersona {
        coachManager.currentCoach
    }
    
    private let quickPrompts = [
        "🦵 Чем заменить приседания и выпады, если ноют колени?",
        "😴 Спал меньше 6 часов, какую тренировку выбрать?",
        "🔥 Оцени мою активность и сожженные калории за сегодня",
        "🏃‍♂️ Как держать правильный темп и пульс при беге?",
        "⏱️ Составь эффективную разминку на 5 минут",
        "💪 Как прогрессировать в силовых упражнениях без травм?"
    ]
    
    private func tr(_ key: String) -> String {
        LocalizationManager.tr(key, lang: appLanguage)
    }
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Верхняя шапка с аватаром и биометрией
                    headerCoachSummary
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 10)
                    
                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.horizontal)
                    
                    // Лента сообщений
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 16) {
                                welcomeCoachBubble
                                
                                ForEach(messages) { msg in
                                    chatBubble(for: msg)
                                        .id(msg.id)
                                }
                                
                                if isLoading {
                                    HStack(spacing: 10) {
                                        ProgressView()
                                            .tint(coach.accentColor)
                                        Text("Тренер \(coach.name) анализирует ваши показатели...")
                                            .font(.caption)
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 16)
                                    .background(Theme.cardBackground)
                                    .cornerRadius(16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id("loading_indicator")
                                }
                                
                                if let err = errorMessage {
                                    Text(err)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .padding()
                                }
                            }
                            .padding()
                        }
                        .onChange(of: messages.count) { _, _ in
                            if let last = messages.last {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        }
                        .onChange(of: isLoading) { _, loading in
                            if loading {
                                withAnimation {
                                    proxy.scrollTo("loading_indicator", anchor: .bottom)
                                }
                            }
                        }
                    }
                    
                    // Быстрые подсказки (Чипы)
                    if !isLoading {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(quickPrompts, id: \.self) { prompt in
                                    Button(action: {
                                        sendMessage(prompt)
                                    }) {
                                        Text(prompt)
                                            .font(.caption)
                                            .bold()
                                            .foregroundColor(Theme.textPrimary)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(Color.white.opacity(0.08))
                                            .cornerRadius(18)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 18)
                                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                            )
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                        }
                    }
                    
                    // Поле ввода текста
                    inputBar
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image(coach.avatarAssetName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(coach.accentColor, lineWidth: 1.5))
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Тренер \(coach.name)")
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(Theme.textPrimary)
                            Text("\(coach.specialty) • Online")
                                .font(.system(size: 10))
                                .foregroundColor(coach.accentColor)
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Шапка биометрии за сегодня
    
    private var headerCoachSummary: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                AITrainerAvatarView(coachState: isLoading ? .exercising : .idle, size: 54, customCoach: coach)
                    .frame(width: 54, height: 54)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(coach.specialty)
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    Text(coach.tagline)
                        .font(.footnote)
                        .bold()
                        .foregroundColor(Theme.textPrimary)
                }
                Spacer()
            }
            
            // Биометрические пилюли
            HStack(spacing: 6) {
                BiometricPill(icon: "flame.fill", color: Theme.moveColor, title: "\(Int(health.activeEnergyBurned)) ккал")
                BiometricPill(icon: "figure.walk", color: Theme.exerciseColor, title: "\(health.stepCountToday) шаг")
                BiometricPill(icon: "heart.fill", color: Theme.pulseColor, title: health.currentHeartRate > 0 ? "\(health.currentHeartRate) уд" : "--")
                BiometricPill(icon: "bed.double.fill", color: Theme.sleepColor, title: health.sleepHoursLastNight > 0 ? String(format: "%.1f ч", health.sleepHoursLastNight) : "--")
            }
        }
        .padding(12)
        .background(Theme.cardBackground)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    // MARK: - Приветственный бабл
    
    private var welcomeCoachBubble: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(coach.avatarAssetName)
                .resizable()
                .scaledToFill()
                .frame(width: 38, height: 38)
                .clipShape(Circle())
                .overlay(Circle().stroke(coach.accentColor, lineWidth: 1.5))
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Тренер \(coach.name)")
                    .font(.caption2)
                    .bold()
                    .foregroundColor(coach.accentColor)
                
                Text(coach.localizedGreeting(lang: appLanguage) + "\n\nЯ учитываю твои шаги, пульс, сон за прошлую ночь и сожженные калории. Спроси меня о технике, упражнениях или плане!")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textPrimary)
                    .lineSpacing(3)
            }
            .padding(14)
            .background(Theme.cardBackground)
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(coach.accentColor.opacity(0.2), lineWidth: 1)
            )
            
            Spacer()
        }
    }
    
    // MARK: - Бабл сообщения
    
    private func chatBubble(for msg: AICoachChatMessage) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if msg.isUser {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(msg.text)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .lineSpacing(3)
                        .padding(14)
                        .background(
                            LinearGradient(
                                colors: [coach.accentColor, coach.accentColor.opacity(0.75)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(18)
                }
            } else {
                Image(coach.avatarAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 38, height: 38)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(coach.accentColor, lineWidth: 1.5))
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Тренер \(coach.name)")
                            .font(.caption2)
                            .bold()
                            .foregroundColor(coach.accentColor)
                        
                        if let provider = msg.provider {
                            Text("• \(provider)")
                                .font(.caption2)
                                .foregroundColor(Theme.textSecondary)
                        }
                        
                        Spacer()
                        
                        // Кнопка озвучки
                        Button(action: {
                            toggleSpeech(for: msg)
                        }) {
                            Image(systemName: isSpeakingMessageId == msg.id ? "speaker.wave.3.fill" : "speaker.wave.2")
                                .font(.caption)
                                .foregroundColor(isSpeakingMessageId == msg.id ? coach.accentColor : Theme.textSecondary)
                                .padding(4)
                        }
                    }
                    
                    Text(msg.text)
                        .font(.system(size: 14))
                        .foregroundColor(Theme.textPrimary)
                        .lineSpacing(3)
                }
                .padding(14)
                .background(Theme.cardBackground)
                .cornerRadius(18)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                
                Spacer()
            }
        }
    }
    
    // MARK: - Нижняя панель ввода
    
    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Спросить тренера \(coach.name)...", text: $inputText, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.08))
                .cornerRadius(20)
                .foregroundColor(Theme.textPrimary)
            
            Button(action: {
                guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                let text = inputText
                inputText = ""
                sendMessage(text)
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 34))
                    .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Theme.textSecondary.opacity(0.5) : coach.accentColor)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Theme.cardBackground.ignoresSafeArea())
    }
    
    // MARK: - Логика отправки сообщения
    
    private func sendMessage(_ text: String) {
        let userMsg = AICoachChatMessage(isUser: true, text: text, provider: nil)
        messages.append(userMsg)
        isLoading = true
        errorMessage = nil
        
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        let weight = health.currentWeight > 0 ? health.currentWeight : userWeight
        let goal = userTargetWeight < weight ? "Похудение и рельеф" : (userTargetWeight > weight ? "Набор мышечной массы" : "Поддержание формы")
        
        let workoutSummary = health.todaysWorkouts.map { "\($0.activityType.name): \(Int($0.duration / 60)) мин, \($0.calories) ккал" }.joined(separator: ", ")
        
        Task {
            do {
                let result = try await GeminiScanService.shared.askCoach(
                    userQuestion: text,
                    coach: coach,
                    todaySteps: health.stepCountToday,
                    activeCalories: health.activeEnergyBurned,
                    currentHeartRate: health.currentHeartRate,
                    restingHeartRate: health.restingHeartRate,
                    sleepHours: health.sleepHoursLastNight,
                    workoutHistorySummary: workoutSummary,
                    userWeight: weight,
                    userGoal: goal,
                    language: appLanguage
                )
                
                await MainActor.run {
                    let coachMsg = AICoachChatMessage(isUser: false, text: result.answer, provider: result.provider)
                    self.messages.append(coachMsg)
                    self.isLoading = false
                    
                    let successImpact = UINotificationFeedbackGenerator()
                    successImpact.notificationOccurred(.success)
                    
                    if voiceCoachEnabled {
                        FormaVoiceCoachManager.shared.speak(result.answer, coach: coach, language: appLanguage)
                        self.isSpeakingMessageId = coachMsg.id
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func toggleSpeech(for msg: AICoachChatMessage) {
        if isSpeakingMessageId == msg.id {
            FormaVoiceCoachManager.shared.resetForNewWorkout()
            isSpeakingMessageId = nil
        } else {
            FormaVoiceCoachManager.shared.speak(msg.text, coach: coach, language: appLanguage)
            isSpeakingMessageId = msg.id
        }
    }
}

// MARK: - Вспомогательная пилюля биометрии
private struct BiometricPill: View {
    let icon: String
    let color: Color
    let title: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.06))
        .cornerRadius(10)
    }
}
