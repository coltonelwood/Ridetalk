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
        Group {
            switch appState.phase {
            case .loading:
                LoadingView()
            case .signedOut:
                SignInView()
            case .signedIn:
                if let room = appState.activeRoom {
                    RideRoomView(room: room, app: appState)
                        .transition(.move(edge: .bottom))
                } else {
                    HomeView()
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
