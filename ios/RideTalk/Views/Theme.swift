import SwiftUI

/// Centralised colors so the riding UI stays high-contrast and consistent.
extension Color {
    /// Primary action / brand accent (electric green — reads well in sunlight).
    static let rideAccent = Color(red: 0.18, green: 0.95, blue: 0.55)
    /// App background (near-black for glanceability + battery on OLED).
    static let rideBackground = Color(red: 0.04, green: 0.05, blue: 0.07)
    /// Card / surface.
    static let rideSurface = Color(red: 0.10, green: 0.12, blue: 0.15)
    /// Danger / emergency.
    static let rideDanger = Color(red: 0.98, green: 0.23, blue: 0.30)
    /// Live-talk highlight.
    static let rideTalk = Color(red: 0.20, green: 0.80, blue: 1.0)
}

/// A big, glanceable card surface used across the riding UI.
struct RideCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.rideSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
