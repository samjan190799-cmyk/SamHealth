import SwiftUI

public struct CustomExercise: Codable, Identifiable, Hashable {
    public var id: UUID
    public var name: String
    public var sets: Int
    public var reps: Int
    public var durationSeconds: Int
    public var weightKg: Double
    public var restSeconds: Int
    public var isTimeBased: Bool
    
    public init(id: UUID = UUID(), name: String, sets: Int, reps: Int, durationSeconds: Int = 0, weightKg: Double = 0.0, restSeconds: Int = 30, isTimeBased: Bool = false) {
        self.id = id
        self.name = name
        self.sets = sets
        self.reps = reps
        self.durationSeconds = durationSeconds
        self.weightKg = weightKg
        self.restSeconds = restSeconds
        self.isTimeBased = isTimeBased
    }
}

public struct CustomWorkout: Codable, Identifiable, Hashable {
    public var id: UUID
    public var name: String
    public var exercises: [CustomExercise]
    
    public init(id: UUID = UUID(), name: String, exercises: [CustomExercise] = []) {
        self.id = id
        self.name = name
        self.exercises = exercises
    }
}

public class CustomWorkoutStore: ObservableObject {
    @Published public var workouts: [CustomWorkout] = []
    
    public init() {
        loadWorkouts()
    }
    
    public func loadWorkouts() {
        if let data = UserDefaults.standard.data(forKey: "custom_workouts"),
           let decoded = try? JSONDecoder().decode([CustomWorkout].self, from: data) {
            self.workouts = decoded
        } else {
            // Демо-тренировки по умолчанию
            self.workouts = [
                CustomWorkout(name: "Быстрая разминка", exercises: [
                    CustomExercise(name: "Приседания", sets: 3, reps: 15, durationSeconds: 0, weightKg: 0.0, restSeconds: 20, isTimeBased: false),
                    CustomExercise(name: "Отжимания", sets: 3, reps: 12, durationSeconds: 0, weightKg: 0.0, restSeconds: 20, isTimeBased: false),
                    CustomExercise(name: "Планка", sets: 2, reps: 0, durationSeconds: 30, weightKg: 0.0, restSeconds: 30, isTimeBased: true)
                ]),
                CustomWorkout(name: "Сила с гантелями", exercises: [
                    CustomExercise(name: "Приседания с гантелями", sets: 4, reps: 12, durationSeconds: 0, weightKg: 12.0, restSeconds: 45, isTimeBased: false),
                    CustomExercise(name: "Жим гантелей стоя", sets: 3, reps: 10, durationSeconds: 0, weightKg: 8.0, restSeconds: 45, isTimeBased: false),
                    CustomExercise(name: "Подъем на бицепс", sets: 3, reps: 12, durationSeconds: 0, weightKg: 6.0, restSeconds: 30, isTimeBased: false)
                ])
            ]
            saveWorkouts()
        }
    }
    
    public func saveWorkouts() {
        if let encoded = try? JSONEncoder().encode(workouts) {
            UserDefaults.standard.set(encoded, forKey: "custom_workouts")
        }
    }
    
    public func addWorkout(_ workout: CustomWorkout) {
        workouts.append(workout)
        saveWorkouts()
    }
    
    public func deleteWorkout(at offsets: IndexSet) {
        workouts.remove(atOffsets: offsets)
        saveWorkouts()
    }
}

public struct AITrainerAvatarView: View {
    public var coachState: CoachState
    public var size: CGFloat
    public var customCoach: AICoachPersona?
    
    @ObservedObject private var coachManager = AICoachManager.shared
    
    @State private var isPulsing = false
    @State private var auraRotation: Double = 0
    
    public enum CoachState: String {
        case idle
        case exercising
        case resting
        case cheering
    }
    
    public init(coachState: CoachState = .idle, size: CGFloat = 80, customCoach: AICoachPersona? = nil) {
        self.coachState = coachState
        self.size = size
        self.customCoach = customCoach
    }
    
    private var activeCoach: AICoachPersona {
        customCoach ?? coachManager.currentCoach
    }
    
    private var stateGradients: [Color] {
        let accent = activeCoach.accentColor
        switch coachState {
        case .idle:
            return [accent, Theme.standColor, Color(red: 168/255, green: 85/255, blue: 247/255)]
        case .exercising:
            return [accent, Color(red: 255/255, green: 204/255, blue: 0/255), Theme.moveColor]
        case .resting:
            return [Theme.standColor, Theme.sleepColor, Color(red: 147/255, green: 197/255, blue: 253/255)]
        case .cheering:
            return [Theme.moveColor, Color(red: 255/255, green: 149/255, blue: 0/255), accent]
        }
    }
    
