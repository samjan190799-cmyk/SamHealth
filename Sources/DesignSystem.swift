import SwiftUI

// Дизайн-система приложения Forma с адаптивной поддержкой темной/светлой тем
public enum Theme {
    // Фон приложения - адаптивный
    public static var background: Color {
        Color(UIColor { trait in
            return trait.userInterfaceStyle == .dark
                ? UIColor(red: 10/255, green: 10/255, blue: 12/255, alpha: 1.0)
                : UIColor(red: 243/255, green: 244/255, blue: 246/255, alpha: 1.0)
        })
    }
    
    public static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 10/255, green: 12/255, blue: 18/255),
                Color(red: 16/255, green: 20/255, blue: 30/255),
                Color(red: 10/255, green: 12/255, blue: 18/255)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // Фоновый цвет карточек - адаптивный
    public static var cardBackground: Color {
        Color(UIColor { trait in
            return trait.userInterfaceStyle == .dark
                ? UIColor(red: 20/255, green: 20/255, blue: 25/255, alpha: 1.0)
                : UIColor.white
        })
    }
    
    // Цвета колец активности
    public static let moveColor = Color(red: 255/255, green: 45/255, blue: 85/255) // Розовый/Красный
    public static let exerciseColor = Color(red: 50/255, green: 215/255, blue: 75/255) // Ярко-зеленый
    public static let standColor = Color(red: 0/255, green: 229/255, blue: 255/255) // Неоновый голубой
    
    // Вспомогательные цвета
    public static let pulseColor = Color(red: 255/255, green: 59/255, blue: 48/255)
    public static let sleepColor = Color(red: 90/255, green: 94/255, blue: 226/255)
    public static let waterColor = Color(red: 0/255, green: 191/255, blue: 255/255) // Неоновый синий
    public static let weightColor = Color(red: 255/255, green: 204/255, blue: 0/255)
    
    // Цвета текста - адаптивные
    public static var textPrimary: Color {
        Color(UIColor { trait in
            return trait.userInterfaceStyle == .dark ? UIColor.white : UIColor(red: 17/255, green: 24/255, blue: 39/255, alpha: 1.0)
        })
    }
    
    public static var textSecondary: Color {
        Color(UIColor { trait in
            return trait.userInterfaceStyle == .dark ? UIColor.lightGray : UIColor(red: 107/255, green: 114/255, blue: 128/255, alpha: 1.0)
        })
    }
    
    // Темно-синий градиент для карточки трекера воды (как на макете)
    public static let waterCardGradient = LinearGradient(
        colors: [
            Color(red: 15/255, green: 32/255, blue: 67/255),
            Color(red: 27/255, green: 55/255, blue: 110/255)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Менеджер тактильной отдачи (Haptic Engine) по стандартам Apple HIG
public final class HapticManager {
    public static let shared = HapticManager()
    private init() {}
    
    public func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    public func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
    
    public func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}

// MARK: - Пружинный стиль нажатия кнопок (Apple Design Awards Style)
public struct AppleDesignAwardsButtonStyle: ButtonStyle {
    public var scaleAmount: CGFloat
    public var hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle?
    
    public init(scaleAmount: CGFloat = 0.96, hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle? = .light) {
        self.scaleAmount = scaleAmount
        self.hapticStyle = hapticStyle
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleAmount : 1.0)
            .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.72), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed, let style = hapticStyle {
                    HapticManager.shared.impact(style)
                }
            }
    }
}

// MARK: - Кастомный модификатор Apple Design Awards Card (Стекломорфизм и глубина)
public struct AdaCardModifier: ViewModifier {
    public var cornerRadius: CGFloat
    public var padding: CGFloat
    
    public init(cornerRadius: CGFloat = 24, padding: CGFloat = 16) {
        self.cornerRadius = cornerRadius
        self.padding = padding
    }
    
    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(UIColor.secondarySystemBackground).opacity(0.85))
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18),
                                Color.white.opacity(0.04),
                                Color.primary.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 6)
    }
}

// MARK: - Шиммер-эффект скелетонной загрузки (ADA Shimmer)
public struct AdaShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1.0
    public var isLoading: Bool
    
    public init(isLoading: Bool = true) {
        self.isLoading = isLoading
    }
    
    public func body(content: Content) -> some View {
        if isLoading {
            content
                .redacted(reason: .placeholder)
                .overlay(
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(0.2),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geo.size.width * 1.5)
                        .offset(x: phase * geo.size.width)
                    }
                )
                .mask(content)
                .onAppear {
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        phase = 1.5
                    }
                }
        } else {
            content
        }
    }
}

// Кастомный модификатор для адаптивных премиум карточек (Обратная совместимость)
struct PremiumCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .modifier(AdaCardModifier(cornerRadius: 24, padding: 16))
    }
}

extension View {
    public func adaCard(cornerRadius: CGFloat = 24, padding: CGFloat = 16) -> some View {
        self.modifier(AdaCardModifier(cornerRadius: cornerRadius, padding: padding))
    }
    
    public func adaShimmer(isLoading: Bool = true) -> some View {
        self.modifier(AdaShimmerModifier(isLoading: isLoading))
    }
    
    public func adaButtonStyle(scaleAmount: CGFloat = 0.96, haptic: UIImpactFeedbackGenerator.FeedbackStyle? = .light) -> some View {
        self.buttonStyle(AppleDesignAwardsButtonStyle(scaleAmount: scaleAmount, hapticStyle: haptic))
    }
    
    public func premiumCard() -> some View {
        self.modifier(AdaCardModifier(cornerRadius: 24, padding: 16))
    }
    
    public func neonShadow(color: Color, radius: CGFloat = 8) -> some View {
        self.shadow(color: color.opacity(0.4), radius: radius, x: 0, y: 0)
    }
}

// Кольцо активности для SwiftUI
public struct ActivityRing: View {
    var progress: Double
    var color: Color
    var iconName: String
    var ringWidth: CGFloat = 12
    
    public var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.12), lineWidth: ringWidth)
            
            Circle()
                .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                .stroke(
                    AngularGradient(
                        colors: [color, color.opacity(0.8), color],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                )
                .rotationEffect(Angle(degrees: -90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
            
            Image(systemName: iconName)
                .font(.system(size: ringWidth * 0.7, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

// Виджет трех колец активности (как на Apple Watch)
public struct ActivityRingsGroup: View {
    public var moveProgress: Double
    public var exerciseProgress: Double
    public var standProgress: Double
    
    public init(moveProgress: Double, exerciseProgress: Double, standProgress: Double) {
        self.moveProgress = moveProgress
        self.exerciseProgress = exerciseProgress
        self.standProgress = standProgress
    }
    
    public var body: some View {
        ZStack {
            ActivityRing(progress: moveProgress, color: Theme.moveColor, iconName: "arrow.right", ringWidth: 12)
                .padding(0)
            ActivityRing(progress: exerciseProgress, color: Theme.exerciseColor, iconName: "arrow.up.forward", ringWidth: 12)
                .padding(16)
            ActivityRing(progress: standProgress, color: Theme.standColor, iconName: "figure.stand", ringWidth: 12)
                .padding(32)
        }
        .frame(width: 120, height: 120)
    }
}

// Текстовый индикатор для колец активности
public struct ActivityTextValue: View {
    public let title: String
    public let value: String
    public let color: Color
    
    public init(title: String, value: String, color: Color) {
        self.title = title
        self.value = value
        self.color = color
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .bold()
                .foregroundColor(Theme.textSecondary)
            Text(value)
                .font(.subheadline)
                .bold()
                .foregroundColor(color)
        }
    }
}

// Данные для недельной статистики по шагам
public struct WeeklyStepsData: Identifiable, Equatable, Codable {
    public var id: String { day }
    public let day: String
    public let steps: Int
    
    public init(day: String, steps: Int) {
        self.day = day
        self.steps = steps
    }
}

public struct WeightRecord: Codable, Identifiable {
    public let id: UUID
    public let date: Date
    public let weight: Double
    
    public init(id: UUID = UUID(), date: Date = Date(), weight: Double) {
        self.id = id
        self.date = date
        self.weight = weight
    }
}

public struct WorkoutRecord: Codable, Identifiable {
    public let id: UUID
    public let type: String
    public let date: Date
    public let durationMinutes: Int
    public let caloriesBurned: Double
    
    public init(id: UUID = UUID(), type: String, date: Date = Date(), durationMinutes: Int, caloriesBurned: Double) {
        self.id = id
        self.type = type
        self.date = date
        self.durationMinutes = durationMinutes
        self.caloriesBurned = caloriesBurned
    }
}

public struct DailyNutritionRecord: Codable, Identifiable {
    public let id: UUID
    public let dateString: String
    public var calories: Double
    
    public init(id: UUID = UUID(), dateString: String, calories: Double) {
        self.id = id
        self.dateString = dateString
        self.calories = calories
    }
}

public struct DailyActivitySummary: Codable, Identifiable, Equatable {
    public var id: String { dateKey }
    public let dateKey: String     // "yyyy-MM-dd"
    public let date: Date
    public var steps: Int
    public var distanceMeters: Double
    public var activeCalories: Double
    
    public init(dateKey: String, date: Date, steps: Int, distanceMeters: Double, activeCalories: Double) {
        self.dateKey = dateKey
        self.date = date
        self.steps = steps
        self.distanceMeters = distanceMeters
        self.activeCalories = activeCalories
    }
}

// Перечисление тренда изменения веса
public enum WeightTrendType {
    case up
    case down
    case stable
    
    public var arrow: String {
        switch self {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }
    
    public var color: Color {
        switch self {
        case .up: return Theme.pulseColor
        case .down: return Theme.exerciseColor
        case .stable: return Theme.textSecondary
        }
    }
}

// Пульсовые зоны для кардио-аналитики
public enum HeartRateZone: String, CaseIterable {
    case rest = "Покой"
    case warmUp = "Разминка"
    case fatBurn = "Жиросжигание"
    case cardio = "Кардио"
    case anaerobic = "Анаэробная"
    case peak = "Пиковая"
    
    public var color: Color {
        switch self {
        case .rest: return Color(red: 0/255, green: 190/255, blue: 255/255)
        case .warmUp: return Color(red: 50/255, green: 215/255, blue: 75/255)
        case .fatBurn: return Color(red: 255/255, green: 204/255, blue: 0/255)
        case .cardio: return Color(red: 255/255, green: 149/255, blue: 0/255)
        case .anaerobic: return Color(red: 255/255, green: 59/255, blue: 48/255)
        case .peak: return Color(red: 175/255, green: 82/255, blue: 222/255)
        }
    }
    
    public func localizedName(lang: String) -> String {
        switch self {
        case .rest: return LocalizationManager.tr("hr_zone_rest", lang: lang)
        case .warmUp: return LocalizationManager.tr("hr_zone_warmup", lang: lang)
        case .fatBurn: return LocalizationManager.tr("hr_zone_fatburn", lang: lang)
        case .cardio: return LocalizationManager.tr("hr_zone_cardio", lang: lang)
        case .anaerobic: return LocalizationManager.tr("hr_zone_anaerobic", lang: lang)
        case .peak: return LocalizationManager.tr("hr_zone_peak", lang: lang)
        }
    }
    
    public static func zone(for heartRate: Int, age: Int = 25) -> HeartRateZone {
        guard heartRate > 0 else { return .rest }
        let maxHR = Double(max(150, 220 - age))
        let percent = Double(heartRate) / maxHR
        
        if percent < 0.55 {
            return .rest
        } else if percent < 0.65 {
            return .warmUp
        } else if percent < 0.75 {
            return .fatBurn
        } else if percent < 0.85 {
            return .cardio
        } else if percent < 0.92 {
            return .anaerobic
        } else {
            return .peak
        }
    }
}

// Тренд изменения пульса
public enum HeartRateTrendType {
    case rising
    case falling
    case stable
    case spike
    case recovered
}

// Форма стакана (трапеция с закругленным дном)
struct GlassCupShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let topWidth = rect.width
        let bottomWidth = rect.width * 0.78
        let xOffset = (topWidth - bottomWidth) / 2
        
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: xOffset, y: rect.height - 12))
        path.addQuadCurve(
            to: CGPoint(x: rect.width - xOffset, y: rect.height - 12),
            control: CGPoint(x: rect.width / 2, y: rect.height)
        )
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.closeSubpath()
        return path
    }
}

// Кастомный неоновый стакан воды с плавной анимацией волны
public struct GlassWaterView: View {
    public var progress: Double
    
    @State private var animatedProgress: Double = 0.0
    @State private var wavePhase = 0.0
    
    public init(progress: Double) {
        self.progress = progress
    }
    
    public var body: some View {
        ZStack {
            // Вода внутри стакана с маской по форме стакана
            GeometryReader { geo in
                let fillHeight = CGFloat(min(max(animatedProgress, 0.0), 1.0)) * geo.size.height
                
                VStack {
                    Spacer()
                    // Волна с плавающим уровнем
                    WaveShape(phase: wavePhase, progress: animatedProgress)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0/255, green: 229/255, blue: 255/255).opacity(0.85),
                                    Color(red: 0/255, green: 145/255, blue: 255/255).opacity(0.65)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: fillHeight)
                }
                .mask(GlassCupShape())
            }
            
            // Контур стакана сверху воды
            GlassCupShape()
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.55), Color.white.opacity(0.15)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 2.5
                )
                .background(
                    GlassCupShape()
                        .fill(Color.white.opacity(0.04))
                )
            
            // Водный блик/свечение
            GlassCupShape()
                .stroke(Color(red: 0/255, green: 229/255, blue: 255/255).opacity(0.25), lineWidth: 1)
                .blur(radius: 1.5)
        }
        .frame(width: 55, height: 85)
        .onAppear {
            animatedProgress = progress
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                wavePhase = .pi * 2
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeInOut(duration: 0.8)) {
                animatedProgress = newValue
            }
        }
    }
}

