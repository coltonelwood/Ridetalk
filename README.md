# RideTalk 🛴🏍️🎙️

> **A private voice channel for riders** — talk through your AirPods, keep your music
> playing, and stay connected with your crew over cellular distance.

For scooter, e-bike, motorcycle, and UTV crews. **iPhone-first** (SwiftUI), backed by
**Supabase** (auth/data/realtime) and **LiveKit** (low-latency group voice over WebRTC),
with **Apple MapKit** for live group location. A small **Next.js** landing/invite page is
included.

---

## What's in the MVP

| Area | Feature |
|---|---|
| **Accounts** | Sign in with Apple · rider profile (name, vehicle type/model) · saved riding groups |
| **Ride rooms** | Create · join by code or invite link · live roster · host mute/remove · lead-rider mode · separation threshold |
| **Voice** | Group voice (LiveKit) · **push-to-talk** + **voice-activated** · self-mute · AirPods route detection · ducks local music · background audio |
| **Music** | Share a Spotify / Apple Music / **YouTube Music** link — each rider plays their own copy. **No illegal rebroadcast.** Full-sync controls scaffolded as a placeholder |
| **Live location** | All riders on a map · name/photo · direction of travel · speed · battery · signal · last-known when disconnected |
| **Separation alerts** | "Jake is 1.2 mi behind the group" at a host-set ½ / 1 / 2 mi threshold |
| **SOS** | One-tap help · shares GPS · priority full-screen alert to the group · fastest-route directions |
| **Ride leader mode** | Host assigns a lead rider · everyone sees distance-from-lead |
| **Recording & stats** | Auto-records the ride · distance, duration, avg/max speed · ride summary + history |
| **Safety alerts** | Low battery · lost signal / reconnecting · stopped-unexpectedly · crash-detection placeholder |
| **Quick messages** | One-tap "Stopping / Need gas / Slow down / I'm behind / All good" (priority for *Slow down*) |

Clearly-marked **placeholders** for: full music sync, crash/rider-down detection, subgroups
(front/mid/rear), whisper mode, Apple Watch, BLE mesh, GoPro, CarPlay — see
[`docs/ROADMAP.md`](docs/ROADMAP.md).

---

## Music: what's legal

iOS / Apple Music / Spotify **do not allow apps to capture and rebroadcast their protected
audio**. RideTalk therefore shares **links** — each rider plays their own copy — and ducks
that local music under voice via the audio session. Full detail:
[`docs/MUSIC_COMPLIANCE.md`](docs/MUSIC_COMPLIANCE.md).

---

## Repository layout

```
RideTalk/
├── ios/                         # SwiftUI iPhone app (the MVP)
│   ├── project.yml              # XcodeGen → generates RideTalk.xcodeproj
│   └── RideTalk/
│       ├── App/                 RideTalkApp, AppState (coordinator), AppConfig, Secrets
│       ├── Models/              users, rider_profiles, ride_rooms, room_members,
│       │                        live_locations, sos_alerts, ride_recordings/stats,
│       │                        shared_music_links, quick_messages (Codable)
│       ├── Services/
│       │   ├── SupabaseManager      client + per-room Realtime state
│       │   ├── AuthService          Sign in with Apple + rider profile
│       │   ├── RideRoomService      create/join/leave/end, host controls, lead, threshold
│       │   ├── VoiceChatService     LiveKit voice + push-to-talk
│       │   ├── AudioSessionManager  AirPods routing, ducking, background, interruptions
│       │   ├── LocationService      CoreLocation → live_locations + speed/battery
│       │   ├── MusicLinkService     shared track links
│       │   ├── SOSService           raise/resolve emergencies
│       │   ├── RideRecordingService route + distance/duration/avg/max + history
│       │   └── PushToTalkController  PTT + VOX
│       ├── ViewModels/          ActiveRideViewModel
│       └── Views/               SignIn, Home, CreateRoom, JoinRoom, ActiveRide, Map,
│                                MusicLink, SOS, RideSummary, RideHistory, Profile + Components
├── supabase/                    # SQL schema, RLS, RPCs, edge function
│   ├── migrations/0001_init.sql · 0002_rls.sql · 0003_functions.sql
│   └── functions/livekit-token/  # mints LiveKit JWTs server-side
├── web/                         # Next.js + Tailwind landing + /join/[code]
└── docs/                        # spec, architecture, music compliance, LiveKit setup,
                                 # MVP checklist, roadmap
```

