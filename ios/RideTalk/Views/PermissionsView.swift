import SwiftUI
import CoreLocation
import AVFoundation

/// Pre-ride permissions explainer: shows what RideTalk needs, **why**, and the current
/// status of each — with in-context request buttons (or a jump to Settings when denied).
/// Reachable from Home ("Before you ride" card) and Profile.
struct PermissionsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var micStatus: AudioSessionManager.MicPermission = .undetermined

    var body: some View {
        NavigationStack {
            ZStack {
                Color.rideBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        header

                        permissionCard(
                            icon: "mic.fill",
                            title: "Microphone",
                            why: "So your crew can hear you. The mic only transmits while you hold Talk (or in hands-free mode) — never otherwise.",
                            status: micStatusText, granted: micStatus == .granted, denied: micStatus == .denied
                        ) {
                            Task {
                                _ = await appState.audio.requestMicPermission()
                                refresh()
                            }
                        }

                        permissionCard(
                            icon: "location.fill",
                            title: "Location",
                            why: "So your group sees you on the map and gets separation/SOS alerts. Shared only with your ride room, only during a ride.",
                            status: locationStatusText, granted: locationGranted, denied: locationDenied
                        ) {
                            appState.location.requestAuthorization()
                        }

                        infoCard(
                            icon: "figure.fall",
                            title: "Motion",
                            text: "Used during rides for possible crash detection (a best-effort safety aid). iOS grants accelerometer access automatically — nothing to approve here."
                        )

                        Text("You can change any of these later in iOS Settings → RideTalk.")
                            .font(.footnote).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
            }
            .navigationTitle("Permissions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .onAppear(perform: refresh)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 44)).foregroundStyle(.rideAccent)
            Text("Ready to ride?").font(.title2.bold())
            Text("RideTalk needs two permissions to work on the road. Here's exactly what each one does.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
    }

    private func permissionCard(icon: String, title: String, why: String,
                                status: String, granted: Bool, denied: Bool,
                                request: @escaping () -> Void) -> some View {
        RideCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(title, systemImage: icon).font(.headline)
                    Spacer()
                    Text(status)
                        .font(.caption.bold())
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(granted ? Color.rideAccent : (denied ? Color.rideDanger : Color.rideSurface.opacity(0.6)),
                                    in: Capsule())
                        .foregroundStyle(granted || denied ? .black : .secondary)
                        .overlay(Capsule().stroke(.white.opacity(granted || denied ? 0 : 0.2)))
                }
                Text(why).font(.subheadline).foregroundStyle(.secondary)

                if denied {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Enable in Settings", systemImage: "gear")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                    }
                    .background(Color.rideSurface.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.15)))
                } else if !granted {
                    Button(action: request) {
                        Text("Allow \(title)")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                    }
                    .background(Color.rideAccent, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.black)
                }
            }
        }
    }

    private func infoCard(icon: String, title: String, text: String) -> some View {
        RideCard {
            VStack(alignment: .leading, spacing: 8) {
                Label(title, systemImage: icon).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Status

    private func refresh() {
        micStatus = appState.audio.micPermission
    }

    private var micStatusText: String {
        switch micStatus {
        case .granted: return "Allowed"
        case .denied: return "Denied"
        case .undetermined: return "Not asked yet"
        }
    }

    private var locationGranted: Bool {
        [.authorizedWhenInUse, .authorizedAlways].contains(appState.location.authorizationStatus)
    }
    private var locationDenied: Bool {
        [.denied, .restricted].contains(appState.location.authorizationStatus)
    }
    private var locationStatusText: String {
        switch appState.location.authorizationStatus {
        case .authorizedAlways: return "Always"
        case .authorizedWhenInUse: return "While using"
        case .denied, .restricted: return "Denied"
        default: return "Not asked yet"
        }
    }
}
