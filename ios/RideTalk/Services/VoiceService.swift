import Foundation
import LiveKit
import Combine

/// Group voice over LiveKit (WebRTC/Opus). Implements push-to-talk by toggling the local
/// mic *publish* on/off rather than tearing down the connection — fast, battery-friendly,
/// privacy-preserving (no hot mic).
///
/// NOTE: LiveKit delegate method signatures evolve across SDK versions; if a callback
/// doesn't fire after `xcodegen generate`, check the installed SDK version's `RoomDelegate`.
@MainActor
final class VoiceService: NSObject, ObservableObject {

    enum State: Equatable { case disconnected, connecting, connected, reconnecting }

    @Published private(set) var state: State = .disconnected
    /// Whether we're currently transmitting (mic published).
    @Published private(set) var isTransmitting = false
    /// Identities (Supabase user IDs) of participants currently speaking.
    @Published private(set) var speakingIdentities: Set<String> = []
    /// True when any *remote* participant is speaking (used to show "incoming" + ducking).
    @Published private(set) var remoteIsSpeaking = false

    let room = Room()
    private var localIdentity: String?

    override init() {
        super.init()
        room.add(delegate: self)
    }

    // MARK: - Connection

    func connect(url: String, token: String, identity: String) async throws {
        localIdentity = identity
        state = .connecting

        // Defaults are well-suited to voice. We deliberately start with the mic OFF and
        // enable it only while transmitting (push-to-talk / VOX).
        let roomOptions = RoomOptions(
            adaptiveStream: false,
            dynacast: false
        )

        try await room.connect(
            url: url,
            token: token,
            connectOptions: ConnectOptions(),
            roomOptions: roomOptions
        )

        // Ensure we start muted (push-to-talk). Mic enabled only while the button is held.
        try? await room.localParticipant.setMicrophone(enabled: false)
        isTransmitting = false
        state = .connected
    }

    func disconnect() async {
        await room.disconnect()
        state = .disconnected
        isTransmitting = false
        speakingIdentities = []
        remoteIsSpeaking = false
    }

    // MARK: - Push-to-talk / VOX

    /// Start transmitting (hold-to-talk down, or VOX gate opens).
    func startTransmitting() async {
        guard state == .connected || state == .reconnecting else { return }
        do {
            try await room.localParticipant.setMicrophone(enabled: true)
            isTransmitting = true
        } catch {
            isTransmitting = false
        }
    }

    /// Stop transmitting (release PTT, or VOX gate closes).
    func stopTransmitting() async {
        try? await room.localParticipant.setMicrophone(enabled: false)
        isTransmitting = false
    }

    /// Convenience used by the big PTT button.
    func setTransmitting(_ on: Bool) {
        Task { on ? await startTransmitting() : await stopTransmitting() }
    }
}

// MARK: - RoomDelegate

extension VoiceService: RoomDelegate {

    nonisolated func room(_ room: Room,
                          didUpdateConnectionState connectionState: ConnectionState,
                          from oldConnectionState: ConnectionState) {
        Task { @MainActor in
            switch connectionState {
            case .connected:    self.state = .connected
            case .connecting:   self.state = .connecting
            case .reconnecting: self.state = .reconnecting
            case .disconnected: self.state = .disconnected
            @unknown default:   break
            }
        }
    }

    nonisolated func room(_ room: Room, didUpdateSpeakingParticipants participants: [Participant]) {
        Task { @MainActor in
            let ids = Set(participants.compactMap { $0.identity?.stringValue })
            self.speakingIdentities = ids
            self.remoteIsSpeaking = ids.contains { $0 != self.localIdentity }
        }
    }
}
