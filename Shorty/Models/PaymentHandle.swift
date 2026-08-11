import Foundation

/// A roommate's optional payment-app identifiers, saved once in Settings so the other
/// roommate's payment buttons can jump straight to the right person instead of making
/// them search their contacts by hand inside Venmo or Cash App.
struct PaymentHandle: Codable, Equatable {
    var venmoUsername: String?
    var cashtag: String?
    /// Zelle has no public deep-link API to pre-address or pre-fill an amount (unlike
    /// Venmo/Cash App) -- this is just the phone number or email the roommate uses for
    /// Zelle, shown so it can be copied into whichever bank app handles it for them.
    var zelleHandle: String?

    static let empty = PaymentHandle(venmoUsername: nil, cashtag: nil, zelleHandle: nil)

    var venmoIsSet: Bool { !(venmoUsername ?? "").isEmpty }
    var cashtagIsSet: Bool { !(cashtag ?? "").isEmpty }
    var zelleIsSet: Bool { !(zelleHandle ?? "").isEmpty }
}
