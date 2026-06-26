import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var health: HealthKitManager
    @State private var showingScanner = false
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            if !health.isRequested {
                // Экран запроса прав (Onboarding)
                VStack(spacing: 24) {
                    Spacer()
                    
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 80))
                        .foregroundColor(Theme.pulseColor)
                        .neonShadow(color: Theme.pulseColor, radius: 12)
                    
                    Text("Добро пожаловать в SamHealth")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("Для работы дашборда нам необходим доступ к вашим данным HealthKit. Все данные хранятся локально на вашем устройстве.")
                        .font(.body)
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    Spacer()
                    
                    Button(action: {
                        health.requestAuthorization()
                    }) {
                        Text("Предоставить доступ")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.white.opacity(0.3), radius: 8)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                }
            } else {
                // Основной Дашборд
                ScrollView {
                    VStack(spacing: 20) {
                        // Заголовок
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Самвел")
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                                Text("Твой дашборд здоровья")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            Spacer()
                            
                            // Кнопка ИИ-Сканера
                            Button(action: {
                                showingScanner = true
                            }) {
                                Image(systemName: "camera.macro")
                                    .font(.title2)
                                    .foregroundColor(.black)
                                    .padding(12)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .shadow(color: Color.white.opacity(0.3), radius: 8)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        
                        if let error = health.authorizationError {
                            // Ошибка авторизации
                            VStack(spacing: 8) {
                                Text("Доступ к HealthKit ограничен")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            .premiumCard()
                            .padding(.horizontal)
                        }
                        
                        // 1. Кольца активности
                        HStack(spacing: 24) {
                            ActivityRingsGroup(
                                moveProgress: health.activeEnergyGoal > 0 ? health.activeEnergyBurned / health.activeEnergyGoal : 0,
                                exerciseProgress: health.exerciseGoal > 0 ? health.exerciseTime / health.exerciseGoal : 0,
                                standProgress: health.standGoal > 0 ? health.standHours / health.standGoal : 0
                            )
                            
                            VStack(alignment: .leading, spacing: 12) {
                                ActivityTextValue(
                                    title: "Подвижность",
                                    value: "\(Int(health.activeEnergyBurned)) / \(Int(health.activeEnergyGoal)) ккал",
                                    color: Theme.moveColor
                                )
                                ActivityTextValue(
                                    title: "Упражнения",
                                    value: "\(Int(health.exerciseTime)) / \(Int(health.exerciseGoal)) мин",
                                    color: Theme.exerciseColor
                                )
                                ActivityTextValue(
                                    title: "Разминка",
                                    value: "\(Int(health.standHours)) / \(Int(health.standGoal)) ч",
                                    color: Theme.standColor
                                )
                            }
                            Spacer()
                        }
                        .premiumCard()
                        .padding(.horizontal)
                        
                        // 2. Шаги за неделю
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "figure.walk")
                                    .foregroundColor(.orange)
                                Text("Шаги за неделю")
                                    .font(.headline)
                                    .foregroundColor(Theme.textPrimary)
                                Spacer()
                                Text("\(health.stepsToday) сегодня")
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                                    .bold()
                            }
                            
                            if health.weeklySteps.isEmpty {
                                Text("Нет данных о шагах за неделю")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 20)
                            } else {
                                HStack(alignment: .bottom, spacing: 12) {
                                    ForEach(health.weeklySteps) { dayData in
                                        VStack(spacing: 8) {
                                            GeometryReader { geometry in
                                                VStack {
                                                    Spacer()
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .fill(dayData.steps >= 10000 ? Color.green : Color.orange)
                                                        .frame(height: max(CGFloat(dayData.steps) / 15000 * geometry.size.height, 4))
                                                }
                                            }
                                            .frame(height: 100)
                                            
                                            Text(dayData.day)
                                                .font(.caption2)
                                                .foregroundColor(Theme.textSecondary)
                                        }
                                    }
                                }
                                .frame(height: 120)
                            }
                        }
                        .premiumCard()
                        .padding(.horizontal)
                        
                        // 3. Пульс и Сон
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "heart.fill")
                                        .foregroundColor(Theme.pulseColor)
                                    Text("Пульс")
                                        .font(.headline)
                                        .foregroundColor(Theme.textPrimary)
                                }
                                Spacer()
                                Text(health.heartRate > 0 ? "\(health.heartRate)" : "--")
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                                + Text(" уд/мин")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
                            .premiumCard()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "bed.double.fill")
                                        .foregroundColor(Theme.sleepColor)
                                    Text("Сон")
                                        .font(.headline)
                                        .foregroundColor(Theme.textPrimary)
                                }
                                Spacer()
                                Text(health.sleepDuration > 0 ? String(format: "%.1f", health.sleepDuration) : "--")
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                                + Text(" ч")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
                            .premiumCard()
                        }
                        .padding(.horizontal)
                        
                        // 4. Вода
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "drop.fill")
                                    .foregroundColor(Theme.waterColor)
                                Text("Водный баланс")
                                    .font(.headline)
                                    .foregroundColor(Theme.textPrimary)
                                Spacer()
                                Text("\(Int(health.waterConsumed)) / \(Int(health.waterGoal)) мл")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.waterColor)
                                    .bold()
                            }
                            
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.white.opacity(0.1))
                                        .frame(height: 12)
                                    
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Theme.waterColor)
                                        .frame(width: min(CGFloat(health.waterConsumed / health.waterGoal) * geo.size.width, geo.size.width), height: 12)
                                        .neonShadow(color: Theme.waterColor, radius: 4)
                                }
                            }
                            .frame(height: 12)
                            .padding(.vertical, 4)
                            
                            HStack(spacing: 12) {
                                Button(action: {
                                    health.addWater(amount: 250)
                                }) {
                                    HStack {
                                        Image(systemName: "plus")
                                        Text("250 мл")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(10)
                                }
                                
                                Button(action: {
                                    health.addWater(amount: 500)
                                }) {
                                    HStack {
                                        Image(systemName: "plus")
                                        Text("500 мл")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(10)
                                }
                            }
                        }
                        .premiumCard()
                        .padding(.horizontal)
                        
                        // 5. Динамика Веса
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "scalemass.fill")
                                        .foregroundColor(Theme.weightColor)
                                    Text("Вес")
                                        .font(.headline)
                                        .foregroundColor(Theme.textPrimary)
                                }
                                Text(health.currentWeight > 0 ? String(format: "%.1f кг", health.currentWeight) : "-- кг")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: health.weightTrend.arrow)
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(health.weightTrend.color)
                                .padding(12)
                                .background(health.weightTrend.color.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .premiumCard()
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
                .refreshable {
                    health.fetchAllData()
                }
            }
        }
        .sheet(isPresented: $showingScanner) {
            FoodScannerView()
                .environmentObject(health)
        }
        .onAppear {
            if health.isRequested {
                health.fetchAllData()
            }
        }
    }
}
