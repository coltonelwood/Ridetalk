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

    let env = AppEnvironment.shared
    private var cancellables: Set<AnyCancellable> = []

    var isDemo: Bool { env.isDemoMode }

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
        // Demo Mode: skip auth/network entirely and sign in with the sample profile.
        if env.isDemoMode {
            profile = DemoData.profile
            phase = .signedIn
            return
        }
        // No backend configured → land on the sign-in screen, which offers Demo Mode and
        // a clear "setup required" note instead of crashing.
        guard env.backendConfigured else { phase = .signedOut; return }
        do {
            if let session = try await auth.restoreSession() {
                profile = try await auth.fetchProfile(userId: session.userId)
                phase = .signedIn
                await consumePendingJoinIfPossible()
            } else { phase = .signedOut }
        } catch { phase = .signedOut; report(error) }
    }

    /// Enter Demo Mode from the sign-in screen.
    func startDemo() {
        env.enableDemo()
        profile = DemoData.profile
        phase = .signedIn
    }

    /// Leave Demo Mode (also signs out).
    func exitDemo() {
        env.disableDemo()
        activeRoom = nil
        profile = nil
        phase = .signedOut
    }

    func signedIn(profile: RiderProfile) async {
        self.profile = profile
        phase = .signedIn
        await consumePendingJoinIfPossible()
    }

    func signOut() async {
        if env.isDemoMode { exitDemo(); return }
        await leaveActiveRoom()
        try? await auth.signOut()
        profile = nil
        phase = .signedOut
    }

    // MARK: - Rooms

    func createRoom(name: String, thresholdMiles: Double) async {
        guard let profile else { return }
        if env.isDemoMode { enterDemoRide(); return }
        do {
            let room = try await rooms.create(name: name, thresholdMiles: thresholdMiles)
            try await enter(room: room, as: profile)
        } catch { report(error) }
    }

    func joinRoom(code: String) async {
        guard profile != nil else { return }
        if env.isDemoMode { enterDemoRide(); return }
        let cleaned = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleaned.isEmpty else { return }
        do {
            let room = try await rooms.join(code: cleaned)
            try await enter(room: room, as: profile!)
        } catch { report(error) }
    }

    private func enter(room: RideRoom, as profile: RiderProfile) async throws {
        // Mic permission first, with a friendly error if it's been denied.
        switch audio.micPermission {
        case .denied:
            throw RideTalkError.micDenied
        case .undetermined:
            _ = await audio.requestMicPermission()   // joining still works listen-only if refused
        case .granted:
            break
        }
        try audio.activateForVoice()                                   // AirPods route ready
        let token = try await fetchVoiceToken(roomId: room.id)
        try await voice.connect(url: token.url, token: token.token, identity: token.identity)
        location.start(roomId: room.id, userId: profile.id)            // background updates on
        recording.start(roomId: room.id, userId: profile.id)          // auto-record the ride
        crash.start()                                                  // possible rider-down detection
        await supabase.subscribe(to: room)                            // roster/location/music/sos/msgs
        activeRoom = room
    }

    /// Demo Mode "enter ride": seed local sample state, no network/voice. Crash detection
    /// still starts so the simulate flow works; location starts for the speed readout.
    private func enterDemoRide() {
        supabase.loadDemoState()
        crash.start()
        location.start(roomId: DemoData.roomId, userId: DemoData.meId)
        activeRoom = DemoData.room
    }

    func leaveActiveRoom() async {
        guard let room = activeRoom else { return }
        crash.stop()
        musicSync.disableSync()
        riderDownEvent = nil
        location.stop()
        audio.deactivate()
        if env.isDemoMode {
            supabase.clearDemoState()
            activeRoom = nil
            return
        }
        lastSavedStats = await recording.stopAndSave()                // save the ride
        await voice.disconnect()
        await supabase.unsubscribe()
        try? await rooms.leave(roomId: room.id)
        activeRoom = nil
    }

    func endActiveRoom() async {
        guard let room = activeRoom else { return }
        if !env.isDemoMode { try? await rooms.end(roomId: room.id) }
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
        // In Demo Mode, surface the alert locally instead of hitting the network.
        if env.isDemoMode, event?.isDemo == false {
            supabase.addDemoSOS(kind: .possibleCrash)
            return
        }
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
        errorMessage = ErrorMessage(text: Self.friendlyMessage(for: error))
    }

    /// Map raw SDK/network errors to rider-friendly text. Unknown errors fall back to
    /// their own description rather than jargon like error codes.
    static func friendlyMessage(for error: Error) -> String {
        if let rt = error as? RideTalkError { return rt.errorDescription ?? "Something went wrong." }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                return "No internet connection. Check cellular/Wi-Fi and try again."
            case .timedOut:
                return "The connection timed out. Weak signal? Try again in a moment."
            case .cannotFindHost, .cannotConnectToHost:
                return "Couldn't reach the RideTalk server. Check your connection (or the backend setup) and try again."
            default:
                return "Network problem — please try again."
            }
        }
        let msg = error.localizedDescription
        if msg.localizedCaseInsensitiveContains("room not found") {
            return "No active ride with that code. Double-check the code with your host."
        }
        if msg.localizedCaseInsensitiveContains("not authenticated") || msg.localizedCaseInsensitiveContains("jwt") {
            return "Your session expired. Please sign in again."
        }
        return msg
    }
}

/// App-level errors with rider-friendly wording.
enum RideTalkError: LocalizedError {
    case micDenied
    case backendUnconfigured

    var errorDescription: String? {
        switch self {
        case .micDenied:
            return "Microphone access is off, so your crew can't hear you. Enable it in Settings → RideTalk → Microphone, then rejoin."
        case .backendUnconfigured:
            return "The backend isn't set up yet. Add Supabase + LiveKit values to Secrets.xcconfig, or use Demo Mode."
        }
    }
}

struct ErrorMessage: Identifiable {
    let id = UUID()
    let text: String
}
