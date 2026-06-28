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
            
            // Nutrition Tabs
            "nutrition_tab_food": ["ru": "Еда", "en": "Food", "hy": "Սնունդ"],
            "nutrition_tab_water": ["ru": "Вода", "en": "Water", "hy": "Ջուր"],
            "nutrition_tab_weight": ["ru": "Вес", "en": "Weight", "hy": "Քաշ"],
            
            // Health Summary / Dashboard Insights
            "dashboard_summary_title": ["ru": "СВОДКА ЗДОРОВЬЯ", "en": "HEALTH SUMMARY", "hy": "ԱՌՈՂՋՈՒԹՅԱՆ ԱՄՓՈՓՈՒՄ"],
            "ai_coach_title": ["ru": "Персональный ИИ-Тренер", "en": "Personal AI Coach", "hy": "Անհատական ԻԻ Մարզիչ"],
            "ai_coach_empty_desc": ["ru": "Пока нет рекомендаций на сегодня. Нажмите кнопку ниже, чтобы ИИ-Тренер оценил вашу активность.", "en": "No recommendations for today yet. Tap the button below to get an AI coach evaluation.", "hy": "Այսօրվա համար դեռ խորհուրդներ չկան: Սեղմեք կոճակը ստորև՝ ԻԻ Մարզչի գնահատականը ստանալու համար:"],
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
            "settings_about_desc": ["ru": "Nano Health — ваш персональный ИИ-ассистент для контроля здоровья, тренировок, водного баланса и распознавания еды с помощью моделей Google Gemini, OpenAI ChatGPT и Anthropic Claude.", "en": "Nano Health is your personal AI assistant for health monitoring, workouts, water balance, and food recognition using Google Gemini, OpenAI ChatGPT, and Anthropic Claude.", "hy": "Nano Health-ը ձեր անձնական ԻԻ օգնականն է առողջության վերահսկման, մարզումների, ջրի հաշվեկշռի և սննդի ճանաչման համար՝ օգտագործելով Google Gemini, OpenAI ChatGPT և Anthropic Claude մոդելները:"],
            
            "water_consumed": ["ru": "Выпито сегодня", "en": "Consumed Today", "hy": "Խմել եք այսօր"],
            "water_add": ["ru": "Добавить воду", "en": "Add Water", "hy": "Ավելացնել ջուր"],
            "water_custom": ["ru": "Ввести кастомный объем", "en": "Enter custom volume", "hy": "Մուտքագրել այլ քանակ"],
            "water_tips": ["ru": "Полезные советы", "en": "Useful Tips", "hy": "Օգտակար խորհուրդներ"],
            
            // Dashboard
            "water_daily_goal": ["ru": "Дневная цель", "en": "Daily Goal", "hy": "Օրական նպատակ"],
            "water_l": ["ru": "л", "en": "l", "hy": "լ"],
            "water_goal_short": ["ru": "цель", "en": "goal", "hy": "նպատակ"],
            "water_steps_label": ["ru": "ШАГИ:", "en": "STEPS:", "hy": "ՔԱՅԼԵՐ."],
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
            "nutrition_analyzing": ["ru": "Анализирую...", "en": "Analyzing...", "hy": "Վերլուծվում է..."],
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
            "music_player_title": ["ru": "Музыка Nano Health", "en": "Nano Health Music", "hy": "Nano Health Երաժշտություն"],
            "music_authorize_apple_music": ["ru": "Разрешить доступ к Apple Music", "en": "Authorize Apple Music", "hy": "Թույլատրել Apple Music մուտքը"],
            "workouts_distance": ["ru": "Расстояние", "en": "Distance", "hy": "Հեռավորություն"],
            "workouts_calories": ["ru": "Калории", "en": "Calories", "hy": "Կալորիաներ"],
            "workouts_steps": ["ru": "Шаги", "en": "Steps", "hy": "Քայլեր"],
            "workouts_record_video": ["ru": "Записать видео тренировки", "en": "Record Workout Video", "hy": "Տեսագրել мարզումը"],
            "workouts_finish": ["ru": "Завершить", "en": "Finish", "hy": "Ավարտել"],
            "workouts_video_saved_title": ["ru": "Видео сохранено!", "en": "Video Saved!", "hy": "Տեսանյութը պահպանված է"],
            "workouts_video_saved_desc": ["ru": "Видеозапись выполнения упражнения успешно сохранена в вашей галерее для соцсетей или отслеживания прогресса.", "en": "The video has been saved to your gallery for social sharing or progress tracking.", "hy": "Մարզման տեսանյութը հաջողությամբ պահպանվել է պատկերասրահում՝ սոցցանցերում կիսվելու կամ առաջընթացին հետևելու համար:"],
            "workouts_finished_title": ["ru": "Тренировка завершена!", "en": "Workout Completed!", "hy": "Մարզումն ավարտվեց"],
            "workout_type_run": ["ru": "Бег", "en": "Running", "hy": "Վազք"],
            "workout_type_walk": ["ru": "Ходьба", "en": "Walking", "hy": "Քայլք"],
            "workout_type_cycling": ["ru": "Велоспорт", "en": "Cycling", "hy": "Հեծանվավազք"],
            "workout_type_strength": ["ru": "Силовая", "en": "Strength", "hy": "Ուժային"],
            "workout_type_yoga": ["ru": "Йога", "en": "Yoga", "hy": "Յոգա"],
            "workout_type_swimming": ["ru": "Плавание", "en": "Swimming", "hy": "Լող"],
            "workout_type_jump_rope": ["ru": "Скакалка", "en": "Jump Rope", "hy": "Ցատկապարան"],
            "ok": ["ru": "Отлично!", "en": "Great!", "hy": "Հիանալի"],
            
            // Water tracker
            "water_reset": ["ru": "Сбросить", "en": "Reset", "hy": "Ջնջել"],
            "water_custom_volume": ["ru": "Ввести кастомный объем", "en": "Enter custom volume", "hy": "Մուտքագրել այլ քանակ"],
            "water_individual_calc": ["ru": "Индивидуальный расчет", "en": "Individual Calculation", "hy": "Անհատական հաշվարկ"],
            "water_calc_desc_with_weight": ["ru": "На основе вашего веса (%.1f кг) ИИ рекомендует пить около %.0f мл воды в сутки (из расчета 35 мл на 1 кг веса).", "en": "Based on your weight (%.1f kg), AI recommends drinking about %.0f ml of water per day (35 ml per 1 kg of body weight).", "hy": "Ձեր քաշի հիման վրա (%.1f կգ) ԻԻ-ն խորհուրդ է տալիս օրական խմել մոտ %.0f մլ ջուր (օրական 35 մլ՝ 1 կգ քաշի դիմաց):"],
            "water_calc_desc_no_weight": ["ru": "Для индивидуального расчета нормы воды внесите ваш вес в разделе 'Настройки'. Сейчас используется стандартная норма: 2500 мл.", "en": "For an individual water norm calculation, please enter your weight in the 'Settings' section. Currently, a standard norm of 2500 ml is used.", "hy": "Ջրի անհատական նորման հաշվարկելու համար խնդրում ենք մուտքագրել ձեր քաշը «Կարգավորումներ» բաժնում: Այժմ օգտագործվում է ստանդարտ քանակը՝ 2500 մլ:"],
            "water_ai_tips": ["ru": "Советы по гидратации от ИИ", "en": "AI Hydration Tips", "hy": "ԻԻ հիդրատացման խորհուրդներ"],
            "water_ai_key_warning": ["ru": "Укажите хотя бы один API-ключ на вкладке 'Настройки', чтобы активировать советы ИИ по гидратации.", "en": "Enter at least one API key in settings to activate AI hydration tips.", "hy": "Կարգավորումներում մուտքագրեք առնвազն մեկ API բանալի՝ ԻԻ հիդրատացման խորհուրդներն ակտիվացնելու համար:"],
            "water_ai_desc": ["ru": "ИИ оценит количество выпитой воды за сегодня относительно вашей цели и вашего веса, дав ценные советы по питьевому режиму.", "en": "AI will evaluate your water intake today relative to your goal and weight, giving valuable advice on your hydration schedule.", "hy": "ԻԻ-ն կգնահատի այսօր խմած ջրի քանակը ձեր նպատակի և քաշի համեմատ՝ օգտակար խորհուրդներ տալով:"],
            "water_analyze_btn": ["ru": "Анализировать питьевой режим", "en": "Analyze Hydration", "hy": "Վերլուծել ջրի ռեժիմը"],
            "water_custom_alert_title": ["ru": "Кастомный объем", "en": "Custom Volume", "hy": "Այլ քանակ"],
            "water_custom_alert_placeholder": ["ru": "Объем (мл)", "en": "Volume (ml)", "hy": "Քանակ (մլ)"],
            "water_custom_alert_desc": ["ru": "Введите количество выпитой воды в миллилитрах.", "en": "Enter the amount of water consumed in milliliters.", "hy": "Մուտքագրեք խմած ջրի քանակը միլիլիտրերով:"]
        ]
        
        return translations[key]?[lang] ?? translations[key]?["ru"] ?? key
    }
}

// Векторный анимированный логотип Nano Health на SwiftUI
public struct AppLogoView: View {
    public var size: CGFloat
    
    public init(size: CGFloat = 40) {
        self.size = size
    }
    
    public var body: some View {
        ZStack {
            // Градиентный фон с неоновым свечением
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 255/255, green: 45/255, blue: 85/255), // Розовый
                            Color(red: 0/255, green: 229/255, blue: 255/255)  // Неоновый голубой
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: Color(red: 255/255, green: 45/255, blue: 85/255).opacity(0.35), radius: size / 4, x: 0, y: size / 8)
            
            // Белая иконка молнии внутри сердца (символ энергии и здоровья)
            Image(systemName: "bolt.heart.fill")
                .font(.system(size: size * 0.55, weight: .bold))
                .foregroundColor(.white)
        }
    }
}
