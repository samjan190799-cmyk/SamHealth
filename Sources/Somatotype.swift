import SwiftUI

/// Физиологический тип телосложения (соматотип по классификации Уильяма Шелдона)
public enum Somatotype: String, CaseIterable, Identifiable, Codable {
    case ectomorph = "ectomorph" // Эктоморф / «Хардгейнер»
    case mesomorph = "mesomorph" // Мезоморф / «Атлетический»
    case endomorph = "endomorph" // Эндоморф / «Плотный»
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .ectomorph: return "Эктоморф (Хардгейнер)"
        case .mesomorph: return "Мезоморф (Атлетический)"
        case .endomorph: return "Эндоморф (Плотный)"
        }
    }
    
    public var shortTitle: String {
        switch self {
        case .ectomorph: return "Эктоморф"
        case .mesomorph: return "Мезоморф"
        case .endomorph: return "Эндоморф"
        }
    }
    
    public var emoji: String {
        switch self {
        case .ectomorph: return "⚡️"
        case .mesomorph: return "🦾"
        case .endomorph: return "🛡️"
        }
    }
    
    public var accentColor: Color {
        switch self {
        case .ectomorph: return Color(red: 0/255, green: 229/255, blue: 255/255) // Электрический голубой
        case .mesomorph: return Color(red: 50/255, green: 215/255, blue: 75/255)  // Атлетический зеленый
        case .endomorph: return Color(red: 255/255, green: 159/255, blue: 10/255) // Плотный янтарный
        }
    }
    
    /// Физиологическое описание для пользователя
    public var shortDescription: String {
        switch self {
        case .ectomorph:
            return "Быстрый обмен веществ, высокий NEAT-термогенез, тонкая кость. Сжигает калории на лету, вес и мышцы набираются с большим трудом."
        case .mesomorph:
            return "Сбалансированный и гибкий метаболизм, атлетический костяк, быстрый отклик на силовые нагрузки. Легко регулирует процент жира и мышечную массу."
        case .endomorph:
            return "Экономный и замедленный обмен, широкая кость, чувствительность к инсулину. Склонность к быстрому запасанию жира даже при умеренном рационе."
        }
    }
    
    /// Корректирующий коэффициент базового метаболизма (BMR) к формуле Миффлина-Сан Жеора
    public var metabolismMultiplier: Double {
        switch self {
        case .ectomorph: return 1.12 // +12% к базовому расходу из-за высокого NEAT и разобщения окисления
        case .mesomorph: return 1.00 // Базовая стандартная норма
        case .endomorph: return 0.92 // -8% к BMR из-за высокой метаболической экономичности
        }
    }
    
    /// Рекомендованное распределение макронутриентов (Углеводы / Белки / Жиры в процентах)
    public var recommendedMacros: (carbs: Int, protein: Int, fat: Int) {
        switch self {
        case .ectomorph: return (carbs: 55, protein: 25, fat: 20) // Углеводный акцент для защиты мышц
        case .mesomorph: return (carbs: 40, protein: 30, fat: 30) // Классический атлетический баланс
        case .endomorph: return (carbs: 25, protein: 40, fat: 35) // Контроль инсулина, акцент на белок и клетчатку
        }
    }
    
    /// Стратегия питания для ИИ-тренера
    public var nutritionStrategyPrompt: String {
        switch self {
        case .ectomorph:
            return "Эктоморф (быстрый обмен, хардгейнер). Рекомендации: профицит калорий (+300..500 ккал), плотные сложные углеводы (гречка, рис, овсянка, паста), полезные калорийные перекусы (орехи, бананы, арахисовая паста), углеводы перед сном для защиты от ночного катаболизма."
        case .mesomorph:
            return "Мезоморф (сбалансированный обмен). Рекомендации: умеренный дефицит или профицит в зависимости от цели, классическое БЖУ 40/30/30, тайминг нутриентов вокруг тренировок."
        case .endomorph:
            return "Эндоморф (медленный/экономный обмен, чувствительность к углеводам). Рекомендации: строгий контроль калорийности, перенос углеводов строго вокруг тренировки, упор на белок (мясо, птица, рыба, творог), зеленые овощи и полезные жиры, минимизация сахара и быстрых углеводов."
        }
    }
    
    /// Стратегия тренировок для ИИ-тренера
    public var trainingStrategyPrompt: String {
        switch self {
        case .ectomorph:
            return "Базовые многосуставные силовые упражнения, рабочий диапазон 6-10 повторений, отдых между сетами 2-3 минуты. Минимизировать изнуряющее длительное кардио (оно быстро пережигает мышцы)."
        case .mesomorph:
            return "Смешанный прогрессивный силовой тренинг (8-12 повторов), суперсеты, умеренное кардио 2-3 раза в неделю для поддержания рельефа."
        case .endomorph:
            return "Высокая плотность тренировки: суперсеты, круговой и функциональный тренинг (12-15 повторений), короткий отдых (45-60 сек), регулярные кардио-сессии и интервальный тренинг (HIIT) для разгона метаболизма."
        }
    }
}

