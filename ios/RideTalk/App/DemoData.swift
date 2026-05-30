import Foundation
import CoreLocation

/// Local sample data used in **Demo Mode** so every screen renders realistically without a
/// backend or real riding. Pure value factories — no network, no persistence.
enum DemoData {

    static let meId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let janeId = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    static let leoId = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    static let roomId = UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!

    static var profile: RiderProfile {
        RiderProfile(userId: meId, displayName: "You (Demo)", photoURL: nil,
                     vehicleType: VehicleType.scooter.rawValue, vehicleName: "Apollo City Pro",
                     emergencyContact: nil)
    }

    static var room: RideRoom {
        RideRoom(id: roomId, code: "DEMO42", name: "Sunset Canyon Run", hostId: meId,
                 leadRiderId: janeId, status: .active, separationThresholdMiles: 1.0,
                 createdAt: Date().addingTimeInterval(-600), endedAt: nil)
    }

    static var roster: [RoomMember] {
        [
            RoomMember(roomId: roomId, userId: meId, role: .host, isMuted: false, subgroup: .none,
                       leftAt: nil, profile: profile),
            RoomMember(roomId: roomId, userId: janeId, role: .rider, isMuted: false, subgroup: .none,
                       leftAt: nil, profile: RiderProfile(userId: janeId, displayName: "Jane",
                       photoURL: nil, vehicleType: VehicleType.motorcycle.rawValue,
                       vehicleName: "Zero SR/F", emergencyContact: nil)),
            RoomMember(roomId: roomId, userId: leoId, role: .rider, isMuted: true, subgroup: .none,
                       leftAt: nil, profile: RiderProfile(userId: leoId, displayName: "Leo",
                       photoURL: nil, vehicleType: VehicleType.ebike.rawValue,
                       vehicleName: "Super73", emergencyContact: nil)),
        ]
    }

    /// Three riders spread around San Francisco; Leo is ~1.4 mi back (triggers separation).
    static var locations: [UUID: LiveLocation] {
        func loc(_ id: UUID, _ lat: Double, _ lng: Double, speed: Double, heading: Double,
                 connected: Bool = true) -> LiveLocation {
            LiveLocation(roomId: roomId, userId: id, lat: lat, lng: lng, speedMps: speed,
                         heading: heading, battery: 0.7, signal: .good, isConnected: connected,
                         updatedAt: Date())
        }
        return [
            meId: loc(meId, 37.7749, -122.4194, speed: 9.0, heading: 90),
            janeId: loc(janeId, 37.7765, -122.4180, speed: 10.5, heading: 88),
            leoId: loc(leoId, 37.7600, -122.4350, speed: 0, heading: 0, connected: false),
        ]
    }

    static var music: SharedMusicLink {
        SharedMusicLink(id: UUID(), roomId: roomId, userId: janeId,
                        url: "https://music.apple.com/us/album/_/1?i=1", provider: .appleMusic,
                        title: "Demo Track — Sample Artist", isPlaying: true, positionMs: 42_000,
                        createdAt: Date(), updatedAt: Date())
    }

    static var quickMessages: [QuickMessage] {
        [
            QuickMessage(id: UUID(), roomId: roomId, userId: janeId, kind: .slowDown,
                         text: QuickMessageKind.slowDown.label, isPriority: true,
                         createdAt: Date().addingTimeInterval(-30)),
            QuickMessage(id: UUID(), roomId: roomId, userId: leoId, kind: .behind,
                         text: QuickMessageKind.behind.label, isPriority: false,
                         createdAt: Date().addingTimeInterval(-90)),
        ]
    }

    static func sampleRecordings() -> [(RideRecording, RideStats)] {
        let id = UUID()
        let start = Date().addingTimeInterval(-3600)
        let end = Date().addingTimeInterval(-1800)
        let rec = RideRecording(id: id, roomId: roomId, userId: meId, title: "Morning loop",
                                startedAt: start, endedAt: end, route: [])
        let stats = RideStats(recordingId: id, distanceM: 12_300, durationS: 1800,
                              avgSpeedMps: 6.8, maxSpeedMps: 13.4, startedAt: start, endedAt: end)
        return [(rec, stats)]
    }
}
