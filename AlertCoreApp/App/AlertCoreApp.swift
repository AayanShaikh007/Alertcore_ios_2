import SwiftUI
import UserNotifications
import UIKit

final class AlertCoreAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushNotificationManager.shared.handleRegisteredDeviceToken(deviceToken)
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        PushNotificationManager.shared.handleRegistrationFailure(error)
    }
}

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
    @UIApplicationDelegateAdaptor(AlertCoreAppDelegate.self) private var appDelegate
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            RootContentView()
                .environmentObject(state)
                .task {
                    UNUserNotificationCenter.current().delegate = AlertCoreNotificationDelegate.shared
                    state.initializeNotificationAuthorization()
                    PushNotificationManager.shared.requestRemoteNotifications()
                    PushNotificationManager.shared.syncRegisteredTokenToBackendIfAvailable()
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
            Color.black
                .ignoresSafeArea()

            MainTabView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .preferredColorScheme(.dark)

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
            Color.black.opacity(0.75)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Warning pulsing glow ring
                ZStack {
                    Circle()
                        .fill(Theme.accentCoral.opacity(0.15))
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .stroke(Theme.accentCoral, lineWidth: 3)
                        .frame(width: 60, height: 60)
                        .shadow(color: Theme.accentCoral, radius: 10)
                    
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.top, 10)

                VStack(spacing: 8) {
                    Text("ALERT TRIGGERED")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(Theme.accentCoral)
                        .tracking(2)
                    
                    Text(alert.message)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 10)

                Button(action: dismissAction) {
                    Text("Acknowledge & Mute")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color.white, Color.white.opacity(0.9)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: .white.opacity(0.2), radius: 8, x: 0, y: 4)
                }
            }
            .padding(28)
            .background(.ultraThinMaterial)
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [Theme.accentCoral, Theme.accentCoral.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
            .shadow(color: Theme.accentCoral.opacity(0.3), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 30)
        }
    }
}
