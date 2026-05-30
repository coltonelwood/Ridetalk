# RideTalk — Roadmap: MVP → Production

## Phase 0 — MVP (this repo)
- [x] Sign in with Apple (Supabase Auth)
- [x] Create / join ride room (code + invite link)
- [x] Group voice (LiveKit, PTT + VOX)
- [x] AirPods audio routing + background audio
- [x] Live location sharing on a map
- [x] Large riding UI + emergency button
- [x] Music **Sync Mode** placeholder (shared links + state broadcast)
- [x] Supabase schema + RLS + token edge function
- [x] Landing page

**Exit criteria:** a group of friends can ride across a city, talk hands-free on AirPods,
see each other on a map, and trigger an emergency alert.

## Phase 1 — Hardening (4–6 weeks)
- [ ] Robust reconnect UX (network transitions LTE↔WiFi, tunnels, dead zones).
- [ ] Host moderation polish: server-enforced mute/remove via LiveKit server API edge fn.
- [ ] Ride history screen (past rooms, who was there, route trace from `ride_locations`).
- [ ] Saved groups + quick re-invite.
- [ ] Profile photos via Supabase Storage.
- [ ] Proper VOX tuning (noise gate, wind handling for riders).
- [ ] Analytics + crash reporting (e.g. TelemetryDeck / Sentry).
- [ ] Accessibility pass on the riding UI (Dynamic Type, VoiceOver, contrast).

## Phase 2 — Music & safety depth (6–8 weeks)
- [ ] MusicKit deep integration (true synced playback for Apple Music subscribers).
- [ ] Spotify App Remote integration (Premium).
- [ ] Collaborative queue (propose/approve), still each-plays-own.
- [ ] Emergency: configurable contacts, optional auto-SMS with location, crash detection
      heuristic (sudden stop + no motion) with countdown-to-alert.
- [ ] CarPlay-style / lock-screen Live Activity controls for PTT + status.
- [ ] Hardware PTT (volume-button or BLE remote) support.

## Phase 3 — Scale & platform (8–12 weeks)
- [ ] Android app (Kotlin/Compose, LiveKit + Supabase parity).
- [ ] Self-hosted LiveKit option + region routing for latency.
- [ ] Push notifications (APNs) for "ride starting", invites, emergencies.
- [ ] Web admin dashboard: manage groups, view ride history, moderation.
- [ ] Paid tiers (larger rooms, longer history, recording w/ consent).

## Phase 4 — Differentiators / R&D
- [ ] **BLE "nearby" offline fallback** — local mesh when internet drops, internet stays
      primary. (Explicitly deprioritized until core is rock-solid.)
- [ ] Group routing / breadcrumb navigation overlay.
- [ ] Auto-ducking music *and* spoken nav prompts.
- [ ] Noise-cancellation tuned for wind/road at speed.
- [ ] Apple Watch companion (PTT from the wrist).

## Cross-cutting / always-on
- Security reviews of RLS + token minting each phase.
- App Store compliance review before each submission (background audio justification,
  location strings, no-rebroadcast guarantee, emergency-button disclaimers).
- Battery profiling — audio + GPS + cellular is the budget; measure each release.
- Legal review of helmet/earbud laws per launch region; in-app safety disclaimers.
