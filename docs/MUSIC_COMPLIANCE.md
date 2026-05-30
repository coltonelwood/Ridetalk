# RideTalk — Music Sharing & Compliance

## TL;DR

**RideTalk does not — and cannot legally — capture Apple Music or Spotify audio and
rebroadcast it to other riders.** Instead we ship **Sync Mode**: the host shares a *track
link*, every rider plays *their own copy*, and we sync play/pause/position. This is the
only App-Store-safe, ToS-compliant approach.

---

## Why direct rebroadcast is off the table

1. **DRM & platform output protection.** Apple Music and Spotify deliver DRM-protected
   audio. iOS does not give third-party apps a tap on another app's protected audio
   output. There is no public, legitimate API to grab "what Apple Music is currently
   playing" as PCM and stream it elsewhere.

2. **Terms of Service.** Both Apple Music and Spotify developer terms explicitly prohibit
   redistributing/retransmitting their streams. Doing so risks app rejection, SDK key
   revocation, and legal exposure.

3. **App Store Review.** Apps that attempt to capture and rebroadcast protected media are
   rejected. Building rebroadcast would jeopardize the entire app.

> Even capturing the device's *system* audio mix (e.g. via ReplayKit/broadcast upload)
> and streaming it would relay protected music and violates the same rules. We don't do
> it.

## What we built instead: **Sync Mode**

### Data
A single `music_state` per room, broadcast over Supabase Realtime and persisted in the
`music_states` table:

```jsonc
{
  "trackUrl":   "https://open.spotify.com/track/...",
  "provider":   "spotify" | "appleMusic" | "other",
  "isPlaying":  true,
  "positionMs": 42000,
  "updatedAt":  "2026-05-30T18:20:05Z"
}
```

### Flow
1. Host taps **Share music**, pastes/share-sheets a track link.
2. App writes `music_state` and broadcasts it to the room.
3. Each rider sees the track card with **Open in Spotify / Apple Music**.
4. Tapping opens the link in the rider's own app; the UI shows the synced position and a
   "tap to re-sync" affordance.
5. When the host taps play/pause or seeks within RideTalk's mini-controls, we re-broadcast
   the new state so riders can re-align.

### How tight is the sync?
- **Coarse but useful.** We can reliably sync *which track* and *play/pause intent*, plus
  a target position with timestamp, so clients can compute "where should I be now."
- **Per-provider control limits:**
  - **Apple Music (MusicKit / `MPMusicPlayerController`):** if the rider is an Apple Music
    subscriber, RideTalk *can* programmatically play a catalog track and set playback
    position via MusicKit — enabling tighter, in-app sync. (Roadmap: deepen this.)
  - **Spotify (iOS SDK / App Remote):** allows connecting to the user's Spotify app to
    play a URI and issue play/pause/seek — also enabling tighter sync for Spotify
    Premium users. Requires the Spotify app installed + auth.
  - **Fallback (no SDK / non-subscriber):** we just deep-link the track and show the
    target position for manual scrubbing.

The MVP ships the **link + broadcast + manual re-sync** baseline (provider-agnostic, zero
extra entitlements), with MusicKit/Spotify App Remote as a documented enhancement.

### Ducking
Each rider's *own* music is ducked under voice automatically because RideTalk's audio
session uses `.duckOthers`. The OS lowers other apps' audio (including the music app)
while RideTalk plays/records voice. No special integration needed.

## What this means for the product copy
- Never claim "share your music with the group" implying audio rebroadcast.
- Correct copy: **"Sync a track so everyone listens together, in their own app."**

## Future, still-compliant enhancements (roadmap)
- Deep MusicKit integration for Apple Music subscribers (true in-app synced playback).
- Spotify App Remote integration for Premium users.
- Collaborative queue (everyone proposes tracks; host approves) — still each-plays-own.
