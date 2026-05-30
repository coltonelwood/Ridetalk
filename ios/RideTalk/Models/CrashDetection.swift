import Foundation
import CoreLocation

/// Sensitivity for possible crash / rider-down detection. Higher sensitivity = lower
/// thresholds = triggers more easily (and with more false positives).
///
/// IMPORTANT: this is **possible** crash detection — a best-effort heuristic, NOT guaranteed
/// emergency detection. It never contacts emergency services; it alerts the ride group.
enum CrashSensitivity: String, Codable, CaseIterable, Identifiable {
    case low, medium, high
    var id: String { rawValue }

    var label: String { rawValue.capitalized }

    /// Impact spike threshold in g (accelerometer magnitude). Resting ≈ 1g.
    var impactG: Double {
        switch self {
        case .low: return 4.0      // needs a hard hit
        case .medium: return 3.0
        case .high: return 2.2     // trips easily
        }
    }

    /// "Was riding" speed (m/s) required before a sudden stop counts.
    /// (4.5 m/s ≈ 10 mph, 3.0 ≈ 6.7 mph, 6.7 ≈ 15 mph.)
    var ridingSpeedMps: Double {
        switch self {
        case .low: return 6.7
        case .medium: return 4.5
        case .high: return 3.0
        }
    }

    /// How long the rider must show no movement after an impact/sudden-stop before we trip.
    var confirmWindow: TimeInterval {
        switch self {
        case .low: return 10
        case .medium: return 8
        case .high: return 6
        }
    }

    var explanation: String {
        switch self {
        case .low: return "Fewest false alarms. Needs a hard impact + full stop."
        case .medium: return "Balanced for most riding."
        case .high: return "Most sensitive. May trigger on rough stops."
        }
    }
}

/// A possible rider-down event that drives the countdown screen.
struct RiderDownEvent: Identifiable, Equatable {
    let id = UUID()
    /// Human-readable trigger reason (e.g. "Impact detected + no movement").
    let reason: String
    /// True when triggered from the settings test button outside an active ride — the
    /// countdown runs but no real SOS is sent.
    let isDemo: Bool
    let coordinate: CLLocationCoordinate2D?

    static func == (lhs: RiderDownEvent, rhs: RiderDownEvent) -> Bool { lhs.id == rhs.id }
}
