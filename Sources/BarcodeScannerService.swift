import Foundation
import SwiftUI

public struct BarcodeProduct: Identifiable, Codable, Equatable {
    public var id: String { barcode }
    public let barcode: String
    public let name: String
    public let brand: String
    public let servingSize: String
    public let servingWeightGrams: Double
    public let caloriesPer100g: Double
    public let proteinPer100g: Double
    public let fatPer100g: Double
    public let carbsPer100g: Double
    public let sugarPer100g: Double?
    public let fiberPer100g: Double?
    public let sodiumPer100g: Double?
    public let nutriScore: String? // "A", "B", "C", "D", "E"
    public let novaGroup: Int? // 1, 2, 3, 4
    public let imageUrl: String?
    public let emoji: String
    
    public init(
        barcode: String,
        name: String,
        brand: String = "",
        servingSize: String = "100 г",
        servingWeightGrams: Double = 100.0,
        caloriesPer100g: Double,
        proteinPer100g: Double,
        fatPer100g: Double,
        carbsPer100g: Double,
        sugarPer100g: Double? = nil,
        fiberPer100g: Double? = nil,
        sodiumPer100g: Double? = nil,
        nutriScore: String? = nil,
        novaGroup: Int? = nil,
        imageUrl: String? = nil,
        emoji: String = "📦"
    ) {
        self.barcode = barcode
        self.name = name
        self.brand = brand
        self.servingSize = servingSize
        self.servingWeightGrams = servingWeightGrams
        self.caloriesPer100g = caloriesPer100g
        self.proteinPer100g = proteinPer100g
        self.fatPer100g = fatPer100g
        self.carbsPer100g = carbsPer100g
        self.sugarPer100g = sugarPer100g
        self.fiberPer100g = fiberPer100g
        self.sodiumPer100g = sodiumPer100g
        self.nutriScore = nutriScore
        self.novaGroup = novaGroup
        self.imageUrl = imageUrl
        self.emoji = emoji
    }
}

public final class BarcodeScannerService {
    public static let shared = BarcodeScannerService()
    
    private init() {}
    
