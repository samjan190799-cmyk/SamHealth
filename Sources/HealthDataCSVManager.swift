import Foundation
import HealthKit
import SwiftUI
import Compression

/// Категории данных здоровья для импорта/экспорта
public enum HealthDataCategory: String, CaseIterable, Identifiable {
    case workouts = "workouts"
    case weight = "weight"
    case activity = "activity"
    case nutrition = "nutrition"
    case allInOneArchive = "archive"
    case unknown = "unknown"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .workouts: return "figure.run"
        case .weight: return "scalemass.fill"
        case .activity: return "flame.fill"
        case .nutrition: return "fork.knife"
        case .allInOneArchive: return "archivebox.fill"
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
        case .allInOneArchive:
            return lang == "ru" ? "Архив Apple Health (ZIP)" : (lang == "hy" ? "Apple Health արխիվ (ZIP)" : "Apple Health Archive (ZIP)")
        case .unknown:
            return lang == "ru" ? "Неопознанный файл" : (lang == "hy" ? "Անհայտ ֆայլ" : "Unknown Format")
        }
    }
}

/// Результат предварительного анализа CSV / ZIP перед импортом
public struct HealthDataImportPreview: Identifiable {
    public let id = UUID()
    public var fileName: String
    public var category: HealthDataCategory
    public var isZipArchive: Bool = false
    public var archiveFilesFound: [String] = []
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
    
    public var totalSummaryBadge: String {
        var parts: [String] = []
        if !parsedWorkouts.isEmpty { parts.append("\(parsedWorkouts.count) трен.") }
        if !parsedWeights.isEmpty { parts.append("\(parsedWeights.count) зам. веса") }
        if !parsedActivities.isEmpty { parts.append("\(parsedActivities.count) дн. активн.") }
        if !parsedNutritions.isEmpty { parts.append("\(parsedNutritions.count) питан.") }
        return parts.isEmpty ? "\(validRecordsCount) записей" : parts.joined(separator: " • ")
    }
}

/// Универсальный менеджер импорта и экспорта данных Apple Health через CSV и ZIP
@MainActor
public final class HealthDataCSVManager {
    public static let shared = HealthDataCSVManager()
    
    private let healthStore = HKHealthStore()
    
    private init() {}
    
    // MARK: - Главный вход для файлов (CSV или ZIP)
    
    /// Автоматическое определение и парсинг файла (Data) как CSV или ZIP
    public func parseFile(data: Data, fileName: String) -> HealthDataImportPreview {
        let isZip = fileName.lowercased().hasSuffix(".zip") ||
                    (data.count >= 4 && data[0] == 0x50 && data[1] == 0x4B)
        
        if isZip {
            return parseZipArchive(data: data, fileName: fileName)
        }
        
        guard let contentString = String(data: data, encoding: .utf8) ??
                                  String(data: data, encoding: .windowsCP1251) ??
                                  String(data: data, encoding: .isoLatin1) else {
            return HealthDataImportPreview(
                fileName: fileName,
                category: .unknown,
                totalRowsFound: 0,
                validRecordsCount: 0,
                warnings: ["Не удалось прочитать кодировку файла. Сохраните CSV в формате UTF-8."]
            )
        }
        
        return parseCSV(content: contentString, fileName: fileName)
    }
    
    // MARK: - Парсер ZIP Архивов (Health Auto Export / iOS ZIP)
    
