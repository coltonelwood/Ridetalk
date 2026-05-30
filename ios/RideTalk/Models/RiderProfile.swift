import Foundation

/// Mirrors `public.users`.
struct AppUser: Codable, Identifiable, Hashable {
    let id: UUID
    var email: String?

    enum CodingKeys: String, CodingKey { case id, email }
}

/// Mirrors `public.rider_profiles`.
struct RiderProfile: Codable, Identifiable, Hashable {
    let userId: UUID
    var displayName: String
    var photoURL: String?
    var vehicleType: String?
    var vehicleName: String?
    var emergencyContact: String?   // PLACEHOLDER: future SOS contact

    var id: UUID { userId }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case displayName = "display_name"
        case photoURL = "photo_url"
        case vehicleType = "vehicle_type"
        case vehicleName = "vehicle_name"
        case emergencyContact = "emergency_contact"
    }
}

/// Vehicle presets for the profile picker.
enum VehicleType: String, CaseIterable, Identifiable {
    case scooter = "Scooter"
    case ebike = "E-Bike"
    case motorcycle = "Motorcycle"
    case utv = "UTV"
    case other = "Other"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .scooter: return "scooter"
        case .ebike: return "bicycle"
        case .motorcycle: return "motorcycle"   // SF Symbol (iOS 17+); falls back gracefully
        case .utv: return "car.fill"
        case .other: return "figure.outdoor.cycle"
        }
    }
}

/// Fields the client may update on its own profile. All optional + `nil`-defaulted so
/// callers can set just one field; synthesized `Encodable` omits `nil` (`encodeIfPresent`),
/// so unset fields are never written to null.
struct ProfileUpdate: Encodable {
    var displayName: String? = nil
    var photoURL: String? = nil
    var vehicleType: String? = nil
    var vehicleName: String? = nil
    var emergencyContact: String? = nil

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case photoURL = "photo_url"
        case vehicleType = "vehicle_type"
        case vehicleName = "vehicle_name"
        case emergencyContact = "emergency_contact"
    }
}
