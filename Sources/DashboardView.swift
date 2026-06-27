import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var health: HealthKitManager
    @State private var showingScanner = false
    
    // Вспомогательный метод для выбора вкладки тренировок
    var onStartWorkout: ((String) -> Void)? = nil
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            // Основной Дашборд Nano Health (загружается сразу, без онбординга HealthKit)
            ScrollView {
                VStack(spacing: 20) {
                    
                    // Заголовок в стиле Nano Health
                    HStack {
                        Text("Nano Health")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                        Spacer()
                        
                        // Аватарка профиля
                        Image(systemName: "person.crop.circle")
                            .font(.title)
                            .foregroundColor(Theme.textPrimary)
                            .onTapGesture {
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                            }
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    
                    // 1. КАРТОЧКА WATER TRACKER (Ключевая деталь макета)
                    VStack(spacing: 16) {
                        HStack {
                            Text("Water Tracker")
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(.white)
                            Spacer()
                            Text("Daily Goal")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        let progress = health.waterGoal > 0 ? health.waterConsumed / health.waterGoal : 0.0
                        
                        HStack(spacing: 24) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Water Intake")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.white.opacity(0.6))
                                Text(String(format: "%.1f L", health.waterConsumed / 1000.0))
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Text(String(format: "goal: %.1f L", health.waterGoal / 1000.0))
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            
                            Spacer()
                            
                            // Glowing Ring + Custom GlassWaterView
                            ZStack {
                                Circle()
                                    .stroke(Color.white.opacity(0.08), lineWidth: 10)
                                
                                Circle()
                                    .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color(red: 0/255, green: 229/255, blue: 255/255), Color(red: 0/255, green: 145/255, blue: 255/255)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                                    )
                                    .rotationEffect(Angle(degrees: -90))
                                    .neonShadow(color: Color(red: 0/255, green: 229/255, blue: 255/255), radius: 6)
                                    .animation(.spring(), value: progress)
                                
                                GlassWaterView(progress: progress)
                            }
                            .frame(width: 110, height: 110)
                        }
                        .padding(.vertical, 8)
                        
                        Divider()
                            .background(Color.white.opacity(0.15))
                        
                        // Нижний ряд показателей: Шаги | Кнопка-Меню + 🍌 | Последняя тренировка
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("STEPS:")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white.opacity(0.5))
                                Text(String(format: "%d", health.stepsToday))
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            
                            Spacer()
                            
                            // Кнопка-Меню + 🍌 (выбор объема выпитой воды: 200 мл, 250 мл, 500 мл)
                            Menu {
                                Button("Добавить 200 мл") {
                                    health.addWater(amount: 200.0)
                                    let impact = UIImpactFeedbackGenerator(style: .medium)
                                    impact.impactOccurred()
                                }
                                Button("Добавить 250 мл 🍌") {
                                    health.addWater(amount: 250.0)
                                    let impact = UIImpactFeedbackGenerator(style: .medium)
                                    impact.impactOccurred()
                                }
                                Button("Добавить 500 мл") {
                                    health.addWater(amount: 500.0)
                                    let impact = UIImpactFeedbackGenerator(style: .medium)
                                    impact.impactOccurred()
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                        .font(.caption)
                                    Text("🍌")
                                        .font(.body)
                                }
                                .bold()
                                .foregroundColor(.white)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(Color(red: 0/255, green: 122/255, blue: 255/255))
                                .cornerRadius(20)
                                .shadow(color: Color(red: 0/255, green: 122/255, blue: 255/255).opacity(0.4), radius: 8)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("LAST WORKOUT:")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white.opacity(0.5))
                                Text(health.lastWorkoutString)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                    }
                    .padding(20)
                    .background(Theme.waterCardGradient)
                    .cornerRadius(28)
                    .shadow(color: Color(red: 15/255, green: 32/255, blue: 67/255).opacity(0.2), radius: 15, x: 0, y: 8)
                    .padding(.horizontal)
                    
                    // 2. ДВЕ КАРТОЧКИ: ACTIVITY RINGS И QUICK WORKOUTS (Рядом, как на макете)
                    HStack(alignment: .top, spacing: 16) {
                        
                        // Левая колонка - Кольца активности
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Activity Rings 🍌")
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(Theme.textPrimary)
                            
                            ActivityRingsGroup(
                                moveProgress: health.activeEnergyGoal > 0 ? health.activeEnergyBurned / health.activeEnergyGoal : 0,
                                exerciseProgress: health.exerciseGoal > 0 ? health.exerciseTime / health.exerciseGoal : 0,
                                standProgress: health.standGoal > 0 ? health.standHours / health.standGoal : 0
                            )
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                        }
                        .frame(maxWidth: .infinity)
                        .premiumCard()
                        
                        // Правая колонка - Быстрый старт тренировок
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Workouts")
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(Theme.textPrimary)
                            
                            VStack(spacing: 8) {
                                WorkoutRow(title: "Run 🍌", icon: "figure.run", color: Theme.moveColor) {
                                    onStartWorkout?("Run")
                                }
                                WorkoutRow(title: "Strength 🍌", icon: "figure.strengthtraining.functional", color: Theme.exerciseColor) {
                                    onStartWorkout?("Strength")
                                }
                                WorkoutRow(title: "Yoga 🍌", icon: "figure.mind.and.body", color: Theme.standColor) {
                                    onStartWorkout?("Yoga")
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .premiumCard()
                    }
                    .padding(.horizontal)
                    
                    // 3. ДОПОЛНИТЕЛЬНАЯ КАРТОЧКА: ДЕТАЛИ КОЛЕЦ АКТИВНОСТИ
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Activity Details")
                                .font(.headline)
                                .foregroundColor(Theme.textPrimary)
                            Spacer()
                        }
                        
                        HStack(spacing: 16) {
                            ActivityTextValue(
                                title: "Подвижность",
                                value: String(format: "%.0f / %.0f ккал", health.activeEnergyBurned, health.activeEnergyGoal),
                                color: Theme.moveColor
                            )
                            Spacer()
                            ActivityTextValue(
                                title: "Упражнения",
                                value: String(format: "%.0f / %.0f мин", health.exerciseTime, health.exerciseGoal),
                                color: Theme.exerciseColor
                            )
                            Spacer()
                            ActivityTextValue(
                                title: "Разминка",
                                value: String(format: "%.0f / %.0f ч", health.standHours, health.standGoal),
                                color: Theme.standColor
                            )
                        }
                    }
                    .premiumCard()
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .refreshable {
                health.fetchAllData()
            }
        }
    }
}
