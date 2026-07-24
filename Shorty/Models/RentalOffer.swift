import Foundation

enum OfferStatus: String, Codable {
    case pending
    case accepted
    case declined
    case countered
    case cancelled
    case completed
}

/// A request from one roommate to have the room to themselves for a window of time,
/// with optional negotiation over price and timing.
struct RentalOffer: Identifiable, Codable, Equatable {
    var id: String
    var fromName: String
    var toName: String
    var purpose: Purpose
    var note: String?

    var requestedStart: Date
    var requestedEnd: Date
    var price: Double?

    var status: OfferStatus

    /// Populated when the receiving roommate proposes different terms instead of a flat accept/decline.
    var counterStart: Date?
    var counterEnd: Date?
    var counterPrice: Double?
    var counterNote: String?

    var createdAt: Date
    var respondedAt: Date?

    /// The terms that are currently on the table: the counter if one exists, otherwise the original ask.
    var activeStart: Date { counterStart ?? requestedStart }
    var activeEnd: Date { counterEnd ?? requestedEnd }
    var activePrice: Double? { counterStart != nil ? counterPrice : price }

    var duration: TimeInterval { activeEnd.timeIntervalSince(activeStart) }

    var isActiveNow: Bool {
        status == .accepted && Date() >= activeStart && Date() < activeEnd
    }

    var isUpcoming: Bool {
        status == .accepted && Date() < activeStart
    }

    static func draft(from: String, to: String) -> RentalOffer {
        let start = Date().addingTimeInterval(15 * 60)
        return RentalOffer(
            id: UUID().uuidString,
            fromName: from,
            toName: to,
            purpose: .study,
            note: nil,
            requestedStart: start,
            requestedEnd: start.addingTimeInterval(60 * 60),
            price: nil,
            status: .pending,
            createdAt: Date()
        )
    }
}
