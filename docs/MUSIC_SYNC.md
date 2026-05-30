# RideTalk — Music Sync (Apple Music / Spotify)

How RideTalk lets a crew "listen together" **without rebroadcasting any audio**. Read this
alongside [`MUSIC_COMPLIANCE.md`](MUSIC_COMPLIANCE.md), which covers why rebroadcast is off
the table.

## The model

1. **Host shares a track link** (Apple Music / Spotify / YouTube Music). Stored in
   `shared_music_links` with host-controlled `is_playing`, `position_ms`, and `updated_at`.
2. **Host controls playback state** — play / pause / restart. This only writes the shared
   *state* (a link + booleans + a number). No audio leaves the host's device.
3. **Each rider opts into Sync.** Their device then drives **their own** music app to the
   same track + position, playing from **their own** Apple Music / Spotify account.
4. **Position projection** — followers compute the live position as
   `position_ms + (now − updated_at)` while playing, so everyone lines up even with network
   jitter. A **"Re-sync to host"** button snaps out any drift.
5. **Ducking is automatic** — playback happens in the system Music app / Spotify app, which
   `AudioSessionManager`'s `.duckOthers` already lowers when someone talks. No change needed.

```
Host app ──writes──▶ shared_music_links (link, is_playing, position_ms, updated_at)
                          │  (Supabase Realtime)
                          ▼
Rider app ──MusicSyncService──▶ Apple Music (MusicKit) or Spotify (App Remote)
                                  └ plays the rider's OWN copy, in time
```

## Code layout (all music code is isolated)

| Concern | File |
|---|---|
| Sharing links + host playback writes | `Services/MusicLinkService.swift` |
| Local follow engine + provider adapters | `Services/MusicSyncService.swift` |
| Link/state model + track-ID parsing | `Models/SharedMusicLink.swift` |
| UI (share, host controls, rider sync, fallbacks) | `Views/MusicLinkView.swift` |
| DB state | `supabase/migrations/0001_init.sql` + `0005_music_sync.sql` |

`MusicSyncService` defines a small `MusicPlaybackController` protocol with two
implementations: `AppleMusicController` (MusicKit) and `SpotifyController` (App Remote). The
orchestration (track change vs. play/pause vs. seek) is provider-agnostic.

## Apple Music (MusicKit) — works out of the box

- Uses **`SystemMusicPlayer`** so playback runs in the system Music app (and thus ducks
  under voice). MusicKit is a system framework — no extra dependency.
- Requires the **MusicKit capability** for your App ID and, at runtime, an **Apple Music
  subscription**. Without a subscription, playback fails gracefully → "Open in Apple Music".
- Authorization is requested in-context via `MusicAuthorization.request()`.
- Track ID is parsed from the link (`?i=` param or `/song/<id>`).

## Spotify (App Remote) — opt-in dependency, isolated behind `#if canImport`

The Spotify iOS SDK is **not** a Swift Package, so it isn't part of the default build (and
isn't on CI). All Spotify playback code is gated behind `#if canImport(SpotifyiOS)`:

- **Without** the SDK (default / CI): `SpotifyController` can still detect whether the
  Spotify app is installed, but cannot control playback → RideTalk shows **"Open in
  Spotify"**. The app builds and runs fine.
- **With** the SDK: the real App Remote controller compiles in automatically.

To enable real Spotify sync:
1. Add the **Spotify iOS SDK** (`SpotifyiOS.xcframework`) to the target (drag-in or via your
   dependency manager). The `#if canImport(SpotifyiOS)` branch then activates.
2. Register a Spotify app at developer.spotify.com; set a **Redirect URI** (e.g.
   `ridetalk://spotify-callback`) and add it to `CFBundleURLTypes`.
3. `LSApplicationQueriesSchemes` already includes `spotify` (so `canOpenURL` works).
4. Wire `SPTAppRemote` connect/authorize in `SpotifyController` (marked TODO in the file).
5. Requires **Spotify Premium** at runtime (App Remote limitation).

## Fallbacks (no app / no subscription / unsupported provider)

`MusicSyncService.status` drives the UI:

| Status | UI |
|---|---|
| `.unsupported` | Provider can't be synced (e.g. **YouTube Music**) → "Open in <app>" |
| `.needsApp` | App not installed → "Install it / open the link" |
| `.needsAuth` | Permission not granted → prompt + retry toggle |
| `.syncing` / `.paused` | Following the host |
| `.error` | Message + still offer the link |

Everyone always has the **"Open in <app>"** link as the lowest common denominator.

## App Store & legal limitations

- **No rebroadcast, ever.** RideTalk transmits only a link + play/pause/position. Protected
  audio is never captured, mixed, or relayed. This is the core compliance guarantee.
- Each rider streams from **their own** account, honoring Apple Music / Spotify ToS and
  artist payouts.
- **Apple Music** requires the MusicKit capability + a subscriber at runtime.
- **Spotify App Remote** requires the Spotify app + **Premium**; free accounts can't be
  remote-controlled (they fall back to the link).
- **YouTube Music** has no first-party iOS remote-control SDK → link-only by design.
- Playback control can be imperfect across app versions/network; the **Re-sync** button and
  position projection keep it "close enough", which is the realistic, compliant ceiling.

## Why this is the right ceiling

True sample-accurate sync would require a shared audio stream — which is exactly what DRM and
platform ToS forbid. Link + state + local playback + drift-correction is the maximum that's
both **legal** and **App-Store-safe**, and it delivers the "we're all hearing the same song"
experience riders actually want.
