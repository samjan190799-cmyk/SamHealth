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
    
    // Центральный метод с поддержкой ротации и обмена контекстом между моделями
    private func executeRequest(prompt: String, systemPrompt: String?, image: UIImage? = nil, responseFormatJSON: Bool = false, analysisType: String? = nil) async throws -> (provider: String, text: String) {
        let defaults = UserDefaults.standard
        let geminiKey = (defaults.string(forKey: "api_key_gemini") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let openAIKey = (defaults.string(forKey: "api_key_openai") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let claudeKey = (defaults.string(forKey: "api_key_claude") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        var modifiedSystemPrompt = systemPrompt ?? ""
        if let type = analysisType,
           let lastAnalysis = defaults.string(forKey: "last_analysis_\(type)"),
           !lastAnalysis.isEmpty {
            modifiedSystemPrompt += "\n\nПредыдущие рекомендации по этому направлению (могут быть даны другой ИИ-моделью):\n\"\(lastAnalysis)\"\n\nПожалуйста, учти эти прошлые советы и при необходимости дополни или скорректируй их на основе новых данных, чтобы рекомендации дополняли друг друга."
        }
        
        var errors: [String] = []
        
        // 1. Пробуем Gemini
        if !geminiKey.isEmpty {
            do {
                let text = try await queryGemini(prompt: prompt, systemPrompt: modifiedSystemPrompt.isEmpty ? nil : modifiedSystemPrompt, image: image, apiKey: geminiKey)
                if let type = analysisType {
                    defaults.set(text, forKey: "last_analysis_\(type)")
                }
                return ("Gemini", text)
            } catch {
                errors.append("Gemini: \(error.localizedDescription)")
            }
        }
        
        // 2. Пробуем OpenAI
        if !openAIKey.isEmpty {
            do {
                let text = try await queryOpenAI(prompt: prompt, systemPrompt: modifiedSystemPrompt.isEmpty ? nil : modifiedSystemPrompt, image: image, responseFormatJSON: responseFormatJSON, apiKey: openAIKey)
                if let type = analysisType {
                    defaults.set(text, forKey: "last_analysis_\(type)")
                }
                return ("ChatGPT", text)
            } catch {
                errors.append("ChatGPT: \(error.localizedDescription)")
            }
        }
        
        // 3. Пробуем Claude
        if !claudeKey.isEmpty {
            do {
                let text = try await queryClaude(prompt: prompt, systemPrompt: modifiedSystemPrompt.isEmpty ? nil : modifiedSystemPrompt, image: image, apiKey: claudeKey)
                if let type = analysisType {
                    defaults.set(text, forKey: "last_analysis_\(type)")
                }
                return ("Claude", text)
            } catch {
                errors.append("Claude: \(error.localizedDescription)")
            }
        }
        
        let details = errors.joined(separator: "; ")
        throw NSError(
            domain: "GeminiScanService",
            code: 429,
            userInfo: [NSLocalizedDescriptionKey: "Все доступные API-ключи (Gemini/ChatGPT/Claude) превысили лимиты или не настроены в параметрах.\nДетали: \(details.isEmpty ? "ключи не введены" : details)"]
        )
    }
    
    private func queryGemini(prompt: String, systemPrompt: String?, image: UIImage?, apiKey: String) async throws -> String {
        let config = GenerationConfig(
            temperature: 0.2,
            topP: 0.95,
            topK: 40,
            candidateCount: 1,
            stopSequences: []
        )
        
        let model = GenerativeModel(
            name: "gemini-2.5-flash",
            apiKey: apiKey,
            generationConfig: config
        )
        
        let finalPrompt = (systemPrompt != nil ? "\(systemPrompt!)\n\n" : "") + prompt
        
        if let img = image {
            guard let resizedImage = resizeImage(img, targetSize: CGSize(width: 800, height: 800)),
                  let jpegData = resizedImage.jpegData(compressionQuality: 0.8) else {
                throw NSError(domain: "Gemini", code: 500, userInfo: [NSLocalizedDescriptionKey: "Ошибка сжатия картинки."])
            }
            let imagePart = ModelContent.Part.jpeg(jpegData)
            let response = try await model.generateContent(finalPrompt, imagePart)
            return response.text ?? ""
        } else {
            let response = try await model.generateContent(finalPrompt)
            return response.text ?? ""
        }
    }
    
    private func queryOpenAI(prompt: String, systemPrompt: String?, image: UIImage?, responseFormatJSON: Bool, apiKey: String) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        var messages: [[String: Any]] = []
        
        if let sysPrompt = systemPrompt {
            messages.append([
                "role": "system",
                "content": sysPrompt
            ])
        }
        
        if let img = image {
            guard let resizedImage = resizeImage(img, targetSize: CGSize(width: 800, height: 800)),
                  let jpegData = resizedImage.jpegData(compressionQuality: 0.8) else {
                throw NSError(domain: "OpenAI", code: 500, userInfo: [NSLocalizedDescriptionKey: "Ошибка сжатия картинки."])
            }
            let base64String = jpegData.base64EncodedString()
            
            messages.append([
                "role": "user",
                "content": [
                    [
                        "type": "text",
                        "text": prompt
                    ],
                    [
                        "type": "image_url",
                        "image_url": [
                            "url": "data:image/jpeg;base64,\(base64String)"
                        ]
                    ]
                ]
            ])
        } else {
            messages.append([
                "role": "user",
                "content": prompt
            ])
        }
        
        var body: [String: Any] = [
            "model": "gpt-4o",
            "messages": messages,
            "temperature": 0.2
        ]
        
        if responseFormatJSON {
            body["response_format"] = ["type": "json_object"]
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "OpenAI", code: 500, userInfo: [NSLocalizedDescriptionKey: "Не удалось получить HTTP-ответ."])
        }
        
        if httpResponse.statusCode != 200 {
            let errorText = String(data: data, encoding: .utf8) ?? "Неизвестная ошибка API"
            throw NSError(domain: "OpenAI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Код ошибки OpenAI \(httpResponse.statusCode): \(errorText)"])
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw NSError(domain: "OpenAI", code: 500, userInfo: [NSLocalizedDescriptionKey: "Не удалось распарсить ответ OpenAI."])
        }
        
        return content
    }
    
    private func queryClaude(prompt: String, systemPrompt: String?, image: UIImage?, apiKey: String) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        var contentParts: [[String: Any]] = []
        
        if let img = image {
            guard let resizedImage = resizeImage(img, targetSize: CGSize(width: 800, height: 800)),
                  let jpegData = resizedImage.jpegData(compressionQuality: 0.8) else {
                throw NSError(domain: "Claude", code: 500, userInfo: [NSLocalizedDescriptionKey: "Ошибка сжатия картинки."])
            }
            let base64String = jpegData.base64EncodedString()
            
            contentParts.append([
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": base64String
                ]
            ])
        }
        
        contentParts.append([
            "type": "text",
            "text": prompt
        ])
        
        var body: [String: Any] = [
            "model": "claude-3-7-sonnet-latest",
            "max_tokens": 2048,
            "messages": [
                [
                    "role": "user",
                    "content": contentParts
                ]
            ],
            "temperature": 0.2
        ]
        
        if let sysPrompt = systemPrompt {
            body["system"] = sysPrompt
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Claude", code: 500, userInfo: [NSLocalizedDescriptionKey: "Не удалось получить HTTP-ответ."])
        }
        
        if httpResponse.statusCode != 200 {
            let errorText = String(data: data, encoding: .utf8) ?? "Неизвестная ошибка API"
            throw NSError(domain: "Claude", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Код ошибки Claude \(httpResponse.statusCode): \(errorText)"])
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contentArray = json["content"] as? [[String: Any]],
              let firstContent = contentArray.first,
              let text = firstContent["text"] as? String else {
            throw NSError(domain: "Claude", code: 500, userInfo: [NSLocalizedDescriptionKey: "Не удалось распарсить ответ Claude."])
        }
        
        return text
    }
    
    public func scanFood(image: UIImage, language: String = "ru") async throws -> FoodScanResult {
        var langName = "русском"
        if language == "en" { langName = "английском" }
        else if language == "hy" { langName = "армянском" }
        
        let systemPrompt = "Ты диетолог. Распознай блюдо на фото. Оцени вес порции. Верни ТОЛЬКО валидный JSON с названиями и текстами на \(langName) языке: {\"dish\": \"Название\", \"weight_grams\": 200, \"calories\": 350, \"protein\": 20, \"fat\": 15, \"carbs\": 30}."
        let prompt = "Распознай это блюдо и верни его БЖУ и вес в JSON формате."
        
        let resultData = try await executeRequest(prompt: prompt, systemPrompt: systemPrompt, image: image, responseFormatJSON: true)
        let responseText = resultData.text
        
        guard let data = responseText.data(using: String.Encoding.utf8) else {
            throw NSError(domain: "GeminiScanService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Ошибка кодирования ответа ИИ."])
        }
        
        do {
            let result = try JSONDecoder().decode(FoodScanResult.self, from: data)
            return result
        } catch {
            if let extractedResult = tryAttemptJSONExtraction(from: responseText) {
                return extractedResult
            }
            throw NSError(domain: "GeminiScanService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Не удалось прочитать формат данных ИИ (\(resultData.provider)): \(responseText)"])
        }
    }
    
    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage? {
        let size = image.size
        
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        let newSize: CGSize
        if widthRatio > heightRatio {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
        }
        
        let rect = CGRect(origin: .zero, size: newSize)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let newImage = renderer.image { _ in
            image.draw(in: rect)
        }
        
        return newImage
    }
    
    private func tryAttemptJSONExtraction(from text: String) -> FoodScanResult? {
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
        language: String = "ru"
    ) async throws -> String {
        var langName = "русском"
        if language == "en" { langName = "английском" }
        else if language == "hy" { langName = "армянском" }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM"
        
        let weightStr = weightHistory.map { "\(formatter.string(from: $0.date)): \($0.weight) кг" }.joined(separator: "\n")
        let workoutsStr = workouts.map { "\(formatter.string(from: $0.date)) — \($0.type), \($0.durationMinutes) мин, \($0.caloriesBurned) ккал" }.joined(separator: "\n")
        let nutritionStr = nutrition.map { "\($0.dateString): \($0.calories) ккал" }.joined(separator: "\n")
        
        let prompt = """
        Ты персональный фитнес-аналитик и диетолог. Проанализируй динамику веса пользователя на основе его активности и питания.
        Дай краткий, понятный и мотивирующий ответ на \(langName) языке. Укажи, набрал, сбросил или сохранил вес пользователь, почему это произошло и дай 2-3 практических совета.
        
        ДАННЫЕ ПОЛЬЗОВАТЕЛЯ:
        
        История веса:
        \(weightStr.isEmpty ? "Нет записей" : weightStr)
        
        Тренировки за последние дни:
        \(workoutsStr.isEmpty ? "Нет тренировок" : workoutsStr)
        
        Калорийность питания за последние дни (потребление):
        \(nutritionStr.isEmpty ? "Нет данных о еде" : nutritionStr)
        
        Формат ответа: дружелюбный, профессиональный, без использования markdown-разметки заголовков (без # и ##), используй простые абзацы и эмодзи.
        """
        
        let result = try await executeRequest(prompt: prompt, systemPrompt: nil, image: nil, responseFormatJSON: false, analysisType: "weight")
        return result.text + "\n\n(Выполнено через \(result.provider))"
    }
    
    public func analyzeWorkouts(workouts: [WorkoutRecord], language: String = "ru") async throws -> String {
        var langName = "русском"
        if language == "en" { langName = "английском" }
        else if language == "hy" { langName = "армянском" }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM"
        
        let workoutsStr = workouts.map { "\(formatter.string(from: $0.date)) — \($0.type), \($0.durationMinutes) min, \($0.caloriesBurned) ккал" }.joined(separator: "\n")
        
        let prompt = """
        Ты персональный фитнес-тренер. Проанализируй выполненные тренировки пользователя и дай короткие практические рекомендации на \(langName) языке.
        Поддержи пользователя, укажи, хорош ли его объем нагрузок, сбалансированы ли типы активностей (кардио/силовые/йога) и предложи 2 конкретных совета по тренировкам или восстановлению.
        
        ТРЕНИРОВКИ ЗА ПОСЛЕДНИЕ ДНИ:
        \(workoutsStr.isEmpty ? "Нет записей о тренировках" : workoutsStr)
        
        Формат ответа: краткий (2-3 абзаца), дружелюбный, без заголовков markdown (без # и ##), используй простые абзацы и эмодзи.
        """
        
        let result = try await executeRequest(prompt: prompt, systemPrompt: nil, image: nil, responseFormatJSON: false, analysisType: "workouts")
        return result.text + "\n\n(Выполнено через \(result.provider))"
    }
    
    public func analyzeNutrition(nutritionHistory: [DailyNutritionRecord], language: String = "ru") async throws -> String {
        var langName = "русском"
        if language == "en" { langName = "английском" }
        else if language == "hy" { langName = "армянском" }
        
        let nutritionStr = nutritionHistory.map { "\($0.dateString): \($0.calories) ккал" }.joined(separator: "\n")
        
        let prompt = """
        Ты профессиональный диетолог и нутрициолог. Проанализируй калорийность рациона пользователя за последние дни и дай рекомендации на \(langName) языке.
        Оцени уровень калорийности, дай советы по контролю аппетита или выбору продуктов и предложи 2 практические рекомендации по улучшению питания.
        
        КАЛОРИЙНОСТЬ ПИТАНИЯ ПО ДНЯМ:
        \(nutritionStr.isEmpty ? "Нет записей о калорийности еды за последние дни" : nutritionStr)
        
        Формат ответа: краткий (2-3 абзаца), дружелюбный, без заголовков markdown (без # и ##), используй простые абзацы и эмодзи.
        """
        
        let result = try await executeRequest(prompt: prompt, systemPrompt: nil, image: nil, responseFormatJSON: false, analysisType: "nutrition")
        return result.text + "\n\n(Выполнено через \(result.provider))"
    }
    
    public func analyzeWaterIntake(consumed: Double, goal: Double, weight: Double, language: String = "ru") async throws -> String {
        var langName = "русском"
        if language == "en" { langName = "английском" }
        else if language == "hy" { langName = "армянском" }
        
        let prompt = """
        Ты специалист по здоровому образу жизни. Дай короткую консультацию по питьевому режиму пользователя на \(langName) языке.
        Пользователь сегодня выпил \(String(format: "%.0f мл", consumed)) воды из суточной цели \(String(format: "%.0f мл", goal)). Его вес составляет \(weight > 0 ? String(format: "%.1f кг", weight) : "не указан").
        
        Оцени текущий прогресс, расскажи, как вода влияет на его организм (активность суставов, выносливость на тренировках, метаболизм), и предложи один полезный совет по выработке привычки пить воду регулярно.
        
        Формат ответа: очень лаконичный (1-2 абзаца), дружелюбный, без заголовков markdown (без # и ##), используй простые абзацы и эмодзи.
        """
        
        let result = try await executeRequest(prompt: prompt, systemPrompt: nil, image: nil, responseFormatJSON: false, analysisType: "water")
        return result.text + "\n\n(Выполнено через \(result.provider))"
    }
    
    public func analyzeOverallHealth(
        steps: Int,
        waterConsumed: Double,
        waterGoal: Double,
        caloriesBurned: Double,
        activeEnergyGoal: Double,
        exerciseTime: Double,
        exerciseGoal: Double,
        caloriesConsumed: Double,
        weight: Double,
        language: String = "ru"
    ) async throws -> String {
        var langName = "русском"
        if language == "en" { langName = "английском" }
        else if language == "hy" { langName = "армянском" }
        
        let prompt = """
        Ты — виртуальный фитнес-тренер и эксперт по здоровому образу жизни Nano Health. Оцени сегодняшние показатели пользователя и дай короткий совет.
        
        ПОКАЗАТЕЛИ ЗА СЕГОДНЯ:
        - Шаги: \(steps)
        - Вода: \(String(format: "%.0f мл из %.0f мл", waterConsumed, waterGoal))
        - Потребленные калории (еда): \(String(format: "%.0f ккал", caloriesConsumed))
        - Сожженные активные калории: \(String(format: "%.0f ккал из %.0f ккал", caloriesBurned, activeEnergyGoal))
        - Время тренировок: \(String(format: "%.0f мин из %.0f мин", exerciseTime, exerciseGoal))
        - Текущий вес: \(weight > 0 ? String(format: "%.1f кг", weight) : "не указан")
        
        На основе этих данных составь емкую (2-3 предложения), бодрую и мотивирующую оценку на \(langName) языке с одним главным советом.
        Пиши дружелюбным тоном, используй эмодзи и отвечай без заголовков markdown (без # и ##).
        """
        
        let result = try await executeRequest(prompt: prompt, systemPrompt: nil, image: nil, responseFormatJSON: false, analysisType: "overall_health")
        return result.text + "\n\n(Выполнено через \(result.provider))"
    }
    
    public func generateWorkoutPlan(
        age: Int,
        height: Int,
        weight: Double,
        gender: String,
        targetWeight: Double,
        activityLevel: String,
        language: String = "ru"
    ) async throws -> String {
        var langName = "русском"
        if language == "en" { langName = "английском" }
        else if language == "hy" { langName = "армянском" }
        
        let prompt = """
        Ты — виртуальный фитнес-тренер Nano Health. Составь индивидуальную программу тренировок для пользователя на основе его профиля.
        
        ПРОФИЛЬ ПОЛЬЗОВАТЕЛЯ:
        - Пол: \(gender)
        - Возраст: \(age) лет
        - Рост: \(height) см
        - Текущий вес: \(String(format: "%.1f кг", weight))
        - Целевой вес: \(String(format: "%.1f кг", targetWeight))
        - Уровень физической активности: \(activityLevel)
        
        Напиши структурированную, конкретную тренировку (например, для дома или улицы в зависимости от целей). 
        Укажи блоки:
        1. Разминка (5-10 мин)
        2. Основная часть (список упражнений, подходы, повторения)
        3. Заминка/Растяжка (5 мин)
        4. Краткий совет от тренера по технике или восстановлению.
        
        Ответь на \(langName) языке в профессиональном и ободряющем стиле, без заголовков markdown (без символов # и ##), используй простые абзацы и эмодзи.
        """
        
        let result = try await executeRequest(prompt: prompt, systemPrompt: nil, image: nil, responseFormatJSON: false, analysisType: "workout_plan")
        return result.text + "\n\n(Выполнено через \(result.provider))"
    }
    
    public func generateNutritionPlan(
        age: Int,
        height: Int,
        weight: Double,
        gender: String,
        targetWeight: Double,
        activityLevel: String,
        recentWorkoutsSummary: String,
        language: String = "ru"
    ) async throws -> String {
        var langName = "русском"
        if language == "en" { langName = "английском" }
        else if language == "hy" { langName = "армянском" }
        
        let prompt = """
        Ты — профессиональный диетолог и нутрициолог Nano Health. Составь индивидуальный план питания на основе профиля пользователя и его физической активности.
        
        ПРОФИЛЬ ПОЛЬЗОВАТЕЛЯ:
        - Пол: \(gender)
        - Возраст: \(age) лет
        - Рост: \(height) см
        - Текущий вес: \(String(format: "%.1f кг", weight))
        - Целевой вес: \(String(format: "%.1f кг", targetWeight))
        - Уровень активности: \(activityLevel)
        
        ПОСЛЕДНИЕ НАГРУЗКИ / ТРЕНИРОВКИ:
        \(recentWorkoutsSummary)
        
        В плане питания рассчитай:
        1. Суточную норму калорий (BMR/TDEE) для его цели.
        2. Рекомендуемое соотношение БЖУ (белки, жиры, углеводы в граммах).
        3. Пример меню на 1 день (завтрак, обед, перекус, ужин).
        4. Совет по питьевому режиму и контролю веса.
        
        Ответь на \(langName) языке, без заголовков markdown (без символов # и ##), используя простые абзацы, списки и эмодзи.
        """
        
        let result = try await executeRequest(prompt: prompt, systemPrompt: nil, image: nil, responseFormatJSON: false, analysisType: "nutrition_plan")
        return result.text + "\n\n(Выполнено через \(result.provider))"
    }
}
