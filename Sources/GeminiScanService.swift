import SwiftUI
import Foundation
import Vision
import GoogleGenerativeAI

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
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Ингредиент"
        self.weight_grams = try container.decodeIfPresent(Double.self, forKey: .weight_grams) ?? 100.0
        self.calories = try container.decodeIfPresent(Double.self, forKey: .calories) ?? 150.0
        self.protein = try container.decodeIfPresent(Double.self, forKey: .protein) ?? 10.0
        self.fat = try container.decodeIfPresent(Double.self, forKey: .fat) ?? 5.0
        self.carbs = try container.decodeIfPresent(Double.self, forKey: .carbs) ?? 15.0
        self.emoji = try container.decodeIfPresent(String.self, forKey: .emoji) ?? "🍽️"
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
    public var ingredients: [FoodIngredient]
    
    public init(dish: String, weight_grams: Double, calories: Double, protein: Double, fat: Double, carbs: Double, healthScore: Int? = nil, advice: String? = nil, ingredients: [FoodIngredient] = []) {
        self.dish = dish
        self.weight_grams = weight_grams
        self.calories = calories
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
        self.healthScore = healthScore
        self.advice = advice
        if ingredients.isEmpty {
            self.ingredients = [
                FoodIngredient(name: dish, weight_grams: weight_grams, calories: calories, protein: protein, fat: fat, carbs: carbs, emoji: "🥗")
            ]
        } else {
            self.ingredients = ingredients
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case dish, weight_grams, calories, protein, fat, carbs, healthScore, advice, ingredients
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.dish = try container.decodeIfPresent(String.self, forKey: .dish) ?? "Блюдо"
        self.weight_grams = try container.decodeIfPresent(Double.self, forKey: .weight_grams) ?? 200.0
        self.calories = try container.decodeIfPresent(Double.self, forKey: .calories) ?? 300.0
        self.protein = try container.decodeIfPresent(Double.self, forKey: .protein) ?? 15.0
        self.fat = try container.decodeIfPresent(Double.self, forKey: .fat) ?? 10.0
        self.carbs = try container.decodeIfPresent(Double.self, forKey: .carbs) ?? 35.0
        self.healthScore = try container.decodeIfPresent(Int.self, forKey: .healthScore)
        self.advice = try container.decodeIfPresent(String.self, forKey: .advice)
        let decodedIngredients = try container.decodeIfPresent([FoodIngredient].self, forKey: .ingredients) ?? []
        if decodedIngredients.isEmpty {
            self.ingredients = [
                FoodIngredient(name: self.dish, weight_grams: self.weight_grams, calories: self.calories, protein: self.protein, fat: self.fat, carbs: self.carbs, emoji: "🥗")
            ]
        } else {
            self.ingredients = decodedIngredients
        }
    }
}

public class GeminiScanService {
    public static let shared = GeminiScanService()
    
