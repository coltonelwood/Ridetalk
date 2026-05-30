import Foundation
import CoreLocation

/// A live location ping broadcast over Supabase Realtime (and optionally persisted to
/// `public.ride_locations`).
struct RiderLocation: Codable, Identifiable, Equatable {
    var userId: UUID
    var lat: Double
    var lng: Double
    var speedMps: Double?
    var heading: Double?
    var battery: Float?
    var recordedAt: Date

    var id: UUID { userId }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    /// Speed in mph for the riding UI (US-friendly; swap to km/h via settings later).
    var speedMph: Double {
        guard let speedMps, speedMps > 0 else { return 0 }
        return speedMps * 2.2369362921
    }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case lat, lng
        case speedMps = "speed_mps"
        case heading, battery
        case recordedAt = "recorded_at"
    }
}

/// Payload broadcast for an "I need help" event.
struct EmergencyEvent: Codable, Identifiable, Equatable {
    var id = UUID()
    var userId: UUID
    var displayName: String
    var lat: Double?
    var lng: Double?
    var timestamp: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case displayName = "display_name"
        case lat, lng, timestamp
    }
}
