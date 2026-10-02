import SwiftUI

// MARK: - GamificationSummaryCard (Карточка ранга и стрика на главном экране)
public struct GamificationSummaryCard: View {
    @ObservedObject private var manager = GamificationManager.shared
    public var onTap: () -> Void
    
    public init(onTap: @escaping () -> Void) {
        self.onTap = onTap
    }
    
    public var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                HStack(alignment: .center, spacing: 14) {
                    // Аватар уровня / Ранг
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [manager.currentRank.color.opacity(0.8), manager.currentRank.color],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 46, height: 46)
                            .shadow(color: manager.currentRank.color.opacity(0.4), radius: 8, x: 0, y: 3)
                        
                        Image(systemName: manager.currentRank.icon)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(manager.currentRank.title)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(Theme.textPrimary)
                            
                            Text("Ур. \(manager.currentRank.level)")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundColor(manager.currentRank.color)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(manager.currentRank.color.opacity(0.12))
                                .cornerRadius(6)
                        }
                        
                        Text("\(manager.totalXP) XP • \(manager.achievements.filter { $0.isUnlocked }.count)/\(manager.achievements.count) бейджей")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                    
                    Spacer()
                    
                    // Стрик непрерывных дней
                    HStack(spacing: 5) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 15))
                            .foregroundColor(.orange)
                        
                        Text("\(manager.currentStreak)")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                        
                        Text("дн.")
                            .font(.caption2.bold())
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.12))
                    .cornerRadius(12)
                }
                
                // Прогресс-бар XP до следующего уровня
                VStack(spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.primary.opacity(0.08))
                                .frame(height: 6)
                            
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [manager.currentRank.color, Theme.standColor],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * CGFloat(manager.currentRank.progress), height: 6)
                        }
                    }
                    .frame(height: 6)
                    
                    HStack {
                        if let next = manager.nextRank {
                            Text("До «\(next.title)»:")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                            Text("\(manager.currentRank.maxXP - manager.totalXP) XP")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(manager.currentRank.color)
                        } else {
                            Text("Максимальный ранг!")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Theme.pulseColor)
                            Spacer()
                            Text("Легенда")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Theme.pulseColor)
                        }
                    }
                }
            }
            .padding(14)
            .background(Theme.cardBackground)
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(manager.currentRank.color.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.02), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - GamificationHubView (Главный экран достижений и наград)
public struct GamificationHubView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var manager = GamificationManager.shared
    @State private var selectedCategory: String = "Все"
    
    private let categories = ["Все", "Шаги", "Тренировки", "Водный баланс", "Стрики"]
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 22) {
                        
                        // 1. HERO РАНГ И УРОВЕНЬ
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            gradient: Gradient(colors: [manager.currentRank.color.opacity(0.35), manager.currentRank.color.opacity(0.0)]),
                                            center: .center,
                                            startRadius: 20,
                                            endRadius: 70
                                        )
                                    )
                                    .frame(width: 140, height: 140)
                                
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [manager.currentRank.color.opacity(0.85), manager.currentRank.color],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                    .shadow(color: manager.currentRank.color.opacity(0.4), radius: 14, x: 0, y: 6)
                                
                                Image(systemName: manager.currentRank.icon)
                                    .font(.system(size: 38, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(spacing: 4) {
                                Text(manager.currentRank.title)
                                    .font(.title2.bold())
                                    .foregroundColor(Theme.textPrimary)
                                
                                Text("Уровень \(manager.currentRank.level) • \(manager.totalXP) Всего XP")
                                    .font(.subheadline)
                                    .foregroundColor(manager.currentRank.color)
                                    .bold()
                            }
                            
                            // Прогресс до следующего уровня
                            VStack(spacing: 6) {
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(Color.primary.opacity(0.08))
                                            .frame(height: 8)
                                        
                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    colors: [manager.currentRank.color, Theme.standColor],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(width: geo.size.width * CGFloat(manager.currentRank.progress), height: 8)
                                    }
                                }
                                .frame(height: 8)
                                
                                HStack {
                                    Text("\(manager.xpForCurrentLevel) XP")
                                        .font(.caption2.bold())
                                        .foregroundColor(Theme.textSecondary)
                                    Spacer()
                                    if let next = manager.nextRank {
                                        Text("Следующий: \(next.title) (\(next.minXP) XP)")
                                            .font(.caption2.bold())
                                            .foregroundColor(Theme.textSecondary)
                                    } else {
                                        Text("Максимальный ранг!")
                                            .font(.caption2.bold())
                                            .foregroundColor(Theme.pulseColor)
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 4)
                        }
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .background(Theme.cardBackground)
                        .cornerRadius(24)
                        .padding(.horizontal)
                        
                        // 2. СТРИКИ СЕРИИ АКТИВНОСТИ
                        HStack(spacing: 14) {
                            // Текущий стрик
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: "flame.fill")
                                        .foregroundColor(.orange)
                                    Text("Текущий стрик")
                                        .font(.caption.bold())
                                        .foregroundColor(Theme.textSecondary)
                                }
                                
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text("\(manager.currentStreak)")
                                        .font(.system(size: 28, weight: .black, design: .rounded))
                                        .foregroundColor(Theme.textPrimary)
                                    Text("дней")
                                        .font(.caption.bold())
                                        .foregroundColor(Theme.textSecondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(Theme.cardBackground)
                            .cornerRadius(18)
                            
                            // Рекорд стрика
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: "crown.fill")
                                        .foregroundColor(.yellow)
                                    Text("Лучший рекорд")
                                        .font(.caption.bold())
                                        .foregroundColor(Theme.textSecondary)
                                }
                                
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text("\(manager.bestStreak)")
                                        .font(.system(size: 28, weight: .black, design: .rounded))
                                        .foregroundColor(Theme.textPrimary)
                                    Text("дней")
                                        .font(.caption.bold())
                                        .foregroundColor(Theme.textSecondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(Theme.cardBackground)
                            .cornerRadius(18)
                        }
                        .padding(.horizontal)
                        
                        // 3. ФИЛЬТР КАТЕГОРИЙ
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(categories, id: \.self) { cat in
                                    Button(action: {
                                        selectedCategory = cat
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }) {
                                        Text(cat)
                                            .font(.caption.bold())
                                            .foregroundColor(selectedCategory == cat ? .white : Theme.textPrimary)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(selectedCategory == cat ? Theme.exerciseColor : Color.primary.opacity(0.06))
                                            .cornerRadius(20)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // 4. СПИСОК ДОСТИЖЕНИЙ
                        let filtered = manager.achievements.filter {
                            if selectedCategory == "Все" { return true }
                            return $0.category.rawValue == selectedCategory
                        }
                        
                        LazyVStack(spacing: 12) {
                            ForEach(filtered) { achievement in
                                AchievementRowView(achievement: achievement)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Награды и Ранг")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(Theme.exerciseColor)
                }
            }
        }
    }
}

