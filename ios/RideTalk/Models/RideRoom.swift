import Foundation

/// A group ride room — mirrors `public.rooms`.
struct RideRoom: Codable, Identifiable, Hashable {
    let id: UUID
    let code: String
    var name: String
    let hostId: UUID
    var status: Status
    let createdAt: Date
    var endedAt: Date?

    enum Status: String, Codable { case active, ended }

    enum CodingKeys: String, CodingKey {
        case id, code, name, status
        case hostId = "host_id"
        case createdAt = "created_at"
        case endedAt = "ended_at"
    }

    /// Deep link to share with riders: `ridetalk://join/<CODE>`.
    var inviteDeepLink: URL? {
        URL(string: "\(AppConfig.deepLinkScheme)://join/\(code)")
    }

    /// HTTPS link for sharing in messages (resolves via your universal-link domain).
    var inviteWebLink: URL? {
        URL(string: "\(AppConfig.webJoinBaseURL)/\(code)")
    }
}
