import SwiftUI
import Charts

// MARK: - 1. ДЕТАЛЬНЫЙ ЭКРАН ШАГОМЕРА И АКТИВНОСТИ
struct StepTrackerDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var health: HealthKitManager
    @EnvironmentObject var stepManager: BackgroundStepManager
    @AppStorage("app_language") private var appLanguage = "ru"
    
    @State private var selectedGoal: Int = 10000
    @State private var isRefreshing = false
    
    private func tr(_ key: String) -> String {
        LocalizationManager.tr(key, lang: appLanguage)
    }
    
    private var effectiveSteps: Int {
        max(stepManager.stepsToday, health.stepsToday)
    }
    
    private var effectiveDistanceKm: Double {
        let dist = max(stepManager.distanceMeters, health.distanceMetersToday)
        return dist / 1000.0
    }
    
    private var activeCalories: Double {
        health.activeEnergyBurned > 0 ? health.activeEnergyBurned : health.calculatedStepCalories
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    
                    // Главный круг / Прогресс
                    VStack(spacing: 12) {
                        let progress = min(1.0, Double(effectiveSteps) / Double(max(1, stepManager.stepGoal)))
                        
                        ZStack {
                            Circle()
                                .stroke(Color.primary.opacity(0.08), lineWidth: 16)
                            
                            Circle()
                                .trim(from: 0, to: CGFloat(progress))
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.orange, Color.red],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .animation(.spring(), value: progress)
                            
                            VStack(spacing: 4) {
                                Image(systemName: "figure.walk")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.orange)
                                
                                Text("\(effectiveSteps)")
                                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                                
                                Text(String(format: "%.0f%% от цели", progress * 100))
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        .frame(width: 180, height: 180)
                        .padding(.vertical, 8)
                        
                        // Метрики
                        HStack(spacing: 16) {
                            MetricItemView(
                                title: "Дистанция",
                                value: String(format: "%.2f км", effectiveDistanceKm),
                                icon: "location.fill",
                                color: .blue
                            )
                            MetricItemView(
                                title: "Калории",
                                value: String(format: "%.0f ккал", activeCalories),
                                icon: "flame.fill",
                                color: .orange
                            )
                            MetricItemView(
                                title: "Подъемы",
                                value: "\(stepManager.floorsAscended) эт.",
                                icon: "stairs",
                                color: .green
                            )
                        }
                    }
                    .premiumCard()
                    
                    // Почасовая активность за сегодня
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.orange)
                            Text("По часам сегодня")
                                .font(.headline)
                                .foregroundColor(Theme.textPrimary)
                            Spacer()
                            
                            let peakHour = stepManager.hourlySteps.max(by: { $0.steps < $1.steps })
                            if let peak = peakHour, peak.steps > 0 {
                                Text("Пик: \(String(format: "%02d:00", peak.hour)) (\(peak.steps) ш.)")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.12))
                                    .cornerRadius(8)
                            }
                        }
                        
                        if #available(iOS 16.0, *) {
                            let currentHour = Calendar.current.component(.hour, from: Date())
                            let maxSteps = max(100, stepManager.hourlySteps.map { $0.steps }.max() ?? 100)
                            
                            Chart {
                                ForEach(stepManager.hourlySteps) { item in
                                    let isCurrent = (item.hour == currentHour)
                                    let isPast = (item.hour <= currentHour)
                                    
                                    BarMark(
                                        x: .value("Час", item.hour),
                                        y: .value("Шаги", item.steps),
                                        width: .fixed(7)
                                    )
                                    .foregroundStyle(
                                        isCurrent
                                            ? LinearGradient(colors: [Color.yellow, Color.orange], startPoint: .top, endPoint: .bottom)
                                            : (item.steps > 0
                                               ? LinearGradient(colors: [Color.orange, Color(red: 255/255, green: 75/255, blue: 0/255)], startPoint: .top, endPoint: .bottom)
                                               : LinearGradient(colors: [Color.primary.opacity(isPast ? 0.08 : 0.03)], startPoint: .top, endPoint: .bottom))
                                    )
                                    .cornerRadius(3)
                                }
                            }
                            .chartXScale(domain: -0.5...23.5)
                            .chartYScale(domain: 0...(Double(maxSteps) * 1.15))
                            .chartXAxis {
                                AxisMarks(values: [0, 6, 12, 18, 23]) { value in
                                    if let hour = value.as(Int.self) {
                                        AxisValueLabel {
                                            Text(String(format: "%02d:00", hour))
                                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                                .foregroundColor(Theme.textSecondary)
                                        }
                                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                                            .foregroundStyle(Color.primary.opacity(0.08))
                                    }
                                }
                            }
                            .chartYAxis {
                                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                                        .foregroundStyle(Color.primary.opacity(0.08))
                                    AxisValueLabel {
                                        if let steps = value.as(Int.self) {
                                            Text("\(steps)")
                                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                                .foregroundColor(Theme.textSecondary)
                                        }
                                    }
                                }
                            }
                            .frame(height: 140)
                        }
                    }
                    .premiumCard()
                    
                    // Структура калорий и метаболизма (Apple Health)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Image(systemName: "flame.circle.fill")
                                .foregroundColor(.orange)
                            Text("Калории и баланс энергии")
                                .font(.headline)
                                .foregroundColor(Theme.textPrimary)
                            Spacer()
                        }
                        
                        VStack(spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Активные (движение & трен.)")
                                        .font(.subheadline)
                                        .foregroundColor(Theme.textSecondary)
                                    Text("Кольцо Move Apple Watch")
                                        .font(.caption2)
                                        .foregroundColor(Theme.textSecondary.opacity(0.8))
                                }
                                Spacer()
                                Text(String(format: "%.0f ккал", activeCalories))
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.orange)
                            }
                            
                            Divider().opacity(0.3)
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("В покое (базовый обмен BMR)")
                                        .font(.subheadline)
                                        .foregroundColor(Theme.textSecondary)
                                    Text("Жизнедеятельность организма")
                                        .font(.caption2)
                                        .foregroundColor(Theme.textSecondary.opacity(0.8))
                                }
                                Spacer()
                                let basal = health.basalEnergyBurned > 0 ? health.basalEnergyBurned : health.calculatedBasalEnergy
                                Text(String(format: "%.0f ккал", basal))
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.blue)
                            }
                            
                            Divider().opacity(0.3)
                            
                            HStack {
                                Text("Всего сожжено за день")
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundColor(Theme.textPrimary)
                                Spacer()
                                Text(String(format: "%.0f ккал", health.totalEnergyBurned))
                                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                            }
                            
                            Divider().opacity(0.3)
                            
                            HStack {
                                Text("Баланс (съедено − сожжено)")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textSecondary)
                                Spacer()
                                let balance = health.calorieBalance
                                HStack(spacing: 4) {
                                    Image(systemName: balance <= 0 ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                                        .foregroundColor(balance <= 0 ? .green : .orange)
                                    Text(String(format: "%+.0f ккал", balance))
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundColor(balance <= 0 ? .green : .orange)
                                }
                            }
                        }
                    }
                    .premiumCard()
                    
                    // Настройка дневной цели
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Image(systemName: "target")
                                .foregroundColor(.red)
                            Text("Дневная цель шагов")
                                .font(.headline)
                                .foregroundColor(Theme.textPrimary)
                            Spacer()
                            Text("\(selectedGoal) шагов")
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(.orange)
                        }
                        
                        HStack(spacing: 8) {
                            ForEach([6000, 8000, 10000, 12000, 15000], id: \.self) { goal in
                                Button(action: {
                                    selectedGoal = goal
                                    stepManager.setStepGoal(goal)
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }) {
                                    Text("\(goal / 1000)k")
                                        .font(.system(size: 13, weight: .bold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(stepManager.stepGoal == goal ? Color.orange : Color.primary.opacity(0.06))
                                        .foregroundColor(stepManager.stepGoal == goal ? .white : Theme.textPrimary)
                                        .cornerRadius(12)
                                }
                            }
                        }
                    }
                    .premiumCard()
                    
                    // Кнопка принудительного обновления сенсоров
                    Button(action: {
                        isRefreshing = true
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        Task {
                            health.fetchAllData()
                            await stepManager.refreshStepsFromPedometer()
                            await MainActor.run {
                                isRefreshing = false
                            }
                        }
                    }) {
                        HStack(spacing: 8) {
                            if isRefreshing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text(isRefreshing ? "Опрос аппаратных сенсоров..." : "Обновить данные шагомера")
                        }
                        .font(.system(size: 15, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .shadow(color: Color.orange.opacity(0.3), radius: 8, y: 4)
                    }
                    .disabled(isRefreshing)
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("Шагомер и активность")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                    .bold()
                }
            }
            .onAppear {
                selectedGoal = stepManager.stepGoal
            }
        }
    }
}

