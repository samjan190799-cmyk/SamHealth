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
    @EnvironmentObject var stepManager: BackgroundStepManager
    
    @AppStorage("app_language") private var appLanguage = "ru"
    @AppStorage("user_weight") private var userWeight = 75.0
    @AppStorage("user_target_weight") private var userTargetWeight = 70.0
    @AppStorage("user_height") private var userHeight = 175
    @AppStorage("user_age") private var userAge = 25
    @AppStorage("user_gender") private var userGender = "Мужской"
    @AppStorage("user_activity_level") private var userActivityLevel = "Средняя"
    @AppStorage("user_somatotype") private var userSomatotype = "mesomorph"
    @AppStorage("user_metabolism_speed") private var userMetabolismSpeed = "normal"
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
    
    private var effectiveSteps: Int {
        max(stepManager.stepsToday, health.stepsToday)
    }
    
    private var effectiveWeight: Double {
        if health.currentWeight > 0 {
            return health.currentWeight
        }
        let savedHealthWeight = UserDefaults.standard.double(forKey: "health_user_weight")
        if savedHealthWeight > 0 {
            return savedHealthWeight
        }
        let savedUserWeight = UserDefaults.standard.double(forKey: "user_weight")
        if savedUserWeight > 0 {
            return savedUserWeight
        }
        return userWeight > 0 ? userWeight : 75.0
    }
    
    private let quickPrompts = [
        "🍲 Оцени баланс супов и плотной пищи в моем рационе",
        "🧬 Как питаться и тренироваться под мой соматотип?",
        "⚖️ Сколько я сегодня теоретически сбросил или набрал жира?",
        "🥗 Оцени мой рацион за сегодня и баланс калорий",
        "🦵 Чем заменить приседания и выпады, если ноют колени?",
        "😴 Спал меньше 6 часов, какую тренировку выбрать?",
        "🔥 Оцени мою активность и сожженные калории за сегодня",
        "🥩 Хватает ли мне белка для восстановления и формы?",
        "🏃‍♂️ Как держать правильный темп и пульс при беге?",
        "⏱️ Составь эффективную разминку на 5 минут"
    ]
    
    private func tr(_ key: String) -> String {
        LocalizationManager.tr(key, lang: appLanguage)
    }
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Верхняя карточка с биометрией за сегодня
                    headerCoachSummary
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                    
                    // Медицинский дисклеймер (Guideline 1.4.1)
                    medicalDisclaimerBanner
                    
                    Divider()
                        .background(Color.primary.opacity(0.08))
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
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 16)
                                    .background(Theme.cardBackground)
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                    )
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
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(Theme.textPrimary)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(Theme.cardBackground)
                                            .cornerRadius(18)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 18)
                                                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                                            )
                                            .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
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
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(Theme.textPrimary)
                            Text("\(coach.specialty) • Online")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(coach.accentColor)
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.textPrimary)
                            .frame(width: 30, height: 30)
                            .background(Theme.cardBackground)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.primary.opacity(0.12), lineWidth: 1))
                            .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
                    }
                }
            }
        }
    }
    
    // MARK: - Шапка биометрии за сегодня
    
    private var headerCoachSummary: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                AITrainerAvatarView(coachState: isLoading ? .exercising : .idle, size: 52, customCoach: coach)
                    .frame(width: 52, height: 52)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(coach.specialty)
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    Text(coach.tagline)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                }
                Spacer()
            }
            
            // Биометрические показатели
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    let somato = Somatotype(rawValue: userSomatotype) ?? .mesomorph
                    BiometricPill(icon: "figure.arms.open", color: somato.accentColor, title: "\(somato.emoji) \(somato.shortTitle)")
                    let calVal = health.activeEnergyBurned > 0 ? health.activeEnergyBurned : health.calculatedStepCalories
                    BiometricPill(icon: "scalemass.fill", color: .purple, title: "\(String(format: "%.1f", effectiveWeight)) кг")
                    BiometricPill(icon: "flame.fill", color: Theme.moveColor, title: "\(Int(calVal)) ккал")
                    BiometricPill(icon: "figure.walk", color: Theme.exerciseColor, title: "\(effectiveSteps) шаг")
                    BiometricPill(icon: "fork.knife", color: .green, title: "\(Int(health.caloriesConsumedToday)) ккал")
                    BiometricPill(icon: "heart.fill", color: Theme.pulseColor, title: health.heartRate > 0 ? "\(Int(health.heartRate)) уд" : "--")
                }
            }
        }
        .padding(12)
        .background(Theme.cardBackground)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
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
                    .font(.caption)
                    .bold()
                    .foregroundColor(coach.accentColor)
                
                Text(coach.localizedGreeting(lang: appLanguage) + "\n\nЯ учитываю твои шаги, тренировки, съеденные блюда, калорийный дефицит и качество сна. Спроси меня о рационе, технике или прогрессе!")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textPrimary)
                    .lineSpacing(3)
            }
            .padding(14)
            .background(Theme.cardBackground)
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(coach.accentColor.opacity(0.3), lineWidth: 1.2)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
            
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
                                colors: [coach.accentColor, coach.accentColor.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(18)
                        .shadow(color: coach.accentColor.opacity(0.25), radius: 6, x: 0, y: 2)
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
                            .font(.caption)
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
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                
                Spacer()
            }
        }
    }
    
    // Медицинский дисклеймер
    private var medicalDisclaimerBanner: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 13))
                .padding(.top, 1)
            Text("Медицинский дисклеймер: Forma не является медицинским сервисом. Советы тренера носят информационный характер. Перед интенсивными нагрузками проконсультируйтесь с врачом.")
                .font(.system(size: 10))
                .foregroundColor(Theme.textSecondary)
                .lineSpacing(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal)
        .padding(.bottom, 6)
    }
    
    // MARK: - Нижняя панель ввода
    
    private var inputBar: some View {
        VStack(spacing: 4) {
            HStack(spacing: 10) {
                TextField("Спросить тренера \(coach.name)...", text: $inputText, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    .foregroundColor(Theme.textPrimary)
                
                Button(action: {
                    guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    let text = inputText
                    inputText = ""
                    sendMessage(text)
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Theme.textSecondary.opacity(0.4) : coach.accentColor)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            }
            
            Text("Советы ИИ-тренера носят мотивационный характер и не являются медицинской консультацией.")
                .font(.system(size: 9))
                .foregroundColor(Theme.textSecondary.opacity(0.8))
                .padding(.top, 2)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(Theme.cardBackground.ignoresSafeArea(edges: .bottom))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.primary.opacity(0.08)),
            alignment: .top
        )
    }
    
    // MARK: - Логика отправки сообщения
    
    private func sendMessage(_ text: String) {
        let userMsg = AICoachChatMessage(isUser: true, text: text, provider: nil)
        messages.append(userMsg)
        isLoading = true
        errorMessage = nil
        
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        let weight = effectiveWeight
        let goal = userTargetWeight < weight 
            ? "Снижение веса и сжигание жира (Текущий вес: \(String(format: "%.1f", weight)) кг, Целевой вес: \(String(format: "%.1f", userTargetWeight)) кг, Осталось сбросить: \(String(format: "%.1f", weight - userTargetWeight)) кг)"
            : (userTargetWeight > weight 
                ? "Набор мышечной массы (Текущий вес: \(String(format: "%.1f", weight)) кг, Целевой вес: \(String(format: "%.1f", userTargetWeight)) кг, Набрать: \(String(format: "%.1f", userTargetWeight - weight)) кг)"
                : "Поддержание стабильного веса и рельефа (\(String(format: "%.1f", weight)) кг)")
        let activeCal = health.activeEnergyBurned > 0 ? health.activeEnergyBurned : health.calculatedStepCalories
        
        let workoutSummary = health.workoutHistory.prefix(3).map { "\($0.type): \($0.durationMinutes) мин, \(Int($0.caloriesBurned)) ккал" }.joined(separator: ", ")
        
        Task {
            do {
                let result = try await GeminiScanService.shared.askCoach(
                    userQuestion: text,
                    coach: coach,
                    todaySteps: effectiveSteps,
                    activeCalories: activeCal,
                    currentHeartRate: Int(health.heartRate),
                    restingHeartRate: Int(health.restingHeartRate),
                    sleepHours: health.todaySleepHours,
                    workoutHistorySummary: workoutSummary,
                    userWeight: weight,
                    userGoal: goal,
                    userHeight: userHeight,
                    userAge: userAge,
                    userGender: userGender,
                    caloriesConsumedToday: health.caloriesConsumedToday,
                    proteinConsumedToday: health.proteinConsumedToday,
                    fatConsumedToday: health.fatConsumedToday,
                    carbsConsumedToday: health.carbsConsumedToday,
                    mealsTodaySummary: health.mealsSummaryString,
                    calorieBalance: health.calorieBalance,
                    estimatedFatChangeGrams: health.estimatedFatChangeGrams,
                    userSomatotype: userSomatotype,
                    userMetabolismSpeed: userMetabolismSpeed,
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
        .background(Color.primary.opacity(0.05))
        .cornerRadius(10)
    }
}
