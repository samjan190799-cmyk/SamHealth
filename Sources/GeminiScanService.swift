import SwiftUI
import Foundation
import Vision
import GoogleGenerativeAI

// MARK: - Нормализация ориентации фото перед передачей в нейросеть
fileprivate extension UIImage {
    func normalizedOrientation() -> UIImage {
        if imageOrientation == .up { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalized ?? self
    }
}

// MARK: - Вспомогательные методы надежного парсинга чисел из ответов LLM
fileprivate extension KeyedDecodingContainer {
    func decodeFlexibleDouble(forKey key: Key, defaultValue: Double = 0.0) -> Double {
        if let direct = try? decodeIfPresent(Double.self, forKey: key) {
            return direct
        }
        if let intVal = try? decodeIfPresent(Int.self, forKey: key) {
            return Double(intVal)
        }
        if let strVal = try? decodeIfPresent(String.self, forKey: key) {
            let sanitized = strVal
                .replacingOccurrences(of: ",", with: ".")
                .components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted)
                .joined()
            return Double(sanitized) ?? defaultValue
        }
        return defaultValue
    }
    
    func decodeFlexibleInt(forKey key: Key) -> Int? {
        if let direct = try? decodeIfPresent(Int.self, forKey: key) {
            return direct
        }
        if let dblVal = try? decodeIfPresent(Double.self, forKey: key) {
            return Int(dblVal)
        }
        if let strVal = try? decodeIfPresent(String.self, forKey: key) {
            let sanitized = strVal
                .components(separatedBy: CharacterSet.decimalDigits.inverted)
                .joined()
            return Int(sanitized)
        }
        return nil
    }
    
    func decodeFlexibleDoubleIfPresent(forKey key: Key) -> Double? {
        if let direct = try? decodeIfPresent(Double.self, forKey: key) {
            return direct
        }
        if let intVal = try? decodeIfPresent(Int.self, forKey: key) {
            return Double(intVal)
        }
        if let strVal = try? decodeIfPresent(String.self, forKey: key) {
            let sanitized = strVal
                .replacingOccurrences(of: ",", with: ".")
                .components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted)
                .joined()
            return Double(sanitized)
        }
        return nil
    }
    
    func decodeFlexibleBoolIfPresent(forKey key: Key) -> Bool? {
        if let direct = try? decodeIfPresent(Bool.self, forKey: key) {
            return direct
        }
        if let strVal = try? decodeIfPresent(String.self, forKey: key)?.lowercased() {
            if strVal == "true" || strVal == "yes" || strVal == "1" || strVal == "да" { return true }
            if strVal == "false" || strVal == "no" || strVal == "0" || strVal == "нет" { return false }
        }
        if let intVal = try? decodeIfPresent(Int.self, forKey: key) {
            return intVal != 0
        }
        return nil
    }
}

public struct FoodIngredient: Identifiable, Codable, Equatable {
    public var id: String
    public var name: String
    public var weight_grams: Double
    public var calories: Double
    public var protein: Double
    public var fat: Double
    public var carbs: Double
    public var emoji: String
    
    public init(id: String = UUID().uuidString, name: String, weight_grams: Double, calories: Double, protein: Double, fat: Double, carbs: Double, emoji: String = "🍽️") {
        self.id = id
        self.name = name
        self.weight_grams = weight_grams
        self.calories = calories
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
        self.emoji = emoji
    }
    
    enum CodingKeys: String, CodingKey {
        case name, weight_grams, calories, protein, fat, carbs, emoji
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID().uuidString
        self.name = (try? container.decodeIfPresent(String.self, forKey: .name)) ?? "Ингредиент"
        self.weight_grams = container.decodeFlexibleDouble(forKey: .weight_grams, defaultValue: 100.0)
        self.calories = container.decodeFlexibleDouble(forKey: .calories, defaultValue: 150.0)
        self.protein = container.decodeFlexibleDouble(forKey: .protein, defaultValue: 10.0)
        self.fat = container.decodeFlexibleDouble(forKey: .fat, defaultValue: 5.0)
        self.carbs = container.decodeFlexibleDouble(forKey: .carbs, defaultValue: 15.0)
        self.emoji = (try? container.decodeIfPresent(String.self, forKey: .emoji)) ?? "🍽️"
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(weight_grams, forKey: .weight_grams)
        try container.encode(calories, forKey: .calories)
        try container.encode(protein, forKey: .protein)
        try container.encode(fat, forKey: .fat)
        try container.encode(carbs, forKey: .carbs)
        try container.encode(emoji, forKey: .emoji)
    }
}

public struct FoodScanResult: Codable, Equatable {
    public var dish: String
    public var weight_grams: Double
    public var calories: Double
    public var protein: Double
    public var fat: Double
    public var carbs: Double
    public var healthScore: Int?
    public var advice: String?
    public var textureType: String?
    public var ingredients: [FoodIngredient]
    
    // Временной контекст и характеристики напитков (2026 AI Nutrition)
    public var suggestedCategory: String?
    public var isBeverage: Bool?
    public var beverageType: String?
    public var volumeMl: Double?
    public var caffeineMg: Double?
    
    // Учет посуды и отделения веса тарелки (Tare / Net Weight Detection)
    public var containerType: String?           // "Керамическая тарелка", "Глубокая миска", "Пластиковый контейнер", "Кухонные весы"
    public var tareWeightGrams: Double?          // Оценочный вес пустой посуды (~380 г)
    public var grossWeightGrams: Double?         // Общий вес с тарелкой (если взвешено на весах)
    public var isTareDeducted: Bool?             // Флаг, что вес тарелки отделен от еды
    public var visualDistinctionNotes: String?   // Примечание ИИ об отличительных признаках (самса vs эчпочмак и т.д.)
    
    // Оценка масштаба и формата крупногабаритных плодов (арбуз, дыня, пицца, кастрюля)
    public var portionFormat: String?            // "single_slice", "large_chunk", "quarter_half", "whole_fruit", "family_dish"
    public var ediblePartPercentage: Double?     // Доля съедобной части в % (например, 70% для арбуза с коркой)
    public var edibleWeightGrams: Double?        // Чистый вес съедобной мякоти
    
    public var isWatermelonOrMelon: Bool {
        let lower = dish.lowercased()
        return lower.contains("арбуз") || lower.contains("дыня") || lower.contains("watermelon") || lower.contains("melon")
    }
    
    public var isLargeFruitOrVolumetricDish: Bool {
        let lower = dish.lowercased()
        return isWatermelonOrMelon || lower.contains("тыква") || lower.contains("ананас") || weight_grams >= 700 || portionFormat == "large_chunk" || portionFormat == "quarter_half" || portionFormat == "whole_fruit"
    }
    
    public var resolvedTexture: MealTextureType {
        if let textureType, let type = MealTextureType(rawValue: textureType) {
            return type
        }
        return MealTextureType.detect(from: dish, emoji: ingredients.first?.emoji ?? "")
    }
    
    public var resolvedMealCategory: MealCategory {
        if let cat = suggestedCategory?.lowercased() {
            if cat.contains("breakfast") || cat.contains("завтрак") { return .breakfast }
            if cat.contains("lunch") || cat.contains("обед") { return .lunch }
            if cat.contains("dinner") || cat.contains("ужин") { return .dinner }
            if cat.contains("snack") || cat.contains("перекус") { return .snack }
        }
        return MealCategory.defaultForCurrentHour()
    }
    
    public var isDrinkOrBeverage: Bool {
        if let isBev = isBeverage { return isBev }
        if volumeMl != nil || caffeineMg != nil { return true }
        return BeverageType.detect(from: dish) != nil
    }
    
    public var resolvedBeverageType: BeverageType? {
        if let bType = beverageType?.lowercased() {
            switch bType {
            case "coffee": return .coffee
            case "tea": return .tea
            case "water": return .water
            case "sparklingwater", "sparkling_water": return .sparklingWater
            case "soda": return .soda
            case "sodazero", "soda_zero": return .sodaZero
            case "juice": return .juice
            case "milk", "smoothie": return .milk
            case "isotonic": return .isotonic
            case "energydrink", "energy_drink": return .energyDrink
            case "alcohol", "beer", "wine": return .alcohol
            default: break
            }
        }
        return BeverageType.detect(from: dish)
    }
    
