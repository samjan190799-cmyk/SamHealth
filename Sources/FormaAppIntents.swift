import Foundation
import AppIntents
import SwiftUI
import HealthKit

// MARK: - 1. Интент для открытия камеры и сканирования еды через Siri / Camera Control
@available(iOS 16.0, *)
public struct ScanFoodIntent: AppIntent {
    public static var title: LocalizedStringResource = "Сканировать еду"
    public static var description = IntentDescription("Открывает камеру Forma для распознавания блюда и подсчета калорий с БЖУ.")
    public static var openAppWhenRun: Bool = true
    
    public init() {}
    
    @MainActor
    public func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: NSNotification.Name("OpenFoodScanner"), object: nil)
        return .result()
    }
}

// MARK: - 2. Интент для голосового запроса баланса калорий у Siri
@available(iOS 16.0, *)
public struct CheckCalorieBalanceIntent: AppIntent {
    public static var title: LocalizedStringResource = "Узнать баланс калорий"
    public static var description = IntentDescription("Озвучивает сожженные калории (активные + покой), калории из еды и суточный баланс.")
    
    public init() {}
    
    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayKey = formatter.string(from: Date())
        
        let defaults = UserDefaults.standard
        let active = defaults.double(forKey: "health_active_energy_\(todayKey)")
        let basal = defaults.double(forKey: "health_basal_energy_\(todayKey)")
        let consumed = defaults.double(forKey: "local_nutrition_calories_\(todayKey)")
        
        let totalBurned = (active > 0 || basal > 0) ? (active + basal) : (active > 0 ? active : 1800.0)
        let balance = consumed - totalBurned
        
        let dialogText: String
        if balance <= 0 {
            dialogText = String(
                format: "Сегодня сожжено %.0f ккал (из них %.0f активных). Потреблено %.0f ккал. Дефицит: %.0f ккал.",
                totalBurned, active, consumed, abs(balance)
            )
        } else {
            dialogText = String(
                format: "Сегодня сожжено %.0f ккал. Потреблено %.0f ккал. Профицит калорий: +%.0f ккал.",
                totalBurned, consumed, balance
            )
        }
        
        return .result(dialog: IntentDialog(stringLiteral: dialogText))
    }
}

// MARK: - 3. Интент для голосовой записи выпитой воды через Siri
@available(iOS 16.0, *)
public struct LogWaterIntent: AppIntent {
    public static var title: LocalizedStringResource = "Записать воду"
    public static var description = IntentDescription("Добавляет объем выпитой воды в дневник гидратации и статистики.")
    
    @Parameter(title: "Объем (мл)", default: 250.0)
    public var amountMl: Double
    
    public init() {
        self.amountMl = 250.0
    }
    
    public init(amountMl: Double) {
        self.amountMl = amountMl
    }
    
    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let actualAmount = max(50.0, amountMl)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayKey = formatter.string(from: Date())
        
        let defaults = UserDefaults.standard
        let current = defaults.double(forKey: "local_water_\(todayKey)")
        let newTotal = current + actualAmount
        defaults.set(newTotal, forKey: "local_water_\(todayKey)")
        
        HealthKitManager.logWaterDirectly(amount: actualAmount)
        
        NotificationCenter.default.post(name: NSNotification.Name("RefreshHealthKitData"), object: nil)
        
        let dialogText = String(format: "Записано %.0f мл воды. Всего за сегодня: %.1f л.", actualAmount, newTotal / 1000.0)
        return .result(dialog: IntentDialog(stringLiteral: dialogText))
    }
}

// MARK: - 4. Интент для быстрой голосовой записи калорий питания
@available(iOS 16.0, *)
public struct LogQuickMealIntent: AppIntent {
    public static var title: LocalizedStringResource = "Записать прием пищи"
    public static var description = IntentDescription("Быстро добавляет калории съеденного блюда в дневник питания.")
    
    @Parameter(title: "Калории (ккал)", default: 300.0)
    public var calories: Double
    
    @Parameter(title: "Название блюда", default: "Прием пищи")
    public var mealName: String
    
    public init() {
        self.calories = 300.0
        self.mealName = "Прием пищи"
    }
    
    public init(calories: Double, mealName: String) {
        self.calories = calories
        self.mealName = mealName
    }
    
    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let actualCalories = max(10.0, calories)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayKey = formatter.string(from: Date())
        
        let defaults = UserDefaults.standard
        let current = defaults.double(forKey: "local_nutrition_calories_\(todayKey)")
        let newTotal = current + actualCalories
        defaults.set(newTotal, forKey: "local_nutrition_calories_\(todayKey)")
        
        HealthKitManager.logNutritionDirectly(calories: actualCalories, mealName: mealName)
        
        NotificationCenter.default.post(name: NSNotification.Name("RefreshHealthKitData"), object: nil)
        
        let dialogText = String(format: "Записано: %@ (%.0f ккал). Всего за день: %.0f ккал.", mealName, actualCalories, newTotal)
        return .result(dialog: IntentDialog(stringLiteral: dialogText))
    }
}

// MARK: - 5. Системный реестр шорткатов Siri (AppShortcutsProvider)
@available(iOS 16.0, *)
public struct FormaShortcutsProvider: AppShortcutsProvider {
    public static var shortcutTileColor: ShortcutTileColor = .orange
    
    public static var appShortcuts: [AppShortcut] {
        return [
            AppShortcut(
                intent: ScanFoodIntent(),
                phrases: [
                    "Сканируй еду в \(.applicationName)",
                    "Scan food in \(.applicationName)"
                ],
                shortTitle: "Сканировать еду",
                systemImageName: "camera.viewfinder"
            ),
            AppShortcut(
                intent: CheckCalorieBalanceIntent(),
                phrases: [
                    "Баланс калорий в \(.applicationName)",
                    "Check calories in \(.applicationName)"
                ],
                shortTitle: "Баланс калорий",
                systemImageName: "flame.fill"
            ),
            AppShortcut(
                intent: LogWaterIntent(),
                phrases: [
                    "Запиши воду в \(.applicationName)",
                    "Log water in \(.applicationName)"
                ],
                shortTitle: "Записать воду",
                systemImageName: "drop.fill"
            ),
            AppShortcut(
                intent: LogQuickMealIntent(),
                phrases: [
                    "Запиши еду в \(.applicationName)",
                    "Log meal in \(.applicationName)"
                ],
                shortTitle: "Записать еду",
                systemImageName: "fork.knife"
            )
        ]
    }
}