// MARK: - Карточка одного достижения
struct AchievementRowView: View {
    let achievement: FormaAchievement
    
    var progressPercent: Double {
        guard achievement.targetValue > 0 else { return 0 }
        return min(1.0, achievement.currentValue / achievement.targetValue)
    }
    
    var body: some View {
        HStack(spacing: 14) {
            // Иконка бейджа
            ZStack {
                Circle()
                    .fill(
                        achievement.isUnlocked
                        ? LinearGradient(colors: [Color.yellow.opacity(0.9), Color.orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 48, height: 48)
                    .shadow(color: achievement.isUnlocked ? Color.orange.opacity(0.35) : Color.clear, radius: 8, x: 0, y: 3)
                
                Image(systemName: achievement.isUnlocked ? achievement.icon : "lock.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(achievement.isUnlocked ? .white : Theme.textSecondary.opacity(0.6))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(achievement.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(achievement.isUnlocked ? Theme.textPrimary : Theme.textSecondary)
                    
                    Spacer()
                    
                    Text("+\(achievement.xpReward) XP")
                        .font(.caption2.bold())
                        .foregroundColor(achievement.isUnlocked ? .green : Theme.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background((achievement.isUnlocked ? Color.green : Color.gray).opacity(0.12))
                        .cornerRadius(6)
                }
                
                Text(achievement.description)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(2)
                
                if !achievement.isUnlocked {
                    VStack(alignment: .trailing, spacing: 2) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.primary.opacity(0.06))
                                    .frame(height: 4)
                                
                                Capsule()
                                    .fill(Theme.exerciseColor)
                                    .frame(width: geo.size.width * CGFloat(progressPercent), height: 4)
                            }
                        }
                        .frame(height: 4)
                        .padding(.top, 2)
                        
                        Text("\(Int(achievement.currentValue)) / \(Int(achievement.targetValue))")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                    }
                } else if let date = achievement.unlockedDate {
                    Text("Разблокировано \(formatDate(date))")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.green.opacity(0.8))
                        .padding(.top, 2)
                }
            }
        }
        .padding(14)
        .background(Theme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(achievement.isUnlocked ? Color.orange.opacity(0.3) : Color.white.opacity(0.05), lineWidth: 1)
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: date)
    }
}

