import Foundation
import CoreLocation

/// A rider's live location — mirrors `public.live_locations` (latest per rider) and is also
/// broadcast over Realtime for instant map updates.
struct LiveLocation: Codable, Identifiable, Equatable {
    var roomId: UUID
    var userId: UUID
    var lat: Double
    var lng: Double
    var speedMps: Double?
    var heading: Double?
    var battery: Float?
    var signal: Signal?
    var isConnected: Bool
    var updatedAt: Date

    var id: UUID { userId }

    enum Signal: String, Codable { case good, weak, lost }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    /// Speed in mph for the riding readouts.
    var speedMph: Double {
        guard let speedMps, speedMps > 0 else { return 0 }
        return speedMps * 2.2369362921
    }

    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case userId = "user_id"
        case lat, lng
        case speedMps = "speed_mps"
        case heading, battery, signal
        case isConnected = "is_connected"
        case updatedAt = "updated_at"
    }
}

extension CLLocationCoordinate2D {
    /// Great-circle distance in miles.
    func milesTo(_ other: CLLocationCoordinate2D) -> Double {
        let a = CLLocation(latitude: latitude, longitude: longitude)
        let b = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return a.distance(from: b) / 1609.344
    }
}
