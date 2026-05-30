import Foundation
import Combine
import Supabase

/// Holds the shared `SupabaseClient` and owns the per-room Realtime channel. Publishes the
/// live room state (roster, locations, music, SOS, quick messages, room row) that the
/// feature services write into and the UI observes.
///
/// Design: high-frequency *location* uses Realtime **broadcast** (ephemeral, instant), and
/// is also upserted to `live_locations` for "last known" persistence. Lower-frequency
/// changes (roster, music, SOS, quick messages, room) use **Postgres change** subscriptions
/// and a cheap refetch — robust and simple for MVP-sized rooms.
@MainActor
final class SupabaseManager: ObservableObject {

    static let shared = SupabaseManager()

    let client: SupabaseClient

    // Live room state
    @Published var room: RideRoom?
    @Published var roster: [RoomMember] = []
    @Published var locations: [UUID: LiveLocation] = [:]
    @Published var music: SharedMusicLink?
    @Published var activeSOS: [SOSAlert] = []
    @Published var quickMessages: [QuickMessage] = []
    @Published var isRealtimeConnected = false

    private var channel: RealtimeChannelV2?
    private var roomId: UUID?
    private var streamTasks: [Task<Void, Never>] = []

    private init() {
        client = SupabaseClient(
            supabaseURL: AppConfig.supabaseURL,
            supabaseKey: AppConfig.supabaseAnonKey
        )
    }

    // MARK: - Subscribe / unsubscribe

    func subscribe(to room: RideRoom) async {
        await unsubscribe()
        self.room = room
        self.roomId = room.id

        // Seed state from the DB.
        await refetchRoster()
        await refetchMusic()
        await refetchSOS()

        let ch = client.realtimeV2.channel("room:\(room.id.uuidString)")

        let memberChanges = ch.postgresChange(AnyAction.self, schema: "public",
                                              table: "room_members",
                                              filter: "room_id=eq.\(room.id.uuidString)")
        let musicChanges = ch.postgresChange(AnyAction.self, schema: "public",
                                             table: "shared_music_links",
                                             filter: "room_id=eq.\(room.id.uuidString)")
        let sosChanges = ch.postgresChange(AnyAction.self, schema: "public",
                                           table: "sos_alerts",
                                           filter: "room_id=eq.\(room.id.uuidString)")
        let quickChanges = ch.postgresChange(AnyAction.self, schema: "public",
                                             table: "quick_messages",
                                             filter: "room_id=eq.\(room.id.uuidString)")
        let roomChanges = ch.postgresChange(AnyAction.self, schema: "public",
                                            table: "ride_rooms",
                                            filter: "id=eq.\(room.id.uuidString)")
        let locationStream = ch.broadcastStream(event: "location")

        await ch.subscribe()
        self.channel = ch
        isRealtimeConnected = true

        streamTasks = [
            Task { [weak self] in for await _ in memberChanges { await self?.refetchRoster() } },
            Task { [weak self] in for await _ in musicChanges  { await self?.refetchMusic() } },
            Task { [weak self] in for await _ in sosChanges    { await self?.refetchSOS() } },
            Task { [weak self] in for await _ in roomChanges   { await self?.refetchRoom() } },
            Task { [weak self] in
                for await _ in quickChanges { await self?.refetchRecentQuickMessages() }
            },
            Task { [weak self] in
                for await msg in locationStream {
                    guard let self else { break }
                    if let loc: LiveLocation = decodeBroadcast(msg) { self.locations[loc.userId] = loc }
                }
            },
        ]
    }

    func unsubscribe() async {
        streamTasks.forEach { $0.cancel() }
        streamTasks = []
        if let channel { await channel.unsubscribe() }
        channel = nil
        roomId = nil
        room = nil
        roster = []; locations = [:]; music = nil; activeSOS = []; quickMessages = []
        isRealtimeConnected = false
    }

    // MARK: - Demo Mode (local sample state, no network)

