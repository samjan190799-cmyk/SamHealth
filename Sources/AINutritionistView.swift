import SwiftUI

public struct NutritionistChatMessage: Identifiable, Equatable {
    public let id: String = UUID().uuidString
    public let isUser: Bool
    public let text: String
    public let provider: String?
    public let timestamp: Date = Date()
}

public struct AINutritionistView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var health: HealthKitManager
    
    @AppStorage("app_language") private var appLanguage = "ru"
    @AppStorage("user_weight") private var userWeight = 75.0
    @AppStorage("user_target_weight") private var userTargetWeight = 70.0
    @AppStorage("user_activity_level") private var userActivityLevel = "Средняя"
    @AppStorage("user_somatotype") private var userSomatotype = "mesomorph"
    @AppStorage("user_metabolism_speed") private var userMetabolismSpeed = "normal"
    
    @State private var messages: [NutritionistChatMessage] = []
    @State private var inputText: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    
    private let quickPrompts = [
        "🍲 Нужен ли моему ЖКТ суп или бульон сегодня?",
        "🥣 Оцени баланс твердой и жидкой пищи в моем рационе",
        "🧬 Какой рацион идеален под мой соматотип?",
        "⚖️ Сколько грамм жира я сегодня сбросил или набрал?",
        "🥗 Оцени качество и баланс БЖУ моего рациона за сегодня",
        "🥩 Как легко добрать норму белка сегодня?",
        "⚡ Что съесть за час до силовой тренировки?",
        "🍫 Как побороть вечернюю тягу к сладкому?",
        "💧 Сколько воды мне нужно пить при моих нагрузках?"
    ]
    
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
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Верхняя сводка за сегодня
                    todaySummaryHeader
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Лента сообщений
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 16) {
                                // Приветственное сообщение
                                welcomeBubble
                                
                                ForEach(messages) { msg in
                                    chatBubble(for: msg)
                                        .id(msg.id)
                                }
                                
                                if isLoading {
                                    HStack(spacing: 8) {
                                        ProgressView()
                                            .tint(Color(red: 0/255, green: 229/255, blue: 255/255))
                                        Text("AI-Нутрициолог составляет персональный ответ...")
                                            .font(.caption)
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                    .padding()
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
                                withAnimation {
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
                    
                    // Быстрые подсказки
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
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(Color.white.opacity(0.06))
                                            .cornerRadius(20)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                            )
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 6)
                        }
                    }
                    
                    // Поле ввода
                    inputBar
                }
            }
            .navigationTitle("AI-Нутрициолог")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                    .foregroundColor(Theme.textPrimary)
                }
            }
        }
    }
    
    // Сводка за сегодня в шапке
    private var todaySummaryHeader: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                let somato = Somatotype(rawValue: userSomatotype) ?? .mesomorph
                NutriSummaryPill(
                    icon: "figure.arms.open",
                    title: "Тип",
                    value: "\(somato.emoji) \(somato.shortTitle)",
                    color: somato.accentColor
                )
                
                NutriSummaryPill(
                    icon: "fork.knife",
                    title: "Съедено",
                    value: "\(Int(health.caloriesConsumedToday)) ккал",
                    color: Theme.pulseColor
                )
                
                let bal = health.calorieBalance
                let balColor: Color = bal < -100 ? .green : (bal > 100 ? .orange : Theme.standColor)
                let balTitle = bal < 0 ? "Дефицит" : (bal > 0 ? "Профицит" : "Баланс")
                NutriSummaryPill(
                    icon: bal < 0 ? "flame.fill" : "bolt.fill",
                    title: balTitle,
                    value: "\(bal > 0 ? "+" : "")\(Int(bal)) ккал",
                    color: balColor
                )
                
                NutriSummaryPill(
                    icon: "shield.fill",
                    title: "Белок",
                    value: "\(Int(health.proteinConsumedToday)) г",
                    color: .green
                )
                
                NutriSummaryPill(
                    icon: "drop.fill",
                    title: "Вода",
                    value: "\(Int(health.waterConsumed)) мл",
                    color: Color(red: 0/255, green: 145/255, blue: 255/255)
                )
            }
        }
    }
    
    // Приветственное сообщение
    private var welcomeBubble: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "brain.head.profile")
                .foregroundColor(Color(red: 0/255, green: 229/255, blue: 255/255))
                .padding(8)
                .background(Color(red: 0/255, green: 229/255, blue: 255/255).opacity(0.15))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text("AI-Нутрициолог Forma")
                    .font(.caption)
                    .bold()
                    .foregroundColor(Color(red: 0/255, green: 229/255, blue: 255/255))
                
                Text("Привет! Я отслеживаю твой рацион за сегодня, баланс БЖУ, калорийный дефицит и качество продуктов. Спроси меня о калорийности, замене блюд или сколько жира ты сжег за сегодня!")
                    .font(.subheadline)
                    .foregroundColor(Theme.textPrimary)
                    .lineSpacing(3)
            }
            .padding(14)
            .background(Color.white.opacity(0.06))
            .cornerRadius(18)
            
            Spacer()
        }
    }
    
    // Пузырь сообщения
    private func chatBubble(for msg: NutritionistChatMessage) -> some View {
        HStack {
            if msg.isUser {
                Spacer()
                Text(msg.text)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Theme.exerciseColor)
                    .cornerRadius(18)
                    .frame(maxWidth: 280, alignment: .trailing)
            } else {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(Color(red: 0/255, green: 229/255, blue: 255/255))
                        .padding(6)
                        .background(Color(red: 0/255, green: 229/255, blue: 255/255).opacity(0.15))
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(msg.text)
                            .font(.subheadline)
                            .foregroundColor(Theme.textPrimary)
                            .lineSpacing(3)
                        
                        if let provider = msg.provider {
                            Text("Ответ сформирован: \(provider)")
                                .font(.system(size: 9))
                                .foregroundColor(Theme.textSecondary.opacity(0.7))
                                .padding(.top, 2)
                        }
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(18)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
            }
        }
    }
    
    // Панель ввода
    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Задайте вопрос нутрициологу...", text: $inputText)
                .font(.subheadline)
                .foregroundColor(Theme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.06))
                .cornerRadius(22)
            
            Button(action: {
                let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    sendMessage(text)
                    inputText = ""
                }
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 34))
                    .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Theme.textSecondary.opacity(0.3) : Theme.exerciseColor)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Theme.cardBackground.ignoresSafeArea())
    }
    
    private func sendMessage(_ text: String) {
        let userMsg = NutritionistChatMessage(isUser: true, text: text, provider: nil)
        messages.append(userMsg)
        isLoading = true
        errorMessage = nil
        
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        let weight = effectiveWeight
        let goal = userTargetWeight < weight ? "Похудение и рельеф" : (userTargetWeight > weight ? "Набор мышечной массы" : "Поддержание формы")
        
        Task {
            do {
                let result = try await GeminiScanService.shared.askNutritionist(
                    userQuestion: text,
                    caloriesConsumedToday: health.caloriesConsumedToday,
                    proteinConsumedToday: health.proteinConsumedToday,
                    fatConsumedToday: health.fatConsumedToday,
                    carbsConsumedToday: health.carbsConsumedToday,
                    waterConsumedToday: health.waterConsumed,
                    caloriesBurnedToday: health.activeEnergyBurned,
                    mealsSummary: health.mealsSummaryString,
                    calorieBalance: health.calorieBalance,
                    estimatedFatChangeGrams: health.estimatedFatChangeGrams,
                    userWeight: weight,
                    userGoal: goal,
                    userSomatotype: userSomatotype,
                    userMetabolismSpeed: userMetabolismSpeed,
                    digestiveBalanceSummary: health.digestiveBalanceSummary,
                    solidMealStreak: health.solidMealStreak,
                    language: appLanguage
                )
                
                await MainActor.run {
                    self.messages.append(NutritionistChatMessage(isUser: false, text: result.answer, provider: result.provider))
                    self.isLoading = false
                    let successImpact = UINotificationFeedbackGenerator()
                    successImpact.notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

// Мини-пилюля показателей в шапке
struct NutriSummaryPill: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textSecondary)
            }
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textPrimary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.04))
        .cornerRadius(14)
    }
}
