import SwiftUI
import UniformTypeIdentifiers
import MapKit
import AVKit
import Combine
import WatchConnectivity


struct WorkoutsView: View {
    @EnvironmentObject var health: HealthKitManager
    @EnvironmentObject var stepManager: BackgroundStepManager
    @StateObject private var tracker = WorkoutTracker()
    @State private var selectedWorkoutType: WorkoutType = .running
    @State private var showingSummary = false
    @State private var lastSummaryCalories = 0.0
    @State private var lastSummaryDistance = 0.0
    
    @State private var showingVideoRecorder = false
    @State private var recordedVideoURL: URL? = nil
    @State private var showVideoSavedAlert = false
    
    @State private var isAnalyzingWorkouts = false
    @State private var workoutsAnalysisResult: String? = nil
    @State private var workoutsAnalysisError: String? = nil
    @AppStorage("app_language") private var appLanguage = "ru"
    @AppStorage("api_key_gemini") private var apiKeyGemini = ""
    @AppStorage("api_key_openai") private var apiKeyOpenAI = ""
    @AppStorage("api_key_claude") private var apiKeyClaude = ""
    
    // Профиль пользователя из AppStorage
    @AppStorage("user_age") private var userAge = 25
    @AppStorage("user_height") private var userHeight = 175
    @AppStorage("user_weight") private var userWeight = 75.0
    @AppStorage("user_target_weight") private var userTargetWeight = 70.0
    @AppStorage("user_gender") private var userGender = "Мужской"
    @AppStorage("user_activity_level") private var userActivityLevel = "Средняя"
    
    // Состояния для ИИ-Планировщика
    @State private var isGeneratingWorkoutPlan = false
    @State private var generatedWorkoutPlan: String? = nil
    @State private var workoutPlanError: String? = nil
    
    // Личные тренировки
    @StateObject private var customStore = CustomWorkoutStore()
    @State private var selectedTab: WorkoutTab = .presets
    @State private var showingCreateWorkout = false
    @State private var selectedCalendarDate: Date = Date()
    
    // Активная личная тренировка
    @State private var activeCustomWorkout: CustomWorkout? = nil
    @State private var currentExerciseIndex = 0
    @State private var currentSetIndex = 1
    
    // Таймер отдыха
    @State private var restTimer: AnyCancellable? = nil
    @State private var isResting = false
    @State private var restSecondsRemaining = 30
    
    enum WorkoutTab {
        case presets
        case custom
    }
    
    private func tr(_ key: String) -> String {
        LocalizationManager.tr(key, lang: appLanguage)
    }
    
    private var hasAnyApiKey: Bool {
        !apiKeyGemini.isEmpty || !apiKeyOpenAI.isEmpty || !apiKeyClaude.isEmpty
    }
    
    enum WorkoutType: String, CaseIterable, Identifiable {
        case running = "Бег"
        case walking = "Ходьба"
        case cycling = "Велоспорт"
        case strength = "Силовая"
        case yoga = "Йога"
        case swimming = "Плавание"
        case jumpRope = "Скакалка"
        case dumbbells = "Гантели"
        case pushups = "Отжимания"
        case squats = "Приседания"
        case plank = "Планка"
        
        var id: String { self.rawValue }
        
        func localizedTitle(lang: String) -> String {
            switch self {
            case .running: return LocalizationManager.tr("workout_type_run", lang: lang)
            case .walking: return LocalizationManager.tr("workout_type_walk", lang: lang)
            case .cycling: return LocalizationManager.tr("workout_type_cycling", lang: lang)
            case .strength: return LocalizationManager.tr("workout_type_strength", lang: lang)
            case .yoga: return LocalizationManager.tr("workout_type_yoga", lang: lang)
            case .swimming: return LocalizationManager.tr("workout_type_swimming", lang: lang)
            case .jumpRope: return LocalizationManager.tr("workout_type_jump_rope", lang: lang)
            case .dumbbells: return LocalizationManager.tr("workout_type_dumbbells", lang: lang)
            case .pushups: return LocalizationManager.tr("workout_type_pushups", lang: lang)
            case .squats: return LocalizationManager.tr("workout_type_squats", lang: lang)
            case .plank: return LocalizationManager.tr("workout_type_plank", lang: lang)
            }
        }
        var icon: String {
            switch self {
            case .running: return "figure.run"
            case .walking: return "figure.walk"
            case .cycling: return "figure.outdoor.cycle"
            case .strength: return "figure.strengthtraining.functional"
            case .yoga: return "figure.mind.and.body"
            case .swimming: return "figure.pool.swim"
            case .jumpRope: return "figure.jumprope"
            case .dumbbells: return "dumbbell.fill"
            case .pushups: return "figure.strengthtraining.traditional"
            case .squats: return "figure.cross.training"
            case .plank: return "figure.core.training"
            }
        }
        
        var met: Double {
            switch self {
            case .running: return 8.0
            case .walking: return 3.5
            case .cycling: return 6.0
            case .strength: return 5.0
            case .yoga: return 2.5
            case .swimming: return 7.0
            case .jumpRope: return 10.0
            case .dumbbells: return 6.0
            case .pushups: return 8.0
            case .squats: return 5.0
            case .plank: return 4.0
            }
        }
        
        var typeId: String {
            switch self {
            case .running: return "Run"
            case .walking: return "Walk"
            case .cycling: return "Cycling"
            case .strength: return "Strength"
            case .yoga: return "Yoga"
            case .swimming: return "Swimming"
            case .jumpRope: return "JumpRope"
            case .dumbbells: return "Dumbbells"
            case .pushups: return "Pushups"
            case .squats: return "Squats"
            case .plank: return "Plank"
            }
        }
        
        var isStationaryFriendly: Bool {
            switch self {
            case .strength, .yoga, .dumbbells, .pushups, .squats, .plank:
                return true
            default:
                return false
            }
        }
        
