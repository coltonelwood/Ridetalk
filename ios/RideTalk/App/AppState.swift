import Foundation
import SwiftUI
import Combine
import CoreLocation

/// App-wide coordinator: owns the auth session, the active room, and the long-lived
/// services. Views observe this via `@EnvironmentObject`.
@MainActor
final class AppState: ObservableObject {

    enum Phase { case loading, signedOut, signedIn }

    @Published var phase: Phase = .loading
    @Published var profile: RiderProfile?
    @Published var activeRoom: RideRoom?
    @Published var errorMessage: ErrorMessage?
    @Published var lastSavedStats: RideStats?      // drives the ride-summary screen
    @Published var pendingJoinCode: String?
    @Published var riderDownEvent: RiderDownEvent? // drives the crash-countdown screen

    // Long-lived services
    let supabase = SupabaseManager.shared
    let auth = AuthService()
    let rooms = RideRoomService()
    let voice = VoiceChatService()
    let location = LocationService()
    let audio = AudioSessionManager.shared
    let music = MusicLinkService()
    let musicSync = MusicSyncService()
    let sos = SOSService()
    let recording = RideRecordingService()
    let crash = CrashDetectionService()

    private var cancellables: Set<AnyCancellable> = []

    init() {
        // Feed location updates into the ride recorder AND the crash detector.
        location.onLocation = { [weak self] loc in
            self?.recording.ingest(loc)
            self?.crash.ingest(loc)
        }
        // A possible rider-down → present the countdown screen.
        crash.onTrigger = { [weak self] reason in self?.presentRiderDown(reason: reason) }

        // Feed host-controlled shared music state into the local sync engine.
        supabase.$music
            .receive(on: RunLoop.main)
            .sink { [weak self] link in self?.musicSync.updateSharedState(link) }
            .store(in: &cancellables)
    }

    // MARK: - Lifecycle

    func bootstrap() async {
        do {
            if let session = try await auth.restoreSession() {
                profile = try await auth.fetchProfile(userId: session.userId)
                phase = .signedIn
                await consumePendingJoinIfPossible()
            } else { phase = .signedOut }
        } catch { phase = .signedOut; report(error) }
    }

    func signedIn(profile: RiderProfile) async {
        self.profile = profile
        phase = .signedIn
        await consumePendingJoinIfPossible()
    }

    func signOut() async {
        await leaveActiveRoom()
        try? await auth.signOut()
        profile = nil
        phase = .signedOut
    }

    // MARK: - Rooms

    func createRoom(name: String, thresholdMiles: Double) async {
        guard let profile else { return }
        do {
            let room = try await rooms.create(name: name, thresholdMiles: thresholdMiles)
            try await enter(room: room, as: profile)
        } catch { report(error) }
    }

    func joinRoom(code: String) async {
        guard let profile else { return }
        let cleaned = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleaned.isEmpty else { return }
        do {
            let room = try await rooms.join(code: cleaned)
            try await enter(room: room, as: profile)
        } catch { report(error) }
    }

    private func enter(room: RideRoom, as profile: RiderProfile) async throws {
        try audio.activateForVoice()                                   // AirPods route ready
        let token = try await fetchVoiceToken(roomId: room.id)
        try await voice.connect(url: token.url, token: token.token, identity: token.identity)
        location.start(roomId: room.id, userId: profile.id)            // background updates on
        recording.start(roomId: room.id, userId: profile.id)          // auto-record the ride
        crash.start()                                                  // possible rider-down detection
        await supabase.subscribe(to: room)                            // roster/location/music/sos/msgs
        activeRoom = room
    }

    func leaveActiveRoom() async {
        guard let room = activeRoom else { return }
        crash.stop()
        musicSync.disableSync()
        riderDownEvent = nil
        lastSavedStats = await recording.stopAndSave()                // save the ride
        location.stop()
        await voice.disconnect()
        await supabase.unsubscribe()
        audio.deactivate()
        try? await rooms.leave(roomId: room.id)
        activeRoom = nil
    }

    func endActiveRoom() async {
        guard let room = activeRoom else { return }
        try? await rooms.end(roomId: room.id)
        await leaveActiveRoom()
    }

    private func fetchVoiceToken(roomId: UUID) async throws -> LiveKitToken {
        try await supabase.client.functions.invoke(
            "livekit-token", options: .init(body: ["roomId": roomId.uuidString])
        )
    }

    // MARK: - Possible crash / rider-down

    /// Show the countdown. Demo when there's no active ride (e.g. the settings test button).
    private func presentRiderDown(reason: String) {
        guard riderDownEvent == nil else { return }   // one at a time
        riderDownEvent = RiderDownEvent(
            reason: reason,
            isDemo: activeRoom == nil,
            coordinate: location.currentCoordinate()
        )
    }

    /// Test trigger used by the settings "Simulate" button and the in-ride debug button.
    func simulateRiderDown() { crash.simulate() }

    /// Rider tapped "I'm OK" (or the countdown was dismissed) — no SOS sent.
    func cancelRiderDown() {
        riderDownEvent = nil
        crash.rearm()
    }

    /// Countdown elapsed or rider chose "Send now" — fire a *possible crash* SOS to the room.
    func confirmRiderDown() async {
        let event = riderDownEvent
        riderDownEvent = nil
        crash.rearm()
        guard let room = activeRoom, let me = profile?.id, event?.isDemo == false else { return }
        do {
            try await sos.raise(
                roomId: room.id, userId: me,
                coordinate: location.currentCoordinate(),
                message: "Possible crash / rider down — auto-detected, UNCONFIRMED.",
                kind: .possibleCrash
            )
        } catch { report(error) }
    }

    // MARK: - Deep links  (ridetalk://join/<CODE>)

    func handleDeepLink(_ url: URL) {
        guard url.scheme == AppConfig.deepLinkScheme else { return }
        let parts = ([url.host] + url.pathComponents).compactMap { $0 }
        guard let i = parts.firstIndex(where: { $0.lowercased() == "join" }), i + 1 < parts.count else { return }
        pendingJoinCode = parts[i + 1]
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

struct ErrorMessage: Identifiable {
    let id = UUID()
    let text: String
}
