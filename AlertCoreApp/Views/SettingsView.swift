import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @AppStorage("pushBackendBaseURL") private var pushBackendBaseURL: String = ""
    @State private var ipText: String = ""
    @State private var portText: String = ""
    @State private var thresholdText: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Endpoint")) {
                    TextField("Device IP", text: $ipText)
                    TextField("Port", text: $portText)
                        .keyboardType(.numberPad)
                    Button("Save") {
                        if let p = Int(portText) { state.ip = ipText; state.port = p }
                    }
                }

                Section(header: Text("App")) {
                    Button("Open iPhone Settings") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }

                    Text("Use iPhone Settings to keep Notifications, Local Network, and Background App Refresh enabled for AlertCore.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Toggle("Notifications", isOn: $state.notificationsEnabled)
                        .onChange(of: state.notificationsEnabled) { newValue in
                            if newValue {
                                state.requestNotificationAuthorization()
                                PushNotificationManager.shared.requestRemoteNotifications()
                            }
                        }

                    Picker("Alert mode", selection: $state.alertPresentationMode) {
                        ForEach(AppState.AlertPresentationMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }

                    Text("Auto dismiss stops ringing after 10 seconds. Ring until dismissed stays active until you stop it.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if state.alertRingEnabled || state.activeAlert != nil {
                        Button("Stop ringing now") {
                            state.acknowledgeActiveAlert()
                        }
                        .foregroundColor(.red)
                    }

                    Button("Send Test Notification") {
                        state.sendTestNotification()
                    }
                }

                Section(header: Text("Push Alerts")) {
                    TextField("APNs backend URL", text: $pushBackendBaseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)

                    Text("Example: https://alerts.example.com. The backend receives your APNs device token and sends repeated alert pushes when the firmware reports an alert.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button("Register for APNs") {
                        PushNotificationManager.shared.requestRemoteNotifications()
                    }

                    Button("Sync APNs token to backend") {
                        PushNotificationManager.shared.syncRegisteredTokenToBackendIfAvailable()
                    }
                }
            }
            .onAppear {
                ipText = state.ip
                portText = String(state.port)
                PushNotificationManager.shared.syncRegisteredTokenToBackendIfAvailable()
            }
            .onChange(of: pushBackendBaseURL) { _ in
                PushNotificationManager.shared.syncRegisteredTokenToBackendIfAvailable()
            }
            .navigationTitle("Settings")
        }
    }
}
