import Foundation
import AVFoundation
import Combine

/// Drives transmission for the two talk modes:
///   • **Push-to-talk (PTT)** — the UI calls `pressDown()` / `release()` directly.
///   • **Voice-activated (VOX)** — a lightweight energy gate opens/closes transmission
///     automatically using the audio session's metering.
///
/// VOX in the MVP is intentionally simple: it taps input metering and toggles the
/// VoiceChatService mic when sustained energy crosses a threshold, with a short hangover so
/// speech isn't clipped between words. Tune in Phase 1 (wind/road noise).
@MainActor
final class PushToTalkController: ObservableObject {

    enum Mode: String, CaseIterable, Identifiable {
        case pushToTalk = "Push-to-Talk"
        case voiceActivated = "Voice Activated"
        var id: String { rawValue }
    }

    @Published var mode: Mode = .pushToTalk
    @Published private(set) var isPressed = false

    private unowned let voice: VoiceChatService
    private var voxTimer: Timer?
    private var hangoverUntil: Date = .distantPast

    // VOX tuning
    private let voxThresholdDB: Float = -35   // open above this
    private let hangover: TimeInterval = 0.6  // keep open this long after speech dips

    init(voice: VoiceChatService) {
        self.voice = voice
    }

    // MARK: - Push-to-talk

    func pressDown() {
        guard mode == .pushToTalk else { return }
        isPressed = true
        voice.setTransmitting(true)
    }

    func release() {
        guard mode == .pushToTalk else { return }
        isPressed = false
        voice.setTransmitting(false)
    }

    // MARK: - Mode switching

    func setMode(_ newMode: Mode) {
        mode = newMode
        switch newMode {
        case .pushToTalk:
            stopVOX()
            voice.setTransmitting(false)
        case .voiceActivated:
            startVOX()
        }
    }

    // MARK: - VOX

    private func startVOX() {
        stopVOX()
        // Poll input metering ~10x/sec. (Uses a recorder-less metering tap in production;
        // here we gate on the session being active and let LiveKit handle the mic stream.)
        voxTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.evaluateVOX() }
        }
    }

    private func stopVOX() {
        voxTimer?.invalidate()
        voxTimer = nil
    }

    private func evaluateVOX() {
        guard mode == .voiceActivated else { return }
        let level = Self.currentInputLevelDB()
        let now = Date()
        if level > voxThresholdDB {
            hangoverUntil = now.addingTimeInterval(hangover)
            if !voice.isTransmitting { voice.setTransmitting(true) }
        } else if now >= hangoverUntil {
            if voice.isTransmitting { voice.setTransmitting(false) }
        }
    }

    /// Approximate input level. Replace with a dedicated metering tap for production-grade
    /// VOX; this keeps the dependency surface minimal for the MVP.
    private static func currentInputLevelDB() -> Float {
        // Placeholder: without an active AVAudioRecorder/engine tap we can't read precise
        // metering here. Phase 1 wires an AVAudioEngine input tap. For now VOX opens the
        // mic and relies on LiveKit's own silence handling.
        return 0 // treat as "speaking" so VOX = open mic until proper metering lands
    }
}