    public var body: some View {
        ZStack {
            // 1. Внешняя пульсирующая аура (Liquid Glow)
            Circle()
                .fill(
                    AngularGradient(
                        colors: stateGradients + [stateGradients.first ?? Theme.exerciseColor],
                        center: .center
                    )
                )
                .frame(width: size * 1.15, height: size * 1.15)
                .rotationEffect(.degrees(auraRotation))
                .blur(radius: size * 0.14)
                .opacity(isPulsing ? 0.75 : 0.4)
                .scaleEffect(isPulsing ? 1.06 : 0.98)
            
            // 2. Вращающийся контур энергии Apple Intelligence
            Circle()
                .stroke(
                    AngularGradient(
                        colors: stateGradients + [stateGradients.first ?? Theme.exerciseColor],
                        center: .center
                    ),
                    lineWidth: max(2, size * 0.04)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-auraRotation * 1.2))
            
            // 3. Человеческий фото-аватар выбранного тренера
            Image(activeCoach.avatarAssetName)
                .resizable()
                .scaledToFill()
                .frame(width: size * 0.88, height: size * 0.88)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
            
            // 4. Онлайн / Статус бейдж
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Theme.cardBackground)
                            .frame(width: size * 0.28, height: size * 0.28)
                        
                        Circle()
                            .fill(activeCoach.accentColor)
                            .frame(width: size * 0.20, height: size * 0.20)
                            .shadow(color: activeCoach.accentColor.opacity(0.8), radius: 4)
                        
