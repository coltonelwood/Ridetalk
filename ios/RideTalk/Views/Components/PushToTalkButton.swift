import SwiftUI

/// The big push-to-talk control. Hold to transmit; release to stop. Designed to be tappable
/// without looking — it fills most of the screen and gives strong haptic + color feedback.
struct PushToTalkButton: View {
    let isTransmitting: Bool
    let someoneElseTalking: Bool
    let mode: PushToTalkController.Mode
    let onPressDown: () -> Void
    let onRelease: () -> Void

    @State private var isDown = false

    var body: some View {
        ZStack {
            Circle()
                .fill(fillColor)
                .shadow(color: fillColor.opacity(0.6), radius: isTransmitting ? 30 : 8)
                .overlay(
                    Circle().stroke(.white.opacity(0.15), lineWidth: 2)
                )
                .scaleEffect(isDown ? 0.97 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isDown)

            VStack(spacing: 10) {
                Image(systemName: iconName)
                    .font(.system(size: 72, weight: .bold))
                Text(label)
                    .font(.title2.bold())
            }
            .foregroundStyle(.black)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .contentShape(Circle())
        .gesture(
            mode == .pushToTalk
            ? DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isDown else { return }
                    isDown = true
                    Haptics.impact(.heavy)
                    onPressDown()
                }
                .onEnded { _ in
                    isDown = false
                    Haptics.impact(.light)
                    onRelease()
                }
            : nil
        )
        .accessibilityLabel(mode == .pushToTalk ? "Push to talk. Hold to speak." : "Voice activated mode")
        .accessibilityAddTraits(.isButton)
    }

    private var fillColor: Color {
        if isTransmitting { return .rideAccent }
        if someoneElseTalking { return .rideTalk }
        return .rideSurface
    }

    private var iconName: String {
        if isTransmitting { return "mic.fill" }
        if someoneElseTalking { return "speaker.wave.3.fill" }
        return mode == .pushToTalk ? "mic" : "waveform"
    }

    private var label: String {
        if isTransmitting { return "Talking…" }
        if someoneElseTalking { return "Listening" }
        return mode == .pushToTalk ? "Hold to Talk" : "Hands-free"
    }
}

/// Tiny haptics helper.
enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.impactOccurred()
    }
}
