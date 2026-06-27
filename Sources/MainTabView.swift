import SwiftUI

struct MainTabView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    @State private var selectedTab = 0
    
    init() {
        // Настройка светлого внешнего вида TabBar в iOS 17 под стиль Nano Health
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.white
        
        // Разделительная линия сверху таббара
        appearance.shadowColor = UIColor.black.withAlphaComponent(0.05)
        
        // Цвет неактивных иконок (серый)
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(Theme.textSecondary)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(Theme.textSecondary)]
        
        // Цвет активных иконок (темно-синий/черный)
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Theme.textPrimary)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(Theme.textPrimary)]
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DashboardView(onStartWorkout: { activityType in
                    // Переключаемся на вкладку тренировок (Tab 1)
                    selectedTab = 1
                })
                .environmentObject(healthKitManager)
            }
            .tabItem {
                Label("Overview", systemImage: "house.fill")
            }
            .tag(0)
            
            NavigationStack {
                WorkoutsView()
                    .environmentObject(healthKitManager)
            }
            .tabItem {
                Label("Workouts", systemImage: "figure.run")
            }
            .tag(1)
            
            NavigationStack {
                FoodScannerView()
                    .environmentObject(healthKitManager)
            }
            .tabItem {
                Label("Nutrition", systemImage: "leaf.fill")
            }
            .tag(2)
            
            NavigationStack {
                TrendsView()
                    .environmentObject(healthKitManager)
            }
            .tabItem {
                Label("Trends", systemImage: "chart.xyaxis.line")
            }
            .tag(3)
        }
        .tint(Theme.textPrimary)
        .background(Theme.background)
    }
}
