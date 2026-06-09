import Foundation
import SwiftUI
import Combine
import CoreLocation

/// View model for the Active Ride screen. Aggregates the live state from the long-lived
/// services and exposes ride actions (talk, mute, SOS, music, quick messages, host
/// controls, lead-rider mode, separation alerts).
@MainActor
final class ActiveRideViewModel: ObservableObject {

    private unowned let app: AppState
    private var cancellables: Set<AnyCancellable> = []

    let ptt: PushToTalkController

    // Local self-mute (distinct from host mute)
    @Published var isSelfMuted = false
    // Sheets
    @Published var showMusic = false
    @Published var showMap = false
    @Published var showRoster = false
    @Published var showSOSConfirm = false
    @Published var showLeaveConfirm = false
    @Published var showQuickMessages = false
    // Quick-message + separation toasts
    @Published var toast: String?

    init(app: AppState) {
        self.app = app
        self.ptt = PushToTalkController(voice: app.voice)
        for obj: ObservableObjectPublisher in [
            app.voice.objectWillChange, app.supabase.objectWillChange,
            app.location.objectWillChange, app.audio.objectWillChange,
            app.recording.objectWillChange, app.musicSync.objectWillChange,
            ptt.objectWillChange
        ] {
            obj.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        }
        observeEvents()
    }

    // MARK: - Identity / room

    var meId: UUID? { app.profile?.id }
    /// Live room row (host may change lead rider / threshold mid-ride).
    var room: RideRoom { app.supabase.room ?? app.activeRoom ?? fallbackRoom }
    var isHost: Bool { room.hostId == meId }

    var members: [RoomMember] { app.supabase.roster.filter { $0.isActive } }
    var memberCount: Int { members.count }

    var leadRider: RoomMember? { members.first { $0.userId == room.leadRiderId } }
    func isLead(_ m: RoomMember) -> Bool { m.userId == room.leadRiderId }

    // MARK: - Voice

    var connectionState: VoiceChatService.State { app.voice.state }
    var isReconnecting: Bool { connectionState == .reconnecting || connectionState == .connecting }
    var someoneElseTalking: Bool { app.voice.remoteIsSpeaking }
    var isTransmitting: Bool { app.voice.isTransmitting }
    func isSpeaking(_ m: RoomMember) -> Bool { app.voice.speakingIdentities.contains(m.userId.uuidString) }

    func talkPressDown() { guard !isSelfMuted else { return }; ptt.pressDown() }
    func talkRelease() { ptt.release() }
    func toggleSelfMute() {
        isSelfMuted.toggle()
        app.voice.setSelfMuted(isSelfMuted)
        if isSelfMuted { ptt.release() }
    }

    // MARK: - Riding status

    var speedMph: Int { Int(app.location.speedMph.rounded()) }
    var batteryLevel: Float { app.location.batteryLevel }
    var routeName: String { app.audio.currentRouteName }
    var usingBluetooth: Bool { app.audio.isUsingBluetooth }
    var lowBattery: Bool { app.location.batteryLevel >= 0 && app.location.batteryLevel < 0.2 }
    var stoppedUnexpectedly: Bool { app.location.isStoppedUnexpectedly }

    // Live recording readouts
    var isRecordingRide: Bool { app.recording.isRecording }
    var recDistanceMiles: Double { app.recording.liveDistanceMiles }
    var recDurationS: TimeInterval { app.recording.liveDurationS }
    var recSummary: String {
        let s = Int(recDurationS)
        let dur = s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
                            : String(format: "%d:%02d", s / 60, s % 60)
        return String(format: "%.1f mi · %@", recDistanceMiles, dur)
    }

    // MARK: - Map / locations

    var locations: [LiveLocation] { Array(app.supabase.locations.values) }
    func location(of userId: UUID) -> LiveLocation? { app.supabase.locations[userId] }

    // MARK: - Separation alerts (distance behind the lead rider)

    struct Separation: Identifiable {
        let id: UUID
        let name: String
        let miles: Double
        let coordinate: CLLocationCoordinate2D
    }

