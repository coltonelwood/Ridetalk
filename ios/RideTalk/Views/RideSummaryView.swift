import SwiftUI

/// Ride Summary screen — shown after a ride ends (distance, duration, avg/max speed).
struct RideSummaryView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let stats: RideStats

    var body: some View {
        NavigationStack {
            ZStack {
                Color.rideBackground.ignoresSafeArea()
                VStack(spacing: 22) {
                    Image(systemName: "checkered.flag")
                        .font(.system(size: 56)).foregroundStyle(.rideAccent).padding(.top, 20)
                    Text("Ride complete").font(.largeTitle.bold())

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        statTile("Distance", String(format: "%.1f", stats.distanceMiles), "mi", "ruler")
                        statTile("Duration", stats.durationFormatted, "", "clock")
                        statTile("Avg speed", String(format: "%.0f", stats.avgSpeedMph), "mph", "speedometer")
                        statTile("Max speed", String(format: "%.0f", stats.maxSpeedMph), "mph", "gauge.high")
                    }
                    .padding(.horizontal)

                    if let start = stats.startedAt, let end = stats.endedAt {
                        Text("\(start.formatted(date: .abbreviated, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened))")
                            .font(.footnote).foregroundStyle(.secondary)
                    }

                    Spacer()
                    Button { appState.lastSavedStats = nil; dismiss() } label: {
                        Text("Done").font(.title3.bold())
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(Color.rideAccent, in: RoundedRectangle(cornerRadius: 16))
                            .foregroundStyle(.black)
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(false)
        }
    }

    private func statTile(_ title: String, _ value: String, _ unit: String, _ icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title3).foregroundStyle(.rideAccent)
            Text(value).font(.system(size: 30, weight: .heavy, design: .rounded)) +
                Text(unit.isEmpty ? "" : " \(unit)").font(.headline).foregroundColor(.secondary)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 20)
        .background(Color.rideSurface, in: RoundedRectangle(cornerRadius: 18))
    }
}
