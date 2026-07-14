import SwiftUI

@main
struct FitCoachApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if appState.profile == nil {
            OnboardingView()
        } else {
            MainTabView()
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Home", systemImage: "house.fill") }
            PlanView()
                .tabItem { Label("Train", systemImage: "dumbbell.fill") }
            CoachChatView()
                .tabItem { Label("Coach", systemImage: "bubble.left.and.text.bubble.right.fill") }
            NutritionView()
                .tabItem { Label("Nutrition", systemImage: "fork.knife") }
            ProgressTabView()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
        }
    }
}
