import SwiftUI

/// Home: start or join a ride, jump back into saved groups, view profile / history.
struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showProfile = false
    @State private var showHistory = false
    @State private var showPermissions = false
    @State private var savedRooms: [RideRoom] = []
    @State private var isBusy = false

    /// Show the "before you ride" nudge until mic + location are settled.
    private var needsPermissionSetup: Bool {
        guard !appState.isDemo else { return false }
        let micOK = appState.audio.micPermission == .granted
        let locOK = [.authorizedWhenInUse, .authorizedAlways].contains(appState.location.authorizationStatus)
        return !(micOK && locOK)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.rideBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        greeting

                        NavigationLink {
                            CreateRoomView()
                        } label: {
                            bigAction("Start a ride", subtitle: "Create a private channel",
                                      icon: "flag.checkered", tint: .rideAccent, fg: .black)
                        }

                        NavigationLink {
                            JoinRoomView()
                        } label: {
                            bigAction("Join a ride", subtitle: "Enter a code or tap an invite",
                                      icon: "person.2.wave.2.fill", tint: .rideTalk, fg: .black)
                        }

                        if needsPermissionSetup { permissionsNudge }

                        if !savedRooms.isEmpty { savedGroups }

                        Text("Voice runs over the internet (cellular/WiFi) — not Bluetooth range. Pop in your AirPods before you start.")
                            .font(.footnote).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center).padding(.horizontal)
                    }
                    .padding()
                }

                if isBusy {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    ProgressView().tint(.white).scaleEffect(1.5)
                }
            }
            .navigationTitle("RideTalk")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showHistory = true } label: { Image(systemName: "clock.arrow.circlepath") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showProfile = true } label: { Image(systemName: "person.crop.circle").font(.title2) }
                }
            }
            .sheet(isPresented: $showProfile) { ProfileView() }
            .sheet(isPresented: $showHistory) { RideHistoryView() }
            .sheet(isPresented: $showPermissions) { PermissionsView() }
            .sheet(item: $appState.lastSavedStats) { stats in
                RideSummaryView(stats: stats)
            }
            .task { await loadSaved() }
        }
    }

    private var greeting: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Hey \(appState.profile?.displayName ?? "Rider") 👋").font(.title.bold())
                if let v = appState.profile?.vehicleName ?? appState.profile?.vehicleType, !v.isEmpty {
                    Text(v).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    private var permissionsNudge: some View {
        Button { showPermissions = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.shield").font(.title2).foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Before you ride").font(.headline)
                    Text("Set up microphone & location — takes 10 seconds.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color.rideSurface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.yellow.opacity(0.3)))
        }
        .foregroundStyle(.primary)
    }

    private var savedGroups: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Saved groups").font(.headline)
            ForEach(savedRooms) { room in
                Button {
                    rejoin(room)
                } label: {
                    HStack {
                        Image(systemName: "person.3.fill").foregroundStyle(.rideAccent)
                        VStack(alignment: .leading) {
                            Text(room.name).font(.headline)
                            Text("Code \(room.code)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if room.status == .active {
                            Text("LIVE").font(.caption2.bold())
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.rideAccent, in: Capsule()).foregroundStyle(.black)
                        }
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                    }
                    .padding()
                    .background(Color.rideSurface, in: RoundedRectangle(cornerRadius: 16))
                }
                .foregroundStyle(.primary)
            }
        }
    }

    private func bigAction(_ title: String, subtitle: String, icon: String, tint: Color, fg: Color) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon).font(.system(size: 34, weight: .bold))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.title2.bold())
                Text(subtitle).font(.subheadline).opacity(0.8)
            }
            Spacer()
        }
        .foregroundStyle(fg)
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(tint, in: RoundedRectangle(cornerRadius: 20))
    }

    private func loadSaved() async {
        if appState.isDemo { savedRooms = [DemoData.room]; return }
        savedRooms = (try? await appState.rooms.savedRooms()) ?? []
    }

    private func rejoin(_ room: RideRoom) {
        isBusy = true
        Task { await appState.joinRoom(code: room.code); isBusy = false }
    }
}
