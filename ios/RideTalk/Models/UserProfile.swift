import Foundation

/// Rider profile — mirrors `public.profiles`.
struct UserProfile: Codable, Identifiable, Hashable {
    let id: UUID
    var displayName: String
    var avatarURL: String?
    var scooterType: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case scooterType = "scooter_type"
    }
}

/// Fields the client is allowed to update on its own profile.
struct ProfileUpdate: Encodable {
    var displayName: String?
    var avatarURL: String?
    var scooterType: String?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case scooterType = "scooter_type"
    }
}
