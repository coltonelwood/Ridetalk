import SwiftUI

/// Connected riders, with speaking indicator and host moderation (mute / remove).
struct RosterView: View {
    @ObservedObject var vm: RideRoomViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(vm.members) { member in
                        row(member)
                    }
                } header: {
                    Text("\(vm.members.count) riding")
                } footer: {
                    if vm.isHost {
                        Text("As host you can mute or remove riders. Mute is enforced for everyone.")
                    }
                }
            }
            .navigationTitle("Riders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(_ member: RoomMember) -> some View {
        HStack(spacing: 12) {
            AvatarView(name: member.displayName, urlString: member.profile?.avatarURL)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(member.displayName).font(.headline)
                    if member.isHost {
                        Text("HOST")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.rideAccent, in: Capsule())
                            .foregroundStyle(.black)
                    }
                    if member.userId == vm.meId {
                        Text("YOU").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                if let scooter = member.profile?.scooterType, !scooter.isEmpty {
                    Text(scooter).font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer()

            if vm.isSpeaking(member) {
                SpeakingIndicator()
            }
            if member.isMuted {
                Image(systemName: "mic.slash.fill").foregroundStyle(.rideDanger)
            }

            // Host moderation menu
            if vm.isHost && member.userId != vm.meId {
                Menu {
                    Button {
                        Task { await vm.toggleMute(member) }
                    } label: {
                        Label(member.isMuted ? "Unmute" : "Mute",
                              systemImage: member.isMuted ? "mic" : "mic.slash")
                    }
                    Button(role: .destructive) {
                        Task { await vm.remove(member) }
                    } label: {
                        Label("Remove from ride", systemImage: "person.fill.xmark")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").font(.title3)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// Animated "speaking" waveform. Uses the iOS 17 symbol effect when available, with a
/// simple opacity pulse fallback for iOS 16.
struct SpeakingIndicator: View {
    @State private var pulse = false
    var body: some View {
        Group {
            if #available(iOS 17.0, *) {
                Image(systemName: "waveform")
                    .symbolEffect(.variableColor.iterative, options: .repeating)
            } else {
                Image(systemName: "waveform")
                    .opacity(pulse ? 0.4 : 1.0)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.6).repeatForever()) { pulse = true }
                    }
            }
        }
        .foregroundStyle(.rideTalk)
    }
}

/// Simple circular avatar with initials fallback.
struct AvatarView: View {
    let name: String
    let urlString: String?

    var body: some View {
        Group {
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    initials
                }
            } else {
                initials
            }
        }
        .clipShape(Circle())
        .overlay(Circle().stroke(.white.opacity(0.1), lineWidth: 1))
    }

    private var initials: some View {
        ZStack {
            Color.rideTalk.opacity(0.3)
            Text(String(name.prefix(1)).uppercased())
                .font(.headline.bold())
        }
    }
}
