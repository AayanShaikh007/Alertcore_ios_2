import Foundation
import Combine
import SwiftUI
import UserNotifications
import AVFoundation
import Network

@MainActor
class AppState: ObservableObject {
    enum AlertTriggerMode: String, CaseIterable, Identifiable {
        case leavingThreshold
        case enteringThreshold
        case both

        var id: String { rawValue }

        var title: String {
            switch self {
            case .leavingThreshold:
                return "Leaving"
            case .enteringThreshold:
                return "Entering"
            case .both:
                return "Both"
            }
        }
    }

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

    @Published var ip: String = "192.168.8.50"
    @Published var port: Int = 80
    @Published var distanceCm: Int? = nil
    @Published var objectPresent: Bool = false
    @Published var alerts: [AlertEvent] = []
    @Published var history: [DistanceSampleDto] = []
    @Published var connected: Bool = false
    @Published var statusMessage: String = ""
    @Published var notificationsEnabled: Bool = true
    @Published var alertTriggerMode: AlertTriggerMode {
        didSet {
            UserDefaults.standard.set(alertTriggerMode.rawValue, forKey: Self.alertTriggerModeDefaultsKey)
        }
    }
    @Published var alertPresentationMode: AlertPresentationMode = .ringUntilDismissed
    @Published var activeAlert: AlertEvent? = nil
    @Published var alertRingEnabled: Bool = false
    @Published var graphMinutes: Int = 60

    private var statusTask: Task<Void, Never>? = nil
    private var historyTask: Task<Void, Never>? = nil
    private var alertAutoStopTask: Task<Void, Never>? = nil
    private var alertPlayer: AVAudioPlayer? = nil
    private var lastAlertSignature: String? = nil
    private var lastAlertAt: Date? = nil
    private var lastAlertTimestampMs: Int64? = nil
    private var currentAlertNotificationIds: [String] = []

    private static let alertTriggerModeDefaultsKey = "alertTriggerMode"
    private let persistentAlertNotificationId = "AlertCorePersistentAlert"
    private let alertToneFileName = "AlertCoreTone.wav"
    private let alertAutoDismissSeconds: TimeInterval = 10

    private static func loadAlertTriggerMode() -> AlertTriggerMode {
        guard let rawValue = UserDefaults.standard.string(forKey: Self.alertTriggerModeDefaultsKey),
              let mode = AlertTriggerMode(rawValue: rawValue) else {
            return .leavingThreshold
        }

        return mode
    }

    init() {
        alertTriggerMode = Self.loadAlertTriggerMode()
    }

