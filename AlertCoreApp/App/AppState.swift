import Foundation
import Combine
import SwiftUI
import UserNotifications

@MainActor
class AppState: ObservableObject {
    enum AlertPresentationMode: String, CaseIterable, Identifiable {
        case autoDismiss
        case ringUntilDismissed

        var id: String { rawValue }

        var title: String {
            switch self {
            case .autoDismiss:
                return "Auto dismiss"
            case .ringUntilDismissed:
                return "Ring until dismissed"
            }
        }
    }

    @Published var ip: String = "192.168.2.186"
    @Published var port: Int = 80
    @Published var distanceCm: Int? = nil
    @Published var objectPresent: Bool = false
    @Published var alerts: [AlertEvent] = []
    @Published var history: [DistanceSampleDto] = []
    @Published var connected: Bool = false
    @Published var statusMessage: String = ""
    @Published var notificationsEnabled: Bool = true
    @Published var alertPresentationMode: AlertPresentationMode = .autoDismiss
    @Published var activeAlert: AlertEvent? = nil
    @Published var graphMinutes: Int = 60

    private var statusTask: Task<Void, Never>? = nil
    private var historyTask: Task<Void, Never>? = nil
    private var lastAlertSignature: String? = nil
    private var lastAlertAt: Date? = nil

    private let persistentAlertNotificationId = "AlertCorePersistentAlert"

    func startPolling() async {
        stopPolling()
        statusTask = Task { [weak self] in
            guard let self = self else { return }
            while !Task.isCancelled {
                await self.pollStatus()
                try? await Task.sleep(nanoseconds: UInt64(self.statusPollMs()) * 1_000_000)
            }
        }

        historyTask = Task { [weak self] in
            guard let self = self else { return }
            while !Task.isCancelled {
                await self.pollHistory()
                try? await Task.sleep(nanoseconds: UInt64(self.historyPollMs()) * 1_000_000)
            }
        }
    }

    func stopPolling() {
        statusTask?.cancel()
        historyTask?.cancel()
        statusTask = nil
        historyTask = nil
    }

    func statusPollMs() -> Int { 1000 }
    func historyPollMs() -> Int { 3000 }

    func pollStatus() async {
        do {
            let s = try await NetworkClient.shared.fetchStatus(ip: ip, port: port)
            connected = true
            statusMessage = "Connected"
            distanceCm = s.distanceCm >= 0 ? s.distanceCm : nil
            objectPresent = s.objectPresent

            let hasAlert = s.alertTransition || (s.manualTransition ?? false)
            if hasAlert {
                let message: String
                if s.alertTransition {
                    message = s.objectPresent ? "Object entered threshold at \(s.distanceCm) cm" : "Object exited threshold range"
                } else {
                    message = "Manual trigger pressed"
                }
                handleAlert(message: message, signature: "\(s.alertTransition ? "alert" : "manual"):\(s.objectPresent):\(s.distanceCm)")
            }
        } catch {
            connected = false
            statusMessage = "Disconnected: \(error.localizedDescription)"
        }
    }

    func pollHistory() async {
        do {
            let samples = try await NetworkClient.shared.fetchHistory(ip: ip, port: port, minutes: graphMinutes)
            self.history = samples
        } catch {
            // keep previous history on error
        }
    }

    func updateThreshold(_ t: Int) async {
        do {
            let s = try await NetworkClient.shared.updateThreshold(ip: ip, port: port, threshold: t)
            // update local state
            distanceCm = s.distanceCm >= 0 ? s.distanceCm : nil
            objectPresent = s.objectPresent
        } catch {
            // ignore
        }
    }

    func acknowledgeActiveAlert() {
        activeAlert = nil
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [persistentAlertNotificationId])
        center.removeDeliveredNotifications(withIdentifiers: [persistentAlertNotificationId])
    }

    private func handleAlert(message: String, signature: String) {
        let now = Date()
        if let lastAlertSignature, let lastAlertAt, lastAlertSignature == signature, now.timeIntervalSince(lastAlertAt) < 5 {
            return
        }

        lastAlertSignature = signature
        lastAlertAt = now

        let alert = AlertEvent(timestampMs: Int64(now.timeIntervalSince1970 * 1000), message: message)
        alerts.insert(alert, at: 0)
        deliverAlertNotification(message: message)

        if alertPresentationMode == .ringUntilDismissed {
            activeAlert = alert
        }
    }

    private func deliverAlertNotification(message: String) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            Task { @MainActor in
                guard self.notificationsEnabled else { return }

                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    let content = UNMutableNotificationContent()
                    content.title = "AlertCore"
                    content.body = message
                    content.sound = .default

                    if self.alertPresentationMode == .ringUntilDismissed {
                        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: true)
                        let request = UNNotificationRequest(identifier: self.persistentAlertNotificationId, content: content, trigger: trigger)
                        center.add(request) { error in
                            if let error = error {
                                print("Failed to schedule persistent alert notification: \(error)")
                            }
                        }

                        let immediateRequest = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                        center.add(immediateRequest) { error in
                            if let error = error {
                                print("Failed to deliver immediate alert notification: \(error)")
                            }
                        }
                    } else {
                        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                        center.add(request) { error in
                            if let error = error {
                                print("Failed to deliver alert notification: \(error)")
                            }
                        }
                    }
                case .notDetermined:
                    self.requestNotificationAuthorization { granted in
                        if granted {
                            self.deliverAlertNotification(message: message)
                        }
                    }
                default:
                    self.notificationsEnabled = false
                }
            }
        }
    }

    // MARK: - Notifications
    func initializeNotificationAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            Task { @MainActor in
                switch settings.authorizationStatus {
                case .notDetermined:
                    self.requestNotificationAuthorization()
                case .authorized, .provisional, .ephemeral:
                    self.notificationsEnabled = true
                default:
                    self.notificationsEnabled = false
                }
            }
        }
    }

    func requestNotificationAuthorization(completion: ((Bool) -> Void)? = nil) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            Task { @MainActor in
                // keep toggle in sync with actual granted state
                self.notificationsEnabled = granted
                completion?(granted)
                if let error = error {
                    print("Notification authorization error: \(error)")
                }
            }
        }
    }

    func scheduleTestNotification(title: String = "AlertCore Test", body: String = "This is a test notification.") {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        center.add(req) { error in
            if let e = error {
                print("Failed to schedule test notification: \(e)")
            }
        }
    }

    func sendTestNotification() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            Task { @MainActor in
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    self.scheduleTestNotification()
                case .notDetermined:
                    self.requestNotificationAuthorization { granted in
                        if granted {
                            self.scheduleTestNotification()
                        }
                    }
                default:
                    self.notificationsEnabled = false
                }
            }
        }
    }
}

struct AlertEvent: Identifiable {
    let id = UUID()
    let timestampMs: Int64
    let message: String
}

extension AppState {
    var cameraPageUrl: String {
        return "http://\(ip):\(port)/"
    }

    var streamUrl: String {
        return "http://\(ip):\(port + 1)/stream"
    }
}
