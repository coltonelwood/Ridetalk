import Foundation
import Combine
import Supabase

/// Shares track *links* (Spotify / Apple Music / YouTube Music) into a room and lets the
/// HOST control the shared playback state (play/pause/position). Compliant: each rider plays
/// their own copy in their own app/account; no audio is captured or rebroadcast. Local
/// playback that follows this state lives in `MusicSyncService`.
@MainActor
final class MusicLinkService: ObservableObject {

    private var client: SupabaseClient { SupabaseManager.shared.client }

    /// Share a link with the room (starts paused at 0). Title is best-effort.
    @discardableResult
    func share(roomId: UUID, userId: UUID, url: String, title: String?) async throws -> SharedMusicLink {
        let insert = SharedMusicInsert(
            roomId: roomId, userId: userId, url: url,
            provider: .detect(from: url),
            title: title?.isEmpty == true ? nil : title
        )
        return try await client.from("shared_music_links").insert(insert).select().single().execute().value
    }

    func history(roomId: UUID, limit: Int = 20) async throws -> [SharedMusicLink] {
        try await client.from("shared_music_links").select()
            .eq("room_id", value: roomId.uuidString)
            .order("created_at", ascending: false).limit(limit)
            .execute().value
    }

    // MARK: - Host playback control (writes shared state; followers project from it)

    /// Update is_playing / position_ms / updated_at on the shared track. Host-only (enforced
    /// by RLS policy "host updates music"). `updated_at` is the anchor followers use to
    /// project the live position.
    func setPlayback(linkId: UUID, isPlaying: Bool, positionMs: Int) async throws {
        struct Update: Encodable {
            let is_playing: Bool
            let position_ms: Int
            let updated_at: String
        }
        let body = Update(
            is_playing: isPlaying,
            position_ms: max(0, positionMs),
            updated_at: ISO8601DateFormatter().string(from: Date())
        )
        _ = try await client.from("shared_music_links")
            .update(body)
            .eq("id", value: linkId.uuidString)
            .execute()
    }
}