    func startPolling() async {
        stopPolling()
        triggerLocalNetworkPrivacyPrompt()
        
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

    func refreshPollingIfNeeded(isActive: Bool) async {
        if isActive {
            await startPolling()
        } else {
            stopPolling()
        }
    }

    func statusPollMs() -> Int { 
        // poll slower when disconnected to give the network/ESP32 room to recover
        connected ? 500 : 2000 
    }
    func historyPollMs() -> Int { connected ? 3000 : 10000 }

    func pollStatus() async {
        do {
            let s = try await NetworkClient.shared.fetchStatus(ip: ip, port: port)
            connected = true
            statusMessage = "Connected"
            distanceCm = s.distanceCm >= 0 ? s.distanceCm : nil
            objectPresent = s.objectPresent

            let hasThresholdAlert = s.alertTransition && shouldPresentThresholdAlert(for: s)
            let hasAlert = hasThresholdAlert || (s.manualTransition ?? false)
            if hasAlert {
                let message: String
                if hasThresholdAlert {
                    message = s.objectPresent ? "Object entered threshold at \(s.distanceCm) cm" : "Object exited threshold range"
                } else {
                    message = "Manual trigger pressed"
                }
                let eventTimestampMs = s.timestampMs ?? Int64(Date().timeIntervalSince1970 * 1000)
                handleAlert(
                    message: message,
                    signature: "\(hasThresholdAlert ? "alert" : "manual"):\(s.objectPresent):\(s.distanceCm)",
                    timestampMs: eventTimestampMs
                )
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

    private func shouldPresentThresholdAlert(for status: StatusDto) -> Bool {
        guard status.alertTransition else { return false }

        switch alertTriggerMode {
        case .leavingThreshold:
            return !status.objectPresent
        case .enteringThreshold:
            return status.objectPresent
        case .both:
            return true
        }
    }

    func acknowledgeActiveAlert() {
        activeAlert = nil
        alertRingEnabled = false
        alertAutoStopTask?.cancel()
        alertAutoStopTask = nil
        stopAlertTone()
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [persistentAlertNotificationId])
        center.removeDeliveredNotifications(withIdentifiers: [persistentAlertNotificationId])

        if !currentAlertNotificationIds.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: currentAlertNotificationIds)
            center.removeDeliveredNotifications(withIdentifiers: currentAlertNotificationIds)
            currentAlertNotificationIds.removeAll()
        }
    }

    private func handleAlert(message: String, signature: String, timestampMs: Int64) {
        if lastAlertTimestampMs == timestampMs {
            return
        }

        let now = Date()
        if let lastAlertSignature, let lastAlertAt, lastAlertSignature == signature, now.timeIntervalSince(lastAlertAt) < 0.75 {
            return
        }

        lastAlertSignature = signature
        lastAlertAt = now
        lastAlertTimestampMs = timestampMs

        let alert = AlertEvent(timestampMs: Int64(now.timeIntervalSince1970 * 1000), message: message)
        alerts.insert(alert, at: 0)
        presentAlert(alert: alert)
    }

    private func presentAlert(alert: AlertEvent) {
        activeAlert = alert
        alertRingEnabled = true
        playAlertTone(persistent: alertPresentationMode == .ringUntilDismissed)

        if alertPresentationMode == .autoDismiss {
            alertAutoStopTask?.cancel()
            alertAutoStopTask = Task { [weak self] in
                guard let self = self else { return }
                try? await Task.sleep(nanoseconds: UInt64(self.alertAutoDismissSeconds * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.stopAlertTone()
                    self.activeAlert = nil
                    self.alertRingEnabled = false
                }
            }
        }

        scheduleAlertNotification(message: alert.message, persistent: alertPresentationMode == .ringUntilDismissed)
    }

    private func scheduleAlertNotification(message: String, persistent: Bool) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            Task { @MainActor in
                guard self.notificationsEnabled else { return }
                guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional || settings.authorizationStatus == .ephemeral else {
                    return
                }

                let sound = self.alertNotificationSound()
                let content = UNMutableNotificationContent()
                content.title = "AlertCore"
                content.body = message
                content.sound = sound

                if persistent {
                    self.schedulePersistentRingNotifications(content: content)
                } else {
                    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                    center.add(request) { error in
                        if let error = error {
                            print("Failed to deliver alert notification: \(error)")
                        }
                    }
                }
            }
        }
    }

