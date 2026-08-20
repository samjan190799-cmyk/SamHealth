import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var health: HealthKitManager
    @EnvironmentObject var stepManager: BackgroundStepManager
    @State private var isAnalyzing = false
    @State private var coachAdvice: String? = nil
    @State private var isManualRefreshing = false
    @State private var showingHealthSyncHub = false
    
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
    
    private var effectiveSteps: Int {
        max(stepManager.stepsToday, health.stepsToday)
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
        if effectiveSteps >= stepManager.stepGoal {
            return tr("status_activity_high")
        } else if health.lastWorkoutString != "Нет данных" && health.lastWorkoutString != "No data" && health.lastWorkoutString != "Տվյալներ չկան" {
            return tr("status_activity_workout")
        } else if effectiveSteps >= 5000 {
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
    var onOpenNutrition: (() -> Void)? = nil
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    
                    // Заголовок
                    HStack(spacing: 12) {
                        AppLogoView(size: 34)
                        Text("Forma")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    
                    // БАННЕР / СТАТУС APPLE HEALTH
                    if !health.isAuthorized && !UserDefaults.standard.bool(forKey: "HealthKitRequested") {
                        AppleHealthConnectBanner(
                            onConnect: {
                                health.requestAuthorization()
                                health.fetchAllData()
                                stepManager.startLiveUpdates()
                                Task {
                                    await stepManager.refreshStepsFromPedometer()
                                }
                            },
                            onOpenDetails: {
                                showingHealthSyncHub = true
                            },
                            appLanguage: appLanguage
                        )
                        .padding(.horizontal)
                    } else {
                        AppleHealthStatusBar(
                            isSyncing: health.isSyncing,
                            lastSyncTime: health.lastSyncTime,
                            onTap: {
                                showingHealthSyncHub = true
                            },
                            appLanguage: appLanguage
                        )
                        .padding(.horizontal)
                    }
                    
                    // 0. КАРТОЧКА ПЕРСОНАЛЬНОГО ИИ-ТРЕНЕРА
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
                        
                        if isAnalyzing {
                            HStack(spacing: 12) {
                                ProgressView()
                                    .tint(Theme.exerciseColor)
                                Text(tr("ai_coach_analyzing"))
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .padding(.vertical, 8)
                        } else if let advice = coachAdvice {
                            Text(advice)
                                .font(.system(size: 14))
                                .foregroundColor(Theme.textPrimary)
                                .lineSpacing(4)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.primary.opacity(0.04))
                                .cornerRadius(14)
                        } else {
                            Text(tr("ai_coach_placeholder"))
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                                .lineSpacing(3)
                        }
                        
                        if !hasAnyApiKey {
                            Text(tr("workouts_ai_key_warning"))
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, alignment: .center)
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
                    .premiumCard()
                    .padding(.horizontal)
                    
                    // 1. КАРТОЧКА ФОНОВОГО ШАГОМЕРА И АКТИВНОСТИ
                    StepTrackerCardView(
                        steps: effectiveSteps,
                        goal: stepManager.stepGoal,
                        distanceMeters: max(stepManager.distanceMeters, health.distanceMetersToday),
                        floors: stepManager.floorsAscended,
                        activeCalories: health.activeEnergyBurned > 0 ? health.activeEnergyBurned : Double(effectiveSteps) * 0.04,
                        hourlyData: stepManager.hourlySteps,
                        isBackgroundActive: stepManager.isBackgroundTrackingEnabled && stepManager.isPedometerAvailable,
                        isRefreshing: isManualRefreshing,
                        appLanguage: appLanguage,
                        onRefresh: {
                            triggerManualStepRefresh()
                        }
                    )
                    .padding(.horizontal)
                    
                    // 2. КАРТОЧКА ТРЕКЕРА ВОДЫ
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
                        
                        // Быстрые кнопки добавления воды
                        HStack(spacing: 8) {
                            Button(action: {
                                health.addWater(amount: 200.0)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }) {
                                Text("+200 мл")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.15))
                                    .cornerRadius(12)
                            }
                            
                            Button(action: {
                                health.addWater(amount: 250.0)
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("250 мл")
                                }
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color(red: 0/255, green: 122/255, blue: 255/255))
                                .cornerRadius(12)
                                .shadow(color: Color(red: 0/255, green: 122/255, blue: 255/255).opacity(0.4), radius: 6)
                            }
                            
                            Button(action: {
                                health.addWater(amount: 500.0)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }) {
                                Text("+500 мл")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.15))
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding(20)
                    .background(Theme.waterCardGradient)
                    .cornerRadius(28)
                    .shadow(color: Color(red: 15/255, green: 32/255, blue: 67/255).opacity(0.2), radius: 15, x: 0, y: 8)
                    .padding(.horizontal)
                    
                    // 3. РАСШИРЕННЫЙ ВИДЖЕТ ПИТАНИЯ И БЖУ (ИИ-ДНЕВНИК)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            HStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(Color.green.opacity(0.15))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "leaf.fill")
                                        .foregroundColor(.green)
                                        .font(.system(size: 15, weight: .bold))
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Питание за сегодня")
                                        .font(.headline)
                                        .lineLimit(1)
                                        .foregroundColor(Theme.textPrimary)
                                    Text(nutritionStatus)
                                        .font(.caption2)
                                        .foregroundColor(Theme.textSecondary)
                                }
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                onOpenNutrition?()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "camera.viewfinder")
                                    Text("Скан блюда")
                                }
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.green.opacity(0.15))
                                .foregroundColor(.green)
                                .cornerRadius(8)
                            }
                        }
                        
                        // Калории: Потреблено vs Цель
                        HStack(alignment: .lastTextBaseline, spacing: 6) {
                            Text(String(format: "%.0f", health.caloriesConsumedToday))
                                .font(.system(size: 34, weight: .heavy, design: .rounded))
                                .foregroundColor(Theme.textPrimary)
                            
                            Text("/ 2 200 " + tr("kcal"))
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(Theme.textSecondary)
                            
                            Spacer()
                            
                            let remaining = max(0, 2200 - Int(health.caloriesConsumedToday))
                            Text(health.caloriesConsumedToday >= 2200 ? "Норма выполнена 🎉" : "Осталось: \(remaining) ккал")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                        }
                        
                        // Прогресс-бар калорий
                        let calorieProgress = min(1.0, health.caloriesConsumedToday / 2200.0)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.primary.opacity(0.08))
                                    .frame(height: 8)
                                
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.green, Color(red: 0/255, green: 210/255, blue: 180/255)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(8, geo.size.width * CGFloat(calorieProgress)), height: 8)
                                    .animation(.spring(), value: calorieProgress)
                            }
                        }
                        .frame(height: 8)
                        
                        Divider()
                            .opacity(0.3)
                        
                        // БЖУ (Макронутриенты: Белки, Жиры, Углеводы)
                        HStack(spacing: 8) {
                            // Белки
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 4) {
                                    Circle().fill(Color(red: 255/255, green: 90/255, blue: 95/255)).frame(width: 6, height: 6)
                                    Text("Белки")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(Theme.textSecondary)
                                }
                                let proteinG = health.proteinConsumedToday > 0 ? health.proteinConsumedToday : min(140, health.caloriesConsumedToday * 0.07)
                                Text(String(format: "%.0fг / 140г", proteinG))
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Жиры
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 4) {
                                    Circle().fill(Color(red: 255/255, green: 185/255, blue: 45/255)).frame(width: 6, height: 6)
                                    Text("Жиры")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(Theme.textSecondary)
                                }
                                let fatG = health.fatConsumedToday > 0 ? health.fatConsumedToday : min(70, health.caloriesConsumedToday * 0.035)
                                Text(String(format: "%.0fг / 70г", fatG))
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Углеводы
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 4) {
                                    Circle().fill(Color(red: 50/255, green: 175/255, blue: 255/255)).frame(width: 6, height: 6)
                                    Text("Углеводы")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(Theme.textSecondary)
                                }
                                let carbsG = health.carbsConsumedToday > 0 ? health.carbsConsumedToday : min(240, health.caloriesConsumedToday * 0.12)
                                Text(String(format: "%.0fг / 240г", carbsG))
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .premiumCard()
                    .padding(.horizontal)
                    
                    // 4.5. КАРТОЧКА ЭКСПРЕСС-ЗАМЕРА ПУЛЬСА И СНА
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "heart.fill")
                                    .foregroundColor(Theme.pulseColor)
                                    .font(.system(size: 13, weight: .bold))
                                Text("Пульс")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(Theme.textSecondary)
                                Spacer()
                                Text(health.heartRateZone.localizedName(lang: appLanguage))
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(health.heartRateZone.color.opacity(0.15))
                                    .foregroundColor(health.heartRateZone.color)
                                    .cornerRadius(6)
                                    .lineLimit(1)
                            }
                            
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(health.isLiveHeartRateActive ? (health.liveHeartRate > 0 ? "\(health.liveHeartRate)" : "...") : (health.heartRate > 0 ? "\(health.heartRate)" : "70"))
                                    .font(.system(size: 26, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                                    .scaleEffect(health.isLiveHeartRateActive ? 1.06 : 1.0)
                                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: health.isLiveHeartRateActive)
                                Text("уд/мин")
                                    .font(.caption2)
                                    .bold()
                                    .foregroundColor(Theme.textSecondary)
                            }
                            
                            // Кнопка быстрого замера в реальном времени
                            Button(action: {
                                if health.isLiveHeartRateActive {
                                    health.stopLiveHeartRateSession()
                                } else {
                                    health.startLiveHeartRateSession()
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: health.isLiveHeartRateActive ? "stop.fill" : "play.fill")
                                        .font(.system(size: 9, weight: .bold))
                                    Text(health.isLiveHeartRateActive ? "Стоп" : "Замер")
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(health.isLiveHeartRateActive ? Color.gray.opacity(0.7) : Theme.pulseColor)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .premiumCard()
                        
                        // Сон / Восстановление
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "moon.stars.fill")
                                    .foregroundColor(Theme.sleepColor)
                                    .font(.system(size: 13, weight: .bold))
                                Text("Сон")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(Theme.textSecondary)
                                Spacer()
                                Text(health.sleepDuration >= 7.0 ? "Отлично" : "Норма")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Theme.sleepColor.opacity(0.15))
                                    .foregroundColor(Theme.sleepColor)
                                    .cornerRadius(6)
                                    .lineLimit(1)
                            }
                            
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(String(format: "%.1f", health.sleepDuration))
                                    .font(.system(size: 26, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                                Text("ч")
                                    .font(.caption2)
                                    .bold()
                                    .foregroundColor(Theme.textSecondary)
                            }
                            
                            Text(health.deepSleepDuration > 0 ? String(format: "Глубокий: %.1f ч", health.deepSleepDuration) : "Восстановление")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Theme.textSecondary)
                                .lineLimit(1)
                                .padding(.vertical, 4)
                        }
                        .frame(maxWidth: .infinity)
                        .premiumCard()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 90)
                }
            }
            .refreshable {
                health.fetchAllData()
                await stepManager.refreshStepsFromPedometer()
            }
            .sheet(isPresented: $showingHealthSyncHub) {
                HealthKitSyncHubView()
                    .environmentObject(health)
            }
        }
        .onAppear {
            coachAdvice = UserDefaults.standard.string(forKey: "coach_advice_\(todayKey)")
            health.fetchAllData()
            stepManager.startLiveUpdates()
            Task {
                await stepManager.refreshStepsFromPedometer()
            }
        }
    }
    
    private func triggerManualStepRefresh() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        isManualRefreshing = true
        Task {
            health.fetchAllData()
            await stepManager.refreshStepsFromPedometer()
            await MainActor.run {
                isManualRefreshing = false
            }
        }
    }
    
    private func runCoachAnalysis() {
        isAnalyzing = true
        let steps = effectiveSteps
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
                    weight: weight,
                    language: appLanguage
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

// MARK: - Премиальная карточка шагомера и активности

struct StepTrackerCardView: View {
    let steps: Int
    let goal: Int
    let distanceMeters: Double
    let floors: Int
    var activeCalories: Double = 0.0
    let hourlyData: [HourlyStepData]
    let isBackgroundActive: Bool
    let isRefreshing: Bool
    let appLanguage: String
    let onRefresh: () -> Void
    
    private func tr(_ key: String) -> String {
        LocalizationManager.tr(key, lang: appLanguage)
    }
    
    private var progress: Double {
        guard goal > 0 else { return 0.0 }
        return min(1.0, Double(steps) / Double(goal))
    }
    
    private var progressPercent: Int {
        guard goal > 0 else { return 0 }
        return Int((Double(steps) / Double(goal)) * 100)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Верхняя строка: Заголовок + Статус фонового датчика + Кнопка обновления
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Image(systemName: "figure.walk.motion")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(red: 255/255, green: 149/255, blue: 0/255))
                    
                    Text(tr("steps_card_title"))
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                }
                
                Spacer()
                
                // Бейдж статуса фона
                if isBackgroundActive {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 7, height: 7)
                        Text(tr("steps_bg_active"))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.12))
                    .cornerRadius(12)
                }
                
                // Кнопка обновления
                Button(action: onRefresh) {
                    Image(systemName: isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                        .rotationEffect(Angle(degrees: isRefreshing ? 360 : 0))
                        .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                        .padding(6)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(Circle())
                }
                .disabled(isRefreshing)
            }
            
            // Основной счетчик шагов и прогресс
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .lastTextBaseline) {
                    Text(String(format: "%d", steps))
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                    
                    Text(tr("steps_label").lowercased())
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                    
                    Spacer()
                    
                    Text(String(format: "%d%%", progressPercent))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(progress >= 1.0 ? .green : Color(red: 255/255, green: 149/255, blue: 0/255))
                }
                
                // Полоса прогресса
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.08))
                            .frame(height: 10)
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 255/255, green: 149/255, blue: 0/255),
                                        Color(red: 255/255, green: 45/255, blue: 85/255)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(10, geo.size.width * CGFloat(progress)), height: 10)
                            .animation(.spring(), value: progress)
                    }
                }
                .frame(height: 10)
                
                HStack {
                    Text(String(format: tr("steps_daily_goal"), goal))
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                }
            }
            
            Divider()
                .opacity(0.5)
            
            // 3 вспомогательные метрики: Дистанция, Подъемы, Калории шагов
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("distance_label"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                    Text(String(format: tr("steps_distance_km"), distanceMeters / 1000.0))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("floors_label"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                    Text(String(format: tr("steps_floors"), floors))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("water_steps_label"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                    Text(String(format: "%.0f %@", activeCalories > 0 ? activeCalories : Double(steps) * 0.04, tr("kcal")))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Почасовой график активности за сегодня
            if !hourlyData.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(tr("steps_hourly_title"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                    
                    HourlyStepsChartView(hourlyData: hourlyData)
                        .frame(height: 50)
                }
                .padding(.top, 4)
            }
        }
        .premiumCard()
    }
}

