import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var health: HealthKitManager
    @EnvironmentObject var stepManager: BackgroundStepManager
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
    @State private var showingAIDeficitAdvisor = false
    
    @ObservedObject private var coachManager = AICoachManager.shared
    @ObservedObject private var gamification = GamificationManager.shared
    @ObservedObject private var habitsManager = HabitsManager.shared
    @ObservedObject private var subscription = SubscriptionManager.shared
    @State private var showingPaywall = false
    @State private var showingMedicalSources = false
    @State private var showingProfileSetup = false
    @State private var profileMissing = FormaProfile.isMissing
    
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
        return !trimGemini.isEmpty || !trimOpenAI.isEmpty || !trimClaude.isEmpty || !GeminiScanService.masterGeminiKey.isEmpty
    }
    
    private var todayKey: String {
        AppDateHelper.todayKey
    }
    
    private var effectiveSteps: Int {
        if health.isAuthorized && health.stepsToday > 0 {
            return health.stepsToday
        }
        return health.stepsToday > 0 ? health.stepsToday : stepManager.stepsToday
    }
    
    private var effectiveActiveCalories: Double {
        if health.activeEnergyBurned > 0 {
            return health.activeEnergyBurned
        }
        if health.calculatedStepCalories > 0 {
            return health.calculatedStepCalories
        }
        let weight = health.currentWeight > 30 ? health.currentWeight : 74.5
        let factor = (weight / 70.0) * 0.042
        return Double(effectiveSteps) * factor
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
    var onOpenHabits: (() -> Void)? = nil
    
    private var profilePromptCard: some View {
        Button(action: {
            HapticManager.shared.impact(.light)
            showingProfileSetup = true
        }) {
            HStack(spacing: 14) {
                FormaCardIcon(systemName: "person.crop.circle.badge.plus", tint: Theme.exerciseColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Расскажите о себе")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    Text("Возраст, рост и вес — чтобы калории и норма воды считались точно")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .premiumCard()
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        ZStack {
            FormaBackdrop(.home)

            ScrollView {
                FormaFeed(spacing: 20) {

                    // Заголовок (растворяется при прокрутке — это делает FormaFeed)
                    FormaScreenHeader(title: FormaGreeting.title(), subtitle: FormaGreeting.dateLine(language: appLanguage))
                        .formaAppear(index: 0)

                    // БЛОК ПОДКЛЮЧЕНИЯ APPLE HEALTH: без доступа кольца пустые, поэтому предложение подключить идёт первым
                    if !health.isAuthorized {
                        AppleHealthConnectBanner {
                            health.requestAuthorization()
                            health.checkHealthDataAndAutoEnable()
                        }
                        .padding(.horizontal)
                        .formaAppear(index: 1)
                    }

                    // ПРОФИЛЬ НЕ ЗАПОЛНЕН: без него неточны калории и норма воды
                    if profileMissing {
                        profilePromptCard
                            .padding(.horizontal)
                            .formaAppear(index: 1)
                    }

                    // ГЕРОЙ ЭКРАНА: ТРИ КОЛЬЦА ДНЯ (ШАГИ, ПИТАНИЕ, ВОДА)
                    HomeHeroCard(
                        steps: effectiveSteps,
                        stepGoal: stepManager.stepGoal,
                        calories: health.caloriesConsumedToday,
                        calorieGoal: Double(health.dailyCalorieGoal),
                        waterMl: health.waterConsumed,
                        waterGoalMl: health.effectiveWaterGoal > 0 ? health.effectiveWaterGoal : 2500.0,
                        language: appLanguage,
                        onSteps: { showingStepDetail = true },
                        onNutrition: { showingNutritionDetail = true },
                        onWater: { showingWaterDetail = true }
                    )
                    .padding(.horizontal)
                    .formaAppear(index: 2)

                    // СТАТУС СИНХРОНИЗАЦИИ APPLE HEALTH
                    if health.isAuthorized {
                        AppleHealthStatusBar(lastSync: health.lastSyncTime, isSyncing: health.isSyncing || health.isHistoricalSyncInProgress) {
                            health.syncAllWithHaptic()
                        }
                        .padding(.horizontal)
                        .formaAppear(index: 3)
                    }

                    // БЛОК ГЕЙМИФИКАЦИИ: РАНГ, УРОВЕНЬ, СТРИК И XP
                    GamificationSummaryCard(onTap: {
                        showingGamificationHub = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    })
                    .padding(.horizontal)
                    .formaAppear(index: 4)
                    
                    // АНАЛИТИЧЕСКАЯ КАРТОЧКА ИМПУЛЬСА ДИСЦИПЛИНЫ И СТРИКА
                    FormaStreakGrid(
                        currentStreak: gamification.currentStreak,
                        bestStreak: gamification.bestStreak,
                        title: "ВАШ ИМПУЛЬС",
                        subtitle: "дней активности подряд",
                        accentColor: Theme.flameOrange
                    )
                    .padding(.horizontal)
                    
                    // ПРОМО-БАННЕР FORMA PRO
                    FormaPromotionalBannerView(placement: .dashboard)
                        .padding(.horizontal)
                    
                    // БЛОК ПРИВЫЧЕК И ДИСЦИПЛИНЫ (КРАТКАЯ СВОДКА)
                    HabitsSummaryDashboardCard(onOpen: onOpenHabits)
                        .padding(.horizontal)
                    
                    // 0. КАРТОЧКА ПЕРСОНАЛЬНОГО ИИ-ТРЕНЕРА И ДЕФИЦИТА КАЛОРИЙ
                    AIDeficitAdvisorCard(
                        onOpenDetails: {
                            showingAIDeficitAdvisor = true
                        },
                        onOpenChat: {
                            showingAICoachChat = true
                        }
                    )
                    .padding(.horizontal)
                    
                    // БАННЕР FORMA PRO (ЕСЛИ НЕ ОФОРМЛЕНА ПОДПИСКА)
                    if !subscription.isPro {
                        Button(action: {
                            showingPaywall = true
                            HapticManager.shared.selection()
                        }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(red: 168/255, green: 85/255, blue: 247/255), Color(red: 236/255, green: 72/255, blue: 153/255)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 38, height: 38)
                                    Image(systemName: "crown.fill")
                                        .foregroundColor(.white)
                                        .font(.system(size: 16))
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    // Неразрывный пробел перед «₽»: раньше знак рубля уезжал на вторую строку один
                                    Text("FORMA PRO — 7 дней 0\u{00A0}₽")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundColor(Theme.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text("СКИДКА 50%")
                                        .font(.caption2.weight(.heavy))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.18))
                                        .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                                        .clipShape(Capsule())
                                    Text("Безлимитный 3D скан еды, 6 тренеров и снятие всех лимитов")
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption.bold())
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .padding(12)
                            .formaSurface(FormaRadius.control)
                        }
                        .buttonStyle(AppleDesignAwardsButtonStyle(scaleAmount: 0.98))
                        .padding(.horizontal)
                    }
                    
                    // 1. КАРТОЧКА ФОНОВОГО ШАГОМЕРА И АКТИВНОСТИ
                    StepTrackerCardView(
                        steps: effectiveSteps,
                        goal: stepManager.stepGoal,
                        distanceMeters: health.bestDistanceMetersToday(steps: effectiveSteps, pedometerMeters: stepManager.distanceMeters),
                        floors: health.todayFloors > 0 ? health.todayFloors : stepManager.floorsAscended,
                        activeCalories: effectiveActiveCalories,
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
                    
                    // 1.1. КАРТОЧКА НОРМЫ АКТИВНОСТИ ВОЗ (WHO 150-300 МИН/НЕДЕЛЮ)
                    WHOActivityCardView(
                        onOpenDetails: {
                            showingStepDetail = true
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        },
                        onOpenCitations: {
                            showingMedicalSources = true
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
                        }
                        
                        // Круговой прогресс и стакан
                        HStack(spacing: 24) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(String(format: "%.1f л", health.waterConsumed / 1000.0))
                                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                                    .foregroundColor(.white)
                                    .contentTransition(.numericText(value: health.waterConsumed))
                                    .formaAnimation(FormaMotion.smooth, value: health.waterConsumed)
                                
                                Text(String(format: tr("water_out_of_goal"), health.effectiveWaterGoal / 1000.0))
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            Spacer()
                            
                            let goal = health.effectiveWaterGoal > 0 ? health.effectiveWaterGoal : 2500.0
                            let progress = min(1.0, health.waterConsumed / goal)
                            
                            ZStack {
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
                                    .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
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
                                .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
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
                                    .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
                            }
                        }
                    }
                    .padding(20)
                    .background(Theme.waterCardGradient)
                    .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
                    .shadow(color: Color(red: 15/255, green: 32/255, blue: 67/255).opacity(0.2), radius: 15, x: 0, y: 8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showingWaterDetail = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    .padding(.horizontal)
                    
                    // 3. РАСШИРЕННЫЙ ВИДЖЕТ ПИТАНИЯ И БЖУ (ИИ-ДНЕВНИК)
                    VStack(alignment: .leading, spacing: 16) {
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
                                .clipShape(RoundedRectangle(cornerRadius: FormaRadius.chip, style: .continuous))
                            }
                        }
                        
                        // Кольцо калорий и мини-кольца БЖУ — как на вкладке «Питание»
                        NutritionRingsContent(
                            calories: health.caloriesConsumedToday,
                            calorieGoal: health.dailyCalorieGoal,
                            protein: health.proteinConsumedToday,
                            fat: health.fatConsumedToday,
                            carbs: health.carbsConsumedToday,
                            goals: health.dailyMacroGoals,
                            language: appLanguage,
                            ringSize: 132
                        )
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
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    .lineLimit(1)
                            }
                            
                            HStack {
                                Spacer(minLength: 0)
                                FormaMiniRing(progress: (health.isLiveHeartRateActive ? health.liveHeartRate : health.heartRate) / 200.0,
                                              color: health.heartRate > 0 ? health.heartRateZone.color : Theme.pulseColor,
                                              size: 86, lineWidth: 10) {
                                    VStack(spacing: 0) {
                                        Text(health.isLiveHeartRateActive ? (health.liveHeartRate > 0 ? "\(Int(health.liveHeartRate))" : "...") : (health.heartRate > 0 ? "\(Int(health.heartRate))" : "--"))
                                            .font(.system(size: 22, weight: .bold, design: .rounded))
                                            .foregroundColor(Theme.textPrimary)
                                            .monospacedDigit()
                                            .scaleEffect(health.isLiveHeartRateActive ? 1.06 : 1.0)
                                            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: health.isLiveHeartRateActive)
                                        Text(tr("pulse_bpm"))
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                }
                                Spacer(minLength: 0)
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
                                .clipShape(RoundedRectangle(cornerRadius: FormaRadius.chip, style: .continuous))
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
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    .lineLimit(1)
                            }
                            
                            HStack {
                                Spacer(minLength: 0)
                                FormaMiniRing(progress: health.sleepDuration / 8.0, color: Theme.sleepColor, size: 86, lineWidth: 10) {
                                    VStack(spacing: 0) {
                                        Text(health.sleepDuration > 0 ? String(format: "%.1f", health.sleepDuration) : "--")
                                            .font(.system(size: 22, weight: .bold, design: .rounded))
                                            .foregroundColor(Theme.textPrimary)
                                            .monospacedDigit()
                                        Text(tr("hrs"))
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                }
                                Spacer(minLength: 0)
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
                                .clipShape(RoundedRectangle(cornerRadius: FormaRadius.chip, style: .continuous))
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
                            
                            Button(action: {
                                showingMedicalSources = true
                            }) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        
                        HStack(spacing: 8) {
                            HStack(spacing: 4) {
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
                            .clipShape(RoundedRectangle(cornerRadius: FormaRadius.chip, style: .continuous))
                            
                            HStack(spacing: 4) {
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
                            .clipShape(RoundedRectangle(cornerRadius: FormaRadius.chip, style: .continuous))
                            
                            HStack(spacing: 4) {
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
                            .clipShape(RoundedRectangle(cornerRadius: FormaRadius.chip, style: .continuous))
                        }
                        
                        // Сноска с научными источниками (Guideline 1.4.1)
                        HStack(spacing: 4) {
                            Image(systemName: "cross.case")
                                .font(.system(size: 9))
                                .foregroundColor(.blue.opacity(0.8))
                            Text("Данные Apple Health • Стандарты Task Force / AHA / PubMed")
                                .font(.system(size: 9))
                                .foregroundColor(Theme.textSecondary.opacity(0.75))
                            Spacer()
                            Button("Источники") {
                                showingMedicalSources = true
                            }
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(Theme.accent)
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
            .sheet(isPresented: $showingAIDeficitAdvisor) {
                AIDeficitAdvisorSheet()
                    .environmentObject(health)
                    .environmentObject(stepManager)
            }
            .sheet(isPresented: $showingAICoachChat) {
                AICoachChatView()
                    .environmentObject(health)
            }
            .sheet(isPresented: $showingPaywall) {
                FormaPaywallView()
            }
            .sheet(isPresented: $showingMedicalSources) {
                MedicalSourcesAndCitationsView()
            }
            .sheet(isPresented: $showingProfileSetup, onDismiss: {
                withAnimation { profileMissing = FormaProfile.isMissing }
            }) {
                FormaProfileSetupSheet()
            }
            .onReceive(NotificationCenter.default.publisher(for: .formaCloudSyncDidApply)) { _ in
                // Профиль пришёл из iCloud: карточка больше не нужна
                withAnimation { profileMissing = FormaProfile.isMissing }
            }
            .alert("Apple Health", isPresented: $health.showAuthorizationAlert) {
                Button("Открыть Настройки") {
                    health.openSystemSettings()
                }
                Button("OK", role: .cancel) { }
            } message: {
                Text(health.authorizationAlertMessage)
            }

            // Праздничный экран новой награды показывается поверх всего приложения:
            // см. CelebrationWindowPresenter (GamificationViews.swift), его запускает MainTabView.
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            Task {
                // Пауза 300 мс позволяет системной CoreAnimation жидкого таббара завершиться плавно без выпадения кадров
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                
                health.checkAndHandleDayRollover()
                health.fetchAllData()
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
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                
                Spacer()
                
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
            
            // Кольцо шагов и крупное число рядом
            HStack(spacing: FormaSpacing.xl) {
                FormaMiniRing(progress: goal > 0 ? Double(steps) / Double(goal) : 0, color: Theme.moveColor, size: 124, lineWidth: 15) {
                    FormaPercentCenter(percent: progressPercent, size: 17)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizationManager.formatNumber(steps, lang: appLanguage))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .contentTransition(.numericText(value: Double(steps)))
                        .formaAnimation(FormaMotion.smooth, value: steps)

                    Text(LocalizationManager.pluralSteps(steps, lang: appLanguage))
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)

                    Text(tr("steps_daily_goal").replacingOccurrences(of: "%d", with: LocalizationManager.formatNumber(goal, lang: appLanguage)))
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                        .padding(.top, 2)

                    // Статус фонового датчика: раньше стоял в заголовке и переносился на две строки
                    if isBackgroundActive {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text(tr("steps_bg_active"))
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(.green)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Три вспомогательных показателя, у каждого своё кольцо — доля от ориентира на день
            // (дистанция ≈ 0,75 м на шаг цели, 10 этажей, 400 ккал активной энергии)
            HStack(spacing: 8) {
                stepRingStat(
                    title: tr("distance_label"),
                    value: String(format: tr("steps_distance_km"), distanceMeters / 1000.0),
                    symbol: "location.fill",
                    color: Theme.standColor,
                    progress: goal > 0 ? distanceMeters / (Double(goal) * 0.75) : 0
                )
                stepRingStat(
                    title: tr("floors_label"),
                    value: String(format: tr("steps_floors"), floors),
                    symbol: "stairs",
                    color: Theme.aiViolet,
                    progress: Double(floors) / 10.0
                )
                stepRingStat(
                    title: tr("calories_label"),
                    value: String(format: "%.0f %@", activeCalories, tr("kcal")),
                    symbol: "flame.fill",
                    color: Theme.flameOrange,
                    progress: activeCalories / 400.0
                )
            }

            // Почасовой график активности за сегодня
            if !hourlyData.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(tr("steps_hourly_title"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                    
                    HourlyStepsChartView(hourlyData: hourlyData)
                        .frame(height: 62)
                }
                .padding(.top, 4)
            }
        }
        .formaHeroCard(tint: Theme.moveColor, padding: FormaSpacing.xl - 4)
    }

    private func stepRingStat(title: String, value: String, symbol: String, color: Color, progress: Double) -> some View {
        VStack(spacing: 6) {
            FormaIconRing(progress: progress, color: color, symbol: symbol, size: 46)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(FormaSurfaceBackground(cornerRadius: FormaRadius.control, elevated: false))
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
        VStack(alignment: .leading, spacing: 8) {
            if #available(iOS 16.0, *) {
                Chart {
                    ForEach(hourlyData) { item in
                        let isCurrent = (item.hour == currentHour)
                        let isPastOrCurrent = (item.hour <= currentHour)
                        
                        BarMark(
                            x: .value("Час", item.hour),
                            y: .value("Шаги", item.steps)
                        )
                        .foregroundStyle(
                            isCurrent
                                ? LinearGradient(colors: [Color.yellow, Color.orange], startPoint: .top, endPoint: .bottom)
                                : (item.steps > 0
                                   ? LinearGradient(colors: [Color(red: 255/255, green: 149/255, blue: 0/255), Color(red: 255/255, green: 45/255, blue: 85/255)], startPoint: .top, endPoint: .bottom)
                                   : LinearGradient(colors: [Color.primary.opacity(isPastOrCurrent ? 0.08 : 0.03)], startPoint: .top, endPoint: .bottom))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                    }
                }
                .chartXScale(domain: -0.5...23.5)
                .chartYScale(domain: 0...(Double(maxStepsInHour) * 1.1))
                .chartXAxis {
                    AxisMarks(values: [0, 6, 12, 18]) { value in
                        if let hour = value.as(Int.self) {
                            AxisValueLabel {
                                Text(String(format: "%02d:00", hour))
                                    .font(.system(size: 9, weight: .medium, design: .rounded))
                                    .foregroundColor(Theme.textSecondary.opacity(0.8))
                            }
                        }
                    }
                }
                .chartYAxis(.hidden)
                .frame(height: 60)
            } else {
                Text("Графики доступны на iOS 16 и выше")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                    .frame(height: 42)
            }
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
            HStack(spacing: 16) {
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
                
                VStack(alignment: .leading, spacing: 4) {
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
                        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
                        .shadow(color: Color(red: 255/255, green: 45/255, blue: 85/255).opacity(0.3), radius: 4)
                }
            }
            .adaCard(cornerRadius: FormaRadius.card, padding: 14)
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
                Text(AppDateHelper.timeFormatter.string(from: lastSync))
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
        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
    }
    
    private func timeString(from date: Date) -> String {
        AppDateHelper.time(from: date)
    }
}

// MARK: - HabitsSummaryDashboardCard (Интерактивная карточка привычек на главном экране)
public struct HabitsSummaryDashboardCard: View {
    @ObservedObject var habitsManager = HabitsManager.shared
    var onOpen: (() -> Void)? = nil
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Шапка с переходом
            Button(action: {
                HapticManager.shared.impact(.light)
                onOpen?()
            }) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 32, height: 32)
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.cyan)
                            .font(.system(size: 15, weight: .bold))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Привычки & Дисциплина")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Theme.textPrimary)
                        
                        let completed = habitsManager.todayCompletedCount
                        let total = habitsManager.todayTotalCount
                        Text(habitsManager.habits.isEmpty ? "Нет активных привычек" : "\(completed) из \(total) выполнено сегодня")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text(habitsManager.habits.isEmpty ? "Настроить" : "Все")
                            .font(.caption.bold())
                            .foregroundColor(.cyan)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.cyan)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if habitsManager.habits.isEmpty {
                Button(action: {
                    HapticManager.shared.impact(.light)
                    onOpen?()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.cyan)
                        Text("Создать свою первую привычку")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Theme.textSecondary)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                // Горизонтальная лента быстрых привычек
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(habitsManager.habits.prefix(5)) { habit in
                            Button(action: {
                                habitsManager.toggleHabitCompletion(id: habit.id)
                            }) {
                                HStack(spacing: 8) {
                                    ZStack {
                                        Circle()
                                            .fill(habit.color.opacity(0.18))
                                            .frame(width: 28, height: 28)
                                        Image(systemName: habit.icon)
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(habit.color)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(habit.title)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(Theme.textPrimary)
                                            .lineLimit(1)
                                        
                                        if habit.type == .quit {
                                            Text("🔥 \(habit.cleanStreakDays) дн. чист")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(.orange)
                                        } else {
                                            Text(habit.isCompletedToday ? "Выполнено" : "+\(habit.xpReward) XP")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(habit.isCompletedToday ? .green : habit.color)
                                        }
                                    }
                                    
                                    ZStack {
                                        Circle()
                                            .fill(habit.isCompletedToday ? habit.color : Color.primary.opacity(0.08))
                                            .frame(width: 20, height: 20)
                                        if habit.isCompletedToday {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .padding(.leading, 2)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .formaSurface(FormaRadius.control)
                                .overlay(
                                    RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                                        .stroke(habit.isCompletedToday ? habit.color.opacity(0.3) : Color.primary.opacity(0.08), lineWidth: 1)
                                )
                            }
                            .buttonStyle(AppleDesignAwardsButtonStyle(scaleAmount: 0.96))
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .premiumCard()
    }
}

// MARK: - Карточка нормы физической активности ВОЗ (WHO Physical Activity Guidelines 2020)
struct WHOActivityCardView: View {
    @EnvironmentObject var health: HealthKitManager
    var onOpenDetails: () -> Void
    var onOpenCitations: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Theme.exerciseColor.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: "figure.run.circle.fill")
                            .foregroundColor(Theme.exerciseColor)
                            .font(.system(size: 16, weight: .bold))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Норма активности ВОЗ")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Theme.textPrimary)
                        Text("150–300 мин аэробной нагрузки в нед.")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                
                Spacer()
                
                Button(action: onOpenCitations) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textSecondary)
                }
            }
            
            // Двойное кольцо: внешнее — минуты аэробной нагрузки за неделю, внутреннее — силовые дни
            let isComplete = health.weeklyExerciseMinutes >= health.whoWeeklyModerateTargetMinutes
            HStack(spacing: FormaSpacing.xl) {
                FormaRingStack(
                    rings: [
                        FormaRingSpec(id: "who-minutes", progress: health.whoWeeklyProgress, color: Theme.exerciseColor, symbol: ""),
                        FormaRingSpec(id: "who-strength", progress: Double(health.weeklyStrengthDaysCount) / 2.0, color: Theme.flameOrange, symbol: "")
                    ],
                    isRevealed: true,
                    lineWidth: 13,
                    gap: 3
                )
                .frame(width: 112, height: 112)

                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Circle().fill(Theme.exerciseColor).frame(width: 8, height: 8)
                            Text("Аэробная нагрузка")
                                .font(FormaFont.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(health.weeklyExerciseMinutes)")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.textPrimary)
                                .monospacedDigit()
                            Text("/ 150 мин")
                                .font(FormaFont.unit)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Circle().fill(Theme.flameOrange).frame(width: 8, height: 8)
                            Text("Силовые дни")
                                .font(FormaFont.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(health.weeklyStrengthDaysCount)")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.textPrimary)
                                .monospacedDigit()
                            Text("/ 2 дня")
                                .font(FormaFont.unit)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Text(isComplete ? "Норма ВОЗ выполнена" : "\(Int(health.whoWeeklyProgress * 100))% недельной нормы")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(isComplete ? .green : Theme.exerciseColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((isComplete ? Color.green : Theme.exerciseColor).opacity(0.15))
                    .clipShape(Capsule())

                Spacer()

                Button(action: onOpenDetails) {
                    HStack(spacing: 4) {
                        Text("Подробнее")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Theme.exerciseColor)
                }
            }
        }
        .premiumCard()
    }
}
