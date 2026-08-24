import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var health: HealthKitManager
    @EnvironmentObject var stepManager: BackgroundStepManager
    @State private var isAnalyzing = false
    @State private var coachAdvice: String? = nil
    @State private var isManualRefreshing = false
    @State private var showingHealthSyncHub = false
    
    // Состояния для интерактивных экранов деталей
    @State private var showingStepDetail = false
    @State private var showingWaterDetail = false
    @State private var showingNutritionDetail = false
    @State private var showingPulseDetail = false
    @State private var showingSleepDetail = false
    @State private var showingGamificationHub = false
    @State private var showingAICoachChat = false
    
    @ObservedObject private var coachManager = AICoachManager.shared
    
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
                    
                    // БЛОК СТАТУСА / ПОДКЛЮЧЕНИЯ APPLE HEALTH
                    if !health.isAuthorized {
                        AppleHealthConnectBanner {
                            health.requestAuthorization()
                            health.checkHealthDataAndAutoEnable()
                        }
                        .padding(.horizontal)
                    } else {
                        AppleHealthStatusBar(lastSync: health.lastSyncTime, isSyncing: health.isSyncing || health.isHistoricalSyncInProgress) {
                            health.syncAllWithHaptic()
                        }
                        .padding(.horizontal)
                    }
                    
                    // БЛОК ГЕЙМИФИКАЦИИ: РАНГ, УРОВЕНЬ, СТРИК И XP
                    GamificationSummaryCard(onTap: {
                        showingGamificationHub = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    })
                    .padding(.horizontal)
                    
                    // 0. КАРТОЧКА ПЕРСОНАЛЬНОГО ИИ-ТРЕНЕРА
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            AITrainerAvatarView(coachState: isAnalyzing ? .exercising : .idle, size: 36)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tr("ai_coach_title"))
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Theme.textPrimary)
                                Text("Тренер \(coachManager.currentCoach.name) • Online")
                                    .font(.system(size: 10))
                                    .foregroundColor(coachManager.currentCoach.accentColor)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                showingAICoachChat = true
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "bubble.left.and.bubble.right.fill")
                                    Text("Чат")
                                }
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(coachManager.currentCoach.accentColor)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(coachManager.currentCoach.accentColor.opacity(0.12))
                                .cornerRadius(12)
                            }
                        }
                        
                        if let advice = coachAdvice {
                            Text(advice)
                                .font(.system(size: 14))
                                .foregroundColor(Theme.textPrimary)
                                .lineSpacing(4)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.primary.opacity(0.04))
                                .cornerRadius(14)
                                .opacity(isAnalyzing ? 0.5 : 1.0)
                        } else {
                            Text(tr("ai_coach_empty_desc"))
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                                .lineSpacing(3)
                                .opacity(isAnalyzing ? 0.5 : 1.0)
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
                        activeCalories: health.activeEnergyBurned > 0 ? health.activeEnergyBurned : health.calculatedStepCalories,
                        hourlyData: stepManager.hourlySteps,
                        isBackgroundActive: stepManager.isBackgroundTrackingEnabled && stepManager.isPedometerAvailable,
                        isRefreshing: isManualRefreshing,
                        appLanguage: appLanguage,
                        onRefresh: {
                            triggerManualStepRefresh()
                        }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showingStepDetail = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
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
                        
                        // Круговой прогресс и стакан
                        HStack(spacing: 24) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(String(format: "%.1f л", health.waterConsumed / 1000.0))
                                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                                    .foregroundColor(.white)
                                
                                Text(String(format: tr("water_out_of_goal"), health.waterGoal / 1000.0))
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            Spacer()
                            
                            let calculatedNorm = health.currentWeight > 0 ? health.currentWeight * 35.0 : 2500.0
                            let progress = calculatedNorm > 0 ? min(1.0, health.waterConsumed / calculatedNorm) : 0.0
                            
                            ZStack {
                                Circle()
                                    .stroke(Color.white.opacity(0.15), lineWidth: 10)
                                
                                Circle()
                                    .trim(from: 0, to: CGFloat(progress))
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
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showingWaterDetail = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
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
                                    Text(tr("dashboard_nutrition_today"))
                                        .font(.system(size: 15, weight: .bold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                        .foregroundColor(Theme.textPrimary)
                                    Text(nutritionStatus)
                                        .font(.caption2)
                                        .foregroundColor(Theme.textSecondary)
                                }
                            }
                            
                            Spacer(minLength: 6)
                            
                            Button(action: {
                                onOpenNutrition?()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "camera.viewfinder")
                                    Text(tr("nutrition_scan_dish"))
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
                            let remainingStr = LocalizationManager.formatNumber(remaining, lang: appLanguage)
                            Text(health.caloriesConsumedToday >= 2200 ? tr("calories_norm_completed") : String(format: tr("calories_remaining_format"), remainingStr))
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
                                
                                if calorieProgress > 0 {
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
                                    Text(tr("nutrition_protein"))
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(Theme.textSecondary)
                                }
                                Text(String(format: "%.0f г / 140 г", health.proteinConsumedToday))
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Жиры
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 4) {
                                    Circle().fill(Color(red: 255/255, green: 185/255, blue: 45/255)).frame(width: 6, height: 6)
                                    Text(tr("nutrition_fat"))
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(Theme.textSecondary)
                                }
                                Text(String(format: "%.0f г / 70 г", health.fatConsumedToday))
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Углеводы
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 4) {
                                    Circle().fill(Color(red: 50/255, green: 175/255, blue: 255/255)).frame(width: 6, height: 6)
                                    Text(tr("nutrition_carbs"))
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(Theme.textSecondary)
                                }
                                Text(String(format: "%.0f г / 240 г", health.carbsConsumedToday))
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .premiumCard()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showingNutritionDetail = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    .padding(.horizontal)
                    
                    // 4.5. КАРТОЧКА ЭКСПРЕСС-ЗАМЕРА ПУЛЬСА И СНА
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "heart.fill")
                                    .foregroundColor(Theme.pulseColor)
                                    .font(.system(size: 13, weight: .bold))
                                Text(tr("pulse_title"))
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(Theme.textSecondary)
                                Spacer()
                                Text(health.heartRate > 0 ? health.heartRateZone.localizedName(lang: appLanguage) : "--")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(health.heartRateZone.color.opacity(0.15))
                                    .foregroundColor(health.heartRateZone.color)
                                    .cornerRadius(6)
                                    .lineLimit(1)
                            }
                            
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(health.isLiveHeartRateActive ? (health.liveHeartRate > 0 ? "\(health.liveHeartRate)" : "...") : (health.heartRate > 0 ? "\(health.heartRate)" : "--"))
                                    .font(.system(size: 26, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                                    .scaleEffect(health.isLiveHeartRateActive ? 1.06 : 1.0)
                                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: health.isLiveHeartRateActive)
                                Text(tr("pulse_bpm"))
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
                                    Text(health.isLiveHeartRateActive ? tr("pulse_stop") : tr("pulse_measure"))
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
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showingPulseDetail = true
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        
                        // Сон / Восстановление
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "moon.stars.fill")
                                    .foregroundColor(Theme.sleepColor)
                                    .font(.system(size: 13, weight: .bold))
                                Text(tr("sleep_title"))
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(Theme.textSecondary)
                                Spacer()
                                Text(health.sleepDuration > 0 ? (health.sleepDuration >= 7.0 ? tr("sleep_great") : tr("sleep_normal")) : "--")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Theme.sleepColor.opacity(0.15))
                                    .foregroundColor(Theme.sleepColor)
                                    .cornerRadius(6)
                                    .lineLimit(1)
                            }
                            
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(health.sleepDuration > 0 ? String(format: "%.1f", health.sleepDuration) : "--")
                                    .font(.system(size: 26, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                                Text(tr("hrs"))
                                    .font(.caption2)
                                    .bold()
                                    .foregroundColor(Theme.textSecondary)
                            }
                            
                            // Кнопка детального анализа сна (симметрично кнопке замера пульса)
                            Button(action: {
                                showingSleepDetail = true
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "chart.bar.fill")
                                        .font(.system(size: 9, weight: .bold))
                                    Text(tr("sleep_analysis_btn"))
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Theme.sleepColor.opacity(0.18))
                                .foregroundColor(Theme.sleepColor)
                                .cornerRadius(8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .premiumCard()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showingSleepDetail = true
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }
                    .padding(.horizontal)
                    
                    // 4.6. КАРТОЧКА ГОТОВНОСТИ И ВОССТАНОВЛЕНИЯ (HRV & RECOVERY)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "bolt.heart.fill")
                                .foregroundColor(Color(red: 0/255, green: 229/255, blue: 255/255))
                                .font(.system(size: 14, weight: .bold))
                            Text("Готовность и Восстановление (HRV)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Theme.textPrimary)
                            Spacer()
                            if health.recoveryScore > 0 {
                                Text("\(health.recoveryScore)%")
                                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                                    .foregroundColor(health.recoveryScore >= 75 ? Theme.exerciseColor : (health.recoveryScore >= 50 ? .orange : Theme.pulseColor))
                            } else {
                                Text("--")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        
                        HStack(spacing: 8) {
                            HStack(spacing: 5) {
                                Image(systemName: "waveform.path.ecg")
                                    .foregroundColor(Theme.pulseColor)
                                    .font(.caption2)
                                Text(health.hrvSDNN > 0 ? "HRV: \(Int(health.hrvSDNN)) мс" : "HRV: --")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Theme.textPrimary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.primary.opacity(0.04))
                            .cornerRadius(10)
                            
                            HStack(spacing: 5) {
                                Image(systemName: "figure.run")
                                    .foregroundColor(Theme.exerciseColor)
                                    .font(.caption2)
                                Text(health.vo2Max > 0 ? "VO2: \(String(format: "%.1f", health.vo2Max))" : "VO2: --")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Theme.textPrimary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.primary.opacity(0.04))
                            .cornerRadius(10)
                            
                            HStack(spacing: 5) {
                                Image(systemName: "lungs.fill")
                                    .foregroundColor(Color.blue)
                                    .font(.caption2)
                                Text(health.bloodOxygen > 0 ? "SpO2: \(Int(health.bloodOxygen))%" : "SpO2: --")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Theme.textPrimary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.primary.opacity(0.04))
                            .cornerRadius(10)
                        }
                    }
                    .premiumCard()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showingPulseDetail = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 110)
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
            .sheet(isPresented: $showingStepDetail) {
                StepTrackerDetailSheet()
                    .environmentObject(health)
                    .environmentObject(stepManager)
            }
            .sheet(isPresented: $showingWaterDetail) {
                WaterDetailSheet()
                    .environmentObject(health)
            }
            .sheet(isPresented: $showingNutritionDetail) {
                NutritionDetailSheet(onOpenScanner: {
                    onOpenNutrition?()
                })
                .environmentObject(health)
            }
            .sheet(isPresented: $showingPulseDetail) {
                HeartRateDetailSheet()
                    .environmentObject(health)
            }
            .sheet(isPresented: $showingSleepDetail) {
                SleepDetailSheet()
                    .environmentObject(health)
            }
            .sheet(isPresented: $showingGamificationHub) {
                GamificationHubView()
            }
            .sheet(isPresented: $showingAICoachChat) {
                AICoachChatView()
                    .environmentObject(health)
            }
            .alert("Apple Health", isPresented: $health.showAuthorizationAlert) {
                Button("Открыть Настройки") {
                    health.openSystemSettings()
                }
                Button("OK", role: .cancel) { }
            } message: {
                Text(health.authorizationAlertMessage)
            }
            
            // Праздничный модальный экран при открытии нового достижения
            if GamificationManager.shared.showCelebrationModal,
               let achievement = GamificationManager.shared.newlyUnlockedAchievement {
                AchievementCelebrationOverlay(
                    achievement: achievement,
                    onDismiss: {
                        GamificationManager.shared.showCelebrationModal = false
                    }
                )
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .onAppear {
            coachAdvice = UserDefaults.standard.string(forKey: "coach_advice_\(todayKey)")
            health.fetchAllData()
            
            // Пересчет геймификации и стриков
            GamificationManager.shared.evaluateProgress(
                stepsToday: effectiveSteps,
                distanceMetersToday: health.distanceMetersToday,
                workouts: health.workoutHistory,
                waterConsumed: health.waterConsumed,
                waterNorm: health.waterGoal,
                dailyHistory: health.dailyActivityHistory
            )
            
            Task {
                await stepManager.refreshStepsFromPedometer()
                stepManager.startLiveUpdates()
                
                await MainActor.run {
                    GamificationManager.shared.evaluateProgress(
                        stepsToday: effectiveSteps,
                        distanceMetersToday: health.distanceMetersToday,
                        workouts: health.workoutHistory,
                        waterConsumed: health.waterConsumed,
                        waterNorm: health.waterGoal,
                        dailyHistory: health.dailyActivityHistory
                    )
                }
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
                    
                    Text(LocalizationManager.pluralSteps(steps, lang: appLanguage))
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
                    Text(tr("calories_label"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                    Text(String(format: "%.0f %@", activeCalories, tr("kcal")))
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
                        .frame(height: 62)
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
        return max(maxVal, 50)
    }
    
    private var currentHour: Int {
        Calendar.current.component(.hour, from: Date())
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(hourlyData) { item in
                        let heightPercent = CGFloat(item.steps) / CGFloat(maxStepsInHour)
                        let barHeight = max(4, geo.size.height * heightPercent)
                        let isCurrent = (item.hour == currentHour)
                        let isPastOrCurrent = (item.hour <= currentHour)
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                isCurrent
                                    ? LinearGradient(colors: [Color.yellow, Color.orange], startPoint: .top, endPoint: .bottom)
                                    : (item.steps > 0
                                       ? LinearGradient(colors: [Color(red: 255/255, green: 149/255, blue: 0/255), Color(red: 255/255, green: 45/255, blue: 85/255)], startPoint: .top, endPoint: .bottom)
                                       : LinearGradient(colors: [Color.primary.opacity(isPastOrCurrent ? 0.08 : 0.03)], startPoint: .top, endPoint: .bottom))
                            )
                            .frame(height: barHeight)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    }
                }
            }
            .frame(height: 42)
            
            // Подписи ключевых часов: 00:00, 06:00, 12:00, 18:00, 23:00
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
            .font(.system(size: 9, weight: .medium, design: .rounded))
            .foregroundColor(Theme.textSecondary.opacity(0.8))
        }
    }
}

