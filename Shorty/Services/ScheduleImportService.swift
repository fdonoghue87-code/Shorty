import Foundation
import UIKit
import Vision

/// One day/time pairing pulled out of a photographed schedule, awaiting the roommate's
/// review before it's saved as a real ScheduleBlock.
struct DetectedScheduleEntry: Identifiable {
    let id = UUID()
    var title: String
    var weekdays: Set<Weekday>
    var startTime: DateComponents
    var endTime: DateComponents
    var isIncluded = true
}

/// Turns a photo of a class schedule into draft ScheduleBlocks. This is best-effort:
/// schedules come in wildly different layouts (grids, lists, screenshots), so results
/// are always shown to the roommate for review/edit before anything gets saved, rather
/// than silently trusting whatever OCR + a handful of regexes could pull out.
enum ScheduleImportService {
    static func recognizeText(in image: UIImage) throws -> [String] {
        guard let cgImage = image.cgImage else { return [] }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
        let observations = request.results as? [VNRecognizedTextObservation] ?? []

        // A grid/table schedule (course | days | time | room, in separate columns) very
        // often comes back from Vision as several *separate* observations at nearly the
        // same height rather than one line of text -- so a course's title ends up with no
        // time on its "line" and gets dropped, while the time's "line" has no title.
        // Clustering observations into rows by vertical position (Vision's origin is
        // bottom-left, so higher y is higher on screen), then reading each row
        // left-to-right, reconstructs one line per table row instead.
        struct Piece { let text: String; let box: CGRect }
        let pieces: [Piece] = observations.compactMap { observation in
            guard let text = observation.topCandidates(1).first?.string else { return nil }
            return Piece(text: text, box: observation.boundingBox)
        }

        let rowTolerance: CGFloat = 0.02
        var rows: [[Piece]] = []
        for piece in pieces.sorted(by: { $0.box.origin.y > $1.box.origin.y }) {
            if let anchor = rows.last?.first, abs(anchor.box.origin.y - piece.box.origin.y) <= rowTolerance {
                rows[rows.count - 1].append(piece)
            } else {
                rows.append([piece])
            }
        }

        return rows.map { row in
            row.sorted { $0.box.origin.x < $1.box.origin.x }
                .map(\.text)
                .joined(separator: " ")
        }
    }

    /// Many real schedules put the day(s) on their own header line followed by several
    /// time rows underneath (a common table layout), rather than repeating the day on
    /// every line. So a line with a time but no day of its own inherits whatever day was
    /// most recently seen, instead of only matching same-line day+time pairs. Likewise, a
    /// course title that lands on its own line with no day or time of its own (row
    /// clustering doesn't always merge perfectly) is remembered as a fallback title for
    /// whichever day/time line comes next, instead of being silently dropped.
    static func parse(lines: [String]) -> [DetectedScheduleEntry] {
        var entries: [DetectedScheduleEntry] = []
        var lastSeenWeekdays: Set<Weekday> = []
        var lastSeenTitle: String?

        for line in lines {
            let lineWeekdays = extractWeekdays(from: line)
            if !lineWeekdays.isEmpty {
                lastSeenWeekdays = lineWeekdays
            }

            guard let (start, end) = extractTimeRange(from: line) else {
                if lineWeekdays.isEmpty {
                    let candidate = cleanedTitle(from: line)
                    if candidate != "Class" { lastSeenTitle = candidate }
                }
                continue
            }

            let weekdays = lineWeekdays.isEmpty ? lastSeenWeekdays : lineWeekdays
            var title = cleanedTitle(from: line)
            if title == "Class", let lastSeenTitle {
                title = lastSeenTitle
            }
            entries.append(DetectedScheduleEntry(title: title, weekdays: weekdays, startTime: start, endTime: end))
            lastSeenTitle = nil
        }

        return entries
    }

    private static let timePattern =
        #"(\d{1,2})(?::(\d{2}))?\s*(am|pm|AM|PM)?\s*(?:-|–|—|to)\s*(\d{1,2})(?::(\d{2}))?\s*(am|pm|AM|PM)?"#

