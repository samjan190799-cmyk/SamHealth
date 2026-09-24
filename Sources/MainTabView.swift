import SwiftUI

struct MainTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    private let healthKitManager = HealthKitManager.shared
    private let stepManager = BackgroundStepManager.shared
    @State private var selectedTab = 0
    @State private var visitedTabs: Set<Int> = [0]
    
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
        Self.configureTabBarAppearance()
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DashboardView(
                    onStartWorkout: { _ in
                        selectedTab = 1
                    },
                    onOpenNutrition: {
                        selectedTab = 2
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
                if visitedTabs.contains(1) {
                    WorkoutsView()
                } else {
                    Color.clear
                }
            }
            .tabItem {
                Label(LocalizationManager.tr("tab_workouts", lang: appLanguage), systemImage: "figure.run")
            }
            .tag(1)
            
            NavigationStack {
                if visitedTabs.contains(2) {
                    NutritionView()
                } else {
                    Color.clear
                }
            }
            .tabItem {
                Label(LocalizationManager.tr("tab_nutrition", lang: appLanguage), systemImage: "leaf.fill")
            }
            .tag(2)
            
            NavigationStack {
                if visitedTabs.contains(3) {
                    HabitsView()
                } else {
                    Color.clear
                }
            }
            .tabItem {
                Label(LocalizationManager.tr("tab_habits", lang: appLanguage), systemImage: "checkmark.seal.fill")
            }
            .tag(3)
            
            NavigationStack {
                if visitedTabs.contains(4) {
                    SettingsView()
                } else {
                    Color.clear
                }
            }
            .tabItem {
                Label(LocalizationManager.tr("tab_settings", lang: appLanguage), systemImage: "gearshape.fill")
            }
            .tag(4)
        }
        .onChange(of: selectedTab) { _, newTab in
            visitedTabs.insert(newTab)
        }
        .environmentObject(healthKitManager)
        .environmentObject(stepManager)
        .tint(Theme.tabBarTint)
        .background(Theme.background)
        .preferredColorScheme(colorScheme)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenFoodScanner"))) { _ in
            visitedTabs.insert(2)
            selectedTab = 2
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshHealthKitData"))) { _ in
            healthKitManager.fetchAllData()
        }
        .onOpenURL { url in
            handleIncomingURL(url)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                // При возврате на экран ПЕРВЫМ делом проверяем и выполняем смену дня для здоровья и питания
                healthKitManager.checkAndHandleDayRollover()
                healthKitManager.onAppAppear()
                stepManager.handleScenePhaseChange(to: newPhase)
            } else if newPhase == .background {
                // При уходе в фон гарантированно немедленно сохраняем все архивы и обновляем виджеты
                stepManager.handleScenePhaseChange(to: newPhase)
                healthKitManager.saveLocalDataImmediately()
            }
        }
        .task {
            healthKitManager.onAppAppear()
            healthKitManager.syncWidgetsData()
            FormaNotificationManager.shared.autoScheduleDefaultRemindersIfNeeded()
            Task {
                await stepManager.syncPastWeekStepsFromPedometer()
            }
        }
    }
    
    private static func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.shadowColor = UIColor.separator.withAlphaComponent(0.12)
        
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.secondaryLabel
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.secondaryLabel]
        
        let activeColor = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 204/255, green: 255/255, blue: 0/255, alpha: 1.0)
                : UIColor(red: 17/255, green: 24/255, blue: 39/255, alpha: 1.0)
        }
        appearance.stackedLayoutAppearance.selected.iconColor = activeColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: activeColor]
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    private func handleIncomingURL(_ url: URL) {
        let scheme = url.scheme?.lowercased() ?? ""
        let host = url.host?.lowercased() ?? ""
        let path = url.path.lowercased()
        
        healthKitManager.flushPendingWidgetWaterLogs()
        
        if scheme == "forma" {
            if host.contains("water") || host.contains("add-water") || path.contains("water") {
                visitedTabs.insert(2)
                selectedTab = 2
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                let amountStr = components?.queryItems?.first(where: { $0.name == "amount" })?.value
                let amount = Double(amountStr ?? "250") ?? 250.0
                healthKitManager.addBeverage(type: .water, volumeMl: amount)
                HapticManager.shared.notification(.success)
            } else if host.contains("scan") || host.contains("food") || host.contains("nutrition") || path.contains("scan") {
                visitedTabs.insert(2)
                selectedTab = 2
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    NotificationCenter.default.post(name: NSNotification.Name("OpenFoodScanner"), object: nil)
                }
            } else if host.contains("coach") || path.contains("coach") {
                visitedTabs.insert(0)
                selectedTab = 0
                NotificationCenter.default.post(name: NSNotification.Name("OpenAICoachChat"), object: nil)
            } else if host.contains("workout") || path.contains("workout") {
                visitedTabs.insert(1)
                selectedTab = 1
            } else if host.contains("habit") || path.contains("habit") {
                visitedTabs.insert(3)
                selectedTab = 3
            } else if host.contains("settings") {
                visitedTabs.insert(4)
                selectedTab = 4
            } else {
                visitedTabs.insert(0)
                selectedTab = 0
            }
        }
    }
}
