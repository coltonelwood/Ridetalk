import Foundation
import CoreLocation

/// One point along a recorded route.
struct RoutePoint: Codable, Equatable {
    var lat: Double
    var lng: Double
    var t: Date
    var speed: Double?   // m/s

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

/// A recorded ride — mirrors `public.ride_recordings`.
struct RideRecording: Codable, Identifiable, Equatable {
    var id: UUID
    var roomId: UUID?
    var userId: UUID
    var title: String?
    var startedAt: Date
    var endedAt: Date?
    var route: [RoutePoint]

    enum CodingKeys: String, CodingKey {
        case id
        case roomId = "room_id"
        case userId = "user_id"
        case title
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case route
    }
}

/// Summary stats — mirrors `public.ride_stats`.
struct RideStats: Codable, Identifiable, Equatable {
    var recordingId: UUID
    var distanceM: Double
    var durationS: Double
    var avgSpeedMps: Double
    var maxSpeedMps: Double
    var startedAt: Date?
    var endedAt: Date?

    var id: UUID { recordingId }

    var distanceMiles: Double { distanceM / 1609.344 }
    var avgSpeedMph: Double { avgSpeedMps * 2.2369362921 }
    var maxSpeedMph: Double { maxSpeedMps * 2.2369362921 }

    var durationFormatted: String {
        let s = Int(durationS)
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec)
                     : String(format: "%d:%02d", m, sec)
    }

    enum CodingKeys: String, CodingKey {
        case recordingId = "recording_id"
        case distanceM = "distance_m"
        case durationS = "duration_s"
        case avgSpeedMps = "avg_speed_mps"
        case maxSpeedMps = "max_speed_mps"
        case startedAt = "started_at"
        case endedAt = "ended_at"
    }
}
