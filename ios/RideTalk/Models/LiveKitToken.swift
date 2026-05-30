import Foundation

/// Response from the `livekit-token` Supabase edge function.
struct LiveKitToken: Decodable {
    let token: String
    let url: String
    let identity: String
}
