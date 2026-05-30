import Foundation
import CoreLocation

/// Emergency alert — mirrors `public.sos_alerts`.
struct SOSAlert: Codable, Identifiable, Equatable {
    var id: UUID
    var roomId: UUID
    var userId: UUID
    var lat: Double?
    var lng: Double?
    var message: String?
    var status: Status
    var createdAt: Date
    var resolvedAt: Date?

    enum Status: String, Codable { case active, resolved }

    var coordinate: CLLocationCoordinate2D? {
        guard let lat, let lng else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case roomId = "room_id"
        case userId = "user_id"
        case lat, lng, message, status
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

    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case userId = "user_id"
        case lat, lng, message
    }
}