// MARK: - Почасовой график активности (24-часовой Bar Chart)

struct HourlyStepsChartView: View {
    let hourlyData: [HourlyStepData]
    
    private var maxStepsInHour: Int {
        let maxVal = hourlyData.map { $0.steps }.max() ?? 0
        return max(maxVal, 100)
    }
    
    private var currentHour: Int {
        Calendar.current.component(.hour, from: Date())
    }
    
    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(hourlyData) { item in
                        let heightPercent = CGFloat(item.steps) / CGFloat(maxStepsInHour)
                        let barHeight = max(3, geo.size.height * heightPercent)
                        let isCurrent = (item.hour == currentHour)
                        let isPastOrCurrent = (item.hour <= currentHour)
                        
                        VStack {
                            Spacer()
                            RoundedRectangle(cornerRadius: 2)
                                .fill(
                                    isCurrent
                                        ? LinearGradient(colors: [Color.yellow, Color.orange], startPoint: .top, endPoint: .bottom)
                                        : (item.steps > 0
                                           ? LinearGradient(colors: [Color.orange.opacity(0.9), Color.red.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                                           : LinearGradient(colors: [Color.primary.opacity(isPastOrCurrent ? 0.08 : 0.03)], startPoint: .top, endPoint: .bottom))
                                )
                                .frame(height: barHeight)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            
            // Подписи ключевых часов: 00, 06, 12, 18, 23
            HStack {
                Text("00:00")
                Spacer()
                Text("06:00")
                Spacer()
                Text("12:00")
                Spacer()
                Text("18:00")
                Spacer()
                Text("23:00")
            }
            .font(.system(size: 8, weight: .regular))
            .foregroundColor(Theme.textSecondary.opacity(0.7))
        }
    }
}

// MARK: - Баннер подключения Apple Health
struct AppleHealthConnectBanner: View {
    let onConnect: () -> Void
    let onOpenDetails: () -> Void
    let appLanguage: String
    
    private func tr(_ key: String) -> String {
        LocalizationManager.tr(key, lang: appLanguage)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 255/255, green: 45/255, blue: 85/255),
                                    Color(red: 255/255, green: 90/255, blue: 120/255)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 42, height: 42)
                        .shadow(color: Color(red: 255/255, green: 45/255, blue: 85/255).opacity(0.3), radius: 6)
                    
                    Image(systemName: "heart.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("health_kit_connect_banner_title"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    
                    Text(tr("health_kit_title"))
                        .font(.caption2)
                        .bold()
                        .foregroundColor(Color(red: 255/255, green: 45/255, blue: 85/255))
                }
                
                Spacer()
                
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    onOpenDetails()
                }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(Theme.textSecondary)
                        .font(.system(size: 18))
                }
            }
            
            Text(tr("health_kit_connect_banner_desc"))
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
                .lineSpacing(2)
            
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                onConnect()
            }) {
                HStack {
                    Image(systemName: "heart.fill")
                    Text(tr("health_kit_connect_btn"))
                        .font(.system(size: 13, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 255/255, green: 45/255, blue: 85/255),
                            Color(red: 255/255, green: 80/255, blue: 110/255)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(color: Color(red: 255/255, green: 45/255, blue: 85/255).opacity(0.3), radius: 6)
            }
        }
        .premiumCard()
    }
}

// MARK: - Компактный статус-бар Apple Health
struct AppleHealthStatusBar: View {
    let isSyncing: Bool
    let lastSyncTime: Date?
    let onTap: () -> Void
    let appLanguage: String
    
    private func tr(_ key: String) -> String {
        LocalizationManager.tr(key, lang: appLanguage)
    }
    
    private var formattedTime: String {
        guard let date = lastSyncTime else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            onTap()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 255/255, green: 45/255, blue: 85/255))
                
                Text(tr("health_kit_connected"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                
                Text("•")
                    .foregroundColor(Theme.textSecondary)
                
                Text(isSyncing ? tr("steps_bg_syncing") : String(format: tr("health_kit_last_synced"), formattedTime))
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textSecondary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.textSecondary.opacity(0.6))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Theme.cardBackground)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

