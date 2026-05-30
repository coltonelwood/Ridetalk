import SwiftUI

/// The safety-first **Active Ride** screen. Dominant push-to-talk; big Mute / SOS / Music;
/// glanceable status; lead-rider + separation + safety banners; map preview; rider list.
struct ActiveRideView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm: ActiveRideViewModel
    @State private var showInvite = false

    init(app: AppState) {
        _vm = StateObject(wrappedValue: ActiveRideViewModel(app: app))
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.rideBackground.ignoresSafeArea()

            VStack(spacing: 12) {
                header
                StatusStrip(vm: vm)
                banners

                leadRiderChip

                MapPreview(vm: vm)
                    .frame(height: 130)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .onTapGesture { vm.showMap = true }

                Spacer(minLength: 4)

                PushToTalkButton(
                    isTransmitting: vm.isTransmitting,
                    someoneElseTalking: vm.someoneElseTalking,
                    mode: vm.ptt.mode,
                    onPressDown: { vm.talkPressDown() },
                    onRelease: { vm.talkRelease() }
                )
                .frame(maxHeight: .infinity)
                .opacity(vm.isSelfMuted ? 0.4 : 1)

                Picker("Talk mode", selection: Binding(get: { vm.ptt.mode },
                                                       set: { vm.ptt.setMode($0) })) {
                    ForEach(PushToTalkController.Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                controlRow
                secondaryRow
            }
            .padding()

            if let toast = vm.toast { ToastView(text: toast).padding(.top, 8) }
        }
        // Sheets
        .sheet(isPresented: $vm.showRoster) { RosterView(vm: vm) }
        .sheet(isPresented: $vm.showMap) { MapView(vm: vm) }
        .sheet(isPresented: $vm.showMusic) { MusicLinkView(vm: vm) }
        .sheet(isPresented: $vm.showQuickMessages) { QuickMessagesView(vm: vm) }
        .sheet(isPresented: $showInvite) { ActivityView(items: vm.inviteItems) }
        // Priority SOS alert (another rider needs help)
        .fullScreenCover(item: $vm.presentedSOS) { alert in SOSView(vm: vm, alert: alert) }
        // SOS confirm
        .confirmationDialog("Send an SOS to your group?",
                            isPresented: $vm.showSOSConfirm, titleVisibility: .visible) {
            Button("Send SOS + share my location", role: .destructive) { Task { await vm.raiseSOS() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Alerts your group with a priority signal and pins your location. This does NOT contact emergency services — call them directly if you're in danger.")
        }
        // Leave / end
        .confirmationDialog(vm.isHost ? "End the ride for everyone?" : "Leave this ride?",
                            isPresented: $vm.showLeaveConfirm, titleVisibility: .visible) {
            if vm.isHost { Button("End ride for all", role: .destructive) { Task { await vm.endRide() } } }
            Button(vm.isHost ? "Just leave (keep ride open)" : "Leave",
                   role: vm.isHost ? .none : .destructive) { Task { await vm.leave() } }
            Button("Cancel", role: .cancel) {}
        }
        .animation(.easeInOut, value: vm.activeSOS.map(\.id))
        .animation(.easeInOut, value: vm.separatedRiders.map(\.id))
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(role: .destructive) { vm.showLeaveConfirm = true } label: {
                Label("Leave", systemImage: "xmark.circle.fill").font(.headline)
            }.tint(.secondary)
            Spacer()
            VStack(spacing: 0) {
                Text(vm.room.name).font(.headline).lineLimit(1)
                HStack(spacing: 6) {
                    Text("Code \(vm.room.code)")
                        .font(.system(.subheadline, design: .monospaced)).foregroundStyle(.rideAccent)
                    Text("· \(vm.memberCount) riding").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button { showInvite = true } label: { Image(systemName: "square.and.arrow.up").font(.title3) }
        }
    }

    // MARK: - Banners (SOS, separation, safety)

    @ViewBuilder private var banners: some View {
        ForEach(vm.activeSOS) { alert in
            SOSBanner(name: vm.name(forUserId: alert.userId), alert: alert,
                      canResolve: alert.userId == vm.meId || vm.isHost) {
                Task { await vm.resolveSOS(alert) }
            }
        }
        if !vm.separatedRiders.isEmpty {
            SeparationBanner(separations: vm.separatedRiders) { vm.showMap = true }
        }
        if vm.lowBattery {
            SafetyBanner(text: "Low phone battery — charging soon keeps you on the channel.",
                         icon: "battery.25percent", tint: .rideDanger)
        }
        if vm.stoppedUnexpectedly {
            SafetyBanner(text: "You've been stopped a while. Tap SOS if you need help.",
                         icon: "exclamationmark.triangle.fill", tint: .yellow)
        }
        if vm.connectionState == .reconnecting {
            SafetyBanner(text: "Reconnecting to voice…", icon: "wifi.exclamationmark", tint: .yellow)
        }
    }

    private var leadRiderChip: some View {
        Group {
            if let lead = vm.leadRider {
                HStack(spacing: 8) {
                    Image(systemName: "flag.fill").foregroundStyle(.rideAccent)
                    Text("Lead: \(lead.displayName)").font(.subheadline.bold())
                    if let me = vm.meId, let leadLoc = vm.location(of: lead.userId),
                       let myLoc = vm.location(of: me), me != lead.userId {
                        Text("· \(String(format: "%.1f", myLoc.coordinate.milesTo(leadLoc.coordinate))) mi behind")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: - Controls

    private var controlRow: some View {
        HStack(spacing: 12) {
            controlButton(vm.isSelfMuted ? "Unmute" : "Mute",
                          icon: vm.isSelfMuted ? "mic.slash.fill" : "mic.fill",
                          tint: vm.isSelfMuted ? .rideDanger : .rideSurface,
                          fg: vm.isSelfMuted ? .white : .primary) { vm.toggleSelfMute() }

            controlButton("SOS", icon: "sos", tint: .rideDanger, fg: .white) { vm.showSOSConfirm = true }

            controlButton("Music", icon: "music.note", tint: .rideSurface, fg: .primary) { vm.showMusic = true }
        }
    }

    private var secondaryRow: some View {
        HStack(spacing: 12) {
            controlButton("Riders", icon: "person.3.fill", tint: .rideSurface, fg: .primary, badge: vm.memberCount) { vm.showRoster = true }
            controlButton("Map", icon: "map.fill", tint: .rideSurface, fg: .primary) { vm.showMap = true }
            controlButton("Quick", icon: "bubble.left.and.bubble.right.fill", tint: .rideSurface, fg: .primary) { vm.showQuickMessages = true }
        }
    }

    private func controlButton(_ title: String, icon: String, tint: Color, fg: Color,
                               badge: Int? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon).font(.title2)
                    if let badge {
                        Text("\(badge)").font(.caption2.bold()).padding(5)
                            .background(Color.rideAccent, in: Circle()).foregroundStyle(.black)
                            .offset(x: 12, y: -10)
                    }
                }
                Text(title).font(.caption.bold())
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(tint, in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(fg)
        }
    }
}

/// Transient toast for quick messages / events.
struct ToastView: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.subheadline.bold())
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.1)))
            .shadow(radius: 8)
            .transition(.move(edge: .top).combined(with: .opacity))
    }
}
