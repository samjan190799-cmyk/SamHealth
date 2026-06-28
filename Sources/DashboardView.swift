import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var health: HealthKitManager
    @State private var isAnalyzing = false
    @State private var coachAdvice: String? = nil
    
    @AppStorage("app_language") private var appLanguage = "ru"
    @AppStorage("api_key_gemini") private var apiKeyGemini = ""
    @AppStorage("api_key_openai") private var apiKeyOpenAI = ""
    @AppStorage("api_key_claude") private var apiKeyClaude = ""
    
    private func tr(_ key: String) -> String {
        LocalizationManager.tr(key, lang: appLanguage)
    }
    
    private var hasAnyApiKey: Bool {
        let trimGemini = apiKeyGemini.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimOpenAI = apiKeyOpenAI.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimClaude = apiKeyClaude.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimGemini.isEmpty || !trimOpenAI.isEmpty || !trimClaude.isEmpty
    }
    
    private var todayKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
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
                    
                    // 0. КАРТОЧКА ПЕРСОНАЛЬНОГО ИИ-ТРЕНЕРА (ВМЕСТО СВОДКИ)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .foregroundColor(.yellow)
                                .font(.headline)
                            Text(tr("ai_coach_title"))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Theme.textPrimary)
                            Spacer()
                        }
                        
                        if !hasAnyApiKey {
                            Text(tr("workouts_ai_key_warning"))
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 8)
                        } else {
                            if let advice = coachAdvice {
                                Text(advice)
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.textPrimary.opacity(0.95))
                                    .lineSpacing(4)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.primary.opacity(0.04))
                                    .cornerRadius(14)
                            } else {
                                Text(tr("ai_coach_empty_desc"))
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                                    .lineSpacing(3)
                                    .padding(.vertical, 4)
                            }
                            
                            Button(action: {
                                runCoachAnalysis()
                            }) {
                                HStack {
                                    if isAnalyzing {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .padding(.trailing, 8)
                                    }
                                    Text(isAnalyzing ? tr("ai_coach_analyzing") : tr("ai_coach_analyze_btn"))
                                        .bold()
                                }
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .background(isAnalyzing ? Theme.exerciseColor.opacity(0.6) : Theme.exerciseColor)
                                .cornerRadius(14)
                                .shadow(color: Theme.exerciseColor.opacity(0.2), radius: 6)
                            }
                            .disabled(isAnalyzing)
                        }
                    }
                    .premiumCard()
                    .padding(.horizontal)
                    
                    // 1. КАРТОЧКА ТРЕКЕРА ВОДЫ (ВСТРОЕН СТАТУС ГИДРАТАЦИИ)
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tr("water_title"))
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundColor(.white)
                                Text(waterStatus)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.85))
                            }
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
                        
                        // Нижний ряд
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
                    
                    // 2. КОЛЬЦА АКТИВНОСТИ + БЫСТРЫЙ СТАРТ ТРЕНИРОВОК (ВСТРОЕН СТАТУС АКТИВНОСТИ)
                    HStack(alignment: .top, spacing: 16) {
                        
                        // Левая колонка - Кольца активности
                        VStack(alignment: .leading, spacing: 8) {
                            Text(tr("activity_title"))
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(Theme.textPrimary)
                            
                            Text(activityStatus)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(height: 28, alignment: .topLeading)
                            
                            ActivityRingsGroup(
                                moveProgress: health.activeEnergyGoal > 0 ? health.activeEnergyBurned / health.activeEnergyGoal : 0,
                                exerciseProgress: health.exerciseGoal > 0 ? health.exerciseTime / health.exerciseGoal : 0,
                                standProgress: health.standGoal > 0 ? health.standHours / health.standGoal : 0
                            )
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 4)
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
                    
                    // 2.5. КАРТОЧКА ПИТАНИЯ (НОВАЯ, ВСТРОЕН СТАТУС ПИТАНИЯ)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tr("dashboard_nutrition_today"))
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundColor(Theme.textPrimary)
                                Text(nutritionStatus)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Theme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "leaf.fill")
                                .font(.title3)
                                .foregroundColor(.green)
                        }
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Потреблено сегодня")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                                Text(String(format: "%.0f %@", health.caloriesConsumedToday, tr("kcal")))
                                    .font(.system(size: 26, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                            }
                            Spacer()
                        }
                    }
                    .premiumCard()
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
        .onAppear {
            coachAdvice = UserDefaults.standard.string(forKey: "coach_advice_\(todayKey)")
        }
    }
    
    private func runCoachAnalysis() {
        isAnalyzing = true
        let steps = health.stepsToday
        let water = health.waterConsumed
        let waterGoal = health.waterGoal
        let caloriesBurned = health.activeEnergyBurned
        let energyGoal = health.activeEnergyGoal
        let exercise = health.exerciseTime
        let exerciseGoal = health.exerciseGoal
        let foodCalories = health.caloriesConsumedToday
        let weight = health.currentWeight
        
        Task {
            do {
                let advice = try await GeminiScanService.shared.analyzeOverallHealth(
                    steps: steps,
                    waterConsumed: water,
                    waterGoal: waterGoal,
                    caloriesBurned: caloriesBurned,
                    activeEnergyGoal: energyGoal,
                    exerciseTime: exercise,
                    exerciseGoal: exerciseGoal,
                    caloriesConsumed: foodCalories,
                    weight: weight
                )
                await MainActor.run {
                    self.coachAdvice = advice
                    UserDefaults.standard.set(advice, forKey: "coach_advice_\(todayKey)")
                    self.isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    self.coachAdvice = "Не удалось связаться с ИИ-Тренером: \(error.localizedDescription)"
                    self.isAnalyzing = false
                }
            }
        }
    }
}
