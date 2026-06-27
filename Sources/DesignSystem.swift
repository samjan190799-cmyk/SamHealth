import SwiftUI

// Дизайн-система приложения SamHealth с адаптивной поддержкой темной/светлой тем
public enum Theme {
    // Фон приложения - адаптивный
    public static var background: Color {
        Color(UIColor { trait in
            return trait.userInterfaceStyle == .dark
                ? UIColor(red: 10/255, green: 10/255, blue: 12/255, alpha: 1.0)
                : UIColor(red: 243/255, green: 244/255, blue: 246/255, alpha: 1.0)
        })
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

// Кастомный модификатор для адаптивных премиум карточек
struct PremiumCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Theme.cardBackground)
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 5)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
    }
}

extension View {
    public func premiumCard() -> some View {
        self.modifier(PremiumCardModifier())
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
public struct WeeklyStepsData: Identifiable, Equatable {
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
            
            "settings_theme": ["ru": "Тема оформления", "en": "App Theme", "hy": "Հավելվածի թեման"],
            "settings_language": ["ru": "Язык интерфейса", "en": "Interface Language", "hy": "Ինտերֆեյսի լեզուն"],
            "theme_system": ["ru": "Системная", "en": "System", "hy": "Համակարգային"],
            "theme_light": ["ru": "Светлая", "en": "Light", "hy": "Լուսավոր"],
            "theme_dark": ["ru": "Темная", "en": "Dark", "hy": "Մութ"],
            "settings_reset_api": ["ru": "Сбросить ключ Gemini API", "en": "Reset Gemini API Key", "hy": "Ջնջել Gemini API բանալին"],
            "settings_about": ["ru": "О приложении", "en": "About App", "hy": "Հավելվածի մասին"],
            "settings_developer": ["ru": "Разработчик: Samvel", "en": "Developer: Samvel", "hy": "Մշակող՝ Սամվել"],
            
            "water_consumed": ["ru": "Выпито сегодня", "en": "Consumed Today", "hy": "Խմել եք այսօր"],
            "water_add": ["ru": "Добавить воду", "en": "Add Water", "hy": "Ավելացնել ջուր"],
            "water_custom": ["ru": "Ввести кастомный объем", "en": "Enter custom volume", "hy": "Մուտքագրել այլ քանակ"],
            "water_tips": ["ru": "Полезные советы", "en": "Useful Tips", "hy": "Օգտակար խորհուրդներ"]
        ]
        
        return translations[key]?[lang] ?? translations[key]?["ru"] ?? key
    }
}
