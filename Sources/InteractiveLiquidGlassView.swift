import SwiftUI

// MARK: - Интерактивный стакан с физикой двойной волны и жестами
public struct InteractiveLiquidGlassView: View {
    @EnvironmentObject var health: HealthKitManager
    
    // Параметры анимации волны
    @State private var wavePhaseFront: Double = 0.0
    @State private var wavePhaseBack: Double = 0.0
    @State private var waveTimer: Timer? = nil
    
    // Состояние жеста свайпа для долива воды
    @State private var dragOffset: CGFloat = 0.0
    @State private var isDragging: Bool = false
    @State private var dragVolumeChange: Int = 0
    @State private var lastFeedbackVolumeStep: Int = 0
    
    // Анимация всплеска
    @State private var splashScale: CGFloat = 1.0
    @State private var showingQuickFillToast: Bool = false
    
    // Пузырьки воздуха
    @State private var bubbles: [BubbleItem] = [
        BubbleItem(xPercent: 0.25, yPercent: 0.85, size: 5, speed: 2.2),
        BubbleItem(xPercent: 0.45, yPercent: 0.92, size: 7, speed: 2.7),
        BubbleItem(xPercent: 0.65, yPercent: 0.80, size: 4, speed: 1.9),
        BubbleItem(xPercent: 0.80, yPercent: 0.88, size: 6, speed: 2.4),
        BubbleItem(xPercent: 0.35, yPercent: 0.70, size: 5, speed: 2.1)
    ]
    
    public init() {}
    
    private var targetGoal: Double {
        max(health.dynamicWaterGoal, 1000.0)
    }
    
    private var currentProgress: Double {
        min(max(health.waterConsumed / targetGoal, 0.0), 1.5)
    }
    
