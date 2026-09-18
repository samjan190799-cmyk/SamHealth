import SwiftUI
import CoreMotion

// MARK: - Интерактивный стакан с физикой наклона CoreMotion, выливанием воды и пасхалкой
@MainActor
public struct InteractiveLiquidGlassView: View {
    @EnvironmentObject var health: HealthKitManager
    @ObservedObject private var tiltManager = DeviceTiltManager.shared
    
    // Сенсорный наклон пальцем (для симулятора или удобства на столе)
    @State private var touchTilt: Double = 0.0
    
    // Фаза непрерывной анимации волны (без фоновых таймеров на главном потоке)
    @State private var wavePhaseFront: Double = 0.0
    @State private var wavePhaseBack: Double = 0.0
    
    // Состояние вертикального жеста свайпа для долива воды
    @State private var dragOffset: CGFloat = 0.0
    @State private var isDraggingVertical: Bool = false
    @State private var dragVolumeChange: Int = 0
    @State private var lastFeedbackVolumeStep: Int = 0
    
    // Анимация всплеска
    @State private var splashScale: CGFloat = 1.0
    @State private var showingQuickFillToast: Bool = false
    
    // Оптимизированная физика выливания с локальным буфером
    @State private var isSpilling: Bool = false
    @State private var spillTimer: Timer? = nil
    @State private var accumulatedSpillMl: Double = 0.0
    @State private var localVisualSpillOffset: Double = 0.0
    @State private var lastSpillFlushTime: Date = Date()
    
    // Пасхалка с уточкой 🦆
    @State private var duckQuackToast: String? = nil
    @State private var duckFlipDegrees: Double = 0.0
    @State private var duckDiving: Bool = false
    
    // Статический пул пузырьков воздуха (без динамических аллокаций)
    private let bubbles: [BubbleItem] = [
        BubbleItem(xPercent: 0.25, yPercent: 0.85, size: 5, speed: 2.2),
        BubbleItem(xPercent: 0.45, yPercent: 0.92, size: 7, speed: 2.7),
        BubbleItem(xPercent: 0.65, yPercent: 0.80, size: 4, speed: 1.9),
        BubbleItem(xPercent: 0.80, yPercent: 0.88, size: 6, speed: 2.4),
        BubbleItem(xPercent: 0.35, yPercent: 0.70, size: 5, speed: 2.1)
    ]
    
    public init() {}
    
    // MARK: - Вычисляемый эффективный наклон (-1.0 ... 1.0)
    private var effectiveTilt: Double {
        let sensorTilt = tiltManager.tiltX
        let combined = (sensorTilt * 0.95) + touchTilt
        return min(max(combined, -1.25), 1.25)
    }
    
    /// Угол наклона самого стакана (до ~32 градусов)
    private var cupRotationAngle: Angle {
        Angle(degrees: effectiveTilt * 28.0)
    }
    
    /// Угол наклона зеркала воды относительно стакана (в противоположную сторону)
    private var liquidSurfaceAngle: Double {
        -effectiveTilt * 0.45
    }
    
    private var targetGoal: Double {
        max(health.dynamicWaterGoal, 1000.0)
    }
    
