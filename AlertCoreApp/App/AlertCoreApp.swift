import SwiftUI

@main
struct AlertCoreApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(state)
                .task {
                    // start polling
                    await state.startPolling()
                }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "house")
                }

            CameraView()
                .tabItem {
                    Label("Camera", systemImage: "camera")
                }

            AlertsView()
                .tabItem {
                    Label("Alerts", systemImage: "bell")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}