    /// Парсинг ZIP-архива, извлечение всех вложенных CSV файлов и объединение данных
    public func parseZipArchive(data: Data, fileName: String) -> HealthDataImportPreview {
        let extractedEntries = ZipArchiveReader.extractCSVFiles(from: data)
        
        guard !extractedEntries.isEmpty else {
            return HealthDataImportPreview(
                fileName: fileName,
                category: .allInOneArchive,
                isZipArchive: true,
                totalRowsFound: 0,
                validRecordsCount: 0,
                warnings: ["В архиве не найдено поддерживаемых CSV файлов (Workouts.csv, Step Count.csv, Body Mass.csv и т.д.)"]
            )
        }
        
        var combinedWorkouts: [WorkoutRecord] = []
        var combinedWeights: [WeightRecord] = []
        var activitiesMap: [String: DailyActivitySummary] = [:]
        var combinedNutritions: [DailyNutritionRecord] = []
        var combinedWaters: [(date: Date, ml: Double)] = []
        var filesFoundSummary: [String] = []
        var allWarnings: [String] = []
        var sampleRows: [[String: String]] = []
        var sampleHeaders: [String] = []
        var totalRows = 0
        
        for entry in extractedEntries {
            guard let content = String(data: entry.data, encoding: .utf8) ??
                                String(data: entry.data, encoding: .windowsCP1251) ??
                                String(data: entry.data, encoding: .isoLatin1) else {
                continue
            }
            
            let preview = parseCSV(content: content, fileName: entry.filename)
            totalRows += preview.totalRowsFound
            
            let baseName = (entry.filename as NSString).lastPathComponent
            
            if !preview.parsedWorkouts.isEmpty {
                combinedWorkouts.append(contentsOf: preview.parsedWorkouts)
                filesFoundSummary.append("🏋️ \(baseName) (\(preview.parsedWorkouts.count) трен.)")
                if sampleRows.isEmpty {
                    sampleRows = preview.previewTableRows
                    sampleHeaders = preview.tableHeaders
                }
            }
            
            if !preview.parsedWeights.isEmpty {
                combinedWeights.append(contentsOf: preview.parsedWeights)
                filesFoundSummary.append("⚖️ \(baseName) (\(preview.parsedWeights.count) зам.)")
                if sampleRows.isEmpty {
                    sampleRows = preview.previewTableRows
                    sampleHeaders = preview.tableHeaders
                }
            }
            
            if !preview.parsedActivities.isEmpty {
                for act in preview.parsedActivities {
                    if var existing = activitiesMap[act.dateKey] {
                        if act.steps > 0 {
                            existing.steps = max(existing.steps, act.steps)
                        }
                        if act.distanceMeters > 0 {
                            existing.distanceMeters = max(existing.distanceMeters, act.distanceMeters)
                        }
                        if act.activeCalories > 0 {
                            existing.activeCalories = max(existing.activeCalories, act.activeCalories)
                        }
                        activitiesMap[act.dateKey] = existing
                    } else {
                        activitiesMap[act.dateKey] = act
                    }
                }
                filesFoundSummary.append("🚶 \(baseName) (\(preview.parsedActivities.count) дн.)")
                if sampleRows.isEmpty {
                    sampleRows = preview.previewTableRows
                    sampleHeaders = preview.tableHeaders
                }
            }
            
            if !preview.parsedNutritions.isEmpty || !preview.parsedWaterRecords.isEmpty {
                combinedNutritions.append(contentsOf: preview.parsedNutritions)
                combinedWaters.append(contentsOf: preview.parsedWaterRecords)
                filesFoundSummary.append("🥗 \(baseName) (\(preview.parsedNutritions.count) зап.)")
                if sampleRows.isEmpty {
                    sampleRows = preview.previewTableRows
                    sampleHeaders = preview.tableHeaders
                }
            }
            
            allWarnings.append(contentsOf: preview.warnings)
        }
        
        let combinedActivities = Array(activitiesMap.values).sorted { $0.date > $1.date }
        combinedWorkouts.sort { $0.date > $1.date }
        combinedWeights.sort { $0.date > $1.date }
        
        let validCount = combinedWorkouts.count + combinedWeights.count + combinedActivities.count + combinedNutritions.count
        
        return HealthDataImportPreview(
            fileName: fileName,
            category: .allInOneArchive,
            isZipArchive: true,
            archiveFilesFound: filesFoundSummary,
            totalRowsFound: totalRows,
            validRecordsCount: validCount,
            parsedWorkouts: combinedWorkouts,
            parsedWeights: combinedWeights,
            parsedActivities: combinedActivities,
            parsedNutritions: combinedNutritions,
            parsedWaterRecords: combinedWaters,
            previewTableRows: sampleRows,
            tableHeaders: sampleHeaders,
            warnings: Array(Set(allWarnings))
        )
    }
    
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
        let category = detectCategory(from: normalizedHeaders, fileName: fileName)
        
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
            parseWorkouts(dataLines: dataLines, headers: normalizedHeaders, rawHeaders: rawHeaders, delimiter: delimiter, fileName: fileName, preview: &preview)
        case .weight:
            parseWeights(dataLines: dataLines, headers: normalizedHeaders, rawHeaders: rawHeaders, delimiter: delimiter, fileName: fileName, preview: &preview)
        case .activity:
            parseActivities(dataLines: dataLines, headers: normalizedHeaders, rawHeaders: rawHeaders, delimiter: delimiter, fileName: fileName, preview: &preview)
        case .nutrition:
            parseNutritions(dataLines: dataLines, headers: normalizedHeaders, rawHeaders: rawHeaders, delimiter: delimiter, fileName: fileName, preview: &preview)
        default:
            preview.warnings.append("Не удалось сопоставить колонки: \(rawHeaders.joined(separator: ", ")). Используйте стандартный шаблон.")
        }
        
        return preview
    }
    
    // MARK: - Парсинг категорий
    
    private func parseWorkouts(dataLines: [String], headers: [String], rawHeaders: [String], delimiter: Character, fileName: String, preview: inout HealthDataImportPreview) {
        let dateIdx = findIndex(in: headers, keys: ["date", "дата", "time", "datetime", "startdate", "start_date", "start", "from", "timestamp"])
        let typeIdx = findIndex(in: headers, keys: ["type", "тип", "activity", "вид", "workout", "workouttype", "activitytype", "name", "упражнение"])
        let durationIdx = findIndex(in: headers, keys: ["duration", "длительность", "durationminutes", "duration_minutes", "минуты", "minutes", "min", "время", "duration(s)", "duration(min)"])
        let caloriesIdx = findIndex(in: headers, keys: ["calories", "калории", "energy", "activeenergy", "activecalories", "ккал", "kcal", "сожжено", "active_energy", "total_energy", "qty", "value"])
        
        var workouts: [WorkoutRecord] = []
        var previewRows: [[String: String]] = []
        
        for line in dataLines {
            let cols = splitCSVLine(line, delimiter: delimiter)
            guard cols.count > 0 else { continue }
            
            let dateRaw = safeGet(cols, index: dateIdx)
            guard let dateVal = parseDate(from: dateRaw) else { continue }
            
            let typeVal = safeGet(cols, index: typeIdx).trimmingCharacters(in: .whitespaces)
            let finalType = typeVal.isEmpty ? "Тренировка" : typeVal
            
            let durRaw = safeGet(cols, index: durationIdx)
            var durationVal = parseNumber(durRaw) ?? 30.0
            if durationVal > 1000.0 {
                durationVal = durationVal / 60.0
            }
            
            let calRaw = safeGet(cols, index: caloriesIdx)
            let caloriesVal = parseNumber(calRaw) ?? (Double(durationVal) * 7.5)
            
            let record = WorkoutRecord(
                type: finalType,
                date: dateVal,
                durationMinutes: max(1, Int(durationVal)),
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
    
    private func parseWeights(dataLines: [String], headers: [String], rawHeaders: [String], delimiter: Character, fileName: String, preview: inout HealthDataImportPreview) {
        let isWeightFile = fileName.lowercased().contains("weight") || fileName.lowercased().contains("bodymass") || fileName.lowercased().contains("масс") || fileName.lowercased().contains("вес")
        
        let dateIdx = findIndex(in: headers, keys: ["date", "дата", "time", "datetime", "timestamp", "start", "startdate", "start_date", "день"])
        var weightIdx = findIndex(in: headers, keys: ["weight", "вес", "bodymass", "mass", "вес (кг)", "weight (kg)", "bodymass(kg)"])
        if weightIdx == nil && isWeightFile {
            weightIdx = findIndex(in: headers, keys: ["qty", "value", "val", "count", "quantity", "amount", "total"])
            if weightIdx == nil && headers.count >= 2 {
                weightIdx = (dateIdx == 0) ? 1 : 0
            }
        }
        
        var weights: [WeightRecord] = []
        var previewRows: [[String: String]] = []
        
        for line in dataLines {
            let cols = splitCSVLine(line, delimiter: delimiter)
            guard cols.count > 0 else { continue }
            
            let dateRaw = safeGet(cols, index: dateIdx)
            guard let dateVal = parseDate(from: dateRaw) else { continue }
            
            let weightRaw = safeGet(cols, index: weightIdx)
            guard var w = parseNumber(weightRaw), w >= 15.0 && w <= 450.0 else {
                continue
            }
            
            // Конвертация фунтов в кг если значение в lbs
            if w > 220.0 && (rawHeaders.joined().lowercased().contains("lb") || line.lowercased().contains("lb")) {
                w = w * 0.453592
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
        
        weights.sort { $0.date > $1.date }
        preview.parsedWeights = weights
        preview.validRecordsCount = weights.count
        preview.previewTableRows = previewRows
    }
    
    private func parseActivities(dataLines: [String], headers: [String], rawHeaders: [String], delimiter: Character, fileName: String, preview: inout HealthDataImportPreview) {
        let lowerName = fileName.lowercased()
        let isStepFile = lowerName.contains("step") || lowerName.contains("шаг")
        let isDistFile = lowerName.contains("distance") || lowerName.contains("дистанц")
        let isEnergyFile = lowerName.contains("energy") || lowerName.contains("calorie") || lowerName.contains("калор")
        
        let dateIdx = findIndex(in: headers, keys: [
            "date", "дата", "day", "день", "datekey", "timestamp", "start", "startdate", "start_date", "from", "time", "datetime", "created_at"
        ])
        
        // Поиск колонки шагов
        var stepsIdx = findIndex(in: headers, keys: [
            "step", "steps", "stepcount", "step_count", "шаги", "шагов", "кол-во шагов", "steps (count)", "step count (count)"
        ])
        if stepsIdx == nil && isStepFile {
            stepsIdx = findIndex(in: headers, keys: ["qty", "value", "val", "count", "quantity", "amount", "total"])
            if stepsIdx == nil && headers.count >= 2 {
                stepsIdx = (dateIdx == 0) ? 1 : 0
            }
        }
        
        // Поиск колонки дистанции
        var distanceIdx = findIndex(in: headers, keys: [
            "distance", "дистанция", "distancekm", "distancemeters", "distance_km", "distance_meters", "дистанция (км)", "км", "расстояние", "dist"
        ])
        if distanceIdx == nil && isDistFile {
            distanceIdx = findIndex(in: headers, keys: ["qty", "value", "val", "count", "quantity", "amount", "total"])
            if distanceIdx == nil && headers.count >= 2 {
                distanceIdx = (dateIdx == 0) ? 1 : 0
            }
        }
        
        // Поиск колонки калорий
        var caloriesIdx = findIndex(in: headers, keys: [
            "calories", "калории", "activecalories", "activeenergy", "active_calories", "active_energy", "активные калории", "ккал", "kcal", "energy"
        ])
        if caloriesIdx == nil && isEnergyFile {
            caloriesIdx = findIndex(in: headers, keys: ["qty", "value", "val", "count", "quantity", "amount", "total"])
            if caloriesIdx == nil && headers.count >= 2 {
                caloriesIdx = (dateIdx == 0) ? 1 : 0
            }
        }
        
        // Агрегация почасовых / точечных интервалов по каждому календарному дню (yyyy-MM-dd)
        var dailyMap: [String: (date: Date, steps: Int, distanceMeters: Double, activeCalories: Double)] = [:]
        var previewRows: [[String: String]] = []
        
        let dateKeyFormatter = DateFormatter()
        dateKeyFormatter.dateFormat = "yyyy-MM-dd"
        dateKeyFormatter.timeZone = TimeZone.current
        dateKeyFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        for line in dataLines {
            let cols = splitCSVLine(line, delimiter: delimiter)
            guard cols.count > 0 else { continue }
            
            let dateRaw = safeGet(cols, index: dateIdx)
            guard let dateVal = parseDate(from: dateRaw) else { continue }
            let dateKey = dateKeyFormatter.string(from: dateVal)
            
            let rowSteps: Int = {
                guard let sIdx = stepsIdx else { return 0 }
                return Int(parseNumber(safeGet(cols, index: sIdx)) ?? 0.0)
            }()
            
            var rowDistance: Double = {
                guard let dIdx = distanceIdx else { return 0.0 }
                var val = parseNumber(safeGet(cols, index: dIdx)) ?? 0.0
                if val < 100.0 && val > 0.0 {
                    val = val * 1000.0 // km -> m
                }
                return val
            }()
            
            var rowCalories: Double = {
                guard let cIdx = caloriesIdx else { return 0.0 }
                var c = parseNumber(safeGet(cols, index: cIdx)) ?? 0.0
                // Если значения в кДж (kJ), переводим в ккал
                if c > 0 && (rawHeaders.joined().lowercased().contains("kj") || line.lowercased().contains("kj")) {
                    c = c / 4.184
                }
                return c
            }()
            
            if var existing = dailyMap[dateKey] {
                existing.steps += rowSteps
                existing.distanceMeters += rowDistance
                existing.activeCalories += rowCalories
                dailyMap[dateKey] = existing
            } else {
                dailyMap[dateKey] = (date: dateVal, steps: rowSteps, distanceMeters: rowDistance, activeCalories: rowCalories)
            }
            
            if previewRows.count < 6 {
                var rowMap: [String: String] = [:]
                for (idx, rawH) in rawHeaders.enumerated() {
                    rowMap[rawH] = safeGet(cols, index: idx)
                }
                previewRows.append(rowMap)
            }
        }
        
        var activities: [DailyActivitySummary] = []
        for (dateKey, entry) in dailyMap {
            var finalDistance = entry.distanceMeters
            if finalDistance == 0 && entry.steps > 0 {
                finalDistance = Double(entry.steps) * 0.75
            }
            var finalCalories = entry.activeCalories
            if finalCalories == 0 && entry.steps > 0 {
                finalCalories = Double(entry.steps) * 0.04
            }
            
            let summary = DailyActivitySummary(
                dateKey: dateKey,
                date: entry.date,
                steps: entry.steps,
                distanceMeters: finalDistance,
                activeCalories: finalCalories
            )
            activities.append(summary)
        }
        
        activities.sort { $0.date > $1.date }
        preview.parsedActivities = activities
        preview.validRecordsCount = activities.count
        preview.previewTableRows = previewRows
    }
    
    private func parseNutritions(dataLines: [String], headers: [String], rawHeaders: [String], delimiter: Character, fileName: String, preview: inout HealthDataImportPreview) {
        let dateIdx = findIndex(in: headers, keys: ["date", "дата", "день", "datetime", "timestamp", "start", "startdate", "start_date"])
        let caloriesIdx = findIndex(in: headers, keys: ["calories", "калории", "energy", "ккал", "kcal", "калорийность", "value", "qty"])
        let proteinIdx = findIndex(in: headers, keys: ["protein", "белки", "белок", "протеин"])
        let fatIdx = findIndex(in: headers, keys: ["fat", "жиры", "жир"])
        let carbsIdx = findIndex(in: headers, keys: ["carbs", "carbohydrates", "углеводы"])
        let waterIdx = findIndex(in: headers, keys: ["water", "вода", "waterml", "жидкость", "мл"])
        
        var nutritions: [DailyNutritionRecord] = []
        var waters: [(date: Date, ml: Double)] = []
        var previewRows: [[String: String]] = []
        
        let dateKeyFormatter = DateFormatter()
        dateKeyFormatter.dateFormat = "yyyy-MM-dd"
        dateKeyFormatter.timeZone = TimeZone.current
        dateKeyFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        for line in dataLines {
            let cols = splitCSVLine(line, delimiter: delimiter)
            guard cols.count > 0 else { continue }
            
            let dateRaw = safeGet(cols, index: dateIdx)
            guard let dateVal = parseDate(from: dateRaw) else { continue }
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
    
    // MARK: - Экспорт и Шаблоны
    
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
        default:
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
    
    private func detectCategory(from headers: [String], fileName: String) -> HealthDataCategory {
        let lowerName = fileName.lowercased()
        
        if lowerName.contains("workout") || lowerName.contains("тренировк") {
            return .workouts
        }
        if lowerName.contains("weight") || lowerName.contains("bodymass") || lowerName.contains("body_mass") || lowerName.contains("вес") {
            return .weight
        }
        if lowerName.contains("step") || lowerName.contains("activity") || lowerName.contains("активност") || lowerName.contains("шаг") || lowerName.contains("energy") || lowerName.contains("distance") || lowerName.contains("dist") || lowerName.contains("stand") || lowerName.contains("exercise") {
            return .activity
        }
        if lowerName.contains("diet") || lowerName.contains("nutrition") || lowerName.contains("food") || lowerName.contains("питани") || lowerName.contains("water") || lowerName.contains("вод") {
            return .nutrition
        }
        
        // По колонкам
        if headers.contains(where: { $0.contains("weight") || $0.contains("вес") || $0.contains("bodymass") || $0.contains("масса") }) {
            return .weight
        }
        
        if headers.contains(where: { $0.contains("workout") || $0.contains("тренировк") || $0.contains("activitytype") || $0.contains("duration") || $0.contains("длительность") }) {
            return .workouts
        }
        
        if headers.contains(where: { $0.contains("step") || $0.contains("шаг") || $0.contains("distance") || $0.contains("дистанц") }) {
            return .activity
        }
        
        if headers.contains(where: { $0.contains("protein") || $0.contains("белк") || $0.contains("carb") || $0.contains("углевод") || $0.contains("water") || $0.contains("вода") }) {
            return .nutrition
        }
        
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
        
        // 1. Быстрый парсер ISO8601
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withTimeZone]
        if let date = isoFormatter.date(from: cleaned) {
            return date
        }
        isoFormatter.formatOptions = [.withInternetDateTime, .withTimeZone]
        if let date = isoFormatter.date(from: cleaned) {
            return date
        }
        
        // 2. Расширенный набор форматов для Health Auto Export, Apple Health и таблиц
        let dateFormats = [
            "yyyy-MM-dd HH:mm:ss Z",
            "yyyy-MM-dd HH:mm:ss ZZZ",
            "yyyy-MM-dd HH:mm:ss ZZZZZ",
            "yyyy-MM-dd HH:mm:ss.SSS Z",
            "yyyy-MM-dd HH:mm:ss.SSS ZZZ",
            "yyyy-MM-dd HH:mm:ss.SSS ZZZZZ",
            "yyyy-MM-dd HH:mm:ssZZZZZ",
            "yyyy-MM-dd'T'HH:mm:ssZZZZZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd",
            "MM/dd/yyyy hh:mm:ss a",
            "MM/dd/yyyy h:mm:ss a",
            "MM/dd/yyyy hh:mm a",
            "MM/dd/yyyy h:mm a",
            "MM/dd/yyyy HH:mm:ss",
            "MM/dd/yyyy",
            "M/d/yyyy h:mm:ss a",
            "M/d/yyyy h:mm a",
            "M/d/yyyy",
            "M/d/yy h:mm a",
            "M/d/yy",
            "dd.MM.yyyy HH:mm:ss",
            "dd.MM.yyyy HH:mm",
            "dd.MM.yyyy",
            "dd/MM/yyyy HH:mm:ss",
            "dd/MM/yyyy HH:mm",
            "dd/MM/yyyy",
            "dd-MM-yyyy HH:mm:ss",
            "dd-MM-yyyy",
            "yyyy/MM/dd HH:mm:ss",
            "yyyy/MM/dd"
        ]
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        for fmt in dateFormats {
            formatter.dateFormat = fmt
            if let date = formatter.date(from: cleaned) {
                return date
            }
        }
        
        // 3. Попытка выделить первые 10 символов если это дата yyyy-MM-dd
        if cleaned.count >= 10 {
            let prefix = String(cleaned.prefix(10))
            formatter.dateFormat = "yyyy-MM-dd"
            if let date = formatter.date(from: prefix) {
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

// MARK: - Легковесный чистый Swift ZIP экстрактор

public struct ZipArchiveEntry {
    public let filename: String
    public let data: Data
}

public enum ZipArchiveReader {
    public static func extractCSVFiles(from zipData: Data) -> [ZipArchiveEntry] {
        var entries: [ZipArchiveEntry] = []
        guard zipData.count > 22 else { return [] }
        
        // 1. Поиск End of Central Directory (EOCD signature: 0x06054b50)
        var eocdOffset: Int? = nil
        let minOffset = max(0, zipData.count - 65557)
        for i in stride(from: zipData.count - 22, through: minOffset, by: -1) {
            if zipData[i] == 0x50 && zipData[i+1] == 0x4B && zipData[i+2] == 0x05 && zipData[i+3] == 0x06 {
                eocdOffset = i
                break
            }
        }
        
        if let eocd = eocdOffset {
            let totalEntries = Int(zipData.readUInt16LE(at: eocd + 10))
            let cdOffset = Int(zipData.readUInt32LE(at: eocd + 16))
            
            var currentCD = cdOffset
            for _ in 0..<totalEntries {
                guard currentCD + 46 <= zipData.count else { break }
                guard zipData[currentCD] == 0x50 && zipData[currentCD+1] == 0x4B && zipData[currentCD+2] == 0x01 && zipData[currentCD+3] == 0x02 else { break }
                
                let compressionMethod = zipData.readUInt16LE(at: currentCD + 10)
                let compSize = Int(zipData.readUInt32LE(at: currentCD + 20))
                let uncompSize = Int(zipData.readUInt32LE(at: currentCD + 24))
                let filenameLen = Int(zipData.readUInt16LE(at: currentCD + 28))
                let extraLen = Int(zipData.readUInt16LE(at: currentCD + 30))
                let commentLen = Int(zipData.readUInt16LE(at: currentCD + 32))
                let localHeaderOffset = Int(zipData.readUInt32LE(at: currentCD + 42))
                
                let fnStart = currentCD + 46
                let fnEnd = fnStart + filenameLen
                if fnEnd <= zipData.count,
                   let name = String(data: zipData.subdata(in: fnStart..<fnEnd), encoding: .utf8) ??
                              String(data: zipData.subdata(in: fnStart..<fnEnd), encoding: .ascii) {
                    let lower = name.lowercased()
                    if !name.hasSuffix("/") && (lower.hasSuffix(".csv") || lower.hasSuffix(".json") || lower.hasSuffix(".txt")) {
                        if let extracted = extractLocalEntry(zipData: zipData, localOffset: localHeaderOffset, compSize: compSize, uncompSize: uncompSize, method: compressionMethod) {
                            entries.append(ZipArchiveEntry(filename: name, data: extracted))
                        }
                    }
                }
                currentCD += 46 + filenameLen + extraLen + commentLen
            }
            if !entries.isEmpty {
                return entries
            }
        }
        
        // 2. Линейный проход по локальным заголовкам (0x04034b50)
        var offset = 0
        while offset + 30 <= zipData.count {
            guard zipData[offset] == 0x50 && zipData[offset+1] == 0x4B && zipData[offset+2] == 0x03 && zipData[offset+3] == 0x04 else {
                offset += 1
                continue
            }
            
            let compressionMethod = zipData.readUInt16LE(at: offset + 8)
            let compSize = Int(zipData.readUInt32LE(at: offset + 18))
            let uncompSize = Int(zipData.readUInt32LE(at: offset + 22))
            let filenameLen = Int(zipData.readUInt16LE(at: offset + 26))
            let extraLen = Int(zipData.readUInt16LE(at: offset + 28))
            
            let nameOffset = offset + 30
            let dataOffset = nameOffset + filenameLen + extraLen
            
            if nameOffset + filenameLen <= zipData.count,
               let name = String(data: zipData.subdata(in: nameOffset..<(nameOffset + filenameLen)), encoding: .utf8) ??
                          String(data: zipData.subdata(in: nameOffset..<(nameOffset + filenameLen)), encoding: .ascii) {
                let lower = name.lowercased()
                if !name.hasSuffix("/") && (lower.hasSuffix(".csv") || lower.hasSuffix(".json") || lower.hasSuffix(".txt")) {
                    if dataOffset + compSize <= zipData.count {
                        let compressedSlice = zipData.subdata(in: dataOffset..<(dataOffset + compSize))
                        if compressionMethod == 0 {
                            entries.append(ZipArchiveEntry(filename: name, data: compressedSlice))
                        } else if compressionMethod == 8 {
                            if let decomp = decompressDeflatedData(compressedSlice, uncompressedSize: uncompSize) {
                                entries.append(ZipArchiveEntry(filename: name, data: decomp))
                            }
                        }
                    }
                }
            }
            offset = dataOffset + max(compSize, 1)
        }
        
        return entries
    }
    
    private static func extractLocalEntry(zipData: Data, localOffset: Int, compSize: Int, uncompSize: Int, method: UInt16) -> Data? {
        guard localOffset + 30 <= zipData.count else { return nil }
        guard zipData[localOffset] == 0x50 && zipData[localOffset+1] == 0x4B && zipData[localOffset+2] == 0x03 && zipData[localOffset+3] == 0x04 else { return nil }
        
        let filenameLen = Int(zipData.readUInt16LE(at: localOffset + 26))
        let extraLen = Int(zipData.readUInt16LE(at: localOffset + 28))
        let dataStart = localOffset + 30 + filenameLen + extraLen
        let dataEnd = dataStart + compSize
        
        guard dataEnd <= zipData.count else { return nil }
        let rawData = zipData.subdata(in: dataStart..<dataEnd)
        
        if method == 0 {
            return rawData
        } else if method == 8 {
            return decompressDeflatedData(rawData, uncompressedSize: uncompSize)
        }
        return nil
    }
    
    private static func decompressDeflatedData(_ data: Data, uncompressedSize: Int) -> Data? {
        guard !data.isEmpty else { return Data() }
        let targetSize = max(uncompressedSize > 0 ? uncompressedSize : data.count * 8, 256 * 1024)
        var destination = Data(count: targetSize)
        
        let decodedSize = destination.withUnsafeMutableBytes { destBytes -> Int in
            data.withUnsafeBytes { srcBytes -> Int in
                guard let srcPtr = srcBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                      let destPtr = destBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
                return compression_decode_buffer(
                    destPtr, destBytes.count,
                    srcPtr, srcBytes.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        
        if decodedSize > 0 {
            return destination.prefix(decodedSize)
        }
        
        if let nsDecomp = try? (data as NSData).decompressed(using: .zlib) as Data {
            return nsDecomp
        }
        return nil
    }
}

// MARK: - Расширение Data для чтения Little-Endian
private extension Data {
    func readUInt16LE(at offset: Int) -> UInt16 {
        guard offset + 2 <= count else { return 0 }
        return UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8)
    }
    func readUInt32LE(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        return UInt32(self[offset]) |
               (UInt32(self[offset + 1]) << 8) |
               (UInt32(self[offset + 2]) << 16) |
               (UInt32(self[offset + 3]) << 24)
    }
}
