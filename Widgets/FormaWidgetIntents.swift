import Foundation
import AppIntents
import WidgetKit

// MARK: - 1. Быстрое фоновое добавление воды из интерактивного виджета
@available(iOS 17.0, *)
public struct AddWaterWidgetIntent: AppIntent {
    public static var title: LocalizedStringResource = "Добавить воду"
    public static var description = IntentDescription("Быстро добавляет объем воды прямо из виджета без открытия приложения.")
    
    @Parameter(title: "Объем (мл)", default: 250)
    public var amountMl: Int
    
    public init() {
        self.amountMl = 250
    }
    
    public init(amountMl: Int) {
        self.amountMl = amountMl
    }
    
    public func perform() async throws -> some IntentResult {
        let actualAmount = Double(max(50, amountMl))
        
        // 1. Обновляем снимок виджета
        var snapshot = FormaWidgetDataManager.shared.getSnapshot()
        snapshot.waterConsumed += actualAmount
        snapshot.lastUpdated = Date()
        FormaWidgetDataManager.shared.saveSnapshot(snapshot)
        
        // 2. Записываем в очередь отложенной синхронизации для HealthKit (через App Group)
        let defaultsList: [UserDefaults] = [
            UserDefaults(suiteName: FormaWidgetDataManager.appGroupId),
            UserDefaults.standard
        ].compactMap { $0 }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayKey = formatter.string(from: Date())
        
        for def in defaultsList {
            let currentPending = def.double(forKey: "forma_pending_widget_water_ml")
            def.set(currentPending + actualAmount, forKey: "forma_pending_widget_water_ml")
            
            let currentDayWater = def.double(forKey: "local_water_\(todayKey)")
            def.set(currentDayWater + actualAmount, forKey: "local_water_\(todayKey)")
            def.set(snapshot.waterConsumed, forKey: "w_water_consumed")
            
            def.synchronize()
        }
        
        // 3. Обновляем таймлайны виджетов
        WidgetCenter.shared.reloadAllTimelines()
        
        return .result()
    }
}

// MARK: - 2. Запуск ИИ-сканера еды из виджета (Home Screen / Lock Screen)
@available(iOS 17.0, *)
public struct OpenFoodScannerWidgetIntent: AppIntent {
    public static var title: LocalizedStringResource = "Сканировать еду"
    public static var description = IntentDescription("Открывает ИИ-камеру Forma для мгновенного сканирования блюда.")
    public static var openAppWhenRun: Bool = true
    
    public init() {}
    
    @MainActor
    public func perform() async throws -> some IntentResult {
        // Уведомляем приложение об открытии сканера еды
        NotificationCenter.default.post(name: NSNotification.Name("OpenFoodScanner"), object: nil)
        return .result()
    }
}
