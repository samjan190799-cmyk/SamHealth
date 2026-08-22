import Foundation
import HealthKit
import SwiftUI

/// Категории данных здоровья для импорта/экспорта
public enum HealthDataCategory: String, CaseIterable, Identifiable {
    case workouts = "workouts"
    case weight = "weight"
    case activity = "activity"
    case nutrition = "nutrition"
    case unknown = "unknown"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .workouts: return "figure.run"
        case .weight: return "scalemass.fill"
        case .activity: return "flame.fill"
        case .nutrition: return "fork.knife"
        case .unknown: return "doc.text.fill"
        }
    }
    
    public func localizedTitle(lang: String) -> String {
        switch self {
        case .workouts:
            return lang == "ru" ? "Тренировки" : (lang == "hy" ? "Մարզումներ" : "Workouts")
        case .weight:
            return lang == "ru" ? "Замеры веса" : (lang == "hy" ? "Քաշի չափումներ" : "Weight Logs")
        case .activity:
            return lang == "ru" ? "Шаги и активность" : (lang == "hy" ? "Քայլեր և ակտիվություն" : "Daily Activity")
        case .nutrition:
            return lang == "ru" ? "Питание и вода" : (lang == "hy" ? "Սնունդ և ջուր" : "Nutrition & Water")
        case .unknown:
            return lang == "ru" ? "Неопознанный файл" : (lang == "hy" ? "Անհայտ ֆայլ" : "Unknown Format")
        }
    }
}

/// Результат предварительного анализа CSV перед импортом
public struct HealthDataImportPreview: Identifiable {
    public let id = UUID()
    public var fileName: String
    public var category: HealthDataCategory
    public var totalRowsFound: Int
    public var validRecordsCount: Int
    public var parsedWorkouts: [WorkoutRecord] = []
    public var parsedWeights: [WeightRecord] = []
    public var parsedActivities: [DailyActivitySummary] = []
    public var parsedNutritions: [DailyNutritionRecord] = []
    public var parsedWaterRecords: [(date: Date, ml: Double)] = []
    public var previewTableRows: [[String: String]] = []
    public var tableHeaders: [String] = []
    public var warnings: [String] = []
}

/// Универсальный менеджер импорта и экспорта данных Apple Health через CSV
@MainActor
public final class HealthDataCSVManager {
    public static let shared = HealthDataCSVManager()
    
    private let healthStore = HKHealthStore()
    
    private init() {}
    
    // MARK: - Парсер CSV
    
    /// Парсинг содержимого файла CSV с автоматическим распознаванием категории и колонок
    public func parseCSV(content: String, fileName: String = "health_data.csv") -> HealthDataImportPreview {
        var cleanContent = content
        if cleanContent.hasPrefix("\u{feff}") {
            cleanContent.removeFirst()
        }
        
        let lines = cleanContent
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
        
        guard let headerLine = lines.first, lines.count > 1 else {
            return HealthDataImportPreview(
                fileName: fileName,
                category: .unknown,
                totalRowsFound: 0,
                validRecordsCount: 0,
                warnings: ["Файл пуст или не содержит строк с данными"]
            )
        }
        
        // Авто-определение разделителя
        let delimiter = detectDelimiter(in: headerLine)
        let rawHeaders = splitCSVLine(headerLine, delimiter: delimiter)
        let normalizedHeaders = rawHeaders.map { normalizeHeader($0) }
        
        // Авто-определение категории
        let category = detectCategory(from: normalizedHeaders)
        
        var preview = HealthDataImportPreview(
            fileName: fileName,
            category: category,
            totalRowsFound: lines.count - 1,
            validRecordsCount: 0,
            tableHeaders: rawHeaders
        )
        
        let dataLines = Array(lines.dropFirst())
        
        // Поколоночный парсинг
        switch category {
        case .workouts:
            parseWorkouts(dataLines: dataLines, headers: normalizedHeaders, rawHeaders: rawHeaders, delimiter: delimiter, preview: &preview)
        case .weight:
            parseWeights(dataLines: dataLines, headers: normalizedHeaders, rawHeaders: rawHeaders, delimiter: delimiter, preview: &preview)
        case .activity:
            parseActivities(dataLines: dataLines, headers: normalizedHeaders, rawHeaders: rawHeaders, delimiter: delimiter, preview: &preview)
        case .nutrition:
            parseNutritions(dataLines: dataLines, headers: normalizedHeaders, rawHeaders: rawHeaders, delimiter: delimiter, preview: &preview)
        case .unknown:
            preview.warnings.append("Не удалось сопоставить колонки: \(rawHeaders.joined(separator: ", ")). Используйте стандартный шаблон.")
        }
        
        return preview
    }
    
