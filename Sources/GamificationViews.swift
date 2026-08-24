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
public struct AchievementCelebrationOverlay: View {
    let achievement: FormaAchievement
    var onDismiss: () -> Void
    
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.0
    
    public var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            VStack(spacing: 20) {
                // Бейдж
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [Color.yellow.opacity(0.5), Color.clear]),
                                center: .center,
                                startRadius: 20,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                    
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.yellow, Color.orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 90, height: 90)
                        .shadow(color: Color.orange.opacity(0.6), radius: 20, x: 0, y: 8)
                    
                    Image(systemName: achievement.icon)
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 6) {
                    Text("НОВОЕ ДОСТИЖЕНИЕ! 🎉")
                        .font(.caption.bold())
                        .foregroundColor(.orange)
                        .tracking(1.2)
                    
                    Text(achievement.title)
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    Text(achievement.description)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                
                // Награда XP
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.yellow)
                    Text("+\(achievement.xpReward) XP добавлено к уровню")
                        .font(.subheadline.bold())
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
                .padding(.top, 10)
            }
            .padding(24)
            .background(Color(red: 25/255, green: 25/255, blue: 30/255))
            .cornerRadius(28)
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(Color.yellow.opacity(0.4), lineWidth: 1.5)
            )
            .padding(.horizontal, 32)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                    scale = 1.0
                    opacity = 1.0
                }
            }
        }
    }
}
