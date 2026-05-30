import SwiftUI
import AuthenticationServices

/// Sign in with Apple landing screen.
struct SignInView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isWorking = false

    var body: some View {
        ZStack {
            Color.rideBackground.ignoresSafeArea()

            VStack(spacing: 28) {
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
                .overlay {
                    if isWorking { ProgressView().tint(.black) }
                }

                Text("By continuing you agree to ride responsibly. RideTalk is a communication aid, not a substitute for safe riding.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
            }
        }
    }

    private func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            isWorking = true
            Task {
                do {
                    let session = try await appState.auth.handleAuthorization(authorization)
                    let profile = try await appState.supabase.fetchProfile(userId: session.userId)
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
