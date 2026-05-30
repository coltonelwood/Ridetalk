# RideTalk — LiveKit (voice) setup notes

RideTalk uses **LiveKit** (a WebRTC SFU) for low-latency group voice. The app never holds
the LiveKit API secret — a Supabase **edge function** mints short-lived, room-scoped JWTs.

## 1. Get a LiveKit project
- Easiest: **LiveKit Cloud** (https://livekit.io) → create a project → copy:
  - `API Key`  → `LIVEKIT_API_KEY`
  - `API Secret` → `LIVEKIT_API_SECRET`
  - `Project URL` (e.g. `wss://yourproj.livekit.cloud`) → `LIVEKIT_URL`
- Or self-host the open-source LiveKit server and point `LIVEKIT_URL` at it.

## 2. Configure the token function (server-side secret)
```bash
supabase secrets set \
  LIVEKIT_API_KEY=APIxxxx \
  LIVEKIT_API_SECRET=secretxxxx \
  LIVEKIT_URL=wss://yourproj.livekit.cloud
supabase functions deploy livekit-token
```
The function (`supabase/functions/livekit-token`):
1. verifies the caller's Supabase session,
2. checks they're a member of the requested room (RLS-backed),
3. signs a LiveKit JWT with `roomJoin` scoped to `room == roomId` and `identity == userId`.

## 3. Configure the app
In `ios/RideTalk/App/Secrets.xcconfig` set `LIVEKIT_URL_HOST` (host only, e.g.
`yourproj.livekit.cloud`). The app actually connects using the `url` returned by the token
function, so this is a default/fallback.

## 4. How the app uses it
- On entering a room, `AppState.enter()` calls the function, then
  `VoiceChatService.connect(url:token:identity:)`.
- **Push-to-talk** toggles `room.localParticipant.setMicrophone(enabled:)` — the mic is off
  unless the rider is talking (battery + privacy + bandwidth).
- `AudioSessionManager` configures `AVAudioSession` (`.playAndRecord` / `.voiceChat`,
  `.allowBluetooth`, `.duckOthers`) **before** connecting so AirPods route correctly and
  music ducks under voice.

## Audio session ownership ⚠️
LiveKit also manages an `AVAudioSession`. RideTalk configures the session for voice +
AirPods + ducking via `AudioSessionManager`; we activate it before connecting. If you bump
the LiveKit SDK and hear routing/ducking regressions, reconcile here — LiveKit exposes
hooks (`AudioManager`) to customize or defer its session configuration.

## SDK version sensitivity ⚠️
`VoiceChatService` targets LiveKit Swift 2.x. If a version bump changes `RoomDelegate`
callback names (`didUpdateConnectionState`, `didUpdateSpeakingParticipants`) or
`participant.identity?.stringValue`, adjust that one file.

## Scaling notes
- An SFU (LiveKit) scales well past peer-to-peer mesh limits — fine for crews of 5–20+.
- Region-route for latency in production; consider per-ride room TTLs and server-side
  mute/kick via the LiveKit server API (Phase 1 moderation hardening).