---

## Database schema (Supabase)

Tables (full DDL in [`supabase/migrations`](supabase/migrations)): `users`,
`rider_profiles`, `ride_rooms`, `room_members`, `live_locations`, `sos_alerts`,
`ride_recordings`, `ride_stats`, `shared_music_links`, `quick_messages`.

**RLS** on every table — a rider can only read/write data for rooms they belong to; host-only
fields (mute/remove, lead rider, threshold, end ride) are gated by `is_room_host()`.

---

## Main screens

1. Onboarding / Sign in with Apple
2. Home (start/join, saved groups, history)
3. Create Ride Room
4. Join Ride Room
5. **Active Ride** (room name, rider count, lead rider, big PTT, mute, SOS, music, map preview, rider list, connection status)
6. Map View
7. Music Link
8. SOS Alert (priority full-screen)
9. Ride Summary
10. Profile / Settings

---

## Quick start

### 1. Supabase
```bash
cd supabase
# apply migrations in order (SQL editor or CLI)
supabase db push
# LiveKit secrets for the token function:
supabase secrets set LIVEKIT_API_KEY=… LIVEKIT_API_SECRET=… LIVEKIT_URL=wss://your.livekit.cloud
supabase functions deploy livekit-token
```
Enable **Apple** under Authentication → Providers. Details: [`supabase/README.md`](supabase/README.md).

### 2. iOS
```bash
cd ios
cp RideTalk/App/Secrets.example.xcconfig RideTalk/App/Secrets.xcconfig   # fill in values
xcodegen generate
open RideTalk.xcodeproj
```
Pick your Team; confirm **Sign in with Apple** + **Background Modes (Audio, Location)**; run
on a real device. Details: [`ios/README.md`](ios/README.md) · LiveKit:
[`docs/LIVEKIT_SETUP.md`](docs/LIVEKIT_SETUP.md).

### 3. Web (optional)
```bash
cd web && npm install && cp .env.example .env.local && npm run dev
```

---

## Environment variables

| Where | Keys |
|---|---|
| `ios/.../Secrets.xcconfig` | `SUPABASE_URL_HOST`, `SUPABASE_ANON_KEY`, `LIVEKIT_URL_HOST` |
| Supabase function secrets | `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`, `LIVEKIT_URL` |
| `web/.env.local` | `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `NEXT_PUBLIC_APP_STORE_URL` |

Examples are in `*.example` files; real secrets are gitignored.

---

## Docs

- [`docs/PRODUCT_SPEC.md`](docs/PRODUCT_SPEC.md) — product spec
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — system design
- [`docs/MUSIC_COMPLIANCE.md`](docs/MUSIC_COMPLIANCE.md) — why we don't rebroadcast audio
- [`docs/LIVEKIT_SETUP.md`](docs/LIVEKIT_SETUP.md) — voice setup notes
- [`docs/MVP_CHECKLIST.md`](docs/MVP_CHECKLIST.md) — what's done / placeholders
- [`docs/ROADMAP.md`](docs/ROADMAP.md) — MVP → production

---

## Safety & legal

RideTalk is a **communication aid, not a substitute for safe riding**. The SOS button
alerts your group — it does **not** contact emergency services. Riders must follow local
laws on earbuds/helmets. Music Sync never captures or rebroadcasts protected audio.

## License

MIT — see `LICENSE`.
