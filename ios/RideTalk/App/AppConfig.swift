import Foundation

/// Centralised, typed access to build configuration injected via `Secrets.xcconfig`
/// (host values) and surfaced through Info.plist. We store hosts (no scheme) in the
/// xcconfig because `//` starts a comment there, then reassemble full URLs here.
///
/// IMPORTANT (stability): nothing here ever `fatalError`s. A fresh checkout without a
/// `Secrets.xcconfig` (or one left with the example placeholders) must still launch — the
/// app shows a "Setup required" screen and offers Demo Mode instead of crashing.
enum AppConfig {

    /// True when real Supabase + LiveKit values are present (not blank, not the placeholder).
    static var isConfigured: Bool {
        !rawSupabaseHost.isEmpty && !rawSupabaseAnonKey.isEmpty && !rawLiveKitHost.isEmpty
    }

    /// Supabase project base URL. Returns a syntactically-valid placeholder when unconfigured
    /// so the SDK can be constructed without crashing (network calls simply fail/are skipped).
    static var supabaseURL: URL {
        let host = rawSupabaseHost.isEmpty ? "unconfigured.invalid" : rawSupabaseHost
        return URL(string: "https://\(host)") ?? URL(string: "https://unconfigured.invalid")!
    }

    /// Supabase anon/public key. Safe to ship; data is protected by RLS.
    static var supabaseAnonKey: String {
        rawSupabaseAnonKey.isEmpty ? "unconfigured" : rawSupabaseAnonKey
    }

    /// LiveKit WebSocket URL, e.g. `wss://your-project.livekit.cloud`.
    /// (The token edge function also returns a `url`; this is a fallback/default.)
    static var liveKitURL: String {
        let host = rawLiveKitHost.isEmpty ? "unconfigured.invalid" : rawLiveKitHost
        return "wss://\(host)"
    }

    /// Deep-link scheme used for invite links: `ridetalk://join/<code>`.
    static let deepLinkScheme = "ridetalk"

    /// HTTPS universal-link base for sharing (configure your domain + AASA for this to
    /// resolve outside the app). Falls back to a friendly web join page.
    static let webJoinBaseURL = "https://ridetalk.app/join"

    // MARK: - Raw Info.plist reads (placeholder-aware)

    private static var rawSupabaseHost: String { infoString("SupabaseURLHost") }
    private static var rawSupabaseAnonKey: String { infoString("SupabaseAnonKey") }
    private static var rawLiveKitHost: String { infoString("LiveKitURLHost") }

    /// Returns the Info.plist string for `key`, or "" if missing/blank/placeholder.
    private static func infoString(_ key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty,
              !value.contains("your-")   // the example placeholder, e.g. "your-project.supabase.co"
        else {
            return ""
        }
        return value
    }
}