// MARK: - 2. ДЕТАЛЬНЫЙ ЭКРАН ВОДНОГО БАЛАНСА
struct WaterDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var health: HealthKitManager
    @AppStorage("app_language") private var appLanguage = "ru"
    
    @State private var customAmount: Double = 250
    @State private var selectedGoal: Double = 3000
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    
                    // Прогресс воды
                    VStack(spacing: 16) {
                        let currentL = health.waterConsumed / 1000.0
                        let goalL = health.waterGoal / 1000.0
                        let progress = min(1.0, health.waterConsumed / max(1.0, health.waterGoal))
                        
                        ZStack {
                            Circle()
                                .stroke(Color.primary.opacity(0.08), lineWidth: 16)
                            
                            Circle()
                                .trim(from: 0, to: CGFloat(progress))
                                .stroke(
                                    LinearGradient(
                                        colors: [Color(red: 0/255, green: 210/255, blue: 255/255), Color(red: 0/255, green: 122/255, blue: 255/255)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .animation(.spring(), value: progress)
                            
                            VStack(spacing: 4) {
                                Image(systemName: "drop.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(Color(red: 0/255, green: 160/255, blue: 255/255))
                                
                                Text(String(format: "%.1f л", currentL))
                                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                                
                                Text(String(format: "из %.1f л (%.0f%%)", goalL, progress * 100))
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        .frame(width: 190, height: 190)
                        .padding(.vertical, 8)
                        
                        Text(health.waterConsumed >= health.waterGoal ? "🎉 Дневная норма воды выполнена!" : "Осталось выпить: \(String(format: "%.1f л", max(0, (health.waterGoal - health.waterConsumed) / 1000.0)))")
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(health.waterConsumed >= health.waterGoal ? .green : Theme.textSecondary)
                    }
                    .premiumCard()
                    
                    // Быстрое добавление порций
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Добавить выпитую воду")
                            .font(.headline)
                            .foregroundColor(Theme.textPrimary)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            QuickWaterButton(amount: 100, label: "+100 мл", icon: "drop") {
                                addWater(100)
                            }
                            QuickWaterButton(amount: 200, label: "+200 мл", icon: "cup.and.saucer.fill") {
                                addWater(200)
                            }
                            QuickWaterButton(amount: 250, label: "+250 мл", icon: "mug.fill") {
                                addWater(250)
                            }
                            QuickWaterButton(amount: 330, label: "+330 мл", icon: "waterbottle.fill") {
                                addWater(330)
                            }
                            QuickWaterButton(amount: 500, label: "+500 мл", icon: "waterbottle") {
                                addWater(500)
                            }
                            QuickWaterButton(amount: 750, label: "+750 мл", icon: "wineglass.fill") {
                                addWater(750)
                            }
                        }
                    }
                    .premiumCard()
                    
                    // Настройка дневной нормы
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                                .foregroundColor(.blue)
                            Text("Целевая норма на день")
                                .font(.headline)
                                .foregroundColor(Theme.textPrimary)
                            Spacer()
                            Text(String(format: "%.1f л", selectedGoal / 1000.0))
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(.blue)
                        }
                        
                        HStack(spacing: 8) {
                            ForEach([2000.0, 2500.0, 3000.0, 3500.0, 4000.0], id: \.self) { goal in
                                Button(action: {
                                    selectedGoal = goal
                                    health.waterGoal = goal
                                    UserDefaults.standard.set(goal, forKey: "local_water_goal")
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }) {
                                    Text(String(format: "%.1fл", goal / 1000.0))
                                        .font(.system(size: 13, weight: .bold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(health.waterGoal == goal ? Color.blue : Color.primary.opacity(0.06))
                                        .foregroundColor(health.waterGoal == goal ? .white : Theme.textPrimary)
                                        .cornerRadius(12)
                                }
                            }
                        }
                    }
                    .premiumCard()
                    
                    // Кнопка сброса за сегодня
                    Button(role: .destructive, action: {
                        health.resetWater()
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Сбросить выпитую воду за сегодня")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.08))
                        .cornerRadius(14)
                    }
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("Водный баланс")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                    .bold()
                }
            }
            .onAppear {
                selectedGoal = health.waterGoal
            }
        }
    }
    
    private func addWater(_ ml: Double) {
        health.addWater(amount: ml)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

struct QuickWaterButton: View {
    let amount: Double
    let label: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.system(size: 13, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.blue.opacity(0.12))
            .foregroundColor(.blue)
            .cornerRadius(14)
        }
    }
}