    // Цвет жидкости адаптируется под последний выпитый напиток
    private var liquidThemeColors: (top: Color, bottom: Color) {
        if let lastBeverage = health.loggedBeveragesToday.last {
            switch lastBeverage.beverageType {
            case .water:
                return (Color(red: 0/255, green: 229/255, blue: 255/255), Color(red: 0/255, green: 135/255, blue: 255/255))
            case .coffee:
                return (Color(red: 195/255, green: 135/255, blue: 85/255), Color(red: 110/255, green: 65/255, blue: 30/255))
            case .tea:
                return (Color(red: 90/255, green: 215/255, blue: 140/255), Color(red: 45/255, green: 140/255, blue: 85/255))
            case .energyDrink:
                return (Color(red: 255/255, green: 200/255, blue: 50/255), Color(red: 220/255, green: 100/255, blue: 20/255))
            case .soda:
                return (Color(red: 235/255, green: 80/255, blue: 80/255), Color(red: 140/255, green: 30/255, blue: 40/255))
            case .juice:
                return (Color(red: 255/255, green: 165/255, blue: 45/255), Color(red: 215/255, green: 90/255, blue: 25/255))
            case .milk:
                return (Color(red: 245/255, green: 245/255, blue: 255/255), Color(red: 190/255, green: 205/255, blue: 230/255))
            case .isotonic:
                return (Color(red: 0/255, green: 240/255, blue: 210/255), Color(red: 0/255, green: 150/255, blue: 210/255))
            default:
                return (Color(red: 0/255, green: 229/255, blue: 255/255), Color(red: 0/255, green: 135/255, blue: 255/255))
            }
        }
        return (Color(red: 0/255, green: 229/255, blue: 255/255), Color(red: 0/255, green: 135/255, blue: 255/255))
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Заголовок интерактивного стакана
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "drop.degreesign.fill")
                        .font(.title3)
                        .foregroundColor(Color(red: 0/255, green: 220/255, blue: 255/255))
                    Text("Интерактивный стакан")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                }
                Spacer()
                
                // Подсказка жестов
                HStack(spacing: 4) {
                    Image(systemName: "hand.draw")
                        .font(.caption2)
                    Text("Свайп или 2× тап")
                        .font(.caption2)
                        .bold()
                }
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.06))
                .cornerRadius(8)
            }
            
            // Основной визуал стакана с физикой
            HStack(spacing: 24) {
                // Сам стакан с физикой жидкости и жестами
                ZStack {
                    glassCupBody
                        .frame(width: 110, height: 160)
                        .scaleEffect(splashScale)
                        .gesture(
                            DragGesture(minimumDistance: 10)
                                .onChanged { value in
                                    isDragging = true
                                    dragOffset = value.translation.height
                                    // Тянем вверх (-translation) -> добавляем воду
                                    let deltaSteps = Int(-dragOffset / 15.0)
                                    let calculatedDelta = deltaSteps * 50
                                    
                                    if calculatedDelta != dragVolumeChange {
                                        dragVolumeChange = max(0, min(1000, calculatedDelta))
                                        let currentStep = dragVolumeChange / 50
                                        if currentStep != lastFeedbackVolumeStep {
                                            lastFeedbackVolumeStep = currentStep
                                            let feedback = UISelectionFeedbackGenerator()
                                            feedback.selectionChanged()
                                        }
                                    }
                                }
                                .onEnded { _ in
                                    if dragVolumeChange > 0 {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                            health.addBeverage(type: .water, volumeMl: Double(dragVolumeChange))
                                            triggerSplashAnimation()
                                        }
                                        let haptic = UIImpactFeedbackGenerator(style: .medium)
                                        haptic.impactOccurred()
                                    }
                                    withAnimation(.easeOut(duration: 0.25)) {
                                        isDragging = false
                                        dragOffset = 0
                                        dragVolumeChange = 0
                                        lastFeedbackVolumeStep = 0
                                    }
                                }
                        )
                        .onTapGesture(count: 2) {
                            // Быстрый налив 250 мл по двойному тапу
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) {
                                health.addBeverage(type: .water, volumeMl: 250)
                                triggerSplashAnimation()
                                showingQuickFillToast = true
                            }
                            let haptic = UIImpactFeedbackGenerator(style: .heavy)
                            haptic.impactOccurred()
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                                withAnimation {
                                    showingQuickFillToast = false
                                }
                            }
                        }
                    
                    // Плавающий бейдж добавления при свайпе
                    if isDragging && dragVolumeChange > 0 {
                        VStack(spacing: 4) {
                            Text("+\(dragVolumeChange) мл")
                                .font(.system(size: 16, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                            Text("Отпустите для налива")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.cyan.opacity(0.6), lineWidth: 1.5)
                        )
                        .offset(y: -95)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                
                // Информационный блок рядом со стаканом
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Текущий уровень")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(Int(health.waterConsumed))")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.textPrimary)
                            Text("из \(Int(targetGoal)) мл")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                        
                        let percent = Int(min(currentProgress * 100.0, 100.0))
                        HStack(spacing: 6) {
                            Circle()
                                .fill(percent >= 100 ? Color.green : Color.cyan)
                                .frame(width: 8, height: 8)
                            Text("\(percent)% от нормы дня")
                                .font(.caption2)
                                .bold()
                                .foregroundColor(percent >= 100 ? .green : Theme.textPrimary)
                        }
                    }
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    // Быстрые порции в 1 тап
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Быстрый долив в 1 тап:")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Theme.textSecondary)
                        
                        HStack(spacing: 8) {
                            quickFillButton(amount: 150, label: "150")
                            quickFillButton(amount: 250, label: "250")
                            quickFillButton(amount: 350, label: "350")
                            quickFillButton(amount: 500, label: "500")
                        }
                    }
                }
            }
            .padding(.vertical, 4)
            
            // Тост подтверждения двойного тапа
            if showingQuickFillToast {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("+250 мл чистой воды добавлено!")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.75))
                .cornerRadius(20)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .premiumCard()
        .onAppear {
            startWaveAnimation()
        }
        .onDisappear {
            stopWaveAnimation()
        }
    }
    
    // MARK: - Тело стакана с двойной синусоидальной волной и стеклянной рамкой
    private var glassCupBody: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let visualProgress = min(max(currentProgress + Double(dragVolumeChange) / targetGoal, 0.0), 1.0)
            let fillHeight = CGFloat(visualProgress) * (h - 14)
            
            ZStack(alignment: .bottom) {
                // 1. Задний фон пустого стакана
                GlassCupShape()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.06), Color.white.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                // 2. Жидкость внутри с маской по форме стакана
                if visualProgress > 0.01 {
                    ZStack(alignment: .bottom) {
                        // Задняя полупрозрачная волна (противофаза для объема)
                        WavePhysicsShape(phase: wavePhaseBack, amplitude: 3.5)
                            .fill(liquidThemeColors.bottom.opacity(0.45))
                            .frame(height: fillHeight + 5)
                            .offset(y: -fillHeight)
                        
                        // Передняя яркая волна
                        WavePhysicsShape(phase: wavePhaseFront, amplitude: 4.5)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        liquidThemeColors.top.opacity(0.9),
                                        liquidThemeColors.bottom.opacity(0.75)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: fillHeight)
                            .offset(y: -fillHeight)
                        
                        // Пузырьки воздуха в толще воды
                        ForEach(0..<bubbles.count, id: \.self) { idx in
                            let b = bubbles[idx]
                            Circle()
                                .fill(Color.white.opacity(0.45))
                                .frame(width: b.size, height: b.size)
                                .position(
                                    x: w * b.xPercent,
                                    y: h - (fillHeight * b.yPercent)
                                )
                        }
                    }
                    .frame(width: w, height: h, alignment: .bottom)
                    .mask(GlassCupShape())
                }
                
                // 3. Градуировочные риски объема на стекле (100, 250, 500 мл)
                VStack {
                    Spacer()
                    ForEach([0.75, 0.5, 0.25], id: \.self) { fraction in
                        HStack {
                            Rectangle()
                                .fill(Color.white.opacity(0.25))
                                .frame(width: 8, height: 1)
                            Spacer()
                            Rectangle()
                                .fill(Color.white.opacity(0.25))
                                .frame(width: 8, height: 1)
                        }
                        .padding(.horizontal, 10)
                        Spacer().frame(height: (h - 20) * 0.22)
                    }
                }
                .mask(GlassCupShape())
                
                // 4. Стеклянный контур стакана
                GlassCupShape()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.75),
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2.2
                    )
                
                // 5. Блик света на левой грани стекла
                Path { p in
                    p.move(to: CGPoint(x: 10, y: 15))
                    p.addLine(to: CGPoint(x: 16, y: h - 25))
                }
                .stroke(Color.white.opacity(0.4), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .blur(radius: 0.5)
            }
        }
    }
    
    // MARK: - Кнопка быстрого добавления порции
    private func quickFillButton(amount: Int, label: String) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                health.addBeverage(type: .water, volumeMl: Double(amount))
                triggerSplashAnimation()
            }
            let haptic = UIImpactFeedbackGenerator(style: .medium)
            haptic.impactOccurred()
        }) {
            Text("+\(label)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.cyan)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.cyan.opacity(0.12))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.cyan.opacity(0.25), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Вспомогательные анимации
    private func triggerSplashAnimation() {
        splashScale = 1.06
        withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
            splashScale = 1.0
        }
    }
    
    private func startWaveAnimation() {
        waveTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { _ in
            wavePhaseFront += 0.08
            wavePhaseBack += 0.05
            if wavePhaseFront > .pi * 2 { wavePhaseFront -= .pi * 2 }
            if wavePhaseBack > .pi * 2 { wavePhaseBack -= .pi * 2 }
        }
    }
    
    private func stopWaveAnimation() {
        waveTimer?.invalidate()
        waveTimer = nil
    }
}

// MARK: - Модель пузырька
struct BubbleItem {
    let xPercent: CGFloat
    let yPercent: CGFloat
    let size: CGFloat
    let speed: CGFloat
}

// MARK: - Физическая форма волны
struct WavePhysicsShape: Shape {
    var phase: Double
    var amplitude: CGFloat
    
    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        path.move(to: CGPoint(x: 0, y: height))
        
        for x in stride(from: 0, to: width + 2, by: 2) {
            let relativeX = x / width
            let sine = sin(relativeX * .pi * 2 + phase)
            let y = amplitude * sine
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()
        
        return path
    }
}
