import SwiftUI

@MainActor
public struct PanicSOSBreathingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var habitsManager = HabitsManager.shared
    
    let habit: HabitItem
    
    @State private var selectedTrigger: String = "Стресс"
    @State private var breathingPhase: BreathingPhase = .inhale
    @State private var phaseTimer: Double = 4.0
    @State private var totalRemainingSeconds: Int = 60
    @State private var isRunning = true
    @State private var circleScale: CGFloat = 0.8
    @State private var timerSubscription: Timer? = nil
    @State private var hasCompletedSession = false
    
    private let triggers = ["Стресс ⚡", "Скука 🥱", "За компьютером 💻", "Тревога 🌊", "Рутина 🔄"]
    
    private enum BreathingPhase: String {
        case inhale = "Вдох (4 сек)"
        case holdIn = "Задержка (4 сек)"
        case exhale = "Выдох (4 сек)"
        case holdOut = "Покой (4 сек)"
        
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
            case .inhale: return "Медленно вдыхайте через нос..."
            case .holdIn: return "Держите дыхание, расслабьте плечи"
            case .exhale: return "Плавный выдох через рот..."
            case .holdOut: return "Спокойная пауза"
            }
        }
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        
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
                        
                        // Интерактивный дыхательный круг (Box Breathing)
                        VStack(spacing: 20) {
                            ZStack {
                                // Фоновые пульсирующие круги
                                Circle()
                                    .stroke(habit.color.opacity(0.15), lineWidth: 24)
                                    .frame(width: 220, height: 220)
                                    .scaleEffect(circleScale * 1.08)
                                
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [habit.color.opacity(0.35), habit.color.opacity(0.05)],
                                            center: .center,
                                            startRadius: 20,
                                            endRadius: 110
                                        )
                                    )
                                    .frame(width: 200, height: 200)
                                    .scaleEffect(circleScale)
                                    .animation(.easeInOut(duration: 4.0), value: circleScale)
                                
                                VStack(spacing: 6) {
                                    Image(systemName: "shield.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(habit.color)
                                    
                                    Text(breathingPhase.rawValue)
                                        .font(.system(size: 17, weight: .bold, design: .rounded))
                                        .foregroundColor(Theme.textPrimary)
                                    
                                    Text(breathingPhase.instruction)
                                        .font(.system(size: 11))
                                        .foregroundColor(Theme.textSecondary)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: 160)
                                }
                            }
                            .frame(height: 230)
                            
                            // Счетчик оставшегося времени фокуса
                            HStack(spacing: 6) {
                                Image(systemName: "timer")
                                    .foregroundColor(Theme.textSecondary)
                                Text("Осталось: \(totalRemainingSeconds) сек фокуса")
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        .premiumCard()
                        .padding(.horizontal)
                        
                        // Мотивационный совет ИИ-Коуча
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.title3)
                                .foregroundColor(Theme.aiAccent)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Совет ИИ-Коуча")
                                    .font(.caption.bold())
                                    .foregroundColor(Theme.aiAccent)
                                Text("Стрик чистых дней: \(habit.cleanStreakDays) дн. Импульс длится всего 90 секунд — после дыхания желание погрызть ногти угаснет. Вы контролируете свои руки!")
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
                            .padding(.vertical, 16)
                            .foregroundColor(.white)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 16/255, green: 185/255, blue: 129/255), Color(red: 5/255, green: 150/255, blue: 105/255)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(18)
                            .shadow(color: Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.3), radius: 10, y: 4)
                        }
                        .buttonStyle(AppleDesignAwardsButtonStyle(scaleAmount: 0.96))
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Фокус и выдержка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") {
                        stopTimer()
                        dismiss()
                    }
                    .font(.body.bold())
                    .foregroundColor(Theme.textPrimary)
                }
            }
            .onAppear {
                startBreathingCycle()
            }
            .onDisappear {
                stopTimer()
            }
        }
    }
    
    // MARK: - Логика таймера и дыхания
    
    private func startBreathingCycle() {
        circleScale = 1.15
        timerSubscription = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                if totalRemainingSeconds > 0 {
                    totalRemainingSeconds -= 1
                }
                
                phaseTimer -= 1.0
                if phaseTimer <= 0 {
                    phaseTimer = 4.0
                    breathingPhase = breathingPhase.next
                    
                    switch breathingPhase {
                    case .inhale:
                        withAnimation(.easeInOut(duration: 4.0)) {
                            circleScale = 1.15
                        }
                        HapticManager.shared.impact(.light)
                    case .holdIn:
                        HapticManager.shared.selection()
                    case .exhale:
                        withAnimation(.easeInOut(duration: 4.0)) {
                            circleScale = 0.75
                        }
                        HapticManager.shared.impact(.light)
                    case .holdOut:
                        HapticManager.shared.selection()
                    }
                }
            }
        }
    }
    
    private func stopTimer() {
        timerSubscription?.invalidate()
        timerSubscription = nil
    }
    
    private func finishAndLogVictory() {
        stopTimer()
        habitsManager.logUrgeResisted(id: habit.id, triggerReason: selectedTrigger)
        dismiss()
    }
}
