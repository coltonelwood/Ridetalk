import Foundation
import SwiftUI
import Combine
import CoreLocation

/// View model for the riding screen. Aggregates the live state from the long-lived
/// services (voice, realtime roster/location/music, location) and exposes the host
/// actions. Republishes child `objectWillChange` so the SwiftUI view updates.
@MainActor
final class RideRoomViewModel: ObservableObject {

    let room: RideRoom
    private unowned let app: AppState
    private var cancellables: Set<AnyCancellable> = []

    // Talk mode controller
    let ptt: PushToTalkController

    @Published var showShareMusic = false
    @Published var showEmergencyConfirm = false
    @Published var showMap = false

    init(room: RideRoom, app: AppState) {
        self.room = room
        self.app = app
        self.ptt = PushToTalkController(voice: app.voice)

        // Forward child updates so views re-render.
        for obj in [app.voice.objectWillChange,
                    app.supabase.objectWillChange,
                    app.location.objectWillChange,
                    app.audio.objectWillChange,
                    ptt.objectWillChange] {
            obj.sink { [weak self] _ in self?.objectWillChange.send() }
                .store(in: &cancellables)
        }
    }

    // MARK: - Derived state

    var meId: UUID? { app.profile?.id }
    var isHost: Bool { room.hostId == app.profile?.id }

    var members: [RoomMember] { app.supabase.roster.filter { $0.isActive } }

    var connectionStatus: VoiceService.State { app.voice.state }

    var isReconnecting: Bool {
        app.voice.state == .reconnecting || app.voice.state == .connecting
    }

    /// Whether a *remote* rider is currently talking (drives the "incoming" indicator
    /// and the music ducking visual).
    var someoneElseTalking: Bool { app.voice.remoteIsSpeaking }

    func isSpeaking(_ member: RoomMember) -> Bool {
        app.voice.speakingIdentities.contains(member.userId.uuidString)
    }

    // Riding status strip
    var speedMph: Int { Int(app.location.speedMph.rounded()) }
    var batteryLevel: Float { app.location.batteryLevel }
    var routeName: String { app.audio.currentRouteName }
    var usingBluetooth: Bool { app.audio.isUsingBluetooth }

    // Music (compliant Sync Mode)
    var musicState: MusicState? { app.supabase.musicState }

    // Latest emergency alert (from self or others)
    var latestEmergency: EmergencyEvent? { app.supabase.latestEmergency }

    var locations: [RiderLocation] { Array(app.supabase.locations.values) }

    // MARK: - Talk

    func talkPressDown() { ptt.pressDown() }
    func talkRelease() { ptt.release() }

    var isTransmitting: Bool { app.voice.isTransmitting }

    // MARK: - Host moderation

    func toggleMute(_ member: RoomMember) async {
        guard isHost else { return }
        do {
            try await app.supabase.setMuted(roomId: room.id,
                                            userId: member.userId,
                                            muted: !member.isMuted)
        } catch { app.report(error) }
    }

    func remove(_ member: RoomMember) async {
        guard isHost, member.userId != meId else { return }
        do {
            try await app.supabase.removeMember(roomId: room.id, userId: member.userId)
        } catch { app.report(error) }
    }

    // MARK: - Music

    func shareMusic(link: String) async {
        guard isHost, let me = meId, let url = URL(string: link), url.scheme != nil else { return }
        let state = MusicState(
            roomId: room.id,
            trackURL: link,
            provider: .detect(from: link),
            title: nil,
            isPlaying: true,
            positionMs: 0,
            updatedBy: me,
            updatedAt: Date()
        )
        do { try await app.supabase.upsertMusicState(state) }
        catch { app.report(error) }
    }

    // MARK: - Emergency

    func triggerEmergency() async {
        guard let profile = app.profile else { return }
        let coord = app.location.currentCoordinate()
        let event = EmergencyEvent(
            userId: profile.id,
            displayName: profile.displayName,
            lat: coord?.latitude,
            lng: coord?.longitude,
            timestamp: Date()
        )
        await app.supabase.broadcastEmergency(event)
    }

    // MARK: - Leaving

    func leave() async { await app.leaveActiveRoom() }
    func endRide() async { await app.endActiveRoom() }

    /// Share sheet contents for inviting riders.
    var inviteItems: [Any] {
        var items: [Any] = ["Join my RideTalk: code \(room.code)"]
        if let web = room.inviteWebLink { items.append(web) }
        if let deep = room.inviteDeepLink { items.append(deep) }
        return items
    }
}
