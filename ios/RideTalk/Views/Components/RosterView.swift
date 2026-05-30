import SwiftUI

/// Connected riders, with speaking/mute indicators, lead-rider flag, distance-from-lead,
/// and host moderation (mute / remove / make lead). Host can also set the separation
/// threshold here.
struct RosterView: View {
    @ObservedObject var vm: ActiveRideViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if vm.isHost { hostSettings }

                Section("\(vm.memberCount) riding") {
                    ForEach(vm.members) { member in row(member) }
                }
            }
            .navigationTitle("Riders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }

    private var hostSettings: some View {
        Section("Separation alert (host)") {
            Picker("Alert distance", selection: Binding(
                get: { vm.room.separationThresholdMiles },
                set: { newVal in Task { await vm.setThreshold(newVal) } }
            )) {
                Text("½ mile").tag(0.5)
                Text("1 mile").tag(1.0)
                Text("2 miles").tag(2.0)
            }
        }
    }

    private func row(_ member: RoomMember) -> some View {
        HStack(spacing: 12) {
            AvatarView(name: member.displayName, urlString: member.profile?.photoURL)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(member.displayName).font(.headline)
                    if member.isHost { tag("HOST", .rideAccent) }
                    if vm.isLead(member) { tag("LEAD", .rideTalk) }
                    if member.userId == vm.meId { Text("YOU").font(.caption2).foregroundStyle(.secondary) }
                }
                HStack(spacing: 6) {
                    if let v = member.profile?.vehicleName ?? member.profile?.vehicleType, !v.isEmpty {
                        Text(v).font(.caption).foregroundStyle(.secondary)
                    }
                    if let dist = distanceFromLead(member) {
                        Text("· \(String(format: "%.1f", dist)) mi from lead")
                            .font(.caption).foregroundStyle(dist >= vm.room.separationThresholdMiles ? .rideDanger : .secondary)
                    }
                }
            }
            Spacer()

            if vm.isSpeaking(member) { SpeakingIndicator() }
            if member.isMuted { Image(systemName: "mic.slash.fill").foregroundStyle(.rideDanger) }

            if vm.isHost && member.userId != vm.meId {
                Menu {
                    Button { Task { await vm.makeLead(member) } } label: { Label("Make lead rider", systemImage: "flag") }
                    Button { Task { await vm.toggleMute(member) } } label: {
                        Label(member.isMuted ? "Unmute" : "Mute", systemImage: member.isMuted ? "mic" : "mic.slash")
                    }
                    Button(role: .destructive) { Task { await vm.remove(member) } } label: {
                        Label("Remove from ride", systemImage: "person.fill.xmark")
                    }
                } label: { Image(systemName: "ellipsis.circle").font(.title3) }
            }
        }
        .padding(.vertical, 4)
    }

    private func distanceFromLead(_ m: RoomMember) -> Double? {
        guard let lead = vm.room.leadRiderId, lead != m.userId,
              let leadLoc = vm.location(of: lead), let loc = vm.location(of: m.userId) else { return nil }
        return loc.coordinate.milesTo(leadLoc.coordinate)
    }

    private func tag(_ text: String, _ color: Color) -> some View {
        Text(text).font(.caption2.bold())
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color, in: Capsule()).foregroundStyle(.black)
    }
}

/// Animated "speaking" waveform (iOS 17 symbol effect, opacity-pulse fallback on iOS 16).
struct SpeakingIndicator: View {
    @State private var pulse = false
    var body: some View {
        Group {
            if #available(iOS 17.0, *) {
                Image(systemName: "waveform").symbolEffect(.variableColor.iterative, options: .repeating)
            } else {
                Image(systemName: "waveform").opacity(pulse ? 0.4 : 1.0)
                    .onAppear { withAnimation(.easeInOut(duration: 0.6).repeatForever()) { pulse = true } }
            }
        }
        .foregroundStyle(.rideTalk)
    }
}

/// Circular avatar with initials fallback.
struct AvatarView: View {
    let name: String
    let urlString: String?
    var body: some View {
        Group {
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: { initials }
            } else { initials }
        }
        .clipShape(Circle()).overlay(Circle().stroke(.white.opacity(0.1), lineWidth: 1))
    }
    private var initials: some View {
        ZStack { Color.rideTalk.opacity(0.3); Text(String(name.prefix(1)).uppercased()).font(.headline.bold()) }
    }
}
