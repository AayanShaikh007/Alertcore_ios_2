import Foundation
import Combine
import SwiftUI
@preconcurrency import UserNotifications
import AVFoundation
import CocoaMQTT

@MainActor
class AppState: ObservableObject {
    enum AlertTriggerMode: String, CaseIterable, Identifiable {
        case stateChange
        case farToNear

        var id: String { rawValue }

        var title: String {
            switch self {
            case .stateChange:
                return "Option 1: Alert on Distance State Changes"
            case .farToNear:
                return "Option 2: Alert Only After \"Far -> Near\" Transition"
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

    // MQTT connection settings, persisted locally
    @Published var mqttHost: String {
        didSet {
            UserDefaults.standard.set(mqttHost, forKey: "mqttHost")
            connectMqtt()
        }
    }
    @Published var mqttPort: Int {
        didSet {
            UserDefaults.standard.set(mqttPort, forKey: "mqttPort")
            connectMqtt()
        }
    }
    @Published var mqttUsername: String {
        didSet {
            UserDefaults.standard.set(mqttUsername, forKey: "mqttUsername")
            connectMqtt()
        }
    }
    @Published var mqttPassword: String {
        didSet {
            UserDefaults.standard.set(mqttPassword, forKey: "mqttPassword")
            connectMqtt()
        }
    }

    // Sensor State
    @Published var distanceCm: Int? = nil
    @Published var objectPresent: Bool = false
    @Published var thresholdCm: Int {
        didSet {
            UserDefaults.standard.set(thresholdCm, forKey: "thresholdCm")
        }
    }
    @Published var zonesCm: [Int] = []
    
    // Alerts and History
    @Published var alerts: [AlertEvent] = []
    @Published var history: [DistanceSampleDto] = []
    @Published var connected: Bool = false
    @Published var statusMessage: String = "Disconnected"
    @Published var notificationsEnabled: Bool = true
    
    // Alert Mode Settings
    @Published var alertTriggerMode: AlertTriggerMode {
        didSet {
            UserDefaults.standard.set(alertTriggerMode.rawValue, forKey: Self.alertTriggerModeDefaultsKey)
            publishAlertModeToMqtt()
        }
    }
    @Published var periodicRefreshEnabled: Bool {
        didSet {
            if oldValue != periodicRefreshEnabled {
                UserDefaults.standard.set(periodicRefreshEnabled, forKey: "periodicRefreshEnabled")
                publishPeriodicRefreshToMqtt()
            }
        }
    }
    @Published var photoOnAlertEnabled: Bool {
        didSet {
            if oldValue != photoOnAlertEnabled {
                UserDefaults.standard.set(photoOnAlertEnabled, forKey: "photoOnAlertEnabled")
                publishPhotoOnAlertToMqtt()
            }
        }
    }
    @Published var alertPresentationMode: AlertPresentationMode = .ringUntilDismissed
    @Published var autoDismissSeconds: Int {
        didSet {
            UserDefaults.standard.set(autoDismissSeconds, forKey: "autoDismissSeconds")
        }
    }
    @Published var activeAlert: AlertEvent? = nil
    @Published var alertRingEnabled: Bool = false
    @Published var graphMinutes: Int = 60
    
    // Camera Image State
    @Published var cameraImage: UIImage? = nil
    @Published var lastImageTimestampMs: Int64 = 0
    @Published var secondsUntilNextImage: Int = 300

    private var mqtt: CocoaMQTT? = nil
    private var countdownTimer: Timer? = nil
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
            return .stateChange
        }
        return mode
    }

    init() {
        self.alertTriggerMode = Self.loadAlertTriggerMode()
        self.mqttHost = UserDefaults.standard.string(forKey: "mqttHost") ?? "fd74af6a042440c3a7c395703c30d39f.s1.eu.hivemq.cloud"
        self.mqttPort = UserDefaults.standard.integer(forKey: "mqttPort") != 0 ? UserDefaults.standard.integer(forKey: "mqttPort") : 8883
        self.mqttUsername = UserDefaults.standard.string(forKey: "mqttUsername") ?? "Phone"
        self.mqttPassword = UserDefaults.standard.string(forKey: "mqttPassword") ?? "123Abcdef"
        self.thresholdCm = UserDefaults.standard.integer(forKey: "thresholdCm") != 0 ? UserDefaults.standard.integer(forKey: "thresholdCm") : 46
        self.periodicRefreshEnabled = UserDefaults.standard.object(forKey: "periodicRefreshEnabled") != nil ? UserDefaults.standard.bool(forKey: "periodicRefreshEnabled") : true
        self.photoOnAlertEnabled = UserDefaults.standard.object(forKey: "photoOnAlertEnabled") != nil ? UserDefaults.standard.bool(forKey: "photoOnAlertEnabled") : true
        self.autoDismissSeconds = UserDefaults.standard.integer(forKey: "autoDismissSeconds") != 0 ? UserDefaults.standard.integer(forKey: "autoDismissSeconds") : 30
        
        connectMqtt()
        fetchImageFromCloudflare() // Initial camera load
        startCountdownTimer()
    }

