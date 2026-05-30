import SwiftUI

/// Create Ride Room screen: name + separation-alert threshold, then start.
struct CreateRoomView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var threshold: Double = 1.0   // miles
    @State private var isBusy = false

    private let thresholdOptions: [Double] = [0.5, 1.0, 2.0]

    var body: some View {
        ZStack {
            Color.rideBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    RideCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Label("Ride name", systemImage: "flag.checkered").font(.title3.bold())
                            TextField("Saturday Canyon Run", text: $name)
                                .textFieldStyle(.roundedBorder).foregroundStyle(.black)
                        }
                    }

                    RideCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Label("Separation alert", systemImage: "ruler").font(.title3.bold())
                            Text("Get alerted when a rider falls this far behind the lead rider.")
                                .font(.caption).foregroundStyle(.secondary)
                            Picker("Threshold", selection: $threshold) {
                                ForEach(thresholdOptions, id: \.self) { mi in
                                    Text(mi == 0.5 ? "½ mile" : "\(Int(mi)) mi").tag(mi)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    Button { create() } label: {
                        Text("Start ride").font(.title3.bold())
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                    }
                    .background(Color.rideAccent, in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(.black)

                    Text("You'll be the host and the initial lead rider. You can hand off the lead during the ride.")
                        .font(.footnote).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            if isBusy { Color.black.opacity(0.4).ignoresSafeArea(); ProgressView().tint(.white).scaleEffect(1.5) }
        }
        .navigationTitle("Create Ride")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func create() {
        isBusy = true
        Task {
            await appState.createRoom(name: name, thresholdMiles: threshold)
            isBusy = false
            if appState.activeRoom != nil { dismiss() }
        }
    }
}
