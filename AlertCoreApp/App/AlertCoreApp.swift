import SwiftUI
import UserNotifications

final class AlertCoreNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AlertCoreNotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

@main
struct AlertCoreApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(state)
                .task {
                    UNUserNotificationCenter.current().delegate = AlertCoreNotificationDelegate.shared
                    state.initializeNotificationAuthorization()
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
