import SwiftUI
import Foundation
import GoogleGenerativeAI

public struct FoodScanResult: Codable {
    public let dish: String
    public let weight_grams: Double
    public let calories: Double
    public let protein: Double
    public let fat: Double
    public let carbs: Double
    
    public init(dish: String, weight_grams: Double, calories: Double, protein: Double, fat: Double, carbs: Double) {
        self.dish = dish
        self.weight_grams = weight_grams
        self.calories = calories
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
    }
}

public class GeminiScanService {
    public static let shared = GeminiScanService()
    
    private init() {}
    
    public func scanFood(image: UIImage, apiKey: String) async throws -> FoodScanResult {
        guard !apiKey.isEmpty else {
            throw NSError(domain: "GeminiScanService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Пожалуйста, введите API-ключ Gemini в настройках сканера."])
        }
        
        // Создаем модель с gemini-1.5-flash
        let config = GenerationConfig(
            temperature: 0.2,
            topP: 0.95,
            topK: 40,
            candidateCount: 1,
            stopSequences: [],
            responseMIMEType: "application/json"
        )
        
        let model = GenerativeModel(
            name: "gemini-2.5-flash",
            apiKey: apiKey,
            generationConfig: config
        )
        
        let systemPrompt = "Ты диетолог. Распознай блюдо на фото. Оцени вес порции. Верни ТОЛЬКО валидный JSON: {\"dish\": \"Название\", \"weight_grams\": 200, \"calories\": 350, \"protein\": 20, \"fat\": 15, \"carbs\": 30}."
        
