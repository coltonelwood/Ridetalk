# RideTalk — Possible Crash / Rider-Down Detection

> **This is best-effort "possible crash" detection — NOT guaranteed emergency detection.**
> It never contacts emergency services. If the rider doesn't cancel the countdown, RideTalk
> sends an **SOS to the ride group** labeled "possible crash / rider down (unconfirmed)".

## How it works

`CrashDetectionService` combines three signals (all on-device, only while a ride is active):

1. **Impact** — accelerometer (CoreMotion) magnitude spikes past a g-threshold.
2. **Sudden stop** — speed was at riding pace, then dropped to ~0.
3. **No movement** — the rider stays stopped for a confirmation window.

When **(1 or 2)** is followed by **(3)**, a possible rider-down event fires:

```
detect → full-screen "Are you OK?" countdown (30s, loud alarm + haptics)
   ├─ rider taps "I'm OK"            → cancel, no SOS
   ├─ rider taps "Send SOS now"      → SOS immediately
   └─ 30s elapse with no response    → SOS to ride room (kind = possible_crash) + GPS
```

Other riders receive the alert as a **priority full-screen SOS** + a red banner labeled
"Possible crash — <name> may be down", and can open **fastest-route directions** to them.

## Sensitivity

Set in **Profile → Rider-down detection**. Higher sensitivity = lower thresholds = trips
more easily (more false positives).

| Level | Impact (g) | "Was riding" speed | Confirm window |
|---|---|---|---|
| Low | 4.0 g | 15 mph | 10 s |
| Medium | 3.0 g | 10 mph | 8 s |
| High | 2.2 g | 6.7 mph | 6 s |

Settings (enabled + sensitivity) persist locally in `UserDefaults`.

## Testing without riding (demo states)

- **Profile → Rider-down detection → "Simulate rider-down (test)"** — runs the full
  countdown immediately. Outside an active ride it's a **DEMO** (clearly labeled; no SOS is
  sent).
- **In a ride (DEBUG builds)** — a small "Simulate rider-down" button on the Active Ride
  screen fires the **real** path, so you can verify the SOS reaches the group.
- The accelerometer is unavailable in the iOS Simulator; speed-based detection still runs,
  and the simulate buttons work everywhere.

## App Store framing

- Always labeled **"possible crash detection"**, with the disclaimer that it's a best-effort
  heuristic and does not contact emergency services.
- Default ON at medium sensitivity; one toggle to disable.
- `NSMotionUsageDescription` explains motion use in-context.
- For production, bundle a custom looping alarm sound and consider the **Critical Alerts**
  entitlement so the alarm sounds through silent mode / a locked device.

## Code map

| Piece | File |
|---|---|
| Detector (CoreMotion + speed heuristics, sensitivity, settings) | `ios/RideTalk/Services/CrashDetectionService.swift` |
| Event + sensitivity models | `ios/RideTalk/Models/CrashDetection.swift` |
| Countdown UI + alarm | `ios/RideTalk/Views/RiderDownCountdownView.swift` |
| Wiring (start/stop, present, confirm→SOS) | `ios/RideTalk/App/AppState.swift` |
| Settings UI | `ios/RideTalk/Views/ProfileView.swift` (`CrashSettingsSection`) |
| SOS labeling | `ios/RideTalk/Models/SOSAlert.swift`, `Views/Components/Banners.swift`, `Views/SOSView.swift` |
| DB column | `supabase/migrations/0004_crash_detection.sql` (`sos_alerts.alert_kind`) |
