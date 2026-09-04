import Foundation
import SwiftUI

// MARK: - Категории продуктов
public enum FoodGroupCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case all = "all"
    case favorites = "favorites"
    case recents = "recents"
    case soups = "soups"
    case grains = "grains"
    case meat = "meat"
    case fish = "fish"
    case dairy = "dairy"
    case vegetables = "vegetables"
    case fruits = "fruits"
    case bakery = "bakery"
    case nutsAndOils = "nuts_oils"
    case beverages = "beverages"
    case snacks = "snacks"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .all: return "Все"
        case .favorites: return "Избранное"
        case .recents: return "Недавние"
        case .soups: return "Супы и бульоны"
        case .grains: return "Крупы и гарниры"
        case .meat: return "Мясо и птица"
        case .fish: return "Рыба и морепродукты"
        case .dairy: return "Яйца и молочка"
        case .vegetables: return "Овощи и зелень"
        case .fruits: return "Фрукты и ягоды"
        case .bakery: return "Хлеб и выпечка"
        case .nutsAndOils: return "Орехи и масла"
        case .beverages: return "Напитки"
        case .snacks: return "Перекусы"
        }
    }
    
    public var emoji: String {
        switch self {
        case .all: return "🍽️"
        case .favorites: return "⭐️"
        case .recents: return "🕒"
        case .soups: return "🍲"
        case .grains: return "🌾"
        case .meat: return "🍗"
        case .fish: return "🐟"
        case .dairy: return "🧀"
        case .vegetables: return "🥗"
        case .fruits: return "🍎"
        case .bakery: return "🍞"
        case .nutsAndOils: return "🥑"
        case .beverages: return "☕️"
        case .snacks: return "🍫"
        }
    }
}

// MARK: - Модель продукта каталога
public struct FoodCatalogItem: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let category: FoodGroupCategory
    public let caloriesPer100g: Double
    public let proteinPer100g: Double
    public let fatPer100g: Double
    public let carbsPer100g: Double
    public let defaultPortionGrams: Double
    public let portionName: String
    public let textureType: MealTextureType
    public let emoji: String
    public let aliases: [String]
    public var isUserCustom: Bool
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        category: FoodGroupCategory,
        caloriesPer100g: Double,
        proteinPer100g: Double,
        fatPer100g: Double,
        carbsPer100g: Double,
        defaultPortionGrams: Double = 100.0,
        portionName: String = "1 порция (100г)",
        textureType: MealTextureType = .solidDense,
        emoji: String = "🍽️",
        aliases: [String] = [],
        isUserCustom: Bool = false
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.caloriesPer100g = caloriesPer100g
        self.proteinPer100g = proteinPer100g
        self.fatPer100g = fatPer100g
        self.carbsPer100g = carbsPer100g
        self.defaultPortionGrams = defaultPortionGrams
        self.portionName = portionName
        self.textureType = textureType
        self.emoji = emoji
        self.aliases = aliases
        self.isUserCustom = isUserCustom
    }
    
    /// Расчет макронутриентов на указанный вес в граммах
    public func macros(for grams: Double) -> (calories: Double, protein: Double, fat: Double, carbs: Double) {
        let factor = max(0, grams) / 100.0
        return (
            calories: (caloriesPer100g * factor).rounded(),
            protein: ((proteinPer100g * factor) * 10).rounded() / 10,
            fat: ((fatPer100g * factor) * 10).rounded() / 10,
            carbs: ((carbsPer100g * factor) * 10).rounded() / 10
        )
    }
    
    /// Преобразование в LoggedMealRecord для сохранения в дневник
    public func toLoggedMealRecord(weightGrams: Double, category: MealCategory, date: Date = Date()) -> LoggedMealRecord {
        let m = macros(for: weightGrams)
        return LoggedMealRecord(
            name: name,
            calories: m.calories,
            protein: m.protein,
            fat: m.fat,
            carbs: m.carbs,
            weightGrams: weightGrams,
            category: category,
            date: date,
            emoji: emoji,
            textureType: textureType
        )
    }
}

// MARK: - Сервис каталога базовых продуктов
@MainActor
public final class FoodCatalogService: ObservableObject {
    public static let shared = FoodCatalogService()
    
    private let recentsStorageKey = "user_recent_food_catalog_v1"
    private let favoritesStorageKey = "user_favorite_food_catalog_v1"
    private let customStorageKey = "user_custom_food_catalog_v1"
    
    @Published public private(set) var recentItems: [FoodCatalogItem] = []
    @Published public private(set) var favoriteIds: Set<String> = []
    @Published public private(set) var customItems: [FoodCatalogItem] = []
    
    /// Основная встроенная эталонная база (~150 ключевых продуктов)
    public let baseCatalog: [FoodCatalogItem]
    
    private init() {
        self.baseCatalog = FoodCatalogService.buildBaseCatalog()
        loadLocalState()
    }
    
    // MARK: - Поиск и фильтрация
    
