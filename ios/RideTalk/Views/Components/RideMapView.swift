import SwiftUI
import MapKit

/// Group map: shows every rider's last-known location. Secondary surface (sheet) so it's
/// not the primary thing you're looking at while moving.
struct RideMapView: View {
    @ObservedObject var vm: RideRoomViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    var body: some View {
        NavigationStack {
            Map(coordinateRegion: $region,
                showsUserLocation: true,
                annotationItems: vm.locations) { loc in
                MapAnnotation(coordinate: loc.coordinate) {
                    riderPin(for: loc)
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Group Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        recenter()
                    } label: { Image(systemName: "scope") }
                }
            }
            .onAppear(perform: recenter)
        }
    }

    private func riderPin(for loc: RiderLocation) -> some View {
        let name = vm.members.first { $0.userId == loc.userId }?.displayName ?? "Rider"
        return VStack(spacing: 2) {
            ZStack {
                Circle().fill(.rideAccent).frame(width: 30, height: 30)
                Image(systemName: "scooter").font(.caption).foregroundStyle(.black)
            }
            Text(name).font(.caption2.bold())
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(.black.opacity(0.6), in: Capsule())
        }
    }

    /// Fit the map around all riders (or center on me if I'm the only ping).
    private func recenter() {
        let coords = vm.locations.map { $0.coordinate }
        guard let first = coords.first else { return }
        var minLat = first.latitude, maxLat = first.latitude
        var minLng = first.longitude, maxLng = first.longitude
        for c in coords {
            minLat = min(minLat, c.latitude); maxLat = max(maxLat, c.latitude)
            minLng = min(minLng, c.longitude); maxLng = max(maxLng, c.longitude)
        }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                            longitude: (minLng + maxLng) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.01, (maxLat - minLat) * 1.5),
            longitudeDelta: max(0.01, (maxLng - minLng) * 1.5)
        )
        region = MKCoordinateRegion(center: center, span: span)
    }
}
