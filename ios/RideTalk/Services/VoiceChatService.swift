import Foundation
import LiveKit
import Combine

/// Group voice over LiveKit (WebRTC/Opus). Push-to-talk is implemented by toggling the
/// local mic *publish*, not by reconnecting — fast, battery-friendly, no hot mic.
///
/// NOTE: LiveKit `RoomDelegate` signatures evolve across SDK versions; if a callback stops
/// firing after a version bump, check the installed SDK's `RoomDelegate`.
@MainActor
final class VoiceChatService: NSObject, ObservableObject {

    enum State: Equatable { case disconnected, connecting, connected, reconnecting }

    @Published private(set) var state: State = .disconnected
    @Published private(set) var isTransmitting = false
    @Published private(set) var speakingIdentities: Set<String> = []
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
        try await room.connect(
            url: url, token: token,
            connectOptions: ConnectOptions(),
            roomOptions: RoomOptions(adaptiveStream: false, dynacast: false)
        )
        // Start muted — push-to-talk enables the mic only while talking.
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

    // MARK: - Transmit (PTT / VOX)

    func startTransmitting() async {
        guard state == .connected || state == .reconnecting else { return }
        do { try await room.localParticipant.setMicrophone(enabled: true); isTransmitting = true }
        catch { isTransmitting = false }
    }

    func stopTransmitting() async {
        try? await room.localParticipant.setMicrophone(enabled: false)
        isTransmitting = false
    }

    func setTransmitting(_ on: Bool) {
        Task { on ? await startTransmitting() : await stopTransmitting() }
    }

    /// Local mute (separate from host-enforced mute): fully stop publishing.
    func setSelfMuted(_ muted: Bool) {
        Task { try? await room.localParticipant.setMicrophone(enabled: !muted && isTransmitting) }
    }
}

extension VoiceChatService: RoomDelegate {
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
