import Foundation

/// Membership row — mirrors `public.room_members`, joined with the member's profile
/// for display in the roster.
struct RoomMember: Codable, Identifiable, Hashable {
    let roomId: UUID
    let userId: UUID
    var role: Role
    var isMuted: Bool
    var leftAt: Date?

    /// Joined profile (when the query selects `profiles(*)`).
    var profile: UserProfile?

    var id: UUID { userId }
    var isHost: Bool { role == .host }
    var isActive: Bool { leftAt == nil }

    enum Role: String, Codable { case host, rider }

    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case userId = "user_id"
        case role
        case isMuted = "is_muted"
        case leftAt = "left_at"
        case profile = "profiles"
    }

    var displayName: String { profile?.displayName ?? "Rider" }
}
