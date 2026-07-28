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
        // Vision doesn't guarantee reading order, especially for grid/table layouts --
        // sorting by vertical position (Vision's coordinate origin is bottom-left, so
        // higher y is higher up on screen) gets us much closer to top-to-bottom order,
        // which the day-carryover logic in parse() depends on.
        let sorted = observations.sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y }
        return sorted.compactMap { $0.topCandidates(1).first?.string }
    }

    /// Many real schedules put the day(s) on their own header line followed by several
    /// time rows underneath (a common table layout), rather than repeating the day on
    /// every line. So a line with a time but no day of its own inherits whatever day was
    /// most recently seen, instead of only matching same-line day+time pairs.
    static func parse(lines: [String]) -> [DetectedScheduleEntry] {
        var entries: [DetectedScheduleEntry] = []
        var lastSeenWeekdays: Set<Weekday> = []

        for line in lines {
            let lineWeekdays = extractWeekdays(from: line)
            if !lineWeekdays.isEmpty {
                lastSeenWeekdays = lineWeekdays
            }

            guard let (start, end) = extractTimeRange(from: line) else { continue }
            let weekdays = lineWeekdays.isEmpty ? lastSeenWeekdays : lineWeekdays
            let title = cleanedTitle(from: line)
            entries.append(DetectedScheduleEntry(title: title, weekdays: weekdays, startTime: start, endTime: end))
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

    /// Looks for a full day name first (e.g. "Wednesday"), then falls back to the
    /// registrar-style letter codes most schedules actually use (e.g. "MWF", "TR").
    private static func extractWeekdays(from line: String) -> Set<Weekday> {
        let lower = line.lowercased()
        for (name, day) in dayNames where lower.contains(name) {
            return [day]
        }

        let words = line.split(whereSeparator: { !$0.isLetter })
        for word in words {
            let lowerWord = word.lowercased()
            guard (1...3).contains(lowerWord.count) else { continue }
            let matched = lowerWord.compactMap { dayCodes[$0] }
            if matched.count == lowerWord.count {
                return Set(matched)
            }
        }
        return []
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
            if lower.count <= 3, lower.allSatisfy({ letterCodes.contains($0) }) { return false }
            return true
        }
        title = words.joined(separator: " ")
        title = title.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "-–—,:")))
        return title.isEmpty ? "Class" : title
    }
}