// MARK: - 3. ДЕТАЛЬНЫЙ ЭКРАН ПИТАНИЯ И БЖУ
struct NutritionDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var health: HealthKitManager
    @AppStorage("app_language") private var appLanguage = "ru"
    
    let onOpenScanner: () -> Void
    
    @State private var manualCalories: String = ""
    @State private var manualProtein: String = ""
    @State private var manualFat: String = ""
    @State private var manualCarbs: String = ""
    @State private var showingAddManual = false
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    
                    // Калории сводка
                    VStack(spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Потреблено калорий")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textSecondary)
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text(String(format: "%.0f", health.caloriesConsumedToday))
                                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                                        .foregroundColor(Theme.textPrimary)
                                    Text("/ 2 200 ккал")
                                        .font(.headline)
                                        .foregroundColor(Theme.textSecondary)
                                }
                            }
                            Spacer()
                            
                            Button(action: {
                                dismiss()
                                onOpenScanner()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "camera.viewfinder")
                                    Text("Скан ИИ")
                                }
                                .font(.system(size: 13, weight: .bold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(14)
                                .shadow(color: Color.green.opacity(0.3), radius: 6)
                            }
                        }
                        
                        let progress = min(1.0, health.caloriesConsumedToday / 2200.0)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.primary.opacity(0.08))
                                    .frame(height: 10)
                                
                                Capsule()
                                    .fill(LinearGradient(colors: [.green, Color(red: 0/255, green: 220/255, blue: 180/255)], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: max(10, geo.size.width * CGFloat(progress)), height: 10)
                            }
                        }
                        .frame(height: 10)
                    }
                    .premiumCard()
                    
                    // Макронутриенты БЖУ
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Баланс макронутриентов (БЖУ)")
                            .font(.headline)
                            .foregroundColor(Theme.textPrimary)
                        
                        MacroDetailRow(
                            name: "Белки",
                            currentG: health.proteinConsumedToday,
                            goalG: 140,
                            color: Color(red: 255/255, green: 90/255, blue: 95/255)
                        )
                        
                        MacroDetailRow(
                            name: "Жиры",
                            currentG: health.fatConsumedToday,
                            goalG: 70,
                            color: Color(red: 255/255, green: 185/255, blue: 45/255)
                        )
                        
                        MacroDetailRow(
                            name: "Углеводы",
                            currentG: health.carbsConsumedToday,
                            goalG: 240,
                            color: Color(red: 50/255, green: 175/255, blue: 255/255)
                        )
                    }
                    .premiumCard()
                    
                    // Ручное добавление приема пищи
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Быстрое добавление вручную")
                            .font(.headline)
                            .foregroundColor(Theme.textPrimary)
                        
                        HStack(spacing: 10) {
                            TextField("Калории (ккал)", text: $manualCalories)
                                .keyboardType(.numberPad)
                                .padding(12)
                                .background(Color.primary.opacity(0.04))
                                .cornerRadius(12)
                            
                            TextField("Белки (г)", text: $manualProtein)
                                .keyboardType(.numberPad)
                                .padding(12)
                                .background(Color.primary.opacity(0.04))
                                .cornerRadius(12)
                        }
                        
                        HStack(spacing: 10) {
                            TextField("Жиры (г)", text: $manualFat)
                                .keyboardType(.numberPad)
                                .padding(12)
                                .background(Color.primary.opacity(0.04))
                                .cornerRadius(12)
                            
                            TextField("Углеводы (г)", text: $manualCarbs)
                                .keyboardType(.numberPad)
                                .padding(12)
                                .background(Color.primary.opacity(0.04))
                                .cornerRadius(12)
                        }
                        
                        Button(action: {
                            guard let kcal = Double(manualCalories), kcal > 0 else { return }
                            let p = Double(manualProtein) ?? 0
                            let f = Double(manualFat) ?? 0
                            let c = Double(manualCarbs) ?? 0
                            
                            health.addDietaryNutrition(
                                calories: kcal,
                                protein: p,
                                fat: f,
                                carbs: c,
                                mealName: "Ручной ввод"
                            )
                            
                            manualCalories = ""
                            manualProtein = ""
                            manualFat = ""
                            manualCarbs = ""
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }) {
                            Text("Сохранить прием пищи")
                                .font(.system(size: 15, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(14)
                        }
                    }
                    .premiumCard()
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("Питание и БЖУ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}

struct MacroDetailRow: View {
    let name: String
    let currentG: Double
    let goalG: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(name)
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Text(String(format: "%.0fг / %.0fг", currentG, goalG))
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(Theme.textSecondary)
            }
            
            let progress = min(1.0, currentG / max(1.0, goalG))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.06))
                        .frame(height: 6)
                    Capsule()
                        .fill(color)
                        .frame(width: max(6, geo.size.width * CGFloat(progress)), height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - 4. ДЕТАЛЬНЫЙ ЭКРАН ПУЛЬСА
struct HeartRateDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var health: HealthKitManager
    @AppStorage("app_language") private var appLanguage = "ru"
    
    @State private var manualPulseInput: String = ""
    @State private var showSavedAlert = false
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    
                    // Живой пульсометр
                    VStack(spacing: 16) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 64))
                            .foregroundColor(Theme.pulseColor)
                            .scaleEffect(health.isLiveHeartRateActive ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: health.isLiveHeartRateActive)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            let displayBpm = health.isLiveHeartRateActive ? (health.liveHeartRate > 0 ? "\(Int(health.liveHeartRate))" : "...") : (health.heartRate > 0 ? "\(Int(health.heartRate))" : "--")
                            Text(displayBpm)
                                .font(.system(size: 52, weight: .heavy, design: .rounded))
                                .foregroundColor(Theme.textPrimary)
                            Text("уд/мин")
                                .font(.title3)
                                .bold()
                                .foregroundColor(Theme.textSecondary)
                        }
                        
                        if health.heartRate > 0 {
                            Text("Зона: \(health.heartRateZone.localizedName(lang: appLanguage))")
                                .font(.system(size: 13, weight: .bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(health.heartRateZone.color.opacity(0.15))
                                .foregroundColor(health.heartRateZone.color)
                                .cornerRadius(10)
                        } else {
                            Text("Датчики пульса ожидают замера")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                        
                        Button(action: {
                            if health.isLiveHeartRateActive {
                                health.stopLiveHeartRateSession()
                            } else {
                                health.startLiveHeartRateSession()
                            }
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: health.isLiveHeartRateActive ? "stop.fill" : "play.fill")
                                Text(health.isLiveHeartRateActive ? "Остановить замер" : "Начать живой замер (AirPods / Apple Watch)")
                            }
                            .font(.system(size: 15, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(health.isLiveHeartRateActive ? Color.gray.opacity(0.7) : Theme.pulseColor)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                        }
                    }
                    .premiumCard()
                    
                    // Ручной ввод пульса
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Внести показатель пульса вручную")
                            .font(.headline)
                            .foregroundColor(Theme.textPrimary)
                        
                        HStack(spacing: 10) {
                            TextField("Пульс (уд/мин)", text: $manualPulseInput)
                                .keyboardType(.numberPad)
                                .padding(12)
                                .background(Color.primary.opacity(0.05))
                                .cornerRadius(12)
                            
                            Button(action: {
                                guard let bpm = Int(manualPulseInput), bpm >= 30, bpm <= 240 else { return }
                                health.addHeartRateSample(bpm: bpm)
                                manualPulseInput = ""
                                showSavedAlert = true
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }) {
                                Text("Сохранить")
                                    .bold()
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Theme.pulseColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .premiumCard()
                    
                    // Кардиовыносливость и Восстановление (HRV, VO2 Max, SpO2)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(.yellow)
                            Text("Восстановление и Кардиовыносливость")
                                .font(.headline)
                                .foregroundColor(Theme.textPrimary)
                        }
                        
                        // Индекс восстановления и HRV
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Индекс готовности")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                                Text("\(health.recoveryScore)%")
                                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                                    .foregroundColor(health.recoveryScore >= 75 ? Theme.exerciseColor : (health.recoveryScore >= 50 ? .orange : Theme.pulseColor))
                                Text("Стресс: \(health.stressLevel)")
                                    .font(.caption2)
                                    .bold()
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.primary.opacity(0.04))
                            .cornerRadius(14)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Вариабельность (HRV)")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                                Text(String(format: "%.0f мс", health.hrvSDNN))
                                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                                Text("Apple Watch SDNN")
                                    .font(.caption2)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.primary.opacity(0.04))
                            .cornerRadius(14)
                        }
                        
                        // VO2 Max и Пульс покоя
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("VO2 Max (Выносливость)")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                                Text(String(format: "%.1f", health.vo2Max))
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                                Text(health.cardioFitnessLevel)
                                    .font(.caption2)
                                    .bold()
                                    .foregroundColor(Theme.exerciseColor)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.primary.opacity(0.04))
                            .cornerRadius(14)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Пульс в покое")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                                Text(String(format: "%.0f уд/мин", health.restingHeartRate > 0 ? health.restingHeartRate : 62.0))
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                                Text("Кислород SpO2: \(Int(health.bloodOxygen))%")
                                    .font(.caption2)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.primary.opacity(0.04))
                            .cornerRadius(14)
                        }
                    }
                    .premiumCard()
                    
                    // Зоны ЧСС
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Пульсовые зоны тренировок")
                            .font(.headline)
                            .foregroundColor(Theme.textPrimary)
                        
                        ZoneRowView(name: "Покой", range: "< 60 уд/мин", color: Color(red: 0/255, green: 190/255, blue: 255/255))
                        ZoneRowView(name: "Разминка", range: "60 - 100 уд/мин", color: Color(red: 50/255, green: 215/255, blue: 75/255))
                        ZoneRowView(name: "Жиросжигание", range: "100 - 140 уд/мин", color: Color(red: 255/255, green: 204/255, blue: 0/255))
                        ZoneRowView(name: "Кардио", range: "140 - 170 уд/мин", color: Color(red: 255/255, green: 149/255, blue: 0/255))
                        ZoneRowView(name: "Пиковая", range: "170+ уд/мин", color: Color(red: 255/255, green: 59/255, blue: 48/255))
                    }
                    .premiumCard()
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("Мониторинг пульса")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}

