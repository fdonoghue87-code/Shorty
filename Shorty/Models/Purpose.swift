import SwiftUI

/// Why a roommate wants the room to themselves.
/// Phase one covers the four cases the app is being built around, a catch-all, and a
/// privacy option for whenever the "why" itself is part of the awkwardness of asking.
enum Purpose: String, CaseIterable, Identifiable, Codable {
    case study
    case call
    case intimacy
    case aloneTime
    case privateReason
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .study: return "Study Time"
        case .call: return "Phone Call"
        case .intimacy: return "Intimacy"
        case .aloneTime: return "Alone Time"
        case .privateReason: return "Personal Time"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .study: return "book.closed.fill"
        case .call: return "phone.fill"
        case .intimacy: return "heart.fill"
        case .aloneTime: return "moon.stars.fill"
        case .privateReason: return "lock.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}
