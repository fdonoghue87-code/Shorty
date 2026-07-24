import Foundation

/// The live state of the shared room, derived from the currently-active accepted offer (if any).
struct RoomStatus: Codable, Equatable {
    var occupantName: String?
    var sessionEnd: Date?
    var purpose: Purpose?
    var offerID: String?

    var isOccupied: Bool { occupantName != nil && (sessionEnd ?? .distantPast) > Date() }

    static let available = RoomStatus(occupantName: nil, sessionEnd: nil, purpose: nil, offerID: nil)
}