        var videoURL: String {
            switch self {
            case .running:
                return "https://assets.mixkit.co/videos/preview/mixkit-man-running-on-a-treadmill-40097-large.mp4"
            case .walking:
                return "https://assets.mixkit.co/videos/preview/mixkit-couple-walking-in-a-park-41558-large.mp4"
            case .cycling:
                return "https://assets.mixkit.co/videos/preview/mixkit-cyclist-riding-on-a-country-road-41562-large.mp4"
            case .strength:
                return "https://assets.mixkit.co/videos/preview/mixkit-woman-doing-dumbbell-squats-41555-large.mp4"
            case .yoga:
                return "https://assets.mixkit.co/videos/preview/mixkit-woman-practicing-yoga-in-nature-41551-large.mp4"
            case .swimming:
                return "https://assets.mixkit.co/videos/preview/mixkit-swimmer-training-in-a-pool-41566-large.mp4"
            case .jumpRope:
                return "https://assets.mixkit.co/videos/preview/mixkit-young-woman-skipping-rope-in-a-gym-41559-large.mp4"
            case .dumbbells:
                return "https://assets.mixkit.co/videos/preview/mixkit-man-training-with-dumbbells-in-the-gym-41561-large.mp4"
            case .pushups:
                return "https://assets.mixkit.co/videos/preview/mixkit-man-doing-push-ups-in-gym-41560-large.mp4"
            case .squats:
                return "https://assets.mixkit.co/videos/preview/mixkit-woman-doing-dumbbell-squats-41555-large.mp4"
            case .plank:
                return "https://assets.mixkit.co/videos/preview/mixkit-woman-practicing-yoga-in-nature-41551-large.mp4"
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let workout = activeCustomWorkout {
                    // ЭКРАН ПРОХОЖДЕНИЯ ЛИЧНОЙ ТРЕНИРОВКИ
                    customWorkoutActiveView(workout: workout)
                } else if tracker.isTracking {
                    // Экран активной стандартной тренировки
                    standardWorkoutActiveView
                } else {
                    // Экран настроек перед началом
                    workoutsSetupView
                }
            }
            .padding(.bottom, 110)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(isPresented: $showingCreateWorkout) {
            CustomWorkoutCreatorView(store: customStore)
        }
        .sheet(isPresented: $showingVideoRecorder) {
            VideoRecorder(videoURL: $recordedVideoURL)
        }
        .onChange(of: recordedVideoURL) { _, newURL in
            if newURL != nil {
                showVideoSavedAlert = true
            }
        }
        .alert(tr("workouts_video_saved_title"), isPresented: $showVideoSavedAlert) {
            Button(tr("ok"), role: .cancel) {
                recordedVideoURL = nil
            }
        } message: {
            Text(tr("workouts_video_saved_desc"))
        }
        .alert(tr("workouts_finished_title"), isPresented: $showingSummary) {
            Button(tr("ok"), role: .cancel) { }
        } message: {
            Text(String(format: tr("workouts_finished_desc"), lastSummaryDistance / 1000.0, Int(lastSummaryCalories)))
        }
        .onAppear {
            generatedWorkoutPlan = UserDefaults.standard.string(forKey: "generated_workout_plan")
            
            WatchConnectivityManager.shared.onMessageReceived = { message in
                guard let action = message["action"] as? String else { return }
                switch action {
                case "pause":
                    if tracker.isTracking && !tracker.isPaused {
                        tracker.pauseTracking()
                    }
                case "resume":
                    if tracker.isTracking && tracker.isPaused {
                        tracker.resumeTracking()
                    }
                case "finish":
                    if let _ = activeCustomWorkout {
                        finishCustomWorkout()
                    } else if tracker.isTracking {
                        finishWorkout()
                    }
                case "complete_set":
                    if activeCustomWorkout != nil {
                        completeSet()
                    }
                case "skip_rest":
                    if activeCustomWorkout != nil {
                        skipRest()
                    }
                case "start_preset":
                    if let typeStr = message["type"] as? String,
                       let type = WorkoutType.allCases.first(where: { $0.rawValue == typeStr }) {
                        selectedWorkoutType = type
                        let isGPS = type == .running || type == .walking || type == .cycling
                        tracker.startTracking(gpsTrackingEnabled: isGPS)
                        FormaLiveActivityManager.shared.startWorkoutActivity(
                            workoutType: type.localizedTitle(lang: appLanguage),
                            icon: type.icon,
                            startDate: Date()
                        )
                        FormaVoiceCoachManager.shared.onWorkoutStart(
                            workoutType: type.localizedTitle(lang: appLanguage),
                            language: appLanguage
                        )
                    }
                default:
                    break
                }
            }
        }
        .onReceive(tracker.$elapsedSeconds) { seconds in
            guard tracker.isTracking else { return }
            let calories = estimateCalories()
            let hr = health.isLiveHeartRateActive ? health.liveHeartRate : (health.heartRate > 0 ? health.heartRate : 0)
            
            // Голосовые подсказки тренера в наушники
            FormaVoiceCoachManager.shared.onWorkoutTick(
                elapsedSeconds: seconds,
                distanceMeters: tracker.distance,
                calories: Int(calories),
                heartRate: hr,
                language: appLanguage
            )
            
            if let customWorkout = activeCustomWorkout {
                let currentExercise = customWorkout.exercises.indices.contains(currentExerciseIndex) ? customWorkout.exercises[currentExerciseIndex] : nil
                WatchConnectivityManager.shared.sendActiveStateToWatch(
                    elapsedSeconds: seconds,
                    calories: calories,
                    exerciseName: currentExercise?.name ?? "",
                    currentSet: currentSetIndex,
                    totalSets: currentExercise?.sets ?? 0,
                    reps: currentExercise?.reps ?? 0,
                    isTimeBased: currentExercise?.isTimeBased ?? false,
                    isResting: isResting,
                    restSecondsRemaining: restSecondsRemaining
                )
                FormaLiveActivityManager.shared.updateWorkoutActivity(
                    elapsedSeconds: seconds,
                    calories: Int(calories),
                    heartRate: hr,
                    distanceMeters: tracker.distance,
                    steps: tracker.steps,
                    isPaused: tracker.isPaused,
                    exerciseName: currentExercise?.name,
                    currentSet: currentSetIndex,
                    totalSets: currentExercise?.sets ?? 0
                )
            } else {
                WatchConnectivityManager.shared.sendActiveStateToWatch(
                    elapsedSeconds: seconds,
                    calories: calories,
                    exerciseName: selectedWorkoutType.localizedTitle(lang: appLanguage),
                    currentSet: 0,
                    totalSets: 0,
                    reps: 0,
                    isTimeBased: false,
                    isResting: false,
                    restSecondsRemaining: 0
                )
                FormaLiveActivityManager.shared.updateWorkoutActivity(
                    elapsedSeconds: seconds,
                    calories: Int(calories),
                    heartRate: hr,
                    distanceMeters: tracker.distance,
                    steps: tracker.steps,
                    isPaused: tracker.isPaused,
                    exerciseName: selectedWorkoutType.localizedTitle(lang: appLanguage),
                    currentSet: 0,
                    totalSets: 0
                )
            }
        }
    }
    
    // MARK: - Subviews
    