    /// Populate the published room state from `DemoData` so every screen renders.
    func loadDemoState() {
        room = DemoData.room
        roster = DemoData.roster
        locations = DemoData.locations
        music = DemoData.music
        quickMessages = DemoData.quickMessages
        activeSOS = []
        isRealtimeConnected = true
    }

    func clearDemoState() {
        room = nil; roster = []; locations = [:]; music = nil
        activeSOS = []; quickMessages = []; isRealtimeConnected = false
    }

    /// Append a local SOS (used by the demo crash flow) so the banner/full-screen alert show.
    func addDemoSOS(kind: AlertKind) {
        let me = DemoData.meId
        let loc = locations[me]
        let alert = SOSAlert(id: UUID(), roomId: DemoData.roomId, userId: me,
                             lat: loc?.lat, lng: loc?.lng,
                             message: kind == .possibleCrash
                                ? "Possible crash / rider down — auto-detected, UNCONFIRMED."
                                : nil,
                             status: .active, kind: kind, createdAt: Date(), resolvedAt: nil)
        activeSOS = [alert] + activeSOS
    }

    func resolveDemoSOS(_ id: UUID) {
        activeSOS.removeAll { $0.id == id }
    }

    // MARK: - Broadcast (instant fan-out)

    func broadcastLocation(_ loc: LiveLocation) async {
        guard channel != nil else { return }   // no-op in demo / when not subscribed
        try? await channel?.broadcast(event: "location", message: encodeJSON(loc))
    }

    // MARK: - Refetch helpers

    private func refetchRoom() async {
        guard let roomId else { return }
        room = try? await client.from("ride_rooms").select().eq("id", value: roomId.uuidString)
            .single().execute().value
    }

    func refetchRoster() async {
        guard let roomId else { return }
        roster = (try? await client.from("room_members")
            .select("room_id,user_id,role,is_muted,subgroup,left_at,rider_profiles(*)")
            .eq("room_id", value: roomId.uuidString)
            .is("left_at", value: nil)
            .execute().value) ?? roster
    }

    private func refetchMusic() async {
        guard let roomId else { return }
        let rows: [SharedMusicLink]? = try? await client.from("shared_music_links")
            .select().eq("room_id", value: roomId.uuidString)
            .order("created_at", ascending: false).limit(1)
            .execute().value
        music = rows?.first
    }

    private func refetchSOS() async {
        guard let roomId else { return }
        activeSOS = (try? await client.from("sos_alerts")
            .select().eq("room_id", value: roomId.uuidString)
            .eq("status", value: "active")
            .order("created_at", ascending: false)
            .execute().value) ?? []
    }

    private func refetchRecentQuickMessages() async {
        guard let roomId else { return }
        quickMessages = (try? await client.from("quick_messages")
            .select().eq("room_id", value: roomId.uuidString)
            .order("created_at", ascending: false).limit(20)
            .execute().value) ?? quickMessages
    }
}

// MARK: - Realtime JSON helpers
//
// supabase-swift represents JSON as `AnyJSON` (Codable), `JSONObject == [String: AnyJSON]`.
// We round-trip Codable models through AnyJSON so we never hand-build payloads.

private let jsonEncoder: JSONEncoder = {
    let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e
}()
private let jsonDecoder: JSONDecoder = {
    let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
}()

func encodeJSON<T: Encodable>(_ value: T) -> JSONObject {
    guard let data = try? jsonEncoder.encode(value),
          let any = try? jsonDecoder.decode(AnyJSON.self, from: data),
          case let .object(obj) = any else { return [:] }
    return obj
}

func decodeBroadcast<T: Decodable>(_ message: JSONObject) -> T? {
    let body: AnyJSON = message["payload"] ?? .object(message)
    guard let data = try? jsonEncoder.encode(body) else { return nil }
    return try? jsonDecoder.decode(T.self, from: data)
}