    public func search(query: String, category: FoodGroupCategory = .all) -> [FoodCatalogItem] {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // 1. Фильтрация по категории
        var pool: [FoodCatalogItem]
        switch category {
        case .all:
            pool = customItems + baseCatalog
        case .favorites:
            pool = (customItems + baseCatalog).filter { favoriteIds.contains($0.id) }
        case .recents:
            pool = recentItems
        default:
            pool = (customItems + baseCatalog).filter { $0.category == category }
        }
        
        // 2. Если запрос пустой, возвращаем отфильтрованный список
        if cleanQuery.isEmpty {
            return pool
        }
        
        // 3. Ранжированный поиск:
        return pool.filter { item in
            let lowerName = item.name.lowercased()
            if lowerName.contains(cleanQuery) { return true }
            return item.aliases.contains { $0.lowercased().contains(cleanQuery) }
        }.sorted { itemA, itemB in
            let nameA = itemA.name.lowercased()
            let nameB = itemB.name.lowercased()
            
            let aStarts = nameA.hasPrefix(cleanQuery)
            let bStarts = nameB.hasPrefix(cleanQuery)
            if aStarts != bStarts { return aStarts }
            
            let aIsFav = favoriteIds.contains(itemA.id)
            let bIsFav = favoriteIds.contains(itemB.id)
            if aIsFav != bIsFav { return aIsFav }
            
            return itemA.name < itemB.name
        }
    }
    
    // MARK: - Управление Избранным и Недавним
    
    public func isFavorite(itemId: String) -> Bool {
        favoriteIds.contains(itemId)
    }
    
    public func toggleFavorite(item: FoodCatalogItem) {
        if favoriteIds.contains(item.id) {
            favoriteIds.remove(item.id)
        } else {
            favoriteIds.insert(item.id)
        }
        saveFavorites()
    }
    
    public func recordUsage(item: FoodCatalogItem) {
        var list = recentItems.filter { $0.id != item.id && $0.name != item.name }
        list.insert(item, at: 0)
        if list.count > 40 {
            list = Array(list.prefix(40))
        }
        recentItems = list
        saveRecents()
    }
    
    public func recordBarcodeProductAsRecent(name: String, brand: String, calories: Double, protein: Double, fat: Double, carbs: Double, grams: Double, emoji: String) {
        let fullName = brand.isEmpty ? name : "\(name) (\(brand))"
        let texture = MealTextureType.detect(from: fullName, emoji: emoji)
        let item = FoodCatalogItem(
            id: "barcode_\(UUID().uuidString.prefix(8))",
            name: fullName,
            category: .snacks,
            caloriesPer100g: grams > 0 ? (calories / grams) * 100.0 : calories,
            proteinPer100g: grams > 0 ? (protein / grams) * 100.0 : protein,
            fatPer100g: grams > 0 ? (fat / grams) * 100.0 : fat,
            carbsPer100g: grams > 0 ? (carbs / grams) * 100.0 : carbs,
            defaultPortionGrams: grams > 0 ? grams : 100.0,
            portionName: "1 уп (\(Int(grams))г)",
            textureType: texture,
            emoji: emoji,
            aliases: [name, brand],
            isUserCustom: true
        )
        recordUsage(item: item)
    }
    
    public func addCustomItem(item: FoodCatalogItem) {
        customItems.removeAll { $0.id == item.id || $0.name.lowercased() == item.name.lowercased() }
        customItems.insert(item, at: 0)
        recordUsage(item: item)
        saveCustomItems()
    }
    
    // MARK: - Персистентность
    
    private func loadLocalState() {
        if let favs = UserDefaults.standard.array(forKey: favoritesStorageKey) as? [String] {
            self.favoriteIds = Set(favs)
        }
        if let data = UserDefaults.standard.data(forKey: recentsStorageKey),
           let decoded = try? JSONDecoder().decode([FoodCatalogItem].self, from: data) {
            self.recentItems = decoded
        }
        if let data = UserDefaults.standard.data(forKey: customStorageKey),
           let decoded = try? JSONDecoder().decode([FoodCatalogItem].self, from: data) {
            self.customItems = decoded
        }
    }
    
    private func saveFavorites() {
        UserDefaults.standard.set(Array(favoriteIds), forKey: favoritesStorageKey)
    }
    
    private func saveRecents() {
        if let encoded = try? JSONEncoder().encode(recentItems) {
            UserDefaults.standard.set(encoded, forKey: recentsStorageKey)
        }
    }
    
    private func saveCustomItems() {
        if let encoded = try? JSONEncoder().encode(customItems) {
            UserDefaults.standard.set(encoded, forKey: customStorageKey)
        }
    }
    
    // MARK: - Встроенная эталонная база продуктов (150+ ключевых продуктов)
    
