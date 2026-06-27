import SwiftUI

struct MainTabView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    @State private var selectedTab = 0
    
    @AppStorage("app_theme") private var appTheme = "system"
    @AppStorage("app_language") private var appLanguage = "ru"
    
    private var colorScheme: ColorScheme? {
        switch appTheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
    
    init() {
        // Настройка внешнего вида TabBar под стиль Nano Health
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        
        // Разделительная линия сверху таббара
        appearance.shadowColor = UIColor.separator
        
        // Цвет неактивных иконок (серый)
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.systemGray
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.systemGray]
        
        // Цвет активных иконок
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor.label
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.label]
        
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
                Label(LocalizationManager.tr("tab_home", lang: appLanguage), systemImage: "house.fill")
            }
            .tag(0)
            
            NavigationStack {
                WorkoutsView()
                    .environmentObject(healthKitManager)
            }
            .tabItem {
                Label(LocalizationManager.tr("tab_workouts", lang: appLanguage), systemImage: "figure.run")
            }
            .tag(1)
            
            NavigationStack {
                WaterTrackerView()
                    .environmentObject(healthKitManager)
            }
            .tabItem {
                Label(LocalizationManager.tr("tab_water", lang: appLanguage), systemImage: "drop.fill")
            }
            .tag(2)
            
            NavigationStack {
                FoodScannerView()
                    .environmentObject(healthKitManager)
            }
            .tabItem {
                Label(LocalizationManager.tr("tab_nutrition", lang: appLanguage), systemImage: "leaf.fill")
            }
            .tag(3)
            
            NavigationStack {
                SettingsView()
                    .environmentObject(healthKitManager)
            }
            .tabItem {
                Label(LocalizationManager.tr("tab_settings", lang: appLanguage), systemImage: "gearshape.fill")
            }
            .tag(4)
        }
        .tint(Theme.textPrimary)
        .background(Theme.background)
        .preferredColorScheme(colorScheme)
    }
}
