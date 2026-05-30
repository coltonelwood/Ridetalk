# RideTalk — Product Spec

**Version:** MVP 0.1
**Platform:** iPhone (iOS 16+), SwiftUI
**One-liner:** Group walkie-talkie + live location + music sync for scooter/bike riders, hands-free over cellular.

---

## 1. Problem & audience

Groups of e-scooter / e-bike / moped riders want to talk while riding, the way a
friend group on a road trip talks in a car. Today they use:

- **Phone calls / FaceTime** — 1:1 or clunky for groups, no push-to-talk, no riding UI.
- **Bluetooth intercoms** (Cardo/Sena) — expensive hardware, ~limited range, pairing pain.
- **Discord/Zello** — not riding-optimized, fiddly UI, no group location, no ride context.

**RideTalk** is built for the *moving rider wearing AirPods*: glanceable, big-button,
hands-free, always-on group voice that works as long as everyone has cell signal —
plus shared location and loosely-synced music.

### Primary persona
"**Group ride organizer**" — plans a Saturday ride with 4–10 friends, wants everyone on
one channel, wants to see where everyone is, wants a panic button if someone goes down.

### Secondary persona
"**The rider**" — joins via a link, taps one big button, talks, rides. Minimal config.

---

## 2. Goals & non-goals

### MVP goals
1. Frictionless group voice that works at city-to-city distance (cellular, not BLE).
2. Hands-free operation with AirPods, including while the screen is locked.
3. A riding UI safe enough to glance at: huge targets, minimal taps.
4. Live group location + emergency button.
5. Legal, App-Store-safe music *sync* (not rebroadcast).

### Non-goals (MVP)
- Video.
- Turn-by-turn navigation (we show the group on a map, not routing).
- Rebroadcasting Apple Music/Spotify audio (legally blocked — see compliance).
- Android (fast-follow, see roadmap).
- True offline mesh (BLE fallback is a roadmap item, internet is the priority).

---

## 3. Feature spec

### 3.1 Accounts & profile
- **Sign in with Apple** only for MVP (one tap, App-Store-preferred, privacy-friendly).
- Profile: `display_name`, `avatar` (photo), `scooter_type` (free text + preset list).
- **Saved groups**: rooms the rider has joined are remembered for quick rejoin.

### 3.2 Ride rooms
- **Create**: host taps "Start a ride" → room created with a 6-char **room code** and a
  shareable **invite link** (`ridetalk://join/<code>` + an https universal link fallback).
- **Join**: enter code, tap an invite link, or pick a saved group.
- **Roster**: live list of connected riders (name, avatar, speaking indicator, muted flag).
- **Host controls**: mute a rider (server-enforced), remove a rider, end the ride.
- Room lifecycle: `active` → `ended`. Ended rooms are kept for ride history.

### 3.3 Walkie-talkie voice
- Transport: **LiveKit** (WebRTC SFU), **Opus** codec, mono, tuned for low latency.
- **Push-to-talk (PTT)**: big button; hold to transmit, release to stop. Mic is muted
  (publish disabled) otherwise → battery + privacy + bandwidth win.
- **Voice-activated (VOX) mode**: optional; mic stays live, local energy gate avoids
  publishing silence. Togglable per session.
- **AirPods**: audio session configured so the AirPods/earbud mic is used and audio
  routes to AirPods; route changes (plugging/unplugging) handled gracefully.
- **Background**: `UIBackgroundModes: audio` so voice keeps working with the screen
  locked / app backgrounded.
- **Ducking**: when any remote rider is speaking, the rider's *own* music (Sync Mode)
  is ducked via the shared audio session (`.duckOthers`).

### 3.4 Music sync (compliant)
- Host pastes/share-sheets an **Apple Music or Spotify track link**.
- App broadcasts a `music_state` event (`track_url`, `is_playing`, `position_ms`,
  `updated_at`) over Supabase Realtime.
- Each rider taps "Open track" → opens it in their own Apple Music/Spotify app, and the
  UI nudges them to scrub to the synced position. (Best-effort sync; deep
  programmatic control of third-party players is limited by those apps' SDKs — see
  compliance doc for what's possible per provider.)
- **No protected audio is ever captured or rebroadcast.**

### 3.5 Safety-first riding mode
- **Riding UI** is the default once you're in a room:
  - One dominant **Talk** button (PTT) filling most of the screen.
  - Big **Mute/Unmute** toggle.
  - **I need help** emergency button (guarded by a confirm to avoid accidental taps).
  - Compact status strip: **speed**, **battery**, **signal/connection**, rider count.
- **Auto-join voice**: entering a room connects + configures audio automatically.
- Map is a secondary tab/sheet so it's not the primary surface while moving.

### 3.6 Emergency
- "I need help" → confirm → broadcasts an `emergency` event to the room (everyone sees a
  red banner + the sender's live location pinned), and offers a one-tap **Call** to the
  rider's configured emergency contact / local services number.
- Clearly labeled as **not** a replacement for dialing emergency services.

### 3.7 Location sharing
- While in a room, the app publishes the rider's coordinate + speed + heading to the
  room (throttled, e.g. every 3–5 s or on significant change) via Supabase Realtime.
- Group map (MapKit) shows everyone with avatars; tap a rider to focus.
- Location sharing is **room-scoped** and stops when you leave the room.

### 3.8 Connectivity / range
- Works anywhere all riders have internet (cellular or WiFi) — **not** limited to
  Bluetooth range.
- **Reconnecting** state surfaced in the UI when the network drops; LiveKit + Supabase
  auto-reconnect; voice resumes when back online.
- BLE "nearby" offline fallback is explicitly a **roadmap** item, deprioritized.

---

## 4. Key user flows

### Create a ride
1. Sign in with Apple → land on Home.
2. Tap **Start a ride** → room created, you're host, voice connects, riding UI shows.
3. Tap **Invite** → share sheet with link + code.

### Join a ride
1. Tap invite link (or enter code on Home) → riding UI, voice connects, you appear in roster.

### Talk
1. Hold the big **Talk** button → you transmit; release → you stop.
2. (Or enable **VOX** in settings to go fully hands-free.)

### Emergency
1. Tap **I need help** → confirm → group is alerted, your location is pinned, optional call.

---

## 5. Success metrics (MVP)
- Time-to-first-word after opening an invite link < 10 s.
- Voice round-trip latency < 300 ms median on LTE.
- Crash-free sessions > 99%.
- D1 rejoin rate of riders who joined a ride.

---

## 6. App Store considerations
- Sign in with Apple satisfies the third-party-login guideline.
- Background audio mode is justified (live group voice) — documented in review notes.
- Location usage strings clearly explain *room-scoped, ride-only* sharing.
- No music rebroadcast → no DRM/ToS rejection risk.
- Emergency button copy avoids implying it replaces 911/112.
- Microphone + location permissions requested in-context with clear purpose strings.

See `docs/ARCHITECTURE.md` for the technical design and `docs/MUSIC_COMPLIANCE.md`
for the music rules.