    /// Текущий прогресс с учетом мгновенного локального выливания без лагов
    private var currentProgress: Double {
        let effectiveConsumed = max(0.0, health.waterConsumed - localVisualSpillOffset)
        return min(max(effectiveConsumed / targetGoal, 0.0), 1.5)
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
        VStack(spacing: 14) {
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
                
                // Индикатор гироскопа и подсказка жестов
                HStack(spacing: 5) {
                    Image(systemName: tiltManager.isMonitoring ? "gyroscope" : "hand.draw")
                        .font(.caption2)
                        .foregroundColor(.cyan)
                    Text(tiltManager.isMonitoring ? "Наклоняй iPhone" : "Свайп / Наклон")
                        .font(.caption2)
                        .bold()
                }
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.06))
                .cornerRadius(8)
            }
            
            // Основной визуал стакана с физикой наклона и брызг
            HStack(spacing: 20) {
                // Область стакана
                ZStack {
                    // Высокопроизводительные анимированные брызги без аллокаций
                    if isSpilling {
                        SpillParticlesOverlay(isLeft: effectiveTilt < 0, color: liquidThemeColors.top)
                    }
                    
                    // Струя льющейся воды при выливании
                    if isSpilling && (health.waterConsumedToday - localVisualSpillOffset) > 0 {
                        spillStreamOverlay
                    }
                    
                    // Сам стакан с физикой наклона и жестами
                    glassCupBody
                        .frame(width: 110, height: 160)
                        .rotationEffect(cupRotationAngle, anchor: .bottom)
                        .scaleEffect(splashScale)
                        .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.8), value: effectiveTilt)
                        .gesture(
                            DragGesture(minimumDistance: 5)
                                .onChanged { value in
                                    let hTrans = value.translation.width
                                    let vTrans = value.translation.height
                                    
                                    // Если тянем преимущественно по горизонтали -> наклоняем стакан
                                    if abs(hTrans) > abs(vTrans) && !isDraggingVertical {
                                        touchTilt = Double(hTrans / 90.0).clamped(to: -1.2...1.2)
                                        checkSpillCondition()
                                    } else {
                                        // Вертикальный жест добавления воды
                                        isDraggingVertical = true
                                        dragOffset = vTrans
                                        let deltaSteps = Int(-dragOffset / 15.0)
                                        let calculatedDelta = deltaSteps * 50
                                        
                                        if calculatedDelta != dragVolumeChange {
                                            dragVolumeChange = max(0, min(1000, calculatedDelta))
                                            let currentStep = dragVolumeChange / 50
                                            if currentStep != lastFeedbackVolumeStep {
                                                lastFeedbackVolumeStep = currentStep
                                                HapticManager.shared.selection()
                                            }
                                        }
                                    }
                                }
                                .onEnded { _ in
                                    if dragVolumeChange > 0 {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                            health.addBeverage(type: .water, volumeMl: Double(dragVolumeChange))
                                            triggerSplashAnimation()
                                        }
                                        HapticManager.shared.impact(.medium)
                                    }
                                    
                                    // Плавный возврат в исходное положение
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                        touchTilt = 0.0
                                        isDraggingVertical = false
                                        dragOffset = 0
                                        dragVolumeChange = 0
                                        lastFeedbackVolumeStep = 0
                                    }
                                    stopSpilling()
                                }
                        )
                        .onTapGesture(count: 2) {
                            // Быстрый налив 250 мл по двойному тапу
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) {
                                health.addBeverage(type: .water, volumeMl: 250)
                                triggerSplashAnimation()
                                showingQuickFillToast = true
                            }
                            HapticManager.shared.impact(.heavy)
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                                withAnimation {
                                    showingQuickFillToast = false
                                }
                            }
                        }
                    
                    // Плавающий бейдж добавления при свайпе вверх
                    if isDraggingVertical && dragVolumeChange > 0 {
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
                        .background(Color.black.opacity(0.85))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.cyan.opacity(0.7), lineWidth: 1.5)
                        )
                        .offset(y: -100)
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    // Облачко реплики уточки 🦆
                    if let toast = duckQuackToast {
                        Text(toast)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.85))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.yellow.opacity(0.8), lineWidth: 1.5)
                            )
                            .offset(y: -95)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: 140, height: 175)
                
                // Информационный блок рядом со стаканом
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Текущий уровень")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(Int(max(0.0, health.waterConsumed - localVisualSpillOffset)))")
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
                        
                        HStack(spacing: 6) {
                            quickFillButton(amount: 150, label: "150")
                            quickFillButton(amount: 250, label: "250")
                            quickFillButton(amount: 350, label: "350")
                        }
                    }
                    
                    // Кнопка восстановления вылитой воды
                    if health.sessionSpilledWaterMl > 0 {
                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                health.restoreSpilledWater()
                                triggerSplashAnimation()
                                showDuckToast("Вода вернулась! Ура! 💦🦆")
                            }
                            HapticManager.shared.impact(.medium)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.uturn.backward.circle.fill")
                                Text("Вернуть \(Int(health.sessionSpilledWaterMl)) мл")
                            }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.yellow)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.yellow.opacity(0.15))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.yellow.opacity(0.4), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(.vertical, 2)
            
            // Предупреждение о выливании
            if isSpilling {
                HStack(spacing: 6) {
                    Image(systemName: "drop.triangle.fill")
                        .foregroundColor(.yellow)
                    Text("Осторожно, вода выливается из стакана! 🌊")
                        .font(.caption2)
                        .bold()
                        .foregroundColor(.yellow)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.yellow.opacity(0.12))
                .cornerRadius(8)
                .transition(.opacity)
            }
            
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
            tiltManager.startMonitoring()
            startDeclarativeWaves()
        }
        .onDisappear {
            tiltManager.stopMonitoring()
            stopSpilling()
        }
        .onChange(of: tiltManager.tiltX) { _ in
            checkSpillCondition()
        }
    }
    
    // MARK: - Тело стакана с физикой волны, наклоном зеркала воды и уточки
    private var glassCupBody: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let visualProgress = min(max(currentProgress + Double(dragVolumeChange) / targetGoal, 0.0), 1.0)
            let fillHeight = CGFloat(visualProgress) * (h - 16)
            
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
                
                // 2. Жидкость внутри с маской по форме стакана (Metal GPU рендеринг)
                if visualProgress > 0.01 {
                    ZStack(alignment: .bottom) {
                        // Задняя волна (противофаза для объемного преломления)
                        TiltedWavePhysicsShape(
                            phase: wavePhaseBack,
                            amplitude: 3.2,
                            tiltAngle: liquidSurfaceAngle
                        )
                        .fill(liquidThemeColors.bottom.opacity(0.45))
                        .frame(height: fillHeight + 8)
                        .offset(y: -fillHeight)
                        
                        // Передняя яркая волна с физическим наклоном уровня
                        TiltedWavePhysicsShape(
                            phase: wavePhaseFront,
                            amplitude: 4.0,
                            tiltAngle: liquidSurfaceAngle
                        )
                        .fill(
                            LinearGradient(
                                colors: [
                                    liquidThemeColors.top.opacity(0.92),
                                    liquidThemeColors.bottom.opacity(0.78)
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
                            let bubbleXShift = CGFloat(effectiveTilt) * 14.0 * (1.0 - b.yPercent)
                            Circle()
                                .fill(Color.white.opacity(0.48))
                                .frame(width: b.size, height: b.size)
                                .position(
                                    x: (w * b.xPercent + bubbleXShift).clamped(to: 12...(w - 12)),
                                    y: h - (fillHeight * b.yPercent)
                                )
                        }
                    }
                    .frame(width: w, height: h, alignment: .bottom)
                    .mask(GlassCupShape())
                }
                
                // 3. Желтая резиновая уточка 🦆
                duckCompanionView(glassWidth: w, glassHeight: h, fillHeight: fillHeight, hasWater: visualProgress > 0.02)
                    .mask(GlassCupShape())
                
                // 4. Градуировочные риски объема на стекле
                VStack {
                    Spacer()
                    ForEach([0.75, 0.5, 0.25], id: \.self) { _ in
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
                
                // 5. Стеклянный контур стакана
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
                
                // 6. Блик света на левой грани стекла
                Path { p in
                    p.move(to: CGPoint(x: 10, y: 15))
                    p.addLine(to: CGPoint(x: 16, y: h - 25))
                }
                .stroke(Color.white.opacity(0.4), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .blur(radius: 0.5)
            }
        }
    }
    
    // MARK: - Забавная резиновая уточка 🦆
    private func duckCompanionView(glassWidth: CGFloat, glassHeight: CGFloat, fillHeight: CGFloat, hasWater: Bool) -> some View {
        let duckX: CGFloat = hasWater
            ? (glassWidth * 0.5 + CGFloat(effectiveTilt) * 22.0).clamped(to: 22...(glassWidth - 22))
            : (glassWidth * 0.5)
        
        let surfaceOffset = CGFloat(effectiveTilt) * 12.0
        let bobbingY = hasWater ? sin(wavePhaseFront * 1.5) * 2.5 : 0.0
        let duckY: CGFloat = hasWater
            ? max(18.0, glassHeight - fillHeight + surfaceOffset + bobbingY)
            : (glassHeight - 16.0)
        
        return ZStack {
            Text("🦆")
                .font(.system(size: hasWater ? 22 : 19))
                .rotationEffect(.degrees(hasWater ? (effectiveTilt * 18.0 + sin(wavePhaseFront) * 8.0) : duckFlipDegrees))
                .scaleEffect(duckDiving ? 0.6 : 1.0)
                .position(x: duckX, y: duckY)
                .onTapGesture {
                    HapticManager.shared.impact(.medium)
                    
                    if hasWater {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                            duckDiving = true
                            triggerSplashAnimation()
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                                duckDiving = false
                            }
                        }
                        showDuckToast(["Кря! 🦆💦", "Бульк! 🌊", "Водичка супер!", "Плывем к норме! 💧"].randomElement() ?? "Кря!")
                    } else {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                            duckFlipDegrees += 180
                        }
                        showDuckToast("Кря! 🦆 Воды нет! Налей скорее! 🚰")
                    }
                }
        }
    }
    
    // MARK: - Струя льющейся воды при наклоне
    private var spillStreamOverlay: some View {
        let isLeft = effectiveTilt < 0
        let startX: CGFloat = isLeft ? 15 : 125
        
        return Path { p in
            p.move(to: CGPoint(x: startX, y: 15))
            p.addQuadCurve(
                to: CGPoint(x: isLeft ? -15 : 155, y: 175),
                control: CGPoint(x: isLeft ? -5 : 145, y: 70)
            )
            p.addLine(to: CGPoint(x: isLeft ? -8 : 148, y: 175))
            p.addQuadCurve(
                to: CGPoint(x: startX + (isLeft ? 8 : -8), y: 15),
                control: CGPoint(x: isLeft ? 0 : 140, y: 70)
            )
            p.closeSubpath()
        }
        .fill(
            LinearGradient(
                colors: [
                    liquidThemeColors.top.opacity(0.9),
                    liquidThemeColors.bottom.opacity(0.6),
                    Color.white.opacity(0.1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Кнопка быстрого добавления порции
    private func quickFillButton(amount: Int, label: String) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                health.addBeverage(type: .water, volumeMl: Double(amount))
                triggerSplashAnimation()
                if health.waterConsumedToday <= Double(amount) + 5 {
                    showDuckToast("Ура! Уточка снова на плаву! 🦆💦")
                }
            }
            HapticManager.shared.impact(.medium)
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
    
    // MARK: - Проверка условий выливания
    private func checkSpillCondition() {
        let absTilt = abs(effectiveTilt)
        
        // Сильный наклон (> 0.65, т.е. более ~38 градусов) и есть вода
        if absTilt > 0.65 && (health.waterConsumedToday - localVisualSpillOffset) > 0 {
            if !isSpilling {
                startSpilling()
            }
        } else {
            if isSpilling {
                stopSpilling()
            }
        }
    }
    
    // MARK: - Оптимизированный запуск выливания воды
    private func startSpilling() {
        guard !isSpilling else { return }
        isSpilling = true
        lastSpillFlushTime = Date()
        
        // Таймер тактильного списания порций (каждые 280 мс вместо бешеного спама)
        spillTimer = Timer.scheduledTimer(withTimeInterval: 0.28, repeats: true) { _ in
            Task { @MainActor in
                let availableWater = self.health.waterConsumedToday - self.localVisualSpillOffset
                guard availableWater > 0 else {
                    self.stopSpilling()
                    self.showDuckToast("Кря! 🦆 Вся вода вылилась на пол! 💦")
                    return
                }
                
                // 1. Быстрое локальное визуальное списание БЕЗ блокировок диска и NutritionView
                let stepSpill = min(35.0, availableWater)
                self.localVisualSpillOffset += stepSpill
                self.accumulatedSpillMl += stepSpill
                
                // 2. Тактильный щелчок капли через синглтон
                HapticManager.shared.impact(.light)
                
                // 3. Если непрерывный наклон длится больше 1.5 сек — мягко сбрасываем в память
                if Date().timeIntervalSince(self.lastSpillFlushTime) > 1.5 && self.accumulatedSpillMl > 0 {
                    self.health.spillWater(amountMl: self.accumulatedSpillMl, flushImmediately: false)
                    self.accumulatedSpillMl = 0.0
                    self.localVisualSpillOffset = 0.0
                    self.lastSpillFlushTime = Date()
                }
            }
        }
    }
    
    private func stopSpilling() {
        guard isSpilling || accumulatedSpillMl > 0 else { return }
        isSpilling = false
        spillTimer?.invalidate()
        spillTimer = nil
        
        // Сохраняем накопленный сброс воды на диск ОДНИМ вызовом
        if accumulatedSpillMl > 0 {
            health.spillWater(amountMl: accumulatedSpillMl, flushImmediately: true)
            accumulatedSpillMl = 0.0
        }
        
        withAnimation(.easeOut(duration: 0.2)) {
            localVisualSpillOffset = 0.0
        }
    }
    
    private func showDuckToast(_ message: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
            duckQuackToast = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeOut(duration: 0.25)) {
                duckQuackToast = nil
            }
        }
    }
    
    // MARK: - Вспомогательные анимации
    private func triggerSplashAnimation() {
        splashScale = 1.06
        withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
            splashScale = 1.0
        }
    }
    
    /// Декларативная плавная волна без таймеров
    private func startDeclarativeWaves() {
        withAnimation(.linear(duration: 3.5).repeatForever(autoreverses: false)) {
            wavePhaseFront = .pi * 2
        }
        withAnimation(.linear(duration: 4.5).repeatForever(autoreverses: false)) {
            wavePhaseBack = .pi * 2
        }
    }
}

