import Foundation

/// Canned text alerts riders can fire one-handed.
enum QuickMessageKind: String, Codable, CaseIterable, Identifiable {
    case stopping
    case gas
    case slowDown = "slow_down"
    case behind
    case allGood = "all_good"
    case custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .stopping: return "Stopping"
        case .gas: return "Need gas/charge"
        case .slowDown: return "Slow down"
        case .behind: return "I'm behind"
        case .allGood: return "All good"
        case .custom: return "Custom"
        }
    }
    var icon: String {
        switch self {
        case .stopping: return "hand.raised.fill"
        case .gas: return "fuelpump.fill"
        case .slowDown: return "tortoise.fill"
        case .behind: return "arrow.down.backward"
        case .allGood: return "checkmark.circle.fill"
        case .custom: return "text.bubble.fill"
        }
    }
    /// "Slow down" is treated as higher priority.
    var isPriority: Bool { self == .slowDown }
}

/// Mirrors `public.quick_messages`.
struct QuickMessage: Codable, Identifiable, Equatable {
    var id: UUID
    var roomId: UUID
    var userId: UUID
    var kind: QuickMessageKind
    var text: String
    var isPriority: Bool
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case roomId = "room_id"
        case userId = "user_id"
        case kind, text
        case isPriority = "is_priority"
        case createdAt = "created_at"
    }
}

struct QuickMessageInsert: Encodable {
    var roomId: UUID
    var userId: UUID
    var kind: QuickMessageKind
    var text: String
    var isPriority: Bool

    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case userId = "user_id"
        case kind, text
        case isPriority = "is_priority"
    }
}
