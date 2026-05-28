import Foundation
import UIKit

@MainActor
final class PushNotificationManager {
    static let shared = PushNotificationManager()

    private let backendURLDefaultsKey = "pushBackendBaseURL"
    private let deviceTokenDefaultsKey = "pushDeviceToken"

    private init() {}

    func requestRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    func handleRegisteredDeviceToken(_ deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(token, forKey: deviceTokenDefaultsKey)
        syncRegisteredTokenToBackendIfAvailable()
    }

    func handleRegistrationFailure(_ error: Error) {
        print("Remote notification registration failed: \(error)")
    }

    func syncRegisteredTokenToBackendIfAvailable() {
        guard let token = UserDefaults.standard.string(forKey: deviceTokenDefaultsKey), !token.isEmpty else {
            return
        }

        guard let backendURLString = UserDefaults.standard.string(forKey: backendURLDefaultsKey),
              !backendURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let backendURL = URL(string: backendURLString) else {
            return
        }

        syncToken(token, to: backendURL)
    }

    private func syncToken(_ token: String, to backendURL: URL) {
        let url = backendURL.appendingPathComponent("api/devices/register")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "deviceToken": token,
            "platform": "ios",
            "bundleId": Bundle.main.bundleIdentifier ?? "com.alertcore.mobile",
            "displayName": UIDevice.current.name
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: [])

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                print("Failed to sync APNs token: \(error)")
                return
            }

            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                print("APNs token sync returned status code \(httpResponse.statusCode)")
            }
        }.resume()
    }
}
