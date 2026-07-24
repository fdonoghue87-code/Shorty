import Foundation

/// The device owner's local identity within the pair. Stored on-device only;
/// the shared CloudKit zone stores names as plain strings on each record.
struct Profile: Codable, Equatable {
    var myName: String
    var roommateName: String?
    var hasSharedRoom: Bool

    static let empty = Profile(myName: "", roommateName: nil, hasSharedRoom: false)

    var isPaired: Bool { !myName.isEmpty && roommateName != nil }
}
