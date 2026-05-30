import SwiftUI

@main
struct RideTalkApp: App {
    /// Single source of truth for session + active room, injected into the environment.
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .tint(.rideAccent)
                .preferredColorScheme(.dark) // riding UI reads best in dark
                .onOpenURL { url in
                    appState.handleDeepLink(url)
                }
        }
    }
}

/// Decides what to show based on auth + active-room state.
struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            if appState.isDemo && appState.phase == .signedIn {
                DemoBanner()
            }
            Group {
                switch appState.phase {
                case .loading:
                    LoadingView()
                case .signedOut:
                    SignInView()
                case .signedIn:
                    if appState.activeRoom != nil {
                        ActiveRideView(app: appState)
                            .transition(.move(edge: .bottom))
                    } else {
                        HomeView()
                    }
                }
            }
        }
        .animation(.easeInOut, value: appState.phase)
        .animation(.easeInOut, value: appState.activeRoom?.id)
        .task {
            await appState.bootstrap()
        }
        .alert(item: $appState.errorMessage) { msg in
            Alert(title: Text("Something went wrong"),
                  message: Text(msg.text),
                  dismissButton: .default(Text("OK")))
        }
        // Possible crash / rider-down countdown — presented at the root so it can appear
        // over any screen (including the settings "Simulate" demo).
        .fullScreenCover(item: $appState.riderDownEvent) { event in
            RiderDownCountdownView(event: event)
                .environmentObject(appState)
        }
    }
}

/// Thin banner shown across the top while in Demo Mode.
struct DemoBanner: View {
    @EnvironmentObject private var appState: AppState
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "play.rectangle.on.rectangle.fill")
            Text(appState.env.demoBanner).font(.caption.bold())
            Spacer()
            Button("Exit") { appState.exitDemo() }
                .font(.caption.bold())
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
        .background(Color.rideAccent)
        .foregroundStyle(.black)
    }
}

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.rideBackground.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.rideAccent)
                ProgressView()
            }
        }
    }
}
