import Foundation

/// The device owner's local identity within the pair. Stored on-device only;
/// the shared CloudKit zone stores names as plain strings on each record.
struct Profile: Codable, Equatable {
    var myName: String
    var roommateName: String?
    var hasSharedRoom: Bool
    var hasSeenHowItWorks: Bool

    static let empty = Profile(myName: "", roommateName: nil, hasSharedRoom: false, hasSeenHowItWorks: false)

    var isPaired: Bool { !myName.isEmpty && roommateName != nil }

    init(myName: String, roommateName: String?, hasSharedRoom: Bool, hasSeenHowItWorks: Bool = false) {
        self.myName = myName
        self.roommateName = roommateName
        self.hasSharedRoom = hasSharedRoom
        self.hasSeenHowItWorks = hasSeenHowItWorks
    }

    private enum CodingKeys: String, CodingKey {
        case myName, roommateName, hasSharedRoom, hasSeenHowItWorks
    }

    /// Custom decoding so a profile saved before `hasSeenHowItWorks` existed still loads
    /// cleanly instead of failing and silently resetting someone's onboarding progress.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        myName = try container.decode(String.self, forKey: .myName)
        roommateName = try container.decodeIfPresent(String.self, forKey: .roommateName)
        hasSharedRoom = try container.decode(Bool.self, forKey: .hasSharedRoom)
        hasSeenHowItWorks = try container.decodeIfPresent(Bool.self, forKey: .hasSeenHowItWorks) ?? false
    }
}