    private static func buildBaseCatalog() -> [FoodCatalogItem] {
        var items: [FoodCatalogItem] = []
        
        // --- 1. КРУПЫ, ГАРНИРЫ И БОБОВЫЕ ---
        items.append(contentsOf: [
            FoodCatalogItem(
                id: "grain_buckwheat",
                name: "Гречневая каша (вареная)",
                category: .grains,
                caloriesPer100g: 110,
                proteinPer100g: 4.2,
                fatPer100g: 1.3,
                carbsPer100g: 21.3,
                defaultPortionGrams: 200,
                portionName: "1 порция (200г)",
                textureType: .solidDense,
                emoji: "🌾",
                aliases: ["гречка", "греча", "ядрица"]
            ),
            FoodCatalogItem(
                id: "grain_oatmeal_water",
                name: "Овсяная каша на воде",
                category: .grains,
                caloriesPer100g: 88,
                proteinPer100g: 3.0,
                fatPer100g: 1.7,
                carbsPer100g: 15.0,
                defaultPortionGrams: 250,
                portionName: "1 тарелка (250г)",
                textureType: .lightFresh,
                emoji: "🥣",
                aliases: ["овсянка", "геркулес", "овес"]
            ),
            FoodCatalogItem(
                id: "grain_oatmeal_milk",
                name: "Овсяная каша на молоке",
                category: .grains,
                caloriesPer100g: 102,
                proteinPer100g: 3.8,
                fatPer100g: 3.0,
                carbsPer100g: 15.5,
                defaultPortionGrams: 250,
                portionName: "1 тарелка (250г)",
                textureType: .lightFresh,
                emoji: "🥣",
                aliases: ["овсянка молочная", "геркулес на молоке"]
            ),
            FoodCatalogItem(
                id: "grain_white_rice",
                name: "Рис белый отварной",
                category: .grains,
                caloriesPer100g: 130,
                proteinPer100g: 2.7,
                fatPer100g: 0.3,
                carbsPer100g: 28.2,
                defaultPortionGrams: 200,
                portionName: "1 порция (200г)",
                textureType: .solidDense,
                emoji: "🍚",
                aliases: ["рис", "басмати", "жасмин"]
            ),
            FoodCatalogItem(
                id: "grain_brown_rice",
                name: "Рис бурый (нерафинированный)",
                category: .grains,
                caloriesPer100g: 111,
                proteinPer100g: 2.6,
                fatPer100g: 0.9,
                carbsPer100g: 23.0,
                defaultPortionGrams: 200,
                portionName: "1 порция (200г)",
                textureType: .solidDense,
                emoji: "🍚",
                aliases: ["рис бурый", "коричневый рис"]
            ),
            FoodCatalogItem(
                id: "grain_pasta_durum",
                name: "Макароны из твердых сортов (вареные)",
                category: .grains,
                caloriesPer100g: 158,
                proteinPer100g: 5.8,
                fatPer100g: 0.9,
                carbsPer100g: 30.9,
                defaultPortionGrams: 200,
                portionName: "1 порция (200г)",
                textureType: .solidDense,
                emoji: "🍝",
                aliases: ["макароны", "спагетти", "паста", "пенне"]
            ),
            FoodCatalogItem(
                id: "grain_mashed_potatoes",
                name: "Картофельное пюре с молоком и маслом",
                category: .grains,
                caloriesPer100g: 106,
                proteinPer100g: 2.0,
                fatPer100g: 4.2,
                carbsPer100g: 15.0,
                defaultPortionGrams: 200,
                portionName: "1 порция (200г)",
                textureType: .lightFresh,
                emoji: "🥔",
                aliases: ["пюре", "картошка пюре", "толкушка"]
            ),
            FoodCatalogItem(
                id: "grain_baked_potato",
                name: "Картофель запеченный в кожуре",
                category: .grains,
                caloriesPer100g: 93,
                proteinPer100g: 2.5,
                fatPer100g: 0.1,
                carbsPer100g: 21.0,
                defaultPortionGrams: 180,
                portionName: "1 средняя картофелина (180г)",
                textureType: .solidDense,
                emoji: "🥔",
                aliases: ["печеный картофель", "картошка в мундире"]
            ),
            FoodCatalogItem(
                id: "grain_quinoa",
                name: "Киноа вареная",
                category: .grains,
                caloriesPer100g: 120,
                proteinPer100g: 4.4,
                fatPer100g: 1.9,
                carbsPer100g: 21.3,
                defaultPortionGrams: 180,
                portionName: "1 порция (180г)",
                textureType: .solidDense,
                emoji: "🌾",
                aliases: ["квинва", "киноа"]
            ),
            FoodCatalogItem(
                id: "grain_bulgur",
                name: "Булгур отварной",
                category: .grains,
                caloriesPer100g: 83,
                proteinPer100g: 3.1,
                fatPer100g: 0.2,
                carbsPer100g: 18.6,
                defaultPortionGrams: 200,
                portionName: "1 порция (200г)",
                textureType: .solidDense,
                emoji: "🌾",
                aliases: ["булгур", "пшеничная крупа"]
            ),
            FoodCatalogItem(
                id: "grain_lentils",
                name: "Чечевица вареная",
                category: .grains,
                caloriesPer100g: 116,
                proteinPer100g: 9.0,
                fatPer100g: 0.4,
                carbsPer100g: 20.1,
                defaultPortionGrams: 200,
                portionName: "1 порция (200г)",
                textureType: .solidDense,
                emoji: "🧆",
                aliases: ["чечевица красная", "чечевица зеленая"]
            ),
            FoodCatalogItem(
                id: "grain_beans",
                name: "Фасоль красная отварная",
                category: .grains,
                caloriesPer100g: 127,
                proteinPer100g: 8.7,
                fatPer100g: 0.5,
                carbsPer100g: 22.8,
                defaultPortionGrams: 180,
                portionName: "1 порция (180г)",
                textureType: .solidDense,
                emoji: "🫘",
                aliases: ["фасоль", "бобы"]
            )
        ])
        
        // --- 2. МЯСО И ПТИЦА ---
        items.append(contentsOf: [
            FoodCatalogItem(
                id: "meat_chicken_breast_boiled",
                name: "Куриная грудка (филе) отварная",
                category: .meat,
                caloriesPer100g: 137,
                proteinPer100g: 29.8,
                fatPer100g: 1.8,
                carbsPer100g: 0.0,
                defaultPortionGrams: 150,
                portionName: "1 филе (150г)",
                textureType: .solidDense,
                emoji: "🍗",
                aliases: ["курица", "грудка", "филе куриное", "курочка"]
            ),
            FoodCatalogItem(
                id: "meat_chicken_breast_grilled",
                name: "Куриное филе на гриле / запеченное",
                category: .meat,
                caloriesPer100g: 165,
                proteinPer100g: 31.0,
                fatPer100g: 3.6,
                carbsPer100g: 0.0,
                defaultPortionGrams: 150,
                portionName: "1 стейк (150г)",
                textureType: .solidDense,
                emoji: "🍗",
                aliases: ["куриный стейк", "грудка на гриле", "курица запеченная"]
            ),
            FoodCatalogItem(
                id: "meat_turkey_fillet",
                name: "Филе индейки запеченное",
                category: .meat,
                caloriesPer100g: 145,
                proteinPer100g: 28.0,
                fatPer100g: 2.5,
                carbsPer100g: 0.0,
                defaultPortionGrams: 150,
                portionName: "1 порция (150г)",
                textureType: .solidDense,
                emoji: "🦃",
                aliases: ["индейка", "грудка индейки", "стейк индейки"]
            ),
            FoodCatalogItem(
                id: "meat_beef_lean_boiled",
                name: "Говядина нежирная отварная",
                category: .meat,
                caloriesPer100g: 215,
                proteinPer100g: 25.8,
                fatPer100g: 12.4,
                carbsPer100g: 0.0,
                defaultPortionGrams: 150,
                portionName: "1 порция (150г)",
                textureType: .solidDense,
                emoji: "🥩",
                aliases: ["говядина", "телятина", "вареная говядина"]
            ),
            FoodCatalogItem(
                id: "meat_beef_steak",
                name: "Говяжий стейк (миньон / стриплойн)",
                category: .meat,
                caloriesPer100g: 240,
                proteinPer100g: 26.0,
                fatPer100g: 15.0,
                carbsPer100g: 0.0,
                defaultPortionGrams: 200,
                portionName: "1 стейк (200г)",
                textureType: .solidDense,
                emoji: "🥩",
                aliases: ["стейк", "рибай", "миньон", "говядина гриль"]
            ),
            FoodCatalogItem(
                id: "meat_beef_cutlet_steam",
                name: "Котлета говяжья паровая",
                category: .meat,
                caloriesPer100g: 185,
                proteinPer100g: 18.0,
                fatPer100g: 11.5,
                carbsPer100g: 3.5,
                defaultPortionGrams: 100,
                portionName: "1 котлета (100г)",
                textureType: .solidDense,
                emoji: "🧆",
                aliases: ["котлета", "бифштекс", "тефтели"]
            ),
            FoodCatalogItem(
                id: "meat_pork_tenderloin",
                name: "Свиная вырезка запеченная",
                category: .meat,
                caloriesPer100g: 195,
                proteinPer100g: 26.0,
                fatPer100g: 9.8,
                carbsPer100g: 0.0,
                defaultPortionGrams: 150,
                portionName: "1 порция (150г)",
                textureType: .solidDense,
                emoji: "🥩",
                aliases: ["свинина нежирная", "вырезка свиная", "карбонад"]
            )
        ])
        
        // --- 3. РЫБА И МОРЕПРОДУКТЫ ---
        items.append(contentsOf: [
            FoodCatalogItem(
                id: "fish_salmon_baked",
                name: "Лосось / Семга запеченная",
                category: .fish,
                caloriesPer100g: 206,
                proteinPer100g: 22.0,
                fatPer100g: 13.0,
                carbsPer100g: 0.0,
                defaultPortionGrams: 150,
                portionName: "1 стейк (150г)",
                textureType: .solidDense,
                emoji: "🐟",
                aliases: ["лосось", "семга", "форель", "красная рыба"]
            ),
            FoodCatalogItem(
                id: "fish_tuna_canned",
                name: "Тунец в собственном соку",
                category: .fish,
                caloriesPer100g: 108,
                proteinPer100g: 25.0,
                fatPer100g: 0.8,
                carbsPer100g: 0.0,
                defaultPortionGrams: 130,
                portionName: "1 банка (130г)",
                textureType: .solidDense,
                emoji: "🐟",
                aliases: ["тунец", "тунец консервированный"]
            ),
            FoodCatalogItem(
                id: "fish_cod_baked",
                name: "Треска / Минтай запеченный",
                category: .fish,
                caloriesPer100g: 82,
                proteinPer100g: 18.2,
                fatPer100g: 0.7,
                carbsPer100g: 0.0,
                defaultPortionGrams: 180,
                portionName: "1 порция (180г)",
                textureType: .solidDense,
                emoji: "🐟",
                aliases: ["треска", "минтай", "хек", "белая рыба"]
            ),
            FoodCatalogItem(
                id: "fish_shrimp_boiled",
                name: "Креветки очищенные вареные",
                category: .fish,
                caloriesPer100g: 95,
                proteinPer100g: 21.0,
                fatPer100g: 1.2,
                carbsPer100g: 0.0,
                defaultPortionGrams: 150,
                portionName: "1 порция (150г)",
                textureType: .solidDense,
                emoji: "🦐",
                aliases: ["креветки", "лангустины", "морепродукты"]
            ),
            FoodCatalogItem(
                id: "fish_squid_boiled",
                name: "Кальмар вареный",
                category: .fish,
                caloriesPer100g: 110,
                proteinPer100g: 22.0,
                fatPer100g: 1.8,
                carbsPer100g: 1.2,
                defaultPortionGrams: 150,
                portionName: "1 порция (150г)",
                textureType: .solidDense,
                emoji: "🦑",
                aliases: ["кальмары", "тушка кальмара"]
            )
        ])
        
        // --- 4. ЯЙЦА И МОЛОЧНЫЕ ПРОДУКТЫ ---
        items.append(contentsOf: [
            FoodCatalogItem(
                id: "dairy_egg_boiled",
                name: "Яйцо куриное вареное",
                category: .dairy,
                caloriesPer100g: 155,
                proteinPer100g: 13.0,
                fatPer100g: 11.0,
                carbsPer100g: 0.7,
                defaultPortionGrams: 55,
                portionName: "1 яйцо C1 (55г)",
                textureType: .solidDense,
                emoji: "🥚",
                aliases: ["яйцо", "яйцо всмятку", "яйцо вкрутую", "пашот"]
            ),
            FoodCatalogItem(
                id: "dairy_scrambled_eggs",
                name: "Яичница из 2 яиц с зеленью",
                category: .dairy,
                caloriesPer100g: 185,
                proteinPer100g: 12.5,
                fatPer100g: 14.5,
                carbsPer100g: 1.0,
                defaultPortionGrams: 120,
                portionName: "Порция из 2 яиц (120г)",
                textureType: .solidDense,
                emoji: "🍳",
                aliases: ["яичница", "глазунья", "омлет", "скрэмбл"]
            ),
            FoodCatalogItem(
                id: "dairy_cottage_cheese_5",
                name: "Творог 5% мягкий/рассыпчатый",
                category: .dairy,
                caloriesPer100g: 121,
                proteinPer100g: 16.5,
                fatPer100g: 5.0,
                carbsPer100g: 2.8,
                defaultPortionGrams: 180,
                portionName: "1 пачка (180г)",
                textureType: .lightFresh,
                emoji: "🧀",
                aliases: ["творог", "творожок", "простоквашино"]
            ),
            FoodCatalogItem(
                id: "dairy_cottage_cheese_0",
                name: "Творог обезжиренный 0.5%",
                category: .dairy,
                caloriesPer100g: 78,
                proteinPer100g: 18.0,
                fatPer100g: 0.5,
                carbsPer100g: 1.8,
                defaultPortionGrams: 180,
                portionName: "1 пачка (180г)",
                textureType: .lightFresh,
                emoji: "🧀",
                aliases: ["творог 0%", "обезжиренный творог"]
            ),
            FoodCatalogItem(
                id: "dairy_greek_yogurt",
                name: "Греческий йогурт натуральный 2%",
                category: .dairy,
                caloriesPer100g: 66,
                proteinPer100g: 8.5,
                fatPer100g: 2.0,
                carbsPer100g: 3.5,
                defaultPortionGrams: 140,
                portionName: "1 стаканчик (140г)",
                textureType: .lightFresh,
                emoji: "🥣",
                aliases: ["йогурт", "теос", "греческий йогурт"]
            ),
            FoodCatalogItem(
                id: "dairy_kefir_1",
                name: "Кефир 1%",
                category: .dairy,
                caloriesPer100g: 40,
                proteinPer100g: 3.0,
                fatPer100g: 1.0,
                carbsPer100g: 4.0,
                defaultPortionGrams: 250,
                portionName: "1 стакан (250мл)",
                textureType: .liquidSoup,
                emoji: "🥛",
                aliases: ["кефир", "кисломолочный напиток"]
            ),
            FoodCatalogItem(
                id: "dairy_milk_25",
                name: "Молоко 2.5%",
                category: .dairy,
                caloriesPer100g: 52,
                proteinPer100g: 2.9,
                fatPer100g: 2.5,
                carbsPer100g: 4.7,
                defaultPortionGrams: 200,
                portionName: "1 стакан (200мл)",
                textureType: .liquidSoup,
                emoji: "🥛",
                aliases: ["молоко", "молочко"]
            ),
            FoodCatalogItem(
                id: "dairy_cheese_hard",
                name: "Сыр твердый (Российский / Гауда / Тильзитер 45%)",
                category: .dairy,
                caloriesPer100g: 360,
                proteinPer100g: 25.0,
                fatPer100g: 29.0,
                carbsPer100g: 0.0,
                defaultPortionGrams: 30,
                portionName: "1 ломтик (30г)",
                textureType: .solidDense,
                emoji: "🧀",
                aliases: ["сыр", "гауда", "тильзитер", "пармезан"]
            ),
            FoodCatalogItem(
                id: "dairy_mozzarella",
                name: "Сыр Моцарелла в рассоле",
                category: .dairy,
                caloriesPer100g: 240,
                proteinPer100g: 18.0,
                fatPer100g: 18.5,
                carbsPer100g: 1.0,
                defaultPortionGrams: 100,
                portionName: "1 шарик (100г)",
                textureType: .solidDense,
                emoji: "🧀",
                aliases: ["моцарелла", "моцарелла мини"]
            )
        ])
        
        // --- 5. СУПЫ И БУЛЬОНЫ (КЛЮЧЕВЫЕ ДЛЯ БАЛАНСА ЖКТ) ---
        items.append(contentsOf: [
            FoodCatalogItem(
                id: "soup_chicken_broth",
                name: "Куриный бульон прозрачный с зеленью",
                category: .soups,
                caloriesPer100g: 28,
                proteinPer100g: 3.5,
                fatPer100g: 1.4,
                carbsPer100g: 0.3,
                defaultPortionGrams: 350,
                portionName: "1 большая пиала (350мл)",
                textureType: .liquidSoup,
                emoji: "🍲",
                aliases: ["бульон куриный", "бульончик", "куриный суп"]
            ),
            FoodCatalogItem(
                id: "soup_bone_broth",
                name: "Костный бульон с коллагеном (томленый)",
                category: .soups,
                caloriesPer100g: 35,
                proteinPer100g: 5.5,
                fatPer100g: 1.2,
                carbsPer100g: 0.2,
                defaultPortionGrams: 300,
                portionName: "1 кружка (300мл)",
                textureType: .liquidSoup,
                emoji: "🥣",
                aliases: ["костный бульон", "говяжий бульон", "коллагеновый бульон"]
            ),
            FoodCatalogItem(
                id: "soup_borscht_beef",
                name: "Борщ домашний со свеклой и говядиной",
                category: .soups,
                caloriesPer100g: 65,
                proteinPer100g: 4.8,
                fatPer100g: 3.2,
                carbsPer100g: 4.5,
                defaultPortionGrams: 350,
                portionName: "1 тарелка (350г)",
                textureType: .liquidSoup,
                emoji: "🍲",
                aliases: ["борщ", "борщец", "суп свекольный"]
            ),
            FoodCatalogItem(
                id: "soup_chicken_noodle",
                name: "Куриный суп с лапшой и морковью",
                category: .soups,
                caloriesPer100g: 48,
                proteinPer100g: 4.0,
                fatPer100g: 1.8,
                carbsPer100g: 4.2,
                defaultPortionGrams: 350,
                portionName: "1 тарелка (350г)",
                textureType: .liquidSoup,
                emoji: "🍜",
                aliases: ["куриная лапша", "супчик куриный"]
            ),
            FoodCatalogItem(
                id: "soup_pumpkin_puree",
                name: "Тыквенный крем-суп с легкими сливками",
                category: .soups,
                caloriesPer100g: 62,
                proteinPer100g: 1.8,
                fatPer100g: 3.5,
                carbsPer100g: 6.0,
                defaultPortionGrams: 300,
                portionName: "1 тарелка (300г)",
                textureType: .liquidSoup,
                emoji: "🥣",
                aliases: ["крем-суп", "суп пюре", "тыквенный суп"]
            ),
            FoodCatalogItem(
                id: "soup_lentil",
                name: "Чечевичный суп-пюре (Мерджимек)",
                category: .soups,
                caloriesPer100g: 68,
                proteinPer100g: 4.5,
                fatPer100g: 1.6,
                carbsPer100g: 9.0,
                defaultPortionGrams: 300,
                portionName: "1 тарелка (300г)",
                textureType: .liquidSoup,
                emoji: "🥣",
                aliases: ["чечевичный суп", "суп из чечевицы", "мерджимек"]
            ),
            FoodCatalogItem(
                id: "soup_ukha",
                name: "Уха рыбацкая из лосося и судака",
                category: .soups,
                caloriesPer100g: 42,
                proteinPer100g: 5.5,
                fatPer100g: 1.6,
                carbsPer100g: 1.5,
                defaultPortionGrams: 350,
                portionName: "1 тарелка (350г)",
                textureType: .liquidSoup,
                emoji: "🍲",
                aliases: ["уха", "рыбный суп"]
            )
        ])
        
        // --- 6. ОВОЩИ И ЗЕЛЕНЬ ---
        items.append(contentsOf: [
            FoodCatalogItem(
                id: "veg_cucumber",
                name: "Огурец свежий",
                category: .vegetables,
                caloriesPer100g: 15,
                proteinPer100g: 0.8,
                fatPer100g: 0.1,
                carbsPer100g: 2.8,
                defaultPortionGrams: 120,
                portionName: "1 средний огурец (120г)",
                textureType: .lightFresh,
                emoji: "🥒",
                aliases: ["огурец", "огурчик"]
            ),
            FoodCatalogItem(
                id: "veg_tomato",
                name: "Помидор свежий (томат)",
                category: .vegetables,
                caloriesPer100g: 18,
                proteinPer100g: 0.9,
                fatPer100g: 0.2,
                carbsPer100g: 3.9,
                defaultPortionGrams: 150,
                portionName: "1 крупный помидор (150г)",
                textureType: .lightFresh,
                emoji: "🍅",
                aliases: ["помидор", "томат", "черри"]
            ),
            FoodCatalogItem(
                id: "veg_bell_pepper",
                name: "Перец болгарский сладкий",
                category: .vegetables,
                caloriesPer100g: 27,
                proteinPer100g: 1.3,
                fatPer100g: 0.1,
                carbsPer100g: 5.3,
                defaultPortionGrams: 150,
                portionName: "1 перец (150г)",
                textureType: .lightFresh,
                emoji: "🫑",
                aliases: ["перец", "болгарский перец", "паприка"]
            ),
            FoodCatalogItem(
                id: "veg_broccoli_steamed",
                name: "Брокколи на пару",
                category: .vegetables,
                caloriesPer100g: 35,
                proteinPer100g: 2.8,
                fatPer100g: 0.4,
                carbsPer100g: 5.1,
                defaultPortionGrams: 150,
                portionName: "1 порция (150г)",
                textureType: .lightFresh,
                emoji: "🥦",
                aliases: ["брокколи", "капуста брокколи"]
            ),
            FoodCatalogItem(
                id: "veg_cabbage_fresh",
                name: "Капуста белокочанная свежая",
                category: .vegetables,
                caloriesPer100g: 25,
                proteinPer100g: 1.8,
                fatPer100g: 0.1,
                carbsPer100g: 4.7,
                defaultPortionGrams: 150,
                portionName: "Салатная порция (150г)",
                textureType: .lightFresh,
                emoji: "🥬",
                aliases: ["капуста", "салат из капусты"]
            ),
            FoodCatalogItem(
                id: "veg_spinach_arugula",
                name: "Микс салата (шпинат, руккола, айсберг)",
                category: .vegetables,
                caloriesPer100g: 22,
                proteinPer100g: 2.5,
                fatPer100g: 0.3,
                carbsPer100g: 2.2,
                defaultPortionGrams: 80,
                portionName: "Большая горсть (80г)",
                textureType: .lightFresh,
                emoji: "🥗",
                aliases: ["зелень", "листья салата", "шпинат", "руккола"]
            )
        ])
        
        // --- 7. ФРУКТЫ И ЯГОДЫ ---
        items.append(contentsOf: [
            FoodCatalogItem(
                id: "fruit_banana",
                name: "Банан свежий",
                category: .fruits,
                caloriesPer100g: 89,
                proteinPer100g: 1.1,
                fatPer100g: 0.3,
                carbsPer100g: 22.8,
                defaultPortionGrams: 120,
                portionName: "1 очищенный банан (120г)",
                textureType: .lightFresh,
                emoji: "🍌",
                aliases: ["банан", "бананчик"]
            ),
            FoodCatalogItem(
                id: "fruit_apple_green",
                name: "Яблоко зеленое (Гренни Смит)",
                category: .fruits,
                caloriesPer100g: 52,
                proteinPer100g: 0.4,
                fatPer100g: 0.2,
                carbsPer100g: 13.8,
                defaultPortionGrams: 160,
                portionName: "1 среднее яблоко (160г)",
                textureType: .lightFresh,
                emoji: "🍏",
                aliases: ["яблоко", "зеленое яблоко"]
            ),
            FoodCatalogItem(
                id: "fruit_orange",
                name: "Апельсин свежий",
                category: .fruits,
                caloriesPer100g: 43,
                proteinPer100g: 0.9,
                fatPer100g: 0.2,
                carbsPer100g: 8.1,
                defaultPortionGrams: 180,
                portionName: "1 средний апельсин (180г)",
                textureType: .lightFresh,
                emoji: "🍊",
                aliases: ["апельсин", "цитрус"]
            ),
            FoodCatalogItem(
                id: "fruit_avocado",
                name: "Авокадо Хасс спелый",
                category: .fruits,
                caloriesPer100g: 160,
                proteinPer100g: 2.0,
                fatPer100g: 14.7,
                carbsPer100g: 8.5,
                defaultPortionGrams: 75,
                portionName: "Половинка авокадо (75г)",
                textureType: .lightFresh,
                emoji: "🥑",
                aliases: ["авокадо", "хасс"]
            ),
            FoodCatalogItem(
                id: "fruit_berries_mix",
                name: "Свежие ягоды (клубника, черника, малина)",
                category: .fruits,
                caloriesPer100g: 45,
                proteinPer100g: 0.8,
                fatPer100g: 0.4,
                carbsPer100g: 8.5,
                defaultPortionGrams: 150,
                portionName: "1 чашка ягод (150г)",
                textureType: .lightFresh,
                emoji: "🫐",
                aliases: ["ягоды", "клубника", "черника", "малина", "голубика"]
            )
        ])
        
        // --- 8. ХЛЕБ, ОРЕХИ, НАПИТКИ И СНЕКИ ---
        items.append(contentsOf: [
            FoodCatalogItem(
                id: "bakery_wholegrain_bread",
                name: "Хлеб цельнозерновой / ржаной",
                category: .bakery,
                caloriesPer100g: 215,
                proteinPer100g: 8.5,
                fatPer100g: 1.5,
                carbsPer100g: 41.0,
                defaultPortionGrams: 35,
                portionName: "1 ломтик (35г)",
                textureType: .solidDense,
                emoji: "🍞",
                aliases: ["хлеб", "бородинский", "цельнозерновой", "тост"]
            ),
            FoodCatalogItem(
                id: "nuts_almonds",
                name: "Миндаль сушеный / обжаренный",
                category: .nutsAndOils,
                caloriesPer100g: 579,
                proteinPer100g: 21.2,
                fatPer100g: 49.9,
                carbsPer100g: 21.6,
                defaultPortionGrams: 30,
                portionName: "Горсть миндаля (30г)",
                textureType: .solidDense,
                emoji: "🥜",
                aliases: ["миндаль", "орехи"]
            ),
            FoodCatalogItem(
                id: "nuts_olive_oil",
                name: "Оливковое масло Extra Virgin",
                category: .nutsAndOils,
                caloriesPer100g: 884,
                proteinPer100g: 0.0,
                fatPer100g: 100.0,
                carbsPer100g: 0.0,
                defaultPortionGrams: 10,
                portionName: "1 столовая ложка (10г)",
                textureType: .liquidSoup,
                emoji: "🫒",
                aliases: ["масло", "оливковое масло", "растительное масло"]
            ),
            FoodCatalogItem(
                id: "bev_cappuccino",
                name: "Капучино на обычном молоке без сахара",
                category: .beverages,
                caloriesPer100g: 45,
                proteinPer100g: 2.5,
                fatPer100g: 2.2,
                carbsPer100g: 3.8,
                defaultPortionGrams: 250,
                portionName: "1 чашка (250мл)",
                textureType: .liquidSoup,
                emoji: "☕️",
                aliases: ["капучино", "кофе", "латте"]
            ),
            FoodCatalogItem(
                id: "bev_protein_shake",
                name: "Протеиновый коктейль (сывороточный на воде)",
                category: .beverages,
                caloriesPer100g: 40,
                proteinPer100g: 8.0,
                fatPer100g: 0.5,
                carbsPer100g: 1.0,
                defaultPortionGrams: 300,
                portionName: "1 шейкер (300мл с 1 скуп)",
                textureType: .liquidSoup,
                emoji: "🥤",
                aliases: ["протеин", "сывороточный протеин", "шейк", "изолят"]
            ),
            FoodCatalogItem(
                id: "snack_dark_chocolate",
                name: "Темный шоколад 75%+",
                category: .snacks,
                caloriesPer100g: 545,
                proteinPer100g: 7.8,
                fatPer100g: 42.6,
                carbsPer100g: 30.8,
                defaultPortionGrams: 20,
                portionName: "2 дольки (20г)",
                textureType: .solidDense,
                emoji: "🍫",
                aliases: ["шоколад", "горький шоколад"]
            )
        ])
        
        return items
    }
}
