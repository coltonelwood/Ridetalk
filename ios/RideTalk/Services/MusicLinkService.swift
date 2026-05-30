import Foundation
import Combine
import Supabase

/// Shares track *links* (Spotify / Apple Music / YouTube Music) into a room. Compliant:
/// each rider plays their own copy; no audio is captured or rebroadcast. Future music-sync
/// controls (play/pause/timestamp) are scaffolded via placeholder fields on the row.
@MainActor
final class MusicLinkService: ObservableObject {

    private var client: SupabaseClient { SupabaseManager.shared.client }

    /// Share a link with the room. Title is best-effort (host can leave blank).
    func share(roomId: UUID, userId: UUID, url: String, title: String?) async throws {
        let insert = SharedMusicInsert(
            roomId: roomId, userId: userId, url: url,
            provider: .detect(from: url),
            title: title?.isEmpty == true ? nil : title
        )
        _ = try await client.from("shared_music_links").insert(insert).execute()
    }

    func history(roomId: UUID, limit: Int = 20) async throws -> [SharedMusicLink] {
        try await client.from("shared_music_links").select()
            .eq("room_id", value: roomId.uuidString)
            .order("created_at", ascending: false).limit(limit)
            .execute().value
    }

    // PLACEHOLDER — future full music sync:
    // func setPlayback(linkId: UUID, isPlaying: Bool, positionMs: Int) async throws { … }
    // Would require MusicKit (Apple Music) / Spotify App Remote for true synced playback.
}
