# RideTalk — Architecture

## System overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                          iPhone — RideTalk (SwiftUI)                  │
│                                                                       │
│  AuthService ──┐                                                      │
│  (Sign in w/   │   SupabaseService (PostgREST + Realtime + Auth)      │
│   Apple)       │        │            │                  │            │
│                ▼        ▼            ▼                  ▼            │
│           Supabase    rooms /     room presence /   music_state /    │
│            Auth       profiles    location broadcast  emergency      │
│                                                                       │
│  VoiceService (LiveKit SDK) ── WebRTC/Opus ──► LiveKit SFU           │
│       ▲                                                               │
│  AudioSessionManager (AirPods routing, background audio, ducking)    │
│  LocationService (CoreLocation) ─► location broadcast                 │
│  PushToTalkController (mic publish on/off, VOX gate)                  │
└─────────────────────────────────────────────────────────────────────┘
           │                                  │
           ▼                                  ▼
┌────────────────────┐            ┌──────────────────────────────┐
│   Supabase Cloud   │            │        LiveKit Cloud         │
│  • Auth (Apple)    │            │  • SFU (group voice)         │
│  • Postgres + RLS  │            │  • Server-enforced mute      │
│  • Realtime (WS)   │            │                              │
│  • Edge Functions ─┼──signs────►│  ◄── JWT access token        │
│    (livekit-token) │   JWT      │                              │
└────────────────────┘            └──────────────────────────────┘
```

## Why these choices

| Concern | Choice | Rationale |
|---|---|---|
| Group voice | **LiveKit** (WebRTC SFU) | Purpose-built, Opus, server-side mute/kick, great Swift SDK, scales past mesh limits, works over cellular. |
| Auth | **Supabase Auth + Sign in with Apple** | One-tap, App-Store-preferred, no password storage. |
| Data + realtime | **Supabase Postgres + Realtime** | Rooms, profiles, history with Row Level Security; Realtime for presence/location/music/emergency without standing up our own WS server. |
| Voice tokens | **Supabase Edge Function** | Keep the LiveKit API secret server-side; mint short-lived, room-scoped JWTs after verifying the Supabase user. |
| Maps | **Apple MapKit** | Native, free, no extra key, great on-device performance. |

## Realtime channel design

We keep **media** (voice) on LiveKit and **lightweight signaling/state** on Supabase
Realtime. Per room (`channel: room:<roomId>`):

- **Presence**: who's connected (Supabase presence) — complements the LiveKit roster.
- **Broadcast `location`**: `{ userId, lat, lng, speed, heading, battery, ts }`.
- **Broadcast `music_state`**: `{ trackUrl, provider, isPlaying, positionMs, ts }`.
- **Broadcast `emergency`**: `{ userId, lat, lng, ts }`.

Why split media vs. state: media needs an SFU (LiveKit); state is tiny JSON that
Supabase Realtime broadcasts cheaply, and persisting some of it (location history,
music state) in Postgres is trivial.

## Voice token flow

1. App authenticates with Supabase (Apple) → has a Supabase JWT.
2. App calls edge function `livekit-token` with `{ roomId }` and the Supabase JWT.
3. Function verifies the user, checks they're a member of the room (RLS-backed query),
   then signs a **LiveKit JWT** with `roomJoin`, the room name, and the user's identity
   using `LIVEKIT_API_SECRET` (never shipped to the client).
4. App connects to LiveKit with that token. Host privileges (mute/remove) are also
   enforced server-side via the LiveKit server API from the function/host path.

## Audio session design (the heart of the app)

`AudioSessionManager` owns a single shared `AVAudioSession`:

- Category `.playAndRecord`
- Mode `.voiceChat` (echo cancellation, tuned for two-way voice)
- Options: `[.allowBluetooth, .allowBluetoothA2DP, .duckOthers, .defaultToSpeaker]`
  - `.allowBluetooth` → AirPods mic (HFP).
  - `.duckOthers` → the rider's own music ducks under voice.
- Observes `AVAudioSession.routeChangeNotification` and `interruptionNotification`
  to react to AirPods connect/disconnect and phone calls.
- Background audio (`UIBackgroundModes: audio`) keeps the session alive when locked.

**Push-to-talk** is implemented at the *publish* layer: we keep the audio session up but
toggle LiveKit's `setMicrophoneEnabled(true/false)` so we only transmit while the button
is held (or while VOX detects speech). This saves battery and bandwidth and is privacy-
preserving (no accidental hot mic).

## Data model summary

See `supabase/migrations/` for the authoritative schema. Tables:

- `profiles` — 1:1 with `auth.users`; name, avatar, scooter type.
- `rooms` — code, host, status, created/ended timestamps.
- `room_members` — join table (room ↔ user), role (host/rider), muted flag.
- `ride_locations` — optional persisted location pings (for history / late joiners).
- `music_states` — last-known shared track per room.

RLS ensures a rider can only read/write rooms they're a member of, and only the host can
mutate host-only fields.

## Failure & reconnect behavior

- **Network drop**: LiveKit SDK auto-reconnects; Supabase Realtime resubscribes. UI shows
  a "Reconnecting…" state derived from both connection states.
- **Interruption (phone call)**: audio session is interrupted; on resume we reactivate
  the session and re-enable mic if PTT/VOX wants it.
- **Backgrounding**: voice continues (background audio); location continues if the user
  granted "Always" or while-in-use with background updates.

## Security

- LiveKit secret stays server-side (edge function only).
- Supabase RLS on every table.
- Short-lived LiveKit tokens scoped to a single room + identity.
- Location is room-scoped and ephemeral; persisted pings are RLS-protected and can be
  purged when a room ends.
