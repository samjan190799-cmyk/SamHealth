import Foundation
import SwiftUI

// MARK: - Модель данных интеллектуальной рекомендации по дефициту калорий и активности
public struct AIDeficitRecommendation: Codable, Sendable, Identifiable, Equatable {
    public var id: String { "\(generatedAt.timeIntervalSince1970)_\(provider)" }
    
    /// Главный заголовок вердикта (например, "Оптимальный дефицит для жиросжигания")
    public let title: String
    
    /// Бейдж статуса ("Дефицит: -480 ккал" / "Профицит: +150 ккал" / "Баланс соблюден")
    public let statusBadge: String
    
    /// Бейдж цвета статуса ("green", "orange", "blue", "purple")
    public let statusColorName: String
    
    /// Оставшийся допустимый бюджет калорий до достижения целевого дефицита на сегодня (ккал)
    public let calorieBudgetRemaining: Int
    
    /// Целевой дефицит калорий (ккал)
    public let targetDeficitKcal: Int
    
    /// Текущий фактический дефицит (ккал, положительный = дефицит, отрицательный = профицит)
    public let currentDeficitKcal: Int
    
    /// Краткий совет из 1-2 предложений (для пуш-уведомлений и виджетов)
    public let shortAdvice: String
    
    /// Развернутый структурированный разбор от ИИ-тренера
    public let detailedAdvice: String
    
    /// Конкретный чеклист действий на остаток дня
    public let actionSteps: [String]
    
    /// Учтенные показатели на момент анализа
    public let stepsCount: Int
    public let activeCaloriesBurned: Double
    public let basalCaloriesBurned: Double
    public let totalCaloriesBurned: Double
    public let caloriesConsumed: Double
    public let workoutsCount: Int
    public let workoutsSummary: String
    
    /// Дата и время генерации
    public let generatedAt: Date
    
    /// Имя провайдера (Gemini / ChatGPT / Claude / Оффлайн-движок ВОЗ)
    public let provider: String
    
    public init(
        title: String,
        statusBadge: String,
        statusColorName: String = "green",
        calorieBudgetRemaining: Int,
        targetDeficitKcal: Int,
        currentDeficitKcal: Int,
        shortAdvice: String,
        detailedAdvice: String,
        actionSteps: [String],
        stepsCount: Int,
        activeCaloriesBurned: Double,
        basalCaloriesBurned: Double,
        totalCaloriesBurned: Double,
        caloriesConsumed: Double,
        workoutsCount: Int,
        workoutsSummary: String,
        generatedAt: Date = Date(),
        provider: String = "Forma AI"
    ) {
        self.title = title
        self.statusBadge = statusBadge
        self.statusColorName = statusColorName
        self.calorieBudgetRemaining = calorieBudgetRemaining
        self.targetDeficitKcal = targetDeficitKcal
        self.currentDeficitKcal = currentDeficitKcal
        self.shortAdvice = shortAdvice
        self.detailedAdvice = detailedAdvice
        self.actionSteps = actionSteps
        self.stepsCount = stepsCount
        self.activeCaloriesBurned = activeCaloriesBurned
        self.basalCaloriesBurned = basalCaloriesBurned
        self.totalCaloriesBurned = totalCaloriesBurned
        self.caloriesConsumed = caloriesConsumed
        self.workoutsCount = workoutsCount
        self.workoutsSummary = workoutsSummary
        self.generatedAt = generatedAt
        self.provider = provider
    }
    