    deinit {
        countdownTimer?.invalidate()
    }

    func startPolling() async {
        connectMqtt()
        startCountdownTimer()
    }

    func stopPolling() {
        disconnectMqtt()
        countdownTimer?.invalidate()
    }

    func refreshPollingIfNeeded(isActive: Bool) async {
        if isActive {
            connectMqtt()
        } else {
            disconnectMqtt()
        }
    }

    // MARK: - MQTT Connection
    func connectMqtt() {
        disconnectMqtt()

        let clientID = "AlertCore-iOS-" + UUID().uuidString.prefix(6)
        let client = CocoaMQTT(clientID: clientID, host: mqttHost, port: UInt16(mqttPort))
        client.username = mqttUsername
        client.password = mqttPassword
        client.keepAlive = 60
        client.enableSSL = true
        client.allowUntrustCACertificate = true

        client.didConnectAck = { [weak self] mqtt, ack in
            guard let self = self else { return }
            Task { @MainActor in
                if ack == .accept {
                    self.connected = true
                    self.statusMessage = "Connected"
                    mqtt.subscribe("alertcore/status")
                    mqtt.subscribe("alertcore/camera/image")
                    
                    self.publishAlertModeToMqtt()
                    self.publishPeriodicRefreshToMqtt()
                    self.publishPhotoOnAlertToMqtt()
                } else {
                    self.connected = false
                    self.statusMessage = "Refused: \(ack)"
                }
            }
        }

        client.didDisconnect = { [weak self] mqtt, err in
            guard let self = self else { return }
            Task { @MainActor in
                self.connected = false
                self.statusMessage = "Disconnected: \(err?.localizedDescription ?? "unknown")"
            }
        }

        client.didReceiveMessage = { [weak self] mqtt, message, id in
            guard let self = self else { return }
            Task { @MainActor in
                if message.topic == "alertcore/status" {
                    self.handleStatusMessage(payload: message.string ?? "")
                } else if message.topic == "alertcore/camera/image" {
                    self.handleImageMessage(payload: message.string ?? "")
                }
            }
        }

        self.mqtt = client
        let success = client.connect()
        if !success {
            statusMessage = "Connection failed to initiate"
        } else {
            statusMessage = "Connecting..."
        }
    }

    func disconnectMqtt() {
        mqtt?.disconnect()
        mqtt = nil
    }

    // MARK: - Message Handling
    private func handleStatusMessage(payload: String) {
        guard let data = payload.data(using: .utf8) else { return }
        do {
            let decoder = JSONDecoder()
            let status = try decoder.decode(StatusDto.self, from: data)

            self.distanceCm = status.distanceCm >= 0 ? status.distanceCm : nil
            self.objectPresent = status.objectPresent
            
            if let threshold = status.thresholdCm {
                self.thresholdCm = threshold
            }

            if let zones = status.zones {
                self.zonesCm = zones
            }

            if let pr = status.periodicRefresh {
                self.periodicRefreshEnabled = (pr != 0)
            }

            if let poa = status.photoOnAlert {
                self.photoOnAlertEnabled = (poa != 0)
            }

            // Append sample to local history for chart rendering
            if status.distanceCm >= 0 {
                let sample = DistanceSampleDto(timestampMs: Int64(Date().timeIntervalSince1970 * 1000), distanceCm: status.distanceCm)
                self.history.append(sample)
                if self.history.count > 3600 {
                    self.history.removeFirst(self.history.count - 3600)
                }
            }

            let hasThresholdAlert = status.alertTransition
            let hasManualAlert = status.manualTransition ?? false
            let hasAlert = hasThresholdAlert || hasManualAlert

            if hasAlert {
                let message: String
                if hasThresholdAlert {
                    message = status.objectPresent ? "Object entered threshold at \(status.distanceCm) cm" : "Object exited threshold range"
                } else {
                    message = "Manual trigger pressed"
                }
                let eventTimestampMs = status.timestampMs ?? Int64(Date().timeIntervalSince1970 * 1000)
                handleAlert(
                    message: message,
                    signature: "\(hasThresholdAlert ? "alert" : "manual"):\(status.objectPresent):\(status.distanceCm)",
                    timestampMs: eventTimestampMs
                )
                
                // Fetch a new image on alert if the toggle is enabled
                if photoOnAlertEnabled {
                    fetchImageFromCloudflare()
                }
            }
        } catch {
            print("Failed to decode status MQTT payload: \(error)")
        }
    }

    private func handleImageMessage(payload: String) {
        fetchImageFromCloudflare()
    }

    // MARK: - Commands
    func updateThreshold(_ t: Int) {
        guard let client = mqtt, client.connState == .connected else {
            statusMessage = "Cannot update threshold: MQTT disconnected"
            return
        }
        let payload = "{\"thresholdCm\":\(t)}"
        client.publish("alertcore/cmd/threshold", withString: payload, qos: .qos1)
        self.thresholdCm = t
        statusMessage = "Threshold updated to \(t) cm"
    }

