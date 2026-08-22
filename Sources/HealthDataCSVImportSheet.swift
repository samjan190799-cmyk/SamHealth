import SwiftUI
import UniformTypeIdentifiers

public struct HealthDataCSVImportSheet: View {
    @EnvironmentObject var health: HealthKitManager
    @Environment(\.dismiss) private var dismiss
    @AppStorage("app_language") private var appLanguage = "ru"
    
    // Состояния импорта
    @State private var showingFilePicker = false
    @State private var importPreview: HealthDataImportPreview? = nil
    @State private var saveToHealthKit = true
    @State private var isProcessing = false
    @State private var importSuccessMessage: String? = nil
    @State private var importErrorMessage: String? = nil
    
    // Состояния экспорта
    @State private var exportText: String? = nil
    @State private var exportFileName: String = "health_export.csv"
    @State private var showingShareSheet = false
    
    private func tr(_ key: String) -> String {
        LocalizationManager.tr(key, lang: appLanguage)
    }
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // MARK: - Баннер импорта CSV / ZIP
                        VStack(spacing: 16) {
                            HStack(spacing: 16) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color(red: 50/255, green: 215/255, blue: 75/255),
                                                    Color(red: 0/255, green: 175/255, blue: 110/255)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 56, height: 56)
                                        .shadow(color: Color.green.opacity(0.3), radius: 8, y: 4)
                                    
                                    Image(systemName: "arrow.down.doc.fill")
                                        .font(.system(size: 26))
                                        .foregroundColor(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Импорт CSV и ZIP-архивов")
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundColor(Theme.textPrimary)
                                    
                                    Text("Поддержка выгрузок Health Auto Export, QS Access, Apple Health и таблиц CSV")
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                        .lineLimit(2)
                                }
                                
                                Spacer()
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                            
                            // Кнопка выбора CSV / ZIP файла
                            Button(action: {
                                let impact = UIImpactFeedbackGenerator(style: .medium)
                                impact.impactOccurred()
                                showingFilePicker = true
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "folder.fill.badge.plus")
                                        .font(.system(size: 16, weight: .bold))
                                    Text("Выбрать CSV или ZIP-архив")
                                        .font(.system(size: 15, weight: .bold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 50/255, green: 215/255, blue: 75/255),
                                            Color(red: 0/255, green: 160/255, blue: 95/255)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundColor(.white)
                                .cornerRadius(16)
                                .shadow(color: Color.green.opacity(0.35), radius: 6, y: 3)
                            }
                        }
                        .premiumCard()
                        .padding(.horizontal)
                        .padding(.top, 12)
                        
