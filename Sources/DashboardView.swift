import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var health: HealthKitManager
    @EnvironmentObject var stepManager: BackgroundStepManager
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

                    // Заголовок (растворяется при прокрутке — это делает FormaFeed) и под ним рекламный баннер.
                    // Они в одной связке без промежутка: пустой баннер (нет рекламы, PRO оплачен) не оставляет зазора.
                    VStack(spacing: 0) {
                        FormaScreenHeader(title: FormaGreeting.title(), subtitle: FormaGreeting.dateLine(language: appLanguage))

                        FormaPromotionalBannerView(placement: .dashboard, spacing: 12)
                            .padding(.horizontal)
                    }
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
                    .formaPerfHidden("hero")

                    // БЫСТРЫЕ ДЕЙСТВИЯ: то, что делают несколько раз в день, сразу под кольцами.
                    // Раньше вода и питание шли отдельными большими карточками и повторяли кольца героя;
                    // подробности по ним открывают строки героя и вкладка «Питание».
                    HomeQuickActions(
                        language: appLanguage,
                        onAddWater: {
                            health.addWater(amount: 250.0)
                        },
                        onScanFood: {
                            onOpenNutrition?()
                        },
                        onStartWorkout: {
                            onStartWorkout?("")
                        }
                    )
                    .padding(.horizontal)
                    .formaAppear(index: 3)
                    .formaPerfHidden("quick")

                    // БЛОК ПРИВЫЧЕК И ДИСЦИПЛИНЫ (КРАТКАЯ СВОДКА)
                    HabitsSummaryDashboardCard(onOpen: onOpenHabits)
                        .padding(.horizontal)
                    
                    .formaPerfHidden("habits")

                    // ТЕЛО: пульс, сон и готовность одной карточкой с тремя кольцами.
                    // Раньше это были три карточки (пульс, сон, HRV) с кнопками ниже удобного размера.
                    HomeBodyCard(
                        heartRate: health.heartRate,
                        zoneColor: health.heartRate > 0 ? health.heartRateZone.color : Theme.pulseColor,
                        isLive: health.isLiveHeartRateActive,
                        sleepHours: health.sleepDuration,
                        recoveryScore: health.recoveryScore,
                        hrv: health.hrvSDNN,
                        vo2Max: health.vo2Max,
                        bloodOxygen: health.bloodOxygen,
                        language: appLanguage,
                        onPulse: {
                            showingPulseDetail = true
                        },
                        onSleep: {
                            showingSleepDetail = true
                        },
                        onToggleLive: {
                            if health.isLiveHeartRateActive {
                                health.stopLiveHeartRateSession()
                            } else {
                                health.startLiveHeartRateSession()
                            }
                        },
                        onSources: {
                            showingMedicalSources = true
                        }
                    )
                    .padding(.horizontal)
                    .formaPerfHidden("body")

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
                    
                    .formaPerfHidden("ai")

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
                    
                    .formaPerfHidden("who")

                    // БЛОК ГЕЙМИФИКАЦИИ: РАНГ, УРОВЕНЬ, СТРИК И XP
                    GamificationSummaryCard(onTap: {
                        showingGamificationHub = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    })
                    .padding(.horizontal)
                    .formaAppear(index: 4)
                    .formaPerfHidden("gamif")

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
                    
                    // Нижний отступ под панель вкладок (раньше был у последней карточки)
                    Color.clear.frame(height: 90)
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
        #if DEBUG
        .onAppear {
            // Сцена `sheet:<имя>` для скриншотов CI: открыть нужный лист поверх Главной
            guard let sheet = FormaScreenshotMode.sheet else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                switch sheet {
                case "steps": showingStepDetail = true
                case "water": showingWaterDetail = true
                case "nutrition": showingNutritionDetail = true
                case "pulse": showingPulseDetail = true
                case "sleep": showingSleepDetail = true
                case "hub": showingGamificationHub = true
                case "deficit": showingAIDeficitAdvisor = true
                case "paywall": showingPaywall = true
                case "profile": showingProfileSetup = true
                case "weekly": NotificationCenter.default.post(name: .formaOpenWeeklySummary, object: nil)
                default: break
                }
            }
        }
        #endif
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
                        .fill(Theme.moveColor)
                        .frame(width: 44, height: 44)
                    
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
                        .tint(Theme.moveColor)
                        .frame(width: 70)
                } else {
                    Text("Включить")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Theme.moveColor)
                        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
                }
            }
            .adaCard(cornerRadius: FormaRadius.card, padding: 14)
            .contentShape(Rectangle())
        }
        .adaButtonStyle(scaleAmount: 0.97, haptic: .medium)
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
                HStack(spacing: 12) {
                    let doneCount = habitsManager.todayCompletedCount
                    let totalCount = habitsManager.todayTotalCount
                    FormaMiniRing(progress: totalCount > 0 ? Double(doneCount) / Double(totalCount) : 0, color: Theme.exerciseColor, size: 50, lineWidth: 6) {
                        if totalCount > 0 {
                            Text("\(doneCount)/\(totalCount)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.textPrimary)
                                .monospacedDigit()
                                .minimumScaleFactor(0.7)
                        } else {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Theme.exerciseColor)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Привычки и дисциплина")
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
                            .foregroundColor(Theme.exerciseColor)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Theme.exerciseColor)
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
                            .foregroundColor(Theme.exerciseColor)
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
                                    FormaMiniRing(progress: habit.isCompletedToday ? 1 : 0, color: habit.color, size: 36, lineWidth: 4) {
                                        Image(systemName: habit.isCompletedToday ? "checkmark" : habit.icon)
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
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(.orange)
                                        } else {
                                            Text(habit.isCompletedToday ? "Выполнено" : "+\(habit.xpReward) XP")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(habit.isCompletedToday ? .green : habit.color)
                                        }
                                    }
                                    
                                    EmptyView()
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
                            .font(.system(size: 11, weight: .medium))
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
