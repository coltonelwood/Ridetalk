# Changelog

All notable changes to RideTalk are documented here. This project adheres to
[Semantic Versioning](https://semver.org/) (pre-1.0: APIs and schema may change).

## [0.1.0-alpha] — 2026-05-30

First MVP. A private group voice channel for riders (scooter / e-bike / motorcycle / UTV),
iPhone-first (SwiftUI) + Supabase (auth / data / realtime) + LiveKit (group voice) + MapKit.

### Added
- **Accounts** — Sign in with Apple, rider profile (name / vehicle), saved riding groups.
- **Ride rooms** — create, join by code or invite link, live roster, host mute/remove,
  lead-rider mode, host-set separation threshold.
- **Voice (LiveKit)** — group voice over cellular/WiFi, push-to-talk + voice-activated,
  self-mute, AirPods route detection, background audio, music ducking.
- **Live location** — all riders on a map with direction / speed / battery / signal, plus
  last-known position when a rider disconnects.
- **Separation alerts** — "X is N mi behind the group" at a ½ / 1 / 2 mi threshold.
- **SOS** — one-tap, GPS share, priority full-screen alert, fastest-route directions.
- **Possible crash / rider-down detection** — accelerometer + sudden-stop + no-movement →
  30s "Are you OK?" countdown → auto-SOS labeled "possible crash"; low/med/high sensitivity;
  clearly framed as best-effort, never contacting emergency services.
- **Ride recording** — route, distance, duration, avg/max speed, summary + history.
- **Quick messages** — Stopping / Need gas / Slow down / I'm behind / All good.
- **Music sync (compliant)** — host shares an Apple Music / Spotify / YouTube Music link and
  controls play/pause/position; each rider plays their own copy (Apple Music via MusicKit,
  Spotify via App Remote). No audio is ever rebroadcast.
- **Backend** — Supabase schema (10 tables) with RLS on every table, atomic RPCs, and a
  `livekit-token` edge function that keeps the LiveKit secret server-side.
- **Web** — Next.js + Tailwind landing page and `/join/[code]` invite handler.
- **CI** — macOS GitHub Actions workflow (`xcodegen` + `xcodebuild`) with stage-marked log
  capture and a diagnostic PR comment on failure.

### Known limitations
- Spotify synced playback requires the Spotify iOS SDK (isolated behind
  `#if canImport(SpotifyiOS)`); without it, RideTalk falls back to "Open in Spotify". Apple
  Music sync requires an Apple Music subscription at runtime.
- Crash detection is a best-effort heuristic, **not** guaranteed emergency detection, and
  does not contact emergency services.
- Profile photo upload, full BLE offline fallback, Android, and push notifications are
  roadmap items (see `docs/ROADMAP.md`).

[0.1.0-alpha]: https://github.com/coltonelwood/Ridetalk/releases/tag/v0.1.0-alpha
