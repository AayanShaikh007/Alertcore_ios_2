import Foundation
import Combine
import SwiftUI
import UserNotifications

@MainActor
class AppState: ObservableObject {
    @Published var ip: String = "192.168.2.186"
    @Published var port: Int = 80
    @Published var distanceCm: Int? = nil
    @Published var objectPresent: Bool = false
    @Published var alerts: [AlertEvent] = []
    @Published var history: [DistanceSampleDto] = []
    @Published var connected: Bool = false
    @Published var statusMessage: String = ""
    @Published var notificationsEnabled: Bool = true
    @Published var graphMinutes: Int = 60

    private var statusTask: Task<Void, Never>? = nil
    private var historyTask: Task<Void, Never>? = nil

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
                alerts.insert(AlertEvent(timestampMs: Int64(Date().timeIntervalSince1970 * 1000), message: message), at: 0)
                // schedule a local notification for the alert if authorized
                if notificationsEnabled {
                    scheduleNotification(body: message)
                }
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

    // MARK: - Notifications
    func requestNotificationAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                // keep toggle in sync with actual granted state
                self.notificationsEnabled = granted
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

    func checkNotificationAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationsEnabled = (settings.authorizationStatus == .authorized)
            }
        }
    }

    func scheduleNotification(body: String) {
        guard notificationsEnabled else { return }
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "AlertCore"
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        center.add(req) { error in
            if let e = error {
                print("Failed to schedule notification: \(e)")
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
