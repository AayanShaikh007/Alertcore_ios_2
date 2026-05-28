import SwiftUI
import UserNotifications


    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
            RootContentView()
                .environmentObject(state)
            .onChange(of: scenePhase) { newPhase in
                Task {
                    switch newPhase {
                    case .active:
                        await state.refreshPollingIfNeeded(isActive: true)
                    case .inactive, .background:
                        state.stopPolling()
                    @unknown default:
                        state.stopPolling()
                    }
                }
            }
            .task {
                UNUserNotificationCenter.current().delegate = AlertCoreNotificationDelegate.shared
                state.initializeNotificationAuthorization()
                // start polling
                await state.startPolling()
            }
        }
    }
}

struct RootContentView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            MainTabView()

            if let activeAlert = state.activeAlert {
                PersistentAlertOverlay(alert: activeAlert) {
                    state.acknowledgeActiveAlert()
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: state.activeAlert?.id)
        .onChange(of: scenePhase) { newPhase in
            Task {
                switch newPhase {
                case .active:
                    await state.refreshPollingIfNeeded(isActive: true)
                case .inactive, .background:
                    break
                @unknown default:
                    break
                }
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
