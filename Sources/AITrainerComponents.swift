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
    
    @State private var isAnimating = false
    @State private var isBlinking = false
    
    public enum CoachState: String {
        case idle
        case exercising
        case resting
        case cheering
    }
    
    public init(coachState: CoachState = .idle) {
        self.coachState = coachState
    }
    
    public var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Theme.exerciseColor.opacity(0.12),
                            Theme.standColor.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 80)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Theme.exerciseColor.opacity(0.3),
                                    Theme.standColor.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Theme.exerciseColor.opacity(0.15), radius: 5)
            
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    Circle()
                        .fill(Color(red: 255/255, green: 220/255, blue: 185/255))
                        .frame(width: 24, height: 24)
                    
                    Path { path in
                        path.addArc(center: CGPoint(x: 12, y: 10), radius: 12, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                    }
                    .fill(Theme.moveColor)
                    .frame(width: 24, height: 24)
                    .offset(y: -4)
                    
                    Capsule()
                        .fill(Theme.moveColor)
                        .frame(width: 14, height: 4)
                        .offset(x: 6, y: 1)
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isBlinking ? Color.clear : Color.black.opacity(0.8))
                            .frame(width: 3, height: 3)
                        Circle()
                            .fill(isBlinking ? Color.clear : Color.black.opacity(0.8))
                            .frame(width: 3, height: 3)
                    }
                    .offset(x: 2, y: 8)
                    
                    if coachState == .resting {
                        Circle()
                            .stroke(Color.black.opacity(0.8), lineWidth: 1.2)
                            .frame(width: 4, height: 4)
                            .offset(x: 2, y: 14)
                    } else {
                        Path { path in
                            path.addArc(center: CGPoint(x: 13, y: 13), radius: 3, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
                        }
                        .stroke(Color.black.opacity(0.8), lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                    }
                }
                .offset(y: coachState == .resting ? (isAnimating ? 1.5 : -0.5) : (coachState == .cheering ? (isAnimating ? -4 : 0) : 0))
                
                Rectangle()
                    .fill(Color(red: 255/255, green: 210/255, blue: 175/255))
                    .frame(width: 6, height: 4)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [Theme.moveColor, Theme.moveColor.opacity(0.85)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 24, height: 26)
                    
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.yellow)
                }
                .offset(y: coachState == .resting ? (isAnimating ? 1 : 0) : (coachState == .cheering ? (isAnimating ? -3 : 0) : 0))
            }
            .offset(y: -4)
            
            Capsule()
                .fill(Color(red: 255/255, green: 220/255, blue: 185/255))
                .frame(width: 5, height: 14)
                .rotationEffect(
                    .degrees(
                        coachState == .cheering ? (isAnimating ? 135 : 120) :
                        (coachState == .idle ? (isAnimating ? 135 : 45) : -15)
                    ),
                    anchor: .top
                )
                .offset(x: -14, y: 10 + (coachState == .cheering && isAnimating ? -3 : 0))
            
            ZStack(alignment: .bottomTrailing) {
                Capsule()
                    .fill(Color(red: 255/255, green: 220/255, blue: 185/255))
                    .frame(width: 5, height: 14)
                    .rotationEffect(
                        .degrees(
                            coachState == .cheering ? (isAnimating ? -135 : -120) :
                            (coachState == .exercising ? (isAnimating ? -120 : -45) : 15)
                        ),
                        anchor: .top
                    )
                
                if coachState == .exercising || coachState == .idle {
                    HStack(spacing: 0.5) {
                        Rectangle()
                            .fill(Color.gray)
                            .frame(width: 3, height: 5)
                        Rectangle()
                            .fill(Color.black)
                            .frame(width: 5, height: 2)
                        Rectangle()
                            .fill(Color.gray)
                            .frame(width: 3, height: 5)
                    }
                    .rotationEffect(
                        .degrees(
                            coachState == .exercising ? (isAnimating ? -120 : -45) : 15
                        )
                    )
                    .offset(
                        x: coachState == .exercising ? (isAnimating ? 8 : 12) : 10,
                        y: coachState == .exercising ? (isAnimating ? -2 : 4) : 6
                    )
                }
            }
            .offset(x: 14, y: 10 + (coachState == .cheering && isAnimating ? -3 : 0))
            
            HStack(spacing: 8) {
                Capsule()
                    .fill(Theme.textPrimary)
                    .frame(width: 5, height: 12)
                    .offset(y: coachState == .cheering && isAnimating ? -4 : 0)
                Capsule()
                    .fill(Theme.textPrimary)
                    .frame(width: 5, height: 12)
                    .offset(y: coachState == .cheering && isAnimating ? -4 : 0)
            }
            .offset(y: 30)
        }
        .onAppear {
            setupAnimations()
        }
    }
    
    private func setupAnimations() {
        Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
            withAnimation(.linear(duration: 0.15)) {
                isBlinking = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.linear(duration: 0.15)) {
                    isBlinking = false
                }
            }
        }
        
        switch coachState {
        case .idle:
            withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        case .exercising:
            withAnimation(Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        case .resting:
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        case .cheering:
            withAnimation(Animation.spring(response: 0.4, dampingFraction: 0.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

public struct AITrainerCoachRow: View {
    public let message: String
    public let coachState: AITrainerAvatarView.CoachState
    
    public init(message: String, coachState: AITrainerAvatarView.CoachState) {
        self.message = message
        self.coachState = coachState
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            AITrainerAvatarView(coachState: coachState)
                .frame(width: 80, height: 80)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizationManager.tr("ai_coach_name", lang: UserDefaults.standard.string(forKey: "app_language") ?? "ru"))
                    .font(.caption2)
                    .bold()
                    .foregroundColor(Theme.exerciseColor)
                
                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(4)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Theme.cardBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.exerciseColor.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.02), radius: 5, x: 0, y: 3)
        }
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