    // MARK: - Парсинг категорий
    
    private func parseWorkouts(dataLines: [String], headers: [String], rawHeaders: [String], delimiter: Character, preview: inout HealthDataImportPreview) {
        let dateIdx = findIndex(in: headers, keys: ["date", "дата", "time", "datetime", "startdate", "start_date", "timestamp"])
        let typeIdx = findIndex(in: headers, keys: ["type", "тип", "activity", "вид", "workout", "workouttype", "activitytype", "name", "упражнение"])
        let durationIdx = findIndex(in: headers, keys: ["duration", "длительность", "durationminutes", "duration_minutes", "минуты", "minutes", "min", "время"])
        let caloriesIdx = findIndex(in: headers, keys: ["calories", "калории", "energy", "activeenergy", "activecalories", "ккал", "kcal", "сожжено"])
        
        var workouts: [WorkoutRecord] = []
        var previewRows: [[String: String]] = []
        
        for line in dataLines {
            let cols = splitCSVLine(line, delimiter: delimiter)
            guard cols.count > 0 else { continue }
            
            let dateVal = parseDate(from: safeGet(cols, index: dateIdx)) ?? Date()
            let typeVal = safeGet(cols, index: typeIdx).trimmingCharacters(in: .whitespaces)
            let finalType = typeVal.isEmpty ? "Тренировка" : typeVal
            
            let durRaw = safeGet(cols, index: durationIdx)
            let durationVal = Int(parseNumber(durRaw) ?? 30.0)
            
            let calRaw = safeGet(cols, index: caloriesIdx)
            let caloriesVal = parseNumber(calRaw) ?? (Double(durationVal) * 7.5)
            
            let record = WorkoutRecord(
                type: finalType,
                date: dateVal,
                durationMinutes: max(1, durationVal),
                caloriesBurned: max(0.0, caloriesVal)
            )
            workouts.append(record)
            
            if previewRows.count < 6 {
                var rowMap: [String: String] = [:]
                for (idx, rawH) in rawHeaders.enumerated() {
                    rowMap[rawH] = safeGet(cols, index: idx)
                }
                previewRows.append(rowMap)
            }
        }
        
        preview.parsedWorkouts = workouts
        preview.validRecordsCount = workouts.count
        preview.previewTableRows = previewRows
    }
    
    private func parseWeights(dataLines: [String], headers: [String], rawHeaders: [String], delimiter: Character, preview: inout HealthDataImportPreview) {
        let dateIdx = findIndex(in: headers, keys: ["date", "дата", "time", "datetime", "timestamp", "день"])
        let weightIdx = findIndex(in: headers, keys: ["weight", "вес", "bodymass", "mass", "вес (кг)", "weight (kg)", "value", "значение", "кг", "kg"])
        
        var weights: [WeightRecord] = []
        var previewRows: [[String: String]] = []
        
        for line in dataLines {
            let cols = splitCSVLine(line, delimiter: delimiter)
            guard cols.count > 0 else { continue }
            
            let dateVal = parseDate(from: safeGet(cols, index: dateIdx)) ?? Date()
            let weightRaw = safeGet(cols, index: weightIdx)
            
            guard let w = parseNumber(weightRaw), w >= 20.0 && w <= 350.0 else {
                continue
            }
            
            let record = WeightRecord(
                date: dateVal,
                weight: w
            )
            weights.append(record)
            
            if previewRows.count < 6 {
                var rowMap: [String: String] = [:]
                for (idx, rawH) in rawHeaders.enumerated() {
                    rowMap[rawH] = safeGet(cols, index: idx)
                }
                previewRows.append(rowMap)
            }
        }
        
        // Сортировка по возрастанию даты
        weights.sort { $0.date < $1.date }
        
        preview.parsedWeights = weights
        preview.validRecordsCount = weights.count
        preview.previewTableRows = previewRows
    }
    
