import Foundation
import Combine
import CoreLocation
import Supabase

/// Raises and resolves SOS alerts. An alert inserts a row (fanned out to the room via
/// Realtime) carrying the rider's coordinates so the group can navigate to them.
@MainActor
final class SOSService: ObservableObject {

    private var client: SupabaseClient { SupabaseManager.shared.client }

    func raise(roomId: UUID, userId: UUID, coordinate: CLLocationCoordinate2D?,
               message: String? = nil, kind: AlertKind = .manual) async throws {
        let insert = SOSInsert(
            roomId: roomId, userId: userId,
            lat: coordinate?.latitude, lng: coordinate?.longitude,
            message: message, alertKind: kind
        )
        _ = try await client.from("sos_alerts").insert(insert).execute()
    }

    func resolve(alertId: UUID) async throws {
        _ = try await client.from("sos_alerts")
            .update(["status": "resolved", "resolved_at": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: alertId.uuidString)
            .execute()
    }
}
