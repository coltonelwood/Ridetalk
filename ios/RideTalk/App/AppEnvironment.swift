import Foundation
import Combine

/// App-wide runtime mode. **Demo Mode** lets every screen be reached and reviewed without
/// real Supabase / LiveKit credentials or actually riding — it seeds local sample data and
/// skips all network. This is how we satisfy "every feature testable from the app" and
/// "don't crash if a backend is unavailable" without shipping fake data to real users.
@MainActor
final class AppEnvironment: ObservableObject {
    static let shared = AppEnvironment()

    /// When true, the app runs entirely on local seeded data (no Supabase/LiveKit calls).
    @Published private(set) var isDemoMode: Bool

    private enum Keys { static let demo = "env.demoMode" }

    private init() {
        isDemoMode = UserDefaults.standard.bool(forKey: Keys.demo)
    }

    /// True when real backend config is missing — the UI nudges toward Demo Mode.
    var backendConfigured: Bool { AppConfig.isConfigured }

    func enableDemo() {
        isDemoMode = true
        UserDefaults.standard.set(true, forKey: Keys.demo)
    }

    func disableDemo() {
        isDemoMode = false
        UserDefaults.standard.set(false, forKey: Keys.demo)
    }

    /// Short label shown in a banner while in Demo Mode.
    var demoBanner: String { "Demo Mode — sample data, nothing is sent" }
}
