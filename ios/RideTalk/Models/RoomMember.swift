import Foundation

/// Membership row — mirrors `public.room_members`, joined with the rider's profile.
struct RoomMember: Codable, Identifiable, Hashable {
    let roomId: UUID
    let userId: UUID
    var role: Role
    var isMuted: Bool
    var subgroup: Subgroup
    var leftAt: Date?

    /// Joined profile (when the query selects `rider_profiles(*)`).
    var profile: RiderProfile?

    var id: UUID { userId }
    var isHost: Bool { role == .host }
    var isActive: Bool { leftAt == nil }
    var displayName: String { profile?.displayName ?? "Rider" }

    enum Role: String, Codable { case host, rider }
    enum Subgroup: String, Codable, CaseIterable { case front, middle, rear, none } // PLACEHOLDER

    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case userId = "user_id"
        case role
        case isMuted = "is_muted"
        case subgroup
        case leftAt = "left_at"
        case profile = "rider_profiles"
    }
}
