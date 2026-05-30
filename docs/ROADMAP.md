# RideTalk — Roadmap: MVP → Production

## Phase 0 — MVP (this repo)
Sign in with Apple · create/join rooms · group voice (PTT + VOX) · AirPods + background
audio · live group location + map · separation alerts · SOS (priority alert + directions) ·
lead-rider mode · ride recording + stats + history · quick messages · safety banners ·
compliant music links · Supabase schema/RLS/RPCs + LiveKit token function · landing page.

See [`MVP_CHECKLIST.md`](MVP_CHECKLIST.md) for the per-feature status.

## Phase 1 — Hardening (4–6 weeks)
- [ ] Reconnect UX across LTE↔WiFi/dead zones; resilient Realtime resubscribe.
- [ ] Server-enforced mute/kick via LiveKit server API (edge function).
- [ ] Profile photos via Supabase Storage.
- [ ] VOX tuning: real AVAudioEngine input metering, wind/road noise gate.
- [ ] Accessibility pass (Dynamic Type, VoiceOver, contrast) on the riding UI.
- [ ] Analytics + crash reporting (Sentry / TelemetryDeck).
- [ ] Battery profiling (audio + GPS + cellular budget).

## Phase 2 — Safety & music depth (6–8 weeks)
- [ ] **Crash / rider-down detection**: sudden-stop + impact + no-movement → "Are you
      okay?" countdown → auto-SOS to the group if no response.
- [ ] **Emergency contact** auto-notify (SMS w/ location) — opt-in, clearly not 911.
- [ ] **Full music sync**: MusicKit (Apple Music) + Spotify App Remote for true synced
      play/pause/seek; collaborative queue / playlist voting (still each-plays-own).
- [ ] **Whisper mode**: private 1:1 / subgroup audio (front/mid/rear) using LiveKit
      track subscriptions or sub-rooms.
- [ ] Priority audio ducking: lower others' voice when a priority/SOS message fires.
- [ ] Lock-screen Live Activity for PTT + ride status.

## Phase 3 — Platform & scale (8–12 weeks)
- [ ] Android app (Kotlin/Compose, LiveKit + Supabase parity).
- [ ] APNs push (ride starting, invites, SOS while backgrounded).
- [ ] Web admin dashboard (groups, ride history, moderation).
- [ ] Self-hosted LiveKit + region routing.
- [ ] Paid tiers (bigger rooms, longer history, consented recording).

## Phase 4 — Premium / R&D (from the spec's future list)
- [ ] **Apple Watch** companion (PTT from the wrist, stats glance).
- [ ] **Bluetooth mesh backup** when internet drops (internet stays primary).
- [ ] **GoPro integration** (start/stop, tag SOS moments).
- [ ] **CarPlay / chase-vehicle mode** (big map + roster for a support driver).
- [ ] **Offline route packs** (download maps for no-signal areas).
- [ ] Turn-by-turn navigation following the lead rider.

## Always-on
- Security review of RLS + token minting each phase.
- App Store compliance review before each submission (background audio justification,
  location strings, no-rebroadcast guarantee, SOS disclaimers).
- Legal review of earbud/helmet laws per launch region; in-app safety disclaimers.
