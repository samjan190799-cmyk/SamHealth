import SwiftUI
import UniformTypeIdentifiers
import MapKit

struct WorkoutsView: View {
    @EnvironmentObject var health: HealthKitManager
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
            case .jumpRope: return "figure.jump.rope"
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
            }
        }
        
        var isStationaryFriendly: Bool {
            switch self {
            case .strength, .yoga:
                return true
            default:
                return false
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                HStack {
                    Text(tr("workouts_title"))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 12)
                
                if !tracker.isTracking {
                    // Экран настроек перед началом
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
                                        .foregroundColor(selectedWorkoutType == type ? .white : Theme.textPrimary)
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
                    
                    // Музыкальный виджет перед началом тренировки
                    WorkoutMusicPlayerWidget()
                        .padding(.horizontal)
                    
                    Button(action: {
                        let isGPS = selectedWorkoutType == .running || selectedWorkoutType == .walking || selectedWorkoutType == .cycling
                        tracker.startTracking(gpsTrackingEnabled: isGPS)
                    }) {
                        Text(tr("workouts_start"))
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.textPrimary)
                            .cornerRadius(16)
                            .shadow(color: Theme.textPrimary.opacity(0.15), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // 3. КАРТОЧКА ПЕРСОНАЛЬНОГО ПЛАНА ТРЕНИРОВКИ ОТ ИИ
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .foregroundColor(.yellow)
                                .font(.title3)
                            Text("Индивидуальный ИИ-план тренировок")
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
                                Text("Нажмите кнопку ниже, чтобы ИИ-Тренер составил программу тренировок на основе ваших физических параметров (возраст, рост, вес).")
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
                                    Text(isGeneratingWorkoutPlan ? "Планирую тренировку..." : "Составить план тренировки")
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
                } else {
                    // Экран активной тренировки
                    VStack(spacing: 24) {
                        Text(selectedWorkoutType.localizedTitle(lang: appLanguage))
                            .font(.title3)
                            .foregroundColor(Theme.textSecondary)
                            .bold()
                        
                        Text(formatDuration(tracker.elapsedSeconds))
                            .font(.system(size: 54, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.textPrimary)
                        
                        // Индикатор автопаузы / активна / ручная пауза
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
                        
                        // Карта Apple Maps для уличных тренировок
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
                        
                        // Музыкальный плеер во время тренировки
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
                        
                        // Управление активностью: Пауза/Продолжить и Завершить
                        HStack(spacing: 16) {
                            Button(action: {
                                if tracker.isPaused {
                                    tracker.resumeTracking()
                                } else {
                                    tracker.pauseTracking()
                                }
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
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarHidden(true)
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
        }
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
                    workouts: health.workoutHistory
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
                    activityLevel: userActivityLevel
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
                    Text("Radio").tag(MusicSource.radio)
                    Text("Music").tag(MusicSource.appleMusic)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 140)
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
                    Text(musicManager.currentTrackTitle)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                    
                    Text(musicManager.currentArtist)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
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
    }
}
