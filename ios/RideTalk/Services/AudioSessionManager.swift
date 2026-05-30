import Foundation
import AVFoundation
import Combine

/// Owns the single shared `AVAudioSession`. This is what makes RideTalk work with AirPods,
/// keep talking while the screen is locked, and duck the rider's own music under voice.
///
/// Key decisions (see docs/ARCHITECTURE.md):
///   • Category `.playAndRecord` + mode `.voiceChat` → two-way voice with echo cancel.
///   • `.allowBluetooth` / `.allowBluetoothA2DP` → AirPods mic + output.
///   • `.duckOthers` → the music app is lowered while voice is active.
///   • `UIBackgroundModes: audio` (Info.plist) → session survives lock/background.
@MainActor
final class AudioSessionManager: ObservableObject {

    static let shared = AudioSessionManager()

    /// Human-readable current output route (e.g. "AirPods Pro", "iPhone Speaker").
    @Published private(set) var currentRouteName: String = "—"
    /// True when audio is routed to a Bluetooth device (AirPods etc.).
    @Published private(set) var isUsingBluetooth = false
    @Published private(set) var isActive = false

    private let session = AVAudioSession.sharedInstance()
    private var observers: [NSObjectProtocol] = []

    private init() {
        registerNotifications()
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    // MARK: - Activation

    /// Configure + activate the session for group voice. Call before connecting to LiveKit.
    func activateForVoice() throws {
        try session.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [.allowBluetooth, .allowBluetoothA2DP, .duckOthers, .defaultToSpeaker]
        )
        // Low-latency-ish buffer; the OS may clamp this.
        try? session.setPreferredIOBufferDuration(0.01)
        try session.setActive(true, options: [])
        isActive = true
        updateRoute()
    }

    /// Release the session (lets other apps regain full volume).
    func deactivate() {
        try? session.setActive(false, options: [.notifyOthersOnDeactivation])
        isActive = false
    }

    /// Force speaker vs. let the route follow the connected device (AirPods).
    func overrideToSpeaker(_ speaker: Bool) {
        try? session.overrideOutputAudioPort(speaker ? .speaker : .none)
        updateRoute()
    }

    // MARK: - Notifications (route changes + interruptions)

    private func registerNotifications() {
        let nc = NotificationCenter.default

        observers.append(nc.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: session, queue: .main
        ) { [weak self] note in
            Task { @MainActor in self?.handleRouteChange(note) }
        })

        observers.append(nc.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session, queue: .main
        ) { [weak self] note in
            Task { @MainActor in self?.handleInterruption(note) }
        })

        observers.append(nc.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: session, queue: .main
        ) { [weak self] _ in
            // Audio server crashed — rebuild the session if we were active.
            Task { @MainActor in
                guard let self, self.isActive else { return }
                try? self.activateForVoice()
            }
        })
    }

    private func handleRouteChange(_ note: Notification) {
        updateRoute()
        // When AirPods are removed (.oldDeviceUnavailable) we keep the session alive but
        // the route falls back to speaker — VoiceService doesn't need to do anything.
    }

    private func handleInterruption(_ note: Notification) {
        guard
            let info = note.userInfo,
            let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: raw)
        else { return }

        switch type {
        case .began:
            // A phone call etc. started. The OS has paused our audio; nothing to do.
            isActive = false
        case .ended:
            // Reactivate if the system says we should resume.
            if let optsRaw = info[AVAudioSessionInterruptionOptionKey] as? UInt,
               AVAudioSession.InterruptionOptions(rawValue: optsRaw).contains(.shouldResume) {
                try? activateForVoice()
            }
        @unknown default:
            break
        }
    }

    private func updateRoute() {
        guard let output = session.currentRoute.outputs.first else {
            currentRouteName = "—"
            isUsingBluetooth = false
            return
        }
        currentRouteName = output.portName
        isUsingBluetooth = [
            .bluetoothA2DP, .bluetoothHFP, .bluetoothLE
        ].contains(output.portType)
    }
}
