import SwiftUI

struct HabitsView: View {
    @EnvironmentObject var health: HealthKitManager
    @State private var habits = [
        Habit(name: "Пить воду регулярно", isCompleted: false, icon: "drop.fill", color: Theme.waterColor),
        Habit(name: "Пройти 10 000 шагов", isCompleted: false, icon: "figure.walk", color: .orange),
        Habit(name: "Лечь спать до 23:00", isCompleted: false, icon: "moon.stars.fill", color: Theme.sleepColor),
        Habit(name: "Сделать разминку", isCompleted: false, icon: "figure.stretch", color: Theme.exerciseColor)
    ]
    
    struct Habit: Identifiable {
        let id = UUID()
        let name: String
        var isCompleted: Bool
        let icon: String
        let color: Color
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                HStack {
                    Text("Привычки")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                VStack(spacing: 16) {
                    ForEach(habits.indices, id: \.self) { index in
                        Button(action: {
                            habits[index].isCompleted.toggle()
                        }) {
                            HStack(spacing: 16) {
                                Image(systemName: habits[index].icon)
                                    .foregroundColor(habits[index].color)
                                    .font(.title3)
                                    .frame(width: 40, height: 40)
                                    .background(habits[index].color.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                
                                Text(habits[index].name)
                                    .foregroundColor(.white)
                                    .font(.body)
                                    .bold()
                                
                                Spacer()
                                
                                Image(systemName: habits[index].isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(habits[index].isCompleted ? .green : .gray)
                                    .font(.title3)
                            }
                            .padding()
                            .premiumCard()
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}
