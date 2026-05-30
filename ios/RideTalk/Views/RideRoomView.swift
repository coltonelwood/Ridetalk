import SwiftUI

/// The safety-first **riding interface**: huge push-to-talk, big mute, emergency button,
/// and a glanceable status strip. Map / roster / music live behind big secondary buttons
/// so the primary surface stays minimal while moving.
struct RideRoomView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm: RideRoomViewModel

    @State private var showInvite = false
    @State private var showRoster = false
    @State private var showLeaveConfirm = false

    init(room: RideRoom, app: AppState) {
        // `RootView` passes the shared AppState so we can build the view model in init
        // (EnvironmentObject isn't available here yet).
        _vm = StateObject(wrappedValue: RideRoomViewModel(room: room, app: app))
    }

    var body: some View {
        ZStack {
            Color.rideBackground.ignoresSafeArea()

            VStack(spacing: 16) {
                header
                StatusStrip(vm: vm)

                if let emergency = vm.latestEmergency {
                    EmergencyBanner(event: emergency)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer(minLength: 8)

                // The dominant control — push to talk.
                PushToTalkButton(
                    isTransmitting: vm.isTransmitting,
                    someoneElseTalking: vm.someoneElseTalking,
                    mode: vm.ptt.mode,
                    onPressDown: { vm.talkPressDown() },
                    onRelease: { vm.talkRelease() }
                )
                .frame(maxHeight: .infinity)

                // Talk mode toggle (PTT vs hands-free VOX)
                Picker("Talk mode", selection: Binding(
                    get: { vm.ptt.mode },
                    set: { vm.ptt.setMode($0) }
                )) {
                    ForEach(PushToTalkController.Mode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                // Emergency — big, but guarded by a confirm to avoid accidental taps.
                Button {
                    vm.showEmergencyConfirm = true
                } label: {
                    Label("I need help", systemImage: "exclamationmark.triangle.fill")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                }
                .background(Color.rideDanger, in: RoundedRectangle(cornerRadius: 18))
                .foregroundStyle(.white)

                // Secondary actions
                secondaryControls
            }
            .padding()
        }
        // Music share sheet (host)
        .sheet(isPresented: $vm.showShareMusic) {
            ShareMusicView(vm: vm)
        }
        // Roster + host moderation
        .sheet(isPresented: $showRoster) {
            RosterView(vm: vm)
        }
        // Group map
        .sheet(isPresented: $vm.showMap) {
            RideMapView(vm: vm)
        }
        // Invite share sheet
        .sheet(isPresented: $showInvite) {
            ActivityView(items: vm.inviteItems)
        }
        // Emergency confirm
        .confirmationDialog("Send an emergency alert to your group?",
                            isPresented: $vm.showEmergencyConfirm, titleVisibility: .visible) {
            Button("Send alert + share my location", role: .destructive) {
                Task { await vm.triggerEmergency() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This alerts your ride group and pins your location. It does NOT contact emergency services — call them directly if you're in danger.")
        }
        // Leave / end
        .confirmationDialog(vm.isHost ? "End the ride for everyone?" : "Leave this ride?",
                            isPresented: $showLeaveConfirm, titleVisibility: .visible) {
            if vm.isHost {
                Button("End ride", role: .destructive) { Task { await vm.endRide() } }
            }
            Button(vm.isHost ? "Just leave (keep ride open)" : "Leave", role: vm.isHost ? .none : .destructive) {
                Task { await vm.leave() }
            }
            Button("Cancel", role: .cancel) {}
        }
        .animation(.easeInOut, value: vm.latestEmergency?.id)
    }

    private var header: some View {
        HStack {
            Button(role: .destructive) {
                showLeaveConfirm = true
            } label: {
                Label("Leave", systemImage: "xmark.circle.fill")
                    .font(.headline)
            }
            .tint(.secondary)

            Spacer()

            VStack(spacing: 0) {
                Text(vm.room.name).font(.headline)
                Text("Code \(vm.room.code)")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.rideAccent)
            }

            Spacer()

            Button { showInvite = true } label: {
                Image(systemName: "square.and.arrow.up").font(.title3)
            }
        }
    }

    private var secondaryControls: some View {
        HStack(spacing: 12) {
            secondaryButton("Riders", systemImage: "person.3.fill", count: vm.members.count) {
                showRoster = true
            }
            secondaryButton("Map", systemImage: "map.fill") {
                vm.showMap = true
            }
            secondaryButton("Music", systemImage: "music.note") {
                vm.showShareMusic = true
            }
        }
    }

    private func secondaryButton(_ title: String, systemImage: String, count: Int? = nil,
                                 action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: systemImage).font(.title2)
                    if let count {
                        Text("\(count)")
                            .font(.caption2.bold())
                            .padding(5)
                            .background(Color.rideAccent, in: Circle())
                            .foregroundStyle(.black)
                            .offset(x: 12, y: -10)
                    }
                }
                Text(title).font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.rideSurface, in: RoundedRectangle(cornerRadius: 14))
        }
        .foregroundStyle(.primary)
    }
}
