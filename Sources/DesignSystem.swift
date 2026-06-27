import SwiftUI

// Дизайн-система приложения SamHealth
public enum Theme {
    public static let background = Color(red: 0.0, green: 0.0, blue: 0.0) // Чистый черный #000000
    public static let cardBackground = Color(red: 28/255, green: 28/255, blue: 30/255) // Темно-серый #1C1C1E
    
    // Цвета колец активности
    public static let moveColor = Color(red: 255/255, green: 45/255, blue: 85/255) // Розовый/Красный
    public static let exerciseColor = Color(red: 50/255, green: 215/255, blue: 75/255) // Ярко-зеленый
    public static let standColor = Color(red: 90/255, green: 200/255, blue: 250/255) // Голубой
    
    // Вспомогательные цвета
    public static let pulseColor = Color(red: 255/255, green: 59/255, blue: 48/255)
    public static let sleepColor = Color(red: 90/255, green: 94/255, blue: 226/255)
    public static let waterColor = Color(red: 0/255, green: 122/255, blue: 255/255)
    public static let weightColor = Color(red: 255/255, green: 204/255, blue: 0/255)
    
    public static let textPrimary = Color.white
    public static let textSecondary = Color.gray
}

// Кастомный модификатор для неоморфных/глянцевых карточек
struct PremiumCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Theme.cardBackground)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(LinearGradient(
                        colors: [Color.white.opacity(0.1), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ), lineWidth: 1)
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
    var ringWidth: CGFloat = 14
    
    public var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: ringWidth)
            
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
                .font(.system(size: ringWidth * 0.8, weight: .bold))
                .foregroundColor(.white)
                .offset(y: -ringWidth * 0.05)
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
            ActivityRing(progress: moveProgress, color: Theme.moveColor, iconName: "arrow.right", ringWidth: 16)
                .padding(0)
            ActivityRing(progress: exerciseProgress, color: Theme.exerciseColor, iconName: "arrow.up.forward", ringWidth: 16)
                .padding(20)
            ActivityRing(progress: standProgress, color: Theme.standColor, iconName: "figure.stand", ringWidth: 16)
                .padding(40)
        }
        .frame(width: 140, height: 140)
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
                .foregroundColor(Theme.textSecondary)
            Text(value)
                .font(.headline)
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
        case .up: return Theme.pulseColor // Красный (набор веса)
        case .down: return Theme.exerciseColor // Зеленый (снижение веса)
        case .stable: return Theme.textSecondary // Серый (стабильный)
        }
    }
}

