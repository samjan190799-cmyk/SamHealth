import SwiftUI
import UniformTypeIdentifiers

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
                    
                    Button(action: {
                        tracker.startTracking()
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
                    .padding(.top, 16)
                    
                    // Карточка ИИ-анализа тренировок
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .foregroundColor(.yellow)
                                .font(.title3)
                            Text(tr("workouts_ai_title"))
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
                            if let analysis = workoutsAnalysisResult {
                                ScrollView {
                                    Text(analysis)
                                        .font(.subheadline)
                                        .foregroundColor(Theme.textPrimary.opacity(0.9))
                                        .lineSpacing(4)
                                        .multilineTextAlignment(.leading)
                                        .padding(12)
                                }
                                .frame(maxHeight: 180)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(16)
                            } else if let error = workoutsAnalysisError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(Theme.pulseColor)
                                    .padding()
                                    .background(Theme.pulseColor.opacity(0.08))
                                    .cornerRadius(16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                Text(tr("workouts_ai_desc"))
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                                    .padding(.vertical, 4)
                            }
                            
                            Button(action: {
                                runWorkoutsAnalysis()
                            }) {
                                HStack {
                                    if isAnalyzingWorkouts {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .padding(.trailing, 8)
                                    }
                                    Text(isAnalyzingWorkouts ? tr("nutrition_analyzing") : tr("workouts_analyze_btn"))
                                        .bold()
                                }
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.white)
                                .padding()
                                .background(isAnalyzingWorkouts ? Theme.exerciseColor.opacity(0.6) : Theme.exerciseColor)
                                .cornerRadius(16)
                                .shadow(color: Theme.exerciseColor.opacity(0.3), radius: 8)
                            }
                            .disabled(isAnalyzingWorkouts)
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
                        
                        // Индикатор автопаузы на основе движения
                        HStack(spacing: 6) {
                            Circle()
                                .fill(selectedWorkoutType.isStationaryFriendly ? Color.green : (tracker.isStationary ? Color.orange : Color.green))
                                .frame(width: 8, height: 8)
                            Text(selectedWorkoutType.isStationaryFriendly ? tr("workouts_active") : (tracker.isStationary ? tr("workouts_autopause") : tr("workouts_active")))
                                .font(.footnote)
                                .foregroundColor(selectedWorkoutType.isStationaryFriendly ? .green : (tracker.isStationary ? .orange : .green))
                                .bold()
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 12)
                        .background(selectedWorkoutType.isStationaryFriendly ? Color.green.opacity(0.1) : (tracker.isStationary ? Color.orange.opacity(0.1) : Color.green.opacity(0.1)))
                        .cornerRadius(12)
                        
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
                            .padding()
                        }
                        
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
                        
                        Button(action: {
                            finishWorkout()
                        }) {
                            Text(tr("workouts_finish"))
                               .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Theme.moveColor)
                                .cornerRadius(16)
                                .shadow(color: Theme.moveColor.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
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
