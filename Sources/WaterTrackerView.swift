import SwiftUI

struct WaterTrackerView: View {
    @EnvironmentObject var health: HealthKitManager
    @State private var customWaterInput = ""
    @State private var showingCustomWaterAlert = false
    @State private var animatedProgress: Double = 0.0
    
    @State private var isAnalyzingWater = false
    @State private var waterAnalysisResult: String? = nil
    @State private var waterAnalysisError: String? = nil
    @AppStorage("api_key_gemini") private var apiKeyGemini = ""
    @AppStorage("api_key_openai") private var apiKeyOpenAI = ""
    @AppStorage("api_key_claude") private var apiKeyClaude = ""
    
    private var hasAnyApiKey: Bool {
        !apiKeyGemini.isEmpty || !apiKeyOpenAI.isEmpty || !apiKeyClaude.isEmpty
    }
    
    // Полезные статьи/советы о воде
    private let waterTips = [
        WaterTip(
            title: "Зачем организму вода?",
            text: "Вода составляет около 60% массы тела взрослого человека. Она доставляет питательные вещества к клеткам, выводит токсины, поддерживает нормальную температуру тела и смазывает суставы. Недостаток воды замедляет метаболизм.",
            icon: "info.circle.fill"
        ),
        WaterTip(
            title: "Вода и спортивные результаты",
            text: "Обезвоживание всего на 2% снижает физическую выносливость на 10-20%. Во время интенсивных тренировок пейте воду каждые 15-20 минут небольшими глотками, чтобы избежать спазмов и перегрева.",
            icon: "figure.run.circle.fill"
        ),
        WaterTip(
            title: "Как узнать, что воды не хватает?",
            text: "Первые признаки обезвоживания — это сухость во рту, легкое головокружение, чувство усталости, головная боль и темный цвет мочи. Не ждите появления жажды — это уже сигнал о начавшемся дефиците воды.",
            icon: "exclamationmark.triangle.fill"
        ),
        WaterTip(
            title: "Как выработать привычку пить воду?",
            text: "1. Держите бутылку с водой всегда под рукой.\n2. Выпивайте стакан воды сразу после пробуждения.\n3. Добавьте в воду ломтик лимона, огурца или мяты для вкуса.\n4. Используйте Nano Health для отслеживания прогресса!",
            icon: "checkmark.circle.fill"
        )
    ]
    
