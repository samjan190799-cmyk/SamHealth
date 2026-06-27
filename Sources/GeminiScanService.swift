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
            maxOutputTokens: 1000,
            stopSequences: [],
            responseMIMEType: "application/json"
        )
        
        let model = GenerativeModel(
            name: "gemini-1.5-flash",
            apiKey: apiKey,
            generationConfig: config
        )
        
        let systemPrompt = "Ты диетолог. Распознай блюдо на фото. Оцени вес порции. Верни ТОЛЬКО валидный JSON: {\"dish\": \"Название\", \"weight_grams\": 200, \"calories\": 350, \"protein\": 20, \"fat\": 15, \"carbs\": 30}."
        
        // Изменяем разрешение изображения, чтобы уменьшить размер полезной нагрузки (оптимально для API)
        guard let resizedImage = resizeImage(image, targetSize: CGSize(width: 800, height: 800)),
              let imageData = resizedImage.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "GeminiScanService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Не удалось подготовить изображение к обработке."])
        }
        
        let response = try await model.generateContent(
            systemPrompt,
            imageData
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
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
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
}
