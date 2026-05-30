# RideTalk 🛴🎙️

> A walkie-talkie style group audio app for scooter riders. Talk hands-free with AirPods, share location, sync music, and stay connected over cellular — not Bluetooth range.

RideTalk is an **iPhone-first** app (SwiftUI) backed by **Supabase** (auth, data, realtime) and **LiveKit** (low-latency group voice over WebRTC). A small **Next.js** landing/admin page is included.

---

## Repository layout

```
RideTalk/
├── ios/                  # SwiftUI iPhone app (the MVP)
│   ├── project.yml       # XcodeGen project definition (generates RideTalk.xcodeproj)
│   ├── RideTalk/         # App source
│   │   ├── App/          # Entry point, app state, configuration
│   │   ├── Models/       # Codable domain models (match the DB schema)
│   │   ├── Services/     # Supabase, Auth, LiveKit voice, Audio, Location, PTT
│   │   ├── ViewModels/   # Observable view models
│   │   ├── Views/        # SwiftUI screens (sign-in, home, ride room, profile)
│   │   └── Resources/    # Info.plist, entitlements, assets
│   └── README.md
├── supabase/             # Database schema, RLS policies, edge functions
│   ├── migrations/       # SQL migrations (run in order)
│   ├── functions/        # Edge functions (LiveKit token mint)
│   └── README.md
├── web/                  # Next.js + Tailwind landing page / admin
│   └── ...
└── docs/                 # Product spec, architecture, roadmap, compliance
    ├── PRODUCT_SPEC.md
    ├── ARCHITECTURE.md
    ├── MUSIC_COMPLIANCE.md
    └── ROADMAP.md
```

---

## What the MVP includes

- ✅ **Sign in with Apple** (via Supabase Auth)
- ✅ **Create / join a ride room** (room code + invite link / deep link)
- ✅ **Group voice chat** — low-latency, over cellular/WiFi (LiveKit/WebRTC)
- ✅ **AirPods support** — proper audio session + route handling
- ✅ **Push-to-talk** *and* optional **voice-activated** mode
- ✅ **Background audio** — voice continues while the phone is locked
- ✅ **Live location sharing** with the group (MapKit)
- ✅ **Large "riding" interface** — huge buttons, minimal interaction
- ✅ **Emergency "I need help"** button
- ✅ **Music sync placeholder** — shared track links + play/pause/seek sync (compliant; see below)
- ✅ **Audio ducking** — music ducks when someone talks

---

## Music: what's legal vs. what we built

iOS, Apple Music, and Spotify **do not allow apps to capture and rebroadcast their
protected audio output** to other users. RideTalk therefore ships **Sync Mode**, not
audio rebroadcast:

- The host shares a **track link** (Apple Music / Spotify).
- Each rider plays **their own copy** in their own music app.
- RideTalk syncs **play / pause / seek position** so everyone stays roughly in time.

This keeps the app **App Store friendly** and avoids DRM/ToS violations. Full detail in
[`docs/MUSIC_COMPLIANCE.md`](docs/MUSIC_COMPLIANCE.md).

---

## Quick start

### 0. Prerequisites

- macOS with **Xcode 15+**
- [`XcodeGen`](https://github.com/yonyz/XcodeGen) (`brew install xcodegen`)
- A [Supabase](https://supabase.com) project (free tier is fine)
- A [LiveKit Cloud](https://livekit.io) project **or** a self-hosted LiveKit server
- Node 18+ (for the web landing page, optional)

### 1. Backend — Supabase

```bash
cd supabase
# Apply schema (either via the Supabase SQL editor or the CLI)
supabase db push          # if using the Supabase CLI with a linked project
# or paste migrations/*.sql into the SQL editor in order
```

Set the LiveKit secrets the token-minting edge function needs:

```bash
supabase secrets set LIVEKIT_API_KEY=... LIVEKIT_API_SECRET=... LIVEKIT_URL=wss://your-project.livekit.cloud
supabase functions deploy livekit-token
```

See [`supabase/README.md`](supabase/README.md) for the full walkthrough.

### 2. iOS app

```bash
cd ios
cp RideTalk/App/Secrets.example.xcconfig RideTalk/App/Secrets.xcconfig
# edit Secrets.xcconfig with your Supabase URL + anon key + LiveKit URL
xcodegen generate          # creates RideTalk.xcodeproj
open RideTalk.xcodeproj
```

In Xcode:
1. Select your **Team** under *Signing & Capabilities*.
2. Confirm capabilities: **Sign in with Apple**, **Background Modes → Audio**, **Location**.
3. Run on a real device (microphone + background audio behave best on hardware).

See [`ios/README.md`](ios/README.md) for the dependency list and signing notes.

### 3. Web landing page (optional)

```bash
cd web
npm install
cp .env.example .env.local   # add your Supabase URL + anon key
npm run dev                  # http://localhost:3000
```

---

## Configuration summary

| Where | Key | Purpose |
|---|---|---|
| `ios/.../Secrets.xcconfig` | `SUPABASE_URL`, `SUPABASE_ANON_KEY` | App talks to Supabase |
| `ios/.../Secrets.xcconfig` | `LIVEKIT_URL` | WebSocket URL for voice |
| Supabase secrets | `LIVEKIT_API_KEY/SECRET` | Edge function mints room tokens |
| `web/.env.local` | `NEXT_PUBLIC_SUPABASE_URL/ANON_KEY` | Landing/admin |

**Never commit `Secrets.xcconfig` or `.env.local`.** They're gitignored.

---

## Architecture at a glance

```
 iPhone (SwiftUI)
   │  Sign in with Apple ──────────────► Supabase Auth
   │  Rooms / profiles / location ─────► Supabase Postgres (RLS) + Realtime
   │  "give me a voice token" ─────────► Supabase Edge Function ──► signs LiveKit JWT
   │  Group voice (WebRTC/Opus) ◄──────► LiveKit SFU (cellular/WiFi, not Bluetooth)
   │  Music sync events ───────────────► Supabase Realtime broadcast
```

Full detail: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

---

## Roadmap

MVP → production path (BLE offline fallback, CarPlay-style safety, push-to-talk
hardware, group history, moderation, etc.) lives in [`docs/ROADMAP.md`](docs/ROADMAP.md).

---

## Legal / safety notes

- RideTalk is a **communication aid**, not a substitute for safe riding. The riding UI is
  designed to minimize interaction, but riders are responsible for local helmet/earbud laws
  (some jurisdictions restrict covering both ears while riding).
- The emergency button calls **your configured contact/flow**, it is **not** a replacement
  for dialing local emergency services.
- Music Sync Mode never captures or rebroadcasts protected audio (see compliance doc).

---

## License

MIT — see `LICENSE`.
