import SwiftUI

/// Music Link screen. Share a Spotify / Apple Music / YouTube Music **link**; every rider
/// opens their own copy. RideTalk never captures or rebroadcasts audio. Future full-sync
/// controls (play/pause/timestamp) are scaffolded as a disabled placeholder.
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
                        if let m = vm.music { currentCard(m) }
                        shareCard
                        syncPlaceholder
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

    private func currentCard(_ m: SharedMusicLink) -> some View {
        RideCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Shared • \(m.provider.displayName)", systemImage: "dot.radiowaves.left.and.right").font(.headline)
                Text(m.title ?? m.url).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                if let url = URL(string: m.url) {
                    Link(destination: url) {
                        Label("Open in \(m.provider.displayName)", systemImage: "arrow.up.right.square")
                            .font(.subheadline.bold())
                    }
                }
            }
        }
    }

    private var shareCard: some View {
        RideCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Share a track", systemImage: "music.note.list").font(.headline)
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

    /// PLACEHOLDER for future synced playback controls.
    private var syncPlaceholder: some View {
        RideCard {
            VStack(alignment: .leading, spacing: 8) {
                Label("Synced playback", systemImage: "slider.horizontal.3").font(.headline)
                Text("Coming soon: play / pause / scrub the whole group in time. Requires Apple Music (MusicKit) or Spotify Premium (App Remote) — opt-in per rider.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    ForEach(["backward.fill", "play.fill", "forward.fill"], id: \.self) { icon in
                        Image(systemName: icon).font(.title3)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                .foregroundStyle(.tertiary)
            }
        }
        .opacity(0.7)
    }

    private var complianceNote: some View {
        Text("RideTalk syncs the *track*, not the audio — everyone listens in their own app. Your voice automatically ducks the music when someone talks.")
            .font(.caption2).foregroundStyle(.tertiary).multilineTextAlignment(.center)
    }
}
