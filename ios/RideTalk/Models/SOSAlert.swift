import Foundation
import CoreLocation

/// How an SOS was raised.
enum AlertKind: String, Codable {
    case manual                       // rider tapped the SOS button
    case possibleCrash = "possible_crash"  // auto-detected, UNCONFIRMED

    var isPossibleCrash: Bool { self == .possibleCrash }
}

/// Emergency alert — mirrors `public.sos_alerts`.
struct SOSAlert: Codable, Identifiable, Equatable {
    var id: UUID
    var roomId: UUID
    var userId: UUID
    var lat: Double?
    var lng: Double?
    var message: String?
    var status: Status
    var kind: AlertKind?              // nil treated as .manual (column is NOT NULL default 'manual')
    var createdAt: Date
    var resolvedAt: Date?

    enum Status: String, Codable { case active, resolved }

    var isPossibleCrash: Bool { kind?.isPossibleCrash ?? false }

    var coordinate: CLLocationCoordinate2D? {
        guard let lat, let lng else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case roomId = "room_id"
        case userId = "user_id"
        case lat, lng, message, status
        case kind = "alert_kind"
        case createdAt = "created_at"
        case resolvedAt = "resolved_at"
    }
}

/// Insert payload for raising an SOS.
struct SOSInsert: Encodable {
    var roomId: UUID
    var userId: UUID
    var lat: Double?
    var lng: Double?
    var message: String?
    var alertKind: AlertKind = .manual

    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case userId = "user_id"
        case lat, lng, message
        case alertKind = "alert_kind"
    }
}
