import Foundation

/// Compliant **Sync Mode** state — mirrors `public.music_states`.
///
/// IMPORTANT: this only ever carries a *link* + playback intent + position. RideTalk never
/// captures or rebroadcasts protected audio. See docs/MUSIC_COMPLIANCE.md.
struct MusicState: Codable, Equatable {
    var roomId: UUID
    var trackURL: String
    var provider: Provider
    var title: String?
    var isPlaying: Bool
    var positionMs: Int
    var updatedBy: UUID?
    var updatedAt: Date

    enum Provider: String, Codable {
        case spotify, appleMusic, other

        /// Best-effort detection from a pasted link.
        static func detect(from urlString: String) -> Provider {
            let s = urlString.lowercased()
            if s.contains("spotify.com") || s.hasPrefix("spotify:") { return .spotify }
            if s.contains("music.apple.com") || s.contains("itunes.apple.com") { return .appleMusic }
            return .other
        }

        var displayName: String {
            switch self {
            case .spotify: return "Spotify"
            case .appleMusic: return "Apple Music"
            case .other: return "Music"
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case trackURL = "track_url"
        case provider, title
        case isPlaying = "is_playing"
        case positionMs = "position_ms"
        case updatedBy = "updated_by"
        case updatedAt = "updated_at"
    }

    /// Where playback "should" be right now, given when the state was set.
    var projectedPositionMs: Int {
        guard isPlaying else { return positionMs }
        let elapsed = Int(Date().timeIntervalSince(updatedAt) * 1000)
        return max(0, positionMs + elapsed)
    }
}