    private var workoutsSetupView: some View {
        VStack(spacing: 24) {
            HStack(spacing: 12) {
                AppLogoView(size: 34)
                Text(tr("workouts_title"))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 12)
            
            // Календарь активности
            fitnessCalendarStrip
            
            // Выбор вкладки (Готовые / Личные)
            Picker("", selection: $selectedTab) {
                Text(tr("workout_tab_presets")).tag(WorkoutTab.presets)
                Text(tr("workout_tab_custom")).tag(WorkoutTab.custom)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            // ИИ-Тренер
            AITrainerCoachRow(
                message: selectedTab == .presets
                    ? tr("coach_msg_presets")
                    : tr("coach_msg_custom"),
                coachState: .idle
            )
            .padding(.horizontal)
            
            if selectedTab == .presets {
                // Готовые тренировки
                VStack(alignment: .leading, spacing: 12) {
                    Text(tr("workouts_select_activity"))
                        .font(.headline)
                        .foregroundColor(Theme.textSecondary)
                    
                    ForEach(WorkoutType.allCases) { type in
                        Button(action: {
                            selectedWorkoutType = type
                        }) {
                            HStack(spacing: 16) {
                                Image(systemName: type.icon)
                                    .font(.title3)
                                    .foregroundColor(selectedWorkoutType == type ? Theme.cardBackground : Theme.textPrimary)
                                    .frame(width: 40, height: 40)
                                    .background(selectedWorkoutType == type ? Theme.textPrimary : Theme.background)
                                    .clipShape(Circle())
                                
                                Text(type.localizedTitle(lang: appLanguage))
                                    .font(.body)
                                    .foregroundColor(Theme.textPrimary)
                                    .bold()
                                
                                Spacer()
                                
                                if selectedWorkoutType == type {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Theme.textPrimary)
                                }
                            }
                            .padding()
                            .background(Theme.cardBackground)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.02), radius: 6, x: 0, y: 3)
                        }
                    }
                }
                .padding(.horizontal)
                
                WorkoutMusicPlayerWidget()
                    .padding(.horizontal)
                
                Button(action: {
                    let isGPS = selectedWorkoutType == .running || selectedWorkoutType == .walking || selectedWorkoutType == .cycling
                    tracker.startTracking(gpsTrackingEnabled: isGPS)
                    FormaLiveActivityManager.shared.startWorkoutActivity(
                        workoutType: selectedWorkoutType.localizedTitle(lang: appLanguage),
                        icon: selectedWorkoutType.icon,
                        startDate: Date()
                    )
                    FormaVoiceCoachManager.shared.onWorkoutStart(
                        workoutType: selectedWorkoutType.localizedTitle(lang: appLanguage),
                        language: appLanguage
                    )
                }) {
                    Text(tr("workouts_start"))
                        .font(.headline)
                        .foregroundColor(Theme.cardBackground)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.textPrimary)
                        .cornerRadius(16)
                        .shadow(color: Theme.textPrimary.opacity(0.15), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Карточка ИИ-плана тренировки
                aiWorkoutPlanCard
            } else {
                // Личные тренировки
                customWorkoutsListView
                    .padding(.horizontal)
            }
        }
    }
    
    private var customWorkoutsListView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(tr("custom_workout_exercises"))
                    .font(.headline)
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Button(action: {
                    showingCreateWorkout = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text(tr("custom_workout_add_exercise"))
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(Theme.exerciseColor)
                }
            }
            
