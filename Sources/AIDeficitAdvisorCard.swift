import SwiftUI

// MARK: - Премиальная карточка AI-анализа активности и дефицита калорий для Dashboard
@MainActor
public struct AIDeficitAdvisorCard: View {
    @EnvironmentObject var health: HealthKitManager
    @EnvironmentObject var stepManager: BackgroundStepManager
    
    @ObservedObject private var coachManager = AICoachManager.shared
    
    @AppStorage("app_language") private var appLanguage = "ru"
    @AppStorage("user_weight") private var userWeight = 75.0
    @AppStorage("user_target_weight") private var userTargetWeight = 70.0
    @AppStorage("user_height") private var userHeight = 175
    @AppStorage("user_age") private var userAge = 25
    @AppStorage("user_gender") private var userGender = "Мужской"
    @AppStorage("user_somatotype") private var userSomatotype = "mesomorph"
    
    var onOpenDetails: () -> Void
    var onOpenChat: () -> Void
    
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
    
    // Мгновенный локальный расчет или кэш
    private var cachedOrComputedRec: AIDeficitRecommendation {
        let defaults = UserDefaults.standard
        let todayKey = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        if let data = defaults.data(forKey: "cached_ai_deficit_rec_\(todayKey)"),
           let saved = try? JSONDecoder().decode(AIDeficitRecommendation.self, from: data) {
            return saved
        }
        
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
    
    public init(onOpenDetails: @escaping () -> Void, onOpenChat: @escaping () -> Void) {
        self.onOpenDetails = onOpenDetails
        self.onOpenChat = onOpenChat
    }
    
    public var body: some View {
        let rec = cachedOrComputedRec
        let actualDeficit = rec.currentDeficitKcal
        let statusColor: Color = actualDeficit >= 0 ? .green : .orange
        let todayWorkouts = health.workoutHistory.filter { Calendar.current.isDateInToday($0.date) }
        
        VStack(alignment: .leading, spacing: 14) {
            // Шапка карточки
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(coach.accentColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(coach.avatarAssetName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(coach.accentColor, lineWidth: 1.5))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("AI-Советник по дефициту")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.textPrimary)
                        Image(systemName: "sparkles")
                            .foregroundColor(coach.accentColor)
                            .font(.system(size: 11))
                    }
                    
                    Text("Тренер \(coach.name) • \(coach.specialty)")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                }
                
                Spacer()
                
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onOpenChat()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                        Text("Чат")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(coach.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(coach.accentColor.opacity(0.12))
                    .cornerRadius(12)
                }
            }
            
            // Бейдж статуса дефицита и мини-чипы
            HStack(spacing: 8) {
                Text(rec.statusBadge)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.12))
                    .cornerRadius(8)
                
                Spacer()
                
                // Метрика шагов
                HStack(spacing: 3) {
                    Image(systemName: "figure.walk")
                        .foregroundColor(Theme.exerciseColor)
                        .font(.system(size: 10))
                    Text("\(effectiveSteps)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(8)
                
                // Метрика тренировок
                if !todayWorkouts.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "figure.run")
                            .foregroundColor(.purple)
                            .font(.system(size: 10))
                        Text("\(todayWorkouts.count) тр.")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Theme.textPrimary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(8)
                }
            }
            
            // Краткий совет тренера
            Text(rec.shortAdvice)
                .font(.system(size: 13))
                .foregroundColor(Theme.textPrimary)
                .lineSpacing(3)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.03))
                .cornerRadius(12)
            
            // Кнопка детального разбора
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onOpenDetails()
            }) {
                HStack(spacing: 6) {
                    Text("Открыть подробный расчет дефицита")
                        .font(.system(size: 13, weight: .bold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [coach.accentColor, coach.accentColor.opacity(0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: coach.accentColor.opacity(0.2), radius: 4, x: 0, y: 2)
            }
        }
        .padding(14)
        .background(Theme.cardBackground)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(coach.accentColor.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}
