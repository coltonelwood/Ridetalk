import Foundation
import Combine
import UIKit

// ─────────────────────────────────────────────────────────────────────────────
// MusicSyncService — compliant, host-controlled music sync.
//
// COMPLIANCE (see docs/MUSIC_SYNC.md + docs/MUSIC_COMPLIANCE.md):
//   • RideTalk NEVER captures or rebroadcasts protected audio.
//   • Each rider plays their OWN copy on their OWN account, in their OWN music app
//     (Apple Music via MusicKit's SystemMusicPlayer, or Spotify via App Remote).
//   • The host shares only: track LINK + play/pause + position. Followers project the
//     position and drive their local player to match.
//   • Because playback happens in the separate Music/Spotify app, the existing
//     AudioSessionManager `.duckOthers` keeps ducking it under voice — unchanged.
//
// SDK ISOLATION (so the default build + CI stay green):
//   • Apple Music uses **MusicKit** (a system framework) → compiled directly.
//   • Spotify uses the **Spotify iOS SDK** (`SpotifyiOS`, NOT a Swift Package). It is
//     gated behind `#if canImport(SpotifyiOS)`. Without the framework, RideTalk falls back
//     to "open the link in Spotify" (no programmatic sync). Add the SDK to enable it; see
//     docs/MUSIC_SYNC.md.
// ─────────────────────────────────────────────────────────────────────────────

/// What the local sync engine is currently doing, surfaced to the UI.
enum MusicSyncStatus: Equatable {
    case off                       // rider hasn't opted into sync
    case unsupported(String)       // provider can't be synced (e.g. YouTube Music) — link only
    case needsApp(String)          // the music app isn't installed → fallback to open link
    case needsAuth(String)         // needs the user to grant access
    case syncing                   // following the host
    case paused                    // following, host paused
    case error(String)
}

/// Abstraction over a provider's local player (Apple Music / Spotify).
@MainActor
protocol MusicPlaybackController: AnyObject {
    var providerName: String { get }
    var isAppInstalled: Bool { get }
    func authorize() async -> Bool
    func play(trackID: String, positionMs: Int) async throws
    func resume(positionMs: Int) async throws
    func pause() async
    func seek(toMs: Int) async
    func stop()
}

enum MusicSyncError: LocalizedError {
    case trackNotFound
    case notAuthorized
    var errorDescription: String? {
        switch self {
        case .trackNotFound: return "Couldn't find that track in your music library/catalog."
        case .notAuthorized: return "Music access wasn't granted."
        }
    }
}

/// Local playback engine that follows the host's shared music state. All music-playback
/// code lives here (and in `MusicLinkService` for sharing/host writes).
@MainActor
final class MusicSyncService: ObservableObject {

    @Published private(set) var status: MusicSyncStatus = .off
    /// Whether the rider has opted into following the host.
    @Published private(set) var isSyncEnabled = false

    /// Drift beyond this triggers a corrective seek when the rider taps "Re-sync".
    let resyncToleranceMs = 2500

    private var current: SharedMusicLink?
    private var lastAppliedTrackID: String?
    private var lastWasPlaying = false
    private var lastAppliedAnchor: Date?

    private lazy var apple: MusicPlaybackController = AppleMusicController()
    private lazy var spotify: MusicPlaybackController = SpotifyController()

    // MARK: - Shared-state intake (called when Supabase music changes)

    func updateSharedState(_ link: SharedMusicLink?) {
        current = link
        guard isSyncEnabled else { return }
        Task { await apply(link) }
    }

    // MARK: - Rider opt-in

    func enableSync() async {
        isSyncEnabled = true
        await apply(current, forceSeek: true)
    }

    func disableSync() {
        isSyncEnabled = false
        status = .off
        // We intentionally do NOT stop the user's music — they may want to keep listening.
    }

    /// Snap to the host's current projected position (manual drift correction).
    func resyncNow() async {
        await apply(current, forceSeek: true)
    }

    // MARK: - Apply state to the local player

