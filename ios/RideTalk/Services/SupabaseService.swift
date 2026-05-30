import Foundation
import Supabase

/// Thin wrapper around the Supabase client. Owns:
///   • PostgREST access (profiles, rooms, RPCs)
///   • the edge-function call that mints LiveKit tokens
///   • the per-room Realtime channel (roster, location, music, emergency)
///
/// Realtime room state is published so view models can observe it directly.
@MainActor
final class SupabaseService: ObservableObject {

    static let shared = SupabaseService()

    let client: SupabaseClient

    // Live room state (updated from Realtime while in a room).
    @Published var roster: [RoomMember] = []
    @Published var locations: [UUID: RiderLocation] = [:]
    @Published var musicState: MusicState?
    @Published var latestEmergency: EmergencyEvent?
    @Published var isRealtimeConnected = false

    private var roomChannel: RealtimeChannelV2?
    private var currentRoomId: UUID?

    private init() {
        self.client = SupabaseClient(
            supabaseURL: AppConfig.supabaseURL,
            supabaseKey: AppConfig.supabaseAnonKey
        )
    }

    // MARK: - Profiles

    func fetchProfile(userId: UUID) async throws -> UserProfile {
        try await client
            .from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value
    }

    func updateProfile(userId: UUID, _ update: ProfileUpdate) async throws -> UserProfile {
        try await client
            .from("profiles")
            .update(update)
            .eq("id", value: userId.uuidString)
            .select()
            .single()
            .execute()
            .value
    }

    // MARK: - Rooms (via RPC for atomic create/join)

    func createRoom(named name: String) async throws -> RideRoom {
        try await client
            .rpc("create_room", params: ["p_name": name])
            .single()
            .execute()
            .value
    }

    func joinRoom(code: String) async throws -> RideRoom {
        try await client
            .rpc("join_room", params: ["p_code": code])
            .single()
            .execute()
            .value
    }

    func leaveRoom(roomId: UUID) async throws {
        _ = try await client
            .rpc("leave_room", params: ["p_room_id": roomId.uuidString])
            .execute()
    }

    func endRoom(roomId: UUID) async throws {
        _ = try await client
            .rpc("end_room", params: ["p_room_id": roomId.uuidString])
            .execute()
    }

    /// Roster with joined profiles for display.
    func fetchRoster(roomId: UUID) async throws -> [RoomMember] {
        try await client
            .from("room_members")
            .select("room_id,user_id,role,is_muted,left_at,profiles(*)")
            .eq("room_id", value: roomId.uuidString)
            .is("left_at", value: nil)
            .execute()
            .value
    }

