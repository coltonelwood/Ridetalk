import Foundation

/// Centralised, typed access to build configuration injected via `Secrets.xcconfig`
/// (host values) and surfaced through Info.plist. We store hosts (no scheme) in the
/// xcconfig because `//` starts a comment there, then reassemble full URLs here.
enum AppConfig {

    /// Supabase project base URL, e.g. `https://your-project.supabase.co`.
    static let supabaseURL: URL = {
        let host = infoString("SupabaseURLHost")
        guard let url = URL(string: "https://\(host)") else {
            fatalError("Invalid SupabaseURLHost in Info.plist: '\(host)'. Did you create Secrets.xcconfig?")
        }
        return url
    }()

    /// Supabase anon/public key. Safe to ship; data is protected by RLS.
    static let supabaseAnonKey: String = infoString("SupabaseAnonKey")

    /// LiveKit WebSocket URL, e.g. `wss://your-project.livekit.cloud`.
    /// (The token edge function also returns a `url`; this is a fallback/default.)
    static let liveKitURL: String = {
        let host = infoString("LiveKitURLHost")
        return "wss://\(host)"
    }()

    /// Deep-link scheme used for invite links: `ridetalk://join/<code>`.
    static let deepLinkScheme = "ridetalk"

    /// HTTPS universal-link base for sharing (configure your domain + AASA for this to
    /// resolve outside the app). Falls back to a friendly web join page.
    static let webJoinBaseURL = "https://ridetalk.app/join"

    // MARK: - Helpers

    private static func infoString(_ key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty,
              !value.contains("your-") // guard against the example placeholder
        else {
            #if DEBUG
            print("⚠️ AppConfig: missing or placeholder value for Info.plist key '\(key)'. " +
                  "Copy Secrets.example.xcconfig → Secrets.xcconfig and fill it in.")
            #endif
            return Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
        }
        return value
    }
}
