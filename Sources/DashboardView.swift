import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var health: HealthKitManager
    @State private var showingScanner = false
    @AppStorage("app_language") private var appLanguage = "ru"
    
    private func tr(_ key: String) -> String {
        LocalizationManager.tr(key, lang: appLanguage)
    }
    
    private var waterStatus: String {
        let calculatedNorm = health.currentWeight > 0 ? health.currentWeight * 35.0 : 2500.0
        let progress = calculatedNorm > 0 ? health.waterConsumed / calculatedNorm : 0.0
        if progress >= 0.70 {
            return tr("status_water_good")
        } else if progress < 0.40 {
            return tr("status_water_low")
        } else {
            return tr("status_water_normal")
        }
    }
    
    private var activityStatus: String {
        if health.stepsToday >= 10000 {
            return tr("status_activity_high")
        } else if health.lastWorkoutString != "Нет данных" && health.lastWorkoutString != "No data" && health.lastWorkoutString != "Տվյալներ չկան" {
            return tr("status_activity_workout")
        } else if health.stepsToday >= 5000 {
            return tr("status_activity_normal")
        } else {
            return tr("status_activity_low")
        }
    }
    
    private var nutritionStatus: String {
        if health.caloriesConsumedToday > 0 {
            return tr("status_nutrition_logged")
        } else {
            return tr("status_nutrition_empty")
        }
    }
    
    var onStartWorkout: ((String) -> Void)? = nil
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    
                    // Заголовок
                    HStack(spacing: 12) {
                        AppLogoView(size: 34)
                        Text("Nano Health")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    
                    // СВОДКА ЗДОРОВЬЯ
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 8) {
                            Image(systemName: "heart.text.square.fill")
                                .foregroundColor(Theme.pulseColor)
                                .font(.subheadline)
                            Text(tr("dashboard_summary_title"))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.1))
                        
                        VStack(alignment: .leading, spacing: 12) {
                            // Гидратация
                            HStack(spacing: 12) {
                                Image(systemName: "drop.fill")
                                    .foregroundColor(.blue)
                                    .frame(width: 20)
                                Text(waterStatus)
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textPrimary)
                            }
                            
                            // Активность
                            HStack(spacing: 12) {
                                Image(systemName: "figure.run")
                                    .foregroundColor(.green)
                                    .frame(width: 20)
                                Text(activityStatus)
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textPrimary)
                            }
                            
                            // Питание
                            HStack(spacing: 12) {
                                Image(systemName: "leaf.fill")
                                    .foregroundColor(.orange)
                                    .frame(width: 20)
                                Text(nutritionStatus)
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textPrimary)
                            }
                        }
                    }
                    .premiumCard()
                    .padding(.horizontal)
                    
                    // 1. КАРТОЧКА ТРЕКЕРА ВОДЫ
                    VStack(spacing: 16) {
                        HStack {
                            Text(tr("water_title"))
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(.white)
                            Spacer()
                            Text(tr("water_daily_goal"))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        let progress = health.waterGoal > 0 ? health.waterConsumed / health.waterGoal : 0.0
                        
                        HStack(spacing: 24) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tr("water_consumed"))
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.white.opacity(0.6))
                                Text(String(format: "%.1f %@", health.waterConsumed / 1000.0, tr("water_l")))
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Text(String(format: "%@: %.1f %@", tr("water_goal_short"), health.waterGoal / 1000.0, tr("water_l")))
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
                                Text(tr("water_steps_label"))
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white.opacity(0.5))
                                Text(String(format: "%d", health.stepsToday))
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            
                            Spacer()
                            
                            // Меню выбора объема воды
                            Menu {
                                Button(tr("water_menu_add_200")) {
                                    health.addWater(amount: 200.0)
                                    let impact = UIImpactFeedbackGenerator(style: .medium)
                                    impact.impactOccurred()
                                }
                                Button(tr("water_menu_add_250")) {
                                    health.addWater(amount: 250.0)
                                    let impact = UIImpactFeedbackGenerator(style: .medium)
                                    impact.impactOccurred()
                                }
                                Button(tr("water_menu_add_500")) {
                                    health.addWater(amount: 500.0)
                                    let impact = UIImpactFeedbackGenerator(style: .medium)
                                    impact.impactOccurred()
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 14, weight: .bold))
                                    Text(tr("water_label"))
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
                                Text(tr("water_workout_label"))
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
                            Text(tr("activity_title"))
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
                            Text(tr("workouts_title"))
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(Theme.textPrimary)
                            
                            VStack(spacing: 8) {
                                WorkoutRow(title: tr("workout_type_run"), icon: "figure.run", color: Theme.moveColor) {
                                    onStartWorkout?("Run")
                                }
                                WorkoutRow(title: tr("workout_type_strength"), icon: "figure.strengthtraining.functional", color: Theme.exerciseColor) {
                                    onStartWorkout?("Strength")
                                }
                                WorkoutRow(title: tr("workout_type_yoga"), icon: "figure.mind.and.body", color: Theme.standColor) {
                                    onStartWorkout?("Yoga")
                                }
                                WorkoutRow(title: tr("workout_type_cycling"), icon: "figure.outdoor.cycle", color: Theme.pulseColor) {
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
                            Text(tr("activity_details"))
                                .font(.headline)
                                .foregroundColor(Theme.textPrimary)
                            Spacer()
                        }
                        
                        HStack(spacing: 16) {
                            ActivityTextValue(
                                title: tr("activity_move"),
                                value: String(format: "%.0f / %.0f %@", health.activeEnergyBurned, health.activeEnergyGoal, tr("kcal")),
                                color: Theme.moveColor
                            )
                            Spacer()
                            ActivityTextValue(
                                title: tr("activity_exercise"),
                                value: String(format: "%.0f / %.0f %@", health.exerciseTime, health.exerciseGoal, tr("min")),
                                color: Theme.exerciseColor
                            )
                            Spacer()
                            ActivityTextValue(
                                title: tr("activity_stand"),
                                value: String(format: "%.0f / %.0f %@", health.standHours, health.standGoal, tr("hrs")),
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