// MARK: - Праздничный экран при разблокировке достижения (Celebration Overlay)
//
// Анимация в духе наград Apple Fitness: медаль вылетает с оборотами вокруг вертикальной оси,
// «приземляется» с лёгким покачиванием, после чего от неё расходится круговой салют
// (ударные кольца + частицы). Медаль живая: блик скользит при наклоне телефона,
// её можно покрутить пальцем. При включённом «Уменьшении движения» показывается статичная версия.

// MARK: Палитра медали

/// Цветовая схема медали: зависит от категории достижения (как цвета наград в Apple Fitness).
struct AchievementMedalPalette {
    let light: Color
    let mid: Color
    let dark: Color
    /// Цвета частиц салюта (ровно 4)
    let burst: [Color]
}

extension FormaAchievement.AchievementCategory {
    var medalPalette: AchievementMedalPalette {
        switch self {
        case .steps:
            return AchievementMedalPalette(
                light: Color(red: 0.62, green: 1.00, blue: 0.66),
                mid: Color(red: 0.20, green: 0.80, blue: 0.40),
                dark: Color(red: 0.04, green: 0.42, blue: 0.22),
                burst: [
                    Color(red: 0.62, green: 1.00, blue: 0.66),
                    Color(red: 0.20, green: 0.80, blue: 0.40),
                    Color.white,
                    Color(red: 0.95, green: 1.00, blue: 0.40)
                ]
            )
        case .workouts:
            return AchievementMedalPalette(
                light: Color(red: 1.00, green: 0.78, blue: 0.40),
                mid: Color(red: 1.00, green: 0.50, blue: 0.12),
                dark: Color(red: 0.62, green: 0.20, blue: 0.04),
                burst: [
                    Color(red: 1.00, green: 0.86, blue: 0.30),
                    Color(red: 1.00, green: 0.50, blue: 0.12),
                    Color.white,
                    Color(red: 1.00, green: 0.35, blue: 0.30)
                ]
            )
        case .water:
            return AchievementMedalPalette(
                light: Color(red: 0.65, green: 0.95, blue: 1.00),
                mid: Color(red: 0.10, green: 0.65, blue: 0.95),
                dark: Color(red: 0.03, green: 0.30, blue: 0.62),
                burst: [
                    Color(red: 0.65, green: 0.95, blue: 1.00),
                    Color(red: 0.10, green: 0.65, blue: 0.95),
                    Color.white,
                    Color(red: 0.50, green: 0.80, blue: 1.00)
                ]
            )
        case .streaks:
            return AchievementMedalPalette(
                light: Color(red: 1.00, green: 0.60, blue: 0.62),
                mid: Color(red: 1.00, green: 0.23, blue: 0.33),
                dark: Color(red: 0.58, green: 0.05, blue: 0.18),
                burst: [
                    Color(red: 1.00, green: 0.60, blue: 0.62),
                    Color(red: 1.00, green: 0.23, blue: 0.33),
                    Color.white,
                    Color(red: 1.00, green: 0.62, blue: 0.20)
                ]
            )
        case .master:
            return AchievementMedalPalette(
                light: Color(red: 1.00, green: 0.92, blue: 0.55),
                mid: Color(red: 0.98, green: 0.74, blue: 0.18),
                dark: Color(red: 0.60, green: 0.38, blue: 0.04),
                burst: [
                    Color(red: 1.00, green: 0.92, blue: 0.55),
                    Color(red: 0.98, green: 0.74, blue: 0.18),
                    Color.white,
                    Color(red: 0.72, green: 0.45, blue: 1.00)
                ]
            )
        }
    }
}

// MARK: Математика анимации

private func medalClamp01(_ x: Double) -> Double {
    return min(max(x, 0.0), 1.0)
}

