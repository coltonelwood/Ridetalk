import SwiftUI

/// Saved ride history with summary stats per ride.
struct RideHistoryView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var recordings: [RideRecording] = []
    @State private var statsById: [UUID: RideStats] = [:]
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ZStack {
                Color.rideBackground.ignoresSafeArea()
                if isLoading {
                    ProgressView().tint(.white)
                } else if recordings.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "map").font(.largeTitle).foregroundStyle(.secondary)
                        Text("No rides yet").font(.headline)
                        Text("Your recorded rides will appear here.").font(.subheadline).foregroundStyle(.secondary)
                    }
                } else {
                    List {
                        ForEach(recordings) { rec in
                            row(rec)
                        }
                        .listRowBackground(Color.rideSurface)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Ride History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .task { await load() }
        }
    }

    private func row(_ rec: RideRecording) -> some View {
        let stats = statsById[rec.id]
        return VStack(alignment: .leading, spacing: 6) {
            Text(rec.title ?? rec.startedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.headline)
            HStack(spacing: 14) {
                if let s = stats {
                    label("\(String(format: "%.1f", s.distanceMiles)) mi", "ruler")
                    label(s.durationFormatted, "clock")
                    label("\(Int(s.avgSpeedMph)) avg", "speedometer")
                    label("\(Int(s.maxSpeedMph)) max", "gauge.high")
                } else {
                    Text("No stats").font(.caption).foregroundStyle(.secondary)
                }
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func label(_ text: String, _ icon: String) -> some View {
        HStack(spacing: 3) { Image(systemName: icon); Text(text) }
    }

    private func load() async {
        guard let id = appState.profile?.id else { isLoading = false; return }
        recordings = (try? await appState.recording.history(userId: id)) ?? []
        for rec in recordings {
            if let s = try? await appState.recording.stats(recordingId: rec.id) {
                statsById[rec.id] = s
            }
        }
        isLoading = false
    }
}
