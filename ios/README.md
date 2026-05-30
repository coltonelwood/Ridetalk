# RideTalk — iOS app

SwiftUI iPhone app. Group voice (LiveKit), Supabase auth/data/realtime, MapKit location,
Sign in with Apple, background audio, push-to-talk.

## Generate & open

The Xcode project is generated from `project.yml` with [XcodeGen] (so we don't commit a
noisy `.pbxproj`):

```bash
brew install xcodegen          # one-time
cd ios
cp RideTalk/App/Secrets.example.xcconfig RideTalk/App/Secrets.xcconfig
#   ↳ fill in SUPABASE_URL_HOST, SUPABASE_ANON_KEY, LIVEKIT_URL_HOST
xcodegen generate              # creates RideTalk.xcodeproj
open RideTalk.xcodeproj
```

[XcodeGen]: https://github.com/yonyz/XcodeGen

## Dependencies (Swift Package Manager — resolved automatically)

| Package | URL | Used for |
|---|---|---|
| **Supabase** | `github.com/supabase/supabase-swift` | Auth (Apple), Postgres, Realtime, Edge Functions |
| **LiveKit**  | `github.com/livekit/client-sdk-swift` | Group voice (WebRTC/Opus) |

Both are declared in `project.yml` → XcodeGen wires them into the target.

## Signing & capabilities (in Xcode)

1. Target **RideTalk → Signing & Capabilities → Team**: pick your Apple team (or set
   `DEVELOPMENT_TEAM` in `project.yml`).
2. Confirm these capabilities are present (they're declared in `project.yml`):
   - **Sign in with Apple**
   - **Background Modes → Audio** (voice keeps running when locked)
   - **Background Modes → Location updates** (group sees you while locked)
3. Bundle ID defaults to `com.ridetalk.app` — change it to your own.
4. Run on a **real device** — microphone, AirPods routing, and background audio behave
   best on hardware (the simulator can't use AirPods mics).

## Project structure

```
RideTalk/
├── App/                 RideTalkApp (entry), AppState (coordinator), AppConfig, Secrets
├── Models/              Codable models matching the DB (UserProfile, RideRoom, …)
├── Services/
│   ├── SupabaseService      PostgREST + RPC + Realtime room channel + token fetch
│   ├── AuthService          Sign in with Apple → Supabase
│   ├── VoiceService         LiveKit room + push-to-talk publish toggling
│   ├── AudioSessionManager  AVAudioSession: AirPods, ducking, background, interruptions
│   ├── LocationService      CoreLocation → throttled room broadcast + speed/battery
│   └── PushToTalkController  PTT + VOX gate
├── ViewModels/
│   └── RideRoomViewModel     Aggregates live state + host actions for the riding UI
├── Views/
│   ├── SignInView, HomeView, ProfileView, RideRoomView, Theme
│   └── Components/           PushToTalkButton, StatusStrip, RosterView, ShareMusicView,
│                             RideMapView, EmergencyBanner, ActivityView
└── Resources/           Info.plist, RideTalk.entitlements
```

## How the pieces talk

- **Auth**: `SignInWithAppleButton` → `AuthService` mints a nonce, gets Apple's identity
  token, calls `supabase.auth.signInWithIdToken`. A `profiles` row is auto-created by a DB
  trigger.
- **Create/join**: `AppState` calls the `create_room` / `join_room` RPCs, then `enter()`
  activates the audio session, fetches a **LiveKit token** from the edge function, connects
  voice, starts location, and subscribes to the room's Realtime channel.
- **Talk**: `PushToTalkButton` → `PushToTalkController` → `VoiceService.setTransmitting()`
  toggles `room.localParticipant.setMicrophone(enabled:)`. Mic is off unless you're talking.
- **Audio**: `AudioSessionManager` keeps a `.playAndRecord`/`.voiceChat` session with
  `.allowBluetooth` (AirPods mic) + `.duckOthers` (music ducks under voice), and reacts to
  route changes/interruptions.
- **Location/music/emergency**: small JSON broadcast over the Supabase Realtime channel
  `room:<id>`; the map and banner read from `SupabaseService`'s published state.

## ⚠️ SDK version notes

The **Realtime** and **LiveKit** APIs evolve between minor versions. The code targets
recent 2.x of each, but if you pin a different version and something doesn't resolve:

- **Supabase Realtime** (`SupabaseService.subscribeToRoom`): the channel API
  (`realtimeV2.channel`, `postgresChange`, `broadcastStream`, `broadcast(event:message:)`)
  and the `AnyJSON`/`JSONObject` helpers may need small signature tweaks.
- **LiveKit** (`VoiceService`): `RoomDelegate` callback names
  (`didUpdateConnectionState`, `didUpdateSpeakingParticipants`) and
  `participant.identity?.stringValue` can differ by version.

These are isolated to the two service files and clearly commented.

## Testing the MVP

1. Two devices (or device + simulator for the non-audio bits), both signed in.
2. Device A: **Start a ride** → share the code.
3. Device B: **Join** with the code (or tap the `ridetalk://join/<CODE>` link).
4. Hold **Hold to Talk** on A → B hears it; the roster shows the speaker.
5. Open **Map** → both riders appear.
6. **I need help** on B → red banner on A with B's location.
7. Host: open **Riders** → mute/remove.