            if customStore.workouts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Theme.textSecondary.opacity(0.4))
                    Text(tr("custom_workout_no_exercises"))
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .premiumCard()
            } else {
                ForEach(customStore.workouts) { workout in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(workout.name)
                                .font(.title3)
                                .bold()
                                .foregroundColor(Theme.textPrimary)
                            Spacer()
                            
                            // Кнопка удаления
                            Button(action: {
                                if let index = customStore.workouts.firstIndex(where: { $0.id == workout.id }) {
                                    customStore.deleteWorkout(at: IndexSet(integer: index))
                                }
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red.opacity(0.8))
                                    .font(.subheadline)
                            }
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.08))
                        
                        ForEach(workout.exercises) { ex in
                            HStack {
                                Image(systemName: ex.isTimeBased ? "timer" : "repeat")
                                    .foregroundColor(Theme.exerciseColor)
                                    .font(.caption)
                                Text(ex.name)
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textPrimary.opacity(0.9))
                                Spacer()
                                Text("\(ex.sets)x\(ex.isTimeBased ? "\(ex.durationSeconds)с" : "\(ex.reps)")")
                                    .font(.caption.bold())
                                    .foregroundColor(Theme.textSecondary)
                                if ex.weightKg > 0 {
                                    Text("\(String(format: "%.1f", ex.weightKg))кг")
                                        .font(.caption.bold())
                                        .foregroundColor(Theme.standColor)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Theme.standColor.opacity(0.12))
                                        .cornerRadius(6)
                                }
                            }
                        }
                        
                        Button(action: {
                            startCustomWorkout(workout)
                        }) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text(tr("custom_workout_start_btn"))
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.exerciseColor)
                            .cornerRadius(14)
                            .shadow(color: Theme.exerciseColor.opacity(0.2), radius: 6)
                        }
                        .padding(.top, 4)
                    }
                    .premiumCard()
                }
            }
        }
    }
    
    private var standardWorkoutActiveView: some View {
        VStack(spacing: 24) {
            Text(selectedWorkoutType.localizedTitle(lang: appLanguage))
                .font(.title3)
                .foregroundColor(Theme.textSecondary)
                .bold()
            
            Text(formatDuration(tracker.elapsedSeconds))
                .font(.system(size: 54, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.textPrimary)
            
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(tracker.isPaused ? Color.orange : (selectedWorkoutType.isStationaryFriendly ? Color.green : (tracker.isStationary ? Color.orange : Color.green)))
                        .frame(width: 8, height: 8)
                    Text(tracker.isPaused ? tr("workouts_paused") : (selectedWorkoutType.isStationaryFriendly ? tr("workouts_active") : (tracker.isStationary ? tr("workouts_autopause") : tr("workouts_active"))))
                        .font(.footnote)
                        .foregroundColor(tracker.isPaused ? .orange : (selectedWorkoutType.isStationaryFriendly ? .green : (tracker.isStationary ? .orange : .green)))
                        .bold()
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 12)
                .background(tracker.isPaused ? Color.orange.opacity(0.1) : (selectedWorkoutType.isStationaryFriendly ? Color.green.opacity(0.1) : (tracker.isStationary ? Color.orange.opacity(0.1) : Color.green.opacity(0.1))))
                .cornerRadius(12)
                
                // Кнопка быстрого переключения голоса тренера
                Button(action: {
                    FormaVoiceCoachManager.shared.isVoiceCoachEnabled.toggle()
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: FormaVoiceCoachManager.shared.isVoiceCoachEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        Text(FormaVoiceCoachManager.shared.isVoiceCoachEnabled ? "Голос" : "Без звука")
                    }
                    .font(.footnote.bold())
                    .foregroundColor(FormaVoiceCoachManager.shared.isVoiceCoachEnabled ? Theme.exerciseColor : Theme.textSecondary)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 10)
                    .background(FormaVoiceCoachManager.shared.isVoiceCoachEnabled ? Theme.exerciseColor.opacity(0.12) : Color.primary.opacity(0.06))
                    .cornerRadius(12)
                }
            }
            
            // ИИ-тренер координирует во время стандартной тренировки
            AITrainerCoachRow(
                message: tracker.isPaused
                    ? "Отдыхаем. Сделай глоток воды 💧."
                    : "Отличный темп! Спина прямо, дыши ровно! 💪 Ты уже сжег \(String(format: "%.0f", estimateCalories())) ккал!",
                coachState: tracker.isPaused ? .resting : .exercising
            )
            .padding(.horizontal)
            
            if selectedWorkoutType.isStationaryFriendly {
                WorkoutExerciseCard(workoutType: selectedWorkoutType)
                    .padding(.horizontal)
            } else if let url = URL(string: selectedWorkoutType.videoURL) {
                WorkoutVideoLoopPlayer(videoURL: url)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                    .padding(.horizontal)
            }

            
            if selectedWorkoutType == .running || selectedWorkoutType == .walking || selectedWorkoutType == .cycling {
                WorkoutMapView(routeCoordinates: tracker.routeCoordinates)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
            }
            
            HStack(spacing: 16) {
                WorkoutStatCard(
                    title: tr("workouts_distance"),
                    value: String(format: "%.2f %@", tracker.distance / 1000.0, appLanguage == "en" ? "km" : (appLanguage == "hy" ? "կմ" : "км")),
                    icon: "arrow.triangle.pull",
                    color: Theme.moveColor
                )
                WorkoutStatCard(
                    title: tr("workouts_calories"),
                    value: String(format: "%.0f %@", estimateCalories(), tr("kcal")),
                    icon: "flame.fill",
                    color: Theme.pulseColor
                )
            }
            
            if tracker.steps > 0 {
                HStack {
                    Image(systemName: "figure.walk")
                        .foregroundColor(.orange)
                    Text(String(format: "%@: %d", tr("workouts_steps"), tracker.steps))
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                }
                .padding(.vertical, 4)
            }
            
            WorkoutMusicPlayerWidget()
            
            Button(action: {
                showingVideoRecorder = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "video.badge.plus.fill")
                        .font(.headline)
                    Text(tr("workouts_record_video"))
                        .font(.headline)
                }
                .foregroundColor(Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Theme.background)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Theme.textSecondary.opacity(0.15), lineWidth: 1)
                )
            }
            .padding(.top, 4)
            
            HStack(spacing: 16) {
                Button(action: {
                    if tracker.isPaused {
                        tracker.resumeTracking()
                    } else {
                        tracker.pauseTracking()
                    }
                    let hr = health.isLiveHeartRateActive ? health.liveHeartRate : (health.heartRate > 0 ? health.heartRate : 0)
                    FormaLiveActivityManager.shared.updateWorkoutActivity(
                        elapsedSeconds: tracker.elapsedSeconds,
                        calories: Int(estimateCalories()),
                        heartRate: hr,
                        distanceMeters: tracker.distance,
                        steps: tracker.steps,
                        isPaused: tracker.isPaused,
                        exerciseName: selectedWorkoutType.localizedTitle(lang: appLanguage)
                    )
                }) {
                    HStack {
                        Image(systemName: tracker.isPaused ? "play.fill" : "pause.fill")
                        Text(tracker.isPaused ? tr("workouts_resume") : tr("workouts_pause"))
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(tracker.isPaused ? Theme.exerciseColor : Color.orange)
                    .cornerRadius(16)
                    .shadow(color: (tracker.isPaused ? Theme.exerciseColor : Color.orange).opacity(0.3), radius: 8)
                }
                
                Button(action: {
                    finishWorkout()
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text(tr("workouts_finish"))
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.moveColor)
                    .cornerRadius(16)
                    .shadow(color: Theme.moveColor.opacity(0.3), radius: 8)
                }
            }
            .padding(.top, 8)
        }
        .padding()
        .premiumCard()
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func customWorkoutActiveView(workout: CustomWorkout) -> some View {
        if workout.exercises.indices.contains(currentExerciseIndex) {
            let currentExercise = workout.exercises[currentExerciseIndex]
            VStack(spacing: 20) {
            VStack(spacing: 4) {
                Text(workout.name)
                    .font(.title2.bold())
                    .foregroundColor(Theme.textPrimary)
                
                Text(tr("workouts_active"))
                    .font(.caption.bold())
                    .foregroundColor(Theme.exerciseColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Theme.exerciseColor.opacity(0.12))
                    .cornerRadius(10)
            }
            .padding(.top, 16)
            
            Text(formatDuration(tracker.elapsedSeconds))
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.textPrimary)
            
            Group {
                if isResting {
                    AITrainerCoachRow(
                        message: "Отлично поработал! Сейчас время отдыха. Восстанови дыхание, сделай глоток воды. Отдыхаем \(restSecondsRemaining) секунд.",
                        coachState: .resting
                    )
                } else {
                    AITrainerCoachRow(
                        message: "Упражнение \(currentExerciseIndex + 1) из \(workout.exercises.count): \(currentExercise.name). Подход \(currentSetIndex) из \(currentExercise.sets). Цель: \(currentExercise.isTimeBased ? "\(currentExercise.durationSeconds) сек" : "\(currentExercise.reps) повт")\(currentExercise.weightKg > 0 ? " · \(String(format: "%.1f", currentExercise.weightKg)) кг" : ""). Держи спину прямо!",
                        coachState: .exercising
                    )
                }
            }
            .padding(.horizontal)
            
            VStack(spacing: 16) {
                if isResting {
                    VStack(spacing: 12) {
                        Text(tr("custom_workout_rest_title"))
                            .font(.headline)
                            .foregroundColor(Theme.textSecondary)
                        
                        Text("\(restSecondsRemaining)")
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.exerciseColor)
                        
                        Button(action: {
                            skipRest()
                        }) {
                            Text(tr("custom_workout_skip_rest"))
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Theme.exerciseColor)
                                .cornerRadius(12)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text(currentExercise.name)
                                .font(.title3.bold())
                                .foregroundColor(Theme.textPrimary)
                            Spacer()
                            Text("\(tr("custom_workout_sets")): \(currentSetIndex)/\(currentExercise.sets)")
                                .font(.subheadline.bold())
                                .foregroundColor(Theme.exerciseColor)
                        }
                        
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(currentExercise.isTimeBased ? tr("custom_workout_duration") : tr("custom_workout_reps"))
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                                Text(currentExercise.isTimeBased ? "\(currentExercise.durationSeconds) \(tr("sec"))" : "\(currentExercise.reps)")
                                    .font(.title2.bold())
                                    .foregroundColor(Theme.textPrimary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Theme.background)
                            .cornerRadius(12)
                            
                            if currentExercise.weightKg > 0 {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(tr("custom_workout_weight"))
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                    Text("\(String(format: "%.1f", currentExercise.weightKg)) \(tr("kg"))")
                                        .font(.title2.bold())
                                        .foregroundColor(Theme.standColor)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Theme.background)
                                .cornerRadius(12)
                            }
                        }
                        
                        Button(action: {
                            completeSet()
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text(tr("custom_workout_next_set"))
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.exerciseColor)
                            .cornerRadius(16)
                            .shadow(color: Theme.exerciseColor.opacity(0.2), radius: 8)
                        }
                    }
                    .padding()
                }
            }
            .premiumCard()
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("План тренировки")
                    .font(.headline)
                    .foregroundColor(Theme.textSecondary)
                    .padding(.horizontal)
                
                VStack(spacing: 0) {
                    ForEach(0..<workout.exercises.count, id: \.self) { idx in
                        let ex = workout.exercises[idx]
                        HStack {
                            Circle()
                                .fill(idx < currentExerciseIndex ? Theme.exerciseColor : (idx == currentExerciseIndex ? Theme.standColor : Theme.textSecondary.opacity(0.3)))
                                .frame(width: 8, height: 8)
                                .padding(.trailing, 8)
                            
                            Text(ex.name)
                                .font(.subheadline)
                                .foregroundColor(idx == currentExerciseIndex ? Theme.textPrimary : Theme.textSecondary)
                                .bold(idx == currentExerciseIndex)
                            
                            Spacer()
                            
                            Text("\(ex.sets) подходов")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal)
                        
                        if idx < workout.exercises.count - 1 {
                            Divider()
                                .padding(.horizontal)
                        }
                    }
                }
                .premiumCard()
                .padding(.horizontal)
            }
            
            WorkoutMusicPlayerWidget()
                .padding(.horizontal)
            
            Button(action: {
                finishCustomWorkout()
            }) {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                    Text(tr("workouts_finish"))
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.85))
                .cornerRadius(16)
                .shadow(color: Color.red.opacity(0.2), radius: 8)
            }
            .padding(.horizontal)
            .padding(.bottom, 100)
            }
        }
    }
    
    private var aiWorkoutPlanCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                    .font(.title3)
                Text(tr("ai_workout_plan_title"))
                    .font(.headline)
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
                if let plan = generatedWorkoutPlan {
                    ScrollView {
                        Text(plan)
                            .font(.subheadline)
                            .foregroundColor(Theme.textPrimary.opacity(0.9))
                            .lineSpacing(4)
                            .multilineTextAlignment(.leading)
                            .padding(12)
                    }
                    .frame(maxHeight: 220)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                } else if let error = workoutPlanError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(Theme.pulseColor)
                        .padding()
                        .background(Theme.pulseColor.opacity(0.08))
                        .cornerRadius(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(tr("ai_workout_plan_desc"))
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                        .padding(.vertical, 4)
                }
                
                Button(action: {
                    runGenerateWorkoutPlan()
                }) {
                    HStack {
                        if isGeneratingWorkoutPlan {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .padding(.trailing, 8)
                        }
                        Text(isGeneratingWorkoutPlan ? tr("ai_workout_plan_btn_planning") : tr("ai_workout_plan_btn_generate"))
                            .bold()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .padding()
                    .background(isGeneratingWorkoutPlan ? Theme.exerciseColor.opacity(0.6) : Theme.exerciseColor)
                    .cornerRadius(16)
                    .shadow(color: Theme.exerciseColor.opacity(0.3), radius: 8)
                }
                .disabled(isGeneratingWorkoutPlan)
            }
        }
        .premiumCard()
        .padding(.horizontal)
        .padding(.top, 16)
    }
    
    // MARK: - Logic Helpers
    
    private func startCustomWorkout(_ workout: CustomWorkout) {
        activeCustomWorkout = workout
        currentExerciseIndex = 0
        currentSetIndex = 1
        isResting = false
        restTimer?.cancel()
        restTimer = nil
        
        tracker.startTracking(gpsTrackingEnabled: false)
        FormaLiveActivityManager.shared.startWorkoutActivity(
            workoutType: workout.name,
            icon: "dumbbell.fill",
            startDate: Date()
        )
        FormaVoiceCoachManager.shared.onWorkoutStart(
            workoutType: workout.name,
            language: appLanguage
        )
        
        let exerciseDicts = workout.exercises.map { ex -> [String: Any] in
            return [
                "name": ex.name,
                "sets": ex.sets,
                "reps": ex.reps,
                "durationSeconds": ex.durationSeconds,
                "isTimeBased": ex.isTimeBased
            ]
        }
        WatchConnectivityManager.shared.sendWorkoutToWatch(name: workout.name, exercises: exerciseDicts)
    }
    
    private func completeSet() {
        guard let workout = activeCustomWorkout else { return }
        let exercise = workout.exercises[currentExerciseIndex]
        
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        if currentSetIndex < exercise.sets {
            FormaVoiceCoachManager.shared.onSetCompleted(
                exerciseName: exercise.name,
                completedSet: currentSetIndex,
                totalSets: exercise.sets,
                restSeconds: exercise.restSeconds,
                language: appLanguage
            )
            startRestTimer(seconds: exercise.restSeconds)
        } else {
            if currentExerciseIndex < workout.exercises.count - 1 {
                currentExerciseIndex += 1
                currentSetIndex = 1
                FormaVoiceCoachManager.shared.onSetCompleted(
                    exerciseName: exercise.name,
                    completedSet: exercise.sets,
                    totalSets: exercise.sets,
                    restSeconds: workout.exercises[currentExerciseIndex].restSeconds,
                    language: appLanguage
                )
                startRestTimer(seconds: workout.exercises[currentExerciseIndex].restSeconds)
            } else {
                finishCustomWorkout()
            }
        }
    }
    
    private func startRestTimer(seconds: Int) {
        restSecondsRemaining = seconds
        isResting = true
        restTimer?.cancel()
        
        let impact = UINotificationFeedbackGenerator()
        impact.notificationOccurred(.success)
        
        restTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                let nextExName = self.currentExerciseIndex < (self.activeCustomWorkout?.exercises.count ?? 0) ? (self.activeCustomWorkout?.exercises[self.currentExerciseIndex].name ?? "") : ""
                FormaVoiceCoachManager.shared.onRestCountdownTick(
                    secondsRemaining: self.restSecondsRemaining,
                    nextExerciseName: nextExName,
                    language: self.appLanguage
                )
                
                if self.restSecondsRemaining > 1 {
                    self.restSecondsRemaining -= 1
                } else {
                    self.skipRest()
                }
            }
    }
    
    private func skipRest() {
        restTimer?.cancel()
        restTimer = nil
        // Увеличиваем подход только если ещё были в состоянии отдыха
        if isResting {
            currentSetIndex += 1
        }
        isResting = false
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    private func finishCustomWorkout() {
        restTimer?.cancel()
        restTimer = nil
        isResting = false
        
        guard let workout = activeCustomWorkout else { return }
        let summary = tracker.stopTracking()
        
        let weight = health.currentWeight > 0 ? health.currentWeight : 75.0
        let minutes = Double(summary.duration) / 60.0
        
        let calories = 6.0 * 3.5 * weight / 200.0 * minutes
        
        lastSummaryCalories = calories
        lastSummaryDistance = 0.0
        
        health.saveWorkout(
            activityType: "Strength",
            startDate: summary.startDate,
            endDate: summary.endDate,
            activeEnergyBurned: calories,
            distance: 0.0
        )
        
        if let last = health.workoutHistory.last {
            health.workoutHistory.removeLast()
            let updated = WorkoutRecord(
                id: last.id,
                type: workout.name,
                date: last.date,
                durationMinutes: last.durationMinutes,
                caloriesBurned: last.caloriesBurned
            )
            health.workoutHistory.append(updated)
            health.saveLocalData()
        }
        
        activeCustomWorkout = nil
        showingSummary = true
        WorkoutMusicManager.shared.pause()
        WatchConnectivityManager.shared.sendFinishToWatch()
        FormaLiveActivityManager.shared.endWorkoutActivity(
            finalSeconds: summary.duration,
            finalCalories: Int(calories),
            finalDistance: 0.0
        )
        FormaVoiceCoachManager.shared.onWorkoutFinish(
            durationSeconds: summary.duration,
            calories: Int(calories),
            distanceMeters: 0.0,
            language: appLanguage
        )
        GamificationManager.shared.addXP(150, reason: "Силовая тренировка")
        GamificationManager.shared.evaluateProgress(
            stepsToday: tracker.steps,
            distanceMetersToday: 0.0,
            workouts: health.workoutHistory,
            waterConsumed: health.waterConsumed,
            waterNorm: health.waterGoal,
            dailyHistory: health.dailyActivityHistory
        )
    }
    
    private func estimateCalories() -> Double {
        let weight = health.currentWeight > 0 ? health.currentWeight : 75.0
        let seconds = selectedWorkoutType.isStationaryFriendly ? tracker.elapsedSeconds : tracker.activeSeconds
        let minutes = Double(seconds) / 60.0
        return selectedWorkoutType.met * 3.5 * weight / 200.0 * minutes
    }
    
    private func finishWorkout() {
        let summary = tracker.stopTracking()
        
        let weight = health.currentWeight > 0 ? health.currentWeight : 75.0
        let seconds = selectedWorkoutType.isStationaryFriendly ? summary.duration : summary.activeDuration
        let minutes = Double(seconds) / 60.0
        let calories = selectedWorkoutType.met * 3.5 * weight / 200.0 * minutes
        
        lastSummaryCalories = calories
        lastSummaryDistance = summary.distance
        
        // Сохранение тренировки
        health.saveWorkout(
            activityType: selectedWorkoutType.typeId,
            startDate: summary.startDate,
            endDate: summary.endDate,
            activeEnergyBurned: calories,
            distance: summary.distance
        )
        
        showingSummary = true
        
        // Останавливаем музыку по окончании тренировки
        WorkoutMusicManager.shared.pause()
        WatchConnectivityManager.shared.sendFinishToWatch()
        FormaLiveActivityManager.shared.endWorkoutActivity(
            finalSeconds: summary.duration,
            finalCalories: Int(calories),
            finalDistance: summary.distance
        )
        FormaVoiceCoachManager.shared.onWorkoutFinish(
            durationSeconds: summary.duration,
            calories: Int(calories),
            distanceMeters: summary.distance,
            language: appLanguage
        )
        GamificationManager.shared.addXP(150, reason: "Тренировка завершена")
        GamificationManager.shared.evaluateProgress(
            stepsToday: tracker.steps,
            distanceMetersToday: summary.distance,
            workouts: health.workoutHistory,
            waterConsumed: health.waterConsumed,
            waterNorm: health.waterGoal,
            dailyHistory: health.dailyActivityHistory
        )
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let hrs = seconds / 3600
        let mins = (seconds % 3600) / 60
        let secs = seconds % 60
        if hrs > 0 {
            return String(format: "%02d:%02d:%02d", hrs, mins, secs)
        } else {
            return String(format: "%02d:%02d", mins, secs)
        }
    }
    
    private func runWorkoutsAnalysis() {
        guard hasAnyApiKey else { return }
        isAnalyzingWorkouts = true
        workoutsAnalysisError = nil
        workoutsAnalysisResult = nil
        
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        Task {
            do {
                let result = try await GeminiScanService.shared.analyzeWorkouts(
                    workouts: health.workoutHistory,
                    language: appLanguage
                )
                await MainActor.run {
                    self.workoutsAnalysisResult = result
                    self.isAnalyzingWorkouts = false
                }
            } catch {
                await MainActor.run {
                    self.workoutsAnalysisError = "Ошибка анализа: \(error.localizedDescription)"
                    self.isAnalyzingWorkouts = false
                }
            }
        }
    }
    
    private func runGenerateWorkoutPlan() {
        guard hasAnyApiKey else { return }
        isGeneratingWorkoutPlan = true
        workoutPlanError = nil
        
        let weight = health.currentWeight > 0 ? health.currentWeight : userWeight
        
        Task {
            do {
                let plan = try await GeminiScanService.shared.generateWorkoutPlan(
                    age: userAge,
                    height: userHeight,
                    weight: weight,
                    gender: userGender,
                    targetWeight: userTargetWeight,
                    activityLevel: userActivityLevel,
                    language: appLanguage
                )
                await MainActor.run {
                    self.generatedWorkoutPlan = plan
                    UserDefaults.standard.set(plan, forKey: "generated_workout_plan")
                    self.isGeneratingWorkoutPlan = false
                }
            } catch {
                await MainActor.run {
                    self.workoutPlanError = "Не удалось составить план: \(error.localizedDescription)"
                    self.isGeneratingWorkoutPlan = false
                }
            }
        }
    }
    
    // MARK: - Fitness Calendar & History by Day
    
    private var fitnessCalendarStrip: some View {
        VStack(spacing: 12) {
            HStack {
                Text(tr("workouts_activity_history"))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Text(formatMonthYear(selectedCalendarDate))
                    .font(.subheadline.bold())
                    .foregroundColor(Theme.exerciseColor)
            }
            .padding(.horizontal, 4)
            
            HStack(spacing: 4) {
                ForEach(lastSevenDays, id: \.self) { date in
                    let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedCalendarDate)
                    let isToday = Calendar.current.isDateInToday(date)
                    let hasWorkout = hasWorkoutOnDate(date)
                    
                    Button(action: {
                        selectedCalendarDate = date
                    }) {
                        VStack(spacing: 6) {
                            Text(getDayOfWeekName(date))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(isSelected ? Theme.textPrimary : Theme.textSecondary)
                            
                            ZStack {
                                Circle()
                                    .fill(isSelected ? Theme.textPrimary : (isToday ? Theme.textPrimary.opacity(0.15) : Color.clear))
                                    .frame(width: 30, height: 30)
                                
                                Text(getDayNumber(date))
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(isSelected ? Theme.cardBackground : Theme.textPrimary)
                            }
                            
                            // Индикатор активности на дне календаря (Зеленый = тренировка, Оранжевый = зафиксированные шаги)
                            let daySteps = health.stepsForDate(date)
                            Circle()
                                .fill(hasWorkout ? Theme.exerciseColor : (daySteps > 0 ? Color.orange : Color.clear))
                                .frame(width: 5, height: 5)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(isSelected ? Theme.textPrimary.opacity(0.04) : Color.clear)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isToday && !isSelected ? Theme.textPrimary.opacity(0.2) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(6)
            .background(Theme.cardBackground)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.01), radius: 4, x: 0, y: 2)
            
            selectedDayDetailsView
        }
        .padding(.horizontal)
    }
    
    private var selectedDayDetailsView: some View {
        let dayWorkouts = workoutsForDate(selectedCalendarDate)
        let totalDuration = dayWorkouts.reduce(0) { $0 + $1.durationMinutes }
        let totalCalories = dayWorkouts.reduce(0.0) { $0 + $1.caloriesBurned }
        
        let isToday = Calendar.current.isDateInToday(selectedCalendarDate)
        let dayActivity = health.activityForDate(selectedCalendarDate)
        
        let daySteps: Int = {
            if isToday {
                return max(health.stepsToday, stepManager.stepsToday, dayActivity?.steps ?? 0)
            }
            return dayActivity?.steps ?? 0
        }()
        
        let dayDistanceKm: Double = {
            if isToday {
                return max(health.distanceMetersToday, stepManager.distanceMeters) / 1000.0
            }
            return (dayActivity?.distanceMeters ?? 0.0) / 1000.0
        }()
        
        let dayActiveCalories: Double = {
            if isToday {
                return health.activeEnergyBurned > 0 ? health.activeEnergyBurned : (health.calculatedStepCalories > 0 ? health.calculatedStepCalories : Double(daySteps) * 0.04)
            }
            return (dayActivity?.activeCalories ?? 0.0) > 0 ? (dayActivity?.activeCalories ?? 0.0) : Double(daySteps) * 0.04
        }()
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(isToday ? tr("today") : formatCalendarDate(selectedCalendarDate))
                    .font(.subheadline.bold())
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                if !dayWorkouts.isEmpty {
                    Text(String(format: tr("workouts_count_badge"), dayWorkouts.count))
                        .font(.caption.bold())
                        .foregroundColor(Theme.exerciseColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.exerciseColor.opacity(0.1))
                        .cornerRadius(8)
                } else if daySteps > 0 {
                    let formattedSteps = LocalizationManager.formatNumber(daySteps, lang: appLanguage)
                    HStack(spacing: 4) {
                        Image(systemName: "figure.walk")
                        Text("\(formattedSteps) ш.")
                    }
                    .font(.caption.bold())
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.12))
                    .cornerRadius(8)
                }
            }
            
            if dayWorkouts.isEmpty {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: daySteps > 0 ? "figure.walk.circle.fill" : "figure.run.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(daySteps > 0 ? .orange : Theme.textSecondary.opacity(0.4))
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(daySteps > 0 ? tr("workouts_no_workouts_activity") : tr("workouts_no_workouts_empty"))
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(Theme.textPrimary)
                            Text(daySteps > 0 ? tr("workouts_steps_calories_source") : tr("workouts_sensors_empty"))
                                .font(.caption2)
                                .foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                    }
                    
                    if daySteps > 0 {
                        Divider()
                            .background(Theme.textSecondary.opacity(0.1))
                        
                        HStack(spacing: 8) {
                            // Шаги
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tr("steps_label"))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Theme.textSecondary)
                                Text(LocalizationManager.formatNumber(daySteps, lang: appLanguage))
                                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Дистанция
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tr("distance_label"))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Theme.textSecondary)
                                Text(String(format: "%.2f км", dayDistanceKm))
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(.blue)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Калории активности
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tr("calories_label"))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Theme.textSecondary)
                                Text(String(format: "%.0f %@", dayActiveCalories, tr("kcal")))
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(.orange)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.top, 2)
                    }
                }
                .padding()
                .background(Theme.cardBackground)
                .cornerRadius(16)
            } else {
                VStack(spacing: 10) {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading) {
                            Text(tr("workouts_time_label"))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                            Text("\(totalDuration) мин")
                                .font(.body.bold())
                                .foregroundColor(Theme.textPrimary)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(tr("workouts_burned_label"))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                            Text(String(format: "%.0f %@", totalCalories, tr("kcal")))
                                .font(.body.bold())
                                .foregroundColor(Theme.exerciseColor)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 2)
                    
                    Divider()
                        .background(Theme.textSecondary.opacity(0.08))
                    
                    ForEach(dayWorkouts) { workout in
                        HStack(spacing: 12) {
                            Image(systemName: workout.type == "Бег" ? "figure.run" : (workout.type == "Ходьба" ? "figure.walk" : "dumbbell.fill"))
                                .foregroundColor(Theme.exerciseColor)
                                .frame(width: 30, height: 30)
                                .background(Theme.exerciseColor.opacity(0.1))
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(workout.type)
                                    .font(.subheadline.bold())
                                    .foregroundColor(Theme.textPrimary)
                                
                                Text("\(formatTimeOnly(workout.date))")
                                    .font(.system(size: 9))
                                    .foregroundColor(Theme.textSecondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(workout.durationMinutes) мин")
                                    .font(.subheadline.bold())
                                    .foregroundColor(Theme.textPrimary)
                                Text(String(format: "%.0f ккал", workout.caloriesBurned))
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    if daySteps > 0 {
                        Divider()
                            .background(Theme.textSecondary.opacity(0.08))
                        
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: "figure.walk")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                Text("Всего шагов за день:")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                                Text("\(daySteps)")
                                    .font(.caption.bold())
                                    .foregroundColor(Theme.textPrimary)
                            }
                            Spacer()
                            Text(String(format: "%.2f км • %.0f ккал", dayDistanceKm, dayActiveCalories))
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                        .padding(.horizontal, 4)
                        .padding(.top, 2)
                    }
                }
                .padding()
                .background(Theme.cardBackground)
                .cornerRadius(16)
            }
        }
    }
    
    private var lastSevenDays: [Date] {
        let calendar = Calendar.current
        let now = Date()
        return (0..<7).compactMap { i in
            calendar.date(byAdding: .day, value: -i, to: now)
        }.reversed()
    }
    
    private func getDayOfWeekName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EE"
        return formatter.string(from: date).capitalized
    }
    
    private func getDayNumber(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private func hasWorkoutOnDate(_ date: Date) -> Bool {
        return health.workoutHistory.contains { record in
            Calendar.current.isDate(record.date, inSameDayAs: date)
        }
    }
    
    private func workoutsForDate(_ date: Date) -> [WorkoutRecord] {
        return health.workoutHistory.filter { record in
            Calendar.current.isDate(record.date, inSameDayAs: date)
        }
    }
    
    private func formatMonthYear(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date).capitalized
    }
    
    private func formatCalendarDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: date)
    }
    
    private func formatTimeOnly(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - WorkoutMapView
struct WorkoutMapView: UIViewRepresentable {
    var routeCoordinates: [CLLocationCoordinate2D]
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .follow
        
        // Премиальные скругленные углы
        mapView.layer.cornerRadius = 20
        mapView.clipsToBounds = true
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeOverlays(mapView.overlays)
        
        if routeCoordinates.count > 1 {
            let polyline = MKPolyline(coordinates: routeCoordinates, count: routeCoordinates.count)
            mapView.addOverlay(polyline)
            
            // Если координаты обновились, центрируем карту на последней точке
            if let lastCoord = routeCoordinates.last {
                let region = MKCoordinateRegion(center: lastCoord, latitudinalMeters: 350, longitudinalMeters: 350)
                mapView.setRegion(region, animated: true)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(red: 0/255, green: 229/255, blue: 255/255, alpha: 0.95) // Неоновый голубой (StandColor)
                renderer.lineWidth = 5
                renderer.lineCap = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// MARK: - WorkoutMusicPlayerWidget
struct WorkoutMusicPlayerWidget: View {
    @StateObject private var musicManager = WorkoutMusicManager.shared
    @State private var equalizerAnimating = false
    @AppStorage("app_language") private var appLanguage = "ru"
    
    private func tr(_ key: String) -> String {
        LocalizationManager.tr(key, lang: appLanguage)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "music.note")
                    .foregroundColor(Theme.standColor)
                Text(tr("music_player_title"))
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                
                // Переключатель источника
                Picker("", selection: Binding(
                    get: { musicManager.currentSource },
                    set: { musicManager.toggleSource(to: $0) }
                )) {
                    Text(tr("music_source_radio")).tag(MusicSource.radio)
                    Text(tr("music_source_music")).tag(MusicSource.appleMusic)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 150)
            }
            
            HStack(spacing: 14) {
                // Превью обложки
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.primary.opacity(0.06))
                        .frame(width: 48, height: 48)
                    
                    if let artwork = musicManager.currentArtwork {
                        Image(uiImage: artwork)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 48, height: 48)
                            .cornerRadius(12)
                    } else {
                        Image(systemName: musicManager.currentSource == .radio ? "radio.fill" : "music.note.list")
                            .font(.title3)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                
                // Название трека и автор
                VStack(alignment: .leading, spacing: 4) {
                    if musicManager.currentSource == .appleMusic && musicManager.isAppleMusicAuthorized {
                        Menu {
                            if musicManager.availablePlaylists.isEmpty {
                                Button("Загрузка...") { }
                                Button("Обновить список 🔄") {
                                    Task {
                                        await musicManager.fetchPlaylists()
                                    }
                                }
                            } else {
                                ForEach(musicManager.availablePlaylists, id: \.id) { playlist in
                                    Button(playlist.name) {
                                        musicManager.playPlaylist(playlist)
                                    }
                                }
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(musicManager.currentTrackTitle)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Theme.textPrimary)
                                        .lineLimit(1)
                                        .multilineTextAlignment(.leading)
                                    Image(systemName: "chevron.down")
                                        .font(.caption2)
                                        .foregroundColor(Theme.textSecondary)
                                }
                                
                                Text(musicManager.currentArtist)
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.textSecondary)
                                    .lineLimit(1)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                    } else {
                        Text(musicManager.currentTrackTitle)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.textPrimary)
                            .lineLimit(1)
                        
                        Text(musicManager.currentArtist)
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textSecondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Анимированный эквалайзер
                if musicManager.isPlaying {
                    HStack(spacing: 2) {
                        ForEach(0..<4) { index in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Theme.standColor)
                                .frame(width: 2.5)
                                .frame(height: equalizerAnimating ? CGFloat.random(in: 4...20) : 8)
                                .animation(
                                    Animation.easeInOut(duration: 0.35)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(index) * 0.08),
                                    value: equalizerAnimating
                                )
                        }
                    }
                    .frame(height: 20)
                    .onAppear {
                        equalizerAnimating = true
                    }
                    .onDisappear {
                        equalizerAnimating = false
                    }
                }
            }
            .padding(.vertical, 2)
            
            Divider()
                .background(Color.white.opacity(0.08))
            
            // Кнопки плеера
            HStack(spacing: 32) {
                Button(action: {
                    musicManager.previous()
                }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Theme.textPrimary)
                }
                
                Button(action: {
                    if musicManager.isPlaying {
                        musicManager.pause()
                    } else {
                        musicManager.play()
                    }
                }) {
                    Image(systemName: musicManager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18))
                        .bold()
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
                        .background(Theme.exerciseColor)
                        .clipShape(Circle())
                        .shadow(color: Theme.exerciseColor.opacity(0.3), radius: 5)
                }
                
                Button(action: {
                    musicManager.next()
                }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Theme.textPrimary)
                }
            }
            .padding(.top, 2)
            
            // Авторизация Apple Music при необходимости
            if musicManager.currentSource == .appleMusic && !musicManager.isAppleMusicAuthorized {
                Button(action: {
                    Task {
                        await musicManager.requestAppleMusicAccess()
                        await musicManager.fetchPlaylists()
                    }
                }) {
                    Text(tr("music_authorize_apple_music"))
                        .font(.caption2)
                        .bold()
                        .foregroundColor(.white)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .background(Theme.moveColor)
                        .cornerRadius(8)
                }
                .padding(.top, 2)
            }
        }
        .padding(12)
        .background(Theme.cardBackground)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
        .onAppear {
            if musicManager.isAppleMusicAuthorized {
                Task {
                    await musicManager.fetchPlaylists()
                }
            }
        }
    }
}

