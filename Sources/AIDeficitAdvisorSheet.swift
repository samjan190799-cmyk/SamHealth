import SwiftUI
import UserNotifications

// MARK: - Интерактивный детальный экран AI-анализа активности и дефицита калорий
@MainActor
public struct AIDeficitAdvisorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var health: HealthKitManager
    @EnvironmentObject var stepManager: BackgroundStepManager
    
    @ObservedObject private var coachManager = AICoachManager.shared
    @ObservedObject private var notifManager = FormaNotificationManager.shared
    
    @AppStorage("app_language") private var appLanguage = "ru"
    @AppStorage("user_weight") private var userWeight = 75.0
    @AppStorage("user_target_weight") private var userTargetWeight = 70.0
    @AppStorage("user_height") private var userHeight = 175
    @AppStorage("user_age") private var userAge = 25
    @AppStorage("user_gender") private var userGender = "Мужской"
    @AppStorage("user_somatotype") private var userSomatotype = "mesomorph"
    @AppStorage("user_metabolism_speed") private var userMetabolismSpeed = "normal"
    @AppStorage("ai_deficit_notifications_enabled") private var aiDeficitNotificationsEnabled = true
    
    @State private var recommendation: AIDeficitRecommendation? = nil
    @State private var isRefreshing: Bool = false
    @State private var testNotificationBanner: String? = nil
    
    private var coach: AICoachPersona {
        coachManager.currentCoach
    }
    
    private var effectiveSteps: Int {
        max(stepManager.stepsToday, health.stepsToday)
    }
    
    private var effectiveDistanceKm: Double {
        health.distanceTodayKm > 0 ? health.distanceTodayKm : (Double(effectiveSteps) * 0.00075)
    }
    
    private var effectiveWeight: Double {
        if health.currentWeight > 0 { return health.currentWeight }
        let saved = UserDefaults.standard.double(forKey: "user_weight")
        return saved > 0 ? saved : userWeight
    }
    
    private var effectiveActiveCal: Double {
        health.activeEnergyBurned > 0 ? health.activeEnergyBurned : health.calculatedStepCalories
    }
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 1. Верхний баннер тренера
                        coachHeaderView
                        
                        // 2. Главный визуальный датчик дефицита и расхода энергии
                        deficitGaugeCard
                        
                        // 3. Биометрическая сетка компонентов расхода и потребления
                        energyBreakdownGrid
                        
                        // 4. Карточка развернутого ИИ-анализа и чеклиста действий
                        detailedRecommendationCard
                        
                        // 5. Управление умными уведомлениями дефицита (Включение / Выключение)
                        notificationSettingsCard
                        
                        // Отступ снизу для комфортного скролла
                        Spacer(minLength: 32)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }
            .navigationTitle("AI-Баланс активности")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        runAnalysis()
                    }) {
                        HStack(spacing: 4) {
                            if isRefreshing {
                                ProgressView()
                                    .tint(coach.accentColor)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text(isRefreshing ? "Расчет..." : "Обновить")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(coach.accentColor)
                    }
                    .disabled(isRefreshing)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
            .onAppear {
                loadCachedOrCompute()
            }
        }
    }
    
    // MARK: - 1. Шапка тренера
    private var coachHeaderView: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(coach.accentColor.opacity(0.15))
                    .frame(width: 54, height: 54)
                
                Image(coach.avatarAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(coach.accentColor, lineWidth: 1.5))
            }
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Тренер \(coach.name)")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                    Text(coach.badgeEmoji)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text("Live Analysis")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(coach.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(coach.accentColor.opacity(0.12))
                        .clipShape(Capsule())
                }
                
                Text(coach.specialty)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                
                let somato = Somatotype(rawValue: userSomatotype) ?? .mesomorph
                Text("Калибровка: \(somato.emoji) \(somato.title)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(somato.accentColor)
            }
        }
        .padding(14)
        .background(Theme.cardBackground)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(coach.accentColor.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
    
    // MARK: - 2. Главный визуальный датчик дефицита калорий
    private var deficitGaugeCard: some View {
        let rec = currentRec
        let actualDeficit = rec.currentDeficitKcal
        let target = rec.targetDeficitKcal
        let isDeficit = actualDeficit >= 0
        let statusColor: Color = actualDeficit >= 0 ? .green : .orange
        
        let progressPercent: Double = target != 0 ? min(1.5, max(0.0, Double(actualDeficit) / Double(target))) : 1.0
        
        return VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ЭНЕРГЕТИЧЕСКИЙ БАЛАНС ДНЯ")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(Theme.textSecondary)
                    Text(rec.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                }
                Spacer()
                
                Text(rec.statusBadge)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(statusColor.opacity(0.12))
                    .cornerRadius(10)
            }
            
            // Дуговой индикатор прогресса
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.08), lineWidth: 12)
                        .frame(width: 100, height: 100)
                    
                    Circle()
                        .trim(from: 0.0, to: min(1.0, progressPercent))
                        .stroke(
                            LinearGradient(
                                colors: [statusColor, statusColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 100, height: 100)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progressPercent)
                    
                    VStack(spacing: 2) {
                        Image(systemName: isDeficit ? "flame.fill" : "plus.circle.fill")
                            .foregroundColor(statusColor)
                            .font(.system(size: 16))
                        Text("\(actualDeficit >= 0 ? "-\(actualDeficit)" : "+\(abs(actualDeficit))")")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Theme.textPrimary)
                        Text("ккал")
                            .font(.system(size: 9))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle().fill(Color.green).frame(width: 8, height: 8)
                        Text("Целевой дефицит:")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        Spacer()
                        Text("\(target >= 0 ? "-\(target)" : "+\(abs(target))") ккал")
                            .font(.caption.bold())
                            .foregroundColor(Theme.textPrimary)
                    }
                    
                    HStack {
                        Circle().fill(Color.orange).frame(width: 8, height: 8)
                        Text("Остаток калорий:")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        Spacer()
                        Text("\(rec.calorieBudgetRemaining) ккал")
                            .font(.caption.bold())
                            .foregroundColor(Theme.textPrimary)
                    }
                    
                    HStack {
                        Circle().fill(Color.blue).frame(width: 8, height: 8)
                        Text("Суммарный расход:")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        Spacer()
                        Text("\(Int(rec.totalCaloriesBurned)) ккал")
                            .font(.caption.bold())
                            .foregroundColor(Theme.textPrimary)
                    }
                }
            }
        }
        .padding(16)
        .background(Theme.cardBackground)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - 3. Биометрическая сетка компонентов расхода и потребления
    private var energyBreakdownGrid: some View {
        let rec = currentRec
        let todayWorkouts = health.workoutHistory.filter { Calendar.current.isDateInToday($0.date) }
        
        return VStack(alignment: .leading, spacing: 12) {
            Text("ИСТОЧНИКИ АКТИВНОСТИ И РАСХОДА")
                .font(.system(size: 11, weight: .black))
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal, 2)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                // Шаги
                metricCard(
                    icon: "figure.walk",
                    color: Theme.exerciseColor,
                    title: "Шаги и ходьба",
                    value: "\(effectiveSteps)",
                    subvalue: "\(String(format: "%.1f", effectiveDistanceKm)) км • \(Int(Double(effectiveSteps) * 0.042)) ккал"
                )
                
                // Активные калории
                metricCard(
                    icon: "flame.fill",
                    color: Theme.moveColor,
                    title: "Активный расход",
                    value: "\(Int(effectiveActiveCal)) ккал",
                    subvalue: "Спорт и бытовое движение"
                )
                
                // Тренировки за сегодня
                metricCard(
                    icon: "figure.run",
                    color: .purple,
                    title: "Тренировки сегодня",
                    value: "\(todayWorkouts.count) сессий",
                    subvalue: todayWorkouts.isEmpty ? "Пока не зафиксировано" : "\(todayWorkouts.map { $0.type }.joined(separator: ", "))"
                )
                
                // Потреблено с пищей
                metricCard(
                    icon: "fork.knife",
                    color: .green,
                    title: "Питание (Съедено)",
                    value: "\(Int(health.caloriesConsumedToday)) ккал",
                    subvalue: "Б:\(Int(health.proteinConsumedToday))г • Ж:\(Int(health.fatConsumedToday))г • У:\(Int(health.carbsConsumedToday))г"
                )
            }
        }
    }
    
    private func metricCard(icon: String, color: Color, title: String, value: String, subvalue: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 13, weight: .bold))
                Text(title)
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
            }
            
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Theme.textPrimary)
            
            Text(subvalue)
                .font(.system(size: 10))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
    
    // MARK: - 4. Карточка развернутого ИИ-анализа и чеклиста действий
    private var detailedRecommendationCard: some View {
        let rec = currentRec
        
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundColor(coach.accentColor)
                    Text("ВЕРДИКТ ТРЕНЕРА \(coach.name.uppercased())")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer()
                Text(rec.provider)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
            }
            
            // Краткий совет
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "quote.opening")
                    .foregroundColor(coach.accentColor.opacity(0.6))
                    .font(.system(size: 16))
                
                Text(rec.shortAdvice)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                    .lineSpacing(3)
            }
            .padding(12)
            .background(coach.accentColor.opacity(0.08))
            .cornerRadius(12)
            
            // Развернутый текст
            Text(rec.detailedAdvice)
                .font(.system(size: 13))
                .foregroundColor(Theme.textPrimary)
                .lineSpacing(4)
            
            // Чеклист действий
            if !rec.actionSteps.isEmpty {
                Divider().background(Color.primary.opacity(0.08))
                
                Text("РЕКОМЕНДУЕМЫЕ ДЕЙСТВИЯ НА СЕГОДНЯ:")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(Theme.textSecondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(rec.actionSteps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(coach.accentColor.opacity(0.2))
                                    .frame(width: 20, height: 20)
                                Text("\(index + 1)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(coach.accentColor)
                            }
                            .padding(.top, 1)
                            
                            Text(step)
                                .font(.system(size: 13))
                                .foregroundColor(Theme.textPrimary)
                                .lineSpacing(2)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Theme.cardBackground)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - 5. Управление умными уведомлениями дефицита (Включение / Выключение)
    private var notificationSettingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: "bell.badge.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 15))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Умные AI-уведомления дефицита")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    Text("Дневной чекпоинт в 14:00 и вечерний срез в 20:30")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }
            }
            
            Divider().background(Color.primary.opacity(0.08))
            
            Toggle(isOn: Binding(
                get: { aiDeficitNotificationsEnabled },
                set: { enabled in
                    aiDeficitNotificationsEnabled = enabled
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    if enabled {
                        notifManager.scheduleAIDeficitNotifications(coach: coach)
                    } else {
                        notifManager.removeAIDeficitNotifications()
                    }
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Получать советы в течение дня")
                        .font(.subheadline.bold())
                        .foregroundColor(Theme.textPrimary)
                    Text("ИИ проанализирует шаги и еду и пришлет персональный совет")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .tint(coach.accentColor)
            
            if let banner = testNotificationBanner {
                Text(banner)
                    .font(.caption.bold())
                    .foregroundColor(coach.accentColor)
                    .padding(.top, 4)
                    .transition(.opacity)
            }
            
            // Кнопка тестового уведомления
            Button(action: {
                sendTestAIDeficitPush()
            }) {
                HStack {
                    Image(systemName: "paperplane.fill")
                    Text("Отправить тестовое уведомление сейчас")
                }
                .font(.caption.bold())
                .foregroundColor(coach.accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(coach.accentColor.opacity(0.12))
                .cornerRadius(10)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(Theme.cardBackground)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
    
    // MARK: - Вспомогательные методы
    private var currentRec: AIDeficitRecommendation {
        if let rec = recommendation { return rec }
        return AIDeficitRecommendation.computeLocalFallback(
            steps: effectiveSteps,
            distanceKm: effectiveDistanceKm,
            activeCalories: effectiveActiveCal,
            basalCalories: health.calculatedBasalEnergy,
            totalEnergyBurned: health.totalEnergyBurned,
            caloriesConsumed: health.caloriesConsumedToday,
            protein: health.proteinConsumedToday,
            fat: health.fatConsumedToday,
            carbs: health.carbsConsumedToday,
            workouts: health.workoutHistory,
            weight: effectiveWeight,
            targetWeight: userTargetWeight,
            height: userHeight,
            age: userAge,
            gender: userGender,
            somatotypeRaw: userSomatotype,
            coach: coach,
            language: appLanguage
        )
    }
    
    private func loadCachedOrCompute() {
        let defaults = UserDefaults.standard
        let todayKey = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        if let data = defaults.data(forKey: "cached_ai_deficit_rec_\(todayKey)"),
           let saved = try? JSONDecoder().decode(AIDeficitRecommendation.self, from: data) {
            self.recommendation = saved
        } else {
            runAnalysis()
        }
    }
    
    private func runAnalysis() {
        isRefreshing = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        let steps = effectiveSteps
        let distance = effectiveDistanceKm
        let active = effectiveActiveCal
        let basal = health.calculatedBasalEnergy
        let total = health.totalEnergyBurned
        let consumed = health.caloriesConsumedToday
        let p = health.proteinConsumedToday
        let f = health.fatConsumedToday
        let c = health.carbsConsumedToday
        let workouts = health.workoutHistory
        let weight = effectiveWeight
        let targetW = userTargetWeight
        let height = userHeight
        let age = userAge
        let gender = userGender
        let somato = userSomatotype
        let metab = userMetabolismSpeed
        let currentCoach = coach
        let lang = appLanguage
        
        Task {
            let result = await GeminiScanService.shared.generateActivityAndDeficitRecommendation(
                steps: steps,
                distanceKm: distance,
                activeCalories: active,
                basalCalories: basal,
                totalEnergyBurned: total,
                caloriesConsumed: consumed,
                protein: p,
                fat: f,
                carbs: c,
                workouts: workouts,
                weight: weight,
                targetWeight: targetW,
                height: height,
                age: age,
                gender: gender,
                somatotype: somato,
                metabolismSpeed: metab,
                coach: currentCoach,
                language: lang
            )
            
            await MainActor.run {
                self.recommendation = result
                self.isRefreshing = false
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                
                let todayKey = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
                if let encoded = try? JSONEncoder().encode(result) {
                    UserDefaults.standard.set(encoded, forKey: "cached_ai_deficit_rec_\(todayKey)")
                }
            }
        }
    }
    
    private func sendTestAIDeficitPush() {
        notifManager.requestPermission { granted in
            if granted {
                notifManager.sendTestAIDeficitNotification(coach: coach)
                withAnimation {
                    testNotificationBanner = "Тестовое уведомление отправлено! 🔔"
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    withAnimation { testNotificationBanner = nil }
                }
            } else {
                withAnimation {
                    testNotificationBanner = "Разрешите уведомления в настройках iOS ⚙️"
                }
            }
        }
    }
}
