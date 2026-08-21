import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var stepManager: BackgroundStepManager
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
        // Настройка внешнего вида TabBar: ультратонкое матовое стекло (Glassmorphism)
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemMaterial)
        appearance.shadowColor = UIColor.separator.withAlphaComponent(0.15)
        
        // Цвет неактивных иконок
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.secondaryLabel
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.secondaryLabel]
        
        // Цвет активных иконок
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor.label
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.label]
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DashboardView(
                    onStartWorkout: { activityType in
                        selectedTab = 1
                    },
                    onOpenNutrition: {
                        selectedTab = 2
                    }
                )
                .environmentObject(healthKitManager)
                .environmentObject(stepManager)
            }
            .tabItem {
                Label(LocalizationManager.tr("tab_home", lang: appLanguage), systemImage: "house.fill")
            }
            .tag(0)
            
            NavigationStack {
                WorkoutsView()
                    .environmentObject(healthKitManager)
                    .environmentObject(stepManager)
            }
            .tabItem {
                Label(LocalizationManager.tr("tab_workouts", lang: appLanguage), systemImage: "figure.run")
            }
            .tag(1)
            
            NavigationStack {
                NutritionView()
                    .environmentObject(healthKitManager)
                    .environmentObject(stepManager)
            }
            .tabItem {
                Label(LocalizationManager.tr("tab_nutrition", lang: appLanguage), systemImage: "leaf.fill")
            }
            .tag(2)
            
            NavigationStack {
                SettingsView()
                    .environmentObject(healthKitManager)
                    .environmentObject(stepManager)
            }
            .tabItem {
                Label(LocalizationManager.tr("tab_settings", lang: appLanguage), systemImage: "gearshape.fill")
            }
            .tag(3)
        }
        .tint(Theme.textPrimary)
        .background(Theme.background)
        .preferredColorScheme(colorScheme)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenFoodScanner"))) { _ in
            withAnimation(.spring()) {
                selectedTab = 2
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshHealthKitData"))) { _ in
            healthKitManager.fetchAllData()
        }
        .onOpenURL { url in
            handleIncomingURL(url)
        }
        .task {
            healthKitManager.onAppAppear()
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        let scheme = url.scheme?.lowercased() ?? ""
        let host = url.host?.lowercased() ?? ""
        let path = url.path.lowercased()
        
        if scheme == "forma" || scheme == "samhealth" {
            if host.contains("scan") || host.contains("food") || host.contains("nutrition") || path.contains("scan") {
                withAnimation(.spring()) {
                    selectedTab = 2
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    NotificationCenter.default.post(name: NSNotification.Name("OpenFoodScanner"), object: nil)
                }
            } else if host.contains("workout") || path.contains("workout") {
                withAnimation(.spring()) {
                    selectedTab = 1
                }
            } else if host.contains("settings") {
                withAnimation(.spring()) {
                    selectedTab = 3
                }
            } else {
                withAnimation(.spring()) {
                    selectedTab = 0
                }
            }
        }
    }
}
