# RideTalk — MVP Checklist

Legend: ✅ implemented · 🟡 scaffolded/placeholder (clearly marked in-app) · ⬜ not started

## Accounts
- ✅ Sign in with Apple (Supabase Auth, native nonce flow)
- ✅ Rider profile: name, vehicle type, vehicle model
- 🟡 Profile photo upload (UI present; wiring to Supabase Storage is Phase 1)
- ✅ Saved riding groups (rooms you've joined)

## Ride rooms
- ✅ Create room (name + separation threshold)
- ✅ Join by code or invite link (`ridetalk://join/<CODE>` + web `/join/<CODE>`)
- ✅ Live roster of connected riders
- ✅ Host controls: mute (server-enforced flag), remove rider
- ✅ Lead-rider mode (host assigns; distance-from-lead shown)
- ✅ Host-set separation threshold (½ / 1 / 2 mi)

## Voice (LiveKit)
- ✅ Group voice over cellular/WiFi
- ✅ Push-to-talk (publish toggling)
- ✅ Voice-activated mode (VOX) — basic gate, 🟡 metering tuning in Phase 1
- ✅ Self mute / unmute
- ✅ AirPods mic + route detection (AVAudioSession `.allowBluetooth`)
- ✅ Music ducking under voice (`.duckOthers`)
- ✅ Background audio (UIBackgroundModes: audio)
- 🟡 Wind/noise suppression (relies on `.voiceChat` mode + LiveKit; dedicated DSP later)

## Music
- ✅ Share Spotify / Apple Music / YouTube Music **link**
- ✅ Each rider opens their own copy (compliant — no rebroadcast)
- 🟡 Full music sync (play/pause/timestamp) — placeholder UI + DB fields; needs MusicKit / Spotify App Remote

## Riding UI
- ✅ Huge buttons, dark UI, big PTT / mute / SOS
- ✅ Minimal interaction; map is a preview + sheet
- ✅ Status strip: connection, AirPods route, speed, battery
- ✅ Background/lock-screen-friendly audio (voice continues)

## Live location
- ✅ All riders on a map (MapKit)
- ✅ Name, direction of travel, speed
- ✅ Battery + signal quality
- ✅ Last-known location when a rider disconnects (`is_connected=false`)

## Separation alerts
- ✅ Distance-behind-lead computed client-side
- ✅ Banner at host threshold ("X is 1.2 mi behind")
- ✅ Separated riders highlighted on the map

## SOS
- ✅ One-tap SOS (guarded confirm)
- ✅ Shares GPS to the group
- ✅ Priority full-screen visual + haptic alert
- ✅ Fastest-route directions (Apple Maps)
- 🟡 Emergency contact (stored on profile; auto-notify is a future version)

## Ride recording / stats
- ✅ Auto-records route while in a ride
- ✅ Distance, duration, avg speed, max speed, start/end
- ✅ Ride summary screen + ride history

## Safety / device alerts
- ✅ Low phone battery warning
- ✅ Lost signal / reconnecting warning
- ✅ Stopped-unexpectedly warning (no-movement heuristic)
- 🟡 Crash/rider-down detection (sudden stop + impact + "Are you okay?") — placeholder hook

## Communication extras
- ✅ Quick text alerts (Stopping / Gas / Slow down / Behind / All good)
- 🟡 Priority messages interrupt normal voice (priority flag + SOS interrupt done; voice-channel ducking of others is future)
- 🟡 Whisper mode (private 1:1) — placeholder
- 🟡 Front/middle/rear subgroups — DB enum present, UI placeholder

## Backend
- ✅ All 10 tables + enums
- ✅ RLS on every table (members-only; host-gated mutations)
- ✅ Atomic RPCs (create/join/leave/end/set_lead/set_threshold)
- ✅ LiveKit token edge function (secret stays server-side)
- ✅ Realtime (Postgres changes + broadcast)

## Web
- ✅ Landing page
- ✅ Invite link handler `/join/[code]`
- ⬜ Admin dashboard (Phase 3)
