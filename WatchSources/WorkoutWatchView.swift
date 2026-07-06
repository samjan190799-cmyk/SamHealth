import SwiftUI
import HealthKit
import Combine
import WatchConnectivity


struct WorkoutWatchView: View {
    @ObservedObject var connectivity = WatchConnectivityManager.shared
    
    @State private var heartRate: Int = 0
    @State private var healthStore = HKHealthStore()
    
    private let heartRateTimer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()
    
    // Встроенные тренировки для быстрого старта с часов
    let watchPresets = [
        ("Гантели", "dumbbell.fill", Color.green),
        ("Отжимания", "figure.strengthtraining.traditional", Color.orange),
        ("Приседания", "figure.squat", Color.blue),
        ("Планка", "figure.core.training", Color.purple),
        ("Бег", "figure.run", Color.red)
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if connectivity.isWorkoutActive {
                    // ЭКРАН АКТИВНОЙ ТРЕНИРОВКИ НА ЧАСАХ
                    activeWorkoutView
                } else {
                    // ЭКРАН НАСТРОЙКИ / ВЫБОРА ТРЕНИРОВКИ
                    setupWorkoutView
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("SamHealth")
        .onAppear {
            requestHealthKitAuthorization()
        }
        .onReceive(heartRateTimer) { _ in
            if connectivity.isWorkoutActive {
                heartRate = Int.random(in: 115...148)
            } else {
                heartRate = Int.random(in: 68...82)
            }
        }
    }
    
    // MARK: - Subviews
    
    private var activeWorkoutView: some View {
        VStack(spacing: 10) {
            // Заголовок тренировки
            Text(connectivity.activeWorkoutName ?? connectivity.currentExerciseName)
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
                    Text(formatDuration(connectivity.elapsedSeconds))
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("АКТИВНОСТЬ")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                    Text(String(format: "%.0f ккал", connectivity.calories))
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
                    .scaleEffect(heartRate > 0 ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: heartRate)
                
                Text(heartRate > 0 ? "\(heartRate) уд/мин" : "-- уд/мин")
                    .font(.body.bold())
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(8)
            .background(Color.red.opacity(0.15))
            .cornerRadius(10)
            
            // Информация о текущем упражнении для личных программ
            if !connectivity.currentExerciseName.isEmpty {
                VStack(spacing: 4) {
                    Text(connectivity.currentExerciseName)
                        .font(.subheadline.bold())
                        .foregroundColor(.cyan)
                        .multilineTextAlignment(.center)
                    
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
                    .padding(.top, 4)
                }
                .padding(8)
                .background(Color.white.opacity(0.06))
                .cornerRadius(12)
            }
            
            // Кнопки управления
            HStack(spacing: 8) {
                Button(action: {
                    connectivity.sendPauseToPhone()
                }) {
                    Image(systemName: "pause.fill")
                        .font(.title3)
                }
                .background(Color.orange)
                .cornerRadius(12)
                
                Button(action: {
                    connectivity.sendFinishToPhone()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                }
                .background(Color.red)
                .cornerRadius(12)
            }
            .padding(.top, 6)
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
    
    // MARK: - Helper Methods
    
    private func startPresetWorkout(name: String) {
        // Отправляем команду запуска тренировки на телефон
        let message = ["action": "start_preset", "type": name]
        WatchConnectivityManager.shared.activeWorkoutName = name
        WatchConnectivityManager.shared.isWorkoutActive = true
        WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: nil)
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
    
    private func requestHealthKitAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let hrType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        healthStore.requestAuthorization(toShare: [], read: [hrType]) { _, _ in }
    }
}
