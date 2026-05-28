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
            RootContentView()
                .environmentObject(state)
                .task {
                    UNUserNotificationCenter.current().delegate = AlertCoreNotificationDelegate.shared
                    state.initializeNotificationAuthorization()
                    await state.startPolling()
                }
        }
    }
}

struct RootContentView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasShownBackgroundRefreshPrompt") private var hasShownBackgroundRefreshPrompt = false
    @State private var showBackgroundRefreshPrompt = false

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            MainTabView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let activeAlert = state.activeAlert {
                PersistentAlertOverlay(alert: activeAlert) {
                    state.acknowledgeActiveAlert()
                }
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.2), value: state.activeAlert?.id)
        .onAppear {
            if !hasShownBackgroundRefreshPrompt {
                showBackgroundRefreshPrompt = true
            }
        }
        .alert("Enable background updates", isPresented: $showBackgroundRefreshPrompt) {
            Button("Open Settings") {
                hasShownBackgroundRefreshPrompt = true
                openAppSettings()
            }
            Button("Not Now", role: .cancel) {
                hasShownBackgroundRefreshPrompt = true
            }
        } message: {
            Text("iPhone does not let apps request Background App Refresh directly. If you want AlertCore to stay more responsive in the background, open Settings and keep Background App Refresh on for the app, plus allow Notifications and Local Network access.")
        }
        .onChange(of: scenePhase) { newPhase in
            Task {
                if newPhase == .active {
                    await state.refreshPollingIfNeeded(isActive: true)
                }
            }
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

struct MainTabView: View {
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PersistentAlertOverlay: View {
    let alert: AlertEvent
    let dismissAction: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(.white)

                Text("AlertCore Alert")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)

                Text(alert.message)
                    .font(.body)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Button(action: dismissAction) {
                    Text("Dismiss")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .foregroundColor(.red)
                        .cornerRadius(12)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.red.opacity(0.92))
            )
            .padding(.horizontal, 24)
        }
    }
}
