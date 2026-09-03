import SwiftUI

struct MainTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var healthKitManager = HealthKitManager.shared
    @StateObject private var stepManager = BackgroundStepManager.shared
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
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DashboardView(
                    onStartWorkout: { activityType in
                        selectedTab = 1
                    },
                    onOpenNutrition: {
                        withAnimation(.spring()) {
                            selectedTab = 2
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            NotificationCenter.default.post(name: NSNotification.Name("OpenFoodScanner"), object: nil)
                        }
                    },
                    onOpenHabits: {
                        selectedTab = 3
                    }
                )
            }
            .tabItem {
                Label(LocalizationManager.tr("tab_home", lang: appLanguage), systemImage: "house.fill")
            }
            .tag(0)
            
            NavigationStack {
                WorkoutsView()
            }
            .tabItem {
                Label(LocalizationManager.tr("tab_workouts", lang: appLanguage), systemImage: "figure.run")
            }
            .tag(1)
            
            NavigationStack {
                NutritionView()
            }
            .tabItem {
                Label(LocalizationManager.tr("tab_nutrition", lang: appLanguage), systemImage: "leaf.fill")
            }
            .tag(2)
            
            NavigationStack {
                HabitsView()
            }
            .tabItem {
                Label(LocalizationManager.tr("tab_habits", lang: appLanguage), systemImage: "checkmark.seal.fill")
            }
            .tag(3)
            
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label(LocalizationManager.tr("tab_settings", lang: appLanguage), systemImage: "gearshape.fill")
            }
            .tag(4)
        }
        .environmentObject(healthKitManager)
        .environmentObject(stepManager)
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
        .onChange(of: selectedTab) {
            HapticManager.shared.selection()
        }
        .onChange(of: scenePhase) {
            stepManager.handleScenePhaseChange(to: scenePhase)
            if scenePhase == .active {
                healthKitManager.onAppAppear()
                healthKitManager.syncWidgetsData()
            }
        }
        .task {
            configureTabBarAppearance()
            healthKitManager.onAppAppear()
            healthKitManager.syncWidgetsData()
            FormaNotificationManager.shared.autoScheduleDefaultRemindersIfNeeded()
            if !healthKitManager.isAuthorized {
                healthKitManager.requestAuthorization()
            }
        }
    }
    
    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        appearance.shadowColor = UIColor.separator.withAlphaComponent(0.12)
        
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.secondaryLabel
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.secondaryLabel]
        
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor.label
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.label]
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    private func handleIncomingURL(_ url: URL) {
        let scheme = url.scheme?.lowercased() ?? ""
        let host = url.host?.lowercased() ?? ""
        let path = url.path.lowercased()
        
        if scheme == "forma" {
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
            } else if host.contains("habit") || path.contains("habit") {
                withAnimation(.spring()) {
                    selectedTab = 3
                }
            } else if host.contains("settings") {
                withAnimation(.spring()) {
                    selectedTab = 4
                }
            } else {
                withAnimation(.spring()) {
                    selectedTab = 0
                }
            }
        }
    }
}
