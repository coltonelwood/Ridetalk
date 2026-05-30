import Foundation
import Combine
import CoreLocation
import CoreMotion

/// Possible crash / rider-down detection.
///
/// Heuristic (NOT guaranteed emergency detection):
///   1. **Impact** — accelerometer magnitude spikes past a g-threshold, OR
///   2. **Sudden stop** — speed was at riding pace then dropped to ~0, AND
///   3. **No movement** — the rider stays stopped for a confirmation window.
/// When (1 or 2) is followed by (3), we raise a *possible* rider-down event. The rider then
/// gets a countdown to cancel; if they don't, an SOS labeled "possible crash" is sent to the
/// ride group (never to emergency services).
///
/// Settings (enabled + sensitivity) persist locally in `UserDefaults`.
@MainActor
final class CrashDetectionService: ObservableObject {

    // MARK: - Settings (persisted)

    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Keys.enabled) }
    }
    @Published var sensitivity: CrashSensitivity {
        didSet { UserDefaults.standard.set(sensitivity.rawValue, forKey: Keys.sensitivity) }
    }

    /// Called when a possible rider-down is detected. The argument is a human-readable
    /// reason; `AppState` decides demo-vs-real and attaches the coordinate.
    var onTrigger: ((String) -> Void)?

    // MARK: - Internal state

    private let motion = CMMotionManager()
    private var confirmTimer: Timer?
    private var isRunning = false
    private var isArmed = true                 // false after a trigger until re-armed

    private var lastSpeed: Double = 0          // m/s
    private var noMovementSince: Date?
    /// An in-progress candidate: when it started + why.
    private var candidate: (since: Date, reason: String)?

    private enum Keys {
        static let enabled = "crash.enabled"
        static let sensitivity = "crash.sensitivity"
    }

    init() {
        // Default ON at medium sensitivity (App Store reviewers can disable; clearly labeled).
        if UserDefaults.standard.object(forKey: Keys.enabled) == nil {
            isEnabled = true
        } else {
            isEnabled = UserDefaults.standard.bool(forKey: Keys.enabled)
        }
        sensitivity = CrashSensitivity(
            rawValue: UserDefaults.standard.string(forKey: Keys.sensitivity) ?? ""
        ) ?? .medium
    }

    var isMotionAvailable: Bool { motion.isAccelerometerAvailable }

    // MARK: - Lifecycle (called when a ride starts/stops)

    func start() {
        guard isEnabled, !isRunning else { return }
        isRunning = true
        isArmed = true
        candidate = nil
        noMovementSince = nil

        // Accelerometer for impact spikes (device-only; no-op in the simulator).
        if motion.isAccelerometerAvailable {
            motion.accelerometerUpdateInterval = 1.0 / 20.0   // 20 Hz
            motion.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
                guard let self, let a = data?.acceleration else { return }
                // Pure math off-actor; only hop to the main actor on a meaningful spike to
                // avoid 20 Tasks/sec (and to stay iOS 16 compatible — no assumeIsolated).
                let g = (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot()  // ≈1 at rest
                guard g >= 1.8 else { return }
                Task { @MainActor [weak self] in self?.handleImpact(g: g) }
            }
        }

        // 1 Hz confirmation tick (speed may stop updating once the rider is stationary).
        confirmTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.evaluate() }
        }
    }

    func stop() {
        isRunning = false
        motion.stopAccelerometerUpdates()
        confirmTimer?.invalidate(); confirmTimer = nil
        candidate = nil; noMovementSince = nil
    }

    /// Re-arm after the rider resolves a countdown (cancel or send), so detection can fire again.
    func rearm() {
        isArmed = true
        candidate = nil
        noMovementSince = nil
    }

    // MARK: - Inputs

    /// Speed feed from `LocationService`.
    func ingest(_ location: CLLocation) {
        guard isRunning else { return }
        let speed = max(0, location.speed)   // m/s

        // No-movement tracking.
        if speed < 1.0 {
            if noMovementSince == nil { noMovementSince = Date() }
        } else {
            noMovementSince = nil
            // Rider clearly moving again → any candidate was a false alarm.
            if speed > sensitivity.ridingSpeedMps { candidate = nil }
        }

        // Sudden stop: was at riding pace, now ~stopped.
        if lastSpeed >= sensitivity.ridingSpeedMps, speed < 1.0, candidate == nil, isArmed {
            candidate = (since: Date(), reason: "Sudden stop detected")
        }
        lastSpeed = speed
        evaluate()
    }

    private func handleImpact(g: Double) {
        guard isRunning, isArmed else { return }
        if g >= sensitivity.impactG {
            candidate = (since: Date(), reason: "Possible impact detected")
            evaluate()
        }
    }

    // MARK: - Decision

    private func evaluate() {
        guard isRunning, isArmed, let candidate else { return }
        // Require sustained no-movement since the candidate began.
        guard let stoppedAt = noMovementSince else { return }
        let stoppedLongEnough = Date().timeIntervalSince(stoppedAt) >= sensitivity.confirmWindow
        let candidateMatured = Date().timeIntervalSince(candidate.since) >= sensitivity.confirmWindow
        if stoppedLongEnough && candidateMatured {
            isArmed = false                 // don't double-fire; AppState re-arms after resolve
            self.candidate = nil
            onTrigger?("\(candidate.reason) + no movement for \(Int(sensitivity.confirmWindow))s")
        }
    }

    // MARK: - Test / demo

    /// Fire the rider-down flow immediately (used by the settings "Simulate" button and the
    /// in-ride debug trigger) so it can be tested without actually crashing.
    func simulate() {
        isArmed = false
        candidate = nil
        onTrigger?("Simulated rider-down (test)")
    }
}
