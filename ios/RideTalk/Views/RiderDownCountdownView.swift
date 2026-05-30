import SwiftUI
import AudioToolbox
import UIKit

/// Repeating loud alert + haptics for the rider-down countdown.
///
/// MVP uses repeated system alert sounds + strong haptics (no bundled asset). For
/// production, bundle a custom looping alarm and consider the **Critical Alerts**
/// entitlement so it can sound through silent mode / a locked device.
@MainActor
final class CrashAlarm: ObservableObject {
    private var timer: Timer?
    private let haptic = UINotificationFeedbackGenerator()

    func start() {
        stop()
        haptic.prepare()
        fire()
        timer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.fire() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func fire() {
        AudioServicesPlayAlertSound(SystemSoundID(1005)) // loud "alarm"-style alert
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        haptic.notificationOccurred(.error)
    }
}

/// "Are you okay?" countdown shown when a possible crash / rider-down is detected.
/// 30s to cancel; otherwise an SOS labeled "possible crash" is sent to the ride group.
struct RiderDownCountdownView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var alarm = CrashAlarm()

    let event: RiderDownEvent
    private let total = 30

    @State private var remaining = 30
    @State private var ringProgress: Double = 1.0
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.rideDanger.ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer().frame(height: 12)

                Label("POSSIBLE CRASH DETECTED", systemImage: "figure.fall")
                    .font(.headline.bold())
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.black.opacity(0.25), in: Capsule())

                if event.isDemo {
                    Text("DEMO — no SOS will be sent")
                        .font(.caption.bold())
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(.black.opacity(0.3), in: Capsule())
                }

                Text("Are you OK?")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))

                Text(event.reason)
                    .font(.subheadline).opacity(0.9)
                    .multilineTextAlignment(.center)

                // Countdown ring
                ZStack {
                    Circle().stroke(.white.opacity(0.25), lineWidth: 14)
                    Circle()
                        .trim(from: 0, to: ringProgress)
                        .stroke(.white, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(remaining)").font(.system(size: 72, weight: .black, design: .rounded))
                        Text("seconds").font(.subheadline).opacity(0.9)
                    }
                }
                .frame(width: 220, height: 220)
                .padding(.vertical, 8)

                Spacer()

                // Primary: cancel (huge, easy to hit)
                Button {
                    appState.cancelRiderDown()
                } label: {
                    Text("I'M OK — CANCEL")
                        .font(.title.bold())
                        .frame(maxWidth: .infinity).padding(.vertical, 24)
                        .background(.white, in: RoundedRectangle(cornerRadius: 20))
                        .foregroundStyle(Color.rideDanger)
                }

                // Secondary: send immediately
                Button {
                    Task { await appState.confirmRiderDown() }
                } label: {
                    Text(event.isDemo ? "End demo (would send SOS)" : "Send SOS now")
                        .font(.headline)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.7)))
                }

                Text("Possible crash detection is a best-effort heuristic — not guaranteed. An SOS alerts your ride group, not emergency services. Call them directly in a real emergency.")
                    .font(.caption2).opacity(0.85)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 12)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
        }
        .onAppear {
            remaining = total
            alarm.start()
            withAnimation(.linear(duration: Double(total))) { ringProgress = 0 }
        }
        .onDisappear { alarm.stop() }
        .onReceive(tick) { _ in
            guard remaining > 0 else { return }
            remaining -= 1
            if remaining == 0 {
                alarm.stop()
                Task { await appState.confirmRiderDown() }
            }
        }
    }
}
