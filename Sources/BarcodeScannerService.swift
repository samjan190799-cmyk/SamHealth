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
    public var isUserCustom: Bool
    
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
        emoji: String = "📦",
        isUserCustom: Bool = false
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
        self.isUserCustom = isUserCustom
    }
}

public final class BarcodeScannerService {
    public static let shared = BarcodeScannerService()
    
    private let customStorageKey = "user_custom_barcode_products_v1"
    private let networkCacheKey = "user_cached_barcode_products_v1"
    
    private init() {}
    
    // MARK: - Нормализация штрих-кода
    
    /// Очистка и нормализация строки штрих-кода
    public func normalizeBarcode(_ raw: String) -> String {
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .filter { $0.isNumber || $0.isLetter }
    }
    
    /// Генерация вариантов штрих-кода для устранения несовпадений (UPC-A 12 vs EAN-13, ведущие нули)
    private func generateBarcodeVariants(barcode: String) -> [String] {
        var variants = [barcode]
        
        // UPC-A (12 цифр) -> EAN-13 (13 цифр с ведущим нулем 0)
        if barcode.count == 12 && barcode.allSatisfy({ $0.isNumber }) {
            let ean13 = "0" + barcode
            if !variants.contains(ean13) {
                variants.append(ean13)
            }
        }
        
        // EAN-13 начинающийся с 0 -> UPC-A 12 цифр
        if barcode.count == 13 && barcode.hasPrefix("0") && barcode.allSatisfy({ $0.isNumber }) {
            let upcA = String(barcode.dropFirst())
            if !variants.contains(upcA) {
                variants.append(upcA)
            }
        }
        
        // EAN-8 (8 цифр) -> EAN-13 с ведущими нулями
        if barcode.count == 8 && barcode.allSatisfy({ $0.isNumber }) {
            let padded = String(repeating: "0", count: 5) + barcode
            if !variants.contains(padded) {
                variants.append(padded)
            }
        }
        
        return variants
    }
    
    // MARK: - Локальная пользовательская база
    
    /// Получение всех созданных/сохраненных пользователем продуктов
    public func getAllCustomProducts() -> [BarcodeProduct] {
        guard let data = UserDefaults.standard.data(forKey: customStorageKey),
              let dict = try? JSONDecoder().decode([String: BarcodeProduct].self, from: data) else {
            return []
        }
        return Array(dict.values)
    }
    
    /// Поиск в локальной пользовательской базе
    public func getCustomProduct(barcode: String) -> BarcodeProduct? {
        guard let data = UserDefaults.standard.data(forKey: customStorageKey),
              let dict = try? JSONDecoder().decode([String: BarcodeProduct].self, from: data) else {
            return nil
        }
        return dict[barcode]
    }
    
