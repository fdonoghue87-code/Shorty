import Foundation

/// A roommate's optional payment-app identifiers, saved once in Settings so the other
/// roommate's payment buttons can jump straight to the right person instead of making
/// them search their contacts by hand inside Venmo or Cash App.
struct PaymentHandle: Codable, Equatable {
    var venmoUsername: String?
    var cashtag: String?

    static let empty = PaymentHandle(venmoUsername: nil, cashtag: nil)

    var venmoIsSet: Bool { !(venmoUsername ?? "").isEmpty }
    var cashtagIsSet: Bool { !(cashtag ?? "").isEmpty }
}
