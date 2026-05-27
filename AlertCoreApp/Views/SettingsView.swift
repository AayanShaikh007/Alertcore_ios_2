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
                }
            }
            .onAppear {
                ipText = state.ip
                portText = String(state.port)
                state.checkNotificationAuthorization()
            }
            .navigationTitle("Settings")
        }
    }
}
