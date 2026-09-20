import Foundation
import SwiftUI

public enum AICoachActionType: String, Codable {
    case logWorkout = "log_workout"
    case adjustActiveCalories = "adjust_active_calories"
    case logWater = "log_water"
    case logMeal = "log_meal"
    case logWeight = "log_weight"
    case markHabitCompleted = "mark_habit_completed"
    case freezeHabit = "freeze_habit"
}

public struct AICoachAction: Identifiable, Codable, Equatable {
    public var id: String = UUID().uuidString
    public let type: AICoachActionType
    public let title: String
    public let subtitle: String
    public var durationMinutes: Int?
    public var calories: Double?
    public var waterMl: Double?
    public var weightKg: Double?
    public var mealCalories: Double?
    public var mealProtein: Double?
    public var mealFat: Double?
    public var mealCarbs: Double?
    public var mealWeightGrams: Double?
    public var metValue: Double?
    public var habitId: String?
    public var habitTitle: String?
    public let reasoning: String
    public var isExecuted: Bool = false
    public var isSanityChecked: Bool = true
    public var validationWarning: String? = nil
    
    public init(
        id: String = UUID().uuidString,
        type: AICoachActionType,
        title: String,
        subtitle: String,
        durationMinutes: Int? = nil,
        calories: Double? = nil,
        waterMl: Double? = nil,
        weightKg: Double? = nil,
        mealCalories: Double? = nil,
        mealProtein: Double? = nil,
        mealFat: Double? = nil,
        mealCarbs: Double? = nil,
        mealWeightGrams: Double? = nil,
        metValue: Double? = nil,
        habitId: String? = nil,
        habitTitle: String? = nil,
        reasoning: String,
        isExecuted: Bool = false,
        isSanityChecked: Bool = true,
        validationWarning: String? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.durationMinutes = durationMinutes
        self.calories = calories
        self.waterMl = waterMl
        self.weightKg = weightKg
        self.mealCalories = mealCalories
        self.mealProtein = mealProtein
        self.mealFat = mealFat
        self.mealCarbs = mealCarbs
        self.mealWeightGrams = mealWeightGrams
        self.metValue = metValue
        self.habitId = habitId
        self.habitTitle = habitTitle
        self.reasoning = reasoning
        self.isExecuted = isExecuted
        self.isSanityChecked = isSanityChecked
        self.validationWarning = validationWarning
    }
}

// MARK: - Защита от галлюцинаций (Физиологический и семантический барьер)

public struct AICoachSanityGuardrail {
    /// Проверка интента: защищает от галлюцинаций при чисто теоретических или абстрактных вопросах
    public static func isIntentActionable(userQuestion: String) -> Bool {
        let q = userQuestion.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        let actionSignals = [
            "я сделал", "я делал", "я таскал", "я носил", "я прошел", "я проехал",
            "я занимался", "я тренировался", "я выпил", "я попил", "я съел", "я покушал",
            "я вешу", "мой вес", "запиши", "занеси", "добавь", "внеси", "сохрани", "посчитай мне нагрузку",
            "сегодня таскал", "сегодня носил", "сегодня собрал", "сегодня работал", "таскал виноград",
            "носил ящики", "таскал мешки", "носил тяжести",
            "сделал растяжку", "сделала растяжку", "выпил витамины", "выпила витамины",
            "выпил воду", "выпила воду", "не ел сахар", "не ела сахар", "отметь привычку",
            "засчитай привычку", "выполнил привычку", "заморозь стрик", "заморозь привычку",
            "защити стрик", "приболел", "заболел", "сохрани стрик"
        ]
        let hasActionSignal = actionSignals.contains(where: { q.contains($0) })
        
        let theoreticalSignals = [
            "сколько калорий сжигает", "сколько сжигает", "почему", "что лучше", "стоит ли",
            "как правильно", "вредно ли", "полезно ли", "какой пульс должен быть", "расскажи о",
            "теоретически", "в среднем", "можно ли узнать"
        ]
        let hasTheoreticalSignal = theoreticalSignals.contains(where: { q.contains($0) })
        
        // Если это абстрактный вопрос и нет маркеров реального действия — блокируем действие
        if hasTheoreticalSignal && !hasActionSignal {
            return false
        }
        
        // Если вопрос оканчивается на '?' и нет ни одного маркера свершившегося действия
        if q.hasSuffix("?") && !hasActionSignal {
            return false
        }
        
        return true
    }
    
