import SwiftUI

// MARK: - Экран медицинских источников и научных исследований (App Store Guideline 1.4.1)
public struct MedicalSourcesAndCitationsView: View {
    @Environment(\.dismiss) private var dismiss
    
    public init() { }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // Шапка с дисклеймером
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.15))
                                    .frame(width: 64, height: 64)
                                Image(systemName: "cross.case.fill")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.blue)
                            }
                            
                            Text("Научная методология\nи источники")
                                .font(.system(size: 24, weight: .heavy, design: .rounded))
                                .multilineTextAlignment(.center)
                                .foregroundColor(Theme.textPrimary)
                            
                            Text("Все алгоритмы расчетов, нормы активности, гидратации и восстановления в Forma базируются на признанных международных исследованиях и рекомендациях организаций здравоохранения.")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                        }
                        .padding(.top, 10)
                        
                        // Важный медицинский дисклеймер
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Медицинский дисклеймер")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Theme.textPrimary)
                                Text("Приложение Forma не является медицинским изделием и не ставит диагнозы. Данные пульса, шагов и сатурации считываются из сертифицированных сенсоров Apple Watch через Apple HealthKit. Всегда консультируйтесь с квалифицированным врачом перед изменением диеты или началом тренировок.")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.textSecondary)
                                    .lineSpacing(2)
                            }
                        }
                        .padding(14)
                        .background(Color.orange.opacity(0.08))
                        .cornerRadius(14)
                        .padding(.horizontal, 20)
                        
                        // Секции с научными источниками
                        VStack(spacing: 16) {
                            
                            // 1. HRV и Восстановление
                            CitationCategoryCard(
                                title: "Вариабельность пульса (HRV) и Восстановление",
                                icon: "waveform.path.ecg",
                                iconColor: Theme.pulseColor,
                                citations: [
                                    CitationItem(
                                        title: "Стандарты измерения и физиологической интерпретации HRV",
                                        authors: "Task Force of the European Society of Cardiology & NASPE",
                                        journal: "Circulation / PubMed (1996)",
                                        url: "https://pubmed.ncbi.nlm.nih.gov/8598068/"
                                    ),
                                    CitationItem(
                                        title: "Обзор метрик вариабельности ритма (rMSSD, SDNN) для оценки стресса",
                                        authors: "Shaffer F., Ginsberg J. P.",
                                        journal: "Frontiers in Public Health (2017)",
                                        url: "https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5624990/"
                                    )
                                ]
                            )
                            
                            // 2. Кардиовыносливость (VO2 Max)
                            CitationCategoryCard(
                                title: "Кардиовыносливость (VO2 Max) и Зоны пульса",
                                icon: "figure.run",
                                iconColor: Theme.exerciseColor,
                                citations: [
                                    CitationItem(
                                        title: "Важность кардиореспираторной выносливости для здоровья",
                                        authors: "American Heart Association (AHA)",
                                        journal: "Circulation Scientific Statement",
                                        url: "https://www.ahajournals.org/doi/10.1161/CIR.0000000000000461"
                                    ),
                                    CitationItem(
                                        title: "Руководство по тестированию и назначению физических нагрузок",
                                        authors: "American College of Sports Medicine (ACSM)",
                                        journal: "ACSM Guidelines (11th Edition)",
                                        url: "https://www.acsm.org/"
                                    )
                                ]
                            )
                            
                            // 3. Гидратация и Кинетика кофеина
                            CitationCategoryCard(
                                title: "Гидратация и Кинетика выведения кофеина",
                                icon: "drop.fill",
                                iconColor: Color(red: 0/255, green: 229/255, blue: 255/255),
                                citations: [
                                    CitationItem(
                                        title: "Научное заключение о безопасности и фармакокинетике кофеина",
                                        authors: "European Food Safety Authority (EFSA)",
                                        journal: "EFSA Journal (2015)",
                                        url: "https://www.efsa.europa.eu/en/efsajournal/pub/4102"
                                    ),
                                    CitationItem(
                                        title: "Нормы суточного потребления воды и электролитов",
                                        authors: "National Academy of Medicine (NAM / IOM)",
                                        journal: "Dietary Reference Intakes for Water",
                                        url: "https://nap.nationalacademies.org/read/10925/"
                                    )
                                ]
                            )
                            
                            // 4. Базовый метаболизм и КБЖУ
                            CitationCategoryCard(
                                title: "Базовый метаболизм (BMR / TDEE) и КБЖУ",
                                icon: "flame.fill",
                                iconColor: .orange,
                                citations: [
                                    CitationItem(
                                        title: "Новая формула расчета расхода энергии в покое (Mifflin-St Jeor)",
                                        authors: "Mifflin M. D., St Jeor S. T. et al.",
                                        journal: "The American Journal of Clinical Nutrition (1990)",
                                        url: "https://pubmed.ncbi.nlm.nih.gov/2305711/"
                                    ),
                                    CitationItem(
                                        title: "Глобальные рекомендации по здоровому питанию и балансу макронутриентов",
                                        authors: "World Health Organization (WHO)",
                                        journal: "WHO Healthy Diet Fact Sheet No. 394",
                                        url: "https://www.who.int/news-room/fact-sheets/detail/healthy-diet"
                                    )
                                ]
                            )
                            
                            // 5. Физическая активность и силовые нагрузки
                            CitationCategoryCard(
                                title: "Физическая активность и Силовые нагрузки (ВОЗ)",
                                icon: "figure.run",
                                iconColor: Theme.exerciseColor,
                                citations: [
                                    CitationItem(
                                        title: "Глобальные рекомендации ВОЗ по физической активности и сидячему образу жизни",
                                        authors: "World Health Organization (WHO)",
                                        journal: "WHO Guidelines on Physical Activity (2020, 150-300 min/week)",
                                        url: "https://www.who.int/publications/i/item/9789240015128"
                                    )
                                ]
                            )
                            
                            // 6. Индекс массы тела (ИМТ)
                            CitationCategoryCard(
                                title: "Индекс массы тела (ИМТ) и Состав тела",
                                icon: "figure.arms.open",
                                iconColor: .green,
                                citations: [
                                    CitationItem(
                                        title: "Предупреждение и ведение глобальной эпидемии ожирения: Классификация ИМТ",
                                        authors: "World Health Organization (WHO)",
                                        journal: "WHO Technical Report Series 894 (TRS 894)",
                                        url: "https://www.who.int/publications/i/item/9241208945"
                                    )
                                ]
                            )
                            
                            // 7. Контроль сахара и натрия (соли)
                            CitationCategoryCard(
                                title: "Контроль свободных сахаров и соли (ВОЗ)",
                                icon: "cube.fill",
                                iconColor: .purple,
                                citations: [
                                    CitationItem(
                                        title: "Руководство ВОЗ: Потребление свободных сахаров взрослыми и детьми (<10% ккал)",
                                        authors: "World Health Organization (WHO)",
                                        journal: "WHO Guideline: Sugars intake (2015)",
                                        url: "https://www.who.int/publications/i/item/9789241549028"
                                    ),
                                    CitationItem(
                                        title: "Руководство ВОЗ: Потребление натрия для взрослых и детей (<2 г натрия = 5 г соли)",
                                        authors: "World Health Organization (WHO)",
                                        journal: "WHO Guideline: Sodium intake (2012)",
                                        url: "https://www.who.int/publications/i/item/9789241504836"
                                    )
                                ]
                            )
                            
                            // 8. Пульс в покое и здоровье сердца
                            CitationCategoryCard(
                                title: "Пульс в покое и Сердечно-сосудистое здоровье",
                                icon: "waveform.path.ecg.rectangle.fill",
                                iconColor: Theme.pulseColor,
                                citations: [
                                    CitationItem(
                                        title: "Глобальное руководство по профилактике сердечно-сосудистых заболеваний",
                                        authors: "World Health Organization (WHO) & ISH",
                                        journal: "WHO CVD Prevention Guidelines (60-100 bpm RHR norm)",
                                        url: "https://www.who.int/publications/i/item/9789241541435"
                                    )
                                ]
                            )
                        }
                        .padding(.horizontal, 20)
                        
                        // Ссылка на полную политику
                        Link(destination: URL(string: "https://samjan190799-cmyk.github.io/SamHealth/privacy.html")!) {
                            HStack(spacing: 6) {
                                Text("Открыть Политику конфиденциальности онлайн")
                                Image(systemName: "arrow.up.right")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.accent)
                        }
                        .padding(.vertical, 16)
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Источники и ссылки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.accent)
                }
            }
        }
    }
}

// MARK: - Вспомогательные компоненты
private struct CitationCategoryCard: View {
    let title: String
    let icon: String
    let iconColor: Color
    let citations: [CitationItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerView
            citationsList
        }
        .padding(14)
        .background(Theme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
    
    private var headerView: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(iconColor)
            }
            
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Theme.textPrimary)
        }
    }
    
    private var citationsList: some View {
        VStack(spacing: 10) {
            ForEach(citations) { item in
                citationRow(item)
            }
        }
    }
    
    @ViewBuilder
    private func citationRow(_ item: CitationItem) -> some View {
        if let url = URL(string: item.url) {
            Link(destination: url) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.textPrimary)
                            .multilineTextAlignment(.leading)
                        
                        Text("\(item.authors) • \(item.journal)")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.accent)
                }
                .padding(10)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(10)
            }
        }
    }
}

private struct CitationItem: Identifiable {
    let id = UUID()
    let title: String
    let authors: String
    let journal: String
    let url: String
}
