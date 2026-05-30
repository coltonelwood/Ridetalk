# RideTalk — iOS app

SwiftUI iPhone app: group voice (LiveKit), Supabase auth/data/realtime, MapKit live
location, Sign in with Apple, background audio, push-to-talk, SOS, ride recording.

## Generate & open

The Xcode project is generated from `project.yml` with [XcodeGen] (so we don't commit a
noisy `.pbxproj`):

```bash
brew install xcodegen
cd ios
cp RideTalk/App/Secrets.example.xcconfig RideTalk/App/Secrets.xcconfig
#   ↳ fill in SUPABASE_URL_HOST, SUPABASE_ANON_KEY, LIVEKIT_URL_HOST
xcodegen generate
open RideTalk.xcodeproj
```

[XcodeGen]: https://github.com/yonyz/XcodeGen

## Dependencies (Swift Package Manager — auto-resolved)

| Package | URL | Used for |
|---|---|---|
| **Supabase** | `github.com/supabase/supabase-swift` | Auth (Apple), Postgres, Realtime, Functions |
| **LiveKit** | `github.com/livekit/client-sdk-swift` | Group voice (WebRTC/Opus) |

Declared in `project.yml`.

## Signing & capabilities (Xcode)

1. Target → **Signing & Capabilities → Team** (or set `DEVELOPMENT_TEAM` in `project.yml`).
2. Capabilities (declared in `project.yml`): **Sign in with Apple**, **Background Modes →
   Audio + Location updates**.
3. Bundle ID defaults to `com.ridetalk.app` — change to your own.
4. Run on a **real device** (mic, AirPods, background audio, GPS behave best on hardware).

## Structure

```
App/        RideTalkApp · AppState (coordinator) · AppConfig · Secrets
Models/     AppUser/RiderProfile · RideRoom · RoomMember · LiveLocation · SOSAlert
            · SharedMusicLink · QuickMessage · RideRecording/RideStats · LiveKitToken
Services/   SupabaseManager (client + per-room Realtime state)
            AuthService · RideRoomService · VoiceChatService · AudioSessionManager
            LocationService · MusicLinkService · SOSService · RideRecordingService
            PushToTalkController
ViewModels/ ActiveRideViewModel
Views/      SignInView · HomeView · CreateRoomView · JoinRoomView · ActiveRideView
            MapView · MusicLinkView · SOSView · RideSummaryView · RideHistoryView · ProfileView
            Components/ PushToTalkButton · StatusStrip · RosterView · Banners
                        · QuickMessagesView · ActivityView · Theme
```

## How the pieces talk

- **Auth** — `SignInWithAppleButton` → `AuthService` (nonce + identity token) →
  `supabase.auth.signInWithIdToken`. DB triggers create `users` + `rider_profiles`.
- **Enter a ride** — `AppState.enter()`: activate the audio session (AirPods) → fetch a
  **LiveKit token** (edge function) → connect `VoiceChatService` → start `LocationService`
  (background updates) → start `RideRecordingService` → `SupabaseManager.subscribe(to:)`.
- **Realtime** — `SupabaseManager` owns the `room:<id>` channel: location via **broadcast**
  (instant) + `live_locations` upsert (last-known); roster/music/SOS/quick-messages/room via
  **Postgres change** + cheap refetch. Published state drives `ActiveRideViewModel`.
- **Talk** — `PushToTalkButton` → `PushToTalkController` → `VoiceChatService` toggles the
  mic publish. VOX is an energy-gate placeholder (Phase 1 wires real metering).
- **Audio** — `AudioSessionManager`: `.playAndRecord`/`.voiceChat`, `.allowBluetooth`
  (AirPods mic), `.duckOthers` (music ducks under voice), route + interruption handling.
- **Location/SOS/recording** — `LocationService` feeds `RideRecordingService` (distance,
  speed) and publishes `live_locations`. `SOSService` raises/resolves alerts (priority
  full-screen via `SOSView`). Separation alerts are computed against the lead rider.

## ⚠️ SDK version notes

Realtime + LiveKit APIs evolve between minor versions. Anything that might need a tweak is
isolated to two files and clearly commented:
- **Supabase Realtime** — `SupabaseManager` (`realtimeV2.channel`, `postgresChange`,
  `broadcastStream`, `broadcast`, and the `AnyJSON`/`JSONObject` helpers).
- **LiveKit** — `VoiceChatService` (`RoomDelegate` callbacks, `participant.identity`).

Deployment target is **iOS 16**; the iOS-17 `symbolEffect` and two-parameter `onChange`
are guarded / avoided.

## Testing the MVP

1. Two devices, both signed in. A: **Start a ride** → share the code.
2. B: **Join** with the code (or the `ridetalk://join/<CODE>` link).
3. Hold **Talk** on A → B hears it; roster shows the speaker; B's music ducks.
4. **Map** → both riders with direction/speed. Host: make B the **lead rider**.
5. **SOS** on B → priority full-screen alert on A with directions.
6. **Quick** → send "Slow down" (priority). Leave → see the **Ride Summary**.