    /// Riders farther than the room threshold from the lead rider.
    var separatedRiders: [Separation] {
        guard let lead = room.leadRiderId, let leadLoc = location(of: lead) else { return [] }
        let threshold = room.separationThresholdMiles
        return members.compactMap { m -> Separation? in
            guard m.userId != lead, let loc = location(of: m.userId) else { return nil }
            let miles = loc.coordinate.milesTo(leadLoc.coordinate)
            guard miles >= threshold else { return nil }
            return Separation(id: m.userId, name: m.displayName, miles: miles, coordinate: loc.coordinate)
        }
        .sorted { $0.miles > $1.miles }
    }

    // MARK: - Music (compliant sync — see MusicSyncService / docs/MUSIC_SYNC.md)

    var music: SharedMusicLink? { app.supabase.music }

    /// Host shares a link (starts paused at 0).
    func shareMusic(url: String, title: String?) async {
        guard let me = meId, URL(string: url)?.scheme != nil else { return }
        if isDemo {
            app.supabase.music = SharedMusicLink(
                id: UUID(), roomId: room.id, userId: me, url: url,
                provider: .detect(from: url),
                title: (title?.isEmpty == false) ? title : nil,
                isPlaying: false, positionMs: 0, createdAt: Date(), updatedAt: Date())
            return
        }
        do { try await app.music.share(roomId: room.id, userId: me, url: url, title: title) }
        catch { app.report(error) }
    }

    // Host playback controls (write shared state; followers project from it).
    var canControlMusic: Bool { isHost && (music?.provider.supportsSyncedPlayback ?? false) }

    /// Demo-aware local mutation of the shared music state.
    private func demoSetPlayback(isPlaying: Bool, positionMs: Int) {
        guard var m = app.supabase.music else { return }
        m.isPlaying = isPlaying; m.positionMs = positionMs; m.updatedAt = Date()
        app.supabase.music = m
    }

    func hostPlay() async {
        guard isHost, let m = music else { return }
        if isDemo { demoSetPlayback(isPlaying: true, positionMs: m.projectedPositionMs); return }
        do { try await app.music.setPlayback(linkId: m.id, isPlaying: true, positionMs: m.projectedPositionMs) }
        catch { app.report(error) }
    }
    func hostPause() async {
        guard isHost, let m = music else { return }
        if isDemo { demoSetPlayback(isPlaying: false, positionMs: m.projectedPositionMs); return }
        do { try await app.music.setPlayback(linkId: m.id, isPlaying: false, positionMs: m.projectedPositionMs) }
        catch { app.report(error) }
    }
    func hostRestart() async {
        guard isHost, let m = music else { return }
        if isDemo { demoSetPlayback(isPlaying: true, positionMs: 0); return }
        do { try await app.music.setPlayback(linkId: m.id, isPlaying: true, positionMs: 0) }
        catch { app.report(error) }
    }

    // Rider sync (opt-in following of the host).
    var syncStatus: MusicSyncStatus { app.musicSync.status }
    var isSyncEnabled: Bool { app.musicSync.isSyncEnabled }
    func toggleMusicSync() async {
        if app.musicSync.isSyncEnabled { app.musicSync.disableSync() }
        else { await app.musicSync.enableSync() }
    }
    func resyncMusic() async { await app.musicSync.resyncNow() }

    // MARK: - SOS

    var activeSOS: [SOSAlert] { app.supabase.activeSOS }
    var myActiveSOS: SOSAlert? { activeSOS.first { $0.userId == meId } }

    /// Priority full-screen alert when another rider raises an SOS.
    @Published var presentedSOS: SOSAlert?
    private var acknowledgedSOS: Set<UUID> = []
    func dismissSOSScreen(_ alert: SOSAlert) { acknowledgedSOS.insert(alert.id); presentedSOS = nil }

    var isDemo: Bool { app.isDemo }

    func raiseSOS() async {
        guard let me = meId else { return }
        if isDemo { app.supabase.addDemoSOS(kind: .manual); return }
        do { try await app.sos.raise(roomId: room.id, userId: me, coordinate: app.location.currentCoordinate()) }
        catch { app.report(error) }
    }
    func resolveSOS(_ alert: SOSAlert) async {
        if isDemo { app.supabase.resolveDemoSOS(alert.id); return }
        do { try await app.sos.resolve(alertId: alert.id) } catch { app.report(error) }
    }
    func name(forUserId id: UUID) -> String { members.first { $0.userId == id }?.displayName ?? "Rider" }

