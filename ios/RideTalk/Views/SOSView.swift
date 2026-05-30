import SwiftUI
import MapKit

/// SOS Alert screen — shown full-screen as a priority interrupt when a rider needs help.
/// Shows who, their location on a map, fastest-route directions, and acknowledge/resolve.
struct SOSView: View {
    @ObservedObject var vm: ActiveRideViewModel
    let alert: SOSAlert

    @State private var region: MKCoordinateRegion

    init(vm: ActiveRideViewModel, alert: SOSAlert) {
        self.vm = vm
        self.alert = alert
        let center = alert.coordinate ?? CLLocationCoordinate2D(latitude: 37.77, longitude: -122.41)
        _region = State(initialValue: MKCoordinateRegion(
            center: center, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)))
    }

    private var name: String { vm.name(forUserId: alert.userId) }
    private var canResolve: Bool { alert.userId == vm.meId || vm.isHost }

    var body: some View {
        ZStack {
            Color.rideDanger.ignoresSafeArea()
            VStack(spacing: 18) {
                Spacer().frame(height: 8)
                Image(systemName: alert.isPossibleCrash ? "figure.fall" : "sos")
                    .font(.system(size: 64, weight: .black))
                Text(alert.isPossibleCrash ? "Possible crash" : "\(name) needs help")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                if alert.isPossibleCrash {
                    Text("\(name) may be down — auto-detected, unconfirmed")
                        .font(.headline).opacity(0.9).multilineTextAlignment(.center)
                } else if let msg = alert.message, !msg.isEmpty {
                    Text(msg).font(.headline).opacity(0.9)
                }

                if let coord = alert.coordinate {
                    Map(coordinateRegion: $region, annotationItems: [alert]) { a in
                        MapAnnotation(coordinate: coord) {
                            Image(systemName: "mappin.circle.fill").font(.largeTitle).foregroundStyle(.white)
                        }
                    }
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .padding(.horizontal)

                    Link(destination: URL(string: "http://maps.apple.com/?daddr=\(coord.latitude),\(coord.longitude)&dirflg=d")!) {
                        Label("Fastest route to \(name)", systemImage: "location.fill")
                            .font(.title3.bold()).frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(.white, in: RoundedRectangle(cornerRadius: 16))
                            .foregroundStyle(Color.rideDanger)
                    }
                    .padding(.horizontal)
                } else {
                    Text("No location was shared with this alert.").padding()
                }

                Spacer()

                VStack(spacing: 12) {
                    Button { vm.dismissSOSScreen(alert) } label: {
                        Text("On my way").font(.title3.bold())
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 16))
                    }
                    if canResolve {
                        Button {
                            Task { await vm.resolveSOS(alert); vm.dismissSOSScreen(alert) }
                        } label: {
                            Text("Mark resolved").font(.headline)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.6)))
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .foregroundStyle(.white)
        }
    }
}
