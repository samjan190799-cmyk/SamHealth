import SwiftUI

// MARK: - Почасовой таймлайн гидратации за день
public struct HourlyHydrationTimelineView: View {
    @EnvironmentObject var health: HealthKitManager
    @State private var selectedHour: Int? = nil
    
    // Часы для отображения на таймлайне: с 07:00 до 23:00
    private let timelineHours: [Int] = Array(7...23)
    
    public init() {}
    
    // Группировка записей по часам
    private var beveragesByHour: [Int: [LoggedBeverageRecord]] {
        var dict: [Int: [LoggedBeverageRecord]] = [:]
        let calendar = Calendar.current
        for record in health.loggedBeveragesToday {
            let hour = calendar.component(.hour, from: record.date)
            dict[hour, default: []].append(record)
        }
        return dict
    }
    
    // Объем по часам
    private func volumeForHour(_ hour: Int) -> Double {
        beveragesByHour[hour]?.reduce(0.0) { $0 + $1.volumeMl } ?? 0.0
    }
    
    // Доминирующий тип напитка за этот час
    private func dominantBeverageType(for hour: Int) -> BeverageType? {
        guard let list = beveragesByHour[hour], !list.isEmpty else { return nil }
        return list.max(by: { $0.volumeMl < $1.volumeMl })?.beverageType
    }
    
    // Текущий час
    private var currentHour: Int {
        Calendar.current.component(.hour, from: Date())
    }
    
    // Время с последнего приема напитка (в часах)
    private var hoursSinceLastBeverage: Double? {
        guard let lastDate = health.loggedBeveragesToday.map({ $0.date }).max() else { return nil }
        return max(0, Date().timeIntervalSince(lastDate) / 3600.0)
    }
    
    // Флаг длительного перерыва (> 3 часов в дневное время)
    private var isDehydrationWarningActive: Bool {
        guard currentHour >= 8 && currentHour <= 22 else { return false }
        if let hours = hoursSinceLastBeverage {
            return hours >= 3.0
        } else {
            // Если за сегодня еще вообще ничего не пили и уже больше 10 утра
            return currentHour >= 10
        }
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Заголовок карточки
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis")
                        .foregroundColor(Color(red: 0/255, green: 220/255, blue: 255/255))
                    Text("Распределение по часам")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                }
                
                Spacer()
                
                // Бейдж статуса паузы
                if let hours = hoursSinceLastBeverage {
                    let totalMin = Int(hours * 60)
                    HStack(spacing: 4) {
                        Image(systemName: hours >= 3.0 ? "exclamationmark.circle.fill" : "clock.fill")
                            .font(.system(size: 10))
                        Text(totalMin < 60 ? "\(totalMin) мин назад" : "\(String(format: "%.1f", hours)) ч назад")
                            .font(.caption2)
                            .bold()
                    }
                    .foregroundColor(hours >= 3.0 ? .orange : Theme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(hours >= 3.0 ? Color.orange.opacity(0.15) : Color.white.opacity(0.06))
                    .cornerRadius(8)
                }
            }
            
            // Предупреждение о дефиците воды (> 3 часов паузы)
            if isDehydrationWarningActive {
                HStack(spacing: 12) {
                    Image(systemName: "timer")
                        .font(.title3)
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Большой перерыв без воды")
                            .font(.caption)
                            .bold()
                            .foregroundColor(.white)
                        Text("Прошло более 3 часов. Сделайте 2-3 глотка (150–200 мл) для поддержания тонуса.")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.85))
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            health.addBeverage(type: .water, volumeMl: 200)
                        }
                        let haptic = UIImpactFeedbackGenerator(style: .medium)
                        haptic.impactOccurred()
                    }) {
                        Text("+200 мл")
                            .font(.caption2)
                            .bold()
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.orange)
                            .cornerRadius(10)
                    }
                }
                .padding(12)
                .background(Color.orange.opacity(0.2))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.orange.opacity(0.35), lineWidth: 1)
                )
            }
            
            // Горизонтальный почасовой график
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(timelineHours, id: \.self) { hour in
                        let volume = volumeForHour(hour)
                        let isCurrent = (hour == currentHour)
                        let isSelected = (selectedHour == hour)
                        let dominantType = dominantBeverageType(for: hour)
                        
                        VStack(spacing: 6) {
                            // Столбик объема
                            ZStack(alignment: .bottom) {
                                // Фоновая направляющая
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(isCurrent ? 0.12 : 0.04))
                                    .frame(width: 22, height: 75)
                                
                                if volume > 0 {
                                    // Цвет столбика по типу напитка
                                    let barColor = dominantType?.accentColor ?? Color.cyan
                                    let barHeight = min(CGFloat(volume / 400.0) * 75.0, 75.0)
                                    
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(
                                            LinearGradient(
                                                colors: [barColor.opacity(0.9), barColor.opacity(0.6)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .frame(width: 22, height: max(barHeight, 8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(isSelected ? Color.white : Color.clear, lineWidth: 1.5)
                                        )
                                }
                                
                                // Метка текущего часа
                                if isCurrent {
                                    VStack {
                                        Circle()
                                            .fill(Color.cyan)
                                            .frame(width: 5, height: 5)
                                            .offset(y: -4)
                                        Spacer()
                                    }
                                }
                            }
                            .frame(height: 80)
                            .onTapGesture {
                                if volume > 0 {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedHour = (selectedHour == hour ? nil : hour)
                                    }
                                    let haptic = UISelectionFeedbackGenerator()
                                    haptic.selectionChanged()
                                }
                            }
                            
                            // Подпись часа (например, 08, 12, 16)
                            Text(String(format: "%02d", hour))
                                .font(.system(size: 10, weight: isCurrent ? .bold : .medium, design: .monospaced))
                                .foregroundColor(isCurrent ? .cyan : (volume > 0 ? Theme.textPrimary : Theme.textSecondary.opacity(0.6)))
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            }
            
            // Всплывающая карточка выбранного часа
            if let sel = selectedHour, let list = beveragesByHour[sel], !list.isEmpty {
                let totalMl = list.reduce(0.0) { $0 + $1.volumeMl }
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("В \(String(format: "%02d:00", sel)) выпито:")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                        HStack(spacing: 8) {
                            Text("\(Int(totalMl)) мл суммарно")
                                .font(.caption)
                                .bold()
                                .foregroundColor(Theme.textPrimary)
                            
                            ForEach(list.prefix(3)) { item in
                                HStack(spacing: 2) {
                                    Text(item.beverageType.emoji)
                                    Text("\(Int(item.volumeMl))")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(Theme.textSecondary)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation { selectedHour = nil }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary.opacity(0.6))
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.06))
                .cornerRadius(12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Экспертная подсказка физиологии
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
                Text("Пейте по 150–250 мл каждые 1.5–2 часа для оптимальной работы мозга и почек.")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(.top, 2)
        }
        .premiumCard()
    }
}
