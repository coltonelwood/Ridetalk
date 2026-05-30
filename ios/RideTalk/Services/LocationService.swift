import Foundation
import CoreLocation
import UIKit

/// Publishes the rider's location into the active room (throttled) and exposes live
/// speed/heading for the riding UI. Uses background location updates so the group keeps
/// seeing you when the screen is locked (requires the location background mode + an
/// appropriate authorization).
@MainActor
final class LocationService: NSObject, ObservableObject {

    @Published private(set) var current: CLLocation?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    /// Current speed in mph for the big riding readout.
    @Published private(set) var speedMph: Double = 0
    /// Battery 0...1 for the status strip.
    @Published private(set) var batteryLevel: Float = 1.0

    private let manager = CLLocationManager()
    private weak var supabase: SupabaseService?
    private var roomId: UUID?
    private var userId: UUID?

    /// Throttle: don't broadcast more often than this.
    private let minBroadcastInterval: TimeInterval = 3.0
    private var lastBroadcast: Date = .distantPast

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .otherNavigation
        manager.distanceFilter = 5 // meters
        UIDevice.current.isBatteryMonitoringEnabled = true
        batteryLevel = UIDevice.current.batteryLevel
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    /// Begin sharing location into a room.
    func start(roomId: UUID, userId: UUID, supabase: SupabaseService) {
        self.roomId = roomId
        self.userId = userId
        self.supabase = supabase

        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
        // Allow updates to continue in the background while a ride is active.
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
        manager.allowsBackgroundLocationUpdates = false
        roomId = nil
        userId = nil
        supabase = nil
        speedMph = 0
    }

    /// Snapshot for an emergency event.
    func currentCoordinate() -> CLLocationCoordinate2D? { current?.coordinate }
}

extension LocationService: CLLocationManagerDelegate {

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.current = loc
            self.speedMph = max(0, loc.speed) * 2.2369362921
            self.batteryLevel = UIDevice.current.batteryLevel
            await self.broadcastIfNeeded(loc)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
        }
    }

    @MainActor
    private func broadcastIfNeeded(_ loc: CLLocation) async {
        guard
            let supabase, let roomId, let userId,
            Date().timeIntervalSince(lastBroadcast) >= minBroadcastInterval
        else { return }
        lastBroadcast = Date()

        let ping = RiderLocation(
            userId: userId,
            lat: loc.coordinate.latitude,
            lng: loc.coordinate.longitude,
            speedMps: loc.speed >= 0 ? loc.speed : nil,
            heading: loc.course >= 0 ? loc.course : nil,
            battery: UIDevice.current.batteryLevel,
            recordedAt: Date()
        )
        _ = roomId // room scoping is enforced by the active channel in SupabaseService
        await supabase.broadcastLocation(ping, persist: false)
    }
}