// Волнообразная форма для анимации воды
struct WaveShape: Shape {
    var phase: Double
    var progress: Double
    
    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        path.move(to: CGPoint(x: 0, y: height))
        
        if progress > 0 {
            for x in stride(from: 0, to: width + 1, by: 1) {
                let relativeX = x / width
                let sine = sin(relativeX * .pi * 2 + phase)
                let amplitude = 4.0 * sin(progress * .pi)
                let y = amplitude * sine
                path.addLine(to: CGPoint(x: x, y: y))
            }
        } else {
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: width, y: 0))
        }
        
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()
        
        return path
    }
}

// Строка быстрого старта тренировки
public struct WorkoutRow: View {
    var title: String
    var icon: String
    var color: Color
    var onTap: (() -> Void)?
    
    public var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 28, height: 28)
                    .background(color.opacity(0.15))
                    .cornerRadius(8)
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Перечисление поддерживаемых языков
public enum AppLanguage: String, CaseIterable, Identifiable {
    case ru = "ru"
    case en = "en"
    case hy = "hy" // Армянский
    
    public var id: String { self.rawValue }
    public var title: String {
        switch self {
        case .ru: return "Русский"
        case .en: return "English"
        case .hy: return "Հայերեն"
        }
    }
}

// Менеджер локализации (упрощенная инлайн поддержка локализации)
public struct LocalizationManager {
    public static func tr(_ key: String, lang: String) -> String {
        let translations: [String: [String: String]] = [
            "tab_home": ["ru": "Главная", "en": "Home", "hy": "Գլխավոր"],
            "tab_workouts": ["ru": "Тренировки", "en": "Workouts", "hy": "Մարզումներ"],
            "tab_water": ["ru": "Вода", "en": "Water", "hy": "Ջուր"],
            "tab_nutrition": ["ru": "Питание", "en": "Nutrition", "hy": "Սնունդ"],
            "tab_stats": ["ru": "Статистика", "en": "Statistics", "hy": "Վիճակագրություն"],
            "tab_settings": ["ru": "Настройки", "en": "Settings", "hy": "Կարգավորումներ"],
            
            "home_welcome": ["ru": "Главная", "en": "Home", "hy": "Գլխավոր"],
            "workouts_title": ["ru": "Тренировки", "en": "Workouts", "hy": "Մարզումներ"],
            "water_title": ["ru": "Водный баланс", "en": "Water Balance", "hy": "Ջրի հաշվեկշիռ"],
            "nutrition_title": ["ru": "Питание", "en": "Nutrition", "hy": "Սնունդ"],
            "stats_title": ["ru": "Статистика", "en": "Statistics", "hy": "Վիճակագրություն"],
            "settings_title": ["ru": "Настройки", "en": "Settings", "hy": "Կարգավորումներ"],
            
            // Nutrition Tabs
            "nutrition_tab_food": ["ru": "Еда", "en": "Food", "hy": "Սնունդ"],
            "nutrition_tab_water": ["ru": "Вода", "en": "Water", "hy": "Ջուր"],
            "nutrition_tab_weight": ["ru": "Вес", "en": "Weight", "hy": "Քաշ"],
            
            // Health Summary / Dashboard Insights
            "dashboard_summary_title": ["ru": "СВОДКА ЗДОРОВЬЯ", "en": "HEALTH SUMMARY", "hy": "ԱՌՈՂՋՈՒԹՅԱՆ ԱՄՓՈՓՈՒՄ"],
            "ai_coach_title": ["ru": "Персональный ИИ-Тренер", "en": "Personal AI Coach", "hy": "Անհատական ԻԻ Մարզիչ"],
            "ai_coach_empty_desc": ["ru": "Пока нет рекомендаций на сегодня. Нажмите кнопку ниже, чтобы ИИ-Тренер оценил вашу активность.", "en": "No recommendations for today yet. Tap the button below to get an AI coach evaluation.", "hy": "Այսօրվա համար դեռ խորհուրդներ չկան: Սեղմեք կոճակը ստորև՝ ԻԻ Մարզչի գնահատականը ստանալու համար:"],
            "ai_coach_placeholder": ["ru": "Пока нет рекомендаций на сегодня. Нажмите кнопку ниже, чтобы ИИ-Тренер оценил вашу активность.", "en": "No recommendations for today yet. Tap the button below to get an AI coach evaluation.", "hy": "Այսօրվա համար դեռ խորհուրդներ չկան: Սեղմեք կոճակը ստորև՝ ԻԻ Մարզչի գնահատականը ստանալու համար:"],
            "ai_coach_analyzing": ["ru": "Анализирую показатели...", "en": "Analyzing metrics...", "hy": "Ցուցանիշները վերլուծվում են..."],
            "ai_coach_analyze_btn": ["ru": "Оценить мои показатели", "en": "Evaluate My Metrics", "hy": "Գնահատել իմ ցուցանիշները"],
            "dashboard_nutrition_today": ["ru": "Питание за сегодня", "en": "Nutrition Today", "hy": "Այսօրվа սնունդը"],
            "status_water_good": ["ru": "Отличный водный баланс 💧", "en": "Great hydration 💧", "hy": "Գերազанց ջրային հաշվեկշիռ 💧"],
            "status_water_normal": ["ru": "Гидратация в норме 🥛", "en": "Hydration is normal 🥛", "hy": "Ջրի քանակը նորմալ է 🥛"],
            "status_water_low": ["ru": "Рекомендуется выпить воды 🥛", "en": "Recommend to drink water 🥛", "hy": "Խորհուրդ է տրվում ջուր խմել 🥛"],
            "status_activity_high": ["ru": "Отличная активность! 🏃‍♂️", "en": "Great activity! 🏃‍♂️", "hy": "Գերազանց ակտիվություն: 🏃‍♂️"],
            "status_activity_normal": ["ru": "Хорошая подвижность 🚶‍♂️", "en": "Good mobility 🚶‍♂️", "hy": "Լավ շարժունակություն 🚶‍♂️"],
            "status_activity_low": ["ru": "Добавьте активности сегодня 🚶‍♂️", "en": "Add some activity today 🚶‍♂️", "hy": "Ավելացրեք ակտիվություն այսօր 🚶‍♂️"],
            "status_activity_workout": ["ru": "Тренировка выполнена ✅", "en": "Workout completed ✅", "hy": "Մարզումն ավարտված է ✅"],
            "status_nutrition_logged": ["ru": "Питание залогировано 🍏", "en": "Meals logged today 🍏", "hy": "Սնունդը գրանցված է 🍏"],
            "status_nutrition_empty": ["ru": "Залогируйте приемы пищи 📸", "en": "Log your meals today 📸", "hy": "Գրանցեք ձեր սնունդը 📸"],
            
            "settings_theme": ["ru": "Тема оформления", "en": "App Theme", "hy": "Հավելվածի թեման"],
            "settings_language": ["ru": "Язык интерфейса", "en": "Interface Language", "hy": "Ինտերֆեյսի լեզուն"],
            "theme_system": ["ru": "Системная", "en": "System", "hy": "Համակարգային"],
            "theme_light": ["ru": "Светлая", "en": "Light", "hy": "Լուսավոր"],
            "theme_dark": ["ru": "Темная", "en": "Dark", "hy": "Մութ"],
            "settings_reset_api": ["ru": "Сбросить ключ Gemini API", "en": "Reset Gemini API Key", "hy": "Ջնջել Gemini API բանալին"],
            "settings_about": ["ru": "О приложении", "en": "About App", "hy": "Հավելվածի մասին"],
            "settings_developer": ["ru": "Разработчик: Samvel", "en": "Developer: Samvel", "hy": "Մշակող՝ Սամվել"],
            
            // Settings - Weight, API, About
            "settings_weight_tracker": ["ru": "Контроль веса", "en": "Weight Tracker", "hy": "Քաշի վերահսկում"],
            "settings_weight_add": ["ru": "Внести", "en": "Add", "hy": "Ավելացնել"],
            "settings_weight_current": ["ru": "Текущий вес", "en": "Current Weight", "hy": "Ընթացիկ քաշը"],
            "settings_weight_trend_gaining": ["ru": "Набор", "en": "Gaining", "hy": "Աճ"],
            "settings_weight_trend_losing": ["ru": "Снижение", "en": "Losing", "hy": "Նվազում"],
            "settings_weight_trend_stable": ["ru": "Стабилен", "en": "Stable", "hy": "Կայուն"],
            "settings_weight_log_title": ["ru": "Ввести вес", "en": "Log Weight", "hy": "Մուտքագրել քաշը"],
            "settings_weight_log_placeholder": ["ru": "Вес (кг)", "en": "Weight (kg)", "hy": "Քաշ (կգ)"],
            "settings_weight_log_desc": ["ru": "Укажите ваш текущий вес в килограммах.", "en": "Enter your current body weight in kilograms.", "hy": "Մուտքագրեք ձեր ընթացիկ քաշը կիլոգրամներով:"],
            "settings_weight_ai_title": ["ru": "Анализ динамики от ИИ", "en": "AI Weight Analysis", "hy": "ԻԻ քաշի վերլուծություն"],
            "settings_weight_ai_desc": ["ru": "ИИ проанализирует вашу историю веса, тренировок и питания, чтобы дать рекомендации.", "en": "AI will analyze your weight history, workouts, and nutrition to provide insights.", "hy": "ԻԻ-ն կվերլուծի ձեր քաշի պատմությունը, մարզումները և սնունդը՝ եզրակացություն տալու համար:"],
            "settings_weight_ai_key_warning": ["ru": "Пожалуйста, настройте хотя бы один API-ключ ниже для активации ИИ.", "en": "Please configure at least one API key below to activate AI.", "hy": "Խնդրում ենք մուտքագրել առնվազն մեկ API բանալի ստորև՝ ԻԻ-ն ակտիվացնելու համար:"],
            "settings_weight_ai_btn": ["ru": "Анализировать динамику", "en": "Analyze Trend", "hy": "Վերլուծել քաշի միտումը"],
            "settings_api_title": ["ru": "Настройка API-ключей", "en": "API Configurations", "hy": "API Կարգավորումներ"],
            "settings_api_desc": ["ru": "Вы можете ввести несколько ключей. Приложение автоматически переключается между ними при достижении лимитов.", "en": "Add multiple keys. The app automatically rotates keys if one hits usage limits.", "hy": "Ավելացրեք մի քանի բանալի. Հավելվածն ավտոմատ կերպով կփոխի բանալիները, եթե մեկի լիմիտը սպառվի:"],
            "settings_about_desc": ["ru": "Forma — ваш персональный ИИ-ассистент для контроля физической формы, тренировок, активности, водного баланса и распознавания еды с помощью моделей Google Gemini, OpenAI ChatGPT и Anthropic Claude.", "en": "Forma is your personal AI assistant for fitness monitoring, workouts, activity, water balance, and food recognition using Google Gemini, OpenAI ChatGPT, and Anthropic Claude.", "hy": "Forma-ն ձեր անձնական ԻԻ օգնականն է մարզավիճակի, մարզումների, ակտիվության, ջրի հաշվեկշռի և սննդի ճանաչման համար՝ օգտագործելով Google Gemini, OpenAI ChatGPT և Anthropic Claude մոդելները:"],
            
            "water_consumed": ["ru": "Выпито сегодня", "en": "Consumed Today", "hy": "Խմել եք այսօր"],
            "water_add": ["ru": "Добавить воду", "en": "Add Water", "hy": "Ավելացնել ջուր"],
            "water_custom": ["ru": "Ввести кастомный объем", "en": "Enter custom volume", "hy": "Մուտքագրել այլ քանակ"],
            "water_tips": ["ru": "Полезные советы", "en": "Useful Tips", "hy": "Օգտակար խորհուրդներ"],
            
            // Dashboard
            "water_daily_goal": ["ru": "Дневная цель", "en": "Daily Goal", "hy": "Օրական նպատակ"],
            "water_out_of_goal": ["ru": "из %.1f л", "en": "of %.1f L", "hy": "%.1f լ-ից"],
            "water_l": ["ru": "л", "en": "l", "hy": "լ"],
            "water_goal_short": ["ru": "цель", "en": "goal", "hy": "նպատակ"],
            "water_steps_label": ["ru": "Шаги", "en": "Steps", "hy": "Քայլեր"],
            "calories_label": ["ru": "Калории", "en": "Calories", "hy": "Կալորիաներ"],
            "water_workout_label": ["ru": "ТРЕНИРОВКА:", "en": "WORKOUT:", "hy": "ՄԱՐԶՈՒՄ."],
            "water_menu_add_200": ["ru": "Добавить 200 мл", "en": "Add 200 ml", "hy": "Ավելացնել 200 մլ"],
            "water_menu_add_250": ["ru": "Добавить 250 мл", "en": "Add 250 ml", "hy": "Ավելացնել 250 մլ"],
            "water_menu_add_500": ["ru": "Добавить 500 мл", "en": "Add 500 ml", "hy": "Ավելացնել 500 мլ"],
            "water_label": ["ru": "Вода", "en": "Water", "hy": "Ջուր"],
            "activity_title": ["ru": "Активность", "en": "Activity", "hy": "Ակտիվություն"],
            "activity_details": ["ru": "Детали активности", "en": "Activity Details", "hy": "Ակտիվության մանրամասները"],
            "activity_move": ["ru": "Движение", "en": "Move", "hy": "Շարժում"],
            "activity_exercise": ["ru": "Тренировка", "en": "Exercise", "hy": "Մարզում"],
            "activity_stand": ["ru": "Активность", "en": "Stand", "hy": "Կանգնել"],
            "kcal": ["ru": "ккал", "en": "kcal", "hy": "կկալ"],
            "min": ["ru": "мин", "en": "min", "hy": "րոպե"],
            "hrs": ["ru": "ч", "en": "h", "hy": "ժ"],
            "calories_active": ["ru": "Активные калории", "en": "Active Calories", "hy": "Ակտիվ կալորիաներ"],
            "calories_basal": ["ru": "Калории в покое", "en": "Resting Calories", "hy": "Հանգստի կալորիաներ"],
            "calories_total_burned": ["ru": "Всего сожжено", "en": "Total Burned", "hy": "Ընդամենը այրված"],
            "calories_consumed": ["ru": "Потреблено (еда)", "en": "Consumed (food)", "hy": "Ընդունված (սնունդ)"],
            "calories_balance": ["ru": "Баланс калорий", "en": "Calorie Balance", "hy": "Կալորիաների հաշվեկշիռ"],
            "calories_deficit": ["ru": "Дефицит", "en": "Deficit", "hy": "Դեֆիցիտ"],
            "calories_surplus": ["ru": "Профицит", "en": "Surplus", "hy": "Ավելցուկ"],
            "calories_bmr_desc": ["ru": "Базовый метаболизм (BMR) и расход энергии в состоянии покоя.", "en": "Basal metabolic rate (BMR) and resting energy expenditure.", "hy": "Հիմնական նյութափոխանակություն (BMR) և հանգստի էներգիայի ծախս:"],
            "calories_active_desc": ["ru": "Калории, сожженные за счет шагов, бега и тренировок (кольцо Move).", "en": "Calories burned through steps, running, and workouts (Move ring).", "hy": "Քայլքի, վազքի և մարզումների արդյունքում այրված կալորիաներ (Move օղակ):"],
            
            // FoodScanner
            "nutrition_api_required_title": ["ru": "Требуется настроить API-ключ", "en": "API Key Required", "hy": "Պահանջվում է API բանալի"],
            "nutrition_api_required_desc": ["ru": "Для работы ИИ-сканера перейдите на вкладку 'Настройки' и укажите хотя бы один API-ключ (Gemini, ChatGPT или Claude).", "en": "To use the AI scanner, go to the 'Settings' tab and enter at least one API key (Gemini, ChatGPT, or Claude).", "hy": "ԻԻ-սկաների աշխատանքի համար անցեք «Կարգավորումներ» բաժին և մուտքագրեք առնվազն մեկ API բանալի (Gemini, ChatGPT կամ Claude):"],
            "nutrition_scanning": ["ru": "Диетолог анализирует блюдо...", "en": "Nutritionist is analyzing the dish...", "hy": "Դիետոլոգը վերլուծում է ուտեստը..."],
            "nutrition_scan_results": ["ru": "Результаты сканирования", "en": "Scan Results", "hy": "Սկանավորման արդյունքները"],
            "nutrition_serving_weight": ["ru": "Вес порции:", "en": "Serving weight:", "hy": "Բաժնի քաշը."],
            "nutrition_add_meal": ["ru": "Добавить прием пищи", "en": "Add Meal", "hy": "Ավելացնել սնունդ"],
            "cancel": ["ru": "Отмена", "en": "Cancel", "hy": "Չեղարկել"],
            "nutrition_ai_tips": ["ru": "Советы по питанию от ИИ", "en": "AI Nutrition Tips", "hy": "ԻԻ սննդի խորհուրդներ"],
            "nutrition_ai_key_warning": ["ru": "Укажите хотя бы один API-ключ в настройках, чтобы активировать советы ИИ по питанию.", "en": "Enter at least one API key in settings to activate AI nutrition tips.", "hy": "Կարգավորումներում մուտքագրեք առնվազն մեկ API բանալի՝ ԻԻ սննդի խորհուրդներն ակտիվացնելու համար:"],
            "nutrition_ai_desc": ["ru": "ИИ проанализирует вашу калорийность и рацион за последние дни и даст полезные рекомендации по диете.", "en": "AI will analyze your calories and diet over the last few days to provide dietary advice.", "hy": "ԻԻ-ն կվերլուծի ձեր կալորիականությունը և սննդակարգը վերջին օրերին՝ սննդային խորհուրդներ տալու համար:"],
            "nutrition_analyze_btn": ["ru": "Анализировать рацион", "en": "Analyze Diet", "hy": "Վերլուծել սննդակարգը"],
            "nutrition_scan_dish": ["ru": "Скан блюда", "en": "Scan Meal", "hy": "Սկանավորել"],
            "calories_norm_completed": ["ru": "Норма выполнена 🎉", "en": "Goal achieved 🎉", "hy": "Նորման կատարված է 🎉"],
            "calories_remaining_format": ["ru": "Осталось: %@ ккал", "en": "%@ kcal left", "hy": "Մնացել է՝ %@ կկալ"],
            "nutrition_ingredients_title": ["ru": "Ингредиенты на тарелке", "en": "Ingredients on Plate", "hy": "Բաղադրիչներ"],
            "nutrition_add_ingredient": ["ru": "+ Добавить продукт", "en": "+ Add Ingredient", "hy": "+ Ավելացնել բաղադրիչ"],
            "nutrition_ingredient_name": ["ru": "Название продукта", "en": "Ingredient Name", "hy": "Բաղադրիչի անվանումը"],
            "nutrition_health_score": ["ru": "Качество рациона", "en": "Meal Quality", "hy": "Որակը"],
            "nutrition_ai_advice": ["ru": "Совет нутрициолога", "en": "Nutritionist Tip", "hy": "Դիետոլոգի խորհուրդ"],
            "nutrition_barcode_btn": ["ru": "Штрих-код", "en": "Barcode", "hy": "Շտրիխ-կոդ"],
            "nutrition_ai_coach_title": ["ru": "AI-Нутрициолог", "en": "AI Nutritionist", "hy": "ԻԻ Դիետոլոգ"],
            "nutrition_ai_coach_desc": ["ru": "Персональный анализ питания, баланс БЖУ и ответы на любые вопросы по рациону.", "en": "Personalized diet analysis, macro balance, and answers to any nutrition questions.", "hy": "Սննդի անհատական վերլուծություն և խորհրդատվություն:"],
            "nutrition_ai_coach_btn": ["ru": "Спросить нутрициолога", "en": "Ask Nutritionist", "hy": "Հարցնել ԻԻ-ին"],
            "nutrition_protein": ["ru": "Белки", "en": "Protein", "hy": "Սպիտակուցներ"],
            "nutrition_fat": ["ru": "Жиры", "en": "Fats", "hy": "Ճարպեր"],
            "nutrition_carbs": ["ru": "Углеводы", "en": "Carbs", "hy": "Ածխաջրեր"],
            
            "pulse_title": ["ru": "Пульс", "en": "Heart Rate", "hy": "Պուլս"],
            "pulse_bpm": ["ru": "уд/мин", "en": "BPM", "hy": "զ/ր"],
            "pulse_measure": ["ru": "Замер", "en": "Measure", "hy": "Չափել"],
            "pulse_stop": ["ru": "Стоп", "en": "Stop", "hy": "Կանգ"],
            "sleep_title": ["ru": "Сон", "en": "Sleep", "hy": "Քուն"],
            "sleep_great": ["ru": "Отлично", "en": "Great", "hy": "Գերազանց"],
            "sleep_normal": ["ru": "Норма", "en": "Normal", "hy": "Նորմալ"],
            "sleep_analysis_btn": ["ru": "Анализ", "en": "Analysis", "hy": "Վերլուծություն"],
            "sleep_deep_format": ["ru": "Глубокий: %.1f ч", "en": "Deep: %.1f h", "hy": "Խորը՝ %.1f ժ"],
            "sleep_recovery": ["ru": "Восстановление", "en": "Recovery", "hy": "Վերականգնում"],
            "camera": ["ru": "Камера", "en": "Camera", "hy": "Տեսախցիկ"],
            "gallery": ["ru": "Галерея", "en": "Gallery", "hy": "Պատկերասրահ"],
            "demo_apple": ["ru": "Зеленое яблоко 🍏 (Демо)", "en": "Green Apple 🍏 (Demo)", "hy": "Կանաչ խնձոր 🍏 (Դեմո)"],
            "protein": ["ru": "белки", "en": "protein", "hy": "սպիտակուցներ"],
            "fat": ["ru": "жиры", "en": "fat", "hy": "ճարպեր"],
            "carbs": ["ru": "углеводы", "en": "carbs", "hy": "ածխաջրեր"],
            
            // Workouts
            "workouts_select_activity": ["ru": "Выберите активность", "en": "Select Activity", "hy": "Ընտրեք մարզումը"],
            "workouts_start": ["ru": "Начать тренировку", "en": "Start Workout", "hy": "Սկսել մարզումը"],
            "workouts_ai_title": ["ru": "Анализ тренировок от ИИ", "en": "AI Workout Analysis", "hy": "ԻԻ մարզումների վերլուծություն"],
            "workouts_ai_key_warning": ["ru": "Укажите хотя бы один API-ключ на вкладке 'Настройки', чтобы активировать ИИ-тренера.", "en": "Enter at least one API key in settings to activate AI Trainer.", "hy": "Կարգավորումներում մուտքագրեք առնվազն մեկ API բանալի՝ ԻԻ մարզիչն ակտիվացնելու համար:"],
            "workouts_ai_desc": ["ru": "ИИ проанализирует ваши тренировки за последние дни и даст персональные советы по нагрузкам и восстановлению.", "en": "AI will analyze your recent workouts to provide custom exercise and recovery tips.", "hy": "ԻԻ-ն կվերլուծի ձեր վերջին մարզումները՝ ծանրաբեռնվածության և վերականգնման խորհուրդներ տալու համար:"],
            "workouts_analyze_btn": ["ru": "Анализировать тренировки", "en": "Analyze Workouts", "hy": "Վերլուծել մարզումները"],
            "workouts_active": ["ru": "Тренировка активна", "en": "Workout active", "hy": "Մարզումն ակտիվ է"],
            "workouts_autopause": ["ru": "Автопауза (нет движения)", "en": "Auto-paused (no motion)", "hy": "Ավտոդադար (շարժում չկա)"],
            "workouts_paused": ["ru": "Тренировка на паузе", "en": "Workout paused", "hy": "Մարզումը դադարեցված է"],
            "workouts_pause": ["ru": "Пауза", "en": "Pause", "hy": "Դադար"],
            "workouts_resume": ["ru": "Продолжить", "en": "Resume", "hy": "Շարունակել"],
            "music_player_title": ["ru": "Музыка Forma", "en": "Forma Music", "hy": "Forma Երաժշտություն"],
            "music_authorize_apple_music": ["ru": "Разрешить доступ к Apple Music", "en": "Authorize Apple Music", "hy": "Թույլատրել Apple Music մուտքը"],
            "workouts_distance": ["ru": "Расстояние", "en": "Distance", "hy": "Հեռավորություն"],
            "workouts_calories": ["ru": "Калории", "en": "Calories", "hy": "Կալորիաներ"],
            "workouts_steps": ["ru": "Шаги", "en": "Steps", "hy": "Քայլեր"],
            "workouts_record_video": ["ru": "Записать видео тренировки", "en": "Record Workout Video", "hy": "Տեսագրել мարզումը"],
            "workouts_finish": ["ru": "Завершить", "en": "Finish", "hy": "Ավարտել"],
            "workouts_video_saved_title": ["ru": "Видео сохранено!", "en": "Video Saved!", "hy": "Տեսանյութը պահպանված է"],
            "workouts_video_saved_desc": ["ru": "Видеозапись выполнения упражнения успешно сохранена в вашей галерее для соцсетей или отслеживания прогресса.", "en": "The video has been saved to your gallery for social sharing or progress tracking.", "hy": "Մարզման տեսանյութը հաջողությամբ պահպանվել է պատկերասրահում՝ սոցցանցերում կիսվելու կամ առաջընթացին հետևելու համար:"],
            "workouts_finished_title": ["ru": "Тренировка завершена!", "en": "Workout Completed!", "hy": "Մարզումն ավարտվեց"],
            "workouts_finished_desc": ["ru": "Дистанция: %.2f км · Сожжено: %d ккал. Отличная работа!", "en": "Distance: %.2f km · Burned: %d kcal. Great job!", "hy": "Հեռավորություն՝ %.2f կմ · Այրված՝ %d կկալ։ Հիանալի աշխատանք:"],
            "workout_type_run": ["ru": "Бег", "en": "Running", "hy": "Վազք"],
            "workout_type_walk": ["ru": "Ходьба", "en": "Walking", "hy": "Քայլք"],
            "workout_type_cycling": ["ru": "Велоспорт", "en": "Cycling", "hy": "Հեծանվավազք"],
            "workout_type_strength": ["ru": "Силовая", "en": "Strength", "hy": "Ուժային"],
            "workout_type_yoga": ["ru": "Йога", "en": "Yoga", "hy": "Յոգա"],
            "workout_type_swimming": ["ru": "Плавание", "en": "Swimming", "hy": "Լող"],
            "workout_type_jump_rope": ["ru": "Скакалка", "en": "Jump Rope", "hy": "Ցատկապարան"],
            
            // Новые типы тренировок
            "workout_type_dumbbells": ["ru": "Гантели", "en": "Dumbbells", "hy": "Ալտերներ"],
            "workout_type_pushups": ["ru": "Отжимания", "en": "Pushups", "hy": "Հենում-ծալում"],
            "workout_type_squats": ["ru": "Приседания", "en": "Squats", "hy": "Կքանիստեր"],
            "workout_type_plank": ["ru": "Планка", "en": "Plank", "hy": "Պլանկա"],
            
            // Переводы для календаря тренировок, статусов и ИИ-тренера
            "workouts_activity_history": ["ru": "История активности", "en": "Activity History", "hy": "Ակտիվության պատմություն"],
            "today": ["ru": "Сегодня", "en": "Today", "hy": "Այսօր"],
            "workouts_count_badge": ["ru": "%d тренир.", "en": "%d workouts", "hy": "%d մարզում"],
            "workouts_no_workouts_activity": ["ru": "Тренировок нет • Активность дня", "en": "No workouts • Daily activity", "hy": "Մարզումներ չկան • Օրվա ակտիվություն"],
            "workouts_steps_calories_source": ["ru": "Шаги и калории из Apple Health", "en": "Steps and calories from Apple Health", "hy": "Քայլեր և կալորիաներ Apple Health-ից"],
            "workouts_no_workouts_empty": ["ru": "В этот день тренировок не обнаружено.", "en": "No workouts recorded for this day.", "hy": "Այս օրվա համար մարզումներ չեն գտնվել:"],
            "workouts_sensors_empty": ["ru": "Датчики активности не зафиксировали тренировок", "en": "Activity sensors did not record any workouts", "hy": "Սենսորները մարզումներ չեն գրանցել"],
            "coach_msg_presets": ["ru": "Привет! Я твой ИИ-тренер Алекс. Выбери активность из готового списка ниже и давай начнем тренировку!", "en": "Hi! I'm your AI Coach Alex. Choose an activity from the list below and let's start!", "hy": "Ողջույն! Ես քո ԻԻ մարզիչ Ալեքսն եմ: Ընտրիր մարզումը ցանկից և սկսենք:"],
            "coach_msg_custom": ["ru": "Здесь ты можешь создавать свои тренировки с гантелями, приседаниями и отжиманиями. Давай настроим твою личную программу!", "en": "Here you can build your custom workouts with dumbbells, squats, and pushups. Let's create your plan!", "hy": "Այստեղ կարող ես ստեղծել անհատական մարզումներ: Եկ կարգավորենք քո ծրագիրը:"],
            "workouts_time_label": ["ru": "Время тренировок", "en": "Workout Time", "hy": "Մարզման ժամանակ"],
            "workouts_burned_label": ["ru": "Сожжено калорий", "en": "Calories Burned", "hy": "Այրված կալորիաներ"],
            "music_source_radio": ["ru": "Радио", "en": "Radio", "hy": "Ռադիո"],
            "music_source_music": ["ru": "Музыка", "en": "Music", "hy": "Երաժշտություն"],
            "ai_workout_plan_title": ["ru": "Индивидуальный ИИ-план тренировок", "en": "Personal AI Workout Plan", "hy": "Անհատական ԻԻ մարզումների ծրագիր"],
            "ai_workout_plan_desc": ["ru": "Нажмите кнопку ниже, чтобы ИИ-Тренер составил программу тренировок на основе ваших физических параметров (возраст, рост, вес).", "en": "Tap the button below to have AI Coach generate a customized workout plan based on your parameters (age, height, weight).", "hy": "Սեղմեք կոճակը, որպեսզի ԻԻ-ն կազմի անհատական մարզումների ծրագիր ձեր պարամետրերի հիման վրա:"],
            "ai_workout_plan_btn_generate": ["ru": "Составить план тренировки", "en": "Generate Workout Plan", "hy": "Կազմել մարզման ծրագիր"],
            "ai_workout_plan_btn_planning": ["ru": "Планирую тренировку...", "en": "Planning workout...", "hy": "Ծրագրում եմ մարզումը..."],
            "ai_coach_name": ["ru": "Тренер Алекс", "en": "Coach Alex", "hy": "Մարզիչ Ալեքս"],
            "workout_tab_presets": ["ru": "Готовые", "en": "Presets", "hy": "Պատրաստի"],
            "workout_tab_custom": ["ru": "Личные", "en": "Custom", "hy": "Անհատական"],
            "custom_workout_create_title": ["ru": "Новая тренировка", "en": "New Workout", "hy": "Նոր մարզում"],
            "custom_workout_info": ["ru": "Информация о тренировке", "en": "Workout Info", "hy": "Մարզման տվյալներ"],
            "custom_workout_name_placeholder": ["ru": "Название (например, Фулбоди дома)", "en": "Name (e.g., Home Fullbody)", "hy": "Անունը (օр.՝ Տնային Ֆուլբոդի)"],
            "custom_workout_exercises": ["ru": "Упражнения", "en": "Exercises", "hy": "Վարժություններ"],
            "custom_workout_no_exercises": ["ru": "Пока нет упражнений. Добавьте упражнения ниже.", "en": "No exercises yet. Add exercises below.", "hy": "Դեռ չկան վարժություններ: Ավելացրեք ստորև:"],
            "custom_workout_add_exercise": ["ru": "Добавить упражнение", "en": "Add Exercise", "hy": "Ավելացնել վարժություն"],
            "custom_workout_sets": ["ru": "Подходы", "en": "Sets", "hy": "Մոտեցումներ"],
            "custom_workout_reps": ["ru": "Повторения", "en": "Reps", "hy": "Կրկնություններ"],
            "custom_workout_duration": ["ru": "Время", "en": "Time", "hy": "Ժամանակ"],
            "custom_workout_weight": ["ru": "Вес", "en": "Weight", "hy": "Քաշ"],
            "custom_workout_rest": ["ru": "Отдых", "en": "Rest", "hy": "Հանգիսт"],
            "custom_workout_exercise_select": ["ru": "Выбор упражнения", "en": "Choose Exercise", "hy": "Վարժության ընտրություն"],
            "custom_workout_exercise_name": ["ru": "Упражнение", "en": "Exercise", "hy": "Վարժություն"],
            "custom_workout_custom_name": ["ru": "Или свое название", "en": "Or custom name", "hy": "Կամ ձեր անունը"],
            "custom_workout_custom_name_placeholder": ["ru": "Введите название", "en": "Enter name", "hy": "Մուտքագրեք անունը"],
            "custom_workout_exercise_settings": ["ru": "Параметры упражнения", "en": "Exercise Settings", "hy": "Վարժության պարամետրերը"],
            "custom_workout_time_based": ["ru": "На время (таймер)", "en": "Time-based (timer)", "hy": "Ժամանակով (վայրկյանաչափ)"],
            "custom_workout_weight_kg": ["ru": "Вес снаряда", "en": "Equipment weight", "hy": "Ծանրությունը"],
            "custom_workout_add_exercise_title": ["ru": "Параметры упражнения", "en": "Exercise Parameters", "hy": "Վարժության պարամետրերը"],
            "save": ["ru": "Сохранить", "en": "Save", "hy": "Պահպանել"],
            "add": ["ru": "Добавить", "en": "Add", "hy": "Ավելացնել"],
            "sec": ["ru": "сек", "en": "sec", "hy": "վրկ"],
            "kg": ["ru": "кг", "en": "kg", "hy": "կգ"],
            "custom_workout_start_btn": ["ru": "Начать личную тренировку", "en": "Start Custom Workout", "hy": "Սկսել անհատական մարզումը"],
            "custom_workout_next_set": ["ru": "Выполнить подход", "en": "Complete Set", "hy": "Կատարել մոտեցումը"],
            "custom_workout_skip_rest": ["ru": "Пропустить отдых", "en": "Skip Rest", "hy": "Բաց թողնել հանգիստը"],
            "custom_workout_rest_title": ["ru": "Время отдыха", "en": "Rest Time", "hy": "Հանգստի ժամանակ"],
            "custom_workout_finished": ["ru": "Личная тренировка завершена!", "en": "Custom Workout Finished!", "hy": "Անհատական մարզումն ավարտվեց!"],
            "ok": ["ru": "Отлично!", "en": "Great!", "hy": "Հիանալի"],
            
            // Water tracker
            "water_reset": ["ru": "Сбросить", "en": "Reset", "hy": "Ջնջել"],
            "water_custom_volume": ["ru": "Ввести кастомный объем", "en": "Enter custom volume", "hy": "Մուտքագրել այլ քանակ"],
            "water_individual_calc": ["ru": "Индивидуальный расчет", "en": "Individual Calculation", "hy": "Անհատական հաշվարկ"],
            "water_calc_desc_with_weight": ["ru": "На основе вашего веса (%.1f кг) ИИ рекомендует пить около %@ мл воды в сутки (из расчета 35 мл на 1 кг веса).", "en": "Based on your weight (%.1f kg), AI recommends drinking about %@ ml of water per day (35 ml per 1 kg of body weight).", "hy": "Ձեր քաշի հիման վրա (%.1f կգ) ԻԻ-ն խորհուրդ է տալիս օրական խմել մոտ %@ մլ ջուր (օրական 35 մլ՝ 1 կգ քաշի դիմաց):"],
            "water_calc_desc_no_weight": ["ru": "Для индивидуального расчета нормы воды внесите ваш вес в разделе 'Настройки'. Сейчас используется стандартная норма: 2500 мл.", "en": "For an individual water norm calculation, please enter your weight in the 'Settings' section. Currently, a standard norm of 2500 ml is used.", "hy": "Ջրի անհատական նորման հաշվարկելու համար խնդրում ենք մուտքագրել ձեր քաշը «Կարգավորումներ» բաժնում: Այժմ օգտագործվում է ստանդարտ քանակը՝ 2500 մլ:"],
            "water_completed_percent": ["ru": "Выполнено: %.0f%%", "en": "Completed: %.0f%%", "hy": "Կատարված է՝ %.0f%%"],
            "water_goal_achieved": ["ru": "Норма выполнена 🎉", "en": "Goal achieved 🎉", "hy": "Նորման կատարված է 🎉"],
            "water_add_success": ["ru": "Выполнено: %.0f%%", "en": "Completed: %.0f%%", "hy": "Կատարված է՝ %.0f%%"],
            "water_ai_tips": ["ru": "Советы по гидратации от ИИ", "en": "AI Hydration Tips", "hy": "ԻԻ հիդրատացման խորհուրդներ"],
            "water_ai_key_warning": ["ru": "Укажите хотя бы один API-ключ на вкладке 'Настройки', чтобы активировать советы ИИ по гидратации.", "en": "Enter at least one API key in settings to activate AI hydration tips.", "hy": "Կարգավորումներում մուտքագրեք առնվազն մեկ API բանալի՝ ԻԻ հիդրատացման խորհուրդներն ակտիվացնելու համար:"],
            "water_ai_desc": ["ru": "ИИ оценит количество выпитой воды за сегодня относительно вашей цели и вашего веса, дав ценные советы по питьевому режиму.", "en": "AI will evaluate your water intake today relative to your goal and weight, giving valuable advice on your hydration schedule.", "hy": "ԻԻ-ն կգնահատի այսօր խմած ջրի քանակը ձեր նպատակի և քաշի համեմատ՝ օգտակար խորհուրդներ տալով:"],
            "water_analyze_btn": ["ru": "Анализировать питьевой режим", "en": "Analyze Hydration", "hy": "Վերլուծել ջրի ռեժիմը"],
            "water_analyzing_btn": ["ru": "Анализирую...", "en": "Analyzing...", "hy": "Վերլուծում եմ..."],
            "ai_nutrition_plan_desc": ["ru": "Нажмите кнопку ниже, чтобы составить план здорового питания на основе параметров вашего тела и физических нагрузок.", "en": "Tap the button below to generate a healthy meal plan tailored to your body parameters and fitness activity.", "hy": "Սեղմեք կոճակը՝ ձեր մարմնի պարամետրերի հիման վրա առողջ սննդակարգի ծրագիր կազմելու համար:"],
            "ai_nutrition_plan_btn_generate": ["ru": "Составить план питания", "en": "Generate Meal Plan", "hy": "Կազմել սննդակարգի ծրագիր"],
            "ai_nutrition_plan_btn_planning": ["ru": "Планирую рацион...", "en": "Planning diet...", "hy": "Ծրագրում եմ սննդակարգը..."],
            "water_custom_alert_title": ["ru": "Кастомный объем", "en": "Custom Volume", "hy": "Այլ քանակ"],
            "water_custom_alert_placeholder": ["ru": "Объем (мл)", "en": "Volume (ml)", "hy": "Քանակ (մլ)"],
            "water_custom_alert_desc": ["ru": "Введите количество выпитой воды в миллилитрах.", "en": "Enter the amount of water consumed in milliliters.", "hy": "Մուտքագրեք խմած ջրի քանակը միլիլիտրերով:"],
            
            // Фоновый шагомер и цели
            "steps_card_title": ["ru": "Шагомер и активность", "en": "Pedometer & Activity", "hy": "Քայլաչափ և ակտիվություն"],
            "steps_bg_active": ["ru": "Фоновый датчик активен", "en": "Background sensor active", "hy": "Ֆոնային սենսորն ակտիվ է"],
            "steps_bg_syncing": ["ru": "Синхронизация...", "en": "Syncing...", "hy": "Համաժամացում..."],
            "steps_daily_goal": ["ru": "Цель: %d", "en": "Goal: %d", "hy": "Նպատակ՝ %d"],
            "steps_distance_km": ["ru": "%.2f км", "en": "%.2f km", "hy": "%.2f կմ"],
            "steps_floors": ["ru": "%d эт.", "en": "%d fl.", "hy": "%d հարկ"],
            "steps_hourly_title": ["ru": "Активность по часам сегодня", "en": "Hourly Activity Today", "hy": "Այսօրվա ակտիվությունն ըստ ժամերի"],
            "steps_refresh_btn": ["ru": "Обновить шаги", "en": "Refresh Steps", "hy": "Թարմացնել քայլերը"],
            
            // Настройки шагомера
            "settings_step_section": ["ru": "Фоновый шагомер и цели", "en": "Background Pedometer & Goals", "hy": "Ֆոնային քայլաչափ և նպատակներ"],
            "settings_step_goal": ["ru": "Дневная цель шагов", "en": "Daily Step Goal", "hy": "Օրական քայլերի նպատակը"],
            "settings_step_bg_toggle": ["ru": "Фоновый подсчет (CoreMotion)", "en": "Background Tracking (CoreMotion)", "hy": "Ֆոնային հաշվարկ (CoreMotion)"],
            "settings_step_bg_desc": ["ru": "Аппаратный сопроцессор движения Apple считывает шаги 24/7 в фоне без расхода батареи.", "en": "Apple Motion Coprocessor tracks steps 24/7 in background with zero battery impact.", "hy": "Apple շարժման համապրոցեսորը հաշվում է քայլերը 24/7 ֆոնային ռեժիմում առանց մարտկոցի ծախսի:"],
            "settings_step_notif_toggle": ["ru": "Мотивационные уведомления", "en": "Goal Progress Notifications", "hy": "Մոտիվացնող ծանուցումներ"],
            "settings_step_notif_desc": ["ru": "Локальные напоминания при достижении 50%, 80% и 100% дневной нормы шагов.", "en": "Local reminders on reaching 50%, 80%, and 100% of your daily step goal.", "hy": "Տեղային ծանուցումներ օրական նպատակի 50%, 80% և 100% հասնելիս:"],
            "settings_step_last_sync": ["ru": "Последняя синхронизация: %@", "en": "Last Sync: %@", "hy": "Վերջին համաժամացում՝ %@"],
            
            // Локальные мотивационные уведомления
            "notif_step_50_title": ["ru": "🔥 Отличное начало!", "en": "🔥 Great progress!", "hy": "🔥 Հիանալի առաջընթաց:"],
            "notif_step_50_body": ["ru": "Вы преодолели половину пути: %d из %d шагов за сегодня!", "en": "You are halfway there: %d of %d steps today!", "hy": "Դուք անցել եք ճանապարհի կեսը՝ %d-ը %d քայլից այսօր:"],
            "notif_step_80_title": ["ru": "⚡️ Почти у цели!", "en": "⚡️ Almost there!", "hy": "⚡️ Գրեթե հասել եք նպատակին:"],
            "notif_step_80_body": ["ru": "Осталось совсем немного: пройдено %d из %d шагов!", "en": "Just a bit more: %d of %d steps completed!", "hy": "Մնացել է շատ քիչ՝ կատարվել է %d-ը %d քայլից:"],
            "notif_step_100_title": ["ru": "🎉 Дневная цель выполнена!", "en": "🎉 Daily Goal Completed!", "hy": "🎉 Օրական նպատակն ավարտված է:"],
            "notif_step_100_body": ["ru": "Ура! Вы успешно выполнили дневную норму в %d шагов. Отличная форма!", "en": "Hooray! You achieved your %d step goal today. Fantastic work!", "hy": "Ուռա՜: Դուք հաջողությամբ կատարեցիք %d քայլի օրական նորման:"],
            "steps_label": ["ru": "Шаги", "en": "Steps", "hy": "Քայլեր"],
            "distance_label": ["ru": "Дистанция", "en": "Distance", "hy": "Հեռավորություն"],
            "floors_label": ["ru": "Подъемы", "en": "Floors", "hy": "Հարկեր"],
            
            // Apple HealthKit Integration
            "health_kit_title": ["ru": "Apple Здоровье", "en": "Apple Health", "hy": "Apple Առողջություն"],
            "health_kit_connect_banner_title": ["ru": "Подключите Apple Здоровье", "en": "Connect Apple Health", "hy": "Միացրեք Apple Առողջությունը"],
            "health_kit_connect_banner_desc": ["ru": "Автоматически считывайте шаги, кольца активности, пульс, сон и тренировки с ваших устройств Apple.", "en": "Automatically sync steps, activity rings, heart rate, sleep, and workouts from your Apple devices.", "hy": "Ավտոմատ կարդացեք քայլերը, ակտիվության օղակները, պուլսը, քունը և մարզումները ձեր Apple սարքերից:"],
            "health_kit_connect_btn": ["ru": "Подключить в 1 клик", "en": "Connect in 1 Tap", "hy": "Միացնել 1 հպումով"],
            "health_kit_connected": ["ru": "Подключено к Apple Здоровье", "en": "Connected to Apple Health", "hy": "Միացված է Apple Առողջությանը"],
            "health_kit_sync_hub": ["ru": "Центр синхронизации", "en": "Sync Hub", "hy": "Համաժամացման կենտրոն"],
            "health_kit_sync_now": ["ru": "Синхронизировать сейчас", "en": "Sync Now", "hy": "Համաժամացնել հիմա"],
            "health_kit_syncing": ["ru": "Синхронизация данных...", "en": "Syncing data...", "hy": "Տվյալները համաժամացվում են..."],
            "health_kit_last_synced": ["ru": "Синхронизировано: %@", "en": "Last synced: %@", "hy": "Վերջին համաժամացում՝ %@"],
            "health_kit_metrics_synced": ["ru": "Синхронизировано метрик: %d из %d", "en": "Synced metrics: %d of %d", "hy": "Համաժամացված ցուցանիշներ՝ %d-ը %d-ից"],
            "health_kit_metric_steps": ["ru": "Шаги и дистанция", "en": "Steps & Distance", "hy": "Քայլեր և հեռավորություն"],
            "health_kit_metric_rings": ["ru": "Кольца активности", "en": "Activity Rings", "hy": "Ակտիվության օղակներ"],
            "health_kit_metric_heart": ["ru": "Пульс (пульсометр)", "en": "Heart Rate", "hy": "Պուլս"],
            "health_kit_metric_sleep": ["ru": "Анализ сна", "en": "Sleep Analysis", "hy": "Քնի վերլուծություն"],
            "health_kit_metric_water": ["ru": "Водный баланс", "en": "Hydration", "hy": "Ջրի հաշվեկշիռ"],
            "health_kit_metric_weight": ["ru": "Контроль веса", "en": "Body Weight", "hy": "Քաշի վերահսկում"],
            "health_kit_metric_workouts": ["ru": "Тренировки", "en": "Workouts", "hy": "Մարզումներ"],
            "health_kit_auto_export": ["ru": "Авто-экспорт в Apple Здоровье", "en": "Auto-export to Apple Health", "hy": "Ավտո-արտահանում Apple Առողջություն"],
            "health_kit_auto_export_desc": ["ru": "Автоматически сохранять тренировки, выпитую воду и питание в системную базу Apple Health.", "en": "Automatically save workouts, water, and nutrition to Apple Health.", "hy": "Ավտոմատ պահպանել մարզումները, ջուրը և սնունդը Apple Health-ում:"],
            "health_kit_history_sync_title": ["ru": "Импорт истории из Apple Health", "en": "Import Apple Health History", "hy": "Ներմուծել պատմությունը Apple Health-ից"],
            "health_kit_history_sync_desc": ["ru": "Загружает историю активности, тренировок, шагов и динамики веса за 365 дней для глубокой аналитики, календаря и графиков.", "en": "Imports 365 days of activity, workouts, steps, and weight history for deep analytics, calendar, and charts.", "hy": "Բեռնում է 365 օրվա ակտիվությունը, մարզումները, քայլերը և քաշի դինամիկան:"],
            "health_kit_history_sync_btn": ["ru": "Загрузить историю за год (365 дней)", "en": "Import 1-Year History (365 days)", "hy": "Ներմուծել տարվա պատմությունը (365 օր)"],
            "health_kit_history_syncing": ["ru": "Загружаю данные из Apple Health...", "en": "Importing data from Apple Health...", "hy": "Տվյալները բեռնվում են Apple Health-ից..."],
            "health_kit_history_synced_success": ["ru": "История успешно загружена (%d дней, %d тренировок, %d замеров веса)", "en": "History imported (%d days, %d workouts, %d weights)", "hy": "Պատմությունը բեռնվեց (%d օր, %d մարզում, %d քաշ)"],
            "health_kit_open_settings": ["ru": "Настройки Apple Здоровье", "en": "Apple Health Settings", "hy": "Apple Health կարգավորումներ"],
            "health_kit_open_settings_desc": ["ru": "Если показатели не синхронизируются, проверьте разрешения для Forma в системных Настройках iOS.", "en": "If metrics are not syncing, check permissions for Forma in iOS Settings.", "hy": "Եթե ցուցանիշները չեն համաժամացվում, ստուգեք Forma-ի թույլտվությունները iOS Կարգավորումներում:"],
            "health_kit_not_available": ["ru": "HealthKit не поддерживается на этом устройстве", "en": "HealthKit is not available on this device", "hy": "HealthKit-ը հասանելի չէ այս սարքում"],
            
            // AirPods Pro Heart Rate Monitoring & Alerts
            "hr_monitoring_title": ["ru": "Мониторинг пульса (AirPods / Датчики)", "en": "Heart Rate Monitoring (AirPods / Sensors)", "hy": "Պուլսի մոնիտորինգ (AirPods / Սենսորներ)"],
            "hr_monitoring_desc": ["ru": "Непрерывный анализ сердечного ритма с AirPods Pro и аксессуаров. Приложение пришлет уведомление при резком скачке пульса или его успешном восстановлении.", "en": "Continuous heart rate tracking from AirPods Pro and accessories with alerts for sudden spikes or healthy recovery.", "hy": "Պուլսի անընդհատ մոնիտորինգ AirPods Pro-ից՝ ծանուցումներով բարձր պուլսի կամ արագ վերականգնման դեպքում:"],
            "hr_bg_toggle": ["ru": "Фоновый мониторинг пульса", "en": "Background Heart Rate Tracking", "hy": "Պուլսի ֆոնային հետևում"],
            "hr_high_alert_toggle": ["ru": "Оповещение о высоком пульсе в покое", "en": "High Resting Heart Rate Alert", "hy": "Բարձր պուլսի ծանուցում"],
            "hr_high_threshold": ["ru": "Порог высокого пульса", "en": "High HR Threshold", "hy": "Բարձր պուլսի շեմ"],
            "hr_low_alert_toggle": ["ru": "Оповещение о низком пульсе", "en": "Low Heart Rate Alert", "hy": "Ցածր պուլսի ծանուցում"],
            "hr_low_threshold": ["ru": "Порог низкого пульса", "en": "Low HR Threshold", "hy": "Ցածր պուլսի շեմ"],
            "hr_recovery_toggle": ["ru": "Уведомления о восстановлении", "en": "Recovery Notifications", "hy": "Վերականգնման ծանուցումներ"],
            "hr_zone_rest": ["ru": "Покой", "en": "Rest", "hy": "Հանգիստ"],
            "hr_zone_warmup": ["ru": "Разминка", "en": "Warm Up", "hy": "Տաքացում"],
            "hr_zone_fatburn": ["ru": "Жиросжигание", "en": "Fat Burn", "hy": "Ճարպայրում"],
            "hr_zone_cardio": ["ru": "Кардио", "en": "Cardio", "hy": "Կարդիո"],
            "hr_zone_anaerobic": ["ru": "Анаэробная", "en": "Anaerobic", "hy": "Անաէրոբ"],
            "hr_zone_peak": ["ru": "Пиковая", "en": "Peak", "hy": "Պիկային"],
            "hr_notif_high_title": ["ru": "⚠️ Высокий пульс в покое", "en": "⚠️ High Resting Heart Rate", "hy": "⚠️ Բարձր պուլս հանգստի ժամանակ"],
            "hr_notif_high_body": ["ru": "Зафиксирован пульс %d уд/мин в состоянии покоя. Сделайте паузу, подышите и выпейте воды.", "en": "Resting heart rate reached %d bpm. Take a moment to relax, breathe, and drink water.", "hy": "Գրանցվել է %d զ/ր պուլս հանգստի վիճակում: Խորհուրդ է տրվում հանգստանալ և ջուր խմել:"],
            "hr_notif_low_title": ["ru": "⚠️ Пониженный пульс", "en": "⚠️ Low Heart Rate", "hy": "⚠️ Ցածր պուլս"],
            "hr_notif_low_body": ["ru": "Зафиксирован пульс %d уд/мин. Проверьте ваше самочувствие.", "en": "Heart rate dropped to %d bpm. Check how you are feeling.", "hy": "Գրանցվել է %d զ/ր պուլս: Ստուգեք ձեր ինքնազգացողությունը:"],
            "hr_notif_recovery_title": ["ru": "💚 Отличное восстановление!", "en": "💚 Great Heart Recovery!", "hy": "💚 Գերազանց վերականգնում:"],
            "hr_notif_recovery_body": ["ru": "Ваш пульс быстро нормализовался до %d уд/мин после нагрузки. Отличная кардио-форма!", "en": "Your heart rate returned to normal (%d bpm) quickly after exercise. Great cardio shape!", "hy": "Ձեր պուլսը մարզումից հետո արագ իջել է մինչև %d զ/ր: Գերազանց կարդիո-մարզավիճակ:"],
            
            // Экспресс-замер пульса в реальном времени (AirPods Pro / Apple Health)
            "hr_live_title": ["ru": "Пульс в реальном времени", "en": "Live Heart Rate", "hy": "Իրական ժամանակի պուլս"],
            "hr_live_desc": ["ru": "Мгновенный замер пульса с AirPods Pro или пульсометра Apple Health.", "en": "Real-time heart rate measurement from AirPods Pro or Apple Health sensors.", "hy": "Ակնթարթային պուլսի չափում AirPods Pro-ից կամ Apple Health սենսորներից:"],
            "hr_live_start": ["ru": "Начать замер", "en": "Start Live Check", "hy": "Սկսել չափումը"],
            "hr_live_stop": ["ru": "Остановить замер", "en": "Stop Measurement", "hy": "Կանգնեցնել"],
            "hr_live_measuring": ["ru": "Считывание пульса...", "en": "Reading heart rate...", "hy": "Ընթերցվում է պուլսը..."],
            "hr_live_airpods_badge": ["ru": "AirPods Pro", "en": "AirPods Pro", "hy": "AirPods Pro"],
            "hr_live_bpm": ["ru": "уд/мин", "en": "BPM", "hy": "զ/ր"],
            
            // Live Activities & Dynamic Island
            "live_activity_title": ["ru": "Live Activity & Dynamic Island", "en": "Live Activity & Dynamic Island", "hy": "Live Activity և Dynamic Island"],
            "live_activity_desc": ["ru": "Отображает таймер тренировки, пульс из AirPods/Apple Watch, сожженные калории и дистанцию в Dynamic Island и на экране блокировки в реальном времени.", "en": "Shows workout timer, heart rate, calories, and distance in Dynamic Island and on the lock screen in real time.", "hy": "Ցուցադրում է մարզման ժամանակաչափը, պուլսը, կալորիաները և հեռավորությունը Dynamic Island-ում և կողպէկրանին:"],
            "live_activity_status_ready": ["ru": "Активно (Dynamic Island готов)", "en": "Active (Dynamic Island ready)", "hy": "Ակտիվ է (Dynamic Island-ը պատրաստ է)"],
            
            // Voice Coach
            "voice_coach_title": ["ru": "Голосовой ИИ-тренер (AirPods / Динамик)", "en": "AI Voice Coach (AirPods / Speaker)", "hy": "ԻԻ Ձայնային մարզիչ (AirPods / Բարձրախոս)"],
            "voice_coach_desc": ["ru": "Озвучивает отметки пройденных километров, интервалы времени, подходы и пульсовые зоны во время тренировки прямо в ваши наушники с приглушением музыки.", "en": "Announces kilometer splits, time intervals, sets, and heart rate zones during workouts with music ducking.", "hy": "Ձայնով հայտնում է անցած կիլոմետրերը, ժամանակը, մոտեցումները և պուլսը մարզման ժամանակ:"],
            "voice_coach_toggle": ["ru": "Голосовые подсказки тренера", "en": "Voice Coach Guidance", "hy": "Մարզչի ձայնային հուշումներ"],
            "voice_coach_splits": ["ru": "Озвучка каждого пройденного км", "en": "Announce kilometer splits", "hy": "Ամեն անցած կմ-ի ձայնային ծանուցում"],
            "voice_coach_intervals": ["ru": "Озвучка интервалов времени (5 мин)", "en": "Announce time intervals (5 min)", "hy": "Ժամանակի ինտերվալներ (5 րոպե)"],
            "voice_coach_hr_alerts": ["ru": "Голосовое предупреждение о высоком пульсе", "en": "High heart rate voice alert", "hy": "Բարձր պուլսի ձայնային նախազգուշացում"],
            
            // Кольца активности Apple
            "activity_rings_title": ["ru": "Активность за сегодня", "en": "Today's Activity", "hy": "Այսօրվա ակտիվություն"],
            "activity_move_label": ["ru": "Подвижность", "en": "Move", "hy": "Շարժում"],
            "activity_exercise_label": ["ru": "Упражнения", "en": "Exercise", "hy": "Մարզում"],
            "activity_stand_label": ["ru": "С разминкой", "en": "Stand", "hy": "Կանգնած ժամեր"],
            "activity_cal_unit": ["ru": "ккал", "en": "CAL", "hy": "կկալ"],
            "activity_min_unit": ["ru": "мин", "en": "MIN", "hy": "րոպե"],
            "activity_hr_unit": ["ru": "ч", "en": "HRS", "hy": "ժ"],
            
            // CSV Import & Export
            "csv_hub_title": ["ru": "Импорт и экспорт CSV", "en": "CSV Import & Export", "hy": "CSV Ներմուծում և արտահանում"],
            "csv_hub_desc": ["ru": "Загружайте данные тренировок, замеров веса, шагов и питания из CSV-таблиц или экспортируйте историю Forma.", "en": "Import workout, weight, steps, and nutrition records from CSV spreadsheets or export Forma history.", "hy": "Բեռնեք մարզումների, քաշի, քայլերի և սննդի տվյալները CSV ֆայլերից:"],
            "csv_choose_file_btn": ["ru": "Выбрать файл CSV (Файлы / iCloud)", "en": "Choose CSV File (Files / iCloud)", "hy": "Ընտրել CSV ֆայլ (Ֆայլեր / iCloud)"],
            "csv_sync_hk_toggle": ["ru": "Записать также в Apple Health", "en": "Also write to Apple Health", "hy": "Գրանցել նաև Apple Health-ում"],
            "csv_sync_hk_desc": ["ru": "Данные попадут как в Forma, так и в системную базу HealthKit устройства.", "en": "Data will be saved both to Forma and system Apple Health.", "hy": "Տվյալները կպահպանվեն ինչպես Forma-ում, այնպես էլ Apple Health-ում:"],
            "csv_import_btn_format": ["ru": "Импортировать %d записей", "en": "Import %d Records", "hy": "Ներմուծել %d գրառում"],
            "csv_importing": ["ru": "Импортирую данные...", "en": "Importing data...", "hy": "Տվյալները ներմուծվում են..."],
            "csv_export_section_title": ["ru": "Экспорт данных и шаблоны CSV", "en": "Data Export & CSV Templates", "hy": "Տվյալների արտահանում և CSV շաբլոններ"],
            "csv_export_section_desc": ["ru": "Выгрузите вашу историю тренировок и замеров в CSV или скачайте готовые шаблоны для ручного заполнения.", "en": "Export your workout and weight history to CSV or download sample templates.", "hy": "Արտահանեք ձեր պատմությունը CSV ֆորմատով կամ ներբեռնեք շաբլոններ:"],
            "csv_export_workouts": ["ru": "Экспорт тренировок в CSV", "en": "Export Workouts to CSV", "hy": "Արտահանել մարզումները CSV"],
            "csv_export_weight": ["ru": "Экспорт замеров веса в CSV", "en": "Export Weight Logs to CSV", "hy": "Արտահանել քաշի չափումները CSV"],
            "csv_export_activity": ["ru": "Экспорт активности в CSV", "en": "Export Activity to CSV", "hy": "Արտահանել ակտիվությունը CSV"],
            "csv_download_templates": ["ru": "Скачать шаблоны CSV для заполнения", "en": "Download CSV Templates to Fill", "hy": "Ներբեռնել CSV շաբլոններ"],
            "csv_nav_title": ["ru": "Импорт / Экспорт CSV", "en": "CSV Import / Export", "hy": "CSV Ներմուծում / Արտահանում"],
            "csv_success_workouts": ["ru": "Успешно импортировано %d тренировок!", "en": "Successfully imported %d workouts!", "hy": "Հաջողությամբ ներմուծվեց %d մարզում:"],
            "csv_success_weight": ["ru": "Успешно импортировано %d замеров веса!", "en": "Successfully imported %d weight logs!", "hy": "Հաջողությամբ ներմուծվեց %d քաշի գրանցում:"],
            "csv_success_activity": ["ru": "Успешно импортировано %d дней активности!", "en": "Successfully imported %d activity days!", "hy": "Հաջողությամբ ներմուծվեց %d օրվա ակտիվություն:"],
            "csv_success_nutrition": ["ru": "Успешно импортировано %d записей питания!", "en": "Successfully imported %d nutrition records!", "hy": "Հաջողությամբ ներմուծվեց %d սննդի գրանցում:"]
        ]
        
        return translations[key]?[lang] ?? translations[key]?["ru"] ?? key
    }
    