    private static func extractTimeRange(from line: String) -> (DateComponents, DateComponents)? {
        guard let regex = try? NSRegularExpression(pattern: timePattern) else { return nil }
        let range = NSRange(line.startIndex..., in: line)
        guard let match = regex.firstMatch(in: line, range: range) else { return nil }

        func group(_ index: Int) -> String? {
            guard let r = Range(match.range(at: index), in: line) else { return nil }
            return String(line[r])
        }

        guard let startHour = group(1).flatMap(Int.init),
              let endHour = group(4).flatMap(Int.init) else { return nil }

        let startMinute = group(2).flatMap(Int.init) ?? 0
        let endMinute = group(5).flatMap(Int.init) ?? 0
        let startMeridiem = group(3)?.lowercased()
        let endMeridiem = group(6)?.lowercased() ?? startMeridiem

        return (
            DateComponents(hour: resolveHour(startHour, meridiem: startMeridiem ?? endMeridiem), minute: startMinute),
            DateComponents(hour: resolveHour(endHour, meridiem: endMeridiem), minute: endMinute)
        )
    }

    private static func resolveHour(_ hour: Int, meridiem: String?) -> Int {
        guard let meridiem else { return hour }
        if meridiem == "pm" && hour < 12 { return hour + 12 }
        if meridiem == "am" && hour == 12 { return 0 }
        return hour
    }

    private static let dayNames: [String: Weekday] = [
        "monday": .monday, "tuesday": .tuesday, "wednesday": .wednesday,
        "thursday": .thursday, "friday": .friday, "saturday": .saturday, "sunday": .sunday,
    ]

    private static let dayCodes: [Character: Weekday] = [
        "m": .monday, "t": .tuesday, "w": .wednesday, "r": .thursday, "f": .friday, "s": .saturday, "u": .sunday,
    ]

    /// Three-letter day abbreviations (e.g. "Mon", "Wed", "Thu"), a format many registrar
    /// systems use instead of, or alongside, the single-letter MTWRFSU codes.
    private static let dayAbbreviations: [String: Weekday] = [
        "mon": .monday, "tue": .tuesday, "tues": .tuesday, "wed": .wednesday,
        "thu": .thursday, "thur": .thursday, "thurs": .thursday, "fri": .friday,
        "sat": .saturday, "sun": .sunday,
    ]

    /// Looks for a full day name first (e.g. "Wednesday"), then three-letter abbreviations
    /// (e.g. "Mon"), then registrar-style single-letter codes (e.g. "MWF", "TR") -- and,
    /// for the letter-code case, collects every matching word on the line instead of
    /// stopping at the first one, since some layouts list days as separate tokens ("M W F"
    /// rather than "MWF").
    private static func extractWeekdays(from line: String) -> Set<Weekday> {
        let lower = line.lowercased()
        for (name, day) in dayNames where lower.contains(name) {
            return [day]
        }

        var collected: Set<Weekday> = []
        let words = line.split(whereSeparator: { !$0.isLetter })
        for word in words {
            let lowerWord = word.lowercased()
            if let abbreviated = dayAbbreviations[lowerWord] {
                collected.insert(abbreviated)
                continue
            }
            guard (1...3).contains(lowerWord.count) else { continue }
            let matched = lowerWord.compactMap { dayCodes[$0] }
            if matched.count == lowerWord.count {
                collected.formUnion(matched)
            }
        }
        return collected
    }

    private static func cleanedTitle(from line: String) -> String {
        var title = line
        if let regex = try? NSRegularExpression(pattern: timePattern) {
            let range = NSRange(title.startIndex..., in: title)
            title = regex.stringByReplacingMatches(in: title, range: range, withTemplate: "")
        }

        let letterCodes = Set("mtwrfsu")
        let words = title.split(separator: " ").filter { word in
            let lower = word.lowercased()
            if dayNames.keys.contains(lower) { return false }
            if dayAbbreviations.keys.contains(lower) { return false }
            if lower.count <= 3, lower.allSatisfy({ letterCodes.contains($0) }) { return false }
            return true
        }
        title = words.joined(separator: " ")
        title = title.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "-–—,:")))
        return title.isEmpty ? "Class" : title
    }
}
