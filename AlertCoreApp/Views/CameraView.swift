import SwiftUI

struct CameraView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ZStack {
            Theme.darkBg.ignoresSafeArea()
            
            // Neon glow blobs
            VStack {
                HStack {
                    Circle()
                        .fill(Theme.accentGreen.opacity(0.06))
                        .frame(width: 200, height: 200)
                        .blur(radius: 70)
                        .offset(x: -40, y: -40)
                    Spacer()
                }
                Spacer()
            }
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Camera")
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("Cellular Photo Capture Pipeline")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(.top, 10)
                    .padding(.horizontal, 4)

                    // Image Frame Container
                    VStack(spacing: 12) {
                        if let image = state.cameraImage {
                            GeometryReader { geometry in
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: geometry.size.width, height: 320)
                                    .clipped()
                            }
                            .frame(height: 320)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        } else {
                            VStack(spacing: 16) {
                                Image(systemName: "photo.fill")
                                    .font(.system(size: 64))
                                    .foregroundColor(Theme.inactiveGrey.opacity(0.5))
                                
                                Text("No Image Received")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("Tap the capture button below to request a manual photo from the cellular device.")
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 320)
                            .background(Color.white.opacity(0.02))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                        }
                    }
                    .glassCardStyle()

                    // Telemetry & Details Card
                    VStack(alignment: .leading, spacing: 14) {
                        Text("CAPTURE TELEMETRY")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                        
                        HStack {
                            Text("Last Refreshed")
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                            Text(formatTimestamp(state.lastImageTimestampMs))
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.1))

                        HStack {
                            Text("Next Auto-Capture In")
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                            Text(state.periodicRefreshEnabled ? formatCountdown(state.secondsUntilNextImage) : "Manual Only")
                                .fontWeight(.bold)
                                .foregroundColor(state.periodicRefreshEnabled ? Theme.accentGreen : Theme.inactiveGrey)
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.1))
                        
                        HStack {
                            Text("Current Distance")
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                            Text(state.distanceCm != nil ? "\(state.distanceCm!) cm" : "--")
                                .fontWeight(.bold)
                                .foregroundColor(state.objectPresent ? Theme.accentCoral : Theme.accentGreen)
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.1))
                        
                        HStack {
                            Text("System State")
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                            Text(state.objectPresent ? "ALERT ACTIVE" : "SECURED")
                                .fontWeight(.bold)
                                .foregroundColor(state.objectPresent ? Theme.accentCoral : Theme.accentGreen)
                        }
                    }
                    .glassCardStyle()

                    // Trigger Manual Capture Button
                    VStack(spacing: 8) {
                        PrimaryButton(title: "Trigger Manual Capture", icon: "camera.fill") {
                            state.triggerManualCapture()
                        }
                        
                        Text("Requests ESP32-S3 to capture a photo, upload it to Cloudflare, and sync over MQTT. Takes 10-15 seconds over cellular.")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                    .padding(.top, 8)
                }
                .padding()
            }
        }
    }

    private func formatTimestamp(_ ms: Int64) -> String {
        guard ms > 0 else { return "Never" }
        let date = Date(timeIntervalSince1970: TimeInterval(ms) / 1000.0)
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    private func formatCountdown(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
