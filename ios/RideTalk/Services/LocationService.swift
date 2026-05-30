import Foundation
import Combine
import CoreLocation
import UIKit
import Supabase

/// Publishes the rider's location into the active room (broadcast + `live_locations`
/// upsert for "last known"), exposes live speed/battery, and feeds the ride recorder.
/// Background updates run **only while a ride is active** (started/stopped explicitly).
@MainActor
final class LocationService: NSObject, ObservableObject {

    @Published private(set) var current: CLLocation?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var speedMph: Double = 0
    @Published private(set) var batteryLevel: Float = 1.0
    @Published private(set) var isStoppedUnexpectedly = false

    /// Called on every accepted location update (for ride recording).
    var onLocation: ((CLLocation) -> Void)?

    private var client: SupabaseClient { SupabaseManager.shared.client }
    private let manager = CLLocationManager()
    private var roomId: UUID?
    private var userId: UUID?

    private let minBroadcastInterval: TimeInterval = 3.0
    private var lastBroadcast: Date = .distantPast
    private var lastMovementAt: Date = Date()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .otherNavigation
        manager.distanceFilter = 5
        UIDevice.current.isBatteryMonitoringEnabled = true
        batteryLevel = UIDevice.current.batteryLevel
    }

    func requestAuthorization() { manager.requestWhenInUseAuthorization() }

    /// Begin sharing location for a ride (enables background updates).
    func start(roomId: UUID, userId: UUID) {
        self.roomId = roomId
        self.userId = userId
        if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
        manager.allowsBackgroundLocationUpdates = true     // only on while riding
        manager.pausesLocationUpdatesAutomatically = false
        lastMovementAt = Date()
    }

    /// Stop sharing (disables background updates — important for battery & privacy).
    func stop() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
        manager.allowsBackgroundLocationUpdates = false
        roomId = nil; userId = nil; speedMph = 0
    }

    func currentCoordinate() -> CLLocationCoordinate2D? { current?.coordinate }

    private var signalQuality: LiveLocation.Signal {
        // Coarse heuristic from horizontal accuracy.
        guard let acc = current?.horizontalAccuracy, acc >= 0 else { return .lost }
        if acc < 25 { return .good }
        if acc < 100 { return .weak }
        return .lost
    }
}

extension LocationService: CLLocationManagerDelegate {

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.current = loc
            self.speedMph = max(0, loc.speed) * 2.2369362921
            self.batteryLevel = UIDevice.current.batteryLevel
            self.onLocation?(loc)

            // "Stopped unexpectedly" heuristic: no meaningful speed for a while.
            if loc.speed > 1.0 { self.lastMovementAt = Date(); self.isStoppedUnexpectedly = false }
            else if Date().timeIntervalSince(self.lastMovementAt) > 120 { self.isStoppedUnexpectedly = true }

            await self.publishIfNeeded(loc)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in self.authorizationStatus = manager.authorizationStatus }
    }

    @MainActor
    private func publishIfNeeded(_ loc: CLLocation) async {
        guard let roomId, let userId,
              Date().timeIntervalSince(lastBroadcast) >= minBroadcastInterval else { return }
        lastBroadcast = Date()

        let live = LiveLocation(
            roomId: roomId, userId: userId,
            lat: loc.coordinate.latitude, lng: loc.coordinate.longitude,
            speedMps: loc.speed >= 0 ? loc.speed : nil,
            heading: loc.course >= 0 ? loc.course : nil,
            battery: UIDevice.current.batteryLevel,
            signal: signalQuality,
            isConnected: true,
            updatedAt: Date()
        )

        // Instant fan-out + durable "last known".
        await SupabaseManager.shared.broadcastLocation(live)
        _ = try? await client.from("live_locations").upsert(live, onConflict: "room_id,user_id").execute()
    }
}
