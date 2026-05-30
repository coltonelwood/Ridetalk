import SwiftUI

/// Rider profile: name, scooter type, sign out. (Photo upload is a Phase 1 feature.)
struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var scooterType = ""
    @State private var isSaving = false

    private let scooterPresets = ["Niu", "Segway/Ninebot", "Apollo", "Dualtron",
                                  "VanMoof", "Super73", "Onewheel", "Other"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Rider") {
                    HStack {
                        AvatarView(name: displayName.isEmpty ? "R" : displayName,
                                   urlString: appState.profile?.avatarURL)
                            .frame(width: 56, height: 56)
                        TextField("Display name", text: $displayName)
                            .font(.headline)
                    }
                }

                Section("Scooter type") {
                    TextField("e.g. Apollo City Pro", text: $scooterType)
                    Menu("Pick a preset") {
                        ForEach(scooterPresets, id: \.self) { preset in
                            Button(preset) { scooterType = preset }
                        }
                    }
                }

                Section {
                    Button {
                        save()
                    } label: {
                        HStack {
                            Text("Save")
                            if isSaving { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(isSaving)
                }

                Section {
                    Button("Sign out", role: .destructive) {
                        Task { await appState.signOut(); dismiss() }
                    }
                } footer: {
                    Text("RideTalk is a communication aid, not a substitute for safe riding. The emergency button alerts your group only — call local emergency services directly in a real emergency.")
                        .font(.caption2)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .onAppear {
                displayName = appState.profile?.displayName ?? ""
                scooterType = appState.profile?.scooterType ?? ""
            }
        }
    }

    private func save() {
        guard let id = appState.profile?.id else { return }
        isSaving = true
        Task {
            do {
                let updated = try await appState.supabase.updateProfile(
                    userId: id,
                    ProfileUpdate(displayName: displayName,
                                  avatarURL: appState.profile?.avatarURL,
                                  scooterType: scooterType)
                )
                appState.profile = updated
                dismiss()
            } catch {
                appState.report(error)
            }
            isSaving = false
        }
    }
}
