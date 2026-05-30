import SwiftUI

/// Music screen. The host shares a track **link** and controls shared play/pause/position;
/// each rider opts into syncing, and their OWN music app (Apple Music via MusicKit, Spotify
/// via App Remote) plays their OWN copy. RideTalk never captures or rebroadcasts audio.
/// See MusicSyncService and docs/MUSIC_SYNC.md.
struct MusicLinkView: View {
    @ObservedObject var vm: ActiveRideViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var link = ""
    @State private var title = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.rideBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        if let m = vm.music {
                            currentCard(m)
                            if vm.isHost { hostControls(m) } else { riderSync(m) }
                        }
                        shareCard
                        complianceNote
                    }
                    .padding()
                }
            }
            .navigationTitle("Music")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.large])
    }

    // MARK: - Current track

    private func currentCard(_ m: SharedMusicLink) -> some View {
        RideCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Shared • \(m.provider.displayName)", systemImage: "dot.radiowaves.left.and.right")
                        .font(.headline)
                    Spacer()
                    if m.isPlaying {
                        Label("Playing", systemImage: "play.fill").font(.caption.bold()).foregroundStyle(.rideAccent)
                    } else {
                        Label("Paused", systemImage: "pause.fill").font(.caption.bold()).foregroundStyle(.secondary)
                    }
                }
                Text(m.title ?? m.url).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                Text("Position \(formatMs(m.projectedPositionMs))")
                    .font(.system(.caption, design: .monospaced)).foregroundStyle(.rideAccent)
                if let url = URL(string: m.url) {
                    Link(destination: url) {
                        Label("Open in \(m.provider.displayName)", systemImage: "arrow.up.right.square")
                            .font(.subheadline.bold())
                    }
                }
            }
        }
    }

    // MARK: - Host controls

    @ViewBuilder private func hostControls(_ m: SharedMusicLink) -> some View {
        RideCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Host controls", systemImage: "slider.horizontal.3").font(.headline)
                if m.provider.supportsSyncedPlayback {
                    HStack(spacing: 12) {
                        controlButton(m.isPlaying ? "Pause" : "Play",
                                      icon: m.isPlaying ? "pause.fill" : "play.fill", tint: .rideAccent) {
                            Task { m.isPlaying ? await vm.hostPause() : await vm.hostPlay() }
                        }
                        controlButton("Restart", icon: "backward.end.fill", tint: .rideSurface) {
                            Task { await vm.hostRestart() }
                        }
                    }
                    Text("Riders who turn on Sync will follow your play/pause and position.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Synced playback isn't available for \(m.provider.displayName). Riders can still open the link to play it themselves.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Rider sync

    @ViewBuilder private func riderSync(_ m: SharedMusicLink) -> some View {
        RideCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Sync playback", systemImage: "arrow.triangle.2.circlepath").font(.headline)

                switch vm.syncStatus {
                case .unsupported(let name):
                    fallbackRow("Sync isn't supported for \(name). Open the link to listen.", m)
                case .needsApp(let name):
                    fallbackRow("\(name) isn't installed. Install it or open the link in a browser.", m)
                case .needsAuth(let name):
                    Text("Allow RideTalk to control \(name) when prompted, then toggle Sync again.")
                        .font(.caption).foregroundStyle(.secondary)
                    syncToggle
                case .error(let msg):
                    Text(msg).font(.caption).foregroundStyle(.rideDanger)
                    syncToggle
                case .off, .syncing, .paused:
                    Text(syncSubtitle).font(.caption).foregroundStyle(.secondary)
                    syncToggle
                    if vm.isSyncEnabled {
                        Button { Task { await vm.resyncMusic() } } label: {
                            Label("Re-sync to host", systemImage: "arrow.clockwise")
                                .font(.subheadline.bold())
                        }
                    }
                }
            }
        }
    }

    private var syncToggle: some View {
        Toggle(isOn: Binding(get: { vm.isSyncEnabled },
                             set: { _ in Task { await vm.toggleMusicSync() } })) {
            Text(vm.isSyncEnabled ? "Following the host" : "Sync with host")
        }
        .tint(.rideAccent)
    }

    private var syncSubtitle: String {
        switch vm.syncStatus {
        case .syncing: return "In sync — playing in your own \(vm.music?.provider.displayName ?? "music app")."
        case .paused: return "In sync — paused by the host."
        default: return "Play the shared track in your own app, in time with the group. Needs Apple Music or Spotify Premium."
        }
    }

    private func fallbackRow(_ text: String, _ m: SharedMusicLink) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text).font(.caption).foregroundStyle(.secondary)
            if let url = URL(string: m.url) {
                Link(destination: url) {
                    Label("Open in \(m.provider.displayName)", systemImage: "arrow.up.right.square").font(.subheadline.bold())
                }
            }
        }
    }

    // MARK: - Share

    private var shareCard: some View {
        RideCard {
            VStack(alignment: .leading, spacing: 12) {
                Label(vm.isHost ? "Share a track" : "Suggest a track", systemImage: "music.note.list").font(.headline)
                Text("Paste a Spotify, Apple Music, or YouTube Music link.")
                    .font(.caption).foregroundStyle(.secondary)
                TextField("https://open.spotify.com/track/…", text: $link)
                    .textFieldStyle(.roundedBorder).foregroundStyle(.black)
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                TextField("Title (optional)", text: $title)
                    .textFieldStyle(.roundedBorder).foregroundStyle(.black)
                Button {
                    Task { await vm.shareMusic(url: link, title: title); link = ""; title = "" }
                } label: {
                    Text("Share with group").font(.headline)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                .background(Color.rideAccent, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.black)
                .disabled(URL(string: link)?.scheme == nil)
            }
        }
    }

    private var complianceNote: some View {
        Text("RideTalk syncs the *track* and timing — never the audio. Everyone listens through their own Apple Music / Spotify account, and your voice automatically ducks the music when someone talks.")
            .font(.caption2).foregroundStyle(.tertiary).multilineTextAlignment(.center)
    }

    private func controlButton(_ title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(.headline)
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(tint, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(tint == .rideAccent ? .black : .primary)
        }
    }

    private func formatMs(_ ms: Int) -> String {
        let total = ms / 1000
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
