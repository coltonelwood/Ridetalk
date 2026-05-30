import Foundation

/// Compliant shared track — mirrors `public.shared_music_links`.
///
/// IMPORTANT: this only carries a *link* (+ placeholder sync fields). RideTalk never
/// captures or rebroadcasts protected audio. See docs/MUSIC_COMPLIANCE.md.
struct SharedMusicLink: Codable, Identifiable, Equatable {
    var id: UUID
    var roomId: UUID
    var userId: UUID?
    var url: String
    var provider: Provider
    var title: String?
    // PLACEHOLDER fields for future music-sync controls:
    var isPlaying: Bool
    var positionMs: Int
    var createdAt: Date

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
    }

    enum CodingKeys: String, CodingKey {
        case id
        case roomId = "room_id"
        case userId = "user_id"
        case url, provider, title
        case isPlaying = "is_playing"
        case positionMs = "position_ms"
        case createdAt = "created_at"
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
