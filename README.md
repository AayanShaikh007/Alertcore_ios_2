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

## Codemagic Setup

This repo now includes a Codemagic-friendly scaffold via [project.yml](project.yml) and [codemagic.yaml](codemagic.yaml).

What this gives you:
- XcodeGen can generate the Xcode project from the source tree.
- Codemagic can archive the app from the generated project.

Important limitation:
- The current Codemagic workflow only produces an `.xcarchive`.
- The workflow now also packages the archived `.app` into an `.ipa` artifact.
- That IPA is intended for AltStore/AltServer, which will sign it during install.
- If Codemagic fails at the package step, the archive is still usable and the issue is usually the archive path or app name.
- If AltStore shows `Encountered unknown tag html`, you are almost certainly pointing it at an HTML page or redirect instead of the raw IPA bytes.

If you want to use Codemagic for CI right now, the workflow is set up to generate the project, archive the app, and package an IPA artifact for AltStore.

### AltStore-specific notes

If you are using AltStore, keep these points in mind:

1. The Codemagic workflow builds an unsigned archive and then packages the `.app` into an `.ipa`.
2. AltStore/AltServer performs signing during installation, so CI-side code signing is not required for this path.
3. The workflow now auto-detects the `.app` name inside the archive and validates that `Payload/<App>.app/Info.plist` exists in the IPA.
4. If AltStore says the data is not in the correct format, the IPA is usually malformed (missing `Payload` or missing `.app` bundle inside it).
5. Do not paste a Codemagic artifact page URL into AltStore. Download the `.ipa` file first, then install that file from the iOS Files app or another direct file source.

### AltStore error: "Encountered unknown tag html"

If you see errors like "Encountered unknown tag html" or plist parse failures, AltStore is usually reading an HTML page (login/redirect page) instead of the IPA binary.

Use this flow:

1. In Codemagic, download the `AlertCoreApp.ipa` artifact to your device/files first.
2. Do not use a private artifact page URL directly inside AltStore sources.
3. In iOS Files app, tap Share on the downloaded `.ipa` and choose AltStore.

For URL-based AltStore sources, host the IPA at a direct public file URL that returns the IPA bytes (not an HTML page).

For local verification, run the same IPA checks used by Codemagic:

```bash
./scripts/validate_ipa.sh /path/to/AlertCoreApp.ipa
```

## Building an IPA

To create a distributable `.ipa` file for AltStore or TestFlight from the archive:

1. Product → Archive
2. In the Organizer window, select your archive
3. Click Distribute App
4. Choose **Ad Hoc** (for AltStore) or **App Store** (for TestFlight)
5. Follow Apple's signing and provisioning steps
6. Save the `.ipa` file

**Requirements:**
- A Mac with Xcode to export the archive into an `.ipa`
- Apple ID signing can work for AltStore, but the export step is still separate from Codemagic's archive output
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
