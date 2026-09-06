import SwiftUI

/// Модель готового предустановленного супа или бульона
public struct SoupBrothPreset: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let emoji: String
    public let defaultWeight: Double
    public let caloriesPer100g: Double
    public let proteinPer100g: Double
    public let fatPer100g: Double
    public let carbsPer100g: Double
    public let gastroBenefit: String
    public let tag: String
    public let accentColor: Color
    
    public var defaultCalories: Double { (caloriesPer100g * defaultWeight) / 100.0 }
    public var defaultProtein: Double { (proteinPer100g * defaultWeight) / 100.0 }
    public var defaultFat: Double { (fatPer100g * defaultWeight) / 100.0 }
    public var defaultCarbs: Double { (carbsPer100g * defaultWeight) / 100.0 }
}

public struct QuickSoupBrothSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (LoggedMealRecord) -> Void
    
    @State private var selectedPreset: SoupBrothPreset? = nil
    @State private var selectedCategory: MealCategory = .lunch
    @State private var portionWeight: Double = 300.0
    
    public static let presets: [SoupBrothPreset] = [
        SoupBrothPreset(
            id: "chicken_broth",
            name: "Куриный бульон с зеленью",
            emoji: "🍲",
            defaultWeight: 300,
            caloriesPer100g: 40,
            proteinPer100g: 4.8,
            fatPer100g: 2.0,
            carbsPer100g: 0.7,
            gastroBenefit: "Легко усваивается, быстро восстанавливает водно-солевой баланс и снабжает природным белком.",
            tag: "Классический",
            accentColor: .orange
        ),
        SoupBrothPreset(
            id: "bone_broth",
            name: "Костный бульон с коллагеном",
            emoji: "🥣",
            defaultWeight: 300,
            caloriesPer100g: 32,
            proteinPer100g: 6.0,
            fatPer100g: 1.0,
            carbsPer100g: 0.0,
            gastroBenefit: "Богат природным коллагеном, глутамином и аминокислотами. Сытный и питательный выбор.",
            tag: "Коллаген",
            accentColor: Color(red: 0/255, green: 229/255, blue: 255/255)
        ),
        SoupBrothPreset(
            id: "pumpkin_soup",
            name: "Тыквенный крем-суп",
            emoji: "🎃",
            defaultWeight: 300,
            caloriesPer100g: 58,
            proteinPer100g: 1.5,
            fatPer100g: 2.7,
            carbsPer100g: 7.3,
            gastroBenefit: "Нежная кремовая текстура, растворимая клетчатка и бета-каротин для мягкого насыщения.",
            tag: "Клетчатка",
            accentColor: .yellow
        ),
        SoupBrothPreset(
            id: "broccoli_soup",
            name: "Крем-суп из брокколи и цукини",
            emoji: "🥦",
            defaultWeight: 300,
            caloriesPer100g: 44,
            proteinPer100g: 2.0,
            fatPer100g: 1.7,
            carbsPer100g: 5.3,
            gastroBenefit: "Хлорофилл, витамины и антиоксиданты. Легкое овощное блюдо для свежести и баланса рациона.",
            tag: "Овощной",
            accentColor: .green
        ),
        SoupBrothPreset(
            id: "fish_soup",
            name: "Легкая уха из лосося и трески",
            emoji: "🐟",
            defaultWeight: 350,
            caloriesPer100g: 54,
            proteinPer100g: 6.3,
            fatPer100g: 2.3,
            carbsPer100g: 2.3,
            gastroBenefit: "Прозрачный рыбный бульон с полиненасыщенными омега-3 жирными кислотами.",
            tag: "Омега-3",
            accentColor: Color(red: 0/255, green: 145/255, blue: 255/255)
        ),
        SoupBrothPreset(
            id: "miso_soup",
            name: "Мисо-суп с тофу и вакаме",
            emoji: "🍜",
            defaultWeight: 280,
            caloriesPer100g: 30,
            proteinPer100g: 2.8,
            fatPer100g: 1.1,
            carbsPer100g: 2.5,
            gastroBenefit: "Ферментированная паста мисо обогащает микробиоту пробиотиками и ферментами, помогая расщеплять тяжелую пищу.",
            tag: "Пробиотики",
            accentColor: Color(red: 255/255, green: 180/255, blue: 0/255)
        ),
        SoupBrothPreset(
            id: "borscht",
            name: "Домашний борщ со свеклой",
            emoji: "🍲",
            defaultWeight: 350,
            caloriesPer100g: 65,
            proteinPer100g: 4.5,
            fatPer100g: 2.8,
            carbsPer100g: 5.7,
            gastroBenefit: "Бетаин свеклы активирует отток желчи и моторику кишечника, мягко предотвращая запоры после сухомятки.",
            tag: "Перистальтика",
            accentColor: Color(red: 255/255, green: 69/255, blue: 58/255)
        ),
        SoupBrothPreset(
            id: "minestrone",
            name: "Овощной суп минестроне",
            emoji: "🍅",
            defaultWeight: 320,
            caloriesPer100g: 45,
            proteinPer100g: 1.6,
            fatPer100g: 1.2,
            carbsPer100g: 6.9,
            gastroBenefit: "Богат калием и растворимой клетчаткой. Прекрасный выбор для гидробаланса и мягкого насыщения.",
            tag: "Баланс калия",
            accentColor: .teal
        )
    ]
    
    public init(onSelect: @escaping (LoggedMealRecord) -> Void) {
        self.onSelect = onSelect
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 18) {
                        // Верхний информационный баннер о пользе жидкой пищи
                        headerInfoCard
                        
                        // Список супов и бульонов
                        VStack(spacing: 12) {
                            ForEach(Self.presets) { preset in
                                soupPresetCard(preset)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .padding(.bottom, 60)
                }
            }
            .navigationTitle("Супы и бульоны")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                    .foregroundColor(Theme.textPrimary)
                }
            }
            .sheet(item: $selectedPreset) { preset in
                portionAdjustmentSheet(for: preset)
            }
        }
    }
    
    // Верхняя карточка с объяснением роли супов
    private var headerInfoCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 26))
                .foregroundColor(Color(red: 0/255, green: 210/255, blue: 255/255))
                .padding(10)
                .background(Color(red: 0/255, green: 210/255, blue: 255/255).opacity(0.15))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Польза первого блюда в рационе")
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(Theme.textPrimary)
                
                Text("Горячие супы и легкие бульоны поддерживают оптимальный водный баланс, согревают, комфортно насыщают и помогают разнообразить повседневный рацион.")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                    .lineSpacing(3)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color(red: 0/255, green: 210/255, blue: 255/255).opacity(0.2), lineWidth: 1)
        )
    }
    
    // Карточка супа
    private func soupPresetCard(_ preset: SoupBrothPreset) -> some View {
        Button(action: {
            selectedPreset = preset
            portionWeight = preset.defaultWeight
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
        }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Text(preset.emoji)
                        .font(.system(size: 32))
                        .padding(8)
                        .background(preset.accentColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(preset.name)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(Theme.textPrimary)
                                .multilineTextAlignment(.leading)
                            
                            Spacer()
                            
                            Text(preset.tag)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(preset.accentColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(preset.accentColor.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        
                        Text("\(Int(preset.defaultWeight)) г • \(Int(preset.defaultCalories)) ккал (Б:\(Int(preset.defaultProtein))г, Ж:\(Int(preset.defaultFat))г, У:\(Int(preset.defaultCarbs))г)")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                
                Text(preset.gastroBenefit)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textPrimary.opacity(0.85))
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)
                
                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Text("Выбрать порцию")
                            .font(.system(size: 12, weight: .bold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(preset.accentColor)
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }
    
    // Модальный лист уточнения порции перед добавлением
    private func portionAdjustmentSheet(for preset: SoupBrothPreset) -> some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text(preset.emoji)
                            .font(.system(size: 54))
                        Text(preset.name)
                            .font(.title3)
                            .bold()
                            .foregroundColor(Theme.textPrimary)
                        Text(preset.gastroBenefit)
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 16)
                    
                    // Выбор категории приема пищи
                    Picker("Прием пищи", selection: $selectedCategory) {
                        ForEach(MealCategory.allCases) { cat in
                            Text("\(cat.emoji) \(cat.title)").tag(cat)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Степпер веса
                    let ratio = portionWeight / 100.0
                    let cals = preset.caloriesPer100g * ratio
                    let prot = preset.proteinPer100g * ratio
                    let fat = preset.fatPer100g * ratio
                    let carbs = preset.carbsPer100g * ratio
                    
                    VStack(spacing: 16) {
                        HStack {
                            Text("Вес порции:")
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                            Stepper(value: $portionWeight, in: 100...1000, step: 50) {
                                Text("\(Int(portionWeight)) г")
                                    .font(.title3)
                                    .bold()
                                    .foregroundColor(Theme.textPrimary)
                            }
                        }
                        
                        Divider()
                        
                        HStack(spacing: 16) {
                            macroNutrientBox(title: "Калории", value: "\(Int(cals)) ккал", color: Theme.pulseColor)
                            macroNutrientBox(title: "Белки", value: "\(Int(prot)) г", color: .green)
                            macroNutrientBox(title: "Жиры", value: "\(Int(fat)) г", color: .orange)
                            macroNutrientBox(title: "Углеводы", value: "\(Int(carbs)) г", color: .blue)
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(18)
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    Button(action: {
                        let record = LoggedMealRecord(
                            name: preset.name,
                            calories: cals,
                            protein: prot,
                            fat: fat,
                            carbs: carbs,
                            weightGrams: portionWeight,
                            category: selectedCategory,
                            date: Date(),
                            emoji: preset.emoji,
                            textureType: .liquidSoup
                        )
                        onSelect(record)
                        selectedPreset = nil
                        dismiss()
                        
                        let success = UINotificationFeedbackGenerator()
                        success.notificationOccurred(.success)
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                            Text("Добавить суп в дневник (\(Int(cals)) ккал)")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0/255, green: 210/255, blue: 255/255), Color(red: 0/255, green: 145/255, blue: 255/255)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(18)
                        .shadow(color: Color(red: 0/255, green: 210/255, blue: 255/255).opacity(0.3), radius: 8)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle("Порция супа")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        selectedPreset = nil
                    }
                    .foregroundColor(Theme.textPrimary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private func macroNutrientBox(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}
