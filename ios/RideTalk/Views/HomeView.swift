import SwiftUI

/// Home: create a ride, join by code, or open your profile.
struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var joinCode = ""
    @State private var roomName = ""
    @State private var showProfile = false
    @State private var isBusy = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.rideBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        greeting

                        // Start a ride
                        RideCard {
                            VStack(alignment: .leading, spacing: 14) {
                                Label("Start a ride", systemImage: "flag.checkered")
                                    .font(.title2.bold())
                                TextField("Ride name (optional)", text: $roomName)
                                    .textFieldStyle(.roundedBorder)
                                    .foregroundStyle(.black)
                                Button {
                                    create()
                                } label: {
                                    Text("Create room")
                                        .font(.title3.bold())
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                }
                                .background(Color.rideAccent, in: RoundedRectangle(cornerRadius: 14))
                                .foregroundStyle(.black)
                            }
                        }

                        // Join a ride
                        RideCard {
                            VStack(alignment: .leading, spacing: 14) {
                                Label("Join a ride", systemImage: "person.2.wave.2")
                                    .font(.title2.bold())
                                TextField("Enter 6-char code", text: $joinCode)
                                    .textInputAutocapitalization(.characters)
                                    .autocorrectionDisabled()
                                    .textFieldStyle(.roundedBorder)
                                    .foregroundStyle(.black)
                                    .font(.system(.title3, design: .monospaced))
                                Button {
                                    join()
                                } label: {
                                    Text("Join room")
                                        .font(.title3.bold())
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                }
                                .background(Color.rideTalk, in: RoundedRectangle(cornerRadius: 14))
                                .foregroundStyle(.black)
                                .disabled(joinCode.trimmingCharacters(in: .whitespaces).count < 4)
                            }
                        }

                        Text("Voice runs over the internet (cellular/WiFi) — not Bluetooth range. Pop in your AirPods before you start.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)

                if isBusy {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    ProgressView().tint(.white).scaleEffect(1.5)
                }
            }
            .navigationTitle("RideTalk")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showProfile = true } label: {
                        Image(systemName: "person.crop.circle")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
            }
        }
    }

    private var greeting: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Hey \(appState.profile?.displayName ?? "Rider") 👋")
                    .font(.title.bold())
                if let scooter = appState.profile?.scooterType, !scooter.isEmpty {
                    Text(scooter)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    private func create() {
        isBusy = true
        Task {
            await appState.createRoom(named: roomName)
            isBusy = false
        }
    }

    private func join() {
        isBusy = true
        Task {
            await appState.joinRoom(code: joinCode)
            isBusy = false
        }
    }
}
