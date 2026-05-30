import Foundation

/// A private ride room — mirrors `public.ride_rooms`.
struct RideRoom: Codable, Identifiable, Hashable {
    let id: UUID
    let code: String
    var name: String
    let hostId: UUID
    var leadRiderId: UUID?
    var status: Status
    var separationThresholdMiles: Double
    let createdAt: Date
    var endedAt: Date?

    enum Status: String, Codable { case active, ended }

    enum CodingKeys: String, CodingKey {
        case id, code, name, status
        case hostId = "host_id"
        case leadRiderId = "lead_rider_id"
        case separationThresholdMiles = "separation_threshold_miles"
        case createdAt = "created_at"
        case endedAt = "ended_at"
    }

    /// `ridetalk://join/<CODE>` for installed apps.
    var inviteDeepLink: URL? { URL(string: "\(AppConfig.deepLinkScheme)://join/\(code)") }
    /// HTTPS universal link for messaging apps.
    var inviteWebLink: URL? { URL(string: "\(AppConfig.webJoinBaseURL)/\(code)") }
}
