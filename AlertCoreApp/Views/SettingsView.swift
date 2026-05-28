import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var state: AppState
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
                    Toggle("Notifications", isOn: $state.notificationsEnabled)
                        .onChange(of: state.notificationsEnabled) { newValue in
                            if newValue {
                                state.requestNotificationAuthorization()
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
            }
            .onAppear {
                ipText = state.ip
                portText = String(state.port)
            }
            .navigationTitle("Settings")
        }
    }
}