struct WorkoutStatCard: View {
    var title: String
    var value: String
    var icon: String
    var color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .bold()
                    .foregroundColor(Theme.textSecondary)
            }
            Text(value)
                .font(.headline)
                .bold()
                .foregroundColor(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.background)
        .cornerRadius(16)
    }
}

struct VideoRecorder: UIViewControllerRepresentable {
    @Binding var videoURL: URL?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            picker.mediaTypes = [UTType.movie.identifier]
            picker.videoQuality = .typeMedium
        } else {
            picker.sourceType = .photoLibrary
            picker.mediaTypes = [UTType.movie.identifier]
        }
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: VideoRecorder
        
        init(_ parent: VideoRecorder) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let mediaURL = info[.mediaURL] as? URL {
                parent.videoURL = mediaURL
                // Сохраняем видеозапись в галерею устройства
                if UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(mediaURL.path) {
                    UISaveVideoAtPathToSavedPhotosAlbum(mediaURL.path, nil, nil, nil)
                }
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// Плеер для зацикленного видео упражнений (без звука)
struct WorkoutVideoLoopPlayer: UIViewControllerRepresentable {
    let videoURL: URL
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspectFill
        
        let asset = AVAsset(url: videoURL)
        let playerItem = AVPlayerItem(asset: asset)
        
        let queuePlayer = AVQueuePlayer(playerItem: playerItem)
        let playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)
        
        controller.player = queuePlayer
        
        // Удерживаем looper и player, чтобы ARC их не стерла
        context.coordinator.looper = playerLooper
        context.coordinator.player = queuePlayer
        
        queuePlayer.play()
        queuePlayer.isMuted = true // Гарантируем тишину, чтобы не мешать музыке/радио
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var looper: AVPlayerLooper?
        var player: AVQueuePlayer?
    }
}

