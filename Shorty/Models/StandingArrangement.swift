import Foundation

enum StandingStatus: String, Codable {
    case pending
    case active
    case declined
    case cancelled
}

/// A recurring room reservation that only needs approving once. Once a roommate accepts
/// one of these, it repeats every matching week without either person having to ask
/// again -- the whole point being to eliminate the ask, not just make it easier.
struct StandingArrangement: Identifiable, Codable, Equatable {
    var id: String
    var ownerName: String
    var otherName: String
    var title: String
    var purpose: Purpose
    var weekdays: Set<Weekday>
    var startTime: DateComponents
    var endTime: DateComponents
    var status: StandingStatus
    var createdAt: Date

    static func draft(owner: String, other: String) -> StandingArrangement {
        StandingArrangement(
            id: UUID().uuidString,
            ownerName: owner,
            otherName: other,
            title: "",
            purpose: .study,
            weekdays: [],
            startTime: DateComponents(hour: 19, minute: 0),
            endTime: DateComponents(hour: 21, minute: 0),
            status: .pending,
            createdAt: Date()
        )
    }

    /// Whether this arrangement is in effect right now.
    func isActive(at date: Date, calendar: Calendar = .current) -> Bool {
        guard status == .active else { return false }
        guard let weekday = Weekday(rawValue: calendar.component(.weekday, from: date)), weekdays.contains(weekday) else {
            return false
        }
        let minute = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        let startMinute = (startTime.hour ?? 0) * 60 + (startTime.minute ?? 0)
        let endMinute = (endTime.hour ?? 0) * 60 + (endTime.minute ?? 0)
        return minute >= startMinute && minute < endMinute
    }

    /// Today's concrete end time, for driving a live countdown the same way an accepted offer does.
    func todaysEnd(calendar: Calendar = .current) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = endTime.hour
        components.minute = endTime.minute
        return calendar.date(from: components) ?? Date()
    }
}
