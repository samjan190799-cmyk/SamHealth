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
        if let data = defaults.data(forKey: "cached_ai_deficit_rec_v2_\(todayKey)"),
           let saved = try? JSONDecoder().decode(AIDeficitRecommendation.self, from: data) {
            return saved
        }
        
        return AIDeficitRecommendation.computeLocalFallback(
            steps: effectiveSteps,
            distanceKm: effectiveDistanceKm,
            activeCalories: effectiveActiveCal,
            basalCalories: health.calculatedBasalEnergy,
            totalEnergyBurned: health.totalEnergyBurned,
            dailyEnergyProjection: health.projectedDailyEnergy,
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
        let statusColor: Color = rec.currentDeficitKcal >= 0 ? Theme.exerciseColor : Color.orange

        // Общий вид ИИ-карточки: шапка с портретом тренера, статус, короткий совет и одно действие.
        // Шаги и число тренировок отсюда убраны: они уже есть в кольцах героя над карточкой.
        VStack(alignment: .leading, spacing: FormaSpacing.m) {
            FormaAICardHeader(
                title: "ИИ-тренер",
                subtitle: "\(coach.name) · \(coach.specialty)",
                avatarAssetName: coach.avatarAssetName,
                onChat: {
                    onOpenChat()
                }
            )

            FormaBadge(rec.statusBadge, tint: statusColor)

            Text(rec.shortAdvice)
                .font(.subheadline)
                .foregroundColor(Theme.textPrimary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            FormaTintedButton(title: "Подробный расчёт дефицита", icon: "chart.bar.doc.horizontal", tint: Theme.aiViolet) {
                onOpenDetails()
            }
        }
        .premiumCard()
    }
}