private func medalEaseOutCubic(_ x: Double) -> Double {
    return 1.0 - pow(1.0 - x, 3.0)
}

private func medalEaseOutBack(_ x: Double) -> Double {
    let c1 = 1.70158
    let c3 = c1 + 1.0
    return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)
}

// MARK: Частицы салюта

private struct AchievementSeededGenerator: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

private struct AchievementBurstParticle {
    enum Kind {
        case dot
        case streak
        case confetti
    }

    let angle: Double
    let speed: Double
    let size: CGFloat
    let life: Double
    let delay: Double
    let colorIndex: Int
    let kind: Kind
    let spin: Double

    /// Три волны частиц, расходящихся ровными кольцами (получается «круглый салют»).
    static func generate(seed: UInt64) -> [AchievementBurstParticle] {
        var rng = AchievementSeededGenerator(state: seed)
        var result: [AchievementBurstParticle] = []

        let waves: [(delay: Double, count: Int, speed: ClosedRange<Double>, size: ClosedRange<Double>, life: Double)] = [
            (0.00, 64, 330.0...400.0, 3.0...6.0, 1.5),
            (0.35, 48, 250.0...320.0, 2.5...5.0, 1.4),
            (0.70, 36, 170.0...240.0, 2.0...4.0, 1.3)
        ]

        for (waveIndex, wave) in waves.enumerated() {
            let step = 2.0 * Double.pi / Double(wave.count)
            for i in 0..<wave.count {
                let base = Double(i) * step + (waveIndex % 2 == 0 ? 0.0 : step / 2.0)
                let jitter = Double.random(in: -0.04...0.04, using: &rng)
                let kind: Kind
                switch i % 3 {
                case 0: kind = .streak
                case 1: kind = .dot
                default: kind = .confetti
                }
                result.append(
                    AchievementBurstParticle(
                        angle: base + jitter,
                        speed: Double.random(in: wave.speed, using: &rng),
                        size: CGFloat(Double.random(in: wave.size, using: &rng)),
                        life: wave.life * Double.random(in: 0.85...1.1, using: &rng),
                        delay: wave.delay,
                        colorIndex: Int.random(in: 0..<4, using: &rng),
                        kind: kind,
                        spin: Double.random(in: -8.0...8.0, using: &rng)
                    )
                )
            }
        }
        return result
    }
}

// MARK: Медаль

/// Блик на медали: `tiltSheen` — мягкий отблеск, следующий за наклоном, `glint` — резкая полоса света
/// (-2 — блик выключен, дальше скользит примерно от -0.6 до 1.6).
struct AchievementMedalSheen: View {
    let tiltSheen: Double
    let glint: Double

    var body: some View {
        ZStack {
            Circle().fill(
                LinearGradient(
                    stops: [
                        Gradient.Stop(color: Color.clear, location: 0.0),
                        Gradient.Stop(color: Color.white.opacity(0.28), location: 0.5),
                        Gradient.Stop(color: Color.clear, location: 1.0)
                    ],
                    startPoint: UnitPoint(x: tiltSheen - 0.4, y: 0.0),
                    endPoint: UnitPoint(x: tiltSheen + 0.4, y: 1.0)
                )
            )
            Circle().fill(
                LinearGradient(
                    stops: [
                        Gradient.Stop(color: Color.clear, location: 0.38),
                        Gradient.Stop(color: Color.white.opacity(0.75), location: 0.5),
                        Gradient.Stop(color: Color.clear, location: 0.62)
                    ],
                    startPoint: UnitPoint(x: glint - 0.5, y: 0.0),
                    endPoint: UnitPoint(x: glint + 0.5, y: 1.0)
                )
            )
        }
        .allowsHitTesting(false)
    }
}

/// Лицевая сторона медали: металлический ободок, выпуклая грань, гравированное кольцо и иконка.
struct AchievementMedalFace: View {
    let icon: String
    let palette: AchievementMedalPalette
    let size: CGFloat
    let tiltSheen: Double
    let glint: Double