    /// Сохранение пользовательского продукта (созданного вручную или через ИИ)
    public func saveCustomProduct(_ product: BarcodeProduct) {
        var dict: [String: BarcodeProduct] = [:]
        if let data = UserDefaults.standard.data(forKey: customStorageKey),
           let existing = try? JSONDecoder().decode([String: BarcodeProduct].self, from: data) {
            dict = existing
        }
        
        var mutableProduct = product
        mutableProduct.isUserCustom = true
        dict[product.barcode] = mutableProduct
        
        if let encoded = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(encoded, forKey: customStorageKey)
        }
    }
    
    /// Удаление продукта из пользовательской базы
    public func deleteCustomProduct(barcode: String) {
        guard let data = UserDefaults.standard.data(forKey: customStorageKey),
              var dict = try? JSONDecoder().decode([String: BarcodeProduct].self, from: data) else {
            return
        }
        dict.removeValue(forKey: barcode)
        if let encoded = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(encoded, forKey: customStorageKey)
        }
    }
    
    // MARK: - Кэш сетевых запросов
    
    private func getCachedProduct(barcode: String) -> BarcodeProduct? {
        guard let data = UserDefaults.standard.data(forKey: networkCacheKey),
              let dict = try? JSONDecoder().decode([String: BarcodeProduct].self, from: data) else {
            return nil
        }
        return dict[barcode]
    }
    
    public func saveCachedProduct(_ product: BarcodeProduct) {
        var dict: [String: BarcodeProduct] = [:]
        if let data = UserDefaults.standard.data(forKey: networkCacheKey),
           let existing = try? JSONDecoder().decode([String: BarcodeProduct].self, from: data) {
            dict = existing
        }
        dict[product.barcode] = product
        
        // Ограничиваем кэш последними 200 товарами
        if dict.count > 200 {
            dict = Dictionary(uniqueKeysWithValues: Array(dict).suffix(150))
        }
        
        if let encoded = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(encoded, forKey: networkCacheKey)
        }
    }
    
    // MARK: - Основной поиск продукта (Локальная база -> Оффлайн пресеты -> Кэш -> OpenFoodFacts v2/v0)
    
    public func fetchProduct(barcode: String) async throws -> BarcodeProduct {
        let cleanBarcode = normalizeBarcode(barcode)
        guard !cleanBarcode.isEmpty else {
            throw NSError(domain: "BarcodeScannerService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Пустой или некорректный номер штрих-кода."])
        }
        
        let variants = generateBarcodeVariants(barcode: cleanBarcode)
        
        // 1. Проверяем локальную пользовательскую базу (для всех вариантов)
        for variant in variants {
            if let custom = getCustomProduct(barcode: variant) {
                return custom
            }
        }
        
        // 2. Проверяем оффлайн-пресеты популярных товаров
        for variant in variants {
            if let local = getOfflineProduct(barcode: variant) {
                return local
            }
        }
        
        // 3. Проверяем сохраненный кэш сетевых запросов
        for variant in variants {
            if let cached = getCachedProduct(barcode: variant) {
                return cached
            }
        }
        
        // 4. Сетевой каскадный поиск по OpenFoodFacts
        var lastError: Error? = nil
        for variant in variants {
            do {
                let product = try await queryOpenFoodFacts(barcode: variant)
                // Успешно нашли в сети — кэшируем для оффлайна
                saveCachedProduct(product)
                return product
            } catch {
                lastError = error
            }
        }
        
        throw lastError ?? NSError(
            domain: "BarcodeScannerService",
            code: 404,
            userInfo: [NSLocalizedDescriptionKey: "Продукт со штрих-кодом \(cleanBarcode) не найден в базе данных."]
        )
    }
    
    // MARK: - Сетевой запрос к OpenFoodFacts API v2 / v0
    
    private func queryOpenFoodFacts(barcode: String) async throws -> BarcodeProduct {
        let urlStrings = [
            "https://world.openfoodfacts.org/api/v2/product/\(barcode).json?fields=product_name,product_name_ru,generic_name,generic_name_ru,brands,nutriments,nutriscore_grade,nova_group,image_front_small_url,image_url,serving_size",
            "https://ru.openfoodfacts.org/api/v2/product/\(barcode).json",
            "https://world.openfoodfacts.org/api/v0/product/\(barcode).json"
        ]
        
        for urlStr in urlStrings {
            guard let url = URL(string: urlStr) else { continue }
            
            var request = URLRequest(url: url)
            request.timeoutInterval = 4.5
            request.setValue("Forma-iOS/1.0 (health@forma.app)", forHTTPHeaderField: "User-Agent")
            request.setValue("ru,en;q=0.9", forHTTPHeaderField: "Accept-Language")
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    continue
                }
                
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let status = json["status"] as? Int, status == 1,
                      let productDict = json["product"] as? [String: Any] else {
                    continue
                }
                
                let rawName = (productDict["product_name_ru"] as? String)
                    ?? (productDict["product_name"] as? String)
                    ?? (productDict["generic_name_ru"] as? String)
                    ?? (productDict["generic_name"] as? String)
                    ?? "Продукт (\(barcode))"
                
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
                    barcode: barcode,
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
                    emoji: emoji,
                    isUserCustom: false
                )
            } catch {
                continue
            }
        }
        
        throw NSError(domain: "BarcodeScannerService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Продукт со штрих-кодом \(barcode) не найден в базе."])
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
        
        let adviceSource = product.isUserCustom ? "Данные из вашей личной базы (распознано ИИ / добавлено вручную)." : "Официальные данные производителя из базы OpenFoodFacts."
        
        Task { @MainActor in
            FoodCatalogService.shared.recordBarcodeProductAsRecent(
                name: product.name,
                brand: product.brand,
                calories: product.caloriesPer100g,
                protein: product.proteinPer100g,
                fat: product.fatPer100g,
                carbs: product.carbsPer100g,
                grams: portionGrams,
                emoji: product.emoji
            )
        }
        
        return FoodScanResult(
            dish: product.brand.isEmpty ? product.name : "\(product.name) — \(product.brand)",
            weight_grams: portionGrams,
            calories: cal,
            protein: p,
            fat: f,
            carbs: c,
            healthScore: healthScore,
            advice: adviceSource,
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