    // MARK: - Quick messages

    var quickMessages: [QuickMessage] { app.supabase.quickMessages }
    func sendQuick(_ kind: QuickMessageKind) async {
        guard let me = meId else { return }
        if isDemo {
            let msg = QuickMessage(id: UUID(), roomId: room.id, userId: me, kind: kind,
                                   text: kind.label, isPriority: kind.isPriority, createdAt: Date())
            app.supabase.quickMessages = [msg] + app.supabase.quickMessages
            return
        }
        let insert = QuickMessageInsert(roomId: room.id, userId: me, kind: kind,
                                        text: kind.label, isPriority: kind.isPriority)
        do { _ = try await app.supabase.client.from("quick_messages").insert(insert).execute() }
        catch { app.report(error) }
    }

    // MARK: - Host controls

    func toggleMute(_ m: RoomMember) async {
        guard isHost else { return }
        if isDemo {
            if let i = app.supabase.roster.firstIndex(where: { $0.userId == m.userId }) {
                app.supabase.roster[i].isMuted.toggle()
            }
            return
        }
        do { try await app.rooms.setMuted(roomId: room.id, userId: m.userId, muted: !m.isMuted) }
        catch { app.report(error) }
    }
    func remove(_ m: RoomMember) async {
        guard isHost, m.userId != meId else { return }
        if isDemo { app.supabase.roster.removeAll { $0.userId == m.userId }; return }
        do { try await app.rooms.remove(roomId: room.id, userId: m.userId) } catch { app.report(error) }
    }
    func makeLead(_ m: RoomMember) async {
        guard isHost else { return }
        if isDemo { app.supabase.room?.leadRiderId = m.userId; return }
        do { try await app.rooms.setLeadRider(roomId: room.id, userId: m.userId) } catch { app.report(error) }
    }
    func setThreshold(_ miles: Double) async {
        guard isHost else { return }
        if isDemo { app.supabase.room?.separationThresholdMiles = miles; return }
        do { try await app.rooms.setSeparationThreshold(roomId: room.id, miles: miles) } catch { app.report(error) }
    }

    // MARK: - Leave / end

    func leave() async { await app.leaveActiveRoom() }
    func endRide() async { await app.endActiveRoom() }

    var inviteItems: [Any] {
        var items: [Any] = ["Join my RideTalk: code \(room.code)"]
        if let web = room.inviteWebLink { items.append(web) }
        if let deep = room.inviteDeepLink { items.append(deep) }
        return items
    }

    // MARK: - Events → transient toasts

    private func observeEvents() {
        // New incoming quick message → toast.
        app.supabase.$quickMessages
            .receive(on: RunLoop.main)
            .sink { [weak self] msgs in
                guard let self, let latest = msgs.first, latest.userId != self.meId else { return }
                self.flash("\(self.name(forUserId: latest.userId)): \(latest.text)")
            }
            .store(in: &cancellables)

        // New SOS from another rider → priority full-screen alert.
        app.supabase.$activeSOS
            .receive(on: RunLoop.main)
            .sink { [weak self] alerts in
                guard let self else { return }
                if let incoming = alerts.first(where: {
                    $0.userId != self.meId && !self.acknowledgedSOS.contains($0.id)
                }) {
                    self.presentedSOS = incoming
                    Haptics.impact(.heavy)
                } else if let presented = self.presentedSOS,
                          !alerts.contains(where: { $0.id == presented.id }) {
                    // Alert was resolved elsewhere.
                    self.presentedSOS = nil
                }
            }
            .store(in: &cancellables)
    }

    private func flash(_ text: String) {
        toast = text
        Task { try? await Task.sleep(nanoseconds: 3_500_000_000); if toast == text { toast = nil } }
    }

    private var fallbackRoom: RideRoom {
        RideRoom(id: UUID(), code: "------", name: "Ride", hostId: UUID(), leadRiderId: nil,
                 status: .active, separationThresholdMiles: 1, createdAt: Date(), endedAt: nil)
    }
}
