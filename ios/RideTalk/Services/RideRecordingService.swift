import Foundation
import Combine
import CoreLocation
import Supabase

/// Records a ride: accumulates the route, computes live distance / duration / avg / max
/// speed, and persists a `ride_recordings` row + `ride_stats` summary on stop.
@MainActor
final class RideRecordingService: ObservableObject {

    @Published private(set) var isRecording = false
    @Published private(set) var liveDistanceMiles: Double = 0
    @Published private(set) var liveMaxSpeedMph: Double = 0
    @Published private(set) var startedAt: Date?

    private var client: SupabaseClient { SupabaseManager.shared.client }

    private var recordingId = UUID()
    private var roomId: UUID?
    private var userId: UUID?
    private var route: [RoutePoint] = []
    private var distanceMeters: Double = 0
    private var maxSpeedMps: Double = 0
    private var lastCoord: CLLocationCoordinate2D?

    var liveDurationS: TimeInterval { startedAt.map { Date().timeIntervalSince($0) } ?? 0 }

    func start(roomId: UUID?, userId: UUID) {
        recordingId = UUID()
        self.roomId = roomId
        self.userId = userId
        route = []; distanceMeters = 0; maxSpeedMps = 0; lastCoord = nil
        startedAt = Date()
        isRecording = true
    }

    /// Feed a location (wired from `LocationService.onLocation`).
    func ingest(_ loc: CLLocation) {
        guard isRecording else { return }
        if let last = lastCoord {
            distanceMeters += CLLocation(latitude: last.latitude, longitude: last.longitude)
                .distance(from: loc)
        }
        lastCoord = loc.coordinate
        if loc.speed > maxSpeedMps { maxSpeedMps = loc.speed }
        route.append(RoutePoint(lat: loc.coordinate.latitude, lng: loc.coordinate.longitude,
                                t: Date(), speed: loc.speed >= 0 ? loc.speed : nil))
        liveDistanceMiles = distanceMeters / 1609.344
        liveMaxSpeedMph = maxSpeedMps * 2.2369362921
    }

    /// Stop and persist. Returns the saved stats for the summary screen.
    @discardableResult
    func stopAndSave(title: String? = nil) async -> RideStats? {
        guard isRecording, let userId else { isRecording = false; return nil }
        isRecording = false
        let ended = Date()
        let started = startedAt ?? ended
        let duration = ended.timeIntervalSince(started)
        let avg = duration > 0 ? distanceMeters / duration : 0

        let recording = RideRecording(
            id: recordingId, roomId: roomId, userId: userId,
            title: title, startedAt: started, endedAt: ended, route: route
        )
        let stats = RideStats(
            recordingId: recordingId,
            distanceM: distanceMeters, durationS: duration,
            avgSpeedMps: avg, maxSpeedMps: maxSpeedMps,
            startedAt: started, endedAt: ended
        )

        do {
            _ = try await client.from("ride_recordings").insert(recording).execute()
            _ = try await client.from("ride_stats").insert(stats).execute()
        } catch {
            #if DEBUG
            print("⚠️ failed to save ride: \(error)")
            #endif
        }
        startedAt = nil
        return stats
    }

    // MARK: - History

    func history(userId: UUID, limit: Int = 50) async throws -> [RideRecording] {
        try await client.from("ride_recordings").select()
            .eq("user_id", value: userId.uuidString)
            .order("started_at", ascending: false).limit(limit)
            .execute().value
    }

    func stats(recordingId: UUID) async throws -> RideStats? {
        let rows: [RideStats] = try await client.from("ride_stats").select()
            .eq("recording_id", value: recordingId.uuidString)
            .execute().value
        return rows.first
    }
}
