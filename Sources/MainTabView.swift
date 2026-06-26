import SwiftUI

struct MainTabView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    
    init() {
        // Настройка внешнего вида TabBar в iOS 17
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Theme.cardBackground)
        
        // Цвет неактивных иконок
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.gray
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.gray]
        
        // Цвет активных иконок
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor.white
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.white]
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        TabView {
            NavigationStack {
                DashboardView()
                    .environmentObject(healthKitManager)
            }
            .tabItem {
                Label("Сводка", systemImage: "heart.text.square.fill")
            }
            
            NavigationStack {
                WorkoutsView()
                    .environmentObject(healthKitManager)
            }
            .tabItem {
                Label("Тренировки", systemImage: "figure.run")
            }
            
            NavigationStack {
                HabitsView()
                    .environmentObject(healthKitManager)
            }
            .tabItem {
                Label("Привычки", systemImage: "checklist")
            }
        }
        .tint(.white)
        .background(Theme.background)
    }
}