    var body: some View {
        ZStack {
            Circle().fill(
                LinearGradient(
                    colors: [palette.light, palette.dark, palette.light.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            Circle().strokeBorder(
                LinearGradient(
                    colors: [Color.white.opacity(0.9), Color.white.opacity(0.05), Color.white.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 2.5
            )
            Circle()
                .fill(
                    RadialGradient(
                        colors: [palette.light, palette.mid, palette.dark],
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 2,
                        endRadius: size * 0.62
                    )
                )
                .padding(size * 0.075)
            Circle()
                .strokeBorder(Color.black.opacity(0.25), lineWidth: 1.5)
                .padding(size * 0.075)
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.55), Color.black.opacity(0.25)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
                .padding(size * 0.16)
            Circle()
                .stroke(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [0.5, 7]))
                .padding(size * 0.12)

            Image(systemName: icon)
                .font(.system(size: size * 0.38, weight: .black))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.white, palette.light],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: palette.dark.opacity(0.9), radius: 0, x: 0, y: 2)
                .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 4)

            AchievementMedalSheen(tiltSheen: tiltSheen, glint: glint)
        }
        .frame(width: size, height: size)
    }
}

/// Обратная сторона медали (видна, пока она вращается в полёте или если её сильно покрутить).
struct AchievementMedalBack: View {
    let palette: AchievementMedalPalette
    let size: CGFloat
    let tiltSheen: Double
    let glint: Double