struct ZoneRowView: View {
    let name: String
    let range: String
    let color: Color
    
    var body: some View {
        HStack {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(name)
                .font(.subheadline)
                .bold()
                .foregroundColor(Theme.textPrimary)
            Spacer()
            Text(range)
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 5. ДЕТАЛЬНЫЙ ЭКРАН СНА
struct SleepDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var health: HealthKitManager
    @AppStorage("app_language") private var appLanguage = "ru"
    
    @State private var sleepInputHours: Double = 8.0
    @State private var deepInputHours: Double = 1.5
    @State private var showSavedSleepAlert = false
    @State private var isRefreshing = false
    
    private var hasDetailedStages: Bool {
        health.deepSleepDuration > 0 || health.remSleepDuration > 0 || health.coreSleepDuration > 0
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    
                    // Сводка сна из Apple Health
                    if health.sleepDuration > 0 {
                        VStack(spacing: 16) {
                            Image(systemName: "moon.stars.fill")
                                .font(.system(size: 54))
                                .foregroundColor(Theme.sleepColor)
                            
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(String(format: "%.1f", health.sleepDuration))
                                    .font(.system(size: 48, weight: .heavy, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                                Text("часов")
                                    .font(.title3)
                                    .bold()
                                    .foregroundColor(Theme.textSecondary)
                            }
                            
                            HStack(spacing: 12) {
                                HStack(spacing: 6) {
                                    Image(systemName: "sparkles")
                                        .foregroundColor(.yellow)
                                    Text("Качество: \(health.sleepQualityScore)%")
                                        .font(.subheadline)
                                        .bold()
                                        .foregroundColor(Theme.textPrimary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.primary.opacity(0.05))
                                .cornerRadius(10)
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "heart.text.square.fill")
                                        .foregroundColor(Theme.sleepColor)
                                    Text("Apple Health")
                                        .font(.caption)
                                        .bold()
                                        .foregroundColor(Theme.textSecondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Theme.sleepColor.opacity(0.1))
                                .cornerRadius(10)
                            }
                        }
                        .premiumCard()
                        
                        // Фазы сна (если зафиксированы Apple Watch)
                        if hasDetailedStages {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Text("Фазы и структура сна")
                                        .font(.headline)
                                        .foregroundColor(Theme.textPrimary)
                                    Spacer()
                                    Image(systemName: "applewatch")
                                        .foregroundColor(Theme.textSecondary)
                                        .font(.subheadline)
                                }
                                
                                // Сегментированный бар фаз
                                GeometryReader { geo in
                                    HStack(spacing: 3) {
                                        let total = max(1.0, health.deepSleepDuration + health.remSleepDuration + health.coreSleepDuration + health.awakeDuration)
                                        if health.deepSleepDuration > 0 {
                                            Rectangle()
                                                .fill(Color(red: 90/255, green: 94/255, blue: 226/255))
                                                .frame(width: geo.size.width * CGFloat(health.deepSleepDuration / total))
                                        }
                                        if health.remSleepDuration > 0 {
                                            Rectangle()
                                                .fill(Color(red: 140/255, green: 145/255, blue: 255/255))
                                                .frame(width: geo.size.width * CGFloat(health.remSleepDuration / total))
                                        }
                                        if health.coreSleepDuration > 0 {
                                            Rectangle()
                                                .fill(Color(red: 80/255, green: 180/255, blue: 255/255))
                                                .frame(width: geo.size.width * CGFloat(health.coreSleepDuration / total))
                                        }
                                        if health.awakeDuration > 0 {
                                            Rectangle()
                                                .fill(Color.orange.opacity(0.7))
                                                .frame(width: geo.size.width * CGFloat(health.awakeDuration / total))
                                        }
                                    }
                                    .cornerRadius(8)
                                }
                                .frame(height: 14)
                                
                                // Детализация фаз
                                VStack(spacing: 8) {
                                    if health.deepSleepDuration > 0 {
                                        SleepStageRow(name: "Глубокий сон (Deep)", duration: health.deepSleepDuration, color: Color(red: 90/255, green: 94/255, blue: 226/255))
                                    }
                                    if health.remSleepDuration > 0 {
                                        SleepStageRow(name: "Быстрый сон (REM)", duration: health.remSleepDuration, color: Color(red: 140/255, green: 145/255, blue: 255/255))
                                    }
                                    if health.coreSleepDuration > 0 {
                                        SleepStageRow(name: "Базовый сон (Core)", duration: health.coreSleepDuration, color: Color(red: 80/255, green: 180/255, blue: 255/255))
                                    }
                                    if health.awakeDuration > 0 {
                                        SleepStageRow(name: "Бодрствование (Awake)", duration: health.awakeDuration, color: Color.orange.opacity(0.7))
                                    }
                                }
                            }
                            .premiumCard()
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 8) {
                                    Image(systemName: "applewatch.side.right")
                                        .foregroundColor(Theme.sleepColor)
                                        .font(.title3)
                                    Text("Базовый замер сна")
                                        .font(.subheadline)
                                        .bold()
                                        .foregroundColor(Theme.textPrimary)
                                }
                                Text("В Apple Health зафиксирована общая продолжительность сна без разделения на стадии. Для отслеживания глубокой, быстрой (REM) и базовой (Core) фаз используйте Apple Watch во время сна.")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                                    .lineSpacing(3)
                            }
                            .premiumCard()
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "moon.zzz.fill")
                                .font(.system(size: 44))
                                .foregroundColor(Theme.sleepColor.opacity(0.8))
                            Text("Нет данных о сне за сегодня")
                                .font(.headline)
                                .foregroundColor(Theme.textPrimary)
                            Text("В Apple Health пока не зафиксирован сон за текущие сутки. Данные появятся автоматически при синхронизации с Apple Watch или после ручной записи.")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                            
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                Task {
                                    isRefreshing = true
                                    await health.fetchSleepData()
                                    isRefreshing = false
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                                    Text(isRefreshing ? "Синхронизация..." : "Проверить Apple Health")
                                }
                                .font(.caption.bold())
                                .foregroundColor(Theme.sleepColor)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Theme.sleepColor.opacity(0.12))
                                .cornerRadius(10)
                            }
                            .padding(.top, 4)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .premiumCard()
                    }
                    
                    // Запись сна в Apple Health
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Записать сон в Apple Health")
                            .font(.headline)
                            .foregroundColor(Theme.textPrimary)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Общее время сна:")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textSecondary)
                                Spacer()
                                Text(String(format: "%.1f ч", sleepInputHours))
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundColor(Theme.textPrimary)
                            }
                            Slider(value: $sleepInputHours, in: 1.0...14.0, step: 0.5)
                                .tint(Theme.sleepColor)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Глубокая фаза (примерно):")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textSecondary)
                                Spacer()
                                Text(String(format: "%.1f ч", deepInputHours))
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundColor(Theme.textPrimary)
                            }
                            Slider(value: $deepInputHours, in: 0.0...max(0.5, sleepInputHours), step: 0.5)
                                .tint(Theme.sleepColor.opacity(0.7))
                        }
                        
                        Button(action: {
                            let now = Date()
                            let start = now.addingTimeInterval(-sleepInputHours * 3600.0)
                            health.addSleepRecord(hours: sleepInputHours, deepHours: deepInputHours, startDate: start, endDate: now)
                            showSavedSleepAlert = true
                            let impact = UINotificationFeedbackGenerator()
                            impact.notificationOccurred(.success)
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.seal.fill")
                                Text("Сохранить в Apple Health")
                            }
                            .font(.system(size: 15, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.sleepColor)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                            .shadow(color: Theme.sleepColor.opacity(0.35), radius: 8)
                        }
                    }
                    .premiumCard()
                    
                    // Советы по сну
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(.yellow)
                            Text("Рекомендации для качественного сна")
                                .font(.headline)
                                .foregroundColor(Theme.textPrimary)
                        }
                        
                        SleepTipRow(icon: "thermometer.snowflake", text: "Оптимальная температура в спальне 18–20°C для глубокой фазы сна.")
                        SleepTipRow(icon: "iphone.slash", text: "Уберите гаджеты за 45 минут до сна для нормализации выработки мелатонина.")
                        SleepTipRow(icon: "cup.and.saucer", text: "Избегайте кофеина за 6 часов до отхода ко сну.")
                    }
                    .premiumCard()
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("Сон и отдых")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await health.fetchSleepData()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        Task {
                            await health.fetchSleepData()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(Theme.textPrimary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                    .bold()
                }
            }
            .alert("Сон сохранен", isPresented: $showSavedSleepAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Данные о сне (\(String(format: "%.1f", sleepInputHours)) ч) успешно записаны в Apple Health и синхронизированы в приложении!")
            }
        }
    }
}

struct SleepTipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(Theme.sleepColor)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundColor(Theme.textPrimary.opacity(0.9))
                .lineSpacing(3)
        }
        .padding(.vertical, 3)
    }
}

struct MetricItemView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 14, weight: .bold))
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textPrimary)
            Text(title)
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .cornerRadius(12)
    }
}

struct SleepStageRow: View {
    let name: String
    let duration: Double
    let color: Color
    
    var body: some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(name)
                .font(.subheadline)
                .bold()
                .foregroundColor(Theme.textPrimary)
            Spacer()
            Text(String(format: "%.1f ч", duration))
                .font(.subheadline)
                .bold()
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.vertical, 2)
    }
}