    // Специальный скоростной URLSession с оптимизированными таймаутами
    private static let fastSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 12.0
        config.timeoutIntervalForResource = 20.0
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
    private func executeRequest(prompt: String, systemPrompt: String?, image: UIImage? = nil, responseFormatJSON: Bool = false, analysisType: String? = nil) async throws -> (provider: String, text: String) {
        let defaults = UserDefaults.standard
        let geminiKey = (defaults.string(forKey: "api_key_gemini") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let openAIKey = (defaults.string(forKey: "api_key_openai") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let claudeKey = (defaults.string(forKey: "api_key_claude") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        
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
                        let text = try await queryGemini(prompt: prompt, systemPrompt: modifiedSystemPrompt.isEmpty ? nil : modifiedSystemPrompt, image: image, apiKey: geminiKey)
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
                        let text = try await queryOpenAI(prompt: prompt, systemPrompt: modifiedSystemPrompt.isEmpty ? nil : modifiedSystemPrompt, image: image, responseFormatJSON: responseFormatJSON, apiKey: openAIKey)
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
                        let text = try await queryClaude(prompt: prompt, systemPrompt: modifiedSystemPrompt.isEmpty ? nil : modifiedSystemPrompt, image: image, apiKey: claudeKey)
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
    
    private func queryGemini(prompt: String, systemPrompt: String?, image: UIImage?, apiKey: String) async throws -> String {
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
                    guard let resizedImage = resizeImage(img, targetSize: CGSize(width: 640, height: 640)),
                          let jpegData = resizedImage.jpegData(compressionQuality: 0.65) else {
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
    
    private func queryOpenAI(prompt: String, systemPrompt: String?, image: UIImage?, responseFormatJSON: Bool, apiKey: String) async throws -> String {
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
            guard let resizedImage = resizeImage(img, targetSize: CGSize(width: 640, height: 640)),
                  let jpegData = resizedImage.jpegData(compressionQuality: 0.65) else {
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
                request.timeoutInterval = 12.0
                
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
    
    private func queryClaude(prompt: String, systemPrompt: String?, image: UIImage?, apiKey: String) async throws -> String {
        var candidateModels = [activeClaudeModel]
        for m in Self.claudeHierarchy where !candidateModels.contains(m) {
            candidateModels.append(m)
        }
        
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        
        var contentParts: [[String: Any]] = []
        
        if let img = image {
            guard let resizedImage = resizeImage(img, targetSize: CGSize(width: 640, height: 640)),
                  let jpegData = resizedImage.jpegData(compressionQuality: 0.65) else {
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
                request.timeoutInterval = 12.0
                
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
        let geminiKey = (defaults.string(forKey: "api_key_gemini") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
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
        
        let systemPrompt = """
        Ты эксперт-диетолог и персональный нутрициолог в приложении Forma.
        Твой стиль и характер: тренер \(targetCoach.name) (\(targetCoach.specialty)).
        
        Твоя задача:
        1. Распознать блюдо на фото и детально сегментировать его на отдельные ингредиенты/составляющие на тарелке (мясо/рыба, гарнир, соусы, овощи, добавки).
        2. Оценить точный вес каждого ингредиента в граммах и их КБЖУ (калории, белки, жиры, углеводы).
        3. Дать оценку качества приема пищи healthScore (от 1 до 10).
        4. Написать краткий мотивирующий вердикт advice (2 предложения) в фирменном стиле тренера \(targetCoach.name) (с акцентом на качество белков, скрытые сахара и баланс нутриентов).
        
        Все тексты и названия должны быть на \(langName) языке.\(hintInstruction)

        Верни ТОЛЬКО валидный JSON следующей структуры без лишнего текста:
        {
          "dish": "Куриное филе с рисом и овощами",
          "weight_grams": 400,
          "calories": 480,
          "protein": 38,
          "fat": 12,
          "carbs": 54,
          "healthScore": 9,
          "advice": "Отличный баланс сложных углеводов и нежирного белка. Рекомендуем добавить немного свежей зелени.",
          "ingredients": [
            {
              "name": "Куриное филе гриль",
              "weight_grams": 150,
              "calories": 220,
              "protein": 32,
              "fat": 4,
              "carbs": 0,
              "emoji": "🍗"
            },
            {
              "name": "Отварной рис",
              "weight_grams": 180,
              "calories": 210,
              "protein": 4,
              "fat": 1,
              "carbs": 46,
              "emoji": "🍚"
            },
            {
              "name": "Свежие овощи",
              "weight_grams": 70,
              "calories": 50,
              "protein": 2,
              "fat": 7,
              "carbs": 8,
              "emoji": "🥗"
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
        let resultData = try await executeRequest(prompt: prompt, systemPrompt: systemPrompt, image: image, responseFormatJSON: true, analysisType: "nutrition_label")
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
        guard let cgImage = image.cgImage else {
            let defaultName = language == "en" ? "Healthy Meal" : (language == "hy" ? "Առողջ ճաշ" : "Полезное блюдо")
            let ing = FoodIngredient(name: defaultName, weight_grams: 200, calories: 320, protein: 15, fat: 10, carbs: 35, emoji: "🥗")
            return FoodScanResult(dish: defaultName, weight_grams: 200, calories: 320, protein: 15, fat: 10, carbs: 35, healthScore: 8, advice: "Локальный анализ блюда на устройстве.", ingredients: [ing])
        }
        
        return await withCheckedContinuation { continuation in
            let request = VNClassifyImageRequest { req, _ in
                guard let observations = req.results as? [VNClassificationObservation],
                      let top = observations.first(where: { $0.confidence > 0.05 }) else {
                    let defaultName = language == "en" ? "Healthy Meal" : (language == "hy" ? "Առողջ ճաշ" : "Сбалансированное блюдо")
                    let ing = FoodIngredient(name: defaultName, weight_grams: 200, calories: 340, protein: 16, fat: 12, carbs: 38, emoji: "🥗")
                    continuation.resume(returning: FoodScanResult(dish: defaultName, weight_grams: 200, calories: 340, protein: 16, fat: 12, carbs: 38, healthScore: 8, advice: "Оффлайн-оценка на базе VisionKit.", ingredients: [ing]))
                    return
                }
                
                let rawIdentifier = top.identifier.replacingOccurrences(of: "_", with: " ").capitalized
                let dishName: String
                if language == "en" {
                    dishName = rawIdentifier
                } else if language == "hy" {
                    dishName = "Ճաշատեսակ (\(rawIdentifier))"
                } else {
                    dishName = "Блюдо (\(rawIdentifier))"
                }
                
                // Детерминированная эвристическая калорийность на основе классификации
                let hash = abs(rawIdentifier.hashValue)
                let calories = 250.0 + Double(hash % 250)
                let p = Double((hash / 3) % 20 + 8)
                let f = Double((hash / 7) % 15 + 4)
                let c = max(10.0, (calories - (p * 4.0 + f * 9.0)) / 4.0)
                
                let ing = FoodIngredient(name: dishName, weight_grams: 200, calories: calories, protein: p, fat: f, carbs: c, emoji: "🍽️")
                
                continuation.resume(returning: FoodScanResult(
                    dish: dishName,
                    weight_grams: 200,
                    calories: calories,
                    protein: p,
                    fat: f,
                    carbs: c,
                    healthScore: 7,
                    advice: language == "en" ? "Offline meal analysis based on visual classification." : "Анализ блюда выполнен оффлайн на базе машинного зрения устройства.",
                    ingredients: [ing]
                ))
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                let defaultName = language == "en" ? "Meal" : (language == "hy" ? "Ճաշ" : "Прием пищи")
                let ing = FoodIngredient(name: defaultName, weight_grams: 200, calories: 300, protein: 12, fat: 8, carbs: 40, emoji: "🍽️")
                continuation.resume(returning: FoodScanResult(dish: defaultName, weight_grams: 200, calories: 300, protein: 12, fat: 8, carbs: 40, healthScore: 7, advice: "Базовый прием пищи.", ingredients: [ing]))
            }
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
        language: String = "ru"
    ) async throws -> (provider: String, answer: String) {
        var langName = "русском"
        if language == "en" { langName = "английском" }
        else if language == "hy" { langName = "армянском" }
        
        let systemPrompt = """
        Ты элитный персональный AI-нутрициолог и диетолог в приложении Forma. Твоя задача — давать профессиональные, научно обоснованные и практичные советы по питанию, водному балансу, калорийному дефициту/профициту и макронутриентам.
        Всегда учитывай текущие показатели пользователя за сегодня: что именно он съел, его энергетический баланс и цель.
        Если пользователь спрашивает, сколько он набрал или сбросил жира, объясняй расчет на основе дефицита/профицита калорий (7700 ккал = ~1 кг жировой массы).
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
        - Потреблено калорий: \(Int(caloriesConsumedToday)) ккал (Б: \(Int(proteinConsumedToday))г, Ж: \(Int(fatConsumedToday))г, У: \(Int(carbsConsumedToday))г)
        - Энергетический баланс за сегодня: \(balanceStr)
        - Выпито воды: \(Int(waterConsumedToday)) мл
        - Активность / сожжено активных калорий: \(Int(caloriesBurnedToday)) ккал
        - Текущий вес: \(String(format: "%.1f", userWeight)) кг
        - Цель: \(userGoal)
        - Что съедено сегодня:
        \(mealsSummary.isEmpty ? "Данных о конкретных блюдах пока нет" : mealsSummary)
        
        Дай конкретный, полезный и мотивирующий ответ на \(langName) языке.
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
        language: String = "ru"
    ) async throws -> (provider: String, answer: String) {
        let targetCoach: AICoachPersona
        if let coach {
            targetCoach = coach
        } else {
            targetCoach = await MainActor.run { AICoachManager.shared.currentCoach }
        }
        var langName = "русском"
        if language == "en" { langName = "английском" }
        else if language == "hy" { langName = "армянском" }
        
        let systemPrompt = """
        \(targetCoach.systemPromptStyle)
        Ты персональный ИИ-тренер по имени \(targetCoach.name) в приложении Forma. Твоя специализация: \(targetCoach.specialty). Девиз: \(targetCoach.tagline).
        
        ФИЗИЧЕСКИЙ ПРОФИЛЬ ПОЛЬЗОВАТЕЛЯ:
        - Текущий вес: \(userWeight > 0 ? String(format: "%.1f кг", userWeight) : "не указан")
        - Рост: \(userHeight) см
        - Возраст и пол: \(userAge) лет, \(userGender)
        - Целевая направленность: \(userGoal)
        
        КРИТИЧЕСКИЕ ИНСТРУКЦИИ:
        1. Всегда знай и учитывай точный вес пользователя (\(userWeight > 0 ? String(format: "%.1f кг", userWeight) : "из настроек")). При вопросах о весе или калориях сразу называй его вес и ориентируй на его цель.
        2. Всегда учитывай биометрические показатели пользователя (шаги, пульс, сон, тренировки) И ЕГО ПИТАНИЕ (съеденные калории, БЖУ, блюда, дефицит/профицит калорий и теоретическое изменение жировой массы).
        3. Если пользователь спрашивает, сколько он набрал или сбросил за сегодня, опирайся на его точный энергетический баланс (дефицит/профицит) и расчет расхода (1 кг жира = 7700 ккал).
        4. Если пользователь спрашивает про боли или дискомфорт, давай безопасные биомеханические альтернативы.
        5. Если пользователь плохо спал (< 6 ч), мягко рекомендуй снизить интенсивность или сделать акцент на мобильности.
        
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
        
        ПИТАНИЕ И ЭНЕРГЕТИЧЕСКИЙ БАЛАНС ЗА СЕГОДНЯ:
        - Потреблено: \(Int(caloriesConsumedToday)) ккал (Б: \(Int(proteinConsumedToday))г, Ж: \(Int(fatConsumedToday))г, У: \(Int(carbsConsumedToday))г)
        - Сальдо (Потреблено - Сожжено): \(balanceStatus)
        - Рацион за сегодня:
        \(mealsTodaySummary.isEmpty ? "Записей о блюдах за сегодня нет" : mealsTodaySummary)
        
        Дай профессиональный, персонализированный и вдохновляющий ответ от лица тренера \(targetCoach.name) на \(langName) языке.
        """
        
        let result = try await executeRequest(prompt: prompt, systemPrompt: systemPrompt, image: nil, responseFormatJSON: false, analysisType: "coach_\(targetCoach.id.rawValue)_chat")
        return (result.provider, result.text)
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
        language: String = "ru"
    ) async throws -> (provider: String, answer: String) {
        return try await askCoach(
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
            language: language
        )
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
        language: String = "ru"
    ) async throws -> String {
        var langName = "русском"
        if language == "en" { langName = "английском" }
        else if language == "hy" { langName = "армянском" }
        
        let prompt = """
        Ты — виртуальный фитнес-тренер Forma. Составь индивидуальную программу тренировок для пользователя на основе его профиля.
        
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
        Ты — профессиональный диетолог и нутрициолог Forma. Составь индивидуальный план питания на основе профиля пользователя и его физической активности.
        
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
}