    /// Склонение слова «шаг» в зависимости от числа и языка
    public static func pluralSteps(_ count: Int, lang: String) -> String {
        switch lang {
        case "ru":
            let n = abs(count) % 100
            let n1 = n % 10
            if n > 10 && n < 20 {
                return "шагов"
            }
            if n1 > 1 && n1 < 5 {
                return "шага"
            }
            if n1 == 1 {
                return "шаг"
            }
            return "шагов"
        case "en":
            return count == 1 ? "step" : "steps"
        case "hy":
            return "քայլ"
        default:
            return "шагов"
        }
    }
    
    /// Форматирование целых чисел с локализованным разделителем тысяч (неразрывный пробел для ru/hy, запятая для en)
    public static func formatNumber(_ number: Int, lang: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        switch lang {
        case "ru", "hy":
            formatter.groupingSeparator = "\u{00A0}" // Неразрывный пробел
        default:
            formatter.groupingSeparator = ","
        }
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

// Официальный премиальный логотип Forma (Спортивная монограмма «F» с атлетом)
public struct AppLogoView: View {
    public var size: CGFloat
    public var showBackground: Bool
    
    public init(size: CGFloat = 40, showBackground: Bool = true) {
        self.size = size
        self.showBackground = showBackground
    }
    
    public var body: some View {
        ZStack {
            if showBackground {
                // Подложка - глубокий темный обсидиан / темное матовое стекло
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 26/255, green: 28/255, blue: 36/255),
                                Color(red: 12/255, green: 13/255, blue: 18/255)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .overlay(
                        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.24),
                                        Color.white.opacity(0.04)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: max(1, size * 0.025)
                            )
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: size * 0.2, x: 0, y: size * 0.08)
            }
            
            // Фирменный логотип Forma с бегуном на монограмме «F»
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: size * (showBackground ? 0.78 : 1.0), height: size * (showBackground ? 0.78 : 1.0))
                .clipShape(RoundedRectangle(cornerRadius: size * (showBackground ? 0.20 : 0.28), style: .continuous))
        }
        .frame(width: size, height: size)
    }
}