// Карточка-иллюстрация с анимацией для домашних/стационарных упражнений
struct WorkoutExerciseCard: View {
    let workoutType: WorkoutsView.WorkoutType
    @State private var scale: CGFloat = 1.0
    @State private var rotate: Double = 0.0
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Пульсирующий неоновый круг на заднем плане
                Circle()
                    .fill(Theme.exerciseColor.opacity(0.15))
                    .frame(width: 120, height: 120)
                    .scaleEffect(scale)
                
                Circle()
                    .stroke(Theme.exerciseColor.opacity(0.3), lineWidth: 2)
                    .frame(width: 100, height: 100)
                    .scaleEffect(scale * 0.9)
                
                // Иконка упражнения по центру
                Image(systemName: workoutType.icon)
                    .font(.system(size: 48))
                    .foregroundColor(Theme.exerciseColor)
                    .neonShadow(color: Theme.exerciseColor, radius: 10)
            }
            .frame(height: 140)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    scale = 1.15
                }
            }
            
            VStack(spacing: 6) {
                Text(workoutType.localizedTitle(lang: "ru"))
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                
                Text(motivationText)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(Theme.cardBackground)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Theme.exerciseColor.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var motivationText: String {
        switch workoutType {
        case .dumbbells:
            return "Сфокусируйтесь на контроле веса и правильной осанке. Не делайте резких движений."
        case .pushups:
            return "Держите тело в одну линию от головы до пят. Опускайтесь плавно."
        case .squats:
            return "Отводите таз назад, держите спину ровной. Напрягайте мышцы бедер."
        case .plank:
            return "Напрягите пресс и ягодицы. Дышите глубоко и ровно."
        case .strength:
            return "Силовая тренировка укрепляет кости и развивает мышечный корсет."
        case .yoga:
            return "Сконцентрируйтесь на дыхании и растяжке. Почувствуйте баланс."
        default:
            return "Держите темп и следите за самочувствием!"
        }
    }
}