// MARK: - Высокопроизводительные частицы брызг без динамических аллокаций
private struct SpillParticlesOverlay: View {
    let isLeft: Bool
    let color: Color
    
    @State private var dropPhase: CGFloat = 0.0
    
    private let dropletOffsets: [(x: CGFloat, delay: Double, size: CGFloat)] = [
        (-8, 0.0, 4.5),
        (12, 0.12, 5.0),
        (-18, 0.22, 3.8),
        (16, 0.30, 4.2),
        (-2, 0.18, 5.2)
    ]
    
    var body: some View {
        let originX: CGFloat = isLeft ? 15 : 125
        
        ZStack {
            ForEach(0..<dropletOffsets.count, id: \.self) { idx in
                let config = dropletOffsets[idx]
                Circle()
                    .fill(color.opacity(0.85 - Double(dropPhase) * 0.5))
                    .frame(width: config.size, height: config.size)
                    .position(
                        x: originX + config.x * (isLeft ? 1.0 : -1.0) + (isLeft ? -15 : 15) * dropPhase,
                        y: 20 + dropPhase * 95
                    )
            }
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.45).repeatForever(autoreverses: false)) {
                dropPhase = 1.0
            }
        }
    }
}

// MARK: - Модель пузырька
struct BubbleItem {
    let xPercent: CGFloat
    let yPercent: CGFloat
    let size: CGFloat
    let speed: CGFloat
}

// MARK: - Оптимизированная форма волны с шагом stride 5pt (в 2.5 раза меньше тригонометрии)
struct TiltedWavePhysicsShape: Shape {
    var phase: Double
    var amplitude: CGFloat
    var tiltAngle: Double
    
    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(phase, tiltAngle) }
        set {
            phase = newValue.first
            tiltAngle = newValue.second
        }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let midX = width * 0.5
        let tanTilt = tan(tiltAngle)
        
        path.move(to: CGPoint(x: 0, y: height))
        
        // Шаг 5pt дает идеальную гладкость и сокращает вычисления в 2.5 раза
        for x in stride(from: 0, to: width + 5, by: 5) {
            let relativeX = x / width
            let sine = sin(relativeX * .pi * 2 + phase)
            let waveY = amplitude * sine
            let tiltY = (x - midX) * tanTilt
            
            let y = waveY + tiltY
            path.addLine(to: CGPoint(x: min(x, width), y: y))
        }
        
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()
        
        return path
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
