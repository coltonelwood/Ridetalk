import SwiftUI

/// Compliant **Sync Mode** UI. The host shares a track *link*; riders open their own copy
/// and re-sync to the broadcast position. RideTalk never captures or rebroadcasts audio.
/// See docs/MUSIC_COMPLIANCE.md.
struct ShareMusicView: View {
    @ObservedObject var vm: RideRoomViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var link = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.rideBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        // Current shared track (everyone sees this)
                        if let state = vm.musicState {
                            currentTrackCard(state)
                        }

                        if vm.isHost {
                            hostShareCard
                        } else {
                            Text("The host controls the shared track. Open it in your own music app and tap re-sync to stay together.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        complianceNote
                    }
                    .padding()
                }
            }
            .navigationTitle("Music Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.large])
    }

    private func currentTrackCard(_ state: MusicState) -> some View {
        RideCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Now syncing • \(state.provider.displayName)", systemImage: "dot.radiowaves.left.and.right")
                    .font(.headline)
                Text(state.title ?? state.trackURL)
                    .font(.subheadline)
                    .lineLimit(2)
                    .foregroundStyle(.secondary)

                HStack {
                    Text("Target: \(formatMs(state.projectedPositionMs))")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.rideAccent)
                    Spacer()
                    if let url = URL(string: state.trackURL) {
                        Link(destination: url) {
                            Label("Open in \(state.provider.displayName)", systemImage: "arrow.up.right.square")
                                .font(.subheadline.bold())
                        }
                    }
                }
            }
        }
    }

    private var hostShareCard: some View {
        RideCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Share a track", systemImage: "music.note.list").font(.headline)
                Text("Paste an Apple Music or Spotify track link.")
                    .font(.caption).foregroundStyle(.secondary)
                TextField("https://open.spotify.com/track/…", text: $link)
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(.black)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Button {
                    Task {
                        await vm.shareMusic(link: link)
                        link = ""
                    }
                } label: {
                    Text("Share with group")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .background(Color.rideAccent, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.black)
                .disabled(URL(string: link)?.scheme == nil)
            }
        }
    }

    private var complianceNote: some View {
        Text("RideTalk syncs *which* track and the play position — everyone listens in their own music app. We never rebroadcast audio, so this stays within Apple Music / Spotify rules.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
    }

    private func formatMs(_ ms: Int) -> String {
        let total = ms / 1000
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