    private func apply(_ link: SharedMusicLink?, forceSeek: Bool = false) async {
        guard isSyncEnabled else { return }
        guard let link else { status = .off; return }

        guard link.provider.supportsSyncedPlayback, let trackID = link.syncTrackID else {
            status = .unsupported(link.provider.displayName)   // YouTube Music / other → link only
            return
        }

        let controller = controller(for: link.provider)

        guard controller.isAppInstalled else {
            status = .needsApp(link.provider.displayName)
            return
        }
        guard await controller.authorize() else {
            status = .needsAuth(link.provider.displayName)
            return
        }

        do {
            let target = link.projectedPositionMs
            let trackChanged = trackID != lastAppliedTrackID
            let anchorChanged = link.updatedAt != lastAppliedAnchor

            if trackChanged {
                if link.isPlaying {
                    try await controller.play(trackID: trackID, positionMs: target)
                } else {
                    try await controller.play(trackID: trackID, positionMs: target)
                    await controller.pause()
                }
            } else if link.isPlaying != lastWasPlaying {
                if link.isPlaying { try await controller.resume(positionMs: target) }
                else { await controller.pause() }
            } else if link.isPlaying, (forceSeek || anchorChanged) {
                // Same track, still playing, host re-anchored (scrub) or rider asked to re-sync.
                await controller.seek(toMs: target)
            }

            lastAppliedTrackID = trackID
            lastWasPlaying = link.isPlaying
            lastAppliedAnchor = link.updatedAt
            status = link.isPlaying ? .syncing : .paused
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    private func controller(for provider: SharedMusicLink.Provider) -> MusicPlaybackController {
        switch provider {
        case .appleMusic: return apple
        case .spotify: return spotify
        default: return apple   // unreachable: guarded by supportsSyncedPlayback above
        }
    }

    /// True if `provider` can be synced on this device right now (app installed).
    func canSync(_ provider: SharedMusicLink.Provider) -> Bool {
        switch provider {
        case .appleMusic: return apple.isAppInstalled
        case .spotify: return spotify.isAppInstalled
        default: return false
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Apple Music controller (MusicKit — system framework, compiles directly)
// ─────────────────────────────────────────────────────────────────────────────

#if canImport(MusicKit)
import MusicKit

/// Controls the **system Music app** (so `.duckOthers` ducks it under voice, and playback
/// uses the rider's own Apple Music subscription). Requires an Apple Music subscription at
/// runtime; without one, playback fails gracefully and we fall back to the link.
@MainActor
final class AppleMusicController: MusicPlaybackController {
    let providerName = "Apple Music"
    /// The Music app ships with iOS.
    var isAppInstalled: Bool { true }

    private let player = SystemMusicPlayer.shared

    func authorize() async -> Bool {
        switch MusicAuthorization.currentStatus {
        case .authorized: return true
        case .notDetermined: return await MusicAuthorization.request() == .authorized
        default: return false
        }
    }

    func play(trackID: String, positionMs: Int) async throws {
        let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(trackID))
        let response = try await request.response()
        guard let song = response.items.first else { throw MusicSyncError.trackNotFound }
        player.queue = [song]
        try await player.prepareToPlay()
        player.playbackTime = TimeInterval(positionMs) / 1000.0
        try await player.play()
    }

    func resume(positionMs: Int) async throws {
        player.playbackTime = TimeInterval(positionMs) / 1000.0
        try await player.play()
    }

    func pause() async { player.pause() }

    func seek(toMs ms: Int) async { player.playbackTime = TimeInterval(ms) / 1000.0 }

    func stop() { player.stop() }
}
#else
/// Fallback when MusicKit isn't available at all (shouldn't happen on iOS, but keeps the
/// type defined for non-iOS compilation contexts).
@MainActor
final class AppleMusicController: MusicPlaybackController {
    let providerName = "Apple Music"
    var isAppInstalled: Bool { false }
    func authorize() async -> Bool { false }
    func play(trackID: String, positionMs: Int) async throws { throw MusicSyncError.notAuthorized }
    func resume(positionMs: Int) async throws { throw MusicSyncError.notAuthorized }
    func pause() async {}
    func seek(toMs ms: Int) async {}
    func stop() {}
}
#endif

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Spotify controller (App Remote — gated; SDK is NOT a Swift Package)
// ─────────────────────────────────────────────────────────────────────────────

#if canImport(SpotifyiOS)
import SpotifyiOS

/// Real Spotify App Remote integration. Compiled ONLY when the Spotify iOS SDK has been
/// added to the project (see docs/MUSIC_SYNC.md for setup: framework, redirect URI,
/// `LSApplicationQueriesSchemes`, and the `spotify-ios-quick-start` config). Requires
/// Spotify Premium at runtime.
@MainActor
final class SpotifyController: NSObject, MusicPlaybackController {
    let providerName = "Spotify"
    var isAppInstalled: Bool {
        guard let url = URL(string: "spotify:") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    // NOTE: a production implementation wires SPTAppRemote here (connect, authorize,
    // playerAPI.play/pause/seek). Kept minimal + clearly marked; the orchestration in
    // MusicSyncService is identical regardless of which controller backs it.
    private var appRemote: SPTAppRemote? // configured during setup

    func authorize() async -> Bool {
        // Real impl: ensure SPTAppRemote is connected (or trigger auth via wakeup deeplink).
        return appRemote?.isConnected ?? false
    }
    func play(trackID uri: String, positionMs: Int) async throws {
        appRemote?.playerAPI?.play(uri, callback: nil)
        if positionMs > 0 { appRemote?.playerAPI?.seek(toPosition: positionMs, callback: nil) }
    }
    func resume(positionMs: Int) async throws { appRemote?.playerAPI?.resume(nil) }
    func pause() async { appRemote?.playerAPI?.pause(nil) }
    func seek(toMs ms: Int) async { appRemote?.playerAPI?.seek(toPosition: ms, callback: nil) }
    func stop() { appRemote?.playerAPI?.pause(nil) }
}
#else

/// Fallback Spotify controller used when the Spotify SDK is **not** linked (the default, and
/// in CI). It can detect whether the Spotify app is installed (to drive fallback UI) but
/// cannot control playback — RideTalk shows "Open in Spotify" instead. Adding the Spotify
/// iOS SDK swaps in the real controller above automatically via `#if canImport`.
@MainActor
final class SpotifyController: MusicPlaybackController {
    let providerName = "Spotify"
    var isAppInstalled: Bool {
        guard let url = URL(string: "spotify:") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
    func authorize() async -> Bool { false } // no SDK → can't programmatically control
    func play(trackID: String, positionMs: Int) async throws { throw MusicSyncError.notAuthorized }
    func resume(positionMs: Int) async throws { throw MusicSyncError.notAuthorized }
    func pause() async {}
    func seek(toMs ms: Int) async {}
    func stop() {}
}
#endif