    /// Host moderation: mute/unmute a rider.
    func setMuted(roomId: UUID, userId: UUID, muted: Bool) async throws {
        _ = try await client
            .from("room_members")
            .update(["is_muted": muted])
            .eq("room_id", value: roomId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    /// Host moderation: remove a rider from the room.
    func removeMember(roomId: UUID, userId: UUID) async throws {
        _ = try await client
            .from("room_members")
            .delete()
            .eq("room_id", value: roomId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    // MARK: - LiveKit token (edge function)

    func liveKitToken(roomId: UUID) async throws -> LiveKitToken {
        try await client.functions
            .invoke("livekit-token", options: .init(body: ["roomId": roomId.uuidString]))
    }

    // MARK: - Music Sync (compliant)

    func upsertMusicState(_ state: MusicState) async throws {
        _ = try await client
            .from("music_states")
            .upsert(state, onConflict: "room_id")
            .execute()
        // Also broadcast for instant delivery to riders already in the channel.
        try? await roomChannel?.broadcast(event: "music_state", message: encodeJSON(state))
    }

    func fetchMusicState(roomId: UUID) async throws -> MusicState? {
        let rows: [MusicState] = try await client
            .from("music_states")
            .select()
            .eq("room_id", value: roomId.uuidString)
            .execute()
            .value
        return rows.first
    }

    // MARK: - Location broadcast

    /// Broadcast a location ping to the room (and optionally persist it).
    func broadcastLocation(_ ping: RiderLocation, persist: Bool = false) async {
        try? await roomChannel?.broadcast(event: "location", message: encodeJSON(ping))
        if persist {
            _ = try? await client.from("ride_locations").insert(ping).execute()
        }
    }

    // MARK: - Emergency broadcast

    func broadcastEmergency(_ event: EmergencyEvent) async {
        try? await roomChannel?.broadcast(event: "emergency", message: encodeJSON(event))
    }

    // MARK: - Realtime room channel

    func subscribeToRoom(roomId: UUID) async {
        await unsubscribeFromRoom()
        currentRoomId = roomId

        // Seed roster + music from the DB, then listen for changes.
        roster = (try? await fetchRoster(roomId: roomId)) ?? []
        musicState = try? await fetchMusicState(roomId: roomId)

        let channel = client.realtimeV2.channel("room:\(roomId.uuidString)")

        // Roster changes (joins/leaves/mutes) via Postgres changes on room_members.
        let memberChanges = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "room_members",
            filter: "room_id=eq.\(roomId.uuidString)"
        )

        // Broadcast events.
        let locationStream = channel.broadcastStream(event: "location")
        let musicStream = channel.broadcastStream(event: "music_state")
        let emergencyStream = channel.broadcastStream(event: "emergency")

        await channel.subscribe()
        roomChannel = channel
        isRealtimeConnected = true

        // Fan out each stream into a Task. They live until the channel is torn down.
        Task { [weak self] in
            for await _ in memberChanges {
                guard let self, let id = self.currentRoomId else { break }
                self.roster = (try? await self.fetchRoster(roomId: id)) ?? self.roster
            }
        }
        Task { [weak self] in
            for await msg in locationStream {
                guard let self else { break }
                if let ping: RiderLocation = decodeBroadcast(msg) {
                    self.locations[ping.userId] = ping
                }
            }
        }
        Task { [weak self] in
            for await msg in musicStream {
                guard let self else { break }
                if let state: MusicState = decodeBroadcast(msg) { self.musicState = state }
            }
        }
        Task { [weak self] in
            for await msg in emergencyStream {
                guard let self else { break }
                if let event: EmergencyEvent = decodeBroadcast(msg) { self.latestEmergency = event }
            }
        }
    }

    func unsubscribeFromRoom() async {
        if let channel = roomChannel {
            await channel.unsubscribe()
        }
        roomChannel = nil
        currentRoomId = nil
        roster = []
        locations = [:]
        musicState = nil
        latestEmergency = nil
        isRealtimeConnected = false
    }
}

// MARK: - JSON helpers for Realtime broadcast payloads
//
// supabase-swift represents JSON as `AnyJSON` (Codable) and `JSONObject == [String: AnyJSON]`.
// We round-trip our Codable models through AnyJSON so we never hand-build payloads.

private let jsonEncoder: JSONEncoder = {
    let e = JSONEncoder()
    e.dateEncodingStrategy = .iso8601
    return e
}()

private let jsonDecoder: JSONDecoder = {
    let d = JSONDecoder()
    d.dateDecodingStrategy = .iso8601
    return d
}()

/// Encode a Codable into the `JSONObject` shape Realtime broadcast expects.
func encodeJSON<T: Encodable>(_ value: T) -> JSONObject {
    guard let data = try? jsonEncoder.encode(value),
          let any = try? jsonDecoder.decode(AnyJSON.self, from: data),
          case let .object(obj) = any
    else { return [:] }
    return obj
}

/// Decode a broadcast message back into a Codable. Supabase nests the sent body under
/// the `"payload"` key, so we unwrap it when present.
func decodeBroadcast<T: Decodable>(_ message: JSONObject) -> T? {
    let body: AnyJSON = message["payload"] ?? .object(message)
    guard let data = try? jsonEncoder.encode(body) else { return nil }
    return try? jsonDecoder.decode(T.self, from: data)
}
