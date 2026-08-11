import EventKit
import Foundation

/// Turns recurring events already on a student's personal calendar (classes, work
/// shifts, standing meetings -- synced in from Google, Outlook, or iCloud through the
/// Calendar app's own account settings, no OAuth or backend of our own needed) into the
/// same draft schedule entries the photo-import flow produces, so they go through the
/// identical review step before anything is saved.
enum CalendarImportService {
    enum ImportError: Error {
        case accessDenied
    }

    static func requestAccess() async throws {
        let granted = try await EKEventStore().requestFullAccessToEvents()
        guard granted else { throw ImportError.accessDenied }
    }

    /// Looks `weeksAhead` weeks into the future across every calendar on the device,
    /// then groups occurrences by title + time-of-day so a class meeting three times a
    /// week comes back as one weekly entry instead of dozens of individual occurrences.
    /// Events that only occur once in that window are one-off appointments, not a
    /// predictable-schedule signal, and are left out on purpose.
    static func detectRecurringEntries(weeksAhead: Int = 8) async throws -> [DetectedScheduleEntry] {
        let store = EKEventStore()
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .weekOfYear, value: weeksAhead, to: start) else { return [] }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate)

        struct GroupKey: Hashable {
            let title: String
            let startHour: Int
            let startMinute: Int
            let endHour: Int
            let endMinute: Int
        }
        struct GroupInfo {
            var weekdays: Set<Weekday> = []
            var occurrenceCount = 0
        }

        var groups: [GroupKey: GroupInfo] = [:]

        for event in events {
            guard !event.isAllDay else { continue }
            let startComponents = calendar.dateComponents([.hour, .minute, .weekday], from: event.startDate)
            let endComponents = calendar.dateComponents([.hour, .minute], from: event.endDate)
            guard let weekdayRaw = startComponents.weekday, let weekday = Weekday(rawValue: weekdayRaw) else { continue }

            let rawTitle = event.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let key = GroupKey(
                title: rawTitle.isEmpty ? "Class" : rawTitle,
                startHour: startComponents.hour ?? 0,
                startMinute: startComponents.minute ?? 0,
                endHour: endComponents.hour ?? 0,
                endMinute: endComponents.minute ?? 0
            )
            groups[key, default: GroupInfo()].weekdays.insert(weekday)
            groups[key, default: GroupInfo()].occurrenceCount += 1
        }

        return groups
            .filter { $0.value.occurrenceCount >= 2 }
            .map { key, info in
                DetectedScheduleEntry(
                    title: key.title,
                    weekdays: info.weekdays,
                    startTime: DateComponents(hour: key.startHour, minute: key.startMinute),
                    endTime: DateComponents(hour: key.endHour, minute: key.endMinute)
                )
            }
            .sorted { ($0.startTime.hour ?? 0, $0.startTime.minute ?? 0) < ($1.startTime.hour ?? 0, $1.startTime.minute ?? 0) }
    }
}