    /// Физиологическая валидация действия
    public static func sanitize(action: AICoachAction, userWeight: Double) -> AICoachAction? {
        var a = action
        let weight = userWeight > 0 ? userWeight : 75.0
        
        switch a.type {
        case .logWorkout, .adjustActiveCalories:
            guard let rawDuration = a.durationMinutes, rawDuration > 0 else { return nil }
            let clampedDuration = max(5, min(720, rawDuration))
            a.durationMinutes = clampedDuration
            
            // Физиологический лимит: человек не может тратить более 18 ккал/мин непрерывно
            let maxBiologicallyPossible = Double(clampedDuration) * 18.0
            let hours = Double(clampedDuration) / 60.0
            
            let met = max(2.5, min(10.0, a.metValue ?? 6.5))
            a.metValue = met
            let standardPhysiologicalCalories = met * weight * hours
            
            let rawCalories = a.calories ?? standardPhysiologicalCalories
            
            if rawCalories > maxBiologicallyPossible || rawCalories > 3500.0 || rawCalories < 30.0 {
                let corrected = min(3500.0, max(50.0, standardPhysiologicalCalories))
                a.calories = round(corrected)
                a.validationWarning = "Калории скорректированы формулой MET (защита от галлюцинаций ИИ)"
            } else {
                a.calories = round(rawCalories)
            }
            a.isSanityChecked = true
            return a
            
        case .logWater:
            guard let rawWater = a.waterMl, rawWater > 0 else { return nil }
            if rawWater > 2500.0 {
                a.waterMl = 2500.0
                a.validationWarning = "Объем ограничен максимумом 2.5 л"
            } else if rawWater < 30.0 {
                a.waterMl = 30.0
            } else {
                a.waterMl = round(rawWater)
            }
            a.isSanityChecked = true
            return a
            
        case .logWeight:
            guard let rawWeight = a.weightKg, rawWeight > 0 else { return nil }
            if rawWeight < 35.0 || rawWeight > 250.0 {
                return nil
            }
            a.weightKg = round(rawWeight * 10) / 10
            a.isSanityChecked = true
            return a
            
        case .logMeal:
            guard let rawCalories = a.mealCalories, rawCalories > 0 else { return nil }
            if rawCalories > 4000.0 {
                a.mealCalories = 4000.0
                a.validationWarning = "Калорийность ограничена 4000 ккал"
            } else {
                a.mealCalories = round(rawCalories)
            }
            a.isSanityChecked = true
            return a
            
        case .markHabitCompleted:
            a.isSanityChecked = true
            return a
            
        case .freezeHabit:
            a.isSanityChecked = true
            return a
        }
    }
}

// MARK: - Парсер структурированных действий тренера

extension AICoachAction {
    public static func parseFromResponse(
        text: String,
        userQuestion: String,
        userWeight: Double
    ) -> (cleanText: String, action: AICoachAction?) {
        guard let startRange = text.range(of: "[COACH_ACTION]"),
              let endRange = text.range(of: "[/COACH_ACTION]") else {
            return (text, nil)
        }
        
        let cleanText = (text[..<startRange.lowerBound] + text[endRange.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Проверка интента пользователя через антигаллюцинационный барьер
        guard AICoachSanityGuardrail.isIntentActionable(userQuestion: userQuestion) else {
            return (cleanText, nil)
        }
        
        let jsonSubstring = text[startRange.upperBound..<endRange.lowerBound]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let jsonData = jsonSubstring.data(using: .utf8) else {
            return (cleanText, nil)
        }
        
        do {
            let decoded = try JSONDecoder().decode(AICoachAction.self, from: jsonData)
            let sanitized = AICoachSanityGuardrail.sanitize(action: decoded, userWeight: userWeight)
            return (cleanText, sanitized)
        } catch {
            return (cleanText, nil)
        }
    }
}
