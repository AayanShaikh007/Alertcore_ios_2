import SwiftUI

struct AlertsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ZStack {
            Theme.darkBg.ignoresSafeArea()
            
            // Neon glow blobs
            VStack {
                Spacer()
                HStack {
                    Circle()
                        .fill(Theme.accentCoral.opacity(0.06))
                        .frame(width: 200, height: 200)
                        .blur(radius: 70)
                        .offset(x: -45, y: 45)
                    Spacer()
                }
            }
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Recent Alerts")
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("Historical log of sensor breaches")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(.top, 10)
                    .padding(.horizontal, 4)

                    if state.alerts.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "bell.slash.fill")
                                .font(.system(size: 48))
                                .foregroundColor(Theme.inactiveGrey.opacity(0.5))
                            
                            Text("No Alerts Yet")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Threshold crossings and manual triggers will appear here in real-time.")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 80)
                        .glassCardStyle()
                    } else {
                        VStack(spacing: 12) {
                            ForEach(state.alerts) { alert in
                                HStack(spacing: 16) {
                                    // Alert Type Icon indicator
                                    let isManual = alert.message.contains("Manual")
                                    Image(systemName: isManual ? "hand.tap.fill" : "exclamationmark.triangle.fill")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(Theme.accentCoral)
                                        .frame(width: 38, height: 38)
                                        .background(Theme.accentCoral.opacity(0.15))
                                        .clipShape(Circle())
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(alert.message)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                        
                                        Text(formatTimestamp(alert.timestampMs))
                                            .font(.system(size: 11))
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                    Spacer()
                                }
                                .padding()
                                .background(Color.white.opacity(0.02))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                                )
                            }
                        }
                    }
                }
                .padding()
            }
        }
    }

    private func formatTimestamp(_ ms: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(ms) / 1000.0)
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}