    func publishAlertModeToMqtt() {
        guard let client = mqtt, client.connState == .connected else { return }
        let modeInt = alertTriggerMode == .stateChange ? 0 : 1
        let payload = "{\"alertMode\":\(modeInt)}"
        client.publish("alertcore/cmd/alert_mode", withString: payload, qos: .qos1)
        print("[MQTT] Alert mode synced: \(alertTriggerMode.rawValue)")
    }

    func publishPeriodicRefreshToMqtt() {
        guard let client = mqtt, client.connState == .connected else { return }
        let val = periodicRefreshEnabled ? 1 : 0
        let payload = "{\"periodicRefresh\":\(val)}"
        client.publish("alertcore/cmd/periodic_refresh", withString: payload, qos: .qos1)
        print("[MQTT] Periodic refresh synced: \(periodicRefreshEnabled)")
    }

    func publishPhotoOnAlertToMqtt() {
        guard let client = mqtt, client.connState == .connected else { return }
        let val = photoOnAlertEnabled ? 1 : 0
        let payload = "{\"photoOnAlert\":\(val)}"
        client.publish("alertcore/cmd/photo_on_alert", withString: payload, qos: .qos1)
        print("[MQTT] Photo on alert synced: \(photoOnAlertEnabled)")
    }

    func triggerManualCapture() {
        guard let client = mqtt, client.connState == .connected else {
            statusMessage = "Cannot capture: MQTT disconnected"
            return
        }
        let message = CocoaMQTTMessage(topic: "alertcore/cmd/capture", payload: [1], qos: .qos1, retained: false)
        client.publish(message)
        statusMessage = "Manual capture command sent"
    }

    // MARK: - Cloudflare Image Fetch
    func fetchImageFromCloudflare() {
        guard let url = URL(string: "https://alertcore-d2.aayanshaikh770.workers.dev/latest.jpg") else { return }
        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                
                var imageTimestamp = Int64(Date().timeIntervalSince1970 * 1000)
                if let httpResponse = response as? HTTPURLResponse,
                   let lastModifiedStr = httpResponse.value(forHTTPHeaderField: "Last-Modified") {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "E, d MMM yyyy HH:mm:ss z"
                    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                    if let parsedDate = dateFormatter.date(from: lastModifiedStr) {
                        imageTimestamp = Int64(parsedDate.timeIntervalSince1970 * 1000)
                    }
                }
                
                if let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        self.cameraImage = uiImage
                        self.lastImageTimestampMs = imageTimestamp
                        self.updateSecondsUntilNextImage()
                    }
                }
            } catch {
                print("Failed to fetch camera image from Cloudflare: \(error)")
            }
        }
    }

    private func startCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.updateSecondsUntilNextImage()
            }
        }
    }
    
    private func updateSecondsUntilNextImage() {
        guard periodicRefreshEnabled else {
            self.secondsUntilNextImage = -1
            return
        }
        guard lastImageTimestampMs > 0 else {
            self.secondsUntilNextImage = 300
            return
        }
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let ageSeconds = Int((nowMs - lastImageTimestampMs) / 1000)
        let remaining = 300 - ageSeconds
        self.secondsUntilNextImage = max(0, min(300, remaining))
    }

    // MARK: - Alerts Management
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
                try? await Task.sleep(nanoseconds: UInt64(TimeInterval(self.autoDismissSeconds) * 1_000_000_000))
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
                    await self.schedulePersistentRingNotifications(content: content)
                } else {
                    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                    do {
                        try await center.add(request)
                    } catch {
                        print("Failed to deliver alert notification: \(error)")
                    }
                }
            }
        }
    }

    private func schedulePersistentRingNotifications(content: UNMutableNotificationContent) async {
        let center = UNUserNotificationCenter.current()

        if !currentAlertNotificationIds.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: currentAlertNotificationIds)
            center.removeDeliveredNotifications(withIdentifiers: currentAlertNotificationIds)
            currentAlertNotificationIds.removeAll()
        }

        let immediateRequest = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        do {
            try await center.add(immediateRequest)
        } catch {
            print("Failed to deliver immediate alert notification: \(error)")
        }
        currentAlertNotificationIds.append(immediateRequest.identifier)

        for offset in stride(from: 10, through: 300, by: 10) {
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(offset), repeats: false)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            do {
                try await center.add(request)
            } catch {
                print("Failed to schedule repeated alert notification: \(error)")
            }
            currentAlertNotificationIds.append(request.identifier)
        }

        let repeatingRequest = UNNotificationRequest(identifier: persistentAlertNotificationId, content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: true))
        do {
            try await center.add(repeatingRequest)
        } catch {
            print("Failed to schedule repeating persistent alert notification: \(error)")
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

    // MARK: - Notifications Auth
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
                self.notificationsEnabled = granted
                completion?(granted)
                if let error = error {
                    print("Notification authorization error: \(error)")
                }
            }
        }
    }

    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "AlertCore Test"
        content.body = "This is a test alert notification."
        content.sound = alertNotificationSound()
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send test notification: \(error)")
            }
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
        return "https://alertcore-d2.aayanshaikh770.workers.dev/latest.jpg"
    }

    var streamUrl: String {
        return "https://alertcore-d2.aayanshaikh770.workers.dev/latest.jpg"
    }
}
