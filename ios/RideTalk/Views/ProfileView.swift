import SwiftUI

/// Profile / Settings: name, vehicle, emergency contact (placeholder), talk defaults, sign out.
struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var vehicleType = VehicleType.scooter.rawValue
    @State private var vehicleName = ""
    @State private var emergencyContact = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Rider") {
                    HStack {
                        AvatarView(name: displayName.isEmpty ? "R" : displayName,
                                   urlString: appState.profile?.photoURL)
                            .frame(width: 56, height: 56)
                        TextField("Display name", text: $displayName).font(.headline)
                    }
                    // Photo upload is a Phase 1 feature (Supabase Storage).
                    Label("Photo upload coming soon", systemImage: "camera").font(.caption).foregroundStyle(.secondary)
                }

                Section("Vehicle") {
                    Picker("Type", selection: $vehicleType) {
                        ForEach(VehicleType.allCases) { Text($0.rawValue).tag($0.rawValue) }
                    }
                    TextField("Model (e.g. Apollo City Pro)", text: $vehicleName)
                }

                CrashSettingsSection(crash: appState.crash) {
                    appState.simulateRiderDown()
                    dismiss()   // close settings so the countdown (root cover) is visible
                }

                Section {
                    TextField("Name & phone", text: $emergencyContact)
                } header: {
                    Text("Emergency contact")
                } footer: {
                    Text("PLACEHOLDER: stored for a future version that can notify this contact. The SOS button currently alerts your ride group only.")
                }

                Section {
                    Button { save() } label: {
                        HStack { Text("Save"); if isSaving { Spacer(); ProgressView() } }
                    }.disabled(isSaving)
                }

                Section {
                    Button("Sign out", role: .destructive) { Task { await appState.signOut(); dismiss() } }
                } footer: {
                    Text("RideTalk is a communication aid, not a substitute for safe riding. The SOS button alerts your group — call local emergency services directly in a real emergency. Check local laws on earbuds while riding.")
                        .font(.caption2)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .onAppear {
                displayName = appState.profile?.displayName ?? ""
                vehicleType = appState.profile?.vehicleType ?? VehicleType.scooter.rawValue
                vehicleName = appState.profile?.vehicleName ?? ""
                emergencyContact = appState.profile?.emergencyContact ?? ""
            }
        }
    }

}

/// Rider-down detection settings (enable, sensitivity, test). Observes the service so the
/// sensitivity row shows/hides reactively.
struct CrashSettingsSection: View {
    @ObservedObject var crash: CrashDetectionService
    let onSimulate: () -> Void

    var body: some View {
        Section {
            Toggle("Possible crash detection", isOn: $crash.isEnabled)

            if crash.isEnabled {
                Picker("Sensitivity", selection: $crash.sensitivity) {
                    ForEach(CrashSensitivity.allCases) { Text($0.label).tag($0) }
                }
                Text(crash.sensitivity.explanation)
                    .font(.caption).foregroundStyle(.secondary)

                if !crash.isMotionAvailable {
                    Label("No accelerometer here — detection uses speed only (full impact detection runs on a real device).",
                          systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Button {
                onSimulate()
            } label: {
                Label("Simulate rider-down (test)", systemImage: "testtube.2")
            }
        } header: {
            Text("Rider-down detection")
        } footer: {
            Text("Best-effort **possible** crash detection — NOT guaranteed emergency detection. If you don't cancel the countdown, an SOS is sent to your ride group (never to emergency services). Detection runs only during an active ride.")
                .font(.caption2)
        }
    }
}

private extension ProfileView {
    func save() {
        guard let id = appState.profile?.id else { return }
        isSaving = true
        Task {
            do {
                let updated = try await appState.auth.updateProfile(userId: id, ProfileUpdate(
                    displayName: displayName,
                    photoURL: appState.profile?.photoURL,
                    vehicleType: vehicleType,
                    vehicleName: vehicleName,
                    emergencyContact: emergencyContact
                ))
                appState.profile = updated
                dismiss()
            } catch { appState.report(error) }
            isSaving = false
        }
    }
}