    var body: some View {
        ZStack {
            Circle().fill(
                LinearGradient(
                    colors: [palette.light, palette.dark, palette.light.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            Circle().strokeBorder(
                LinearGradient(
                    colors: [Color.white.opacity(0.9), Color.white.opacity(0.05), Color.white.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 2.5
            )
            Circle()
                .fill(
                    RadialGradient(
                        colors: [palette.mid, palette.dark],
                        center: UnitPoint(x: 0.5, y: 0.35),
                        startRadius: 2,
                        endRadius: size * 0.6
                    )
                )
                .padding(size * 0.075)
            Circle()
                .strokeBorder(Color.white.opacity(0.3), lineWidth: 1.2)
                .padding(size * 0.16)

            Text("FORMA")
                .font(.system(size: size * 0.15, weight: .black, design: .rounded))
                .tracking(size * 0.02)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.white.opacity(0.85), palette.light.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: palette.dark, radius: 0, x: 0, y: 1.5)

            AchievementMedalSheen(tiltSheen: tiltSheen, glint: glint)
        }
        .frame(width: size, height: size)
    }
}

// MARK: Экран празднования

public struct AchievementCelebrationOverlay: View {
    let achievement: FormaAchievement
    var onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var tilt = DeviceTiltManager.shared

    @State private var startDate = Date()
    @State private var particles: [AchievementBurstParticle] = AchievementBurstParticle.generate(seed: 20260101)
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var releaseDate: Date? = nil
    @State private var releaseOffset: CGSize = .zero

    private let medalSize: CGFloat = 176
    /// Через сколько секунд после появления медаль «взрывается» салютом
    private let burstDelay: Double = 0.55
    private let burstDuration: Double = 2.6

    public init(achievement: FormaAchievement, onDismiss: @escaping () -> Void) {
        self.achievement = achievement
        self.onDismiss = onDismiss
    }

    public var body: some View {
        let palette = achievement.category.medalPalette

        TimelineView(.animation(paused: reduceMotion)) { context in
            let t: Double = reduceMotion ? 99.0 : max(0.0, context.date.timeIntervalSince(startDate))
            content(palette: palette, t: t, now: context.date)
        }
        .onAppear {
            tilt.startMonitoring()
        }
        .onDisappear {
            tilt.stopMonitoring()
        }
        .task {
            await playHaptics()
        }
    }

    // MARK: Содержимое

    @ViewBuilder
    private func content(palette: AchievementMedalPalette, t: Double, now: Date) -> some View {
        ZStack {
            Color.black
                .opacity(0.84 * medalClamp01(t / 0.3))
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    onDismiss()
                }

            RadialGradient(
                colors: [palette.mid.opacity(0.35 * medalClamp01(t / 0.8)), Color.clear],
                center: .center,
                startRadius: 10,
                endRadius: 360
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 28) {
                medal(palette: palette, t: t, now: now)
                    .frame(width: medalSize, height: medalSize)
                    .overlay(
                        burstCanvas(palette: palette, t: t)
                            .frame(width: 520, height: 520)
                            .allowsHitTesting(false)
                    )

                textBlock(t: t)
            }
            .padding(.horizontal, 28)
        }
    }

    // MARK: Медаль в движении

    private func medal(palette: AchievementMedalPalette, t: Double, now: Date) -> some View {
        let spinProgress = medalClamp01(t / 1.0)
        let spin = -720.0 * (1.0 - medalEaseOutCubic(spinProgress))
        let settleTime = t - 1.0
        let settle: Double = settleTime > 0 ? 7.0 * sin(settleTime * 9.0) * exp(-settleTime * 3.2) : 0.0
        let scale = 0.2 + 0.8 * medalEaseOutBack(medalClamp01(t / 0.8))
        let opacity = medalClamp01(t / 0.2)
        let float: Double = (settleTime > 0 && !reduceMotion) ? sin(settleTime * 1.8) * 3.5 : 0.0
        let pulse = 0.7 + 0.2 * sin(t * 2.0)

        let live = currentDrag(now: now)
        let dragYaw = min(max(Double(live.width) * 0.45, -75.0), 75.0)
        let dragPitch = min(max(Double(-live.height) * 0.35, -60.0), 60.0)
        let tiltYaw = tilt.tiltX * 12.0
        let tiltPitch = min(max((tilt.tiltY + 0.8) * 10.0, -12.0), 12.0)

        let yaw = spin + settle + dragYaw + tiltYaw
        let pitch = dragPitch + tiltPitch
        let showsBack = cos(yaw * Double.pi / 180.0) < 0

        let tiltSheen = 0.5 + tilt.tiltX * 0.3 + Double(live.width) / 300.0
        let glint = glintPosition(t: t)

        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [palette.light.opacity(0.55), Color.clear],
                        center: .center,
                        startRadius: medalSize * 0.35,
                        endRadius: medalSize * 1.1
                    )
                )
                .frame(width: medalSize * 2.2, height: medalSize * 2.2)
                .scaleEffect(scale)
                .opacity(opacity * pulse)

            ZStack {
                AchievementMedalFace(
                    icon: achievement.icon,
                    palette: palette,
                    size: medalSize,
                    tiltSheen: tiltSheen,
                    glint: glint
                )
                .opacity(showsBack ? 0.0 : 1.0)

                AchievementMedalBack(
                    palette: palette,
                    size: medalSize,
                    tiltSheen: tiltSheen,
                    glint: glint
                )
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(showsBack ? 1.0 : 0.0)
            }
            .rotation3DEffect(.degrees(yaw), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .rotation3DEffect(.degrees(pitch), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
            .scaleEffect(scale)
            .offset(y: CGFloat(float))
            .opacity(opacity)
            .shadow(color: palette.mid.opacity(0.55), radius: 28, x: 0, y: 10)
            .gesture(dragGesture)
        }
    }

    /// Положение резкого блика: после приземления пробегает по медали каждые ~3 секунды.
    private func glintPosition(t: Double) -> Double {
        guard !reduceMotion, t >= 1.0 else { return -2.0 }
        let cycle = (t - 1.0).truncatingRemainder(dividingBy: 3.2)
        guard cycle < 1.1 else { return -2.0 }
        return -0.6 + (cycle / 1.1) * 2.2
    }

    // MARK: Жесты

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                isDragging = true
                releaseDate = nil
                dragOffset = value.translation
            }
            .onEnded { value in
                isDragging = false
                releaseOffset = value.translation
                releaseDate = Date()
                dragOffset = .zero
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
    }

    /// Пока палец на медали — следуем за ним, после отпускания медаль пружинит обратно.
    private func currentDrag(now: Date) -> CGSize {
        if isDragging {
            return dragOffset
        }
        guard let release = releaseDate else { return .zero }
        let dt = now.timeIntervalSince(release)
        if dt > 2.0 {
            return .zero
        }
        let k = exp(-5.0 * dt) * cos(11.0 * dt)
        return CGSize(width: releaseOffset.width * CGFloat(k), height: releaseOffset.height * CGFloat(k))
    }

    // MARK: Салют

    private func burstCanvas(palette: AchievementMedalPalette, t: Double) -> some View {
        let bt = t - burstDelay
        let duration = burstDuration
        let items = particles
        let colors = palette.burst
        let ringColor = palette.light

        return Canvas { ctx, size in
            guard bt > 0, bt < duration else { return }
            let center = CGPoint(x: size.width / 2, y: size.height / 2)

            // Ударные кольца
            for ringDelay in [0.0, 0.35] {
                let lt = bt - ringDelay
                guard lt > 0, lt < 0.9 else { continue }
                let p = lt / 0.9
                let radius = 24.0 + 210.0 * (1.0 - pow(1.0 - p, 3.0))
                let rect = CGRect(
                    x: center.x - CGFloat(radius),
                    y: center.y - CGFloat(radius),
                    width: CGFloat(radius * 2),
                    height: CGFloat(radius * 2)
                )
                ctx.stroke(
                    Path(ellipseIn: rect),
                    with: .color(ringColor.opacity(0.65 * (1.0 - p))),
                    lineWidth: CGFloat(4.0 * (1.0 - p) + 0.5)
                )
            }

            // Частицы: скорость гаснет экспоненциально, плюс лёгкая гравитация
            let drag = 2.4
            for particle in items {
                let lt = bt - particle.delay
                guard lt > 0, lt < particle.life else { continue }
                let progress = lt / particle.life
                let radius = particle.speed * (1.0 - exp(-drag * lt)) / drag
                let x = center.x + CGFloat(cos(particle.angle) * radius)
                let y = center.y + CGFloat(sin(particle.angle) * radius + 45.0 * lt * lt)
                let alpha = pow(1.0 - progress, 1.3)
                let color = colors[particle.colorIndex % colors.count].opacity(alpha)
                let sz = particle.size * CGFloat(1.0 - 0.55 * progress)

                switch particle.kind {
                case .dot:
                    let rect = CGRect(x: x - sz, y: y - sz, width: sz * 2, height: sz * 2)
                    ctx.fill(Path(ellipseIn: rect), with: .color(color))
                case .streak:
                    let prev = max(lt - 0.07, 0.0)
                    let prevRadius = particle.speed * (1.0 - exp(-drag * prev)) / drag
                    let x0 = center.x + CGFloat(cos(particle.angle) * prevRadius)
                    let y0 = center.y + CGFloat(sin(particle.angle) * prevRadius + 45.0 * prev * prev)
                    var path = Path()
                    path.move(to: CGPoint(x: x0, y: y0))
                    path.addLine(to: CGPoint(x: x, y: y))
                    ctx.stroke(
                        path,
                        with: .color(color),
                        style: StrokeStyle(lineWidth: sz * 0.8, lineCap: .round)
                    )
                case .confetti:
                    var layer = ctx
                    layer.translateBy(x: x, y: y)
                    layer.rotate(by: .radians(particle.spin * lt))
                    let piece = CGRect(x: -sz, y: -sz * 0.45, width: sz * 2, height: sz * 0.9)
                    layer.fill(Path(roundedRect: piece, cornerRadius: 1), with: .color(color))
                }
            }
        }
    }

    // MARK: Текст и кнопка

    private func textBlock(t: Double) -> some View {
        let p = medalClamp01((t - 0.95) / 0.5)
        let xpProgress = medalEaseOutCubic(medalClamp01((t - 1.1) / 0.9))
        let xpShown = Int((Double(achievement.xpReward) * xpProgress).rounded())

        return VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text("НОВОЕ ДОСТИЖЕНИЕ! 🎉")
                    .font(.caption.bold())
                    .foregroundColor(.orange)
                    .tracking(1.2)

                Text(achievement.title)
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text(achievement.description)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                Text("+\(xpShown) XP добавлено к уровню")
                    .font(.subheadline.bold())
                    .monospacedDigit()
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.12))
            .cornerRadius(20)

            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onDismiss()
            }) {
                Text("Отлично!")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color.yellow, Color.orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: Color.orange.opacity(0.35), radius: 8, x: 0, y: 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
        }
        .opacity(p)
        .offset(y: CGFloat((1.0 - p) * 18.0))
    }

    // MARK: Тактильный отклик

    /// Удар в момент салюта и затихающие «отголоски». Задача отменяется вместе с исчезновением экрана.
    @MainActor
    private func playHaptics() async {
        guard !reduceMotion else { return }
        do {
            try await Task.sleep(nanoseconds: UInt64(burstDelay * 1_000_000_000))
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            try await Task.sleep(nanoseconds: 400_000_000)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            try await Task.sleep(nanoseconds: 350_000_000)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } catch {
            return
        }
    }
}
