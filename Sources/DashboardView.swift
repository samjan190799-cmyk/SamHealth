import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var health: HealthKitManager
    @State private var showingScanner = false
    @AppStorage("app_language") private var appLanguage = "ru"
    
    var onStartWorkout: ((String) -> Void)? = nil
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    
                    // Заголовок
                    HStack {
                        Text("Nano Health")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    
                    // 1. КАРТОЧКА ТРЕКЕРА ВОДЫ
                    VStack(spacing: 16) {
                        HStack {
                            Text(LocalizationManager.tr("water_title", lang: appLanguage))
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(.white)
                            Spacer()
                            Text(appLanguage == "en" ? "Daily Goal" : (appLanguage == "hy" ? "Օրական նպատակ" : "Дневная цель"))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        let progress = health.waterGoal > 0 ? health.waterConsumed / health.waterGoal : 0.0
                        
                        HStack(spacing: 24) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(LocalizationManager.tr("water_consumed", lang: appLanguage))
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.white.opacity(0.6))
                                Text(String(format: "%.1f %@", health.waterConsumed / 1000.0, appLanguage == "en" ? "l" : (appLanguage == "hy" ? "լ" : "л")))
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Text(String(format: "%@: %.1f %@", appLanguage == "en" ? "goal" : (appLanguage == "hy" ? "նպատակ" : "цель"), health.waterGoal / 1000.0, appLanguage == "en" ? "l" : (appLanguage == "hy" ? "լ" : "л")))
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            
                            Spacer()
                            
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
                        
                        // Нижний ряд: Шаги | Кнопка добавления воды | Последняя тренировка
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("ШАГИ:")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white.opacity(0.5))
                                Text(String(format: "%d", health.stepsToday))
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            
                            Spacer()
                            
                            // Меню выбора объема воды
                            Menu {
                                Button("Добавить 200 мл") {
                                    health.addWater(amount: 200.0)
                                    let impact = UIImpactFeedbackGenerator(style: .medium)
                                    impact.impactOccurred()
                                }
                                Button("Добавить 250 мл") {
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
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 14, weight: .bold))
                                    Text("Вода")
                                        .font(.system(size: 13, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(Color(red: 0/255, green: 122/255, blue: 255/255))
                                .cornerRadius(20)
                                .shadow(color: Color(red: 0/255, green: 122/255, blue: 255/255).opacity(0.4), radius: 8)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("ТРЕНИРОВКА:")
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
                    
                    // 2. КОЛЬЦА АКТИВНОСТИ + БЫСТРЫЙ СТАРТ ТРЕНИРОВОК
                    HStack(alignment: .top, spacing: 16) {
                        
                        // Левая колонка - Кольца активности
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Активность")
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
                        
                        // Правая колонка - Тренировки
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Тренировки")
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(Theme.textPrimary)
                            
                            VStack(spacing: 8) {
                                WorkoutRow(title: "Бег", icon: "figure.run", color: Theme.moveColor) {
                                    onStartWorkout?("Run")
                                }
                                WorkoutRow(title: "Силовая", icon: "figure.strengthtraining.functional", color: Theme.exerciseColor) {
                                    onStartWorkout?("Strength")
                                }
                                WorkoutRow(title: "Йога", icon: "figure.mind.and.body", color: Theme.standColor) {
                                    onStartWorkout?("Yoga")
                                }
                                WorkoutRow(title: "Велоспорт", icon: "figure.outdoor.cycle", color: Theme.pulseColor) {
                                    onStartWorkout?("Cycling")
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .premiumCard()
                    }
                    .padding(.horizontal)
                    
                    // 3. ДЕТАЛИ АКТИВНОСТИ
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Детали активности")
                                .font(.headline)
                                .foregroundColor(Theme.textPrimary)
                            Spacer()
                        }
                        
                        HStack(spacing: 16) {
                            ActivityTextValue(
                                title: "Движение",
                                value: String(format: "%.0f / %.0f ккал", health.activeEnergyBurned, health.activeEnergyGoal),
                                color: Theme.moveColor
                            )
                            Spacer()
                            ActivityTextValue(
                                title: "Тренировка",
                                value: String(format: "%.0f / %.0f мин", health.exerciseTime, health.exerciseGoal),
                                color: Theme.exerciseColor
                            )
                            Spacer()
                            ActivityTextValue(
                                title: "Активность",
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
