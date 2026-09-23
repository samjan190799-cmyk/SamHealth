import SwiftUI

@MainActor
public struct PanicSOSBreathingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var habitsManager = HabitsManager.shared
    @ObservedObject var coachManager = AICoachManager.shared
    @AppStorage("app_language") private var appLanguage = "ru"
    
    let habit: HabitItem
    
    @State private var selectedTrigger: String = "Стресс"
    @State private var breathingPhase: BreathingPhase = .inhale
    @State private var phaseSecondsRemaining: Int = 4
    @State private var phaseProgress: Double = 0.0 // 0.0 -> 1.0
    @State private var totalRemainingSeconds: Int = 60
    @State private var isRunning = true
    @State private var circleScale: CGFloat = 0.85
    @State private var timerSubscription: Timer? = nil
    @State private var hasCompletedSession = false
    @State private var isMuted: Bool = false
    
    private let triggers = ["Стресс ⚡", "Скука 🥱", "За компьютером 💻", "Тревога 🌊", "Рутина 🔄"]
    
    private enum BreathingPhase: String {
        case inhale = "Вдох"
        case holdIn = "Задержка"
        case exhale = "Выдох"
        case holdOut = "Пауза"
        
        var next: BreathingPhase {
            switch self {
            case .inhale: return .holdIn
            case .holdIn: return .exhale
            case .exhale: return .holdOut
            case .holdOut: return .inhale
            }
        }
        
        var instruction: String {
            switch self {
            case .inhale: return "Медленно вдыхайте носом"
            case .holdIn: return "Держите воздух, расслабьте плечи"
            case .exhale: return "Плавный выдох через рот"
            case .holdOut: return "Спокойная пауза"
            }
        }
        
        var icon: String {
            switch self {
            case .inhale: return "arrow.up.circle.fill"
            case .holdIn: return "pause.circle.fill"
            case .exhale: return "arrow.down.circle.fill"
            case .holdOut: return "shield.fill"
            }
        }
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 22) {
                        
                        // Шапка привычки
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(habit.color.opacity(0.18))
                                    .frame(width: 44, height: 44)
                                Image(systemName: habit.icon)
                                    .font(.title3.bold())
                                    .foregroundColor(habit.color)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Кнопка выдержки 🛡️")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Theme.moveColor)
                                Text(habit.title)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(Theme.textPrimary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        
                        // Статистика сохраненных ресурсов и побед
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Image(systemName: "banknote.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                    Text("Сэкономлено")
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                }
                                Text("\(Int(habit.totalMoneySaved)) ₽")
                                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.green.opacity(0.2), lineWidth: 1)
                            )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Image(systemName: "shield.checkered")
                                        .foregroundColor(Theme.moveColor)
                                        .font(.caption)
                                    Text("Отражено тяг")
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                }
                                Text("\(habit.urgeResistedCount) раз")
                                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Theme.moveColor.opacity(0.1))
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Theme.moveColor.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal)
                        
                        // Выбор триггера
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Что вызвало импульс сейчас?")
                                .font(.caption.bold())
                                .foregroundColor(Theme.textSecondary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(triggers, id: \.self) { trg in
                                        Button(action: {
                                            selectedTrigger = trg
                                            HapticManager.shared.selection()
                                        }) {
                                            Text(trg)
                                                .font(.system(size: 13, weight: .semibold))
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(selectedTrigger == trg ? habit.color.opacity(0.2) : Color.primary.opacity(0.05))
                                                .foregroundColor(selectedTrigger == trg ? habit.color : Theme.textPrimary)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(selectedTrigger == trg ? habit.color : Color.clear, lineWidth: 1.5)
                                                )
                                                .cornerRadius(12)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // ИНТЕРАКТИВНЫЙ ТАЙМЕР-КРУГ С АКТИВНЫМ СЧЕТЧИКОМ (Box Breathing)
                        VStack(spacing: 18) {
                            ZStack {
                                // 1. Фоновая круговая направляющая
                                Circle()
                                    .stroke(Color.primary.opacity(0.06), lineWidth: 10)
                                    .frame(width: 220, height: 220)
                                
                                // 2. Анимированный прогресс-бар такта дыхания (0-4 сек)
                                Circle()
                                    .trim(from: 0, to: CGFloat(phaseProgress))
                                    .stroke(
                                        habit.color,
                                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                                    )
                                    .frame(width: 220, height: 220)
                                    .rotationEffect(.degrees(-90))
                                    .animation(.linear(duration: 0.1), value: phaseProgress)
                                
                                // 3. Пульсирующее тело круга дыхания
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [habit.color.opacity(0.35), habit.color.opacity(0.08)],
                                            center: .center,
                                            startRadius: 20,
                                            endRadius: 100
                                        )
                                    )
                                    .frame(width: 190, height: 190)
                                    .scaleEffect(circleScale)
                                    .animation(.easeInOut(duration: 4.0), value: circleScale)
                                
                                // 4. Контент внутри круга: Крупный счетчик и фаза
                                VStack(spacing: 4) {
                                    Image(systemName: breathingPhase.icon)
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(habit.color)
                                    
                                    Text("\(phaseSecondsRemaining)")
                                        .font(.system(size: 48, weight: .heavy, design: .rounded))
                                        .foregroundColor(Theme.textPrimary)
                                        .contentTransition(.numericText())
                                    
                                    Text(breathingPhase.rawValue)
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(habit.color)
                                    
                                    Text(breathingPhase.instruction)
                                        .font(.system(size: 10))
                                        .foregroundColor(Theme.textSecondary)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: 140)
                                }
                            }
                            .frame(height: 240)
                            
                            // Общий таймер сессии
                            HStack(spacing: 6) {
                                Image(systemName: "timer")
                                    .foregroundColor(Theme.textSecondary)
                                Text("Осталось: \(totalRemainingSeconds) сек фокуса")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(Theme.textPrimary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.primary.opacity(0.05))
                            .cornerRadius(10)
                        }
                        .premiumCard()
                        .padding(.horizontal)
                        
                        // Мгновенные микро-замещения дофамина («Правило 2 минут»)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Image(systemName: "bolt.heart.fill")
                                    .foregroundColor(.orange)
                                Text("Мгновенные микро-замещения")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Theme.textPrimary)
                            }
                            
                            Text("Переключите фокус здоровым действием прямо сейчас:")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                            
                            HStack(spacing: 10) {
                                Button(action: {
                                    HealthKitManager.shared.addWater(milliliters: 250)
                                    finishAndLogVictory(extraReason: "Выпил стакан воды 💧")
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "drop.fill")
                                            .foregroundColor(.cyan)
                                            .font(.headline)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Стакан воды")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(Theme.textPrimary)
                                            Text("+250 мл • Освежись")
                                                .font(.caption2)
                                                .foregroundColor(.cyan)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 10)
                                    .background(Color.cyan.opacity(0.12))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Button(action: {
                                    GamificationManager.shared.addXP(15, reason: "15 приседаний вместо срыва ⚡")
                                    finishAndLogVictory(extraReason: "15 приседаний ⚡")
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "figure.cross.training")
                                            .foregroundColor(.orange)
                                            .font(.headline)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("15 приседаний")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(Theme.textPrimary)
                                            Text("+15 XP • Дофамин")
                                                .font(.caption2)
                                                .foregroundColor(.orange)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 10)
                                    .background(Color.orange.opacity(0.12))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(14)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(16)
                        .padding(.horizontal)
                        
                        // Динамический мотивационный совет ИИ-Коуча
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.title3)
                                .foregroundColor(Theme.aiAccent)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Совет ИИ-Коуча")
                                    .font(.caption.bold())
                                    .foregroundColor(Theme.aiAccent)
                                Text("Стрик чистых дней: \(habit.cleanStreakDays) дн. Острый импульс длится всего 90 секунд — после дыхания желание сорваться на «\(habit.title.lowercased())» угаснет. Вы полностью контролируете свои действия!")
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.textPrimary)
                                    .lineSpacing(3)
                            }
                        }
                        .padding(14)
                        .background(Theme.aiAccent.opacity(0.1))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Theme.aiAccent.opacity(0.25), lineWidth: 1)
                        )
                        .padding(.horizontal)
                        
                        // Кнопка победы «Я сдержался!»
                        Button(action: {
                            finishAndLogVictory()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.shield.fill")
                                    .font(.headline)
                                Text("Я сдержался! 🛡️ (+15 XP)")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .foregroundColor(.white)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 16/255, green: 185/255, blue: 129/255), Color(red: 5/255, green: 150/255, blue: 105/255)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.3), radius: 10, y: 4)
                        }
                        .buttonStyle(AppleDesignAwardsButtonStyle(scaleAmount: 0.96))
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Фокус и выдержка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        isMuted.toggle()
                        if isMuted {
                            FormaVoiceCoachManager.shared.stopSpeaking()
                        } else {
                            speakCoachMotivation()
                        }
                        HapticManager.shared.selection()
                    }) {
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .foregroundColor(isMuted ? Theme.textSecondary : Theme.aiAccent)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") {
                        stopTimer()
                        FormaVoiceCoachManager.shared.stopSpeaking()
                        dismiss()
                    }
                    .font(.body.bold())
                    .foregroundColor(Theme.textPrimary)
                }
            }
            .onAppear {
                startBreathingCycle()
                speakCoachMotivation()
            }
            .onDisappear {
                stopTimer()
                FormaVoiceCoachManager.shared.stopSpeaking()
            }
        }
    }
    
    // MARK: - Голосовой коуч
    
    private func speakCoachMotivation() {
        guard !isMuted else { return }
        let speechText: String
        if appLanguage == "ru" {
            speechText = "Дыши спокойно. Острый импульс длится всего девяносто секунд. Ты сильнее сиюминутного желания. Я с тобой!"
        } else {
            speechText = "Breathe steadily. The acute urge lasts only 90 seconds. You are stronger than this craving. I am with you!"
        }
        FormaVoiceCoachManager.shared.speakDirectly(speechText, coach: coachManager.currentCoach, language: appLanguage)
    }
    
    // MARK: - Логика таймера и дыхания (высокоточный такт 0.1 сек)
    
    private func startBreathingCycle() {
        stopTimer()
        circleScale = 1.15
        var subSecondsElapsed: Double = 0.0
        
        timerSubscription = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                guard timerSubscription != nil else { return }
                subSecondsElapsed += 0.1
                
                // Каждую 1 секунду
                if Int(subSecondsElapsed * 10) % 10 == 0 {
                    if totalRemainingSeconds > 0 {
                        totalRemainingSeconds -= 1
                    }
                    if phaseSecondsRemaining > 1 {
                        phaseSecondsRemaining -= 1
                        HapticManager.shared.selection()
                    }
                }
                
                // Прогресс текущей фазы (4 секунды)
                let phaseTime = subSecondsElapsed.truncatingRemainder(dividingBy: 4.0)
                phaseProgress = min(1.0, phaseTime / 4.0)
                
                // Переключение фазы каждые 4 секунды
                if subSecondsElapsed >= 4.0 {
                    subSecondsElapsed = 0.0
                    phaseSecondsRemaining = 4
                    phaseProgress = 0.0
                    breathingPhase = breathingPhase.next
                    
                    switch breathingPhase {
                    case .inhale:
                        withAnimation(.easeInOut(duration: 4.0)) {
                            circleScale = 1.15
                        }
                        HapticManager.shared.impact(.medium)
                    case .holdIn:
                        HapticManager.shared.impact(.light)
                    case .exhale:
                        withAnimation(.easeInOut(duration: 4.0)) {
                            circleScale = 0.75
                        }
                        HapticManager.shared.impact(.medium)
                    case .holdOut:
                        HapticManager.shared.impact(.light)
                    }
                }
            }
        }
    }
    
    private func stopTimer() {
        timerSubscription?.invalidate()
        timerSubscription = nil
    }
    
    private func finishAndLogVictory(extraReason: String? = nil) {
        stopTimer()
        FormaVoiceCoachManager.shared.stopSpeaking()
        let fullReason: String
        if let extra = extraReason {
            fullReason = "\(selectedTrigger) • \(extra)"
        } else {
            fullReason = selectedTrigger
        }
        habitsManager.logUrgeResisted(id: habit.id, triggerReason: fullReason)
        dismiss()
    }
}