public struct FormaGlyphFView: View {
    public var size: CGFloat
    
    public init(size: CGFloat = 32) {
        self.size = size
    }
    
    public var body: some View {
        ZStack {
            // Заднее неоновое свечение контура (Electric Cyan & Magenta)
            FormaFShape()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0/255, green: 220/255, blue: 255/255).opacity(0.7),
                            Color(red: 255/255, green: 40/255, blue: 120/255).opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: size * 0.08, lineCap: .round, lineJoin: .round)
                )
                .frame(width: size, height: size)
                .blur(radius: size * 0.04)
                .offset(x: -size * 0.02, y: -size * 0.02)
            
            // Основное тело монограммы F (Sunset Flame Gradient)
            FormaFShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 255/255, green: 130/255, blue: 60/255), // Яркий солнечный коралл
                            Color(red: 255/255, green: 65/255, blue: 85/255),  // Пламенный неон
                            Color(red: 255/255, green: 30/255, blue: 90/255)   // Глубокий кармин
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: Color(red: 255/255, green: 65/255, blue: 85/255).opacity(0.5), radius: size * 0.12, x: 0, y: size * 0.05)
            
            // Среднее аэродинамическое крыло активности (Biometric Energy Wing)
            FormaMidWingShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 255/255, green: 165/255, blue: 75/255),
                            Color(red: 255/255, green: 85/255, blue: 75/255)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: Color(red: 255/255, green: 100/255, blue: 60/255).opacity(0.4), radius: size * 0.08)
            
            // Верхний глянцевый блик (Specular highlight)
            FormaFHighlightShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.55),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
    }
}