    // Рассчитанная норма воды: 35 мл на 1 кг веса
    private var calculatedNorm: Double {
        if health.currentWeight > 0 {
            return health.currentWeight * 35.0 // в мл
        } else {
            return 2500.0 // Дефолтное значение: 2.5 литра
        }
    }
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Заголовок
                    HStack {
                        Text("Водный баланс")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    
                    // 1. КАРТОЧКА ПРОГРЕССА (СТАКАН И ПРОЦЕНТЫ)
                    VStack(spacing: 16) {
                        let progress = calculatedNorm > 0 ? health.waterConsumed / calculatedNorm : 0.0
                        
                        HStack(spacing: 24) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Выпито сегодня")
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundColor(.white.opacity(0.7))
                                
                                Text(String(format: "%.0f / %.0f мл", health.waterConsumed, calculatedNorm))
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                
                                Text(String(format: "Выполнено на %.0f%%", min(progress * 100.0, 100.0)))
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(progress >= 1.0 ? .green : .white.opacity(0.6))
                            }
                            
                            Spacer()
                            
                            // Визуальный стакан
                            ZStack {
                                Circle()
                                    .stroke(Color.white.opacity(0.1), lineWidth: 8)
                                
                                Circle()
                                    .trim(from: 0.0, to: CGFloat(min(animatedProgress, 1.0)))
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color(red: 0/255, green: 229/255, blue: 255/255), Color(red: 0/255, green: 145/255, blue: 255/255)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                    )
                                    .rotationEffect(Angle(degrees: -90))
                                    .neonShadow(color: Color(red: 0/255, green: 229/255, blue: 255/255), radius: 4)
                                
                                GlassWaterView(progress: progress)
                            }
                            .frame(width: 100, height: 100)
                        }
                    }
                    .padding(20)
                    .background(Theme.waterCardGradient)
                    .cornerRadius(24)
                    .shadow(color: Color(red: 0/255, green: 122/255, blue: 255/255).opacity(0.15), radius: 10)
                    .padding(.horizontal)
                    
                    // 2. БЫСТРОЕ ВНЕСЕНИЕ
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Добавить воду")
                                .font(.headline)
                                .foregroundColor(Theme.textPrimary)
                            Spacer()
                            if health.waterConsumed > 0 {
                                Button(action: {
                                    let impact = UIImpactFeedbackGenerator(style: .heavy)
                                    impact.impactOccurred()
                                    health.resetWater()
                                }) {
                                    Text("Сбросить")
                                        .font(.caption)
                                        .bold()
                                        .foregroundColor(Theme.pulseColor)
                                }
                            }
                        }
                        
                        HStack(spacing: 12) {
                            WaterButton(amount: 200, icon: "drop") {
                                health.addWater(amount: 200)
                            }
                            
                            WaterButton(amount: 250, icon: "drop.fill") {
                                health.addWater(amount: 250)
                            }
                            
                            WaterButton(amount: 500, icon: "drop.circle.fill") {
                                health.addWater(amount: 500)
                            }
                        }
                        
                        Button(action: {
                            showingCustomWaterAlert = true
                        }) {
                            HStack {
                                Image(systemName: "pencil.line")
                                Text("Ввести кастомный объем")
                            }
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(red: 0/255, green: 122/255, blue: 255/255))
                            .cornerRadius(16)
                            .shadow(color: Color(red: 0/255, green: 122/255, blue: 255/255).opacity(0.3), radius: 6)
                        }
                    }
                    .premiumCard()
                    .padding(.horizontal)
                    
                    // 3. КАЛЬКУЛЯТОР НОРМЫ
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "calculator.fill")
                                .foregroundColor(Theme.exerciseColor)
                            Text("Индивидуальный расчет")
                                .font(.headline)
                                .foregroundColor(Theme.textPrimary)
                        }
                        
                        if health.currentWeight > 0 {
                            Text("На основе вашего веса (\(String(format: "%.1f кг", health.currentWeight))) ИИ рекомендует пить около \(String(format: "%.0f мл", calculatedNorm)) воды в сутки (из расчета 35 мл на 1 кг веса).")
                                .font(.subheadline)
                                .foregroundColor(Theme.textPrimary.opacity(0.8))
                                .lineSpacing(3)
                        } else {
                            Text("Для индивидуального расчета нормы воды внесите ваш вес в разделе 'Настройки'. Сейчас используется стандартная норма: 2500 мл.")
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                                .lineSpacing(3)
                        }
                    }
                    .premiumCard()
                    .padding(.horizontal)
                    
                    // 3.5. Карточка ИИ-анализа воды
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .foregroundColor(.yellow)
                                .font(.title3)
                            Text("Советы по гидратации от ИИ")
                                .font(.headline)
                                .foregroundColor(Theme.textPrimary)
                            Spacer()
                        }
                        
                        if !hasAnyApiKey {
                            Text("Укажите хотя бы один API-ключ на вкладке 'Настройки', чтобы активировать советы ИИ по гидратации.")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 8)
                        } else {
                            if let analysis = waterAnalysisResult {
                                ScrollView {
                                    Text(analysis)
                                        .font(.subheadline)
                                        .foregroundColor(Theme.textPrimary.opacity(0.9))
                                        .lineSpacing(4)
                                        .multilineTextAlignment(.leading)
                                        .padding(12)
                                }
                                .frame(maxHeight: 180)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(16)
                            } else if let error = waterAnalysisError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(Theme.pulseColor)
                                    .padding()
                                    .background(Theme.pulseColor.opacity(0.08))
                                    .cornerRadius(16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                Text("ИИ оценит количество выпитой воды за сегодня относительно вашей цели и вашего веса, дав ценные советы по питьевому режиму.")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                                    .padding(.vertical, 4)
                            }
                            
                            Button(action: {
                                runWaterAnalysis()
                            }) {
                                HStack {
                                    if isAnalyzingWater {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .padding(.trailing, 8)
                                    }
                                    Text(isAnalyzingWater ? "Анализирую..." : "Анализировать питьевой режим")
                                        .bold()
                                }
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.white)
                                .padding()
                                .background(isAnalyzingWater ? Theme.exerciseColor.opacity(0.6) : Theme.exerciseColor)
                                .cornerRadius(16)
                                .shadow(color: Theme.exerciseColor.opacity(0.3), radius: 8)
                            }
                            .disabled(isAnalyzingWater)
                        }
                    }
                    .premiumCard()
                    .padding(.horizontal)
                    
                    // 4. ПОЛЕЗНАЯ ИНФОРМАЦИЯ
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Полезные советы")
                            .font(.headline)
                            .foregroundColor(Theme.textPrimary)
                        
                        ForEach(waterTips) { tip in
                            DisclosureGroup(
                                content: {
                                    Text(tip.text)
                                        .font(.subheadline)
                                        .foregroundColor(Theme.textPrimary.opacity(0.8))
                                        .padding(.vertical, 8)
                                        .lineSpacing(3)
                                },
                                label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: tip.icon)
                                            .foregroundColor(Color(red: 0/255, green: 145/255, blue: 255/255))
                                            .font(.headline)
                                        Text(tip.title)
                                            .font(.subheadline)
                                            .bold()
                                            .foregroundColor(Theme.textPrimary)
                                    }
                                }
                            )
                            .padding()
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(12)
                        }
                    }
                    .premiumCard()
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
        }
        .alert("Кастомный объем", isPresented: $showingCustomWaterAlert) {
            TextField("Объем (мл)", text: $customWaterInput)
                .keyboardType(.numberPad)
            Button("Отмена", role: .cancel) {
                customWaterInput = ""
            }
            Button("Добавить") {
                if let amount = Double(customWaterInput) {
                    health.addWater(amount: amount)
                }
                customWaterInput = ""
            }
        } message: {
            Text("Введите количество выпитой воды в миллилитрах.")
        }
    }
    
    private func runWaterAnalysis() {
        guard hasAnyApiKey else { return }
        isAnalyzingWater = true
        waterAnalysisError = nil
        waterAnalysisResult = nil
        
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        Task {
            do {
                let result = try await GeminiScanService.shared.analyzeWaterIntake(
                    consumed: health.waterConsumed,
                    goal: calculatedNorm,
                    weight: health.currentWeight
                )
                await MainActor.run {
                    self.waterAnalysisResult = result
                    self.isAnalyzingWater = false
                }
            } catch {
                await MainActor.run {
                    self.waterAnalysisError = "Ошибка анализа: \(error.localizedDescription)"
                    self.isAnalyzingWater = false
                }
            }
        }
        .onAppear {
            animatedProgress = calculatedNorm > 0 ? health.waterConsumed / calculatedNorm : 0.0
        }
        .onChange(of: health.waterConsumed) { _, newValue in
            let newProgress = calculatedNorm > 0 ? newValue / calculatedNorm : 0.0
            withAnimation(.easeInOut(duration: 0.8)) {
                animatedProgress = newProgress
            }
        }
    }
}

// Кнопка быстрого добавления воды
struct WaterButton: View {
    let amount: Int
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            action()
        }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(Color(red: 0/255, green: 145/255, blue: 255/255))
                
                Text("+\(amount) мл")
                    .font(.caption)
                    .bold()
                    .foregroundColor(Theme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
        }
    }
}

// Модель подсказок
struct WaterTip: Identifiable {
    let id = UUID()
    let title: String
    let text: String
    let icon: String
}
