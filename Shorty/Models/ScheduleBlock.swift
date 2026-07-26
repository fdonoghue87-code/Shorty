import Foundation

enum Weekday: Int, CaseIterable, Codable, Identifiable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    var id: Int { rawValue }

    var short: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }

    /// Single-letter registrar-style code (the "MWF" / "TR" convention used on most
    /// class schedules), used both to label detected schedule blocks and to parse them.
    var code: String {
        switch self {
        case .sunday: return "U"
        case .monday: return "M"
        case .tuesday: return "T"
        case .wednesday: return "W"
        case .thursday: return "R"
        case .friday: return "F"
        case .saturday: return "S"
        }
    }

    var fullName: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }
}

/// A block of time a roommate is predictably out (class, practice, work) or predictably
/// in the room, shared so the other roommate can see when a rental will actually be needed.
struct ScheduleBlock: Identifiable, Codable, Equatable {
    enum Kind: String, Codable {
        case away       // roommate is reliably out of the room
        case inRoom     // roommate is reliably in the room
    }

    var id: String
    var ownerName: String
    var title: String
    var kind: Kind

    /// One-off block, or nil if this is a recurring weekly block.
    var date: Date?

    /// Recurring weekly block fields.
    var recurringWeekdays: Set<Weekday>
    var startTime: DateComponents?
    var endTime: DateComponents?

    var createdAt: Date

    static func draft(owner: String) -> ScheduleBlock {
        ScheduleBlock(
            id: UUID().uuidString,
            ownerName: owner,
            title: "",
            kind: .away,
            date: nil,
            recurringWeekdays: [],
            startTime: DateComponents(hour: 9, minute: 0),
            endTime: DateComponents(hour: 10, minute: 0),
            createdAt: Date()
        )
    }

    /// Whether this block covers the given moment (handles both one-off and recurring blocks).
    func covers(_ date: Date, calendar: Calendar = .current) -> Bool {
        guard let startTime, let endTime else { return false }

        if let fixedDate = self.date {
            return calendar.isDate(fixedDate, inSameDayAs: date)
                && timeFalls(date, between: startTime, and: endTime, calendar: calendar)
        }

        let weekday = Weekday(rawValue: calendar.component(.weekday, from: date))
        guard let weekday, recurringWeekdays.contains(weekday) else { return false }
        return timeFalls(date, between: startTime, and: endTime, calendar: calendar)
    }

    private func timeFalls(_ date: Date, between start: DateComponents, and end: DateComponents, calendar: Calendar) -> Bool {
        let minute = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        let startMinute = (start.hour ?? 0) * 60 + (start.minute ?? 0)
        let endMinute = (end.hour ?? 0) * 60 + (end.minute ?? 0)
        return minute >= startMinute && minute < endMinute
    }
}
