import SwiftUI
import Combine
import WatchConnectivity
import CoreMotion
import HealthKit
import WatchKit

struct WorkoutWatchView: View {
    @ObservedObject var connectivity = WatchConnectivityManager.shared
    @ObservedObject var workoutSession = WatchWorkoutSessionManager.shared
    
    @State private var heartRate: Int = 0
    private let healthStore = HKHealthStore()
    @State private var heartRateQuery: HKQuery? = nil
    
    // Датчики и авто-подсчет повторений
    @State private var motionManager = CMMotionManager()
    @State private var repsCounted = 0
    @State private var isAutoCountEnabled = true
    @State private var hasExceededUpperThreshold = false
    @State private var lastRepTime: TimeInterval = 0
    @State private var accelHistory: [Double] = []
    
    // Состояние автономного режима (Standalone Mode)
    @State private var isStandaloneMode = false
    @State private var localWorkoutActive = false
    @State private var localWorkoutName = ""
    @State private var localElapsedSeconds = 0
    @State private var localCalories = 0.0
    
    private let heartRateTimer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()
    private let secondTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    // Встроенные тренировки для быстрого старта с часов
    let watchPresets = [
        ("Гантели", "dumbbell.fill", Color.green),
        ("Отжимания", "figure.strengthtraining.traditional", Color.orange),
        ("Приседания", "figure.cross.training", Color.blue),
        ("Планка", "figure.core.training", Color.purple),
        ("Бег", "figure.run", Color.red)
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if connectivity.isWorkoutActive || workoutSession.isSessionActive {
                    // ЭКРАН АКТИВНОЙ ТРЕНИРОВКИ НА ЧАСАХ
                    activeWorkoutView
                } else {
                    // ЭКРАН НАСТРОЙКИ / ВЫБОРА ТРЕНИРОВКИ
                    setupWorkoutView
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Forma")
        .onAppear {
            workoutSession.requestAuthorization { _ in }
            manageAccelerometerUpdates()
            requestHeartRateAuthorization()
        }
        .onDisappear {
            stopAccelerometerUpdates()
            stopHeartRateUpdates()
        }
        .onReceive(heartRateTimer) { _ in
            fetchLatestHeartRate()
        }
        .onReceive(secondTimer) { _ in
            if isStandaloneMode && localWorkoutActive && !workoutSession.isSessionActive {
                localElapsedSeconds += 1
                
                // Рассчитываем калории локально как фолбек
                let calorieRate: Double
                switch localWorkoutName {
                case "Бег": calorieRate = 0.16
                case "Ходьба": calorieRate = 0.08
                case "Велоспорт": calorieRate = 0.12
                case "Гантели", "Отжимания", "Приседания": calorieRate = 0.10
                default: calorieRate = 0.08
                }
                localCalories += calorieRate
            }
        }
        .onChange(of: connectivity.currentSet) {
            repsCounted = 0
            hasExceededUpperThreshold = false
            accelHistory.removeAll()
        }
        .onChange(of: connectivity.isWorkoutActive) { _, isActive in
            if !isActive && !workoutSession.isSessionActive {
                localWorkoutActive = false
                isStandaloneMode = false
            }
            manageAccelerometerUpdates()
        }
        .onChange(of: connectivity.isResting) {
            manageAccelerometerUpdates()
        }
        .onChange(of: isAutoCountEnabled) {
            manageAccelerometerUpdates()
        }
    }
    
    // MARK: - Subviews
    
    private var activeWorkoutView: some View {
        VStack(spacing: 10) {
            if connectivity.isResting {
                // ЭКРАН ОТДЫХА НА ЧАСАХ
                VStack(spacing: 8) {
                    Text("ОТДЫХ")
                        .font(.headline)
                        .foregroundColor(.orange)
                    
                    Text("\(connectivity.restSecondsRemaining)")
                        .font(.system(size: 44, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)
                    
                    Text("Приготовьтесь к:")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                    
                    Text(connectivity.currentExerciseName)
                        .font(.footnote.bold())
                        .foregroundColor(.cyan)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    Button(action: {
                        connectivity.sendSkipRestToPhone()
                    }) {
                        Text("Пропустить")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                }
            } else {
                // ЭКРАН АКТИВНОГО УПРАЖНЕНИЯ
                VStack(spacing: 10) {
                    // Заголовок тренировки
                    Text(activeTitle)
                        .font(.headline)
                        .foregroundColor(.green)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    // Таймер и Калории
                    HStack(spacing: 12) {
                        VStack(alignment: .leading) {
                            Text("ВРЕМЯ")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.gray)
                            Text(formatDuration(currentDurationSeconds))
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("АКТИВНОСТЬ")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.gray)
                            Text(String(format: "%.0f ккал", currentCaloriesDisplay))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(.horizontal, 4)
                    
                    // Пульс
                    HStack(spacing: 8) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .font(.title3)
                            .scaleEffect(currentHeartRateDisplay > 0 ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: currentHeartRateDisplay)
                        
                        Text(currentHeartRateDisplay > 0 ? "\(currentHeartRateDisplay) уд/мин" : "-- уд/мин")
                            .font(.body.bold())
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(6)
                    .background(Color.red.opacity(0.15))
                    .cornerRadius(10)
                    
                    // Автоматический подсчет повторений
                    if !connectivity.isTimeBased && !isStandaloneMode && connectivity.reps > 0 {
                        VStack(spacing: 4) {
                            HStack {
                                Text("Повторения:")
                                    .font(.footnote)
                                    .foregroundColor(.gray)
                                Spacer()
                                Text("\(repsCounted) из \(connectivity.reps)")
                                    .font(.body.bold())
                                    .foregroundColor(.cyan)
                            }
                            
                            // Тумблер переключения режима авто-подсчета
                            Button(action: {
                                isAutoCountEnabled.toggle()
                            }) {
                                HStack {
                                    Image(systemName: isAutoCountEnabled ? "waveform.path.ecg" : "hand.tap.fill")
                                    Text(isAutoCountEnabled ? "Авто-подсчет: Вкл" : "Авто-подсчет: Выкл")
                                }
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                            }
                            .frame(height: 24)
                            .background(isAutoCountEnabled ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                            .cornerRadius(8)
                        }
                        .padding(6)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(10)
                    }
                    
                    // Информация о текущем подходе для личных программ
                    if !connectivity.currentExerciseName.isEmpty && !isStandaloneMode {
                        VStack(spacing: 4) {
                            Text("Подход: \(connectivity.currentSet) из \(connectivity.totalSets)")
                                .font(.footnote)
                                .foregroundColor(.gray)
                            
                            Button(action: {
                                connectivity.sendCompleteSetToPhone()
                            }) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Выполнить подход")
                                }
                                .font(.footnote.bold())
                                .foregroundColor(.white)
                            }
                            .background(Color.green)
                            .cornerRadius(12)
                            .padding(.top, 2)
                        }
                        .padding(6)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(12)
                    }
                    
                    // Кнопки управления
                    HStack(spacing: 8) {
                        Button(action: {
                            if isStandaloneMode || !connectivity.isWorkoutActive {
                                if workoutSession.isPaused {
                                    workoutSession.resumeWorkout()
                                } else {
                                    workoutSession.pauseWorkout()
                                }
                            } else {
                                connectivity.sendPauseToPhone()
                            }
                        }) {
                            Image(systemName: (workoutSession.isPaused) ? "play.fill" : "pause.fill")
                                .font(.title3)
                        }
                        .background(Color.orange)
                        .cornerRadius(12)
                        
                        Button(action: {
                            if isStandaloneMode || !connectivity.isWorkoutActive {
                                finishStandaloneWorkout()
                            } else {
                                connectivity.sendFinishToPhone()
                            }
                        }) {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                if isStandaloneMode || !connectivity.isWorkoutActive {
                                    Text("Финиш")
                                        .font(.footnote.bold())
                                }
                            }
                            .foregroundColor(.white)
                        }
                        .background(Color.red)
                        .cornerRadius(12)
                    }
                    .padding(.top, 4)
                }
            }
        }
    }
    
    private var setupWorkoutView: some View {
        VStack(spacing: 8) {
            Text("Готов к тренировке?")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            ForEach(watchPresets, id: \.0) { preset in
                Button(action: {
                    startPresetWorkout(name: preset.0)
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: preset.1)
                            .foregroundColor(preset.2)
                            .frame(width: 24, height: 24)
                        Text(preset.0)
                            .font(.body)
                        Spacer()
                        Image(systemName: "play.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
                .background(Color.white.opacity(0.06))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Helper Properties & Methods
    
    private var activeTitle: String {
        if let name = connectivity.activeWorkoutName, !name.isEmpty {
            return name
        }
        if !connectivity.currentExerciseName.isEmpty {
            return connectivity.currentExerciseName
        }
        if !localWorkoutName.isEmpty {
            return localWorkoutName
        }
        return "Тренировка"
    }
    
    private var currentDurationSeconds: Int {
        if isStandaloneMode || !connectivity.isWorkoutActive {
            return workoutSession.elapsedSeconds > 0 ? workoutSession.elapsedSeconds : localElapsedSeconds
        }
        return connectivity.elapsedSeconds
    }
    
    private var currentCaloriesDisplay: Double {
        if isStandaloneMode || !connectivity.isWorkoutActive {
            return workoutSession.activeCalories > 0 ? workoutSession.activeCalories : localCalories
        }
        return connectivity.calories
    }
    
    private func startPresetWorkout(name: String) {
        WKInterfaceDevice.current().play(.start)
        workoutSession.startWorkout(name: name)
        
        if WCSession.default.isReachable {
            // Связанный режим с телефоном
            isStandaloneMode = false
            let message = ["action": "start_preset", "type": name]
            connectivity.activeWorkoutName = name
            connectivity.isWorkoutActive = true
            WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: nil)
        } else {
            // Полностью автономный режим (Standalone)
            isStandaloneMode = true
            localWorkoutActive = true
            localWorkoutName = name
            localElapsedSeconds = 0
            localCalories = 0.0
            
            connectivity.isWorkoutActive = true
            connectivity.activeWorkoutName = name
            connectivity.currentExerciseName = name
            connectivity.isTimeBased = false
            connectivity.reps = 0
        }
    }
    
    private func finishStandaloneWorkout() {
        let name = localWorkoutName.isEmpty ? (connectivity.activeWorkoutName ?? "Тренировка") : localWorkoutName
        let now = Date()
        
        localWorkoutActive = false
        connectivity.isWorkoutActive = false
        connectivity.activeWorkoutName = nil
        
        WKInterfaceDevice.current().play(.success)
        
        workoutSession.endWorkout { hkWorkout, finalCalories, finalDuration in
            let duration = finalDuration > 0 ? finalDuration : self.localElapsedSeconds
            let calories = finalCalories > 0 ? finalCalories : self.localCalories
            let start = now.addingTimeInterval(-Double(max(1, duration)))
            
            // 1. Гарантированная передача на телефон через WatchConnectivity
            self.connectivity.sendStandaloneWorkoutToPhone(
                name: name,
                durationSeconds: duration,
                calories: calories,
                startDate: start,
                endDate: now
            )
            
            print("[Watch] Тренировка сохранена на часах и передана на телефон: \(name), \(duration) сек, \(calories) ккал")
        }
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }
    
    // MARK: - CoreMotion Accelerometer Count
    
    private func manageAccelerometerUpdates() {
        let shouldBeActive = (connectivity.isWorkoutActive || workoutSession.isSessionActive) &&
                             !connectivity.isTimeBased &&
                             !connectivity.isResting &&
                             isAutoCountEnabled
        
        if shouldBeActive {
            startAccelerometerUpdates()
        } else {
            stopAccelerometerUpdates()
        }
    }
    
    private func startAccelerometerUpdates() {
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = 0.1
        motionManager.startAccelerometerUpdates(to: .main) { data, error in
            guard let data = data, error == nil else { return }
            processAccelerometerData(data.acceleration)
        }
    }
    
    private func stopAccelerometerUpdates() {
        motionManager.stopAccelerometerUpdates()
        accelHistory.removeAll()
        hasExceededUpperThreshold = false
    }
    
    private func processAccelerometerData(_ acceleration: CMAcceleration) {
        let magnitude = sqrt(acceleration.x * acceleration.x + acceleration.y * acceleration.y + acceleration.z * acceleration.z)
        
        // Скользящее среднее на 5 элементов для фильтрации
        accelHistory.append(magnitude)
        if accelHistory.count > 5 {
            accelHistory.removeFirst()
        }
        let smoothAccel = accelHistory.reduce(0, +) / Double(accelHistory.count)
        
        let currentTime = Date().timeIntervalSince1970
        
        // Анализ пиков: движение вверх (превышение порога) -> движение вниз
        if !hasExceededUpperThreshold {
            if smoothAccel > 1.22 { // Порог импульса движения
                hasExceededUpperThreshold = true
            }
        } else {
            if smoothAccel < 0.82 { // Порог завершения фазы движения
                if currentTime - lastRepTime > 1.0 { // Дебаунс 1 секунда
                    repsCounted += 1
                    lastRepTime = currentTime
                    
                    // Мягкий щелчок на руке
                    WKInterfaceDevice.current().play(.click)
                    
                    // Проверка достижения цели подходам
                    let targetReps = connectivity.reps
                    if targetReps > 0 && repsCounted >= targetReps {
                        WKInterfaceDevice.current().play(.success)
                        connectivity.sendCompleteSetToPhone()
                        repsCounted = 0
                    }
                }
                hasExceededUpperThreshold = false
            }
        }
    }
    
    // MARK: - Реальное считывание пульса с оптического датчика Apple Watch
    
    private var currentHeartRateDisplay: Int {
        if workoutSession.currentHeartRate > 0 {
            return workoutSession.currentHeartRate
        }
        if heartRate > 0 {
            return heartRate
        }
        if connectivity.heartRate > 0 {
            return connectivity.heartRate
        }
        return 0
    }
    
    private func requestHeartRateAuthorization() {
        guard HKHealthStore.isHealthDataAvailable(),
              let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        
        healthStore.requestAuthorization(toShare: nil, read: [hrType]) { success, _ in
            if success {
                DispatchQueue.main.async {
                    self.startRealHeartRateQuery()
                }
            }
        }
    }
    
    private func startRealHeartRateQuery() {
        guard HKHealthStore.isHealthDataAvailable(),
              let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        
        fetchLatestHeartRate()
        stopHeartRateUpdates()
        
        let query = HKAnchoredObjectQuery(
            type: hrType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { _, samples, _, _, _ in
            self.processHeartRateSamples(samples)
        }
        
        query.updateHandler = { _, samples, _, _, _ in
            self.processHeartRateSamples(samples)
        }
        
        self.heartRateQuery = query
        healthStore.execute(query)
    }
    
    private func stopHeartRateUpdates() {
        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
        }
    }
    
    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let quantitySamples = samples as? [HKQuantitySample], let last = quantitySamples.last else { return }
        let bpm = last.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        DispatchQueue.main.async {
            if bpm >= 35 && bpm <= 230 {
                let intBpm = Int(bpm)
                self.heartRate = intBpm
                self.connectivity.sendHeartRateToPhone(intBpm)
            }
        }
    }
    
    private func fetchLatestHeartRate() {
        guard HKHealthStore.isHealthDataAvailable(),
              let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: hrType, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
            if let sample = samples?.first as? HKQuantitySample {
                let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                DispatchQueue.main.async {
                    if bpm >= 35 && bpm <= 230 {
                        let intBpm = Int(bpm)
                        self.heartRate = intBpm
                        self.connectivity.sendHeartRateToPhone(intBpm)
                    }
                }
            }
        }
        healthStore.execute(query)
    }
}
