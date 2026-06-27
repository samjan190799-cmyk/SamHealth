import SwiftUI

// Дизайн-система приложения SamHealth (Светлая тема Nano Health)
public enum Theme {
    // Фон приложения - очень мягкий светло-серый градиент
    public static let background = Color(red: 243/255, green: 244/255, blue: 246/255)
    // Фоновый цвет карточек - чистый белый
    public static let cardBackground = Color.white
    
    // Цвета колец активности
    public static let moveColor = Color(red: 255/255, green: 45/255, blue: 85/255) // Розовый/Красный
    public static let exerciseColor = Color(red: 50/255, green: 215/255, blue: 75/255) // Ярко-зеленый
    public static let standColor = Color(red: 0/255, green: 229/255, blue: 255/255) // Неоновый голубой
    
    // Вспомогательные цвета
    public static let pulseColor = Color(red: 255/255, green: 59/255, blue: 48/255)
    public static let sleepColor = Color(red: 90/255, green: 94/255, blue: 226/255)
    public static let waterColor = Color(red: 0/255, green: 191/255, blue: 255/255) // Неоновый синий
    public static let weightColor = Color(red: 255/255, green: 204/255, blue: 0/255)
    
    // Цвета текста
    public static let textPrimary = Color(red: 17/255, green: 24/255, blue: 39/255) // Угольный темный
    public static let textSecondary = Color(red: 107/255, green: 114/255, blue: 128/255) // Серый
    
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

// Кастомный модификатор для неоморфных/глянцевых карточек светлой темы
struct PremiumCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Theme.cardBackground)
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 5)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.black.opacity(0.03), lineWidth: 1)
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

// Кастомный неоновый стакан воды
public struct GlassWaterView: View {
    public var progress: Double
    
    public init(progress: Double) {
        self.progress = progress
    }
    
    public var body: some View {
        ZStack {
            // Вода внутри стакана с маской по форме стакана
            GeometryReader { geo in
                let fillHeight = CGFloat(min(max(progress, 0.0), 1.0)) * geo.size.height
                
                VStack {
                    Spacer()
                    Rectangle()
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