/// Субъективная скорость метаболизма
public enum MetabolismSpeed: String, CaseIterable, Identifiable, Codable {
    case fast = "fast"
    case normal = "normal"
    case slow = "slow"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .fast: return "Быстрый (ем много, вес не растет)"
        case .normal: return "Сбалансированный (норма)"
        case .slow: return "Замедленный (легко поправляюсь)"
        }
    }
    
    public var shortTitle: String {
        switch self {
        case .fast: return "Быстрый ⚡️"
        case .normal: return "Норма ⚖️"
        case .slow: return "Экономный 🛡️"
        }
    }
}

/// Интерактивный лист самодиагностики соматотипа
public struct SomatotypeQuizSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding public var userSomatotype: String
    @Binding public var userMetabolismSpeed: String
    
    @State private var selectedWristOption: Int? = nil
    @State private var selectedCarbOption: Int? = nil
    @State private var selectedTeenOption: Int? = nil
    
    // Результат расчета
    private var calculatedSomatotype: Somatotype? {
        guard let w = selectedWristOption, let c = selectedCarbOption, let t = selectedTeenOption else {
            return nil
        }
        let score = w + c + t // 3..9
        if score <= 4 {
            return .ectomorph
        } else if score <= 6 {
            return .mesomorph
        } else {
            return .endomorph
        }
    }
    
    private var calculatedMetabolism: MetabolismSpeed? {
        guard let c = selectedCarbOption else { return nil }
        if c == 1 { return .fast }
        if c == 2 { return .normal }
        return .slow
    }
    
    public init(userSomatotype: Binding<String>, userMetabolismSpeed: Binding<String>) {
        self._userSomatotype = userSomatotype
        self._userMetabolismSpeed = userMetabolismSpeed
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Заголовок и пояснение
                    VStack(spacing: 8) {
                        Image(systemName: "figure.walk.motion")
                            .font(.system(size: 40))
                            .foregroundColor(Theme.exerciseColor)
                        
                        Text("Определи свой соматотип")
                            .font(.title2.bold())
                            .foregroundColor(Theme.textPrimary)
                        
                        Text("Ответь на 3 физиологических вопроса, чтобы ИИ откалибровал расход калорий и стратегию питания под твой организм.")
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .foregroundColor(Theme.textSecondary)
                            .padding(.horizontal)
                    }
                    .padding(.top, 12)
                    
                    // Вопрос 1: Запястье
                    VStack(alignment: .leading, spacing: 12) {
                        Text("1. Обхватите запястье ведущей руки большим и средним пальцами другой руки:")
                            .font(.subheadline.bold())
                            .foregroundColor(Theme.textPrimary)
                        
                        quizOptionButton(
                            title: "Пальцы легко перекрывают друг друга",
                            subtitle: "Тонкий костяк, обхват запястья < 16 см",
                            isSelected: selectedWristOption == 1
                        ) {
                            selectedWristOption = 1
                            HapticManager.shared.selection()
                        }
                        
                        quizOptionButton(
                            title: "Пальцы касаются кончиками",
                            subtitle: "Средняя костная структура, обхват 16-19 см",
                            isSelected: selectedWristOption == 2
                        ) {
                            selectedWristOption = 2
                            HapticManager.shared.selection()
                        }
                        
                        quizOptionButton(
                            title: "Пальцы не достают друг до друга",
                            subtitle: "Широкий мощный костяк, обхват > 19 см",
                            isSelected: selectedWristOption == 3
                        ) {
                            selectedWristOption = 3
                            HapticManager.shared.selection()
                        }
                    }
                    .padding()
                    .background(Theme.cardBackground)
                    .cornerRadius(18)
                    
                    // Вопрос 2: Реакция на углеводы
                    VStack(alignment: .leading, spacing: 12) {
                        Text("2. Как ваш организм реагирует на обильные углеводы и переедание?")
                            .font(.subheadline.bold())
                            .foregroundColor(Theme.textPrimary)
                        
                        quizOptionButton(
                            title: "Вес не растет, чувствую жар и прилив энергии",
                            subtitle: "Быстрое сжигание калорий, высокий NEAT-термогенез",
                            isSelected: selectedCarbOption == 1
                        ) {
                            selectedCarbOption = 1
                            HapticManager.shared.selection()
                        }
                        
                        quizOptionButton(
                            title: "Вес стабилен, мышцы становятся плотнее",
                            subtitle: "Сбалансированное распределение в гликоген и мышцы",
                            isSelected: selectedCarbOption == 2
                        ) {
                            selectedCarbOption = 2
                            HapticManager.shared.selection()
                        }
                        
                        quizOptionButton(
                            title: "Мгновенно появляется отечность и откладывается жир",
                            subtitle: "Высокая чувствительность к инсулину, экономный обмен",
                            isSelected: selectedCarbOption == 3
                        ) {
                            selectedCarbOption = 3
                            HapticManager.shared.selection()
                        }
                    }
                    .padding()
                    .background(Theme.cardBackground)
                    .cornerRadius(18)
                    
                    // Вопрос 3: Подростковый возраст
                    VStack(alignment: .leading, spacing: 12) {
                        Text("3. Каким было ваше телосложение в возрасте 16–18 лет?")
                            .font(.subheadline.bold())
                            .foregroundColor(Theme.textPrimary)
                        
                        quizOptionButton(
                            title: "Худощавое, узкие плечи, трудно было набрать вес",
                            subtitle: "Естественная склонность к худобе",
                            isSelected: selectedTeenOption == 1
                        ) {
                            selectedTeenOption = 1
                            HapticManager.shared.selection()
                        }
                        
                        quizOptionButton(
                            title: "Атлетичное, спортивное, V-образная фигура",
                            subtitle: "Легко появлялся рельеф при базовых тренировках",
                            isSelected: selectedTeenOption == 2
                        ) {
                            selectedTeenOption = 2
                            HapticManager.shared.selection()
                        }
                        
                        quizOptionButton(
                            title: "Плотное, коренастое, широкая талия",
                            subtitle: "Легко набирались лишние килограммы при отсутствии спорта",
                            isSelected: selectedTeenOption == 3
                        ) {
                            selectedTeenOption = 3
                            HapticManager.shared.selection()
                        }
                    }
                    .padding()
                    .background(Theme.cardBackground)
                    .cornerRadius(18)
                    
                    // Итоговый вердикт
                    if let result = calculatedSomatotype, let metabolism = calculatedMetabolism {
                        VStack(spacing: 12) {
                            HStack {
                                Text(result.emoji)
                                    .font(.system(size: 32))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Ваш соматотип:")
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                    Text(result.title)
                                        .font(.headline.bold())
                                        .foregroundColor(result.accentColor)
                                }
                                Spacer()
                            }
                            
                            Text(result.shortDescription)
                                .font(.footnote)
                                .foregroundColor(Theme.textPrimary)
                                .lineSpacing(2)
                            
                            HStack {
                                Text("Метаболизм: \(metabolism.title)")
                                    .font(.caption2.bold())
                                    .foregroundColor(Theme.textSecondary)
                                Spacer()
                            }
                            
                            Button(action: {
                                userSomatotype = result.rawValue
                                userMetabolismSpeed = metabolism.rawValue
                                HapticManager.shared.notification(.success)
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Применить к профилю и обучить ИИ")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(result.accentColor)
                                .cornerRadius(14)
                            }
                            .padding(.top, 4)
                        }
                        .padding()
                        .background(result.accentColor.opacity(0.1))
                        .cornerRadius(18)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(result.accentColor, lineWidth: 1.5)
                        )
                    }
                }
                .padding()
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Тест соматотипа")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                    .foregroundColor(Theme.textSecondary)
                }
            }
        }
    }
    
    private func quizOptionButton(title: String, subtitle: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? Theme.exerciseColor : Theme.textSecondary.opacity(0.5))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundColor(isSelected ? Theme.exerciseColor : Theme.textPrimary)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer()
            }
            .padding(12)
            .background(isSelected ? Theme.exerciseColor.opacity(0.08) : Color.primary.opacity(0.03))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Theme.exerciseColor : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
