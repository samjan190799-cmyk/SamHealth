import SwiftUI
import HealthKit

struct WorkoutsView: View {
    @EnvironmentObject var health: HealthKitManager
    @StateObject private var tracker = WorkoutTracker()
    @State private var selectedWorkoutType: WorkoutType = .running
    @State private var showingSummary = false
    @State private var lastSummaryCalories = 0.0
    @State private var lastSummaryDistance = 0.0
    
    enum WorkoutType: String, CaseIterable, Identifiable {
        case running = "Бег"
        case walking = "Ходьба"
        case cycling = "Велоспорт"
        
        var id: String { self.rawValue }
        var icon: String {
            switch self {
            case .running: return "figure.run"
            case .walking: return "figure.walk"
            case .cycling: return "figure.outdoor.cycle"
            }
        }
        
        var met: Double {
            switch self {
            case .running: return 8.0
            case .walking: return 3.5
            case .cycling: return 6.0
            }
        }
        
        var hkType: HKWorkoutActivityType {
            switch self {
            case .running: return .running
            case .walking: return .walking
            case .cycling: return .cycling
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                HStack {
                    Text("Тренировки")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                if !tracker.isTracking {
                    // Экран настроек перед началом
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Выберите активность")
                            .font(.headline)
                            .foregroundColor(Theme.textSecondary)
                        
                        ForEach(WorkoutType.allCases) { type in
                            Button(action: {
                                selectedWorkoutType = type
                            }) {
                                HStack(spacing: 16) {
                                    Image(systemName: type.icon)
                                        .font(.title2)
                                        .foregroundColor(selectedWorkoutType == type ? .black : .white)
                                        .frame(width: 44, height: 44)
                                        .background(selectedWorkoutType == type ? Color.white : Theme.cardBackground)
                                        .clipShape(Circle())
                                    
                                    Text(type.rawValue)
                                        .font(.body)
                                        .foregroundColor(.white)
                                        .bold()
                                    
                                    Spacer()
                                    
                                    if selectedWorkoutType == type {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding()
                                .background(selectedWorkoutType == type ? Color.white.opacity(0.15) : Theme.cardBackground)
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Button(action: {
                        tracker.startTracking()
                    }) {
                        Text("Начать тренировку")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.white.opacity(0.2), radius: 8)
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                } else {
                    // Экран активной тренировки
                    VStack(spacing: 24) {
                        Text(selectedWorkoutType.rawValue)
                            .font(.title2)
                            .foregroundColor(Theme.textSecondary)
                            .bold()
                        
                        Text(formatDuration(tracker.elapsedSeconds))
                            .font(.system(size: 64, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        
                        HStack(spacing: 24) {
                            WorkoutStatCard(
                                title: "Расстояние",
                                value: String(format: "%.2f км", tracker.distance / 1000.0),
                                icon: "arrow.triangle.pull"
                            )
                            WorkoutStatCard(
                                title: "Калории (оценка)",
                                value: String(format: "%.0f ккал", estimateCalories()),
                                icon: "flame.fill"
                            )
                        }
                        
                        if tracker.steps > 0 {
                            HStack {
                                Image(systemName: "figure.walk")
                                    .foregroundColor(.orange)
                                Text("Шаги: \(tracker.steps)")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            .padding()
                        }
                        
                        Button(action: {
                            finishWorkout()
                        }) {
                            Text("Завершить")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .cornerRadius(12)
                                .shadow(color: Color.red.opacity(0.4), radius: 8)
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
        .alert("Тренировка сохранена", isPresented: $showingSummary) {
            Button("Отлично", role: .cancel) { }
        } message: {
            Text("Сохранено в Apple Health:\nДистанция: \(String(format: "%.2f", lastSummaryDistance / 1000.0)) км\nЭнергия: \(Int(lastSummaryCalories)) ккал")
        }
    }
    
    private func estimateCalories() -> Double {
        let weight = health.currentWeight > 0 ? health.currentWeight : 75.0
        let minutes = Double(tracker.elapsedSeconds) / 60.0
        return selectedWorkoutType.met * 3.5 * weight / 200.0 * minutes
    }
    
    private func finishWorkout() {
        let summary = tracker.stopTracking()
        
        let weight = health.currentWeight > 0 ? health.currentWeight : 75.0
        let minutes = Double(summary.duration) / 60.0
        let calories = selectedWorkoutType.met * 3.5 * weight / 200.0 * minutes
        
        lastSummaryCalories = calories
        lastSummaryDistance = summary.distance
        
        // Запись в HealthKit
        health.saveWorkout(
            activityType: selectedWorkoutType.hkType,
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
}
