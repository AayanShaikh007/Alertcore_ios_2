import SwiftUI

struct AlertsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        NavigationView {
            List(state.alerts) { alert in
                VStack(alignment: .leading) {
                    Text(alert.message)
                    Text(Date(timeIntervalSince1970: TimeInterval(alert.timestampMs) / 1000.0), style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Recent alerts")
            .overlay(
                state.alerts.isEmpty ? Text("No alerts yet. A threshold crossing will appear here.").foregroundColor(.secondary) : nil
            )
        }
    }
}