    /// Запрос информации о продукте в базе OpenFoodFacts с оффлайн-кэшем
    public func fetchProduct(barcode: String) async throws -> BarcodeProduct {
        let cleanBarcode = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Проверяем локальную базу популярных штрих-кодов
        if let local = getOfflineProduct(barcode: cleanBarcode) {
            return local
        }
        
        // 2. Запрос в OpenFoodFacts API v0
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v0/product/\(cleanBarcode).json") else {
            throw NSError(domain: "BarcodeScannerService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Некорректный номер штрих-кода."])
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 6.0
        request.setValue("Forma-iOS/1.0 (health@forma.app)", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "BarcodeScannerService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Продукт с таким штрих-кодом не найден в мировой базе."])
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let status = json["status"] as? Int, status == 1,
              let productDict = json["product"] as? [String: Any] else {
            throw NSError(domain: "BarcodeScannerService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Продукт со штрих-кодом \(cleanBarcode) не найден."])
        }
        
        let rawName = (productDict["product_name_ru"] as? String)
            ?? (productDict["product_name"] as? String)
            ?? (productDict["generic_name_ru"] as? String)
            ?? (productDict["generic_name"] as? String)
            ?? "Продукт (\(cleanBarcode))"
        
        let brand = (productDict["brands"] as? String) ?? ""
        let nutriments = productDict["nutriments"] as? [String: Any] ?? [:]
        
        let calories = (nutriments["energy-kcal_100g"] as? Double)
            ?? (nutriments["energy-kcal"] as? Double)
            ?? (nutriments["energy_100g"] as? Double ?? 0.0) / 4.184
        
        let protein = (nutriments["proteins_100g"] as? Double) ?? (nutriments["proteins"] as? Double) ?? 0.0
        let fat = (nutriments["fat_100g"] as? Double) ?? (nutriments["fat"] as? Double) ?? 0.0
        let carbs = (nutriments["carbohydrates_100g"] as? Double) ?? (nutriments["carbohydrates"] as? Double) ?? 0.0
        let sugar = (nutriments["sugars_100g"] as? Double) ?? (nutriments["sugars"] as? Double)
        let fiber = (nutriments["fiber_100g"] as? Double) ?? (nutriments["fiber"] as? Double)
        let sodium = (nutriments["sodium_100g"] as? Double) ?? (nutriments["sodium"] as? Double)
        
        let nutriScore = (productDict["nutriscore_grade"] as? String)?.uppercased()
        let novaGroup = productDict["nova_group"] as? Int
        let imageUrl = productDict["image_front_small_url"] as? String ?? productDict["image_url"] as? String
        
        let servingStr = (productDict["serving_size"] as? String) ?? "100 г"
        let servingWeight = parseServingWeight(servingStr) ?? 100.0
        let emoji = deduceEmoji(name: rawName)
        
        return BarcodeProduct(
            barcode: cleanBarcode,
            name: rawName,
            brand: brand,
            servingSize: servingStr,
            servingWeightGrams: servingWeight,
            caloriesPer100g: max(0, calories),
            proteinPer100g: max(0, protein),
            fatPer100g: max(0, fat),
            carbsPer100g: max(0, carbs),
            sugarPer100g: sugar,
            fiberPer100g: fiber,
            sodiumPer100g: sodium,
            nutriScore: nutriScore,
            novaGroup: novaGroup,
            imageUrl: imageUrl,
            emoji: emoji
        )
    }
    
    /// Преобразование продукта штрих-кода в FoodScanResult для мгновенного добавления в дневник
    public func convertToScanResult(product: BarcodeProduct, portionGrams: Double) -> FoodScanResult {
        let ratio = portionGrams / 100.0
        let cal = product.caloriesPer100g * ratio
        let p = product.proteinPer100g * ratio
        let f = product.fatPer100g * ratio
        let c = product.carbsPer100g * ratio
        
        let ing = FoodIngredient(
            name: product.brand.isEmpty ? product.name : "\(product.name) (\(product.brand))",
            weight_grams: portionGrams,
            calories: cal,
            protein: p,
            fat: f,
            carbs: c,
            emoji: product.emoji
        )
        
        var healthScore = 8
        if let nutri = product.nutriScore {
            switch nutri {
            case "A": healthScore = 10
            case "B": healthScore = 8
            case "C": healthScore = 6
            case "D": healthScore = 4
            case "E": healthScore = 2
            default: healthScore = 7
            }
        }
        
        let advice = "Официальные данные производителя из базы OpenFoodFacts. Отсканировано по штрих-коду."
        
        return FoodScanResult(
            dish: product.brand.isEmpty ? product.name : "\(product.name) — \(product.brand)",
            weight_grams: portionGrams,
            calories: cal,
            protein: p,
            fat: f,
            carbs: c,
            healthScore: healthScore,
            advice: advice,
            ingredients: [ing]
        )
    }
    
    private func parseServingWeight(_ str: String) -> Double? {
        let pattern = #"(\d+[\.,]?\d*)\s*(g|г|мл|ml)"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: str, options: [], range: NSRange(location: 0, length: str.utf16.count)),
           let range = Range(match.range(at: 1), in: str) {
            let numStr = String(str[range]).replacingOccurrences(of: ",", with: ".")
            return Double(numStr)
        }
        return nil
    }
    
    private func deduceEmoji(name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("молок") || lower.contains("milk") { return "🥛" }
        if lower.contains("творог") || lower.contains("curd") || lower.contains("cottage") { return "🧀" }
        if lower.contains("йогурт") || lower.contains("yogurt") { return "🥣" }
        if lower.contains("хлеб") || lower.contains("bread") { return "🍞" }
        if lower.contains("батончик") || lower.contains("protein") || lower.contains("bar") { return "🍫" }
        if lower.contains("сыр") || lower.contains("cheese") { return "🧀" }
        if lower.contains("яйц") || lower.contains("egg") { return "🥚" }
        if lower.contains("куриц") || lower.contains("chicken") { return "🍗" }
        if lower.contains("рыб") || lower.contains("salmon") || lower.contains("тунец") { return "🐟" }
        if lower.contains("сок") || lower.contains("juice") { return "🧃" }
        if lower.contains("вода") || lower.contains("water") { return "💧" }
        if lower.contains("овсян") || lower.contains("oat") { return "🌾" }
        if lower.contains("шоколад") || lower.contains("chocolate") { return "🍫" }
        if lower.contains("кофе") || lower.contains("coffee") { return "☕" }
        if lower.contains("чай") || lower.contains("tea") { return "🫖" }
        if lower.contains("банан") || lower.contains("banana") { return "🍌" }
        if lower.contains("яблок") || lower.contains("apple") { return "🍎" }
        return "📦"
    }
    
    private func getOfflineProduct(barcode: String) -> BarcodeProduct? {
        let offlineDict: [String: BarcodeProduct] = [
            "4607004891234": BarcodeProduct(
                barcode: "4607004891234",
                name: "Творог 5%",
                brand: "Простоквашино",
                servingWeightGrams: 200.0,
                caloriesPer100g: 121.0,
                proteinPer100g: 16.0,
                fatPer100g: 5.0,
                carbsPer100g: 3.0,
                nutriScore: "A",
                novaGroup: 1,
                emoji: "🧀"
            ),
            "4607004895678": BarcodeProduct(
                barcode: "4607004895678",
                name: "Греческий йогурт Teos 2%",
                brand: "Савушкин",
                servingWeightGrams: 140.0,
                caloriesPer100g: 66.0,
                proteinPer100g: 8.0,
                fatPer100g: 2.0,
                carbsPer100g: 4.0,
                nutriScore: "A",
                novaGroup: 1,
                emoji: "🥣"
            ),
            "4607004899999": BarcodeProduct(
                barcode: "4607004899999",
                name: "Протеиновый батончик Hazelnut",
                brand: "Bombbar",
                servingWeightGrams: 60.0,
                caloriesPer100g: 310.0,
                proteinPer100g: 33.3,
                fatPer100g: 12.0,
                carbsPer100g: 8.5,
                nutriScore: "B",
                novaGroup: 3,
                emoji: "🍫"
            )
        ]
        return offlineDict[barcode]
    }
}