        // Изменяем разрешение изображения, чтобы уменьшить размер полезной нагрузки (оптимально для API)
        guard let resizedImage = resizeImage(image, targetSize: CGSize(width: 800, height: 800)) else {
            throw NSError(domain: "GeminiScanService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Не удалось подготовить изображение к обработке."])
        }
        
        // Конвертируем изображение в JPEG Data
        guard let jpegData = resizedImage.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "GeminiScanService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Не удалось сжать изображение в JPEG."])
        }
        
        // Передаем изображение в виде бинарных данных, чтобы избежать багов внутренней конвертации в SDK
        let imagePart = ModelContent.Part.jpeg(jpegData)
        
        let response = try await model.generateContent(
            systemPrompt,
            imagePart
        )
        
        guard let responseText = response.text else {
            throw NSError(domain: "GeminiScanService", code: 500, userInfo: [NSLocalizedDescriptionKey: "ИИ вернул пустой ответ."])
        }
        
        // Парсим JSON
        guard let data = responseText.data(using: String.Encoding.utf8) else {
            throw NSError(domain: "GeminiScanService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Ошибка кодирования ответа ИИ."])
        }
        
        do {
            let result = try JSONDecoder().decode(FoodScanResult.self, from: data)
            return result
        } catch {
            // Если ИИ не вернул точный JSON, попробуем найти JSON в строке с помощью регулярного выражения
            if let extractedResult = tryAttemptJSONExtraction(from: responseText) {
                return extractedResult
            }
            throw NSError(domain: "GeminiScanService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Не удалось прочитать формат данных ИИ: \(responseText)"])
        }
    }
    
    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage? {
        let size = image.size
        
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        // Выбираем коэффициент для сохранения пропорций
        let newSize: CGSize
        if widthRatio > heightRatio {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
        }
        
        let rect = CGRect(origin: .zero, size: newSize)
        
        // Используем современный UIGraphicsImageRenderer для корректной поддержки P3 цветового профиля
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let newImage = renderer.image { _ in
            image.draw(in: rect)
        }
        
        return newImage
    }
    
    private func tryAttemptJSONExtraction(from text: String) -> FoodScanResult? {
        // Простой поиск блока JSON между фигурных скобок
        guard let openBracket = text.firstIndex(of: "{"),
              let closeBracket = text.lastIndex(of: "}") else { return nil }
        
        let jsonSubstring = text[openBracket...closeBracket]
        guard let data = String(jsonSubstring).data(using: .utf8) else { return nil }
        
        return try? JSONDecoder().decode(FoodScanResult.self, from: data)
    }
    
    public func analyzeWeightTrend(
        weightHistory: [WeightRecord],
        workouts: [WorkoutRecord],
        nutrition: [DailyNutritionRecord],
        apiKey: String
    ) async throws -> String {
        let model = GenerativeModel(
            name: "gemini-2.5-flash",
            apiKey: apiKey
        )
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM"
        
        let weightStr = weightHistory.map { "\(formatter.string(from: $0.date)): \($0.weight) кг" }.joined(separator: "\n")
        let workoutsStr = workouts.map { "\(formatter.string(from: $0.date)) — \($0.type), \($0.durationMinutes) мин, \($0.caloriesBurned) ккал" }.joined(separator: "\n")
        let nutritionStr = nutrition.map { "\($0.dateString): \($0.calories) ккал" }.joined(separator: "\n")
        
        let prompt = """
        Ты персональный фитнес-аналитик и диетолог. Проанализируй динамику веса пользователя на основе его активности и питания.
        Дай краткий, понятный и мотивирующий ответ на русском языке. Укажи, набрал, сбросил или сохранил вес пользователь, почему это произошло и дай 2-3 практических совета.
        
        ДАННЫЕ ПОЛЬЗОВАТЕЛЯ:
        
        История веса:
        \(weightStr.isEmpty ? "Нет записей" : weightStr)
        
        Тренировки за последние дни:
        \(workoutsStr.isEmpty ? "Нет тренировок" : workoutsStr)
        
        Калорийность питания за последние дни (потребление):
        \(nutritionStr.isEmpty ? "Нет данных о еде" : nutritionStr)
        
        Формат ответа: дружелюбный, профессиональный, без использования markdown-разметки заголовков (без # и ##), используй простые абзацы и эмодзи.
        """
        
        let response = try await model.generateContent(prompt)
        return response.text ?? "Не удалось получить анализ от ИИ."
    }
    
    public func analyzeWorkouts(workouts: [WorkoutRecord], apiKey: String) async throws -> String {
        let model = GenerativeModel(
            name: "gemini-2.5-flash",
            apiKey: apiKey
        )
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM"
        
        let workoutsStr = workouts.map { "\(formatter.string(from: $0.date)) — \($0.type), \($0.durationMinutes) min, \($0.caloriesBurned) ккал" }.joined(separator: "\n")
        
        let prompt = """
        Ты персональный фитнес-тренер. Проанализируй выполненные тренировки пользователя и дай короткие практические рекомендации на русском языке.
        Поддержи пользователя, укажи, хорош ли его объем нагрузок, сбалансированы ли типы активностей (кардио/силовые/йога) и предложи 2 конкретных совета по тренировкам или восстановлению.
        
        ТРЕНИРОВКИ ЗА ПОСЛЕДНИЕ ДНИ:
        \(workoutsStr.isEmpty ? "Нет записей о тренировках" : workoutsStr)
        
        Формат ответа: краткий (2-3 абзаца), дружелюбный, без заголовков markdown (без # и ##), используй простые абзацы и эмодзи.
        """
        
        let response = try await model.generateContent(prompt)
        return response.text ?? "Не удалось получить рекомендации от ИИ."
    }
    
    public func analyzeNutrition(nutritionHistory: [DailyNutritionRecord], apiKey: String) async throws -> String {
        let model = GenerativeModel(
            name: "gemini-2.5-flash",
            apiKey: apiKey
        )
        
        let nutritionStr = nutritionHistory.map { "\($0.dateString): \($0.calories) ккал" }.joined(separator: "\n")
        
        let prompt = """
        Ты профессиональный диетолог и нутрициолог. Проанализируй калорийность рациона пользователя за последние дни и дай рекомендации на русском языке.
        Оцени уровень калорийности, дай советы по контролю аппетита или выбору продуктов и предложи 2 практические рекомендации по улучшению питания.
        
        КАЛОРИЙНОСТЬ ПИТАНИЯ ПО ДНЯМ:
        \(nutritionStr.isEmpty ? "Нет записей о калорийности еды за последние дни" : nutritionStr)
        
        Формат ответа: краткий (2-3 абзаца), дружелюбный, без заголовков markdown (без # и ##), используй простые абзацы и эмодзи.
        """
        
        let response = try await model.generateContent(prompt)
        return response.text ?? "Не удалось получить рекомендации от ИИ."
    }
    
    public func analyzeWaterIntake(consumed: Double, goal: Double, weight: Double, apiKey: String) async throws -> String {
        let model = GenerativeModel(
            name: "gemini-2.5-flash",
            apiKey: apiKey
        )
        
        let prompt = """
        Ты специалист по здоровому образу жизни. Дай короткую консультацию по питьевому режиму пользователя на русском языке.
        Пользователь сегодня выпил \(String(format: "%.0f мл", consumed)) воды из суточной цели \(String(format: "%.0f мл", goal)). Его вес составляет \(weight > 0 ? String(format: "%.1f кг", weight) : "не указан").
        
        Оцени текущий прогресс, расскажи, как вода влияет на его организм (активность суставов, выносливость на тренировках, метаболизм), и предложи один полезный совет по выработке привычки пить воду регулярно.
        
        Формат ответа: очень лаконичный (1-2 абзаца), дружелюбный, без заголовков markdown (без # и ##), используй простые абзацы и эмодзи.
        """
        
        let response = try await model.generateContent(prompt)
        return response.text ?? "Не удалось получить рекомендации от ИИ."
    }
}
