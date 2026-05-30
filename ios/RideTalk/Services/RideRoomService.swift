import Foundation
import Combine
import Supabase

/// Room lifecycle + host controls: create/join/leave/end, roster, mute/remove, lead rider,
/// separation threshold, and saved groups.
@MainActor
final class RideRoomService: ObservableObject {

    private var client: SupabaseClient { SupabaseManager.shared.client }

    // Encodable RPC param structs (avoids hand-building JSON / version-specific AnyJSON cases).
    private struct CreateParams: Encodable { let p_name: String; let p_threshold: Double }
    private struct ThresholdParams: Encodable { let p_room_id: String; let p_miles: Double }

    // MARK: - Lifecycle (RPCs for atomic create/join)

    func create(name: String, thresholdMiles: Double) async throws -> RideRoom {
        try await client.rpc("create_room",
                             params: CreateParams(p_name: name, p_threshold: thresholdMiles))
            .single().execute().value
    }

    func join(code: String) async throws -> RideRoom {
        try await client.rpc("join_room", params: ["p_code": code]).single().execute().value
    }

    func leave(roomId: UUID) async throws {
        _ = try await client.rpc("leave_room", params: ["p_room_id": roomId.uuidString]).execute()
    }

    func end(roomId: UUID) async throws {
        _ = try await client.rpc("end_room", params: ["p_room_id": roomId.uuidString]).execute()
    }

    // MARK: - Host controls

    func setMuted(roomId: UUID, userId: UUID, muted: Bool) async throws {
        _ = try await client.from("room_members").update(["is_muted": muted])
            .eq("room_id", value: roomId.uuidString)
            .eq("user_id", value: userId.uuidString).execute()
    }

    func remove(roomId: UUID, userId: UUID) async throws {
        _ = try await client.from("room_members").delete()
            .eq("room_id", value: roomId.uuidString)
            .eq("user_id", value: userId.uuidString).execute()
    }

    func setLeadRider(roomId: UUID, userId: UUID) async throws {
        _ = try await client.rpc("set_lead_rider", params: [
            "p_room_id": roomId.uuidString, "p_user_id": userId.uuidString
        ]).execute()
    }

    func setSeparationThreshold(roomId: UUID, miles: Double) async throws {
        _ = try await client.rpc("set_separation_threshold",
                                 params: ThresholdParams(p_room_id: roomId.uuidString, p_miles: miles)).execute()
    }

    // MARK: - Saved groups (rooms the rider has been part of)

    func savedRooms(limit: Int = 20) async throws -> [RideRoom] {
        // Rooms the user is/was a member of, most recent first.
        struct Row: Decodable { let ride_rooms: RideRoom }
        let rows: [Row] = try await client.from("room_members")
            .select("ride_rooms(*)")
            .order("joined_at", ascending: false)
            .limit(limit)
            .execute().value
        return rows.map { $0.ride_rooms }
    }
}
