# RideTalk v0.1.0-alpha — Real-Device Test Plan

**Goal:** validate the MVP on physical hardware. The iOS Simulator can't exercise AirPods
mic, real GPS, cellular handoff, or the accelerometer — these must be tested on devices.

> **Safety first:** Do **not** stage real crashes or unsafe riding to test rider-down
> detection. Use the in-app simulate/test triggers. See [Safety note](#safety-note).

---

## Required devices / accounts
- **2 iPhones** (real devices; 3rd device ideal for group/separation tests).
- **1+ AirPods** (or compatible Bluetooth earbuds with mic).
- **2 Apple IDs** (for Sign in with Apple on each device).
- **2 SIMs with cellular data** (to test real range off Wi-Fi).
- For music sync: an **Apple Music subscription** on at least one device; optionally
  **Spotify Premium** + the Spotify app.

## Backend prerequisites
- A **Supabase** project with migrations `0001`–`0005` applied.
- **Sign in with Apple** enabled in Supabase Auth (Services ID / key configured).
- **LiveKit** project; `livekit-token` edge function deployed with
  `LIVEKIT_API_KEY` / `LIVEKIT_API_SECRET` / `LIVEKIT_URL` secrets set.
- `ios/RideTalk/App/Secrets.xcconfig` filled with `SUPABASE_URL_HOST`,
  `SUPABASE_ANON_KEY`, `LIVEKIT_URL_HOST`.

## Pre-flight setup
- `cd ios && xcodegen generate`, set your **Team** in Signing, run on device over USB.
- Grant permissions in-context when prompted: **Microphone**, **Location**
  (While Using → allow **Always** when asked), **Motion**.
- Confirm **Sign in with Apple** works on a clean device (first-run profile auto-creation).
- Confirm both devices can **create** and **join by code** before deeper tests.

---

## 1. iPhone + AirPods voice
- Connect AirPods; create room on A, join on B. Hold PTT on A → B hears via AirPods.
- **Check:** status strip shows AirPods route; mic uses AirPods (not phone); VOX mode
  transmits hands-free; self-mute stops transmission.
- **Edge:** disconnect AirPods mid-talk → route falls back to speaker without crash
  (`AudioSessionManager` route-change handler).

## 2. Background audio
- In a ride, **lock the phone** / background the app. Voice must keep flowing both ways.
- **Check:** screen-locked talk + listen works; an incoming phone call interrupts then
  resumes (interruption handler); audio survives ~5 min locked.

## 3. Cellular ride-room (real range)
- Both devices on **cellular only (Wi-Fi off)**, physically apart. Verify join-by-code and
  voice.
- **Check:** "Reconnecting…" banner appears in a dead zone and recovers; LiveKit reconnects
  after a tunnel / airplane-mode blip; voice latency acceptable on LTE/5G.

## 4. Live map / location
- Both riding (or walking apart). Open Map.
- **Check:** both pins update with direction arrow + speed; battery/signal show;
  **separation alert** fires past the host threshold ("X is N mi behind"); disconnect a
  rider → "last known" pin persists (`is_connected=false`).

## 5. SOS
- Tap SOS on B → confirm.
- **Check:** A gets the **priority full-screen alert** + red banner; "Fastest route to
  <rider>" opens Apple Maps driving directions to B's coords; host/sender can resolve;
  alert clears on all devices.

## 6. Crash-detection simulation (no real crash)
- **Settings → Rider-down detection:** toggle on, set sensitivity. Use **"Simulate
  rider-down (test)"** → 30s "Are you OK?" countdown with **loud alarm + haptics**.
- **Check:** "I'm OK" cancels (no SOS); letting it elapse / "Send now" posts an SOS labeled
  **possible_crash** to the group (DEBUG in-ride button tests the real path); demo outside a
  ride sends nothing. Sweep low/med/high.
- *(Real accelerometer trip is hard to stage safely — rely on the simulate buttons. Only
  attempt a controlled drop of a padded test phone if you must validate thresholds, and
  never while riding.)*

## 7. Music sync (compliant)
- Host shares an **Apple Music** link; rider (Apple Music subscriber) toggles **Sync**.
- **Check:** rider's own Music app plays the same track near the host position; host
  play/pause/restart propagates; **Re-sync** corrects drift; **voice ducks music** when
  someone talks.
- Then a **Spotify** link → without the SDK linked, shows **"Open in Spotify"** fallback; a
  **YouTube Music** link → "unsupported, open link". Verify no-app and no-subscription
  fallbacks behave.

## 8. Battery drain
- Full charge → **30–60 min** realistic ride: voice connected + GPS background + map +
  music sync.
- **Check:** record %/hr; confirm GPS/voice **stop** on leave (background location
  disabled); compare PTT vs. VOX drain; watch for thermal throttling. Target a usable
  multi-hour ride; log the number for tuning.

---

## Pass/fail matrix template

Duplicate per device. Mark `P` / `F` / `—` (n/a) and add notes.

| # | Test | Device A | Device B | Device C | Notes |
|---|------|:--------:|:--------:|:--------:|-------|
| 1 | AirPods voice (PTT + VOX + self-mute) |  |  |  |  |
| 1e | AirPods disconnect mid-talk |  |  |  |  |
| 2 | Background audio (locked) |  |  |  |  |
| 2e | Phone-call interruption + resume |  |  |  |  |
| 3 | Cellular join + voice |  |  |  |  |
| 3e | Reconnect after dead zone |  |  |  |  |
| 4 | Map pins: direction + speed |  |  |  |  |
| 4 | Separation alert at threshold |  |  |  |  |
| 4 | Last-known on disconnect |  |  |  |  |
| 5 | SOS priority alert + route |  |  |  |  |
| 5 | SOS resolve clears alert |  |  |  |  |
| 6 | Simulate countdown + cancel |  |  |  |  |
| 6 | Timeout/Send → possible_crash SOS |  |  |  |  |
| 6 | Sensitivity low/med/high |  |  |  |  |
| 7 | Apple Music sync + ducking |  |  |  |  |
| 7 | Host play/pause/restart + re-sync |  |  |  |  |
| 7 | Spotify / YouTube Music fallbacks |  |  |  |  |
| 8 | Battery %/hr (record value) |  |  |  |  |
| 8 | GPS/voice stop on leave |  |  |  |  |

**Environment:** iOS version ___ · device models ___ · build/commit ___ · carrier(s) ___ ·
Supabase project ___ · LiveKit region ___ · date ___ · tester ___

---

## Known limitations
- **Spotify** synced playback requires the Spotify iOS SDK (isolated behind
  `#if canImport(SpotifyiOS)`); without it, the app falls back to "Open in Spotify".
- **Apple Music** sync requires an Apple Music subscription at runtime; otherwise falls back
  to the link.
- **YouTube Music** is link-only (no first-party iOS remote-control SDK).
- **Crash detection** is a best-effort heuristic, **not** guaranteed emergency detection,
  and does not contact emergency services.
- Background location requires the user to grant **Always** (or While-Using with background)
  for the group to see a rider when the screen is locked.
- Profile photo upload, BLE offline fallback, Android, and push notifications are roadmap
  items (see `docs/ROADMAP.md`).

## Safety note
Do **not** attempt unsafe crash testing. Never crash, drop, or throw a phone while riding,
and never ride in a way that risks injury to validate rider-down detection. Use the in-app
**"Simulate rider-down (test)"** control (and the DEBUG in-ride trigger) to exercise the full
countdown → SOS path safely. Any physical threshold validation must be done off-vehicle with
a padded test device, away from traffic. RideTalk is a communication aid, not a substitute
for safe riding or for emergency services.
