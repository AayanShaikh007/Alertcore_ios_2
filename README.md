# AlertCore iOS App

A SwiftUI implementation of the AlertCore mobile app for iOS. This is the companion app to the Android app and the ESP32 firmware.

## Directory Structure

```
alertcore_ios/
├── AlertCoreApp/
│   ├── App/                    # App entry point and navigation
│   │   ├── AlertCoreApp.swift
│   │   └── AppState.swift
│   ├── Network/                # API client
│   │   └── NetworkClient.swift
│   ├── Models/                 # Data models and DTOs
│   │   └── Models.swift
│   ├── Views/                  # UI screens
│   │   ├── DashboardView.swift
│   │   ├── CameraView.swift
│   │   ├── AlertsView.swift
│   │   └── SettingsView.swift
│   ├── Components/             # Reusable UI components
│   │   └── CameraWebView.swift
│   └── Resources/              # Assets, images, etc.
├── README.md
└── .gitignore
```

## Quick Start (on macOS with Xcode)

1. **Create a new Xcode project:**
   - Open Xcode
   - File → New → Project
   - Choose **App** template for iOS
   - Select **SwiftUI** and **Swift**
   - Product Name: `AlertCore`
   - Organization Identifier: `com.alertcore`

2. **Add source files:**
   - Copy all files from `AlertCoreApp/` into your Xcode project
   - Ensure they are added to the app target

3. **Configure deployment:**
   - Set deployment target to **iOS 16+**
   - Set bundle identifier (e.g., `com.alertcore.mobile`)

4. **Allow HTTP (if using local ESP32 on LAN):**
   - Open `Info.plist` in Xcode
   - Add `App Transport Security Settings`:
     - `Allow Arbitrary Loads: YES` (or add a domain exception for your ESP32 IP)

5. **Build and run:**
   - Select a simulator or connected device
   - Press Cmd+R to build and run

## Building an IPA

To create a distributable `.ipa` file for AltStore or TestFlight:

1. Product → Archive
2. In the Organizer window, select your archive
3. Click Distribute App
4. Choose **Ad Hoc** (for AltStore) or **App Store** (for TestFlight)
5. Follow Apple's signing and provisioning steps
6. Save the `.ipa` file

**Requirements:**
- Apple Developer account (free tier works for AltStore)
- Valid provisioning profile
- Device to be added to the provisioning profile

## ESP32 API Endpoints Expected

The app expects the ESP32 to provide:
- `GET /api/status` — current distance, object present, alert/manual transition flags
- `GET /api/history?minutes=60` — historical distance samples
- `POST /api/threshold` — update distance threshold
- `GET /api/health` — health check
- Stream: `http://<ip>:<port+1>/stream` — MJPEG camera stream

## Features

- **Dashboard:** Real-time distance display and alert status
- **Camera:** Live MJPEG stream and portal access
- **Alerts:** Recent alert history with timestamps
- **Settings:** Configure device IP, port, and notification preferences

## Compatibility

- iOS 16.0+
- Requires local network connection to ESP32
- Works over HTTP (WiFi LAN)

## Notes

- This is a SwiftUI app targeting iOS 16+
- HTTP cleartext is required for LAN communication with the ESP32
- The app polls the ESP32 status every 1 second and history every 3 seconds (configurable in `AppState`)
- Manual button press notifications are included if the firmware supports the `manualTransition` flag
