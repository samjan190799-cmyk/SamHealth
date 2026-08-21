import SwiftUI

public struct HealthKitSyncHubView: View {
    @EnvironmentObject var health: HealthKitManager
    @Environment(\.dismiss) private var dismiss
    @AppStorage("app_language") private var appLanguage = "ru"
    
    // Настройки двустороннего экспорта
    @AppStorage("healthkit_auto_export_workouts") private var autoExportWorkouts = true
    @AppStorage("healthkit_auto_export_water") private var autoExportWater = true
    @AppStorage("healthkit_auto_export_weight") private var autoExportWeight = true
    @AppStorage("healthkit_auto_export_nutrition") private var autoExportNutrition = true
    
    @State private var isSpinning = false
    
    private func tr(_ key: String) -> String {
        LocalizationManager.tr(key, lang: appLanguage)
    }
    
    private var formattedLastSync: String {
        guard let date = health.lastSyncTime else {
            return tr("steps_bg_syncing")
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // MARK: - Главная карточка статуса Apple Health
                        VStack(spacing: 16) {
                            HStack(spacing: 16) {
                                // Иконка Apple Health
                                ZStack {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color(red: 255/255, green: 45/255, blue: 85/255),
                                                    Color(red: 255/255, green: 90/255, blue: 120/255)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 60, height: 60)
                                        .shadow(color: Color(red: 255/255, green: 45/255, blue: 85/255).opacity(0.35), radius: 10, x: 0, y: 5)
                                    
                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 30))
                                        .foregroundColor(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(tr("health_kit_title"))
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundColor(Theme.textPrimary)
                                    
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(health.isAuthorized ? Color.green : Color.orange)
                                            .frame(width: 8, height: 8)
                                        
                                        Text(health.isAuthorized ? tr("health_kit_connected") : tr("health_kit_connect_banner_title"))
                                            .font(.caption)
                                            .bold()
                                            .foregroundColor(health.isAuthorized ? .green : .orange)
                                    }
                                    
                                    if health.isAuthorized {
                                        Text(String(format: tr("health_kit_last_synced"), formattedLastSync))
                                            .font(.caption2)
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                }
                                
                                Spacer()
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                            
                            // Кнопка синхронизации / подключения
                            if health.isAuthorized {
                                Button(action: {
                                    triggerSync()
                                }) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .font(.system(size: 16, weight: .bold))
                                            .rotationEffect(Angle(degrees: isSpinning || health.isSyncing ? 360 : 0))
                                            .animation(isSpinning || health.isSyncing ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isSpinning || health.isSyncing)
                                        
                                        Text(health.isSyncing ? tr("health_kit_syncing") : tr("health_kit_sync_now"))
                                            .font(.system(size: 15, weight: .bold))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Theme.cardBackground)
                                    .foregroundColor(Theme.textPrimary)
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                                    )
                                }
                                .disabled(health.isSyncing)
                            } else {
                                Button(action: {
                                    let impact = UIImpactFeedbackGenerator(style: .medium)
                                    impact.impactOccurred()
                                    health.requestAuthorization()
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "heart.fill")
                                        Text(tr("health_kit_connect_btn"))
                                            .bold()
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 255/255, green: 45/255, blue: 85/255),
                                                Color(red: 255/255, green: 80/255, blue: 110/255)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .foregroundColor(.white)
                                    .cornerRadius(16)
                                    .shadow(color: Color(red: 255/255, green: 45/255, blue: 85/255).opacity(0.4), radius: 8, y: 4)
                                }
                            }
                        }
                        .premiumCard()
                        .padding(.horizontal)
                        .padding(.top, 12)
                        
                        // MARK: - Экспресс-замер пульса в реальном времени
                        VStack(spacing: 12) {
                            HStack {
                                HStack(spacing: 8) {
                                    Image(systemName: "airpodspro")
                                        .foregroundColor(Theme.pulseColor)
                                        .font(.system(size: 16, weight: .bold))
                                    Text(tr("hr_live_title"))
                                        .font(.headline)
                                        .foregroundColor(Theme.textPrimary)
                                }
                                
                                Spacer()
                                
                                Text(health.heartRateZone.localizedName(lang: appLanguage))
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(health.heartRateZone.color.opacity(0.15))
                                    .foregroundColor(health.heartRateZone.color)
                                    .cornerRadius(6)
                            }
                            
                            HStack(spacing: 16) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(Theme.pulseColor)
                                    .scaleEffect(health.isLiveHeartRateActive ? 1.15 : 1.0)
                                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: health.isLiveHeartRateActive)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                                        Text(health.isLiveHeartRateActive ? (health.liveHeartRate > 0 ? "\(health.liveHeartRate)" : "...") : (health.heartRate > 0 ? "\(health.heartRate)" : "70"))
                                            .font(.system(size: 26, weight: .bold, design: .rounded))
                                            .foregroundColor(Theme.textPrimary)
                                        Text("уд/мин")
                                            .font(.caption)
                                            .bold()
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                    
                                    Text(health.isLiveHeartRateActive ? tr("hr_live_measuring") : "AirPods Pro и датчики Apple Health")
                                        .font(.caption2)
                                        .foregroundColor(Theme.textSecondary)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    if health.isLiveHeartRateActive {
                                        health.stopLiveHeartRateSession()
                                    } else {
                                        health.startLiveHeartRateSession()
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: health.isLiveHeartRateActive ? "stop.fill" : "play.fill")
                                        Text(health.isLiveHeartRateActive ? tr("hr_live_stop") : tr("hr_live_start"))
                                    }
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(health.isLiveHeartRateActive ? Color.gray.opacity(0.8) : Theme.pulseColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                            }
                        }
                        .premiumCard()
                        .padding(.horizontal)
                        
                        // MARK: - Сетка синхронизируемых метрик
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Показатели здоровья")
                                    .font(.headline)
                                    .foregroundColor(Theme.textPrimary)
                                Spacer()
                                Text("8 метрик")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                // 1. Шаги и дистанция
                                MetricCard(
                                    icon: "figure.walk",
                                    color: Color.orange,
                                    title: tr("health_kit_metric_steps"),
                                    value: "\(health.stepsToday)",
                                    subtitle: health.distanceMetersToday > 0 ? String(format: "%.2f км", health.distanceMetersToday / 1000.0) : "в фоне"
                                )
                                
                                // 2. Активные калории (Move Ring)
                                MetricCard(
                                    icon: "flame.fill",
                                    color: Theme.moveColor,
                                    title: tr("calories_active"),
                                    value: String(format: "%.0f ккал", health.activeEnergyBurned),
                                    subtitle: String(format: "Цель: %.0f ккал", health.activeEnergyGoal)
                                )
                                
                                // 3. Энергия покоя / Всего сожжено
                                MetricCard(
                                    icon: "bolt.heart.fill",
                                    color: Color.blue,
                                    title: tr("calories_total_burned"),
                                    value: String(format: "%.0f ккал", health.totalEnergyBurned),
                                    subtitle: health.basalEnergyBurned > 0 ? String(format: "Покой: %.0f ккал", health.basalEnergyBurned) : "BMR расчет"
                                )
                                
                                // 4. Питание (Калории из еды)
                                MetricCard(
                                    icon: "fork.knife",
                                    color: Color.green,
                                    title: tr("calories_consumed"),
                                    value: String(format: "%.0f ккал", health.caloriesConsumedToday),
                                    subtitle: String(format: "Б:%.0f Ж:%.0f У:%.0f", health.proteinConsumedToday, health.fatConsumedToday, health.carbsConsumedToday)
                                )
                                
                                // 5. Пульс (AirPods Pro / Датчики)
                                MetricCard(
                                    icon: "airpodspro",
                                    color: Theme.pulseColor,
                                    title: tr("health_kit_metric_heart"),
                                    value: health.heartRate > 0 ? "\(health.heartRate) уд/м" : "70 уд/м",
                                    subtitle: "\(health.heartRateZone.rawValue) • AirPods Pro"
                                )
                                
                                // 6. Сон
                                MetricCard(
                                    icon: "moon.fill",
                                    color: Theme.sleepColor,
                                    title: tr("health_kit_metric_sleep"),
                                    value: String(format: "%.1f ч", health.sleepDuration),
                                    subtitle: health.deepSleepDuration > 0 ? String(format: "Глуб.: %.1f ч", health.deepSleepDuration) : "Фазы сна"
                                )
                                
                                // 7. Водный баланс
                                MetricCard(
                                    icon: "drop.fill",
                                    color: Theme.waterColor,
                                    title: tr("health_kit_metric_water"),
                                    value: String(format: "%.1f л", health.waterConsumed / 1000.0),
                                    subtitle: String(format: "Цель: %.1f л", health.waterGoal / 1000.0)
                                )
                                
                                // 8. Контроль веса
                                MetricCard(
                                    icon: "scalemass.fill",
                                    color: Theme.weightColor,
                                    title: tr("health_kit_metric_weight"),
                                    value: health.currentWeight > 0 ? String(format: "%.1f кг", health.currentWeight) : "—",
                                    subtitle: health.weightTrend == .up ? "Набор" : (health.weightTrend == .down ? "Снижение" : "Стабилен")
                                )
                            }
                            
                            // 7. Тренировки (Широкая карточка)
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Theme.exerciseColor.opacity(0.15))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "figure.run")
                                        .foregroundColor(Theme.exerciseColor)
                                        .font(.system(size: 20))
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tr("health_kit_metric_workouts"))
                                        .font(.subheadline)
                                        .bold()
                                        .foregroundColor(Theme.textPrimary)
                                    Text(health.lastWorkoutString)
                                        .font(.caption2)
                                        .foregroundColor(Theme.textSecondary)
                                        .lineLimit(2)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                            .padding()
                            .background(Theme.cardBackground)
                            .cornerRadius(18)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal)
                        
                        // MARK: - Импорт полной истории за год (365 дней)
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(Theme.exerciseColor)
                                    .font(.system(size: 18, weight: .bold))
                                Text(tr("health_kit_history_sync_title"))
                                    .font(.headline)
                                    .foregroundColor(Theme.textPrimary)
                                Spacer()
                                if health.dailyActivityHistory.count > 0 {
                                    Text("\(health.dailyActivityHistory.count) дн.")
                                        .font(.caption.bold())
                                        .foregroundColor(Theme.exerciseColor)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Theme.exerciseColor.opacity(0.12))
                                        .cornerRadius(8)
                                }
                            }
                            
                            Text(tr("health_kit_history_sync_desc"))
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                                .lineSpacing(3)
                            
                            if health.isHistoricalSyncInProgress {
                                HStack(spacing: 12) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.exerciseColor))
                                    Text(health.historicalSyncStatusMessage ?? tr("health_kit_history_syncing"))
                                        .font(.subheadline)
                                        .foregroundColor(Theme.textPrimary)
                                }
                                .padding(.vertical, 8)
                            } else {
                                Button(action: {
                                    let impact = UIImpactFeedbackGenerator(style: .medium)
                                    impact.impactOccurred()
                                    Task {
                                        await health.syncFullHistoricalData(daysBack: 365)
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "arrow.down.doc.fill")
                                            .font(.system(size: 14, weight: .bold))
                                        Text(tr("health_kit_history_sync_btn"))
                                            .font(.system(size: 14, weight: .bold))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Theme.exerciseColor.opacity(0.15))
                                    .foregroundColor(Theme.exerciseColor)
                                    .cornerRadius(14)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Theme.exerciseColor.opacity(0.3), lineWidth: 1)
                                    )
                                }
                                
                                if !health.dailyActivityHistory.isEmpty || !health.workoutHistory.isEmpty || !health.weightHistory.isEmpty {
                                    HStack(spacing: 14) {
                                        Label("\(health.dailyActivityHistory.count) дн.", systemImage: "figure.walk")
                                        Label("\(health.workoutHistory.count) трен.", systemImage: "figure.run")
                                        Label("\(health.weightHistory.count) зам.", systemImage: "scalemass.fill")
                                    }
                                    .font(.caption2)
                                    .foregroundColor(Theme.textSecondary)
                                }
                            }
                        }
                        .premiumCard()
                        .padding(.horizontal)
                        
                        // MARK: - Автоматический двусторонний экспорт
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Image(systemName: "arrow.left.arrow.right.circle.fill")
                                    .foregroundColor(Theme.exerciseColor)
                                Text(tr("health_kit_auto_export"))
                                    .font(.headline)
                                    .foregroundColor(Theme.textPrimary)
                            }
                            
                            Text(tr("health_kit_auto_export_desc"))
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                                .lineSpacing(3)
                            
                            VStack(spacing: 12) {
                                Toggle("Экспорт тренировок (HKWorkout)", isOn: $autoExportWorkouts)
                                    .tint(.green)
                                Divider()
                                Toggle("Экспорт выпитой воды", isOn: $autoExportWater)
                                    .tint(.green)
                                Divider()
                                Toggle("Экспорт веса", isOn: $autoExportWeight)
                                    .tint(.green)
                                Divider()
                                Toggle("Синхронизация питания и БЖУ", isOn: $autoExportNutrition)
                                    .tint(.green)
                            }
                            .font(.subheadline)
                            .foregroundColor(Theme.textPrimary)
                            .padding(.top, 4)
                        }
                        .premiumCard()
                        .padding(.horizontal)
                        
                        // MARK: - Настройки системы iOS
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "gearshape.fill")
                                    .foregroundColor(Theme.pulseColor)
                                Text(tr("health_kit_open_settings"))
                                    .font(.headline)
                                    .foregroundColor(Theme.textPrimary)
                            }
                            
                            Text(tr("health_kit_open_settings_desc"))
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                                .lineSpacing(3)
                            
                            Button(action: {
                                health.openSystemSettings()
                            }) {
                                HStack {
                                    Text("Перейти в Настройки iOS")
                                        .font(.subheadline)
                                        .bold()
                                    Spacer()
                                    Image(systemName: "arrow.up.forward.app")
                                }
                                .foregroundColor(Theme.exerciseColor)
                                .padding(.vertical, 8)
                            }
                        }
                        .premiumCard()
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle(tr("health_kit_sync_hub"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(tr("cancel")) {
                        dismiss()
                    }
                    .foregroundColor(Theme.textPrimary)
                }
            }
        }
    }
    
    private func triggerSync() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        withAnimation(.spring()) {
            isSpinning = true
        }
        
        health.syncAllWithHaptic()
        
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            await MainActor.run {
                withAnimation {
                    isSpinning = false
                }
            }
        }
    }
}

// MARK: - Карточка отдельной метрики
struct MetricCard: View {
    let icon: String
    let color: Color
    let title: String
    let value: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.system(size: 14, weight: .bold))
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }
            
            Text(title)
                .font(.caption2)
                .bold()
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
            
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
            
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
        }
        .padding(12)
        .background(Theme.cardBackground)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
