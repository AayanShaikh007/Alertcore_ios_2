import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @AppStorage("pushBackendBaseURL") private var pushBackendBaseURL: String = ""
    
    // Local state to avoid reconnect floods while editing
    @State private var hostText: String = ""
    @State private var portText: String = ""
    @State private var usernameText: String = ""
    @State private var passwordText: String = ""
    
    @State private var thresholdValue: Double = 46
    @State private var autoDismissText: String = ""

    var body: some View {
        ZStack {
            Theme.darkBg.ignoresSafeArea()
            
            // Neon glow blobs
            VStack {
                HStack {
                    Spacer()
                    Circle()
                        .fill(Theme.accentGreen.opacity(0.08))
                        .frame(width: 200, height: 200)
                        .blur(radius: 70)
                        .offset(x: 50, y: -20)
                }
                Spacer()
                HStack {
                    Circle()
                        .fill(Theme.accentCoral.opacity(0.08))
                        .frame(width: 220, height: 220)
                        .blur(radius: 80)
                        .offset(x: -50, y: 50)
                    Spacer()
                }
            }
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        Text("Settings")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.top, 10)
                    .padding(.horizontal, 4)
                    
                    // MQTT Broker Configuration
                    VStack(alignment: .leading, spacing: 14) {
                        Text("MQTT BROKER CREDENTIALS")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                        
                        DarkTextField(title: "Broker Host", text: $hostText)
                        DarkTextField(title: "Port", text: $portText)
                            .keyboardType(.numberPad)
                        DarkTextField(title: "Username", text: $usernameText)
                        DarkTextField(title: "Password", text: $passwordText, isSecure: true)
                        
                        PrimaryButton(title: "Save & Reconnect", icon: "arrow.clockwise") {
                            saveMqttSettings()
                        }
                        .padding(.top, 4)
                    }
                    .glassCardStyle()
                    
                    // Distance Threshold Card
                    VStack(alignment: .leading, spacing: 14) {
                        Text("DISTANCE THRESHOLD")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                        
                        Stepper(value: $thresholdValue, in: 10...200, step: 1) {
                            HStack {
                                Text("Alert Threshold:")
                                    .foregroundColor(.white)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("\(Int(thresholdValue)) cm")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.accentCoral)
                            }
                        }
                        .onChange(of: thresholdValue) { newValue in
                            state.updateThreshold(Int(newValue))
                        }
                    }
                    .glassCardStyle()
                    
                    // Alert Trigger Mode Selection Card (Frosted Div Boxes)
                    VStack(alignment: .leading, spacing: 14) {
                        Text("ALERT TRIGGER MODE")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                        
                        VStack(spacing: 12) {
                            // Option 1 Box
                            Button(action: {
                                state.alertTriggerMode = .stateChange
                            }) {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Option 1: Alert on State Changes")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                        
                                        Spacer()
                                        
                                        Circle()
                                            .stroke(state.alertTriggerMode == .stateChange ? Theme.accentGreen : Theme.textSecondary.opacity(0.5), lineWidth: 2)
                                            .background(
                                                Circle()
                                                    .fill(state.alertTriggerMode == .stateChange ? Theme.accentGreen : Color.clear)
                                                    .padding(3)
                                            )
                                            .frame(width: 18, height: 18)
                                    }
                                    
                                    Text("Generates alerts on startup if the target is far (> 46 cm). Sends alerts on subsequent transitions to either side of the threshold.")
                                        .font(.system(size: 12))
                                        .foregroundColor(Theme.textSecondary)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(12)
                                .background(Color.white.opacity(state.alertTriggerMode == .stateChange ? 0.06 : 0.02))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(state.alertTriggerMode == .stateChange ? Theme.accentGreen.opacity(0.4) : Color.white.opacity(0.05), lineWidth: 1)
                                )
                            }
                            
                            // Option 2 Box
                            Button(action: {
                                state.alertTriggerMode = .farToNear
                            }) {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Option 2: Alert Only on Far -> Near")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                        
                                        Spacer()
                                        
                                        Circle()
                                            .stroke(state.alertTriggerMode == .farToNear ? Theme.accentGreen : Theme.textSecondary.opacity(0.5), lineWidth: 2)
                                            .background(
                                                Circle()
                                                    .fill(state.alertTriggerMode == .farToNear ? Theme.accentGreen : Color.clear)
                                                    .padding(3)
                                            )
                                            .frame(width: 18, height: 18)
                                    }
                                    
                                    Text("No alerts on boot. The system arms once a far reading (> 46 cm) is detected. Generates an alert and disarms upon transitioning to near (< 46 cm).")
                                        .font(.system(size: 12))
                                        .foregroundColor(Theme.textSecondary)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(12)
                                .background(Color.white.opacity(state.alertTriggerMode == .farToNear ? 0.06 : 0.02))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(state.alertTriggerMode == .farToNear ? Theme.accentGreen.opacity(0.4) : Color.white.opacity(0.05), lineWidth: 1)
                                )
                            }
                        }
                    }
                    .glassCardStyle()
                    
                    // App Preferences & Ringing
                    VStack(alignment: .leading, spacing: 16) {
                        Text("APP PREFERENCES")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                        
                        Toggle(isOn: $state.notificationsEnabled) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Local Notifications")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Receive local sound and banner alerts")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        .tint(Theme.accentGreen)
                        .onChange(of: state.notificationsEnabled) { newValue in
                            if newValue {
                                state.requestNotificationAuthorization()
                                PushNotificationManager.shared.requestRemoteNotifications()
                            }
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.1))

                        Toggle(isOn: $state.periodicRefreshEnabled) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Periodic Image Refresh")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Upload a camera image automatically every 5 minutes. Disable to save cellular data and battery.")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        .tint(Theme.accentGreen)
                        
                        Divider()
                            .background(Color.white.opacity(0.1))

                        Toggle(isOn: $state.photoOnAlertEnabled) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Photo on Alert")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Automatically capture and upload a new photo when an alert is triggered. Disable to reduce cellular data usage.")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        .tint(Theme.accentGreen)
                        
                        Divider()
                            .background(Color.white.opacity(0.1))
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Alert Tone Presentation")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            
                            Picker("Alert Presentation", selection: $state.alertPresentationMode) {
                                ForEach(AppState.AlertPresentationMode.allCases) { mode in
                                    Text(mode.title).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            
                            Text("Auto dismiss stops ringing after \(state.autoDismissSeconds)s. Ring until dismissed rings indefinitely until manual dismissal.")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.textSecondary)
                                .padding(.top, 2)
                        }
                        
                        if state.alertPresentationMode == .autoDismiss {
                            DarkTextField(title: "Auto Dismiss Timeout (seconds)", text: $autoDismissText)
                                .keyboardType(.numberPad)
                                .onChange(of: autoDismissText) { newValue in
                                    let filtered = newValue.filter { $0.isNumber }
                                    if let val = Int(filtered) {
                                        state.autoDismissSeconds = max(5, min(600, val))
                                    }
                                }
                        }
                        
                        if state.alertRingEnabled || state.activeAlert != nil {
                            PrimaryButton(title: "Stop Ringing Now", icon: "bell.slash.fill", color: Theme.accentCoral) {
                                state.acknowledgeActiveAlert()
                            }
                        }
                        
                        Button(action: {
                            state.sendTestNotification()
                        }) {
                            Text("Send Test Notification")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Theme.accentGreen)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Theme.accentGreen.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                    .glassCardStyle()
                    
                    // APNs Remote Alerts Backend
                    VStack(alignment: .leading, spacing: 14) {
                        Text("APNS PUSH ALERTS")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                        
                        DarkTextField(title: "APNs Backend URL", text: $pushBackendBaseURL)
                        
                        Text("The backend receives your APNs device token and triggers notifications when the firmware reports an alert.")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textSecondary)
                        
                        HStack(spacing: 12) {
                            Button(action: {
                                PushNotificationManager.shared.requestRemoteNotifications()
                            }) {
                                Text("Register APNs")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(8)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            }
                            
                            Button(action: {
                                PushNotificationManager.shared.syncRegisteredTokenToBackendIfAvailable()
                            }) {
                                Text("Sync Token")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(8)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            }
                        }
                    }
                    .glassCardStyle()
                    
                    // System Settings button
                    Button(action: {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }) {
                        Text("Open iOS System Settings")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                    }
                    .padding(.bottom, 20)
                }
                .padding()
            }
        }
        .onAppear {
            hostText = state.mqttHost
            portText = String(state.mqttPort)
            usernameText = state.mqttUsername
            passwordText = state.mqttPassword
            thresholdValue = Double(state.thresholdCm)
            autoDismissText = String(state.autoDismissSeconds)
            PushNotificationManager.shared.syncRegisteredTokenToBackendIfAvailable()
        }
        .onChange(of: pushBackendBaseURL) { _ in
            PushNotificationManager.shared.syncRegisteredTokenToBackendIfAvailable()
        }
    }
    
    private func saveMqttSettings() {
        guard let portVal = Int(portText) else { return }
        state.mqttHost = hostText
        state.mqttPort = portVal
        state.mqttUsername = usernameText
        state.mqttPassword = passwordText
    }
}

// Reuse custom controls
struct DarkTextField: View {
    let title: String
    @Binding var text: String
    var isSecure: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Theme.textSecondary)
            
            Group {
                if isSecure {
                    SecureField("", text: $text)
                } else {
                    TextField("", text: $text)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(Color.white.opacity(0.04))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .foregroundColor(.white)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        }
    }
}

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var color: Color = Theme.accentGreen
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [color, color.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .foregroundColor(color == Theme.accentGreen ? .black : .white)
            .cornerRadius(10)
            .shadow(color: color.opacity(0.25), radius: 6, x: 0, y: 3)
        }
    }
}
