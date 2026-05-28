# AlertCore APNs Backend

This service watches the stable ESP32 firmware API and sends repeated APNs pushes for alert events.

## What it does

- Polls `GET /api/status` on the firmware.
- Detects `alertTransition` and `manualTransition` events.
- Sends a burst of APNs notifications with the bundled sound name `AlertCoreTone.wav`.
- Registers iPhone device tokens via `POST /api/devices/register`.

## Required environment variables

See [.env.example](.env.example).

Important values:
- `FIRMWARE_BASE_URL` - the ESP32 base URL, for example `http://192.168.2.186`
- `APNS_TEAM_ID` - Apple Developer team ID
- `APNS_KEY_ID` - APNs auth key ID
- `APNS_KEY_PATH` - path to the `.p8` key file
- `APNS_TOPIC` - the iOS bundle identifier, for example `com.alertcore.mobile`

## Run

```bash
npm install
npm start
```

## Push behavior

Default burst cadence:

- Push 1 at `0s`
- Push 2 at `15s`
- Push 3 at `30s`

This matches the current sound length and gives a moderate repeated alert pattern without needing the app to remain foregrounded.

## Notes

- The iPhone app must already have the custom sound bundled in the app resources.
- APNs delivery also requires the iOS app target to be signed with push notification capability.
- The firmware API is not changed by this backend.
