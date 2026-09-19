import SwiftUI
import CoreMotion

// MARK: - Интерактивный стакан с физикой наклона CoreMotion, плавной водой и уточкой
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
    
    // Подтверждение уменьшения объема воды
    @State private var showingReduceConfirmationAlert: Bool = false
    @State private var pendingVolumeToReduce: Int = 0
    
    // Анимация всплеска
    @State private var splashScale: CGFloat = 1.0
    @State private var showingQuickFillToast: Bool = false
    
    // Оптимизированная физика выливания с защитой от случайного наклона
    @State private var isSpilling: Bool = false
    @State private var spillTimer: Timer? = nil
    @State private var accumulatedSpillMl: Double = 0.0
    @State private var localVisualSpillOffset: Double = 0.0
    @State private var lastSpillFlushTime: Date = Date()
    
    // Пасхалка с уточкой 🦆
    @State private var duckQuackToast: String? = nil
    @State private var duckFlipDegrees: Double = 0.0
    @State private var duckDiving: Bool = false
    
    // Статический пул пузырьков воздуха
    private let bubbles: [BubbleItem] = [
        BubbleItem(xPercent: 0.25, yPercent: 0.85, size: 5, speed: 2.2),
        BubbleItem(xPercent: 0.45, yPercent: 0.92, size: 6, speed: 2.7),
        BubbleItem(xPercent: 0.65, yPercent: 0.80, size: 4, speed: 1.9),
        BubbleItem(xPercent: 0.80, yPercent: 0.88, size: 5, speed: 2.4),
        BubbleItem(xPercent: 0.35, yPercent: 0.70, size: 4, speed: 2.1)
    ]
    
    public init() {}
    
    // MARK: - Вычисляемый сглаженный наклон (-1.0 ... 1.0)
    private var effectiveTilt: Double {
        let sensorTilt = tiltManager.tiltX
        let combined = (sensorTilt * 0.85) + touchTilt
        return min(max(combined, -1.1), 1.1)
    }
    
    /// Мягкий и стабильный наклон стакана (максимум ±7 градусов, чтобы избежать заломов и перекосов)
    private var cupRotationAngle: Angle {
        Angle(degrees: (effectiveTilt * 6.5).clamped(to: -7.0...7.0))
    }
    
    /// Угол наклона зеркала воды относительно стакана (в противоположную сторону для компенсации гравитации)
    private var liquidSurfaceAngle: Double {
        (-effectiveTilt * 0.18).clamped(to: -0.22...0.22)
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
    
    private func formatMl(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "\u{00A0}" // Неразрывный пробел исключает разрыв чисел
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }
    
    public var body: some View {
        VStack(spacing: 14) {
            // Заголовок интерактивного стакана с защитой от переноса строк
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "drop.degreesign.fill")
                        .font(.title3)
                        .foregroundColor(Color(red: 0/255, green: 220/255, blue: 255/255))
                    Text("Интерактивный стакан")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                Spacer(minLength: 6)
                
                // Индикатор жестов
                HStack(spacing: 5) {
                    Image(systemName: "arrow.up.and.down")
                        .font(.caption2)
                        .foregroundColor(.cyan)
                    Text("Свайп ↑ / ↓")
                        .font(.caption2)
                        .bold()
                        .lineLimit(1)
                }
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.06))
                .cornerRadius(8)
            }
            
            // Основной визуал стакана с физикой наклона и брызг
            HStack(spacing: 16) {
                // Область стакана
                ZStack {
                    // Высокопроизводительные анимированные брызги без аллокаций
                    if isSpilling {
                        SpillParticlesOverlay(isLeft: effectiveTilt < 0, color: liquidThemeColors.top)
                    }
                    
                    // Струя льющейся воды при намеренном сильном выливании
                    if isSpilling && (health.waterConsumedToday - localVisualSpillOffset) > 0 {
                        spillStreamOverlay
                    }
                    
                    // Сам стакан с естественным физическим покачиванием
                    glassCupBody
                        .frame(width: 105, height: 155)
                        .rotationEffect(cupRotationAngle, anchor: .center)
                        .scaleEffect(splashScale)
                        .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.82), value: effectiveTilt)
                        .gesture(
                            DragGesture(minimumDistance: 5)
                                .onChanged { value in
                                    let hTrans = value.translation.width
                                    let vTrans = value.translation.height
                                    
                                    // Если тянем преимущественно по горизонтали -> наклоняем стакан
                                    if abs(hTrans) > abs(vTrans) && !isDraggingVertical {
                                        touchTilt = Double(hTrans / 100.0).clamped(to: -1.1...1.1)
                                        checkSpillCondition()
                                    } else {
                                        // Вертикальный жест добавления (вверх) или убавления (вниз)
                                        isDraggingVertical = true
                                        dragOffset = vTrans
                                        let deltaSteps = Int(-dragOffset / 15.0)
                                        let calculatedDelta = deltaSteps * 50
                                        
                                        let currentConsumed = Int(health.waterConsumedToday)
                                        let newDelta: Int
                                        if calculatedDelta >= 0 {
                                            newDelta = min(1000, calculatedDelta)
                                        } else {
                                            // Не даем убавить больше, чем выпито сегодня
                                            newDelta = max(-currentConsumed, max(-1000, calculatedDelta))
                                        }
                                        
                                        if newDelta != dragVolumeChange {
                                            dragVolumeChange = newDelta
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
                                        // Добавление: применяется сразу
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                            health.addBeverage(type: .water, volumeMl: Double(dragVolumeChange))
                                            triggerSplashAnimation()
                                        }
                                        HapticManager.shared.impact(.medium)
                                        resetDragState()
                                    } else if dragVolumeChange < 0 {
                                        // Убавление: запрашиваем подтверждение перед списанием!
                                        pendingVolumeToReduce = abs(dragVolumeChange)
                                        showingReduceConfirmationAlert = true
                                        HapticManager.shared.impact(.heavy)
                                        resetDragState()
                                    } else {
                                        resetDragState()
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
                        .offset(y: -95)
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    // Плавающий бейдж уменьшения при свайпе вниз
                    if isDraggingVertical && dragVolumeChange < 0 {
                        VStack(spacing: 4) {
                            Text("\(dragVolumeChange) мл")
                                .font(.system(size: 16, weight: .heavy, design: .rounded))
                                .foregroundColor(Color(red: 255/255, green: 95/255, blue: 95/255))
                            Text("Отпустите для списания")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.85))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(red: 255/255, green: 95/255, blue: 95/255).opacity(0.7), lineWidth: 1.5)
                        )
                        .offset(y: 40)
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
                            .offset(y: -92)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: 125, height: 165)
                
                // Информационный блок рядом со стаканом
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Текущий уровень")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(formatMl(Int(max(0.0, health.waterConsumed - localVisualSpillOffset))))
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                            Text("из \(formatMl(Int(targetGoal))) мл")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                                .lineLimit(1)
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
                                .lineLimit(1)
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
                                Text("Вернуть \(formatMl(Int(health.sessionSpilledWaterMl))) мл")
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
        .alert("Уменьшить количество воды?", isPresented: $showingReduceConfirmationAlert) {
            Button("Списать \(pendingVolumeToReduce) мл", role: .destructive) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    health.reduceWater(volumeMl: Double(pendingVolumeToReduce))
                    triggerSplashAnimation()
                    showDuckToast("Списали \(pendingVolumeToReduce) мл 💧")
                }
                HapticManager.shared.notification(.success)
            }
            Button("Отмена", role: .cancel) {
                HapticManager.shared.selection()
            }
        } message: {
            Text("Вы действительно хотите убавить \(pendingVolumeToReduce) мл из сегодняшнего объема выпитой воды?")
        }
    }
    
    // MARK: - Тело стакана с физикой волны, наклоном зеркала воды и уточки
    private var glassCupBody: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let visualProgress = min(max(currentProgress + Double(dragVolumeChange) / targetGoal, 0.0), 1.0)
            
            ZStack(alignment: .bottom) {
                // 1. Задний фон пустого стакана
                GlassCupShape()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.18), Color.white.opacity(0.08)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color.white.opacity(0.08), radius: 4, x: 0, y: 2)
                
                // 2. Жидкость внутри со стабильной привязкой ко дну и физикой волн
                if visualProgress > 0.005 {
                    ZStack {
                        // Задняя волна (противофаза для создания объема жидкости)
                        TiltedWavePhysicsShape(
                            phase: wavePhaseBack,
                            amplitude: 2.2,
                            tiltAngle: liquidSurfaceAngle,
                            fillProgress: min(visualProgress + 0.02, 1.0)
                        )
                        .fill(liquidThemeColors.bottom.opacity(0.42))
                        
                        // Передняя яркая волна с физическим зеркалом воды
                        TiltedWavePhysicsShape(
                            phase: wavePhaseFront,
                            amplitude: 3.2,
                            tiltAngle: liquidSurfaceAngle,
                            fillProgress: visualProgress
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
                        
                        // Пузырьки воздуха в толще налитой воды
                        ForEach(0..<bubbles.count, id: \.self) { idx in
                            let b = bubbles[idx]
                            let usableH = h - 16
                            let bubbleBaseY = (h - 6) - (usableH * CGFloat(visualProgress) * b.yPercent)
                            let bubbleXShift = CGFloat(effectiveTilt) * 10.0 * (1.0 - b.yPercent)
                            Circle()
                                .fill(Color.white.opacity(0.48))
                                .frame(width: b.size, height: b.size)
                                .position(
                                    x: (w * b.xPercent + bubbleXShift).clamped(to: 14...(w - 14)),
                                    y: bubbleBaseY.clamped(to: 14...(h - 10))
                                )
                        }
                    }
                    .frame(width: w, height: h)
                    .mask(GlassCupShape())
                }
                
                // 3. Желтая резиновая уточка 🦆 на поверхности воды
                duckCompanionView(glassWidth: w, glassHeight: h, visualProgress: visualProgress, hasWater: visualProgress > 0.02)
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
                
                // 5. Стеклянный контур стакана (повышенная видимость)
                GlassCupShape()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.9),
                                Color.white.opacity(0.35),
                                Color.white.opacity(0.65)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2.8
                    )
                    .shadow(color: Color.cyan.opacity(0.12), radius: 6, x: 0, y: 0)
                
                // 6. Блик света на левой грани стекла (усиленный)
                Path { p in
                    p.move(to: CGPoint(x: 10, y: 15))
                    p.addLine(to: CGPoint(x: 16, y: h - 25))
                }
                .stroke(Color.white.opacity(0.6), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                .blur(radius: 0.5)
            }
        }
    }
    
    // MARK: - Забавная резиновая уточка 🦆 на поверхности волн
    private func duckCompanionView(glassWidth: CGFloat, glassHeight: CGFloat, visualProgress: Double, hasWater: Bool) -> some View {
        let duckX: CGFloat = hasWater
            ? (glassWidth * 0.5 + CGFloat(effectiveTilt) * 16.0).clamped(to: 22...(glassWidth - 22))
            : (glassWidth * 0.5)
        
        let usableH = glassHeight - 16
        let centerSurfaceY = (glassHeight - 6) - CGFloat(visualProgress) * usableH
        let clampedTilt = liquidSurfaceAngle.clamped(to: -0.22...0.22)
        let relativeX = duckX / glassWidth
        let waveY = 2.5 * sin(relativeX * .pi * 2.0 + wavePhaseFront)
        let tiltY = (duckX - glassWidth * 0.5) * tan(clampedTilt)
        let surfaceY = centerSurfaceY + waveY + tiltY
        
        let duckY: CGFloat = hasWater
            ? (surfaceY - 8.0).clamped(to: 14...(glassHeight - 16))
            : (glassHeight - 16.0)
        
        let duckTiltDegrees = hasWater ? (clampedTilt * (180.0 / .pi) + sin(wavePhaseFront * 2.0) * 5.0) : duckFlipDegrees
        
        return ZStack {
            Text("🦆")
                .font(.system(size: hasWater ? 22 : 19))
                .rotationEffect(.degrees(duckTiltDegrees))
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
    
    // MARK: - Струя льющейся воды при сильном наклоне (физически-реалистичная)
    private var spillStreamOverlay: some View {
        let isLeft = effectiveTilt < 0
        let tiltStrength = CGFloat(min(abs(effectiveTilt), 1.1))
        
        // Начало струи: край стакана на стороне наклона
        let startX: CGFloat = isLeft ? 12 : 108
        let startY: CGFloat = 10
        
        // Конец струи: отлетает дальше при более сильном наклоне
        let endOffsetX: CGFloat = (25 + tiltStrength * 15) * (isLeft ? -1 : 1)
        let endX: CGFloat = startX + endOffsetX
        let endY: CGFloat = 170
        
        // Контрольная точка: формирует естественную параболу падающей воды
        let ctrlX: CGFloat = startX + endOffsetX * 0.3
        let ctrlY: CGFloat = 55
        
        // Ширина струи: тонкая у горлышка → шире к концу
        let topWidth: CGFloat = 4.0
        let bottomWidth: CGFloat = 7.0 + tiltStrength * 3.0
        
        return ZStack {
            // Основная струя
            Path { p in
                // Левый край струи
                p.move(to: CGPoint(x: startX - topWidth * 0.5, y: startY))
                p.addQuadCurve(
                    to: CGPoint(x: endX - bottomWidth * 0.5, y: endY),
                    control: CGPoint(x: ctrlX - topWidth * 0.4, y: ctrlY)
                )
                // Нижняя кромка
                p.addLine(to: CGPoint(x: endX + bottomWidth * 0.5, y: endY))
                // Правый край струи (обратно вверх)
                p.addQuadCurve(
                    to: CGPoint(x: startX + topWidth * 0.5, y: startY),
                    control: CGPoint(x: ctrlX + topWidth * 0.4, y: ctrlY)
                )
                p.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [
                        liquidThemeColors.top.opacity(0.92),
                        liquidThemeColors.bottom.opacity(0.65),
                        liquidThemeColors.bottom.opacity(0.3)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            // Тонкий светлый блик по центру струи
            Path { p in
                p.move(to: CGPoint(x: startX, y: startY + 3))
                p.addQuadCurve(
                    to: CGPoint(x: endX, y: endY - 10),
                    control: CGPoint(x: ctrlX, y: ctrlY + 5)
                )
            }
            .stroke(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            .blur(radius: 0.8)
        }
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
    
    // MARK: - Проверка условий выливания (только при осознанном переворачивании телефона > 1.05)
    private func checkSpillCondition() {
        let absTilt = abs(effectiveTilt)
        
        // Сильный намеренный наклон (> 1.05, т.е. более ~65-70 градусов — телефон почти горизонтален)
        if absTilt > 1.05 && (health.waterConsumedToday - localVisualSpillOffset) > 0 {
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
        
        // Таймер тактильного списания порций (мягкое списание по 15 мл)
        spillTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { _ in
            Task { @MainActor in
                let availableWater = self.health.waterConsumedToday - self.localVisualSpillOffset
                guard availableWater > 0 else {
                    self.stopSpilling()
                    self.showDuckToast("Кря! 🦆 Вся вода вылилась! 💦")
                    return
                }
                
                // Мягкое локальное списание БЕЗ лагов UI
                let stepSpill = min(15.0, availableWater)
                self.localVisualSpillOffset += stepSpill
                self.accumulatedSpillMl += stepSpill
                
                HapticManager.shared.impact(.light)
                
                // Периодический сброс в хранилище раз в 2 секунды
                if Date().timeIntervalSince(self.lastSpillFlushTime) > 2.0 && self.accumulatedSpillMl > 0 {
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
    
    private func resetDragState() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            touchTilt = 0.0
            isDraggingVertical = false
            dragOffset = 0
            dragVolumeChange = 0
            lastFeedbackVolumeStep = 0
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
        splashScale = 1.05
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
        let originX: CGFloat = isLeft ? 15 : 105
        
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

// MARK: - Оптимизированная форма волны с точной привязкой ко дну стакана
struct TiltedWavePhysicsShape: Shape {
    var phase: Double
    var amplitude: CGFloat
    var tiltAngle: Double
    var fillProgress: Double
    
    var animatableData: AnimatablePair<Double, AnimatablePair<Double, Double>> {
        get { AnimatablePair(phase, AnimatablePair(tiltAngle, fillProgress)) }
        set {
            phase = newValue.first
            tiltAngle = newValue.second.first
            fillProgress = newValue.second.second
        }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard fillProgress > 0.005 else { return path }
        
        let width = rect.width
        let height = rect.height
        let midX = width * 0.5
        
        // Поверхность воды рассчитывается от дна (height) вверх
        let usableHeight = height - 16
        let currentFillH = CGFloat(fillProgress).clamped(to: 0.0...1.0) * usableHeight
        let baseY = (height - 6) - currentFillH
        
        let clampedTilt = tiltAngle.clamped(to: -0.22...0.22)
        let tanTilt = tan(clampedTilt)
        
        // 1. Начинаем с левого нижнего угла стакана (дно)
        path.move(to: CGPoint(x: 0, y: height))
        
        // 2. Поднимаемся к левой кромке поверхности воды
        let startTiltOffset = -midX * tanTilt
        let startWaveOffset = amplitude * sin(phase)
        let startY = (baseY + startTiltOffset + startWaveOffset).clamped(to: 6.0...height)
        path.addLine(to: CGPoint(x: 0, y: startY))
        
        // 3. Волнообразный профиль с шагом 4pt (гладко и без лишней тригонометрии)
        for x in stride(from: 4.0, through: width, by: 4.0) {
            let relativeX = x / width
            let waveOffset = amplitude * sin(relativeX * .pi * 2.0 + phase)
            let tiltOffset = (x - midX) * tanTilt
            let surfaceY = (baseY + waveOffset + tiltOffset).clamped(to: 6.0...height)
            path.addLine(to: CGPoint(x: x, y: surfaceY))
        }
        
        // 4. Опускаемся по правой кромке на дно стакана
        path.addLine(to: CGPoint(x: width, y: height))
        
        // 5. Замыкаем по дну
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
