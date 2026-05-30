import Foundation
import AuthenticationServices
import CryptoKit
import Supabase

/// Sign in with Apple → Supabase. We use the native `ASAuthorizationController` to get an
/// Apple **identity token** and exchange it with Supabase via `signInWithIdToken`.
@MainActor
final class AuthService: NSObject, ObservableObject {

    struct SessionInfo { let userId: UUID }

    private let supabase: SupabaseService
    private var currentNonce: String?
    private var continuation: CheckedContinuation<SessionInfo, Error>?

    init(supabase: SupabaseService) {
        self.supabase = supabase
    }

    /// Restore a persisted session (Supabase stores it in the keychain).
    func restoreSession() async throws -> SessionInfo? {
        guard let session = try? await supabase.client.auth.session else { return nil }
        return SessionInfo(userId: session.user.id)
    }

    func signOut() async throws {
        try await supabase.client.auth.signOut()
    }

    // MARK: - Sign in with Apple

    /// Configure an `ASAuthorizationAppleIDRequest` (called from `SignInWithAppleButton`).
    func configureRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    /// Handle the controller result, exchange with Supabase, return the session.
    func handleAuthorization(_ authorization: ASAuthorization) async throws -> SessionInfo {
        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = credential.identityToken,
            let idToken = String(data: tokenData, encoding: .utf8),
            let nonce = currentNonce
        else {
            throw AuthError.invalidCredential
        }

        let session = try await supabase.client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )

        // First-time sign-in: Apple gives us the name once. Persist it to the profile.
        if let fullName = credential.fullName,
           let given = fullName.givenName {
            let display = [given, fullName.familyName].compactMap { $0 }.joined(separator: " ")
            _ = try? await supabase.updateProfile(
                userId: session.user.id,
                ProfileUpdate(displayName: display, avatarURL: nil, scooterType: nil)
            )
        }

        return SessionInfo(userId: session.user.id)
    }

    enum AuthError: LocalizedError {
        case invalidCredential
        var errorDescription: String? {
            switch self {
            case .invalidCredential: return "Couldn't read your Apple credential. Please try again."
            }
        }
    }

    // MARK: - Nonce helpers (per Apple's recommended pattern)

    private static func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if status == errSecSuccess {
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}