    private func parseActivities(dataLines: [String], headers: [String], rawHeaders: [String], delimiter: Character, preview: inout HealthDataImportPreview) {
        let dateIdx = findIndex(in: headers, keys: ["date", "дата", "day", "день", "datekey", "timestamp"])
        let stepsIdx = findIndex(in: headers, keys: ["steps", "шаги", "stepcount", "шагов", "count", "кол-во шагов"])
        let distanceIdx = findIndex(in: headers, keys: ["distance", "дистанция", "distancekm", "distancemeters", "дистанция (км)", "км", "расстояние"])
        let caloriesIdx = findIndex(in: headers, keys: ["calories", "калории", "activecalories", "activeenergy", "активные калории", "ккал", "kcal"])
        
        var activities: [DailyActivitySummary] = []
        var previewRows: [[String: String]] = []
        
        let dateKeyFormatter = DateFormatter()
        dateKeyFormatter.dateFormat = "yyyy-MM-dd"
        
        for line in dataLines {
            let cols = splitCSVLine(line, delimiter: delimiter)
            guard cols.count > 0 else { continue }
            
            let dateVal = parseDate(from: safeGet(cols, index: dateIdx)) ?? Date()
            let dateKey = dateKeyFormatter.string(from: dateVal)
            
            let steps = Int(parseNumber(safeGet(cols, index: stepsIdx)) ?? 0.0)
            var distance = parseNumber(safeGet(cols, index: distanceIdx)) ?? 0.0
            if distance < 100.0 && distance > 0.0 {
                // Если дистанция указана в км (например, 5.2 км), переводим в метры
                distance = distance * 1000.0
            } else if distance == 0.0 && steps > 0 {
                distance = Double(steps) * 0.75
            }
            
            var calories = parseNumber(safeGet(cols, index: caloriesIdx)) ?? 0.0
            if calories == 0.0 && steps > 0 {
                calories = Double(steps) * 0.04
            }
            
            let summary = DailyActivitySummary(
                dateKey: dateKey,
                date: dateVal,
                steps: steps,
                distanceMeters: distance,
                activeCalories: calories
            )
            activities.append(summary)
            
            if previewRows.count < 6 {
                var rowMap: [String: String] = [:]
                for (idx, rawH) in rawHeaders.enumerated() {
                    rowMap[rawH] = safeGet(cols, index: idx)
                }
                previewRows.append(rowMap)
            }
        }
        
        preview.parsedActivities = activities
        preview.validRecordsCount = activities.count
        preview.previewTableRows = previewRows
    }
    
    private func parseNutritions(dataLines: [String], headers: [String], rawHeaders: [String], delimiter: Character, preview: inout HealthDataImportPreview) {
        let dateIdx = findIndex(in: headers, keys: ["date", "дата", "день", "datetime", "timestamp"])
        let caloriesIdx = findIndex(in: headers, keys: ["calories", "калории", "energy", "ккал", "kcal", "калорийность"])
        let proteinIdx = findIndex(in: headers, keys: ["protein", "белки", "белок", "протеин"])
        let fatIdx = findIndex(in: headers, keys: ["fat", "жиры", "жир"])
        let carbsIdx = findIndex(in: headers, keys: ["carbs", "carbohydrates", "углеводы"])
        let waterIdx = findIndex(in: headers, keys: ["water", "вода", "waterml", "жидкость", "мл"])
        
        var nutritions: [DailyNutritionRecord] = []
        var waters: [(date: Date, ml: Double)] = []
        var previewRows: [[String: String]] = []
        
        let dateKeyFormatter = DateFormatter()
        dateKeyFormatter.dateFormat = "yyyy-MM-dd"
        
        for line in dataLines {
            let cols = splitCSVLine(line, delimiter: delimiter)
            guard cols.count > 0 else { continue }
            
            let dateVal = parseDate(from: safeGet(cols, index: dateIdx)) ?? Date()
            let dateKey = dateKeyFormatter.string(from: dateVal)
            
            let calories = parseNumber(safeGet(cols, index: caloriesIdx)) ?? 0.0
            let record = DailyNutritionRecord(
                dateString: dateKey,
                calories: calories
            )
            nutritions.append(record)
            
            if let wIdx = waterIdx {
                var waterVal = parseNumber(safeGet(cols, index: wIdx)) ?? 0.0
                if waterVal > 0 && waterVal <= 10.0 {
                    // Если вода в литрах (например 2.5), переводим в мл
                    waterVal = waterVal * 1000.0
                }
                if waterVal > 0 {
                    waters.append((dateVal, waterVal))
                }
            }
            
            if previewRows.count < 6 {
                var rowMap: [String: String] = [:]
                for (idx, rawH) in rawHeaders.enumerated() {
                    rowMap[rawH] = safeGet(cols, index: idx)
                }
                previewRows.append(rowMap)
            }
        }
        
        preview.parsedNutritions = nutritions
        preview.parsedWaterRecords = waters
        preview.validRecordsCount = nutritions.count
        preview.previewTableRows = previewRows
    }
    