// MARK: - Баннер подключения Apple Health
struct AppleHealthConnectBanner: View {
    let onConnect: () -> Void
    @EnvironmentObject var health: HealthKitManager
    
    var body: some View {
        Button(action: {
            HapticManager.shared.impact(.medium)
            onConnect()
        }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 255/255, green: 45/255, blue: 85/255), Color(red: 255/255, green: 110/255, blue: 140/255)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .shadow(color: Color(red: 255/255, green: 45/255, blue: 85/255).opacity(0.35), radius: 8, x: 0, y: 4)
                    
                    Image(systemName: "heart.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 22))
                        .symbolEffect(.pulse, options: .repeating)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Подключите Apple Health")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                    
                    Text("Авто-синхронизация шагов, калорий, сна и тренировок за 365 дней")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                if health.isSyncing || health.isHistoricalSyncInProgress {
                    ProgressView()
                        .tint(Color(red: 255/255, green: 45/255, blue: 85/255))
                        .frame(width: 70)
                } else {
                    Text("Включить")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color(red: 255/255, green: 45/255, blue: 85/255))
                        .cornerRadius(12)
                        .shadow(color: Color(red: 255/255, green: 45/255, blue: 85/255).opacity(0.3), radius: 4)
                }
            }
            .adaCard(cornerRadius: 20, padding: 14)
            .contentShape(Rectangle())
        }
        .adaButtonStyle(scaleAmount: 0.97, haptic: .medium)
    }
}

// MARK: - Статус-бар Apple Health
struct AppleHealthStatusBar: View {
    let lastSync: Date?
    let isSyncing: Bool
    let onSync: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "heart.fill")
                .foregroundColor(Color(red: 255/255, green: 45/255, blue: 85/255))
                .font(.system(size: 12))
            
            Text("Apple Health:")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textPrimary)
            
            if isSyncing {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.65)
                        .tint(Color(red: 255/255, green: 45/255, blue: 85/255))
                    Text("Синхронизация истории...")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                }
            } else if let lastSync = lastSync {
                Text(lastSync.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.textSecondary)
            } else {
                Text("Подключено")
                    .font(.system(size: 11))
                    .foregroundColor(.green)
            }
            
            Spacer()
            
            Button(action: onSync) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                    .rotationEffect(.degrees(isSyncing ? 360 : 0))
                    .animation(isSyncing ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isSyncing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.cardBackground.opacity(0.8))
        .cornerRadius(12)
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}