    public init(
        dish: String,
        weight_grams: Double,
        calories: Double,
        protein: Double,
        fat: Double,
        carbs: Double,
        healthScore: Int? = nil,
        advice: String? = nil,
        textureType: String? = nil,
        ingredients: [FoodIngredient] = [],
        suggestedCategory: String? = nil,
        isBeverage: Bool? = nil,
        beverageType: String? = nil,
        volumeMl: Double? = nil,
        caffeineMg: Double? = nil,
        containerType: String? = nil,
        tareWeightGrams: Double? = nil,
        grossWeightGrams: Double? = nil,
        isTareDeducted: Bool? = nil,
        visualDistinctionNotes: String? = nil,
        portionFormat: String? = nil,
        ediblePartPercentage: Double? = nil,
        edibleWeightGrams: Double? = nil
    ) {
        self.dish = dish
        self.weight_grams = weight_grams
        self.calories = calories
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
        self.healthScore = healthScore
        self.advice = advice
        self.textureType = textureType
        self.suggestedCategory = suggestedCategory
        self.isBeverage = isBeverage
        self.beverageType = beverageType
        self.volumeMl = volumeMl
        self.caffeineMg = caffeineMg
        self.containerType = containerType
        self.tareWeightGrams = tareWeightGrams
        self.grossWeightGrams = grossWeightGrams
        self.isTareDeducted = isTareDeducted
        self.visualDistinctionNotes = visualDistinctionNotes
        self.portionFormat = portionFormat
        self.ediblePartPercentage = ediblePartPercentage
        self.edibleWeightGrams = edibleWeightGrams
        if ingredients.isEmpty {
            self.ingredients = [
                FoodIngredient(name: dish, weight_grams: weight_grams, calories: calories, protein: protein, fat: fat, carbs: carbs, emoji: "🥗")
            ]
        } else {
            self.ingredients = ingredients
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case dish, weight_grams, calories, protein, fat, carbs, healthScore, advice, textureType, ingredients
        case suggestedCategory, isBeverage, beverageType, volumeMl, caffeineMg
        case containerType, tareWeightGrams, grossWeightGrams, isTareDeducted, visualDistinctionNotes
        case portionFormat, ediblePartPercentage, edibleWeightGrams
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.dish = (try? container.decodeIfPresent(String.self, forKey: .dish)) ?? "Блюдо"
        self.weight_grams = container.decodeFlexibleDouble(forKey: .weight_grams, defaultValue: 200.0)
        self.calories = container.decodeFlexibleDouble(forKey: .calories, defaultValue: 300.0)
        self.protein = container.decodeFlexibleDouble(forKey: .protein, defaultValue: 15.0)
        self.fat = container.decodeFlexibleDouble(forKey: .fat, defaultValue: 10.0)
        self.carbs = container.decodeFlexibleDouble(forKey: .carbs, defaultValue: 35.0)
        self.healthScore = container.decodeFlexibleInt(forKey: .healthScore)
        self.advice = try? container.decodeIfPresent(String.self, forKey: .advice)
        self.textureType = try? container.decodeIfPresent(String.self, forKey: .textureType)
        self.suggestedCategory = try? container.decodeIfPresent(String.self, forKey: .suggestedCategory)
        self.isBeverage = container.decodeFlexibleBoolIfPresent(forKey: .isBeverage)
        self.beverageType = try? container.decodeIfPresent(String.self, forKey: .beverageType)
        self.volumeMl = container.decodeFlexibleDoubleIfPresent(forKey: .volumeMl)
        self.caffeineMg = container.decodeFlexibleDoubleIfPresent(forKey: .caffeineMg)
        self.containerType = try? container.decodeIfPresent(String.self, forKey: .containerType)
        self.tareWeightGrams = container.decodeFlexibleDoubleIfPresent(forKey: .tareWeightGrams)
        self.grossWeightGrams = container.decodeFlexibleDoubleIfPresent(forKey: .grossWeightGrams)
        self.isTareDeducted = container.decodeFlexibleBoolIfPresent(forKey: .isTareDeducted)
        self.visualDistinctionNotes = try? container.decodeIfPresent(String.self, forKey: .visualDistinctionNotes)
        self.portionFormat = try? container.decodeIfPresent(String.self, forKey: .portionFormat)
        self.ediblePartPercentage = container.decodeFlexibleDoubleIfPresent(forKey: .ediblePartPercentage)
        self.edibleWeightGrams = container.decodeFlexibleDoubleIfPresent(forKey: .edibleWeightGrams)
        
        let decodedIngredients = (try? container.decodeIfPresent([FoodIngredient].self, forKey: .ingredients)) ?? []
        if decodedIngredients.isEmpty {
            self.ingredients = [
                FoodIngredient(name: self.dish, weight_grams: self.weight_grams, calories: self.calories, protein: self.protein, fat: self.fat, carbs: self.carbs, emoji: "🥗")
            ]
        } else {
            self.ingredients = decodedIngredients
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(dish, forKey: .dish)
        try container.encode(weight_grams, forKey: .weight_grams)
        try container.encode(calories, forKey: .calories)
        try container.encode(protein, forKey: .protein)
        try container.encode(fat, forKey: .fat)
        try container.encode(carbs, forKey: .carbs)
        try container.encodeIfPresent(healthScore, forKey: .healthScore)
        try container.encodeIfPresent(advice, forKey: .advice)
        try container.encodeIfPresent(textureType, forKey: .textureType)
        try container.encode(ingredients, forKey: .ingredients)
        try container.encodeIfPresent(suggestedCategory, forKey: .suggestedCategory)
        try container.encodeIfPresent(isBeverage, forKey: .isBeverage)
        try container.encodeIfPresent(beverageType, forKey: .beverageType)
        try container.encodeIfPresent(volumeMl, forKey: .volumeMl)
        try container.encodeIfPresent(caffeineMg, forKey: .caffeineMg)
        try container.encodeIfPresent(containerType, forKey: .containerType)
        try container.encodeIfPresent(tareWeightGrams, forKey: .tareWeightGrams)
        try container.encodeIfPresent(grossWeightGrams, forKey: .grossWeightGrams)
        try container.encodeIfPresent(isTareDeducted, forKey: .isTareDeducted)
        try container.encodeIfPresent(visualDistinctionNotes, forKey: .visualDistinctionNotes)
        try container.encodeIfPresent(portionFormat, forKey: .portionFormat)
        try container.encodeIfPresent(ediblePartPercentage, forKey: .ediblePartPercentage)
        try container.encodeIfPresent(edibleWeightGrams, forKey: .edibleWeightGrams)
    }
}

public class GeminiScanService {
    public static let shared = GeminiScanService()
    
    /// Сервисный мастер-ключ Google Gemini по умолчанию (для PRO пользователей, квот и накопленных бонусов от рекламы Meta)
    public static var masterGeminiKey: String {
        let payload = "QVEuQWI4Uk42TDB5Ums4WDdzOS1JWm9ZVVF0Wkp4ZVNJcjVkNXBqZVdYRW9mZUdPZ0hrM2c="
        if let data = Data(base64Encoded: payload), let key = String(data: data, encoding: .utf8) {
            return key
        }
        return ""
    }
    
    // Специальный скоростной URLSession с оптимизированными таймаутами
    private static let fastSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 18.0
        config.timeoutIntervalForResource = 25.0
        config.waitsForConnectivity = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()
    
    // Иерархия моделей в порядке убывания новизны и возможностей (для авто-апгрейда)
    public static let geminiHierarchy = [
        "gemini-3.7-flash",
        "gemini-3.5-flash",
        "gemini-2.5-flash",
        "gemini-2.0-flash",
        "gemini-1.5-flash"
    ]
    
    public static let openAIHierarchy = [
        "gpt-5-mini",
        "gpt-5",
        "gpt-4.5-preview",
        "gpt-4o-mini",
        "gpt-4o"
    ]
    
    public static let claudeHierarchy = [
        "claude-3-7-sonnet-latest",
        "claude-3-5-haiku-latest",
        "claude-3-5-sonnet-latest"
    ]
    
    public var activeGeminiModel: String {
        get { UserDefaults.standard.string(forKey: "active_gemini_model") ?? "gemini-2.0-flash" }
        set { UserDefaults.standard.set(newValue, forKey: "active_gemini_model") }
    }
    
    public var activeOpenAIModel: String {
        get { UserDefaults.standard.string(forKey: "active_openai_model") ?? "gpt-4o-mini" }
        set { UserDefaults.standard.set(newValue, forKey: "active_openai_model") }
    }
    
    public var activeClaudeModel: String {
        get { UserDefaults.standard.string(forKey: "active_claude_model") ?? "claude-3-5-haiku-latest" }
        set { UserDefaults.standard.set(newValue, forKey: "active_claude_model") }
    }
    
    private init() {
        // Фоновая тихая проверка при инициализации сервиса
        discoverNewerModelsInBackground()
    }
    
    // Центральный метод с поддержкой ротации, кэша успешного провайдера и ультрабыстрого ответа
    private func executeRequest(prompt: String, systemPrompt: String?, image: UIImage? = nil, responseFormatJSON: Bool = false, analysisType: String? = nil, targetImageSize: CGSize = CGSize(width: 1024, height: 1024)) async throws -> (provider: String, text: String) {
        let defaults = UserDefaults.standard
        
        // Проверка явного согласия пользователя (Apple Guidelines 5.1.1(i) & 5.1.2(i))
        guard defaults.bool(forKey: "user_consented_to_ai_sharing") else {
            throw NSError(
                domain: "GeminiScanService",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "Требуется предварительное согласие на передачу данных в сторонний ИИ (Google Gemini API). Разрешите доступ в Настройках приложения."]
            )
        }
        
        let userGeminiKey = (defaults.string(forKey: "api_key_gemini") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let openAIKey = (defaults.string(forKey: "api_key_openai") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let claudeKey = (defaults.string(forKey: "api_key_claude") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Мастер-ключ активен, если пользователь ввел свой ключ, либо если у него есть PRO, бонусы Meta или дневная квота
        let hasEntitlement = await MainActor.run {
            SubscriptionManager.shared.isPro || 
            SubscriptionManager.shared.bonusAIScans > 0 || 
            SubscriptionManager.shared.freeScansRemainingToday > 0
        }
        
        let geminiKey = !userGeminiKey.isEmpty ? userGeminiKey : (hasEntitlement ? Self.masterGeminiKey : "")
        
        var modifiedSystemPrompt = systemPrompt ?? ""
        if let type = analysisType,
           let lastAnalysis = defaults.string(forKey: "last_analysis_\(type)"),
           !lastAnalysis.isEmpty {
            let truncated = String(lastAnalysis.prefix(400))
            modifiedSystemPrompt += "\n\nПредыдущие рекомендации (учти их):\n\"\(truncated)\""
        }
        
        // Начинаем с последнего успешно ответившего провайдера для максимальной скорости
        let lastWorking = defaults.string(forKey: "last_working_ai_provider") ?? "Gemini"
        var providerOrder: [String] = []
        if lastWorking == "ChatGPT" {
            providerOrder = ["ChatGPT", "Gemini", "Claude"]
        } else if lastWorking == "Claude" {
            providerOrder = ["Claude", "Gemini", "ChatGPT"]
        } else {
            providerOrder = ["Gemini", "ChatGPT", "Claude"]
        }
        
        var errors: [String] = []
        
        for provider in providerOrder {
            switch provider {
            case "Gemini":
                if !geminiKey.isEmpty {
                    do {
                        let text = try await queryGemini(prompt: prompt, systemPrompt: modifiedSystemPrompt.isEmpty ? nil : modifiedSystemPrompt, image: image, apiKey: geminiKey, targetImageSize: targetImageSize)
                        if let type = analysisType {
                            defaults.set(text, forKey: "last_analysis_\(type)")
                        }
                        defaults.set("Gemini", forKey: "last_working_ai_provider")
                        return ("Gemini", text)
                    } catch {
                        errors.append("Gemini: \(error.localizedDescription)")
                    }
                }
            case "ChatGPT":
                if !openAIKey.isEmpty {
                    do {
                        let text = try await queryOpenAI(prompt: prompt, systemPrompt: modifiedSystemPrompt.isEmpty ? nil : modifiedSystemPrompt, image: image, responseFormatJSON: responseFormatJSON, apiKey: openAIKey, targetImageSize: targetImageSize)
                        if let type = analysisType {
                            defaults.set(text, forKey: "last_analysis_\(type)")
                        }
                        defaults.set("ChatGPT", forKey: "last_working_ai_provider")
                        return ("ChatGPT", text)
                    } catch {
                        errors.append("ChatGPT: \(error.localizedDescription)")
                    }
                }
            case "Claude":
                if !claudeKey.isEmpty {
                    do {
                        let text = try await queryClaude(prompt: prompt, systemPrompt: modifiedSystemPrompt.isEmpty ? nil : modifiedSystemPrompt, image: image, apiKey: claudeKey, targetImageSize: targetImageSize)
                        if let type = analysisType {
                            defaults.set(text, forKey: "last_analysis_\(type)")
                        }
                        defaults.set("Claude", forKey: "last_working_ai_provider")
                        return ("Claude", text)
                    } catch {
                        errors.append("Claude: \(error.localizedDescription)")
                    }
                }
            default:
                break
            }
        }
        
        let details = errors.joined(separator: "; ")
        throw NSError(
            domain: "GeminiScanService",
            code: 429,
            userInfo: [NSLocalizedDescriptionKey: "Все доступные API-ключи (Gemini/ChatGPT/Claude) превысили лимиты или не настроены в параметрах.\nДетали: \(details.isEmpty ? "ключи не введены" : details)"]
        )
    }
    
    private func queryGemini(prompt: String, systemPrompt: String?, image: UIImage?, apiKey: String, targetImageSize: CGSize = CGSize(width: 1024, height: 1024)) async throws -> String {
        let config = GenerationConfig(
            temperature: 0.2,
            topP: 0.95,
            topK: 40,
            candidateCount: 1,
            stopSequences: []
        )
        
        // Список моделей: сначала текущая проверенная/активная, затем резервные
        var candidateModels = [activeGeminiModel]
        for m in Self.geminiHierarchy where !candidateModels.contains(m) {
            candidateModels.append(m)
        }
        
        let finalPrompt = (systemPrompt != nil ? "\(systemPrompt!)\n\n" : "") + prompt
        
        var lastError: Error?
        for modelName in candidateModels {
            do {
                let model = GenerativeModel(
                    name: modelName,
                    apiKey: apiKey,
                    generationConfig: config
                )
                
                if let img = image {
                    guard let resizedImage = resizeImage(img, targetSize: targetImageSize),
                          let jpegData = resizedImage.jpegData(compressionQuality: 0.82) else {
                        throw NSError(domain: "Gemini", code: 500, userInfo: [NSLocalizedDescriptionKey: "Ошибка сжатия картинки."])
                    }
                    let imagePart = ModelContent.Part.jpeg(jpegData)
                    let response = try await model.generateContent(finalPrompt, imagePart)
                    if let text = response.text, !text.isEmpty {
                        if modelName != activeGeminiModel {
                            activeGeminiModel = modelName
                        }
                        return text
                    }
                } else {
                    let response = try await model.generateContent(finalPrompt)
                    if let text = response.text, !text.isEmpty {
                        if modelName != activeGeminiModel {
                            activeGeminiModel = modelName
                        }
                        return text
                    }
                }
            } catch {
                lastError = error
                continue
            }
        }
        
        throw lastError ?? NSError(domain: "Gemini", code: 500, userInfo: [NSLocalizedDescriptionKey: "Не удалось получить ответ от моделей Gemini (\(candidateModels.joined(separator: ", ")))."])
    }
    
    private func queryOpenAI(prompt: String, systemPrompt: String?, image: UIImage?, responseFormatJSON: Bool, apiKey: String, targetImageSize: CGSize = CGSize(width: 1024, height: 1024)) async throws -> String {
        var candidateModels = [activeOpenAIModel]
        for m in Self.openAIHierarchy where !candidateModels.contains(m) {
            candidateModels.append(m)
        }
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        
        var messages: [[String: Any]] = []
        
        if let sysPrompt = systemPrompt {
            messages.append([
                "role": "system",
                "content": sysPrompt
            ])
        }
        
        if let img = image {
            guard let resizedImage = resizeImage(img, targetSize: targetImageSize),
                  let jpegData = resizedImage.jpegData(compressionQuality: 0.82) else {
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
        
        var lastError: Error?
        for modelName in candidateModels {
            do {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                request.timeoutInterval = 18.0
                
                var body: [String: Any] = [
                    "model": modelName,
                    "messages": messages,
                    "temperature": 0.2
                ]
                
                if responseFormatJSON {
                    body["response_format"] = ["type": "json_object"]
                }
                
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                
                let (data, response) = try await GeminiScanService.fastSession.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else { continue }
                
                if httpResponse.statusCode == 200 {
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let choices = json["choices"] as? [[String: Any]],
                          let firstChoice = choices.first,
                          let message = firstChoice["message"] as? [String: Any],
                          let content = message["content"] as? String else {
                        continue
                    }
                    if modelName != activeOpenAIModel {
                        activeOpenAIModel = modelName
                    }
                    return content
                } else {
                    let errorText = String(data: data, encoding: .utf8) ?? "Неизвестная ошибка API"
                    lastError = NSError(domain: "OpenAI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "[\(modelName)] Код \(httpResponse.statusCode): \(errorText)"])
                }
            } catch {
                lastError = error
            }
        }
        
        throw lastError ?? NSError(domain: "OpenAI", code: 500, userInfo: [NSLocalizedDescriptionKey: "Не удалось получить ответ от моделей OpenAI."])
    }
    
    private func queryClaude(prompt: String, systemPrompt: String?, image: UIImage?, apiKey: String, targetImageSize: CGSize = CGSize(width: 1024, height: 1024)) async throws -> String {
        var candidateModels = [activeClaudeModel]
        for m in Self.claudeHierarchy where !candidateModels.contains(m) {
            candidateModels.append(m)
        }
        
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        
        var contentParts: [[String: Any]] = []
        
        if let img = image {
            guard let resizedImage = resizeImage(img, targetSize: targetImageSize),
                  let jpegData = resizedImage.jpegData(compressionQuality: 0.82) else {
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
        
        var lastError: Error?
        for modelName in candidateModels {
            do {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                request.timeoutInterval = 18.0
                
                var body: [String: Any] = [
                    "model": modelName,
                    "max_tokens": 1500,
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
                
                let (data, response) = try await GeminiScanService.fastSession.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else { continue }
                
                if httpResponse.statusCode == 200 {
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let contentArray = json["content"] as? [[String: Any]],
                          let firstContent = contentArray.first,
                          let text = firstContent["text"] as? String else {
                        continue
                    }
                    if modelName != activeClaudeModel {
                        activeClaudeModel = modelName
                    }
                    return text
                } else {
                    let errorText = String(data: data, encoding: .utf8) ?? "Неизвестная ошибка API"
                    lastError = NSError(domain: "Claude", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "[\(modelName)] Код \(httpResponse.statusCode): \(errorText)"])
                }
            } catch {
                lastError = error
            }
        }
        
        throw lastError ?? NSError(domain: "Claude", code: 500, userInfo: [NSLocalizedDescriptionKey: "Не удалось получить ответ от моделей Claude."])
    }
    
    // MARK: - Фоновое авто-обнаружение и переключение на новые модели (Zero User Latency)
    
    /// Запуск тихой фоновой проверки новых моделей
    public func discoverNewerModelsInBackground(force: Bool = false) {
        let defaults = UserDefaults.standard
        let lastProbe = defaults.double(forKey: "last_ai_model_probe_time")
        let now = Date().timeIntervalSince1970
        
        // Проверяем раз в 12 часов, если не вызвано принудительно
        if !force && (now - lastProbe) < 43200 {
            return
        }
        defaults.set(now, forKey: "last_ai_model_probe_time")
        
        Task(priority: .utility) {
            _ = await performModelDiscovery()
        }
    }
    
    /// Проверяет наличие доступных более новых моделей и автоматически повышает активную модель
    public func performModelDiscovery() async -> [String: String] {
        let defaults = UserDefaults.standard
        let userGeminiKey = (defaults.string(forKey: "api_key_gemini") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let geminiKey = !userGeminiKey.isEmpty ? userGeminiKey : Self.masterGeminiKey
        let openAIKey = (defaults.string(forKey: "api_key_openai") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let claudeKey = (defaults.string(forKey: "api_key_claude") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        var upgraded: [String: String] = [:]
        
        // 1. Проверяем Gemini модели сверху вниз
        if !geminiKey.isEmpty {
            for modelName in Self.geminiHierarchy {
                if await testGeminiModel(name: modelName, apiKey: geminiKey) {
                    if self.activeGeminiModel != modelName {
                        self.activeGeminiModel = modelName
                        upgraded["Gemini"] = modelName
                        print("[AI Auto-Upgrade] 🎉 Gemini переключен на новую доступную модель: \(modelName)")
                    }
                    break
                }
            }
        }
        
        // 2. Проверяем OpenAI модели сверху вниз
        if !openAIKey.isEmpty {
            for modelName in Self.openAIHierarchy {
                if await testOpenAIModel(name: modelName, apiKey: openAIKey) {
                    if self.activeOpenAIModel != modelName {
                        self.activeOpenAIModel = modelName
                        upgraded["ChatGPT"] = modelName
                        print("[AI Auto-Upgrade] 🎉 OpenAI переключен на новую доступную модель: \(modelName)")
                    }
                    break
                }
            }
        }
        
        // 3. Проверяем Claude модели сверху вниз
        if !claudeKey.isEmpty {
            for modelName in Self.claudeHierarchy {
                if await testClaudeModel(name: modelName, apiKey: claudeKey) {
                    if self.activeClaudeModel != modelName {
                        self.activeClaudeModel = modelName
                        upgraded["Claude"] = modelName
                        print("[AI Auto-Upgrade] 🎉 Claude переключен на новую доступную модель: \(modelName)")
                    }
                    break
                }
            }
        }
        
        return upgraded
    }
    
    private func testGeminiModel(name: String, apiKey: String) async -> Bool {
        let config = GenerationConfig(temperature: 0.1, candidateCount: 1)
        let model = GenerativeModel(name: name, apiKey: apiKey, generationConfig: config)
        do {
            let res = try await model.generateContent("ping")
            return res.text != nil && !(res.text!.isEmpty)
        } catch {
            return false
        }
    }
    
    private func testOpenAIModel(name: String, apiKey: String) async -> Bool {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 8.0
        let body: [String: Any] = [
            "model": name,
            "messages": [["role": "user", "content": "ping"]],
            "max_tokens": 5
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return false }
        req.httpBody = data
        guard let (_, response) = try? await Self.fastSession.data(for: req),
              let http = response as? HTTPURLResponse else { return false }
        return http.statusCode == 200
    }
    
    private func testClaudeModel(name: String, apiKey: String) async -> Bool {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.timeoutInterval = 8.0
        let body: [String: Any] = [
            "model": name,
            "max_tokens": 5,
            "messages": [["role": "user", "content": "ping"]]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return false }
        req.httpBody = data
        guard let (_, response) = try? await Self.fastSession.data(for: req),
              let http = response as? HTTPURLResponse else { return false }
        return http.statusCode == 200
    }
    
    public func scanFood(
        image: UIImage,
        language: String = "ru",
        userHint: String? = nil,
        lidarEstimate: PlateVolumeEstimate? = nil,
        coach: AICoachPersona? = nil
    ) async throws -> FoodScanResult {
        var langName = "русском"
        if language == "en" { langName = "английском" }
        else if language == "hy" { langName = "армянском" }
        
        var hintInstruction = ""
        if let hint = userHint, !hint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            hintInstruction += "\nВАЖНО: Пользователь оставил комментарий к этому приему пищи: \"\(hint)\". Обязательно учти эти детали при оценке состава, скрытых соусов, масел или сахара."
        }
        
        if let lidar = lidarEstimate, lidar.estimatedWeightGrams > 30 {
            let lidarType = lidar.hasLiDAR ? "Аппаратный датчик Apple LiDAR (SceneDepth Mesh)" : "Оптический ARKit дальномер"
            hintInstruction += "\nФИЗИЧЕСКИЕ ДАННЫЕ 3D ДАТЧИКА (\(lidarType)):\n- Расстояние до тарелки: \(String(format: "%.2f", lidar.distanceMeters)) м\n- 3D-объем блюда: ~\(Int(lidar.estimatedVolumeCm3)) см³\n- Физическая оценка суммарного веса: ~\(Int(lidar.estimatedWeightGrams)) г (Достоверность: \(Int(lidar.confidence * 100))%)\nВНИМАНИЕ: Используй эти реальные 3D замеры для максимально точной калибровки веса порции и пропорций каждого ингредиента!"
        }
        
        let targetCoach: AICoachPersona
        if let coach {
            targetCoach = coach
        } else {
            targetCoach = await MainActor.run { AICoachManager.shared.currentCoach }
        }
        
        let now = Date()
        let hour = Calendar.current.component(.hour, from: now)
        let minute = Calendar.current.component(.minute, from: now)
        let timeString = String(format: "%02d:%02d", hour, minute)
        let currentSlot: String
        let slotCategory: String
        switch hour {
        case 5..<11:
            currentSlot = "утро (Завтрак)"
            slotCategory = "breakfast"
        case 11..<16:
            currentSlot = "день (Обед)"
            slotCategory = "lunch"
        case 16..<22:
            currentSlot = "вечер (Ужин)"
            slotCategory = "dinner"
        default:
            currentSlot = "ночь (Перекус)"
            slotCategory = "snack"
        }
        
        let systemPrompt = """
        Ты ведущий эксперт-диетолог, шеф-нутрициолог и визуальный ИИ-диагност питания в приложении Forma.
        Твой стиль и характер: персональный тренер \(targetCoach.name) (\(targetCoach.specialty)).
        
        ВРЕМЕННОЙ КОНТЕКСТ:
        - Текущее местное время: \(timeString) (\(currentSlot)).
        
        ТВОИ КЛЮЧЕВЫЕ ЗАДАЧИ:
        
        1. ВЫСОКОТОЧНАЯ КУЛИНАРНАЯ ДИФФЕРЕНЦИАЦИЯ (КРИТИЧЕСКИ ВАЖНО):
           Никогда не путай визуально схожие блюда! Тщательно анализируй геометрию, тип теста, защипы, отверстия, посыпку и начинку:
           
           * САМСА (узбекская / среднеазиатская) vs ЭЧПОЧМАК (татарский треугольник):
             - САМСА: СЛОЁНОЕ тесто (видны слои, спирали, хрустящая/глянцевая корочка, смазанная яйцом), ГЕРМЕТИЧНЫЙ защип (БЕЗ отверстия в центре!), почти всегда посыпана ЧЁРНЫМ или БЕЛЫМ КУНЖУТОМ / нигеллой (седана). Форма: треугольная, круглая, овальная или квадратная, но шов ВСЕГДА ЗАКРЫТ. Внутри: рубленое мясо с луком и зирой (кумином), тыква или сыр.
             - ЭЧПОЧМАК (треугольник): пресное, дрожжевое или песочное тесто (НЕ слоёное, гладкая матовая поверхность), строго треугольная форма с КРУГЛЫМ ОТВЕРСТИЕМ ПОСЕРЕДИНЕ (для доливания бульона), БЕЗ кунжута. Внутри: мясо кубиками, картофель кубиками и лук.
             - ЕСЛИ на фото треугольная слоёная выпечка с кунжутом и без отверстия по центру — это СТРОГО САМСА!
           
           * БЕЛЯШИ (ПЕРЕМЯЧИ) vs ПИРОЖКИ:
             - Беляш/перемяч: круглый с круглым отверстием посередине, жаренный в масле до румянца.
             - Пирожок: закрытый продолговатый (печеный или жареный).
           
           * ХАЧАПУРИ:
             - По-аджарски (лодочка с сулугуни, жидким желтком и сливочным маслом).
             - По-мегрельски (круглый с сыром внутри и сырной корочкой сверху).
             - По-имеретински (круглый закрытый, сыр только внутри).
           
           * ЧЕБУРЕК vs ЯНТЫК:
             - Чебурек: жаренный во фритюре полукруг с пузырчатым тестом.
             - Янтык: сухая сковорода без масла, смазан сливочным маслом.
           
           * МАНТЫ vs ХИНКАЛИ vs БУУЗЫ (ПОЗЫ):
             - Хинкали: характерный хвостик-узелок из теста сверху, складки (18+).
             - Манты: конверт/мешочек из тонкого теста на пару.
             - Буузы: форма юрты с круглым отверстием на верхушке.
        
        2. АНАЛИЗ ФИЗИЧЕСКОГО МАСШТАБА, ОБЪЕМА И КРУПНЫХ ПЛОДОВ / БЛЮД (КРИТИЧЕСКИ ВАЖНО):
           НЕ оценивай все подряд как маленькую стандартную порцию в 150-250 грамм!
           Оценивай РЕАЛЬНЫЙ ФИЗИЧЕСКИЙ РАЗМЕР И ОБЪЕМ объекта:
           
           * ОРИЕНТИРЫ МАСШТАБА В КАДРЕ:
             - Разделочная доска (длина ~30–40 см), кухонный нож (лезвие ~18–25 см), столовые приборы (~18–20 см), рука или ладонь человека (ладонь ~8–10 см, кисть ~18–20 см), кухонный стол или блюдо.
             - Если кусок плода или блюдо занимает большую часть разделочной доски или сопоставим по длине с ножом — это МАССИВНЫЙ ОБЪЕКТ весом 1.5 – 3+ кг!
           
           * АРБУЗ (WATERMELON) И ДЫНЯ (MELON) — СТРОГАЯ ГРАДАЦИЯ ПОРЦИЙ:
             Арбуз на 92% состоит из воды, его плотность ~1.0 г/см³ (1 литр объема = 1 кг веса!).
             - ТОНКИЙ ДЕСЕРТНЫЙ ЛОМТИК (slice): толщина 1.5–2 см, треугольник на тарелке = 150–250 г.
             - ТОЛСТЫЙ ЛОМОТЬ / СТЕЙК: полукруг толщиной 4–6 см = 500–900 г.
             - КРУПНЫЙ КУСОК / СЕКТОР (large chunk / wedge): массивный сегмент длиной 20–30 см на доске/столе = 1.5 – 2.5 кг (1500 – 2500 г)!
             - ЧЕТВЕРТЬ СРЕДНЕГО АРБУЗА (1/4 плода): = 1.8 – 3.0 кг (1800 – 3000 г).
             - ПОЛОВИНА АРБУЗА (1/2 плода): = 3.5 – 6.0 кг (3500 – 6000 г).
             - ЦЕЛЫЙ АРБУЗ: = 5.0 – 12.0 кг (5000 – 12000 г).
             
             ВНИМАНИЕ: Если на фото виден большой кусок или четверть арбуза — СТРОГО УКАЗЫВАЙ ЕГО РЕАЛЬНЫЙ ВЕС (например, 2000 г)! Категорически запрещено ставить 160 г на крупный кусок арбуза!
             
             * УЧЕТ КОРКИ И СЪЕДОБНОЙ МЯКОТИ:
               - У арбуза с коркой съедобная сочная мякоть составляет ~70% веса ("ediblePartPercentage": 70), а корка ~30%.
               - Калории считай СТРОГО по съедобной мякоти (в 100 г мякоти арбуза: 30 ккал, Белки: 0.6 г, Жиры: 0.2 г, Углеводы: 7.6 г).
               - Для куска арбуза весом 2000 г с коркой: чистый вес мякоти = 1400 г, калории мякоти = 420 ккал (Б: 8.4г, Ж: 2.8г, У: 106.4г)!
               - В "edibleWeightGrams" запиши 1400, в "weight_grams" общий вес 2000.
               - В "portionFormat" укажи "large_chunk" или "quarter_half".
           
           * ДРУГИЕ КРУПНЫЕ ОБЪЕКТЫ:
             - Целая пицца (30–35 см) = 650–900 г, 1 слайс = 100–140 г.
             - Целая птица/курица = 1.3–2.2 кг.
             - Кастрюля/сковорода блюда (плов, рагу, суп) = 1.5–3.5 кг (1 порция в тарелке = 350–450 г).
             - Целый торт/пирог = 1.0–2.5 кг.
        
        3. АНАЛИЗ ПОСУДЫ И СТРОГОЕ ОТДЕЛЕНИЕ ВЕСА ТАРЕЛКИ (TARE / NET WEIGHT):
           * Определение типа посуды:
             - "Керамическая тарелка" (~350–450 г), "Глубокая миска / супница" (~400–550 г), "Разделочная доска" (~250–500 г), "Стеклянное блюдо" (~450–650 г), "Пластиковый контейнер" (~25–45 г), "Кухонные весы" или "Без посуды".
             - Запиши тип в "containerType", вес пустой тары в "tareWeightGrams".
           
           * Кухонные весы в кадре:
             - Если на весах стоит тарелка с небольшой порцией еды (например 1 пирожок), и весы показывают 540 г: вычти тару 380 г, чистый вес еды = 160 г.
             - Если на весах или доске лежит большой кусок арбуза и показания весов около 2000–2300 г: чистый вес арбуза = ~2000 г!
             - Поле "isTareDeducted": true, если тара отделена.
        
        4. РАЗДЕЛЕНИЕ ЕДЫ И НАПИТКОВ:
           - Если НАПИТОК: "isBeverage": true, "beverageType": ("coffee", "tea", "water", "sparklingWater", "juice", "milk", "soda", "sodaZero", "isotonic", "energyDrink", "alcohol"), "volumeMl": объем в мл, "caffeineMg": кофеин.
           - Если ТВЕРДАЯ ЕДА: "isBeverage": false, "beverageType": null, "volumeMl": null, "caffeineMg": null.
        
        5. КАТЕГОРИЯ ПРИЕМА ПИЩИ ("suggestedCategory"):
           - "breakfast", "lunch", "dinner", "snack" на основе текущего времени (\(timeString), \(currentSlot)) и блюда.
        
        6. СЕГМЕНТАЦИЯ НА ИНГРЕДИЕНТЫ:
           - Раздели блюдо на ингредиенты/составляющие с точным весом и КБЖУ каждого.
        
        7. Оценка качества healthScore (1-10) и совет advice (2 предложения) в стиле тренера \(targetCoach.name) по нормам ВОЗ.
        8. Консистенция textureType: "solid_dense", "liquid_soup", "light_fresh".
        
        Все тексты и названия должны быть на \(langName) языке.\(hintInstruction)

        Верни ТОЛЬКО валидный JSON следующей структуры без лишнего текста:
        {
          "dish": "Свежий арбуз",
          "weight_grams": 2000,
          "calories": 420,
          "protein": 8.4,
          "fat": 2.8,
          "carbs": 106.4,
          "healthScore": 9,
          "advice": "Превосходный источник гидратации и антиоксиданта ликопина. Учтите высокое содержание натуральных сахаров при контроле углеводов.",
          "textureType": "light_fresh",
          "suggestedCategory": "\(slotCategory)",
          "isBeverage": false,
          "beverageType": null,
          "volumeMl": null,
          "caffeineMg": null,
          "containerType": "Разделочная доска",
          "tareWeightGrams": 350,
          "grossWeightGrams": 2350,
          "isTareDeducted": true,
          "portionFormat": "large_chunk",
          "ediblePartPercentage": 70.0,
          "edibleWeightGrams": 1400.0,
          "visualDistinctionNotes": "Определен крупный кусок свежего арбуза (~1/4 плода на разделочной доске). Общий вес ~2000 г, чистая съедобная мякоть ~1400 г (70%), корка (~600 г) исключена из расчета калорий.",
          "ingredients": [
            {
              "name": "Мякоть арбуза (съедобная часть)",
              "weight_grams": 1400,
              "calories": 420,
              "protein": 8.4,
              "fat": 2.8,
              "carbs": 106.4,
              "emoji": "🍉"
            }
          ]
        }
        """
        let prompt = "Распознай блюдо, выдели все ингредиенты с их БЖУ и верни валидный JSON."
        
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
    
    /// Распознавание состава и КБЖУ с фотографии этикетки / упаковки продукта через Gemini Vision OCR
    public func scanNutritionLabel(image: UIImage, barcode: String? = nil, language: String = "ru") async throws -> BarcodeProduct {
        var langName = "русском"
        if language == "en" { langName = "английском" }
        else if language == "hy" { langName = "армянском" }
        
        let systemPrompt = """
        Ты эксперт-диетолог и профессиональный OCR-сканер этикеток продуктов питания.
        Твоя задача — внимательно изучить фото упаковки, этикетки или таблицы пищевой ценности (КБЖУ).
        
        Извлеки следующие данные:
        - name: Название продукта (например, "Греческий йогурт 2%", "Овсяные хлопья Нежный вкус", "Творог 5%")
        - brand: Производитель или торговая марка (например, "Савушкин", "Простоквашино", "Danone"). Если не указан, оставь пустую строку.
        - servingWeightGrams: Размер стандартной порции в граммах (по умолчанию 100).
        - servingSize: Описание порции текстом (например, "100 г", "1 стакан (250 мл)", "1 упаковка (140 г)").
        - caloriesPer100g: Калорийность СТРОГО НА 100 ГРАММ / 100 МЛ (в ккал). Если указано только на всю упаковку или порцию, пересчитай на 100 г!
        - proteinPer100g: Белки на 100 г (в граммах).
        - fatPer100g: Жиры на 100 г (в граммах).
        - carbsPer100g: Углеводы на 100 г (в граммах).
        - sugarPer100g: Сахар на 100 г (если указан, иначе null).
        - fiberPer100g: Пищевые волокна/клетчатка на 100 г (если указана, иначе null).
        - sodiumPer100g: Натрий/соль на 100 г в граммах (если указана, иначе null).
        - nutriScore: Оценка пищевой ценности ("A", "B", "C", "D", "E" или null).
        - emoji: Один подходящий эмодзи для этого типа еды (например 🥛, 🧀, 🍞, 🥣, 🍫, 🍎, 🍗, 🐟).
        
        Все названия должны быть на \(langName) языке.
        
        Верни ТОЛЬКО валидный JSON строго следующей структуры без каких-либо комментариев:
        {
          "name": "Греческий йогурт 2%",
          "brand": "Савушкин",
          "servingWeightGrams": 140.0,
          "servingSize": "140 г",
          "caloriesPer100g": 66.0,
          "proteinPer100g": 8.0,
          "fatPer100g": 2.0,
          "carbsPer100g": 4.0,
          "sugarPer100g": 4.0,
          "fiberPer100g": null,
          "sodiumPer100g": 0.08,
          "nutriScore": "A",
          "emoji": "🥣"
        }
        """
        
        let prompt = "Распознай название продукта, бренд и таблицу КБЖУ на 100г с фото упаковки и верни JSON."
        let resultData = try await executeRequest(
            prompt: prompt,
            systemPrompt: systemPrompt,
            image: image,
            responseFormatJSON: true,
            analysisType: "nutrition_label",
            targetImageSize: CGSize(width: 1280, height: 1280)
        )
        let responseText = resultData.text
        
        struct LabelDTO: Codable {
            let name: String?
            let brand: String?
            let servingWeightGrams: Double?
            let servingSize: String?
            let caloriesPer100g: Double?
            let proteinPer100g: Double?
            let fatPer100g: Double?
            let carbsPer100g: Double?
            let sugarPer100g: Double?
            let fiberPer100g: Double?
            let sodiumPer100g: Double?
            let nutriScore: String?
            let emoji: String?
        }
        
        let defaultBarcode = barcode ?? "AI_\(UUID().uuidString.prefix(8))"
        
        if let data = responseText.data(using: .utf8),
           let dto = try? JSONDecoder().decode(LabelDTO.self, from: data) {
            return BarcodeProduct(
                barcode: defaultBarcode,
                name: dto.name ?? "Продукт",
                brand: dto.brand ?? "",
                servingSize: dto.servingSize ?? "\(Int(dto.servingWeightGrams ?? 100.0)) г",
                servingWeightGrams: dto.servingWeightGrams ?? 100.0,
                caloriesPer100g: max(0, dto.caloriesPer100g ?? 0),
                proteinPer100g: max(0, dto.proteinPer100g ?? 0),
                fatPer100g: max(0, dto.fatPer100g ?? 0),
                carbsPer100g: max(0, dto.carbsPer100g ?? 0),
                sugarPer100g: dto.sugarPer100g,
                fiberPer100g: dto.fiberPer100g,
                sodiumPer100g: dto.sodiumPer100g,
                nutriScore: dto.nutriScore,
                novaGroup: nil,
                imageUrl: nil,
                emoji: dto.emoji ?? "📦"
            )
        }
        
        if let open = responseText.firstIndex(of: "{"),
           let close = responseText.lastIndex(of: "}"),
           let sliceData = String(responseText[open...close]).data(using: .utf8),
           let dto = try? JSONDecoder().decode(LabelDTO.self, from: sliceData) {
            return BarcodeProduct(
                barcode: defaultBarcode,
                name: dto.name ?? "Продукт",
                brand: dto.brand ?? "",
                servingSize: dto.servingSize ?? "\(Int(dto.servingWeightGrams ?? 100.0)) г",
                servingWeightGrams: dto.servingWeightGrams ?? 100.0,
                caloriesPer100g: max(0, dto.caloriesPer100g ?? 0),
                proteinPer100g: max(0, dto.proteinPer100g ?? 0),
                fatPer100g: max(0, dto.fatPer100g ?? 0),
                carbsPer100g: max(0, dto.carbsPer100g ?? 0),
                sugarPer100g: dto.sugarPer100g,
                fiberPer100g: dto.fiberPer100g,
                sodiumPer100g: dto.sodiumPer100g,
                nutriScore: dto.nutriScore,
                novaGroup: nil,
                imageUrl: nil,
                emoji: dto.emoji ?? "📦"
            )
        }
        
        throw NSError(
            domain: "GeminiScanService",
            code: 500,
            userInfo: [NSLocalizedDescriptionKey: "Не удалось распознать таблицу КБЖУ на этикетке. Попробуйте сфотографировать при лучшем освещении."]
        )
    }
    
    /// Оффлайн-распознавание блюд через системный Apple VisionKit (работает на устройстве без интернета)
    public func scanFoodOffline(image: UIImage, language: String = "ru") async -> FoodScanResult {
        let effectiveCgImage: CGImage?
        if let cg = image.cgImage {
            effectiveCgImage = cg
        } else if let ci = image.ciImage {
            effectiveCgImage = CIContext().createCGImage(ci, from: ci.extent)
        } else {
            let renderer = UIGraphicsImageRenderer(size: image.size)
            let rendered = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: image.size))
            }
            effectiveCgImage = rendered.cgImage
        }
        
        guard let cgImage = effectiveCgImage else {
            let defaultName = language == "en" ? "Balanced Meal" : (language == "hy" ? "Հավասարակշռված ճաշ" : "Сбалансированное блюдо")
            let ing = FoodIngredient(name: defaultName, weight_grams: 300, calories: 380, protein: 22, fat: 12, carbs: 45, emoji: "🥗")
            return FoodScanResult(dish: defaultName, weight_grams: 300, calories: 380, protein: 22, fat: 12, carbs: 45, healthScore: 8, advice: "Локальный анализ блюда на устройстве.", ingredients: [ing])
        }
        
        return await withCheckedContinuation { continuation in
            let request = VNClassifyImageRequest { req, _ in
                guard let observations = req.results as? [VNClassificationObservation] else {
                    let defaultName = language == "en" ? "Healthy Meal" : (language == "hy" ? "Առողջ ճաշ" : "Сбалансированное блюдо")
                    let ing = FoodIngredient(name: defaultName, weight_grams: 300, calories: 360, protein: 20, fat: 12, carbs: 42, emoji: "🥗")
                    continuation.resume(returning: FoodScanResult(dish: defaultName, weight_grams: 300, calories: 360, protein: 20, fat: 12, carbs: 42, healthScore: 8, advice: "Оффлайн-оценка на базе VisionKit.", ingredients: [ing]))
                    return
                }
                
                // Ищем наиболее вероятную классификацию с приоритетом на еду
                let foodKeywords = ["food", "dish", "meal", "salad", "pizza", "bread", "fruit", "vegetable", "meat", "chicken", "beef", "pork", "fish", "soup", "pasta", "spaghetti", "noodle", "burger", "sandwich", "egg", "rice", "cake", "cookie", "dessert", "coffee", "tea", "cheese", "yogurt", "apple", "banana", "berry", "watermelon", "melon", "cantaloupe", "steak", "samsa", "samosa", "pastry", "pie", "turnover", "bakery", "dough", "dumpling"]
                
                let topObs = observations.first(where: { obs in
                    let lower = obs.identifier.lowercased()
                    return foodKeywords.contains(where: { lower.contains($0) })
                }) ?? observations.first(where: { $0.confidence > 0.05 })
                
                let rawIdent = (topObs?.identifier ?? "food").lowercased()
                
                // Семантический маппинг в структурированные КБЖУ и ингредиенты
                let (dishName, totalWeight, totalCal, p, f, c, emoji, ingredients): (String, Double, Double, Double, Double, Double, String, [FoodIngredient])
                
                if rawIdent.contains("watermelon") || rawIdent.contains("melon") {
                    let title = language == "en" ? "Fresh Watermelon" : "Свежий арбуз"
                    let ing1 = FoodIngredient(name: language == "en" ? "Watermelon Pulp" : "Мякоть арбуза (съедобная часть)", weight_grams: 1400, calories: 420, protein: 8.4, fat: 2.8, carbs: 106.4, emoji: "🍉")
                    (dishName, totalWeight, totalCal, p, f, c, emoji, ingredients) = (title, 2000, 420, 8.4, 2.8, 106.4, "🍉", [ing1])
                } else if rawIdent.contains("samsa") || rawIdent.contains("samosa") || rawIdent.contains("pastry") || rawIdent.contains("pie") || rawIdent.contains("turnover") {
                    let title = language == "en" ? "Samsa / Meat Pastry" : "Самса с мясом"
                    let ing1 = FoodIngredient(name: language == "en" ? "Flaky Dough" : "Слоёное тесто", weight_grams: 70, calories: 230, protein: 4, fat: 13, carbs: 24, emoji: "🥐")
                    let ing2 = FoodIngredient(name: language == "en" ? "Minced Beef with Onions" : "Рубленое мясо с луком и зирой", weight_grams: 85, calories: 180, protein: 10, fat: 11, carbs: 2, emoji: "🥩")
                    let ing3 = FoodIngredient(name: language == "en" ? "Sesame Seeds" : "Кунжут", weight_grams: 5, calories: 10, protein: 0, fat: 0, carbs: 10, emoji: "🌱")
                    (dishName, totalWeight, totalCal, p, f, c, emoji, ingredients) = (title, 160, 420, 14, 24, 36, "🥐", [ing1, ing2, ing3])
                } else if rawIdent.contains("salad") || rawIdent.contains("vegetable") {
                    let title = language == "en" ? "Fresh Vegetable Salad" : "Свежий овощной салат"
                    let ing1 = FoodIngredient(name: language == "en" ? "Mixed Greens" : "Свежие овощи и зелень", weight_grams: 200, calories: 70, protein: 3, fat: 1, carbs: 12, emoji: "🥗")
                    let ing2 = FoodIngredient(name: language == "en" ? "Olive Oil Dressing" : "Заправка / Масло", weight_grams: 20, calories: 150, protein: 0, fat: 16, carbs: 0, emoji: "🫒")
                    (dishName, totalWeight, totalCal, p, f, c, emoji, ingredients) = (title, 220, 220, 3, 17, 12, "🥗", [ing1, ing2])
                } else if rawIdent.contains("pizza") {
                    let title = language == "en" ? "Pizza" : "Пицца"
                    let ing = FoodIngredient(name: title, weight_grams: 250, calories: 580, protein: 24, fat: 22, carbs: 68, emoji: "🍕")
                    (dishName, totalWeight, totalCal, p, f, c, emoji, ingredients) = (title, 250, 580, 24, 22, 68, "🍕", [ing])
                } else if rawIdent.contains("pasta") || rawIdent.contains("spaghetti") || rawIdent.contains("noodle") {
                    let title = language == "en" ? "Pasta with Sauce" : "Паста с соусом"
                    let ing = FoodIngredient(name: title, weight_grams: 300, calories: 450, protein: 15, fat: 12, carbs: 70, emoji: "🍝")
                    (dishName, totalWeight, totalCal, p, f, c, emoji, ingredients) = (title, 300, 450, 15, 12, 70, "🍝", [ing])
                } else if rawIdent.contains("chicken") || rawIdent.contains("poultry") {
                    let title = language == "en" ? "Chicken Fillet with Garnish" : "Куриное филе с гарниром"
                    let ing1 = FoodIngredient(name: language == "en" ? "Chicken Breast" : "Куриное филе", weight_grams: 160, calories: 230, protein: 35, fat: 5, carbs: 0, emoji: "🍗")
                    let ing2 = FoodIngredient(name: language == "en" ? "Garnish" : "Сложный гарнир", weight_grams: 140, calories: 170, protein: 4, fat: 3, carbs: 32, emoji: "🍚")
                    (dishName, totalWeight, totalCal, p, f, c, emoji, ingredients) = (title, 300, 400, 39, 8, 32, "🍗", [ing1, ing2])
                } else if rawIdent.contains("beef") || rawIdent.contains("meat") || rawIdent.contains("steak") {
                    let title = language == "en" ? "Meat Dish / Steak" : "Мясное блюдо / Стейк"
                    let ing = FoodIngredient(name: title, weight_grams: 250, calories: 490, protein: 42, fat: 26, carbs: 12, emoji: "🥩")
                    (dishName, totalWeight, totalCal, p, f, c, emoji, ingredients) = (title, 250, 490, 42, 26, 12, "🥩", [ing])
                } else if rawIdent.contains("fish") || rawIdent.contains("salmon") || rawIdent.contains("seafood") {
                    let title = language == "en" ? "Fish Fillet with Side" : "Рыбное блюдо с гарниром"
                    let ing = FoodIngredient(name: title, weight_grams: 280, calories: 370, protein: 34, fat: 14, carbs: 24, emoji: "🐟")
                    (dishName, totalWeight, totalCal, p, f, c, emoji, ingredients) = (title, 280, 370, 34, 14, 24, "🐟", [ing])
                } else if rawIdent.contains("soup") {
                    let title = language == "en" ? "Hot Soup" : "Горячий суп"
                    let ing = FoodIngredient(name: title, weight_grams: 350, calories: 220, protein: 12, fat: 8, carbs: 24, emoji: "🍲")
                    (dishName, totalWeight, totalCal, p, f, c, emoji, ingredients) = (title, 350, 220, 12, 8, 24, "🍲", [ing])
                } else if rawIdent.contains("burger") {
                    let title = language == "en" ? "Burger" : "Бургер"
                    let ing = FoodIngredient(name: title, weight_grams: 250, calories: 560, protein: 26, fat: 28, carbs: 50, emoji: "🍔")
                    (dishName, totalWeight, totalCal, p, f, c, emoji, ingredients) = (title, 250, 560, 26, 28, 50, "🍔", [ing])
                } else if rawIdent.contains("sandwich") {
                    let title = language == "en" ? "Sandwich" : "Сэндвич"
                    let ing = FoodIngredient(name: title, weight_grams: 180, calories: 340, protein: 16, fat: 14, carbs: 36, emoji: "🥪")
                    (dishName, totalWeight, totalCal, p, f, c, emoji, ingredients) = (title, 180, 340, 16, 14, 36, "🥪", [ing])
                } else if rawIdent.contains("egg") || rawIdent.contains("omelet") {
                    let title = language == "en" ? "Scrambled Eggs / Omelet" : "Яичница / Омлет"
                    let ing = FoodIngredient(name: title, weight_grams: 160, calories: 250, protein: 18, fat: 16, carbs: 4, emoji: "🍳")
                    (dishName, totalWeight, totalCal, p, f, c, emoji, ingredients) = (title, 160, 250, 18, 16, 4, "🍳", [ing])
                } else if rawIdent.contains("rice") {
                    let title = language == "en" ? "Rice Dish" : "Блюдо с рисом"
                    let ing = FoodIngredient(name: title, weight_grams: 250, calories: 340, protein: 8, fat: 5, carbs: 64, emoji: "🍚")
                    (dishName, totalWeight, totalCal, p, f, c, emoji, ingredients) = (title, 250, 340, 8, 5, 64, "🍚", [ing])
                } else if rawIdent.contains("fruit") || rawIdent.contains("apple") || rawIdent.contains("banana") || rawIdent.contains("berry") {
                    let title = language == "en" ? "Fresh Fruits Plate" : "Фруктовая тарелка"
                    let ing = FoodIngredient(name: title, weight_grams: 200, calories: 130, protein: 2, fat: 1, carbs: 30, emoji: "🍎")
                    (dishName, totalWeight, totalCal, p, f, c, emoji, ingredients) = (title, 200, 130, 2, 1, 30, "🍎", [ing])
                } else if rawIdent.contains("cake") || rawIdent.contains("dessert") || rawIdent.contains("cookie") {
                    let title = language == "en" ? "Dessert / Pastry" : "Десерт / Выпечка"
                    let ing = FoodIngredient(name: title, weight_grams: 150, calories: 420, protein: 6, fat: 20, carbs: 54, emoji: "🍰")
                    (dishName, totalWeight, totalCal, p, f, c, emoji, ingredients) = (title, 150, 420, 6, 20, 54, "🍰", [ing])
                } else {
                    let readable = topObs?.identifier.replacingOccurrences(of: "_", with: " ").capitalized ?? "Блюдо"
                    let title = language == "en" ? readable : "Блюдо (\(readable))"
                    let ing = FoodIngredient(name: title, weight_grams: 250, calories: 380, protein: 22, fat: 14, carbs: 40, emoji: "🍽️")
                    (dishName, totalWeight, totalCal, p, f, c, emoji, ingredients) = (title, 250, 380, 22, 14, 40, "🍽️", [ing])
                }
                
                let adviceText = language == "en" 
                    ? "Offline meal analysis based on device neural engine." 
                    : "Анализ блюда выполнен оффлайн на базе машинного зрения Apple VisionKit."
                
                let detectedTexture = rawIdent.contains("soup") ? "liquid_soup" : ((rawIdent.contains("salad") || rawIdent.contains("fruit") || rawIdent.contains("vegetable")) ? "light_fresh" : "solid_dense")
                
                let isWatermelon = dishName.lowercased().contains("арбуз") || dishName.lowercased().contains("watermelon")
                let ediblePct: Double = isWatermelon ? 70.0 : 100.0
                let edibleWeight: Double = isWatermelon ? totalWeight * 0.7 : totalWeight
                let distinction = isWatermelon 
                    ? "Определен свежий арбуз. Расчет калорий выполнен по сочной мякоти (~70%), корка (~30%) исключена." 
                    : "Оффлайн VisionKit: чистый вес нетто (тара исключена)."
                
                continuation.resume(returning: FoodScanResult(
                    dish: dishName,
                    weight_grams: totalWeight,
                    calories: totalCal,
                    protein: p,
                    fat: f,
                    carbs: c,
                    healthScore: 8,
                    advice: adviceText,
                    textureType: detectedTexture,
                    ingredients: ingredients,
                    containerType: "Тарелка / Посуда",
                    tareWeightGrams: 380,
                    grossWeightGrams: totalWeight + 380,
                    isTareDeducted: true,
                    visualDistinctionNotes: distinction,
                    portionFormat: totalWeight >= 1000 ? "large_chunk" : "single_slice",
                    ediblePartPercentage: ediblePct,
                    edibleWeightGrams: edibleWeight
                ))
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                let defaultName = language == "en" ? "Meal" : "Прием пищи"
                let ing = FoodIngredient(name: defaultName, weight_grams: 250, calories: 320, protein: 16, fat: 10, carbs: 40, emoji: "🍽️")
                continuation.resume(returning: FoodScanResult(dish: defaultName, weight_grams: 250, calories: 320, protein: 16, fat: 10, carbs: 40, healthScore: 7, advice: "Базовый прием пищи.", ingredients: [ing]))
            }
        }
    }
    
    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage? {
        let normalizedImage = image.normalizedOrientation()
        let size = normalizedImage.size
        guard size.width > 0, size.height > 0 else { return nil }
        
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        let ratio = min(widthRatio, heightRatio, 1.0)
        
        let newSize = CGSize(width: max(1, size.width * ratio), height: max(1, size.height * ratio))
        let rect = CGRect(origin: .zero, size: newSize)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let newImage = renderer.image { _ in
            normalizedImage.draw(in: rect)
        }
        
        return newImage
    }
    
    private func tryAttemptJSONExtraction(from text: String) -> FoodScanResult? {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            if let firstNewline = cleaned.firstIndex(of: "\n") {
                cleaned = String(cleaned[firstNewline...])
            }
            if cleaned.hasSuffix("```") {
                cleaned = String(cleaned.dropLast(3))
            }
        }
        
        guard let openBracket = cleaned.firstIndex(of: "{"),
              let closeBracket = cleaned.lastIndex(of: "}") else { return nil }
        
        var jsonString = String(cleaned[openBracket...closeBracket])
        // Удаляем trailing commas перед закрывающими фигурными и квадратными скобками
        jsonString = jsonString.replacingOccurrences(of: #",\s*([\}\]])"#, with: "$1", options: .regularExpression)
        
        guard let data = jsonString.data(using: .utf8) else { return nil }
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
    
    public func askNutritionist(
        userQuestion: String,
        caloriesConsumedToday: Double,
        proteinConsumedToday: Double,
        fatConsumedToday: Double,
        carbsConsumedToday: Double,
        waterConsumedToday: Double,
        caloriesBurnedToday: Double,
        mealsSummary: String = "",
        calorieBalance: Double = 0,
        estimatedFatChangeGrams: Double = 0,
        userWeight: Double,
        userGoal: String = "Поддержание формы",
        userSomatotype: String = "mesomorph",
        userMetabolismSpeed: String = "normal",
        digestiveBalanceSummary: String = "",
        solidMealStreak: Int = 0,
        language: String = "ru"
    ) async throws -> (provider: String, answer: String) {
        var langName = "русском"
        if language == "en" { langName = "английском" }
        else if language == "hy" { langName = "армянском" }
        
        let somato = Somatotype(rawValue: userSomatotype) ?? .mesomorph
        let metab = MetabolismSpeed(rawValue: userMetabolismSpeed) ?? .normal
        
        let systemPrompt = """
        Ты элитный персональный AI-нутрициолог и диетолог в приложении Forma. Твоя задача — давать профессиональные, научно обоснованные и практичные советы по питанию, водному балансу, калорийному дефициту/профициту и макронутриентам.
        
        ФИЗИОЛОГИЧЕСКИЙ ПРОФИЛЬ ПОЛЬЗОВАТЕЛЯ:
        - Соматотип: \(somato.title)
        - Скорость метаболизма: \(metab.title)
        - Особенности организма: \(somato.shortDescription)
        - Целевое соотношение БЖУ: Углеводы \(somato.recommendedMacros.carbs)%, Белки \(somato.recommendedMacros.protein)%, Жиры \(somato.recommendedMacros.fat)%
        - Стратегия питания: \(somato.nutritionStrategyPrompt)
        
        КРИТИЧЕСКИЕ ПРАВИЛА:
        1. Всегда учитывай соматотип пользователя! 
           - Для эктоморфа/хардгейнера (быстрый метаболизм) не бойся рекомендовать повышенную калорийность, плотные сложные углеводы и перекусы.
           - Для эндоморфа (медленный обмен) следи за гликемической нагрузкой, рекомендуй смещать углеводы строго к тренировкам, делать упор на белок, клетчатку и полезные ненасыщенные жиры.
           - Для мезоморфа держи классический атлетический баланс 40/30/30.
        2. Всегда учитывай текущие показатели пользователя за сегодня: что именно он съел, его энергетический баланс и цель.
        3. Если пользователь спрашивает, сколько он набрал или сбросил жира, объясняй расчет на основе дефицита/профицита калорий (7700 ккал = ~1 кг жировой массы).
        4. КРИТИЧЕСКОЕ ПРАВИЛО БАЛАНСА ЖКТ И КОНСИСТЕНЦИИ ПИЩИ:
           Внимательно анализируй соотношение твердой/долгой пищи и жидких первых блюд (супов, бульонов).
           Если в данных зафиксировано, что пользователь ест твердую/плотную пищу (сухомятка: стейки, бургеры, паста, пицца, крупы) 2-3 и более приемов пищи подряд или давно не ел супа/бульона:
           - Обязательно предупреди о перегрузке ЖКТ: соляная кислота и ферменты работают на пределе, замедляется эвакуация из желудка, возникает риск тяжести, вялости и нарушения моторики кишечника.
           - Настоятельно рекомендуй согревающие жидкие первые блюда с медицинским обоснованием:
             * Наваристый костный бульон (глутамин, натуральный коллаген и глицин для заживления и питания эпителия кишечника);
             * Легкий куриный бульон с зеленью (легкоусвояемый белок, регидратация и снятие спазма ЖКТ);
             * Нежный овощной крем-суп (растворимая клетчатка без грубых волокон, мягкое очищение кишечника);
             * Ферментированный мисо-суп (поддержка полезного микробиома).
           - Если у пользователя баланс в норме или он регулярно ест супы, похвали за бережное отношение к органам пищеварения.
        5. НАУЧНАЯ МЕТОДОЛОГИЯ И СТАНДАРТЫ ВОЗ (World Health Organization Fact Sheet #394):
           - Всегда сверяй рацион с официальными рекомендациями Всемирной организации здравоохранения.
           - Контролируй свободные сахара: строго не более 10% от суточной калорийности (оптимально < 5%).
           - Контролируй натрий и соль: не более 5 г поваренной соли (< 2000 мг натрия) в сутки.
           - Рекомендуй норму клетчатки (пищевых волокон): не менее 25–30 г в день.
           - Напоминай о правиле 5 порций овощей и фруктов (≥ 400 г/сутки).
           - При уместности ссылайся на нормативы ВОЗ, чтобы дать пользователю научно обоснованную и авторитетную опору.
        
        Пиши вдохновляюще, понятно, используй эмодзи и давай конкретные варианты продуктов, рецептов и порций.
        Язык ответа: \(langName).
        """
        
        let balanceStr = calorieBalance < 0
            ? "Дефицит \(Int(abs(calorieBalance))) ккал (теоретически сожжено ~\(String(format: "%.0f", abs(estimatedFatChangeGrams))) г жира)"
            : (calorieBalance > 0 ? "Профицит +\(Int(calorieBalance)) ккал (теоретический прирост ~\(String(format: "%.0f", estimatedFatChangeGrams)) г)" : "Равновесие (0 ккал)")
        
        let prompt = """
        ВОПРОС ПОЛЬЗОВАТЕЛЯ:
        "\(userQuestion)"
        
        ТЕКУЩИЕ ПОКАЗАТЕЛИ ЗА СЕГОДНЯ:
        - Тип телосложения: \(somato.title) (Метаболизм: \(metab.title))
        - Потреблено калорий: \(Int(caloriesConsumedToday)) ккал (Б: \(Int(proteinConsumedToday))г, Ж: \(Int(fatConsumedToday))г, У: \(Int(carbsConsumedToday))г)
        - Энергетический баланс за сегодня: \(balanceStr)
        - Выпито воды: \(Int(waterConsumedToday)) мл
        - Активность / сожжено активных калорий: \(Int(caloriesBurnedToday)) ккал
        - Текущий вес: \(String(format: "%.1f", userWeight)) кг
        - Цель: \(userGoal)
        - Состояние ЖКТ и баланс консистенции:
        \(digestiveBalanceSummary.isEmpty ? "Анализ недавних приемов: стрик плотной пищи \(solidMealStreak) приемов подряд" : digestiveBalanceSummary)
        - Что съедено сегодня:
        \(mealsSummary.isEmpty ? "Данных о конкретных блюдах пока нет" : mealsSummary)
        
        Дай конкретный, полезный и мотивирующий ответ на \(langName) языке с акцентом на физиологию его соматотипа и баланс пищеварения.
        """
        
        let result = try await executeRequest(prompt: prompt, systemPrompt: systemPrompt, image: nil, responseFormatJSON: false, analysisType: "nutritionist_chat")
        return (result.provider, result.text)
    }
    
    public func askCoach(
        userQuestion: String,
        coach: AICoachPersona? = nil,
        todaySteps: Int,
        activeCalories: Double,
        currentHeartRate: Int,
        restingHeartRate: Int,
        sleepHours: Double,
        workoutHistorySummary: String,
        userWeight: Double,
        userGoal: String = "Форма и здоровье",
        userHeight: Int = 175,
        userAge: Int = 25,
        userGender: String = "Мужской",
        caloriesConsumedToday: Double = 0,
        proteinConsumedToday: Double = 0,
        fatConsumedToday: Double = 0,
        carbsConsumedToday: Double = 0,
        mealsTodaySummary: String = "",
        calorieBalance: Double = 0,
        estimatedFatChangeGrams: Double = 0,
        userSomatotype: String = "mesomorph",
        userMetabolismSpeed: String = "normal",
        habitsSummaryToday: String = "",
        language: String = "ru"
    ) async throws -> (provider: String, answer: String, action: AICoachAction?) {
        let targetCoach: AICoachPersona
        if let coach {
            targetCoach = coach
        } else {
            targetCoach = await MainActor.run { AICoachManager.shared.currentCoach }
        }
        var langName = "русском"
        if language == "en" { langName = "английском" }
        else if language == "hy" { langName = "армянском" }
        
        let somato = Somatotype(rawValue: userSomatotype) ?? .mesomorph
        let metab = MetabolismSpeed(rawValue: userMetabolismSpeed) ?? .normal
        
        let systemPrompt = """
        \(targetCoach.systemPromptStyle)
        Ты персональный ИИ-тренер по имени \(targetCoach.name) в приложении Forma. Твоя специализация: \(targetCoach.specialty). Девиз: \(targetCoach.tagline).
        
        ФИЗИОЛОГИЧЕСКИЙ ПРОФИЛЬ ПОЛЬЗОВАТЕЛЯ:
        - Текущий вес: \(userWeight > 0 ? String(format: "%.1f кг", userWeight) : "не указан")
        - Рост: \(userHeight) см
        - Возраст и пол: \(userAge) лет, \(userGender)
        - Целевая направленность: \(userGoal)
        - Тип телосложения (Соматотип): \(somato.title)
        - Скорость метаболизма: \(metab.title)
        - Физиологические особенности: \(somato.shortDescription)
        - Целевое соотношение БЖУ: Углеводы \(somato.recommendedMacros.carbs)%, Белки \(somato.recommendedMacros.protein)%, Жиры \(somato.recommendedMacros.fat)%
        - Стратегия питания соматотипа: \(somato.nutritionStrategyPrompt)
        - Стратегия тренировок соматотипа: \(somato.trainingStrategyPrompt)
        
        КРИТИЧЕСКИЕ ИНСТРУКЦИИ:
        1. Всегда знай и учитывай точный вес пользователя (\(userWeight > 0 ? String(format: "%.1f кг", userWeight) : "из настроек")) И ЕГО ТИП ТЕЛОСЛОЖЕНИЯ (\(somato.shortTitle), метаболизм: \(metab.shortTitle)). Обязательно давай рекомендации с акцентом на его метаболизм!
           - Если он эктоморф/хардгейнер (быстрый метаболизм) — объясняй, почему ему нужно плотно есть и не бояться сложных углеводов, ограничить изнурительное кардио;
           - Если эндоморф (экономный обмен) — делай упор на белок, клетчатку, короткий отдых между сетами и функциональные суперсеты/HIIT;
           - Если мезоморф — на классический баланс и прогрессию нагрузок.
        2. Всегда учитывай биометрические показатели пользователя (шаги, пульс, сон, тренировки) И ЕГО ПИТАНИЕ (съеденные калории, БЖУ, блюда, дефицит/профицит калорий и теоретическое изменение жировой массы).
        3. Если пользователь спрашивает, сколько он набрал или сбросил за сегодня, опирайся на его точный энергетический баланс (дефицит/профицит) и расчет расхода (1 кг жира = 7700 ккал).
        4. Если пользователь спрашивает про боли или дискомфорт, давай безопасные биомеханические альтернативы.
        5. Если пользователь плохо спал (< 6 ч), мягко рекомендуй снизить интенсивность или сделать акцент на мобильности.
        6. Обращай внимание на баланс плотной и жидкой пищи. Если в рационе доминирует долгая сухая пища без супов и первых блюд, порекомендуй согревающий бульон или легкий суп-пюре для восстановления комфорта в ЖКТ.
        7. СТАНДАРТЫ ФИЗИЧЕСКОЙ АКТИВНОСТИ И ЗДОРОВЬЯ ВОЗ (WHO 2020 Guidelines):
           - Опирайся на нормы Всемирной организации здравоохранения: 150–300 минут умеренной аэробной нагрузки или 75–150 минут высокой интенсивности в неделю, плюс минимум 2 дня силовых нагрузок.
           - Помогай пользователю грамотно распределять недельный объем активности без перетренированности.
        
        8. РАСПОЗНАВАНИЕ ТЯЖЕЛОГО ФИЗИЧЕСКОГО ТРУДА И ДЕЙСТВИЙ (COACH ACTION ENGINE):
           - Если пользователь сообщает о тяжелом ручном/бытовом труде (таскал виноград, собирал урожай, носил ящики 15-25 кг, мешки, стройка, ремонт, переезд, rucking с отягощением):
             * Понимай, что стандартный шагомер считает шаги как пустую ходьбу налегке (MET ~3.2), теряя более половины реальных сожженных калорий!
             * Перенос ящиков/груза 15–25 кг повышает MET до 6.5 – 8.0.
             * Рассчитай ДОПОЛНИТЕЛЬНЫЙ расход калорий (дельта MET × вес × часы работы).
             * Например, 30 000 шагов с ящиками винограда (~6 часов работы, ~20 км с грузом): базовая ходьба дает ~1100 ккал, а перенос груза дает еще +1500..+1700 дополнительных активных ккал (всего ~2600–2800 ккал)!
             * Обязательно похвали за колоссальную функциональную выносливость и предложи зафиксировать эту нагрузку!
           
           - КРИТИЧЕСКИЕ ПРАВИЛА ЗАЩИТЫ ОТ ГАЛЛЮЦИНАЦИЙ:
             * КАТЕГОРИЧЕСКИ ЗАПРЕЩЕНО создавать [COACH_ACTION], если пользователь задал абстрактный, познавательный или теоретический вопрос («Сколько сжигает перенос винограда?», «Полезно ли носить ящики?», «Как правильно поднимать тяжести?»). В этом случае давай только текстовый ответ БЕЗ блока [COACH_ACTION].
             * Создавай блок [COACH_ACTION] ИСКЛЮЧИТЕЛЬНО тогда, когда пользователь утверждает о СВЕРШИВШЕМСЯ ФАКТЕ своей активности («я таскал виноград, сделал 30 000 шагов», «я сегодня носил ящики», «запиши мне тяжелый труд», «я выпил 500 мл воды», «мой вес 74 кг», «я сделал вечернюю растяжку», «я приболел, заморозь стрик»).
             * Формат блока строго в самом конце ответа:
             [COACH_ACTION]
             {
               "type": "log_workout",
               "title": "Сбор и перенос винограда (Тяжелый труд)",
               "subtitle": "30 000 шагов с ящиками (~20 кг)",
               "duration_minutes": 360,
               "calories": 1650,
               "met_value": 6.8,
               "reasoning": "Перенос груза повышает расход с 3.2 до 6.8 MET на протяжении 6 часов (+1650 ккал сверх базовых шагов)"
             }
             [/COACH_ACTION]
             (Поддерживаемые type: "log_workout", "adjust_active_calories", "log_water", "log_weight", "log_meal", "mark_habit_completed", "freeze_habit")
        
        9. УПРАВЛЕНИЕ ПРИВЫЧКАМИ И СТРИКАМИ:
           - Если пользователь сообщает, что выполнил привычку («я выпил витамины», «сделал растяжку», «выпил 2.5 л воды», «отметь привычку»):
             [COACH_ACTION]
             {
               "type": "mark_habit_completed",
               "title": "Отметить привычку",
               "subtitle": "Растяжка (Выполнено)",
               "habit_title": "растяжка",
               "reasoning": "Пользователь подтвердил выполнение вечерней растяжки"
             }
             [/COACH_ACTION]
           - Если пользователь сообщает о болезни, отдыхе или просит защитить стрик («заболел, заморозь стрик», «сохрани стрик на сегодня»):
             [COACH_ACTION]
             {
               "type": "freeze_habit",
               "title": "Заморозка стрика 🧊",
               "subtitle": "Защитить стрик щитом от сгорания",
               "reasoning": "Активация защитного щита стрика при болезни/дне отдыха"
             }
             [/COACH_ACTION]
        
        Пиши четко, мотивирующе, в своей уникальной манере речи тренера \(targetCoach.name), используй эмодзи и форматируй ключевые пункты списком.
        Язык ответа: \(langName).
        """
        
        let balanceStatus = calorieBalance < 0
            ? "Дефицит: -\(Int(abs(calorieBalance))) ккал (теоретически сожжено ~\(String(format: "%.0f", abs(estimatedFatChangeGrams))) г жира)"
            : (calorieBalance > 0 ? "Профицит: +\(Int(calorieBalance)) ккал (теоретический прирост ~\(String(format: "%.0f", estimatedFatChangeGrams)) г)" : "Баланс: 0 ккал")
        
        let prompt = """
        ВОПРОС / СИТУАЦИЯ ПОЛЬЗОВАТЕЛЯ:
        "\(userQuestion)"
        
        ТЕКУЩАЯ БИОМЕТРИЯ И АКТИВНОСТЬ ЗА СЕГОДНЯ:
        - Тип телосложения: \(somato.title) (Метаболизм: \(metab.title))
        - Текущий вес: \(userWeight > 0 ? String(format: "%.1f кг", userWeight) : "не указан")
        - Рост: \(userHeight) см
        - Возраст и пол: \(userAge) лет, \(userGender)
        - Цель: \(userGoal)
        - Пройдено шагов: \(todaySteps)
        - Активные калории (спорт/шаги): \(Int(activeCalories)) ккал
        - Текущий пульс: \(currentHeartRate > 0 ? "\(currentHeartRate) уд/мин" : "не измерен")
        - Пульс покоя: \(restingHeartRate > 0 ? "\(restingHeartRate) уд/мин" : "в норме")
        - Сон за прошлую ночь: \(sleepHours > 0 ? String(format: "%.1f ч", sleepHours) : "нет данных")
        - Недавние тренировки: \(workoutHistorySummary.isEmpty ? "тренировок сегодня не зафиксировано" : workoutHistorySummary)
        
        ПРИВЫЧКИ И ДИСЦИПЛИНА НА СЕГОДНЯ:
        \(habitsSummaryToday.isEmpty ? "Привычки: нет активных записей на сегодня" : habitsSummaryToday)
        
        ПИТАНИЕ И ЭНЕРГЕТИЧЕСКИЙ БАЛАНС ЗА СЕГОДНЯ:
        - Потреблено: \(Int(caloriesConsumedToday)) ккал (Б: \(Int(proteinConsumedToday))г, Ж: \(Int(fatConsumedToday))г, У: \(Int(carbsConsumedToday))г)
        - Сальдо (Потреблено - Сожжено): \(balanceStatus)
        - Рацион за сегодня:
        \(mealsTodaySummary.isEmpty ? "Записей о блюдах за сегодня нет" : mealsTodaySummary)
        
        Дай профессиональный, персонализированный и вдохновляющий ответ от лица тренера \(targetCoach.name) на \(langName) языке с учетом его типа телосложения.
        """
        
        let result = try await executeRequest(prompt: prompt, systemPrompt: systemPrompt, image: nil, responseFormatJSON: false, analysisType: "coach_\(targetCoach.id.rawValue)_chat")
        
        let parsed = AICoachAction.parseFromResponse(
            text: result.text,
            userQuestion: userQuestion,
            userWeight: userWeight
        )
        return (result.provider, parsed.cleanText, parsed.action)
    }
    
    public func askCoachAlex(
        userQuestion: String,
        todaySteps: Int,
        activeCalories: Double,
        currentHeartRate: Int,
        restingHeartRate: Int,
        sleepHours: Double,
        workoutHistorySummary: String,
        userWeight: Double,
        userGoal: String = "Форма и здоровье",
        userSomatotype: String = "mesomorph",
        userMetabolismSpeed: String = "normal",
        language: String = "ru"
    ) async throws -> (provider: String, answer: String) {
        let res = try await askCoach(
            userQuestion: userQuestion,
            coach: nil,
            todaySteps: todaySteps,
            activeCalories: activeCalories,
            currentHeartRate: currentHeartRate,
            restingHeartRate: restingHeartRate,
            sleepHours: sleepHours,
            workoutHistorySummary: workoutHistorySummary,
            userWeight: userWeight,
            userGoal: userGoal,
            userSomatotype: userSomatotype,
            userMetabolismSpeed: userMetabolismSpeed,
            language: language
        )
        return (res.provider, res.answer)
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
    
    public func analyzeWaterIntake(consumed: Double, goal: Double, weight: Double, beveragesSummary: String? = nil, language: String = "ru") async throws -> String {
        var langName = "русском"
        if language == "en" { langName = "английском" }
        else if language == "hy" { langName = "армянском" }
        
        let bevContext = (beveragesSummary != nil && !beveragesSummary!.isEmpty)
            ? "\nСписок выпитых напитков за сегодня:\n\(beveragesSummary!)"
            : ""
        
        let prompt = """
        Ты специалист по спортивной гидратации и нутрициологии. Дай короткую консультацию по питьевому режиму пользователя на \(langName) языке.
        Пользователь сегодня потребил \(String(format: "%.0f мл", consumed)) эффективной гидратации из суточной цели \(String(format: "%.0f мл", goal)). Его вес: \(weight > 0 ? String(format: "%.1f кг", weight) : "не указан").\(bevContext)
        
        Оцени текущий прогресс, влияние выпитых напитков (например, если был кофе или кола — напомни про мочегонный эффект или скрытые калории, если изотоник — отметь восстановление электролитов) и дай 1-2 практических совета по поддержанию идеального водного баланса.
        
        Формат ответа: лаконичный (1-2 абзаца), профессиональный, дружелюбный, без заголовков markdown (без # и ##), используй простые абзацы и эмодзи.
        """
        
        let result = try await executeRequest(prompt: prompt, systemPrompt: nil, image: nil, responseFormatJSON: false, analysisType: "water")
        return result.text + "\n\n(Выполнено через \(result.provider))"
    }
    
    public func analyzeOverallHealth(
        steps: Int,
        waterConsumed: Double,
        waterGoal: Double,
        activeCalories: Double,
        activeEnergyGoal: Double,
        basalCalories: Double = 1650.0,
        totalCaloriesBurned: Double = 2100.0,
        exerciseTime: Double,
        exerciseGoal: Double,
        caloriesConsumed: Double,
        weight: Double,
        timingDetails: String? = nil,
        language: String = "ru"
    ) async throws -> String {
        var langName = "русском"
        if language == "en" { langName = "английском" }
        else if language == "hy" { langName = "армянском" }
        
        let netBalance = caloriesConsumed - totalCaloriesBurned
        let balanceStatus = netBalance < -100 ? "Дефицит калорий (\(Int(abs(netBalance))) ккал) — жиросжигание" : (netBalance > 100 ? "Профицит калорий (+\(Int(netBalance)) ккал) — анаболизм" : "Баланс калорий в равновесии")
        
        let prompt = """
        Ты — элитный персональный ИИ-тренер, биохимик и хроно-нутрициолог Forma. Проанализируй метаболизм, биометрию и тайминг приемов пищи/воды пользователя за сегодня.
        
        БИОМЕТРИЧЕСКИЕ ДАННЫЕ ИЗ APPLE HEALTH:
        - Шаги за день: \(steps)
        - Активные сожженные калории (движение): \(String(format: "%.0f ккал из %.0f ккал", activeCalories, activeEnergyGoal))
        - Пассивные калории покоя (Базовый обмен BMR): \(String(format: "%.0f ккал", basalCalories))
        - Полный суточный расход энергии (TDEE = Активные + Пассивные): \(String(format: "%.0f ккал", totalCaloriesBurned))
        - Потреблено калорий с пищей: \(String(format: "%.0f ккал", caloriesConsumed))
        - Энергетический статус: \(balanceStatus)
        - Водный баланс: \(String(format: "%.0f мл из %.0f мл", waterConsumed, waterGoal))
        - Время тренировок: \(String(format: "%.0f мин из %.0f мин", exerciseTime, exerciseGoal))
        - Текущий вес: \(weight > 0 ? String(format: "%.1f кг", weight) : "не указан")
        \(timingDetails != nil ? "- Хронология приемов пищи и гидратации за день:\n\(timingDetails!)" : "")
        
        ТВОЯ ЗАДАЧА:
        1. Оцени соотношение активного и пассивного расхода калорий и текущий энергобаланс.
        2. Проанализируй тайминг (время добавления еды и воды): своевременность гидратации, интервалы между приемами пищи и влияние на метаболизм и пищеварение.
        3. Дай бодрую оценку активности и 1 ключевой шаг прямо сейчас (например, время для следующего стакана воды или перекуса).
        
        Формат ответа: 2-3 емких, понятных абзаца, живой и мотивирующий тон, используй подходящие эмодзи, без заголовков markdown (# или ##).
        """
        
        let result = try await executeRequest(prompt: prompt, systemPrompt: nil, image: nil, responseFormatJSON: false, analysisType: "overall_health")
        return result.text + "\n\n(Выполнено через \(result.provider))"
    }
    
    // MARK: - Интеллектуальный анализ активности, тренировок и дефицита калорий
    public func generateActivityAndDeficitRecommendation(
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
        somatotype: String,
        metabolismSpeed: String,
        coach: AICoachPersona,
        language: String = "ru"
    ) async -> AIDeficitRecommendation {
        var langName = "русском"
        if language == "en" { langName = "английском" }
        else if language == "hy" { langName = "армянском" }
        
        let somatoObj = Somatotype(rawValue: somatotype) ?? .mesomorph
        let metabObj = MetabolismSpeed(rawValue: metabolismSpeed) ?? .normal
        
        let workoutsSummaryText = workouts.isEmpty 
            ? "Сегодня тренировок пока не зафиксировано" 
            : workouts.map { "\($0.type) (\($0.durationMinutes) мин, \(Int($0.caloriesBurned)) ккал)" }.joined(separator: ", ")
        
        let actualDeficit = Int(totalEnergyBurned - caloriesConsumed)
        let effectiveTargetWeight = targetWeight > 30 ? targetWeight : weight
        let isWeightLoss = effectiveTargetWeight < weight - 0.5
        let targetDeficit = isWeightLoss ? max(350, min(650, Int(totalEnergyBurned * 0.20))) : (effectiveTargetWeight > weight + 0.5 ? -250 : 0)
        
        let systemPrompt = """
        \(coach.systemPromptStyle)
        Ты персональный ИИ-тренер и спортивный физиолог \(coach.name) в приложении Forma.
        Твоя специализация: \(coach.specialty). Девиз: \(coach.tagline).
        
        ТВОЯ ЗАДАЧА:
        Проанализировать дневную двигательную активность, пройденные шаги, выполненные тренировки, расход энергии (TDEE = Базовый BMR + Активные калории) и потребленные калории/БЖУ.
        На основе этих данных рассчитать точный энергетический дефицит/профицит и выдать научно обоснованный вердикт по питанию и активности на остаток дня.
        
        ФИЗИОЛОГИЧЕСКИЙ ПРОФИЛЬ ПОЛЬЗОВАТЕЛЯ:
        - Текущий вес: \(String(format: "%.1f", weight)) кг (Целевой: \(String(format: "%.1f", effectiveTargetWeight)) кг)
        - Рост: \(height) см, Возраст: \(age) лет, Пол: \(gender)
        - Соматотип: \(somatoObj.title) (Метаболизм: \(metabObj.title))
        - Стратегия питания: \(somatoObj.nutritionStrategyPrompt)
        
        ТЕКУЩИЕ ДАННЫЕ ЗА СЕГОДНЯ:
        - Шаги: \(steps) (\(String(format: "%.2f", distanceKm)) км)
        - Выполненные тренировки: \(workoutsSummaryText)
        - Сожжено активных калорий (спорт + бытовая активность): \(Int(activeCalories)) ккал
        - Базовый обмен веществ BMR: \(Int(basalCalories)) ккал
        - Суммарный суточный расход энергии (TDEE): \(Int(totalEnergyBurned)) ккал
        - Потреблено калорий с пищей: \(Int(caloriesConsumed)) ккал (Белки: \(Int(protein))г, Жиры: \(Int(fat))г, Углеводы: \(Int(carbs))г)
        - Текущий дефицит/профицит (Расход - Потребление): \(actualDeficit >= 0 ? "Дефицит \(actualDeficit) ккал" : "Профицит \(abs(actualDeficit)) ккал")
        - Целевой безопасный дефицит по ВОЗ: \(targetDeficit >= 0 ? "\(targetDeficit) ккал" : "Профицит \(abs(targetDeficit)) ккал")
        
        КРИТИЧЕСКИЕ ТРЕБОВАНИЯ:
        1. Все тексты строго на \(langName) языке.
        2. Верни ТОЛЬКО валидный JSON следующей структуры:
        {
          "title": "Краткий емкий заголовок статуса дефицита",
          "statusBadge": "Дефицит: -450 ккал",
          "statusColorName": "green",
          "calorieBudgetRemaining": 350,
          "targetDeficitKcal": \(targetDeficit),
          "currentDeficitKcal": \(actualDeficit),
          "shortAdvice": "Совет из 1-2 предложений с акцентом на шаги и ужин для пуш-уведомления.",
          "detailedAdvice": "Подробный разбор от тренера \(coach.name) с объяснением расхода энергии, влияния тренировок и соматотипа.",
          "actionSteps": [
            "Конкретный шаг 1",
            "Конкретный шаг 2",
            "Конкретный шаг 3"
          ]
        }
        """
        
        let prompt = "Рассчитай рекомендацию по дефициту калорий с учетом шагов, тренировок и соматотипа. Верни валидный JSON."
        
        do {
            let resultData = try await executeRequest(prompt: prompt, systemPrompt: systemPrompt, image: nil, responseFormatJSON: true, analysisType: "activity_deficit")
            let text = resultData.text
            
            struct DeficitDTO: Codable {
                let title: String?
                let statusBadge: String?
                let statusColorName: String?
                let calorieBudgetRemaining: Int?
                let targetDeficitKcal: Int?
                let currentDeficitKcal: Int?
                let shortAdvice: String?
                let detailedAdvice: String?
                let actionSteps: [String]?
            }
            
            let jsonString: String
            if let open = text.firstIndex(of: "{"), let close = text.lastIndex(of: "}") {
                jsonString = String(text[open...close])
            } else {
                jsonString = text
            }
            
            if let data = jsonString.data(using: .utf8),
               let dto = try? JSONDecoder().decode(DeficitDTO.self, from: data) {
                return AIDeficitRecommendation(
                    title: dto.title ?? "Анализ дефицита калорий",
                    statusBadge: dto.statusBadge ?? (actualDeficit >= 0 ? "Дефицит: -\(actualDeficit) ккал" : "Профицит: +\(abs(actualDeficit)) ккал"),
                    statusColorName: dto.statusColorName ?? (actualDeficit >= 0 ? "green" : "orange"),
                    calorieBudgetRemaining: dto.calorieBudgetRemaining ?? max(0, Int(totalEnergyBurned - Double(targetDeficit) - caloriesConsumed)),
                    targetDeficitKcal: dto.targetDeficitKcal ?? targetDeficit,
                    currentDeficitKcal: dto.currentDeficitKcal ?? actualDeficit,
                    shortAdvice: dto.shortAdvice ?? "Отличная активность! Продолжайте контролировать рацион.",
                    detailedAdvice: dto.detailedAdvice ?? "Тренер \(coach.name) зафиксировал вашу активность.",
                    actionSteps: dto.actionSteps ?? ["Держите водный баланс", "Зафиксируйте вечерний прием пищи"],
                    stepsCount: steps,
                    activeCaloriesBurned: activeCalories,
                    basalCaloriesBurned: basalCalories,
                    totalCaloriesBurned: totalEnergyBurned,
                    caloriesConsumed: caloriesConsumed,
                    workoutsCount: workouts.count,
                    workoutsSummary: workoutsSummaryText,
                    generatedAt: Date(),
                    provider: "\(resultData.provider)"
                )
            }
        } catch {
            print("[GeminiScanService] generateActivityAndDeficitRecommendation fallback to local engine: \(error.localizedDescription)")
        }
        
        // Надежный автономный локальный движок при ошибках сети/API
        return AIDeficitRecommendation.computeLocalFallback(
            steps: steps,
            distanceKm: distanceKm,
            activeCalories: activeCalories,
            basalCalories: basalCalories,
            totalEnergyBurned: totalEnergyBurned,
            caloriesConsumed: caloriesConsumed,
            protein: protein,
            fat: fat,
            carbs: carbs,
            workouts: workouts,
            weight: weight,
            targetWeight: targetWeight,
            height: height,
            age: age,
            gender: gender,
            somatotypeRaw: somatotype,
            coach: coach,
            language: language
        )
    }
    
    public func analyzeActivityTrends(
        daysCount: Int,
        totalSteps: Int,
        avgDailySteps: Int,
        totalCalories: Double,
        totalDistanceKm: Double,
        bestDaySteps: Int,
        language: String = "ru"
    ) async throws -> String {
        var langName = "русском"
        if language == "en" { langName = "английском" }
        else if language == "hy" { langName = "армянском" }
        
        let prompt = """
        Ты персональный ИИ-тренер Forma. Проанализируй активность пользователя за последние \(daysCount) дней.
        
        ПОКАЗАТЕЛИ ЗА ПЕРИОД:
        - Всего пройдено шагов: \(totalSteps) (в среднем \(avgDailySteps) шагов в день)
        - Суммарно сожжено активных калорий: \(Int(totalCalories)) ккал
        - Пройденная дистанция: \(String(format: "%.1f", totalDistanceKm)) км
        - Рекорд за день: \(bestDaySteps) шагов
        
        ДАЙ ОЦЕНКУ:
        1. Динамики выносливости и регулярности движения.
        2. Одно главное предостережение или рекомендацию по прогрессии на следующую неделю.
        
        Формат: 2 лаконичных абзаца, живой и мотивирующий тон, используй эмодзи, без заголовков (#).
        """
        let result = try await executeRequest(prompt: prompt, systemPrompt: nil, image: nil, responseFormatJSON: false, analysisType: "trends")
        return result.text + "\n\n(Выполнено через \(result.provider))"
    }
    
    public func generateWorkoutPlan(
        age: Int,
        height: Int,
        weight: Double,
        gender: String,
        targetWeight: Double,
        activityLevel: String,
        somatotype: String = "mesomorph",
        metabolismSpeed: String = "normal",
        language: String = "ru"
    ) async throws -> String {
        var langName = "русском"
        if language == "en" { langName = "английском" }
        else if language == "hy" { langName = "армянском" }
        
        let somato = Somatotype(rawValue: somatotype) ?? .mesomorph
        let metab = MetabolismSpeed(rawValue: metabolismSpeed) ?? .normal
        
        let prompt = """
        Ты — виртуальный фитнес-тренер Forma. Составь индивидуальную программу тренировок для пользователя на основе его профиля и соматотипа.
        
        ПРОФИЛЬ ПОЛЬЗОВАТЕЛЯ:
        - Пол: \(gender)
        - Возраст: \(age) лет
        - Рост: \(height) см
        - Текущий вес: \(String(format: "%.1f кг", weight))
        - Целевой вес: \(String(format: "%.1f кг", targetWeight))
        - Уровень физической активности: \(activityLevel)
        - Соматотип: \(somato.title)
        - Метаболизм: \(metab.title)
        - Стратегия тренировок под этот тип: \(somato.trainingStrategyPrompt)
        
        Напиши структурированную, конкретную тренировку (например, для дома или улицы в зависимости от целей). 
        Укажи блоки:
        1. Разминка (5-10 мин)
        2. Основная часть (список упражнений, подходы, повторения, время отдыха между сетами с учетом соматотипа)
        3. Заминка/Растяжка (5 мин)
        4. Краткий совет от тренера по технике, восстановлению и адаптации под \(somato.shortTitle).
        
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
        somatotype: String = "mesomorph",
        metabolismSpeed: String = "normal",
        language: String = "ru"
    ) async throws -> String {
        var langName = "русском"
        if language == "en" { langName = "английском" }
        else if language == "hy" { langName = "армянском" }
        
        let somato = Somatotype(rawValue: somatotype) ?? .mesomorph
        let metab = MetabolismSpeed(rawValue: metabolismSpeed) ?? .normal
        
        let prompt = """
        Ты — профессиональный диетолог и нутрициолог Forma. Составь индивидуальный план питания на основе профиля пользователя, соматотипа и его физической активности.
        
        ПРОФИЛЬ ПОЛЬЗОВАТЕЛЯ:
        - Пол: \(gender)
        - Возраст: \(age) лет
        - Рост: \(height) см
        - Текущий вес: \(String(format: "%.1f кг", weight))
        - Целевой вес: \(String(format: "%.1f кг", targetWeight))
        - Уровень активности: \(activityLevel)
        - Соматотип: \(somato.title)
        - Скорость метаболизма: \(metab.title)
        - Особенности физиологии: \(somato.shortDescription)
        - Целевой баланс БЖУ: Углеводы \(somato.recommendedMacros.carbs)%, Белки \(somato.recommendedMacros.protein)%, Жиры \(somato.recommendedMacros.fat)%
        - Стратегия питания под тип: \(somato.nutritionStrategyPrompt)
        
        ПОСЛЕДНИЕ НАГРУЗКИ / ТРЕНИРОВКИ:
        \(recentWorkoutsSummary)
        
        В плане питания рассчитай:
        1. Суточную норму калорий с учетом метаболического коэффициента соматотипа (BMR * \(String(format: "%.2f", somato.metabolismMultiplier))).
        2. Рекомендуемое соотношение БЖУ (белки, жиры, углеводы в граммах под соматотип).
        3. Пример меню на 1 день (завтрак, обед, перекус, ужин) с акцентом на скорость усвоения нутриентов.
        4. Совет по питьевому режиму, контролю сахара в крови и веса.
        
        Ответь на \(langName) языке, без заголовков markdown (без символов # и ##), используя простые абзацы, списки и эмодзи.
        """
        
        let result = try await executeRequest(prompt: prompt, systemPrompt: nil, image: nil, responseFormatJSON: false, analysisType: "nutrition_plan")
        return result.text + "\n\n(Выполнено через \(result.provider))"
    }
    
    // MARK: - ИИ-Анализ привычек и дисциплины
    public func analyzeHabitsAndDiscipline(
        habits: [HabitItem],
        todaySteps: Int,
        waterConsumed: Double,
        sleepHours: Double,
        workoutHistorySummary: String = "",
        coach: AICoachPersona? = nil,
        language: String = "ru"
    ) async throws -> String {
        var langName = "русском"
        if language == "en" { langName = "английском" }
        else if language == "hy" { langName = "армянском" }
        
        let targetCoach: AICoachPersona
        if let coach {
            targetCoach = coach
        } else {
            targetCoach = await MainActor.run { AICoachManager.shared.currentCoach }
        }
        
        var habitsDescription = ""
        for h in habits {
            if h.type == .quit {
                habitsDescription += "• [Отказ от вредной привычки]: '\(h.title)' — Стрик: \(h.cleanStreakDays) дней без срывов. Сдержался при позывах: \(h.urgeResistedCount) раз. Сегодня: \(h.isCompletedToday ? "Сдержался ✅" : "Еще не отмечено ⏳")\n"
            } else {
                habitsDescription += "• [Полезная привычка]: '\(h.title)' — Стрик: \(h.buildStreakDays) дн. Сегодня: \(h.isCompletedToday ? "Выполнено ✅" : "Не выполнено ❌")\n"
            }
        }
        
        let prompt = """
        Ты персональный ИИ-тренер и ментальный наставник \(targetCoach.name) в приложении Forma.
        Твоя специализация: \(targetCoach.specialty). Девиз: \(targetCoach.tagline).
        
        Проанализируй текущую дисциплину пользователя, его полезные привычки и прогресс отказа от вредных привычек.
        
        ДАННЫЕ ПРИВЫЧЕК И ДИСЦИПЛИНЫ:
        \(habitsDescription.isEmpty ? "Привычки пока не добавлены" : habitsDescription)
        
        ДАННЫЕ АКТИВНОСТИ И ВОССТАНОВЛЕНИЯ:
        - Шаги за сегодня: \(todaySteps)
        - Выпито воды: \(Int(waterConsumed)) мл
        - Сон: \(String(format: "%.1f ч", sleepHours))
        - Последние тренировки: \(workoutHistorySummary.isEmpty ? "Нет данных" : workoutHistorySummary)
        
        ТРЕБОВАНИЯ К ОТВЕТУ:
        1. Оцени текущий прогресс, похвали за удержание чистых стриков и выполнение полезных привычек.
        2. Дай глубокий психологический/физиологический совет: как избежать срывов при отказе от вредных привычек (работа с триггерами, дофамином, стрессом).
        3. Дай 2 конкретных практических шага на сегодня и завтра для укрепления дисциплины.
        4. Ответь в своем фирменном стиле тренера (\(targetCoach.name)), на \(langName) языке, лаконично (3-4 абзаца), без заголовков markdown (без # и ##), используй эмодзи и абзацы.
        """
        
        let result = try await executeRequest(prompt: prompt, systemPrompt: targetCoach.systemPromptStyle, image: nil, responseFormatJSON: false, analysisType: "habits_analysis")
        return result.text + "\n\n(Анализ от тренера \(targetCoach.name) • \(result.provider))"
    }

    public func getHabitStrategyAdvice(
        habit: HabitItem,
        coach: AICoachPersona? = nil,
        language: String = "ru"
    ) async throws -> String {
        var langName = "русском"
        if language == "en" { langName = "английском" }
        else if language == "hy" { langName = "армянском" }
        
        let targetCoach: AICoachPersona
        if let coach {
            targetCoach = coach
        } else {
            targetCoach = await MainActor.run { AICoachManager.shared.currentCoach }
        }
        
        let habitTypeDesc = habit.type == .quit ? "отказаться от вредной привычки '\(habit.title)' (чистый стрик: \(habit.cleanStreakDays) дн.)" : "закрепить полезную привычку '\(habit.title)' (стрик: \(habit.buildStreakDays) дн.)"
        
        let prompt = """
        Ты персональный ИИ-тренер и ментальный наставник \(targetCoach.name).
        Пользователь хочет \(habitTypeDesc).
        
        Дай конкретное пошаговое руководство:
        1. Психологическая механика: почему возникает эта привычка / триггер (стресс, скука, поиск дофамина, автоматизм).
        2. Техника «Замена петли привычки»: чем экологично заменить действие в момент импульса.
        3. Микро-прием экстренной выдержки (дыхание, кинестетический якорь, переключение внимания).
        
        Ответь на \(langName) языке, дружелюбно, структурированно по пунктам, без символов # и ##.
        """
        
        let result = try await executeRequest(prompt: prompt, systemPrompt: targetCoach.systemPromptStyle, image: nil, responseFormatJSON: false, analysisType: "habit_advice")
        return result.text + "\n\n(Совет от тренера \(targetCoach.name) • \(result.provider))"
    }

    // MARK: - ИИ-Перепроверка и калибровка параметров тела, воды и калорий
    public func auditAndCalibrateProfile(
        gender: String,
        age: Int,
        height: Int,
        weight: Double,
        targetWeight: Double,
        activityLevel: String,
        somatotype: String,
        metabolismSpeed: String,
        language: String = "ru"
    ) async throws -> AIBodyCalibrationResult {
        var langName = "русском"
        if language == "en" { langName = "английском" }
        else if language == "hy" { langName = "армянском" }
        
        let somato = Somatotype(rawValue: somatotype) ?? .mesomorph
        let metab = MetabolismSpeed(rawValue: metabolismSpeed) ?? .normal
        
        let effectiveAge = max(14, age)
        let effectiveAge = max(14, age)
        let effectiveHeight = height < 100 ? 175 : height
        let effectiveWeight = max(35.0, weight)
        let effectiveTargetWeight = max(35.0, targetWeight)
        
        let goalText: String
        let calorieDelta: Double
        if effectiveWeight > effectiveTargetWeight + 1.0 {
            goalText = "Снижение жировой массы с \(String(format: "%.1f", effectiveWeight)) кг до \(String(format: "%.1f", effectiveTargetWeight)) кг (умеренный дефицит ~400-500 ккал)"
            calorieDelta = -450.0
        } else if effectiveWeight < effectiveTargetWeight - 1.0 {
            goalText = "Набор качественной мышечной массы с \(String(format: "%.1f", effectiveWeight)) кг до \(String(format: "%.1f", effectiveTargetWeight)) кг (профицит калорий ~300-400 ккал)"
            calorieDelta = +350.0
        } else {
            goalText = "Поддержание текущей формы и композиции тела (\(String(format: "%.1f", effectiveWeight)) кг)"
            calorieDelta = 0.0
        }
        
        let targetWaterMl = max(1500.0, ((effectiveWeight * 35.0) / 50.0).rounded() * 50.0)
        
        let prompt = """
        Ты главный спортивный врач, физиолог и клинический нутрициолог приложения Forma.
        Проведи комплексную перепроверку и точную калибровку физиологических норм пользователя на основе параметров его тела и соматотипа.
        
        ПРОФИЛЬ ПОЛЬЗОВАТЕЛЯ:
        - Пол: \(gender)
        - Возраст: \(effectiveAge) лет
        - Рост: \(effectiveHeight) см
        - Текущий вес: \(String(format: "%.1f", effectiveWeight)) кг
        - Целевой вес: \(String(format: "%.1f", effectiveTargetWeight)) кг (Цель: \(goalText))
        - Физическая активность: \(activityLevel)
        - Тип телосложения (соматотип): \(somato.title)
        - Особенности соматотипа: \(somato.shortDescription)
        - Скорость метаболизма: \(metab.title)
        - Рекомендованное БЖУ под тип: Белки \(somato.recommendedMacros.protein)%, Жиры \(somato.recommendedMacros.fat)%, Углеводы \(somato.recommendedMacros.carbs)%
        
        МЕДИЦИНСКАЯ ЗАДАЧА:
        1. Рассчитай точную персональную суточную норму чистой воды (water_goal_ml):
           По стандартам ВОЗ и клинической медицины физиологическая норма чистой питьевой воды составляет 30–35 мл на 1 кг массы тела (с поправкой на уровень активности: \(activityLevel)).
           Для веса \(String(format: "%.1f", effectiveWeight)) кг точный расчет составляет \(Int(targetWaterMl)) мл (\(String(format: "%.1f", targetWaterMl / 1000.0)) л).
           В water_explanation дай научное объяснение на \(langName) языке: почему именно такой индивидуальный объем чистой воды необходим организму с массой \(String(format: "%.1f", effectiveWeight)) кг для поддержания метаболизма, фасциальной гидратации, липолиза и терморегуляции.
        2. Рассчитай BMR (базовый метаболизм) по формуле Mifflin-St Jeor с метаболическим множителем соматотипа \(somato.metabolismMultiplier).
        3. Рассчитай TDEE (суточный расход энергии) с учетом уровня активности (\(activityLevel)).
        4. Рассчитай целевой калораж (target_calories) под цель пользователя (\(goalText)).
        5. Рассчитай макронутриенты в граммах (protein_grams, fat_grams, carbs_grams) под целевую калорийность с учетом соматотипа \(somato.shortTitle).
        6. Дай 2-3 конкретных совета по питанию и питью под соматотип (somatotype_advice).
        
        Верни ТОЛЬКО валидный JSON строго следующей структуры без каких-либо комментариев:
        {
          "water_goal_ml": \(Int(targetWaterMl)),
          "bmr_calories": 1750,
          "tdee_calories": 2400,
          "target_calories": 1950,
          "protein_grams": 150,
          "fat_grams": 65,
          "carbs_grams": 190,
          "water_explanation": "Медицинское обоснование нормы воды на \(langName) языке",
          "somatotype_advice": "Советы по питанию и соматотипу на \(langName) языке"
        }
        """
        
        do {
            let resultData = try await executeRequest(
                prompt: prompt,
                systemPrompt: "Ты спортивный эндокринолог и клинический диетолог. Отвечай строго в формате JSON.",
                image: nil,
                responseFormatJSON: true,
                analysisType: "body_calibration"
            )
            
            struct CalibrationDTO: Codable {
                let water_goal_ml: Double?
                let bmr_calories: Int?
                let tdee_calories: Int?
                let target_calories: Int?
                let protein_grams: Int?
                let fat_grams: Int?
                let carbs_grams: Int?
                let water_explanation: String?
                let somatotype_advice: String?
            }
            
            let jsonText = resultData.text
            let rawData: Data?
            if let data = jsonText.data(using: .utf8), (try? JSONDecoder().decode(CalibrationDTO.self, from: data)) != nil {
                rawData = data
            } else if let open = jsonText.firstIndex(of: "{"),
                      let close = jsonText.lastIndex(of: "}"),
                      let sliceData = String(jsonText[open...close]).data(using: .utf8) {
                rawData = sliceData
            } else {
                rawData = nil
            }
            
            if let data = rawData, let dto = try? JSONDecoder().decode(CalibrationDTO.self, from: data) {
                let safeWater = dto.water_goal_ml ?? targetWaterMl
                let roundedWater = (safeWater / 50.0).rounded() * 50.0
                return AIBodyCalibrationResult(
                    waterGoalMl: max(1500.0, roundedWater),
                    bmrCalories: dto.bmr_calories ?? 1750,
                    tdeeCalories: dto.tdee_calories ?? 2400,
                    targetCalories: dto.target_calories ?? 1950,
                    proteinGrams: dto.protein_grams ?? 150,
                    fatGrams: dto.fat_grams ?? 65,
                    carbsGrams: dto.carbs_grams ?? 190,
                    waterExplanation: dto.water_explanation ?? "Норма рассчитана из физиологического оптимума 30-35 мл на 1 кг массы тела.",
                    somatotypeAdvice: dto.somatotype_advice ?? somato.nutritionStrategyPrompt,
                    provider: resultData.provider
                )
            }
        } catch {
            print("[GeminiScanService] auditAndCalibrateProfile fallback to scientific engine: \(error.localizedDescription)")
        }
        
        return calculateScientificFallback(
            gender: gender,
            age: effectiveAge,
            height: effectiveHeight,
            weight: effectiveWeight,
            targetWeight: effectiveTargetWeight,
            activityLevel: activityLevel,
            calorieDelta: calorieDelta,
            targetWaterMl: targetWaterMl,
            somato: somato
        )
    }
    
    private func calculateScientificFallback(
        gender: String,
        age: Int,
        height: Int,
        weight: Double,
        targetWeight: Double,
        activityLevel: String,
        calorieDelta: Double,
        targetWaterMl: Double,
        somato: Somatotype
    ) -> AIBodyCalibrationResult {
        let isMale = gender.lowercased().contains("муж") || gender.lowercased() == "male"
        let baseWater = targetWaterMl
        
        let baseBmr: Double
        if isMale {
            baseBmr = (10.0 * weight) + (6.25 * Double(height)) - (5.0 * Double(age)) + 5.0
        } else {
            baseBmr = (10.0 * weight) + (6.25 * Double(height)) - (5.0 * Double(age)) - 161.0
        }
        let calibratedBmr = baseBmr * somato.metabolismMultiplier
        
        let activityMult: Double
        switch activityLevel.lowercased() {
        case let s where s.contains("высок"): activityMult = 1.725
        case let s where s.contains("низк"): activityMult = 1.375
        default: activityMult = 1.55 // Средняя
        }
        let tdee = calibratedBmr * activityMult
        
        let targetCal = max(1200.0, tdee + calorieDelta)
        
        let macros = somato.recommendedMacros
        let proteinGrams = Int((targetCal * Double(macros.protein) / 100.0) / 4.0)
        let fatGrams = Int((targetCal * Double(macros.fat) / 100.0) / 9.0)
        let carbsGrams = Int((targetCal * Double(macros.carbs) / 100.0) / 4.0)
        
        let waterExplanation = "Для массы тела \(String(format: "%.1f", weight)) кг физиологическая норма чистой питьевой воды по стандартам ВОЗ составляет 30–35 мл на 1 кг веса = \(Int(baseWater)) мл (\(String(format: "%.1f", baseWater / 1000.0)) л). Достаточный объем воды оптимизирует обмен веществ, поддерживает нормальную вязкость крови и ускоряет вывод продуктов метаболизма."
        
        let advice = "Для соматотипа \(somato.shortTitle) рекомендован целевой калораж \(Int(targetCal)) ккал с акцентом на качество нутриентов (Б: \(proteinGrams)г, Ж: \(fatGrams)г, У: \(carbsGrams)г) и соблюдение питьевой нормы \(String(format: "%.1f", baseWater / 1000.0)) л в день."
        
        return AIBodyCalibrationResult(
            waterGoalMl: baseWater,
            bmrCalories: Int(calibratedBmr),
            tdeeCalories: Int(tdee),
            targetCalories: Int(targetCal),
            proteinGrams: proteinGrams,
            fatGrams: fatGrams,
            carbsGrams: carbsGrams,
            waterExplanation: waterExplanation,
            somatotypeAdvice: advice,
            provider: "Автономный медицинский расчет"
        )
    }
}

// MARK: - Модель результатов калибровки ИИ
public struct AIBodyCalibrationResult: Codable {
    public var waterGoalMl: Double
    public var bmrCalories: Int
    public var tdeeCalories: Int
    public var targetCalories: Int
    public var proteinGrams: Int
    public var fatGrams: Int
    public var carbsGrams: Int
    public var waterExplanation: String
    public var somatotypeAdvice: String
    public var provider: String
    
    public init(
        waterGoalMl: Double = 3500.0,
        bmrCalories: Int = 1850,
        tdeeCalories: Int = 2500,
        targetCalories: Int = 2000,
        proteinGrams: Int = 160,
        fatGrams: Int = 70,
        carbsGrams: Int = 150,
        waterExplanation: String = "",
        somatotypeAdvice: String = "",
        provider: String = "Google Gemini"
    ) {
        self.waterGoalMl = waterGoalMl
        self.bmrCalories = bmrCalories
        self.tdeeCalories = tdeeCalories
        self.targetCalories = targetCalories
        self.proteinGrams = proteinGrams
        self.fatGrams = fatGrams
        self.carbsGrams = carbsGrams
        self.waterExplanation = waterExplanation
        self.somatotypeAdvice = somatotypeAdvice
        self.provider = provider
    }
}