                        if coachState == .exercising {
                            Image(systemName: "flame.fill")
                                .font(.system(size: size * 0.12))
                                .foregroundColor(.white)
                        }
                    }
                    .offset(x: size * 0.02, y: size * 0.02)
                }
            }
            .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(Animation.linear(duration: 6.0).repeatForever(autoreverses: false)) {
                auraRotation = 360
            }
            withAnimation(Animation.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

public struct AITrainerCoachRow: View {
    public let message: String
    public let coachState: AITrainerAvatarView.CoachState
    public var customCoach: AICoachPersona?
    public var onTap: (() -> Void)? = nil
    
    @ObservedObject private var coachManager = AICoachManager.shared
    
    public init(message: String, coachState: AITrainerAvatarView.CoachState, customCoach: AICoachPersona? = nil, onTap: (() -> Void)? = nil) {
        self.message = message
        self.coachState = coachState
        self.customCoach = customCoach
        self.onTap = onTap
    }
    
    private var activeCoach: AICoachPersona {
        customCoach ?? coachManager.currentCoach
    }
    
    public var body: some View {
        Button(action: {
            if let onTap {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onTap()
            }
        }) {
            HStack(spacing: 12) {
                AITrainerAvatarView(coachState: coachState, size: 68, customCoach: activeCoach)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Тренер \(activeCoach.name)")
                            .font(.caption)
                            .bold()
                            .foregroundColor(activeCoach.accentColor)
                        
                        Spacer()
                        
                        HStack(spacing: 3) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                            Text("Спросить")
                        }
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(activeCoach.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(activeCoach.accentColor.opacity(0.12))
                        .cornerRadius(10)
                    }
                    
                    Text(message)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Theme.cardBackground)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(activeCoach.accentColor.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

public struct CustomWorkoutCreatorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: CustomWorkoutStore
    
    @State private var workoutName = ""
    @State private var exercises: [CustomExercise] = []
    
    @State private var newExerciseName = "Приседания"
    @State private var newExerciseSets = 3
    @State private var newExerciseReps = 12
    @State private var newExerciseDuration = 30
    @State private var newExerciseWeight = 0.0
    @State private var newExerciseRest = 30
    @State private var newExerciseIsTimeBased = false
    
    @State private var showingAddExerciseForm = false
    
    let suggestedExercises = [
        "Приседания", "Отжимания", "Планка", "Жим гантелей стоя",
        "Подъем на бицепс", "Махи гантелями", "Выпады", "Скручивания",
        "Берпи", "Тяга гантелей в наклоне"
    ]
    
    @AppStorage("app_language") private var appLanguage = "ru"
    
    private func tr(_ key: String) -> String {
        LocalizationManager.tr(key, lang: appLanguage)
    }
    
    public init(store: CustomWorkoutStore) {
        self.store = store
    }
    
    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text(tr("custom_workout_info"))) {
                    TextField(tr("custom_workout_name_placeholder"), text: $workoutName)
                        .font(.body)
                }
                
                Section(header: Text(tr("custom_workout_exercises"))) {
                    if exercises.isEmpty {
                        Text(tr("custom_workout_no_exercises"))
                            .foregroundColor(.gray)
                            .font(.caption)
                    } else {
                        ForEach(exercises) { ex in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(ex.name)
                                        .font(.headline)
                                        .foregroundColor(Theme.textPrimary)
                                    HStack(spacing: 8) {
                                        Text("\(tr("custom_workout_sets")): \(ex.sets)")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        if ex.isTimeBased {
                                            Text("\(tr("custom_workout_duration")): \(ex.durationSeconds) \(tr("sec"))")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        } else {
                                            Text("\(tr("custom_workout_reps")): \(ex.reps)")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                        if ex.weightKg > 0 {
                                            Text("\(tr("custom_workout_weight")): \(String(format: "%.1f", ex.weightKg)) \(tr("kg"))")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    Text("\(tr("custom_workout_rest")): \(ex.restSeconds) \(tr("sec"))")
                                        .font(.caption2)
                                        .foregroundColor(Theme.exerciseColor)
                                }
                                Spacer()
                            }
                        }
                        .onDelete { indexSet in
                            exercises.remove(atOffsets: indexSet)
                        }
                    }
                    
                    Button(action: {
                        showingAddExerciseForm = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text(tr("custom_workout_add_exercise"))
                        }
                        .foregroundColor(Theme.exerciseColor)
                    }
                }
            }
            .navigationTitle(tr("custom_workout_create_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(tr("cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(tr("save")) {
                        saveWorkout()
                    }
                    .disabled(workoutName.trimmingCharacters(in: .whitespaces).isEmpty || exercises.isEmpty)
                }
            }
            .sheet(isPresented: $showingAddExerciseForm) {
                addExerciseSheet
            }
        }
    }
    
    private var addExerciseSheet: some View {
        NavigationView {
            Form {
                Section(header: Text(tr("custom_workout_exercise_select"))) {
                    Picker(tr("custom_workout_exercise_name"), selection: $newExerciseName) {
                        ForEach(suggestedExercises, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    
                    HStack {
                        Text(tr("custom_workout_custom_name"))
                        TextField(tr("custom_workout_custom_name_placeholder"), text: $newExerciseName)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section(header: Text(tr("custom_workout_exercise_settings"))) {
                    Stepper("\(tr("custom_workout_sets")): \(newExerciseSets)", value: $newExerciseSets, in: 1...10)
                    
                    Toggle(tr("custom_workout_time_based"), isOn: $newExerciseIsTimeBased)
                    
                    if newExerciseIsTimeBased {
                        Stepper("\(tr("custom_workout_duration")): \(newExerciseDuration) \(tr("sec"))", value: $newExerciseDuration, in: 5...300, step: 5)
                    } else {
                        Stepper("\(tr("custom_workout_reps")): \(newExerciseReps)", value: $newExerciseReps, in: 1...100)
                    }
                    
                    HStack {
                        Text(tr("custom_workout_weight_kg"))
                        Spacer()
                        TextField("0.0", value: $newExerciseWeight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text(tr("kg"))
                    }
                    
                    Stepper("\(tr("custom_workout_rest")): \(newExerciseRest) \(tr("sec"))", value: $newExerciseRest, in: 5...180, step: 5)
                }
            }
            .navigationTitle(tr("custom_workout_add_exercise_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(tr("cancel")) {
                        showingAddExerciseForm = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(tr("add")) {
                        let exercise = CustomExercise(
                            name: newExerciseName,
                            sets: newExerciseSets,
                            reps: newExerciseReps,
                            durationSeconds: newExerciseDuration,
                            weightKg: newExerciseWeight,
                            restSeconds: newExerciseRest,
                            isTimeBased: newExerciseIsTimeBased
                        )
                        exercises.append(exercise)
                        showingAddExerciseForm = false
                        newExerciseName = suggestedExercises.first ?? ""
                        newExerciseSets = 3
                        newExerciseReps = 12
                        newExerciseDuration = 30
                        newExerciseWeight = 0.0
                        newExerciseRest = 30
                        newExerciseIsTimeBased = false
                    }
                }
            }
        }
    }
    
    private func saveWorkout() {
        let workout = CustomWorkout(name: workoutName, exercises: exercises)
        store.addWorkout(workout)
        dismiss()
    }
}