    // MARK: - Автономный локальный физиологический расчет (Offline Engine ВОЗ)
    public static func computeLocalFallback(
        steps: Int,
        distanceKm: Double,
        activeCalories: Double,
        basalCalories: Double,
        totalEnergyBurned: Double,
        caloriesConsumed: Double,
        protein: Double,
        fat: Double,
        carbs: Double,
        workouts: [WorkoutRecord],
        weight: Double,
        targetWeight: Double,
        height: Int,
        age: Int,
        gender: String,
        somatotypeRaw: String,
        coach: AICoachPersona,
        language: String
    ) -> AIDeficitRecommendation {
        let somato = Somatotype(rawValue: somatotypeRaw) ?? .mesomorph
        let effectiveWeight = weight > 30 ? weight : 75.0
        let effectiveTarget = targetWeight > 30 ? targetWeight : effectiveWeight
        
        // Базовый обмен (BMR) по формуле Mifflin-St Jeor
        let calculatedBmr: Double
        if gender.lowercased().contains("жен") || gender.lowercased().contains("fem") {
            calculatedBmr = (10.0 * effectiveWeight) + (6.25 * Double(height)) - (5.0 * Double(age)) - 161.0
        } else {
            calculatedBmr = (10.0 * effectiveWeight) + (6.25 * Double(height)) - (5.0 * Double(age)) + 5.0
        }
        
        let adjustedBmr = max(1200.0, basalCalories > 0 ? basalCalories : (calculatedBmr * somato.metabolismMultiplier))
        let effectiveActive = activeCalories > 0 ? activeCalories : (Double(steps) * 0.042)
        let effectiveTdee = totalEnergyBurned > 0 ? totalEnergyBurned : (adjustedBmr + effectiveActive)
        
        // Фактический дефицит = Расход (TDEE) - Потребление
        let actualDeficit = Int(effectiveTdee - caloriesConsumed)
        
        // Определение цели пользователя
        let isWeightLoss = effectiveTarget < effectiveWeight - 0.5
        let isMuscleGain = effectiveTarget > effectiveWeight + 0.5
        
        let targetDeficit: Int
        if isWeightLoss {
            // Рекомендуемый ВОЗ безопасный дефицит: 15-20% от TDEE (~400-550 ккал)
            targetDeficit = max(350, min(650, Int(effectiveTdee * 0.20)))
        } else if isMuscleGain {
            // Небольшой профицит для роста мышц (~200-300 ккал)
            targetDeficit = -250
        } else {
            // Поддержание формы
            targetDeficit = 0
        }
        
        // Сколько еще можно съесть до целевого дефицита
        let remainingBudget = max(0, Int(effectiveTdee - Double(targetDeficit) - caloriesConsumed))
        
        let title: String
        let statusBadge: String
        let colorName: String
        let shortAdvice: String
        var actions: [String] = []
        
        let workoutsSummaryText = workouts.isEmpty 
            ? "Тренировок пока нет" 
            : workouts.map { "\($0.type) (\($0.durationMinutes) мин)" }.joined(separator: ", ")
        
        if isWeightLoss {
            if actualDeficit >= targetDeficit + 300 && caloriesConsumed > 0 {
                title = "Глубокий дефицит калорий"
                statusBadge = "Дефицит: -\(actualDeficit) ккал"
                colorName = "orange"
                shortAdvice = "Дефицит превысил целевую норму. Рекомендуем подкрепиться качественным белком и овощами, чтобы сберечь мышцы."
                actions = [
                    "Съешьте легкий белковый ужин на \(min(remainingBudget, 400)) ккал (рыба, птица или творог).",
                    "Выпейте 300 мл чистой воды для поддержки гидратации.",
                    "Обеспечьте качественный сон не менее 7.5 часов для восстановления."
                ]
            } else if actualDeficit >= targetDeficit - 150 {
                title = "Идеальный темп жиросжигания"
                statusBadge = "Дефицит: -\(actualDeficit) ккал"
                colorName = "green"
                shortAdvice = "Отличная работа! Текущий дефицит в \(actualDeficit) ккал идеально стимулирует сжигание жира без замедления обмена веществ."
                actions = [
                    remainingBudget > 150 ? "Остался запас на \(remainingBudget) ккал — отличный слот для полезного перекуса." : "Суточная цель калорий достигнута, держите водный баланс.",
                    "Сделайте легкую вечернюю растяжку на 5-10 минут.",
                    "Зафиксируйте чистый день в привычках!"
                ]
            } else if actualDeficit > 0 {
                title = "Умеренный дефицит калорий"
                statusBadge = "Дефицит: -\(actualDeficit) ккал"
                colorName = "blue"
                let stepsNeeded = max(0, (targetDeficit - actualDeficit) * 22)
                shortAdvice = "Вы в дефиците, но для оптимального сброса веса не хватает около \(targetDeficit - actualDeficit) ккал."
                actions = [
                    "Пройдите еще ~\(min(stepsNeeded, 3500)) шагов в бодром темпе.",
                    "Если планируется ужин — отдайте предпочтение клетчатке и нежирному белку.",
                    "Откажитесь от быстрых углеводов и сладких напитков перед сном."
                ]
            } else {
                let surplus = abs(actualDeficit)
                title = "Энергетический профицит"
                statusBadge = "Профицит: +\(surplus) ккал"
                colorName = "orange"
                shortAdvice = "Потреблено на \(surplus) ккал больше расхода. Добавьте вечернюю активность, чтобы выровнять баланс."
                actions = [
                    "30-минутная вечерняя прогулка или кардио сожжет около 180-220 ккал.",
                    "Завершите приемы пищи на сегодня, перейдите на воду или травяной чай.",
                    "Завтра сделайте акцент на белке и активности с первой половины дня."
                ]
            }
        } else if isMuscleGain {
            if actualDeficit <= targetDeficit {
                title = "Анаболический баланс для роста"
                statusBadge = "Профицит: +\(abs(actualDeficit)) ккал"
                colorName = "green"
                shortAdvice = "Отличный режим профицита для мышечной гипертрофии и прогресса в силовых!"
                actions = [
                    "Держите норму белка не менее \(Int(effectiveWeight * 1.8)) г в сутки.",
                    "Не забывайте о сложных углеводах для восполнения гликогена.",
                    "Качественный сон 8 часов — ключевой фактор анаболизма."
                ]
            } else {
                title = "Недостаток калорий для набора"
                statusBadge = "Дефицит: -\(actualDeficit) ккал"
                colorName = "blue"
                shortAdvice = "Для набора массы организму требуется больше энергии. Добавьте питательный прием пищи."
                actions = [
                    "Добавьте питательный перекус на \(remainingBudget) ккал (орехи, бананы, протеиновый шейк).",
                    "Снизьте изнуряющее кардио, сфокусируйтесь на базовых упражнениях.",
                    "Выпейте порцию аминокислот или протеина перед сном."
                ]
            }
        } else {
            // Поддержание
            if abs(actualDeficit) <= 200 {
                title = "Баланс энергии соблюден"
                statusBadge = "Равновесие (±\(abs(actualDeficit)) ккал)"
                colorName = "green"
                shortAdvice = "Ваш энергетический баланс находится в идеальной точке сохранения текущего веса и рельефа."
                actions = [
                    "Продолжайте придерживаться текущего ритма питания.",
                    "Держите дневную норму 8000–10000 шагов.",
                    "Водный баланс: не менее 35 мл на 1 кг массы тела."
                ]
            } else if actualDeficit > 200 {
                title = "Легкий дефицит калорий"
                statusBadge = "Дефицит: -\(actualDeficit) ккал"
                colorName = "blue"
                shortAdvice = "Расход превышает потребление на \(actualDeficit) ккал. Можно комфортно поужинать."
                actions = [
                    "У вас остался запас на ужин около \(remainingBudget) ккал.",
                    "Добавьте порцию сложных углеводов и полезных жиров.",
                    "Продолжайте умеренную ежедневную активность."
                ]
            } else {
                title = "Небольшой профицит"
                statusBadge = "Профицит: +\(abs(actualDeficit)) ккал"
                colorName = "orange"
                shortAdvice = "Потребление слегка превысило расход (+ \(abs(actualDeficit)) ккал). Достаточно небольшой прогулки."
                actions = [
                    "15-20 минут ходьбы полностью скомпенсируют разницу.",
                    "Перейдите на чистую воду до сна.",
                    "Отличный повод для бодрой утренней разминки завтра!"
                ]
            }
        }
        
        let detailedText = """
        Привет от тренера \(coach.name)! Я проанализировал твою сегодняшнюю активность и питание.

        📊 ТВОЙ ЭНЕРГЕТИЧЕСКИЙ БАЛАНС:
        • Пройдено шагов: \(steps) (\(String(format: "%.1f", distanceKm)) км)
        • Тренировки: \(workoutsSummaryText)
        • Активный расход (движение): \(Int(effectiveActive)) ккал
        • Базовый обмен (\(somato.title)): \(Int(adjustedBmr)) ккал
        • Суммарный расход (TDEE): \(Int(effectiveTdee)) ккал
        • Потреблено с едой: \(Int(caloriesConsumed)) ккал
        • Текущее сальдо: \(actualDeficit >= 0 ? "Дефицит \(actualDeficit) ккал" : "Профицит \(abs(actualDeficit)) ккал")
        • Целевой ориентир дефицита: \(targetDeficit >= 0 ? "\(targetDeficit) ккал" : "Профицит \(abs(targetDeficit)) ккал")

        💡 ФИЗИОЛОГИЧЕСКИЙ ВЕРДИКТ:
        \(shortAdvice)
        
        Твой соматотип — \(somato.title) (\(somato.shortDescription)). \(somato.nutritionStrategyPrompt)
        """
        
        return AIDeficitRecommendation(
            title: title,
            statusBadge: statusBadge,
            statusColorName: colorName,
            calorieBudgetRemaining: remainingBudget,
            targetDeficitKcal: targetDeficit,
            currentDeficitKcal: actualDeficit,
            shortAdvice: shortAdvice,
            detailedAdvice: detailedText,
            actionSteps: actions,
            stepsCount: steps,
            activeCaloriesBurned: effectiveActive,
            basalCaloriesBurned: adjustedBmr,
            totalCaloriesBurned: effectiveTdee,
            caloriesConsumed: caloriesConsumed,
            workoutsCount: workouts.count,
            workoutsSummary: workoutsSummaryText,
            generatedAt: Date(),
            provider: "Forma Physiology Core (WHO)"
        )
    }
}
