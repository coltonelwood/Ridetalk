import Foundation
import Combine
import AuthenticationServices
import CryptoKit
import Supabase

/// Sign in with Apple → Supabase, plus rider-profile read/update.
@MainActor
final class AuthService: NSObject, ObservableObject {

    struct SessionInfo { let userId: UUID }

    private var client: SupabaseClient { SupabaseManager.shared.client }
    private var currentNonce: String?

    // MARK: - Session

    func restoreSession() async throws -> SessionInfo? {
        guard let session = try? await client.auth.session else { return nil }
        return SessionInfo(userId: session.user.id)
    }

    func signOut() async throws { try await client.auth.signOut() }

    // MARK: - Profiles (rider_profiles)

    func fetchProfile(userId: UUID) async throws -> RiderProfile {
        try await client.from("rider_profiles").select()
            .eq("user_id", value: userId.uuidString)
            .single().execute().value
    }

    @discardableResult
    func updateProfile(userId: UUID, _ update: ProfileUpdate) async throws -> RiderProfile {
        try await client.from("rider_profiles").update(update)
            .eq("user_id", value: userId.uuidString)
            .select().single().execute().value
    }

    // MARK: - Sign in with Apple

    func configureRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    func handleAuthorization(_ authorization: ASAuthorization) async throws -> SessionInfo {
        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = credential.identityToken,
            let idToken = String(data: tokenData, encoding: .utf8),
            let nonce = currentNonce
        else { throw AuthError.invalidCredential }

        let session = try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )

        // Apple returns the name only on first authorization — persist it.
        if let fullName = credential.fullName, let given = fullName.givenName {
            let display = [given, fullName.familyName].compactMap { $0 }.joined(separator: " ")
            _ = try? await updateProfile(userId: session.user.id,
                                         ProfileUpdate(displayName: display))
        }
        return SessionInfo(userId: session.user.id)
    }

    enum AuthError: LocalizedError {
        case invalidCredential
        var errorDescription: String? {
            switch self { case .invalidCredential: return "Couldn't read your Apple credential. Please try again." }
        }
    }

    // MARK: - Nonce helpers

    private static func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""; var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            if SecRandomCopyBytes(kSecRandomDefault, 1, &random) == errSecSuccess, random < charset.count {
                result.append(charset[Int(random)]); remaining -= 1
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
