import Foundation
import SwiftUI

/// App-wide coordinator: owns the auth session, the active room, and the long-lived
/// services. Views observe this via `@EnvironmentObject`.
@MainActor
final class AppState: ObservableObject {

    enum Phase { case loading, signedOut, signedIn }

    @Published var phase: Phase = .loading
    @Published var profile: UserProfile?
    @Published var activeRoom: RideRoom?
    @Published var errorMessage: ErrorMessage?

    /// A join code captured from a deep link before the user is signed in.
    @Published var pendingJoinCode: String?

    // Long-lived services
    let supabase = SupabaseService.shared
    let auth: AuthService
    let voice = VoiceService()
    let location = LocationService()
    let audio = AudioSessionManager.shared

    init() {
        self.auth = AuthService(supabase: supabase)
    }

    // MARK: - Lifecycle

    /// Restore an existing session on launch.
    func bootstrap() async {
        do {
            if let session = try await auth.restoreSession() {
                self.profile = try await supabase.fetchProfile(userId: session.userId)
                self.phase = .signedIn
                await consumePendingJoinIfPossible()
            } else {
                self.phase = .signedOut
            }
        } catch {
            self.phase = .signedOut
            report(error)
        }
    }

    func signedIn(profile: UserProfile) async {
        self.profile = profile
        self.phase = .signedIn
        await consumePendingJoinIfPossible()
    }

    func signOut() async {
        await leaveActiveRoom()
        try? await auth.signOut()
        self.profile = nil
        self.phase = .signedOut
    }

    // MARK: - Rooms

    func createRoom(named name: String) async {
        guard let profile else { return }
        do {
            let room = try await supabase.createRoom(named: name)
            try await enter(room: room, as: profile)
        } catch {
            report(error)
        }
    }

    func joinRoom(code: String) async {
        guard let profile else { return }
        let cleaned = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleaned.isEmpty else { return }
        do {
            let room = try await supabase.joinRoom(code: cleaned)
            try await enter(room: room, as: profile)
        } catch {
            report(error)
        }
    }

    /// Connect voice + location + realtime for a room and show the riding UI.
    private func enter(room: RideRoom, as profile: UserProfile) async throws {
        // 1. Audio session up first so AirPods route is ready before connecting voice.
        try audio.activateForVoice()

        // 2. Mint a LiveKit token and connect.
        let token = try await supabase.liveKitToken(roomId: room.id)
        try await voice.connect(url: token.url, token: token.token, identity: token.identity)

        // 3. Start sharing location into the room.
        location.start(roomId: room.id, userId: profile.id, supabase: supabase)

        // 4. Subscribe to realtime room state (roster, music, emergency).
        await supabase.subscribeToRoom(roomId: room.id)

        self.activeRoom = room
    }

    func leaveActiveRoom() async {
        guard let room = activeRoom else { return }
        location.stop()
        await voice.disconnect()
        await supabase.unsubscribeFromRoom()
        audio.deactivate()
        try? await supabase.leaveRoom(roomId: room.id)
        self.activeRoom = nil
    }

    /// Host-only: end the ride for everyone.
    func endActiveRoom() async {
        guard let room = activeRoom else { return }
        try? await supabase.endRoom(roomId: room.id)
        await leaveActiveRoom()
    }

    // MARK: - Deep links  (ridetalk://join/<CODE>)

    func handleDeepLink(_ url: URL) {
        guard url.scheme == AppConfig.deepLinkScheme else { return }
        // ridetalk://join/ABC123  → host == "join", last path component == code
        let parts = ([url.host] + url.pathComponents).compactMap { $0 }
        guard let joinIdx = parts.firstIndex(where: { $0.lowercased() == "join" }),
              joinIdx + 1 < parts.count else { return }
        let code = parts[joinIdx + 1]
        pendingJoinCode = code
        Task { await consumePendingJoinIfPossible() }
    }

    private func consumePendingJoinIfPossible() async {
        guard phase == .signedIn, let code = pendingJoinCode else { return }
        pendingJoinCode = nil
        await joinRoom(code: code)
    }

    // MARK: - Errors

    func report(_ error: Error) {
        #if DEBUG
        print("❌ \(error)")
        #endif
        errorMessage = ErrorMessage(text: error.localizedDescription)
    }
}

/// Identifiable wrapper so we can drive a SwiftUI `.alert(item:)`.
struct ErrorMessage: Identifiable {
    let id = UUID()
    let text: String
}