                        // MARK: - Сообщение об успешном / неуспешном импорте
                        if let successMsg = importSuccessMessage {
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.title2)
                                Text(successMsg)
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textPrimary)
                                Spacer()
                            }
                            .padding()
                            .background(Color.green.opacity(0.15))
                            .cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.green.opacity(0.3), lineWidth: 1))
                            .padding(.horizontal)
                        }
                        
                        if let errorMsg = importErrorMessage {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .font(.title2)
                                Text(errorMsg)
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textPrimary)
                                Spacer()
                            }
                            .padding()
                            .background(Color.red.opacity(0.15))
                            .cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.red.opacity(0.3), lineWidth: 1))
                            .padding(.horizontal)
                        }
                        
                        // MARK: - Карточка предпросмотра выбранного файла / Архива
                        if let preview = importPreview {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Image(systemName: preview.category.icon)
                                        .foregroundColor(Theme.exerciseColor)
                                        .font(.title3)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(preview.category.localizedTitle(lang: appLanguage))
                                            .font(.headline)
                                            .foregroundColor(Theme.textPrimary)
                                        
                                        Text("Файл: \(preview.fileName)")
                                            .font(.caption2)
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text("\(preview.validRecordsCount) зап.")
                                        .font(.caption.bold())
                                        .foregroundColor(.green)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color.green.opacity(0.15))
                                        .cornerRadius(8)
                                }
                                
                                // Сводка по категориям в архиве ZIP
                                if preview.isZipArchive {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Файлы, найденные в ZIP-архиве:")
                                            .font(.caption2.bold())
                                            .foregroundColor(Theme.textSecondary)
                                        
                                        VStack(alignment: .leading, spacing: 6) {
                                            ForEach(preview.archiveFilesFound, id: \.self) { fileItem in
                                                HStack {
                                                    Text(fileItem)
                                                        .font(.system(size: 12, weight: .medium))
                                                        .foregroundColor(Theme.textPrimary)
                                                    Spacer()
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundColor(.green)
                                                        .font(.caption)
                                                }
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(Color.primary.opacity(0.04))
                                                .cornerRadius(8)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                                
                                if !preview.warnings.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        ForEach(preview.warnings, id: \.self) { warn in
                                            Text("⚠️ \(warn)")
                                                .font(.caption2)
                                                .foregroundColor(.orange)
                                        }
                                    }
                                }
                                
                                // Таблица предпросмотра
                                if !preview.previewTableRows.isEmpty {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Предпросмотр записей:")
                                            .font(.caption.bold())
                                            .foregroundColor(Theme.textSecondary)
                                        
                                        ScrollView(.horizontal, showsIndicators: true) {
                                            VStack(alignment: .leading, spacing: 6) {
                                                // Заголовки таблицы
                                                HStack(spacing: 16) {
                                                    ForEach(preview.tableHeaders, id: \.self) { header in
                                                        Text(header)
                                                            .font(.caption2.bold())
                                                            .foregroundColor(Theme.textSecondary)
                                                            .frame(minWidth: 100, alignment: .leading)
                                                    }
                                                }
                                                .padding(.bottom, 2)
                                                
                                                Divider()
                                                    .background(Color.white.opacity(0.1))
                                                
                                                // Строки таблицы
                                                ForEach(0..<preview.previewTableRows.count, id: \.self) { rIdx in
                                                    let row = preview.previewTableRows[rIdx]
                                                    HStack(spacing: 16) {
                                                        ForEach(preview.tableHeaders, id: \.self) { h in
                                                            Text(row[h] ?? "—")
                                                                .font(.caption2)
                                                                .foregroundColor(Theme.textPrimary)
                                                                .frame(minWidth: 100, alignment: .leading)
                                                        }
                                                    }
                                                }
                                            }
                                            .padding(10)
                                            .background(Color.primary.opacity(0.04))
                                            .cornerRadius(12)
                                        }
                                    }
                                }
                                
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                
                                // Тумблер записи в Apple Health
                                Toggle(isOn: $saveToHealthKit) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(tr("csv_sync_hk_toggle"))
                                            .font(.subheadline.bold())
                                            .foregroundColor(Theme.textPrimary)
                                        Text(tr("csv_sync_hk_desc"))
                                            .font(.caption2)
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                }
                                .tint(.green)
                                
                                // Кнопка подтверждения импорта
                                Button(action: {
                                    executeImport(preview: preview)
                                }) {
                                    HStack(spacing: 8) {
                                        if isProcessing {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        } else {
                                            Image(systemName: preview.isZipArchive ? "archivebox.fill" : "checkmark.circle.fill")
                                        }
                                        Text(isProcessing ? tr("csv_importing") : (preview.isZipArchive ? "Импортировать все данные архива (\(preview.validRecordsCount))" : String(format: tr("csv_import_btn_format"), preview.validRecordsCount)))
                                            .bold()
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Theme.exerciseColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(16)
                                    .shadow(color: Theme.exerciseColor.opacity(0.3), radius: 6, y: 3)
                                }
                                .disabled(isProcessing || preview.validRecordsCount == 0)
                            }
                            .premiumCard()
                            .padding(.horizontal)
                        }
                        
                        // MARK: - Экспорт данных и шаблоны CSV
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Image(systemName: "square.and.arrow.up.fill")
                                    .foregroundColor(Theme.pulseColor)
                                Text(tr("csv_export_section_title"))
                                    .font(.headline)
                                    .foregroundColor(Theme.textPrimary)
                            }
                            
                            Text(tr("csv_export_section_desc"))
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                                .lineSpacing(3)
                            
                            // Кнопки экспорта
                            VStack(spacing: 10) {
                                // 1. Экспорт тренировок
                                Button(action: {
                                    let csv = HealthDataCSVManager.shared.exportWorkoutsToCSV(health.workoutHistory)
                                    shareCSV(content: csv, filename: "Forma_Workouts.csv")
                                }) {
                                    HStack {
                                        Label(tr("csv_export_workouts"), systemImage: "figure.run")
                                        Spacer()
                                        Text("\(health.workoutHistory.count) шт.")
                                            .font(.caption2)
                                            .foregroundColor(Theme.textSecondary)
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                    .foregroundColor(Theme.textPrimary)
                                    .padding(.vertical, 8)
                                }
                                
                                Divider()
                                    .background(Color.white.opacity(0.08))
                                
                                // 2. Экспорт веса
                                Button(action: {
                                    let csv = HealthDataCSVManager.shared.exportWeightsToCSV(health.weightHistory)
                                    shareCSV(content: csv, filename: "Forma_Weight.csv")
                                }) {
                                    HStack {
                                        Label(tr("csv_export_weight"), systemImage: "scalemass.fill")
                                        Spacer()
                                        Text("\(health.weightHistory.count) шт.")
                                            .font(.caption2)
                                            .foregroundColor(Theme.textSecondary)
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                    .foregroundColor(Theme.textPrimary)
                                    .padding(.vertical, 8)
                                }
                                
                                Divider()
                                    .background(Color.white.opacity(0.08))
                                
                                // 3. Экспорт дневной активности
                                Button(action: {
                                    let list = Array(health.dailyActivityHistory.values).sorted { $0.date > $1.date }
                                    let csv = HealthDataCSVManager.shared.exportActivityToCSV(list)
                                    shareCSV(content: csv, filename: "Forma_DailyActivity.csv")
                                }) {
                                    HStack {
                                        Label(tr("csv_export_activity"), systemImage: "flame.fill")
                                        Spacer()
                                        Text("\(health.dailyActivityHistory.count) дн.")
                                            .font(.caption2)
                                            .foregroundColor(Theme.textSecondary)
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                    .foregroundColor(Theme.textPrimary)
                                    .padding(.vertical, 8)
                                }
                                
                                Divider()
                                    .background(Color.white.opacity(0.08))
                                
                                // 4. Скачать шаблоны для заполнения
                                Menu {
                                    Button("Шаблон тренировок (Workouts CSV)") {
                                        let t = HealthDataCSVManager.shared.getSampleTemplateCSV(category: .workouts)
                                        shareCSV(content: t, filename: "Template_Workouts.csv")
                                    }
                                    Button("Шаблон веса (Weight CSV)") {
                                        let t = HealthDataCSVManager.shared.getSampleTemplateCSV(category: .weight)
                                        shareCSV(content: t, filename: "Template_Weight.csv")
                                    }
                                    Button("Шаблон активности (Activity CSV)") {
                                        let t = HealthDataCSVManager.shared.getSampleTemplateCSV(category: .activity)
                                        shareCSV(content: t, filename: "Template_Activity.csv")
                                    }
                                    Button("Шаблон питания и воды (Nutrition CSV)") {
                                        let t = HealthDataCSVManager.shared.getSampleTemplateCSV(category: .nutrition)
                                        shareCSV(content: t, filename: "Template_Nutrition.csv")
                                    }
                                } label: {
                                    HStack {
                                        Label(tr("csv_download_templates"), systemImage: "doc.badge.arrow.up")
                                            .foregroundColor(Theme.exerciseColor)
                                        Spacer()
                                        Image(systemName: "ellipsis.circle")
                                            .foregroundColor(Theme.exerciseColor)
                                    }
                                    .padding(.vertical, 8)
                                }
                            }
                        }
                        .premiumCard()
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationTitle(tr("csv_nav_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(tr("cancel")) {
                        dismiss()
                    }
                    .foregroundColor(Theme.textPrimary)
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [
                    .commaSeparatedText,
                    .plainText,
                    .text,
                    .zip,
                    UTType(filenameExtension: "csv") ?? .plainText,
                    UTType(filenameExtension: "zip") ?? .data
                ],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
            .sheet(isPresented: $showingShareSheet) {
                if let text = exportText {
                    ShareActivitySheet(text: text, filename: exportFileName)
                }
            }
        }
    }
    
    // MARK: - Логика обработки выбранного файла (CSV или ZIP)
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        do {
            guard let selectedURL = try result.get().first else { return }
            
            // Запрос доступа к security-scoped URL (iOS Files)
            let accessing = selectedURL.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    selectedURL.stopAccessingSecurityScopedResource()
                }
            }
            
            let data = try Data(contentsOf: selectedURL)
            let preview = HealthDataCSVManager.shared.parseFile(data: data, fileName: selectedURL.lastPathComponent)
            
            withAnimation(.spring()) {
                self.importPreview = preview
                self.importSuccessMessage = nil
                self.importErrorMessage = nil
            }
            
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
        } catch {
            importErrorMessage = "Ошибка открытия файла: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Выполнение импорта
    private func executeImport(preview: HealthDataImportPreview) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        isProcessing = true
        importSuccessMessage = nil
        importErrorMessage = nil
        
        Task {
            if preview.isZipArchive {
                // Пакетный импорт всех категорий из архива
                if !preview.parsedWorkouts.isEmpty {
                    await health.importWorkoutsFromCSV(preview.parsedWorkouts, saveToHK: saveToHealthKit)
                }
                if !preview.parsedWeights.isEmpty {
                    await health.importWeightsFromCSV(preview.parsedWeights, saveToHK: saveToHealthKit)
                }
                if !preview.parsedActivities.isEmpty {
                    await health.importActivitiesFromCSV(preview.parsedActivities, saveToHK: saveToHealthKit)
                }
                if !preview.parsedNutritions.isEmpty || !preview.parsedWaterRecords.isEmpty {
                    await health.importNutritionsFromCSV(preview.parsedNutritions, waters: preview.parsedWaterRecords, saveToHK: saveToHealthKit)
                }
                
                await MainActor.run {
                    importSuccessMessage = "Архив успешно импортирован! (\(preview.totalSummaryBadge))"
                }
            } else {
                switch preview.category {
                case .workouts:
                    await health.importWorkoutsFromCSV(preview.parsedWorkouts, saveToHK: saveToHealthKit)
                    await MainActor.run {
                        importSuccessMessage = String(format: tr("csv_success_workouts"), preview.parsedWorkouts.count)
                    }
                case .weight:
                    await health.importWeightsFromCSV(preview.parsedWeights, saveToHK: saveToHealthKit)
                    await MainActor.run {
                        importSuccessMessage = String(format: tr("csv_success_weight"), preview.parsedWeights.count)
                    }
                case .activity:
                    await health.importActivitiesFromCSV(preview.parsedActivities, saveToHK: saveToHealthKit)
                    await MainActor.run {
                        importSuccessMessage = String(format: tr("csv_success_activity"), preview.parsedActivities.count)
                    }
                case .nutrition:
                    await health.importNutritionsFromCSV(preview.parsedNutritions, waters: preview.parsedWaterRecords, saveToHK: saveToHealthKit)
                    await MainActor.run {
                        importSuccessMessage = String(format: tr("csv_success_nutrition"), preview.parsedNutritions.count)
                    }
                default:
                    await MainActor.run {
                        importErrorMessage = "Невозможно импортировать данные из неизвестного формата."
                    }
                }
            }
            
            await MainActor.run {
                isProcessing = false
                let notify = UINotificationFeedbackGenerator()
                notify.notificationOccurred(.success)
            }
        }
    }
    
    // MARK: - Экспорт через ShareSheet
    private func shareCSV(content: String, filename: String) {
        self.exportText = content
        self.exportFileName = filename
        self.showingShareSheet = true
    }
}

// MARK: - Вспомогательный ShareSheet для iOS
struct ShareActivitySheet: UIViewControllerRepresentable {
    let text: String
    let filename: String
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? text.write(to: tempURL, atomically: true, encoding: .utf8)
        
        let controller = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
