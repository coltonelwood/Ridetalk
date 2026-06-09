import SwiftUI
import MapKit

/// Full-screen group map: every rider with name, direction of travel, speed; lead rider
/// and SOS riders highlighted; disconnected riders shown at last known location.
struct MapView: View {
    @ObservedObject var vm: ActiveRideViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))

    var body: some View {
        NavigationStack {
            Map(coordinateRegion: $region, showsUserLocation: true, annotationItems: vm.locations) { loc in
                MapAnnotation(coordinate: loc.coordinate) { RiderPin(loc: loc, vm: vm) }
            }
            .overlay {
                if vm.locations.isEmpty {
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("Waiting for rider locations…").font(.headline)
                        Text("Pins appear as soon as riders share a fix. Make sure Location is allowed in Settings → RideTalk.")
                            .font(.caption).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                    .padding(40)
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Group Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarLeading) { Button { recenter() } label: { Image(systemName: "scope") } }
            }
            .onAppear(perform: recenter)
        }
    }

    private func recenter() {
        let coords = vm.locations.map(\.coordinate)
        guard let first = coords.first else { return }
        var minLat = first.latitude, maxLat = first.latitude, minLng = first.longitude, maxLng = first.longitude
        for c in coords {
            minLat = min(minLat, c.latitude); maxLat = max(maxLat, c.latitude)
            minLng = min(minLng, c.longitude); maxLng = max(maxLng, c.longitude)
        }
        region = MKCoordinateRegion(
            center: .init(latitude: (minLat + maxLat) / 2, longitude: (minLng + maxLng) / 2),
            span: .init(latitudeDelta: max(0.008, (maxLat - minLat) * 1.6),
                        longitudeDelta: max(0.008, (maxLng - minLng) * 1.6)))
    }
}

/// A single rider marker.
struct RiderPin: View {
    let loc: LiveLocation
    @ObservedObject var vm: ActiveRideViewModel

    private var isLead: Bool { loc.userId == vm.room.leadRiderId }
    private var hasSOS: Bool { vm.activeSOS.contains { $0.userId == loc.userId } }
    private var name: String { vm.name(forUserId: loc.userId) }

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle().fill(pinColor).frame(width: 32, height: 32)
                    .opacity(loc.isConnected ? 1 : 0.5)
                Image(systemName: hasSOS ? "exclamationmark" : (isLead ? "flag.fill" : "scooter"))
                    .font(.caption.bold()).foregroundStyle(.black)
                // Direction-of-travel arrow.
                if let heading = loc.heading, loc.speedMph > 1 {
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 9)).foregroundStyle(.white)
                        .rotationEffect(.degrees(heading)).offset(y: -22)
                }
            }
            Text("\(name)\(loc.speedMph > 1 ? " · \(Int(loc.speedMph))" : "")")
                .font(.caption2.bold())
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(.black.opacity(0.65), in: Capsule())
        }
    }

    private var pinColor: Color {
        if hasSOS { return .rideDanger }
        if isLead { return .rideAccent }
        return loc.isConnected ? .rideTalk : .gray
    }
}

/// Compact, non-interactive map preview embedded in the Active Ride screen.
struct MapPreview: View {
    @ObservedObject var vm: ActiveRideViewModel
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))

    var body: some View {
        Map(coordinateRegion: .constant(region), interactionModes: [],
            showsUserLocation: true, annotationItems: vm.locations) { loc in
            MapAnnotation(coordinate: loc.coordinate) {
                Circle().fill(loc.userId == vm.room.leadRiderId ? Color.rideAccent : .rideTalk)
                    .frame(width: 14, height: 14).overlay(Circle().stroke(.black, lineWidth: 1.5))
            }
        }
        .allowsHitTesting(false)
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.caption).padding(6).background(.black.opacity(0.5), in: Circle()).padding(6)
        }
        .onChange(of: vm.locations.map(\.id)) { _ in fit() }
        .onAppear(perform: fit)
    }

    private func fit() {
        let coords = vm.locations.map(\.coordinate)
        guard let first = coords.first else { return }
        var minLat = first.latitude, maxLat = first.latitude, minLng = first.longitude, maxLng = first.longitude
        for c in coords {
            minLat = min(minLat, c.latitude); maxLat = max(maxLat, c.latitude)
            minLng = min(minLng, c.longitude); maxLng = max(maxLng, c.longitude)
        }
        region = MKCoordinateRegion(
            center: .init(latitude: (minLat + maxLat) / 2, longitude: (minLng + maxLng) / 2),
            span: .init(latitudeDelta: max(0.006, (maxLat - minLat) * 1.8),
                        longitudeDelta: max(0.006, (maxLng - minLng) * 1.8)))
    }
}
