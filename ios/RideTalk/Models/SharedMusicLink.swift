import Foundation

/// Compliant shared track — mirrors `public.shared_music_links`.
///
/// IMPORTANT: this only carries a *link* + host-controlled playback state (play/pause/
/// position). RideTalk never captures or rebroadcasts protected audio — each rider plays
/// their own copy in their own music app/account. See docs/MUSIC_COMPLIANCE.md.
struct SharedMusicLink: Codable, Identifiable, Equatable {
    var id: UUID
    var roomId: UUID
    var userId: UUID?
    var url: String
    var provider: Provider
    var title: String?
    // Host-controlled shared playback state:
    var isPlaying: Bool
    var positionMs: Int
    var createdAt: Date
    /// Anchor for `positionMs` so followers can project the live position.
    var updatedAt: Date?

    enum Provider: String, Codable {
        case spotify, appleMusic, youtubeMusic, other

        static func detect(from urlString: String) -> Provider {
            let s = urlString.lowercased()
            if s.contains("spotify.com") || s.hasPrefix("spotify:") { return .spotify }
            if s.contains("music.apple.com") || s.contains("itunes.apple.com") { return .appleMusic }
            if s.contains("music.youtube.com") || s.contains("youtu.be") || s.contains("youtube.com") { return .youtubeMusic }
            return .other
        }

        var displayName: String {
            switch self {
            case .spotify: return "Spotify"
            case .appleMusic: return "Apple Music"
            case .youtubeMusic: return "YouTube Music"
            case .other: return "Music"
            }
        }
        var icon: String { "music.note" }

        /// Can RideTalk programmatically control playback for this provider (MusicKit /
        /// Spotify App Remote)? YouTube Music / other are link-only.
        var supportsSyncedPlayback: Bool { self == .appleMusic || self == .spotify }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case roomId = "room_id"
        case userId = "user_id"
        case url, provider, title
        case isPlaying = "is_playing"
        case positionMs = "position_ms"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// Where playback *should* be right now, given when the state was last set.
    var projectedPositionMs: Int {
        guard isPlaying, let anchor = updatedAt else { return positionMs }
        return max(0, positionMs + Int(Date().timeIntervalSince(anchor) * 1000))
    }

    // MARK: - Provider track identifiers (parsed from the link)

    /// Apple Music catalog song ID (the `i=` query param, or a `/song/<id>` path).
    var appleMusicTrackID: String? {
        guard provider == .appleMusic, let comps = URLComponents(string: url) else { return nil }
        if let i = comps.queryItems?.first(where: { $0.name == "i" })?.value { return i }
        let parts = comps.path.split(separator: "/").map(String.init)
        if let idx = parts.firstIndex(of: "song"), idx + 1 < parts.count { return parts[idx + 1] }
        if let last = parts.last, last.allSatisfy(\.isNumber), !last.isEmpty { return last }
        return nil
    }

    /// Spotify track URI (`spotify:track:<id>`), parsed from a link or passthrough URI.
    var spotifyTrackURI: String? {
        guard provider == .spotify else { return nil }
        if url.hasPrefix("spotify:") { return url }
        guard let comps = URLComponents(string: url) else { return nil }
        let parts = comps.path.split(separator: "/").map(String.init)
        if let idx = parts.firstIndex(of: "track"), idx + 1 < parts.count {
            return "spotify:track:\(parts[idx + 1])"
        }
        return nil
    }

    /// Provider-specific track identifier used by the sync engine, if any.
    var syncTrackID: String? {
        switch provider {
        case .appleMusic: return appleMusicTrackID
        case .spotify: return spotifyTrackURI
        default: return nil
        }
    }
}

/// Insert payload for sharing a track link.
struct SharedMusicInsert: Encodable {
    var roomId: UUID
    var userId: UUID
    var url: String
    var provider: SharedMusicLink.Provider
    var title: String?

    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case userId = "user_id"
        case url, provider, title
    }
}