    // MARK: - Пакетная запись в Apple HealthKit (HKHealthStore)
    
    /// Сохранение тренировок в Apple Health
    public func writeWorkoutsToHealthKit(_ workouts: [WorkoutRecord]) async -> (saved: Int, errors: Int) {
        guard HKHealthStore.isHealthDataAvailable() else { return (0, workouts.count) }
        
        var savedCount = 0
        var errorCount = 0
        
        for record in workouts {
            let hkActivityType = mapActivityTypeToHK(record.type)
            let startDate = record.date
            let endDate = startDate.addingTimeInterval(Double(record.durationMinutes) * 60.0)
            
            let energyQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: record.caloriesBurned)
            
            let workout = HKWorkout(
                activityType: hkActivityType,
                start: startDate,
                end: endDate,
                duration: Double(record.durationMinutes) * 60.0,
                totalEnergyBurned: energyQuantity,
                totalDistance: nil,
                device: HKDevice.local(),
                metadata: [
                    HKMetadataKeyIndoorWorkout: false,
                    "ImportedBy": "Forma Health Data CSV Import"
                ]
            )
            
            do {
                try await healthStore.save(workout)
                savedCount += 1
            } catch {
                errorCount += 1
            }
        }
        
        return (savedCount, errorCount)
    }
    
    /// Сохранение замеров веса в Apple Health
    public func writeWeightsToHealthKit(_ weights: [WeightRecord]) async -> (saved: Int, errors: Int) {
        guard HKHealthStore.isHealthDataAvailable() else { return (0, weights.count) }
        guard let bodyMassType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            return (0, weights.count)
        }
        
        var samples: [HKQuantitySample] = []
        for record in weights {
            let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: record.weight)
            let sample = HKQuantitySample(
                type: bodyMassType,
                quantity: quantity,
                start: record.date,
                end: record.date,
                metadata: ["ImportedBy": "Forma CSV Import"]
            )
            samples.append(sample)
        }
        
        do {
            try await healthStore.save(samples)
            return (samples.count, 0)
        } catch {
            return (0, samples.count)
        }
    }
    
    /// Сохранение шагов и активности в Apple Health
    public func writeActivitiesToHealthKit(_ activities: [DailyActivitySummary]) async -> (saved: Int, errors: Int) {
        guard HKHealthStore.isHealthDataAvailable() else { return (0, activities.count) }
        guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount),
              let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
              let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else {
            return (0, activities.count)
        }
        
        var samples: [HKQuantitySample] = []
        for act in activities {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: act.date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)?.addingTimeInterval(-1) ?? act.date
            
            if act.steps > 0 {
                let stepSample = HKQuantitySample(
                    type: stepsType,
                    quantity: HKQuantity(unit: .count(), doubleValue: Double(act.steps)),
                    start: startOfDay,
                    end: endOfDay,
                    metadata: ["ImportedBy": "Forma CSV Import"]
                )
                samples.append(stepSample)
            }
            
            if act.activeCalories > 0 {
                let energySample = HKQuantitySample(
                    type: energyType,
                    quantity: HKQuantity(unit: .kilocalorie(), doubleValue: act.activeCalories),
                    start: startOfDay,
                    end: endOfDay,
                    metadata: ["ImportedBy": "Forma CSV Import"]
                )
                samples.append(energySample)
            }
            
            if act.distanceMeters > 0 {
                let distSample = HKQuantitySample(
                    type: distanceType,
                    quantity: HKQuantity(unit: .meter(), doubleValue: act.distanceMeters),
                    start: startOfDay,
                    end: endOfDay,
                    metadata: ["ImportedBy": "Forma CSV Import"]
                )
                samples.append(distSample)
            }
        }
        
        do {
            try await healthStore.save(samples)
            return (activities.count, 0)
        } catch {
            return (0, activities.count)
        }
    }
    
    // MARK: - Генератор шаблонов и экспорт данных в CSV
    
    /// Создание CSV строки с историей тренировок
    public func exportWorkoutsToCSV(_ workouts: [WorkoutRecord]) -> String {
        var csv = "Дата,Тип тренировки,Длительность (мин),Калории (ккал)\n"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        for w in workouts {
            let dateStr = formatter.string(from: w.date)
            let typeClean = w.type.replacingOccurrences(of: ",", with: " ")
            csv += "\(dateStr),\(typeClean),\(w.durationMinutes),\(String(format: "%.0f", w.caloriesBurned))\n"
        }
        return csv
    }
    
    /// Создание CSV строки с историей замеров веса
    public func exportWeightsToCSV(_ weights: [WeightRecord]) -> String {
        var csv = "Дата,Вес (кг)\n"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        for w in weights {
            let dateStr = formatter.string(from: w.date)
            csv += "\(dateStr),\(String(format: "%.2f", w.weight))\n"
        }
        return csv
    }
    
    /// Создание CSV строки со сводкой дневной активности
    public func exportActivityToCSV(_ activities: [DailyActivitySummary]) -> String {
        var csv = "Дата,Шаги,Дистанция (км),Активные калории (ккал)\n"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        for a in activities {
            let dateStr = formatter.string(from: a.date)
            let distKm = a.distanceMeters / 1000.0
            csv += "\(dateStr),\(a.steps),\(String(format: "%.2f", distKm)),\(String(format: "%.0f", a.activeCalories))\n"
        }
        return csv
    }
    
    /// Создание чистого шаблона CSV для ручного заполнения
    public func getSampleTemplateCSV(category: HealthDataCategory) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let nowStr = formatter.string(from: Date())
        let yesterdayStr = formatter.string(from: Date().addingTimeInterval(-86400))
        
        switch category {
        case .workouts:
            return """
            Дата,Тип тренировки,Длительность (мин),Калории (ккал)
            \(nowStr),Бег на улице,45,420
            \(yesterdayStr),Силовая тренировка,60,350
            """
        case .weight:
            return """
            Дата,Вес (кг)
            \(nowStr),74.5
            \(yesterdayStr),74.8
            """
        case .activity:
            return """
            Дата,Шаги,Дистанция (км),Активные калории (ккал)
            2026-08-22,10500,7.85,480
            2026-08-21,8400,6.20,390
            """
        case .nutrition:
            return """
            Дата,Калории (ккал),Белки (г),Жиры (г),Углеводы (г),Вода (мл)
            2026-08-22,2150,140,65,230,2500
            2026-08-21,1980,125,58,210,2200
            """
        case .unknown:
            return ""
        }
    }
    
    // MARK: - Вспомогательные утилиты парсера
    
    private func detectDelimiter(in headerLine: String) -> Character {
        let semicolonCount = headerLine.filter { $0 == ";" }.count
        let tabCount = headerLine.filter { $0 == "\t" }.count
        let commaCount = headerLine.filter { $0 == "," }.count
        
        if semicolonCount > commaCount && semicolonCount > tabCount { return ";" }
        if tabCount > commaCount && tabCount > semicolonCount { return "\t" }
        return ","
    }
    
    private func splitCSVLine(_ line: String, delimiter: Character) -> [String] {
        var result: [String] = []
        var currentToken = ""
        var insideQuotes = false
        
        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == delimiter && !insideQuotes {
                result.append(currentToken.trimmingCharacters(in: .whitespaces))
                currentToken = ""
            } else {
                currentToken.append(char)
            }
        }
        result.append(currentToken.trimmingCharacters(in: .whitespaces))
        return result
    }
    
    private func normalizeHeader(_ header: String) -> String {
        return header
            .lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func detectCategory(from headers: [String]) -> HealthDataCategory {
        let headerSet = Set(headers)
        
        // Вес
        if headers.contains(where: { $0.contains("weight") || $0.contains("вес") || $0.contains("bodymass") || $0.contains("масса") }) {
            return .weight
        }
        
        // Тренировки
        if headers.contains(where: { $0.contains("workout") || $0.contains("тренировк") || $0.contains("activitytype") || $0.contains("duration") || $0.contains("длительность") }) {
            return .workouts
        }
        
        // Шаги и активность
        if headers.contains(where: { $0.contains("step") || $0.contains("шаг") || $0.contains("distance") || $0.contains("дистанц") }) {
            return .activity
        }
        
        // Питание
        if headers.contains(where: { $0.contains("protein") || $0.contains("белк") || $0.contains("carb") || $0.contains("углевод") || $0.contains("water") || $0.contains("вода") }) {
            return .nutrition
        }
        
        // Калории как общий fallback
        if headers.contains(where: { $0.contains("calor") || $0.contains("калор") || $0.contains("energy") }) {
            return .activity
        }
        
        return .unknown
    }
    
    private func findIndex(in headers: [String], keys: [String]) -> Int? {
        for (index, header) in headers.enumerated() {
            for key in keys {
                let normKey = normalizeHeader(key)
                if header == normKey || header.contains(normKey) {
                    return index
                }
            }
        }
        return nil
    }
    
    private func safeGet(_ array: [String], index: Int?) -> String {
        guard let idx = index, idx >= 0 && idx < array.count else { return "" }
        return array[idx].replacingOccurrences(of: "\"", with: "").trimmingCharacters(in: .whitespaces)
    }
    
    private func parseNumber(_ text: String) -> Double? {
        let cleaned = text
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "kg", with: "")
            .replacingOccurrences(of: "кг", with: "")
            .replacingOccurrences(of: "kcal", with: "")
            .replacingOccurrences(of: "ккал", with: "")
            .replacingOccurrences(of: "min", with: "")
            .replacingOccurrences(of: "мин", with: "")
            .replacingOccurrences(of: "m", with: "")
            .replacingOccurrences(of: "м", with: "")
            .replacingOccurrences(of: "km", with: "")
            .replacingOccurrences(of: "км", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Double(cleaned)
    }
    
    private func parseDate(from text: String) -> Date? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        
        let dateFormats = [
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd",
            "dd.MM.yyyy HH:mm:ss",
            "dd.MM.yyyy HH:mm",
            "dd.MM.yyyy",
            "dd/MM/yyyy HH:mm:ss",
            "dd/MM/yyyy",
            "MM/dd/yyyy HH:mm:ss",
            "MM/dd/yyyy"
        ]
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        for fmt in dateFormats {
            formatter.dateFormat = fmt
            if let date = formatter.date(from: cleaned) {
                return date
            }
        }
        
        return nil
    }
    
    private func mapActivityTypeToHK(_ type: String) -> HKWorkoutActivityType {
        let lower = type.lowercased()
        if lower.contains("бег") || lower.contains("run") { return .running }
        if lower.contains("ходьб") || lower.contains("walk") { return .walking }
        if lower.contains("вело") || lower.contains("cycl") || lower.contains("bike") { return .cycling }
        if lower.contains("плав") || lower.contains("swim") { return .swimming }
        if lower.contains("йог") || lower.contains("yoga") { return .yoga }
        if lower.contains("сил") || lower.contains("strength") || lower.contains("гантел") || lower.contains("gym") { return .traditionalStrengthTraining }
        if lower.contains("скакал") || lower.contains("rope") { return .jumpRope }
        if lower.contains("hiit") || lower.contains("интервал") { return .highIntensityIntervalTraining }
        return .other
    }
}
