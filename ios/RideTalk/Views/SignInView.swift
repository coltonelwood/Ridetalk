import SwiftUI
import AuthenticationServices

/// Sign in with Apple landing screen. Also surfaces a clear "setup required" note when no
/// backend is configured, and a Demo Mode entry so every screen is reviewable without
/// real credentials.
struct SignInView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isWorking = false

    private var backendConfigured: Bool { appState.env.backendConfigured }

    var body: some View {
        ZStack {
            Color.rideBackground.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundStyle(.rideAccent)

                VStack(spacing: 8) {
                    Text("RideTalk")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                    Text("Talk hands-free with your crew.\nGroup voice, live location, music sync.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .font(.headline)
                }

                Spacer()

                if backendConfigured {
                    SignInWithAppleButton(.signIn) { request in
                        appState.auth.configureRequest(request)
                    } onCompletion: { result in
                        handle(result)
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 24)
                    .disabled(isWorking)
                    .overlay { if isWorking { ProgressView().tint(.black) } }
                } else {
                    setupRequiredCard
                }

                // Demo Mode — always available so every screen is reviewable.
                Button {
                    appState.startDemo()
                } label: {
                    Label("Explore in Demo Mode", systemImage: "play.rectangle.on.rectangle")
                        .font(.headline)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.rideAccent.opacity(0.6)))
                }
                .foregroundStyle(.rideAccent)
                .padding(.horizontal, 24)

                Text("Demo Mode uses sample data and never sends anything. RideTalk is a communication aid, not a substitute for safe riding.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
            }
        }
    }

    private var setupRequiredCard: some View {
        VStack(spacing: 8) {
            Label("Backend not configured", systemImage: "gearshape.2")
                .font(.headline).foregroundStyle(.yellow)
            Text("Add your Supabase + LiveKit values to `Secrets.xcconfig` to enable Sign in with Apple. Until then, explore the app in Demo Mode below.")
                .font(.footnote).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.rideSurface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.yellow.opacity(0.3)))
        .padding(.horizontal, 24)
    }

    private func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            isWorking = true
            Task {
                do {
                    let session = try await appState.auth.handleAuthorization(authorization)
                    let profile = try await appState.auth.fetchProfile(userId: session.userId)
                    await appState.signedIn(profile: profile)
                } catch {
                    appState.report(error)
                }
                isWorking = false
            }
        case .failure(let error):
            // User cancelled is not an error worth surfacing.
            if (error as? ASAuthorizationError)?.code != .canceled {
                appState.report(error)
            }
        }
    }
}