// Контур основного тела буквы F с динамичным спортивным изгибом
struct FormaFShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Верхнее крыло и вертикальный ствол буквы F
        path.move(to: CGPoint(x: w * 0.88, y: h * 0.22))
        // Верхняя кромка
        path.addQuadCurve(
            to: CGPoint(x: w * 0.22, y: h * 0.16),
            control: CGPoint(x: w * 0.50, y: h * 0.14)
        )
        // Плавный левый изгиб ствола вниз (динамичный наклон бегуна)
        path.addQuadCurve(
            to: CGPoint(x: w * 0.16, y: h * 0.88),
            control: CGPoint(x: w * 0.24, y: h * 0.50)
        )
        // Закругленный нижний кончик
        path.addQuadCurve(
            to: CGPoint(x: w * 0.36, y: h * 0.76),
            control: CGPoint(x: w * 0.26, y: h * 0.88)
        )
        // Внутренняя грань ствола вверх
        path.addQuadCurve(
            to: CGPoint(x: w * 0.44, y: h * 0.38),
            control: CGPoint(x: w * 0.40, y: h * 0.56)
        )
        // Нижняя грань верхнего крыла направо
        path.addQuadCurve(
            to: CGPoint(x: w * 0.88, y: h * 0.22),
            control: CGPoint(x: w * 0.68, y: h * 0.34)
        )
        path.closeSubpath()
        return path
    }
}

// Среднее крыло буквы F
struct FormaMidWingShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        path.move(to: CGPoint(x: w * 0.26, y: h * 0.56))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.74, y: h * 0.48),
            control: CGPoint(x: w * 0.50, y: h * 0.46)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.66, y: h * 0.62),
            control: CGPoint(x: w * 0.74, y: h * 0.58)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.26, y: h * 0.56),
            control: CGPoint(x: w * 0.44, y: h * 0.64)
        )
        path.closeSubpath()
        return path
    }
}

// Блик верхнего гребня
struct FormaFHighlightShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        path.move(to: CGPoint(x: w * 0.84, y: h * 0.22))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.26, y: h * 0.17),
            control: CGPoint(x: w * 0.52, y: h * 0.15)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.84, y: h * 0.22),
            control: CGPoint(x: w * 0.54, y: h * 0.21)
        )
        path.closeSubpath()
        return path
    }
}