    private func schedulePersistentRingNotifications(content: UNMutableNotificationContent) {
        let center = UNUserNotificationCenter.current()

        if !currentAlertNotificationIds.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: currentAlertNotificationIds)
            center.removeDeliveredNotifications(withIdentifiers: currentAlertNotificationIds)
            currentAlertNotificationIds.removeAll()
        }

        let immediateRequest = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(immediateRequest) { error in
            if let error = error {
                print("Failed to deliver immediate alert notification: \(error)")
            }
        }
        currentAlertNotificationIds.append(immediateRequest.identifier)

        for offset in stride(from: 10, through: 300, by: 10) {
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(offset), repeats: false)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            center.add(request) { error in
                if let error = error {
                    print("Failed to schedule repeated alert notification: \(error)")
                }
            }
            currentAlertNotificationIds.append(request.identifier)
        }

        let repeatingRequest = UNNotificationRequest(identifier: persistentAlertNotificationId, content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: true))
        center.add(repeatingRequest) { error in
            if let error = error {
                print("Failed to schedule repeating persistent alert notification: \(error)")
            }
        }
        currentAlertNotificationIds.append(persistentAlertNotificationId)
    }

    private func stopAlertTone() {
        alertPlayer?.stop()
        alertPlayer = nil
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    private func playAlertTone(persistent: Bool) {
        alertAutoStopTask?.cancel()
        alertAutoStopTask = nil

        guard let toneURL = prepareAlertToneFile() else {
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)

            let player = try AVAudioPlayer(contentsOf: toneURL)
            player.numberOfLoops = persistent ? -1 : 0
            player.volume = 1.0
            player.prepareToPlay()
            player.play()
            alertPlayer = player
            alertRingEnabled = true

            if !persistent {
                alertAutoStopTask = Task { [weak self] in
                    guard let self = self else { return }
                    try? await Task.sleep(nanoseconds: UInt64(self.alertAutoDismissSeconds * 1_000_000_000))
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        self.stopAlertTone()
                        self.alertRingEnabled = false
                    }
                }
            }
        } catch {
            print("Failed to start alert tone playback: \(error)")
        }
    }

    private func alertNotificationSound() -> UNNotificationSound {
        let _ = prepareAlertToneFile()
        return UNNotificationSound(named: UNNotificationSoundName(alertToneFileName))
    }

    private func prepareAlertToneFile() -> URL? {
        do {
            if let bundledToneURL = Bundle.main.url(forResource: "AlertCoreTone", withExtension: "wav") {
                return bundledToneURL
            }

            let libraryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
            let soundsDirectory = libraryURL?.appendingPathComponent("Sounds", isDirectory: true)
            guard let soundsDirectory else { return nil }
            try FileManager.default.createDirectory(at: soundsDirectory, withIntermediateDirectories: true)

            let toneURL = soundsDirectory.appendingPathComponent(alertToneFileName)
            if FileManager.default.fileExists(atPath: toneURL.path) {
                return toneURL
            }

            let sampleRate: Int = 44_100
            let durationSeconds: Int = 10
            let totalSamples = sampleRate * durationSeconds
            var pcm = Data()
            pcm.reserveCapacity(totalSamples * 2)

            for sampleIndex in 0..<totalSamples {
                let progress = Double(sampleIndex) / Double(sampleRate)
                let tonePhase = progress.truncatingRemainder(dividingBy: 1.0)
                let isTone = tonePhase < 0.35 || (tonePhase >= 0.5 && tonePhase < 0.85)
                let fadeWindow = 0.02
                let envelope: Double
                if tonePhase < fadeWindow {
                    envelope = tonePhase / fadeWindow
                } else if tonePhase < 0.35 - fadeWindow {
                    envelope = 1.0
                } else if tonePhase < 0.35 {
                    envelope = max(0.0, (0.35 - tonePhase) / fadeWindow)
                } else if tonePhase < 0.5 {
                    envelope = 0.0
                } else if tonePhase < 0.5 + fadeWindow {
                    envelope = (tonePhase - 0.5) / fadeWindow
                } else if tonePhase < 0.85 - fadeWindow {
                    envelope = 1.0
                } else if tonePhase < 0.85 {
                    envelope = max(0.0, (0.85 - tonePhase) / fadeWindow)
                } else {
                    envelope = 0.0
                }

                let amplitude = isTone ? 0.45 * envelope : 0.0
                let frequency = 880.0
                let sample = Int16(sin(2.0 * Double.pi * frequency * progress) * amplitude * Double(Int16.max))
                pcm.appendInt16LE(sample)
            }

            var wav = Data()
            let subchunk2Size = UInt32(pcm.count)
            let chunkSize = UInt32(36) + subchunk2Size

            wav.appendASCII("RIFF")
            wav.appendUInt32LE(chunkSize)
            wav.appendASCII("WAVE")
            wav.appendASCII("fmt ")
            wav.appendUInt32LE(16)
            wav.appendUInt16LE(1)
            wav.appendUInt16LE(1)
            wav.appendUInt32LE(UInt32(sampleRate))
            wav.appendUInt32LE(UInt32(sampleRate * 2))
            wav.appendUInt16LE(2)
            wav.appendUInt16LE(16)
            wav.appendASCII("data")
            wav.appendUInt32LE(subchunk2Size)
            wav.append(pcm)

            try wav.write(to: toneURL, options: .atomic)
            return toneURL
        } catch {
            print("Failed to prepare alert tone file: \(error)")
            return nil
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

    /// Triggers the iOS Local Network privacy prompt by starting a dummy browse.
    private func triggerLocalNetworkPrivacyPrompt() {
        let browser = NWBrowser(for: .bonjour(type: "_http._tcp", domain: nil), using: .tcp)
        browser.stateUpdateHandler = { state in
            if case .failed = state {
                browser.cancel()
            }
        }
        browser.start(queue: .main)
        
        // cancel after a short delay; the prompt will have been triggered
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            browser.cancel()
        }
    }
}

private extension Data {
    mutating func appendASCII(_ string: String) {
        if let data = string.data(using: .ascii) {
            append(data)
        }
    }

    mutating func appendUInt16LE(_ value: UInt16) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }

    mutating func appendUInt32LE(_ value: UInt32) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }

    mutating func appendInt16LE(_ value: Int16) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
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
