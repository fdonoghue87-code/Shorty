import Foundation
import UIKit

/// Sends a schedule photo to Shorty's backend (a small proxy that holds the real Claude
/// API key, since a real key can never live inside the app itself) for far more accurate
/// reading than the on-device Vision-based parser can manage on messy table layouts.
/// Gated behind Shorty Plus in the UI, since every call costs real money -- see
/// `ImportScheduleView.scan(_:)` for the gating and on-device fallback.
enum SmartScheduleImportService {
    enum ImportError: Error, LocalizedError {
        case serverError(String)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .serverError(let message): return message
            case .invalidResponse: return "Got an unexpected response from the schedule-reading service."
            }
        }
    }

    /// Replace with your deployed Cloudflare Worker URL (see Backend/README.md).
    private static let endpoint = URL(string: "https://shorty-schedule-backend.YOUR-SUBDOMAIN.workers.dev")!
    /// Must exactly match the SHARED_SECRET set on the Worker via `wrangler secret put`.
    private static let sharedSecret = "REPLACE_WITH_YOUR_SHARED_SECRET"

    static func detectEntries(in image: UIImage) async throws -> [DetectedScheduleEntry] {
        guard let jpegData = image.jpegData(compressionQuality: 0.7) else {
            throw ImportError.invalidResponse
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(sharedSecret, forHTTPHeaderField: "X-Shorty-Secret")
        request.httpBody = try JSONEncoder().encode(RequestBody(image: jpegData.base64EncodedString()))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw ImportError.invalidResponse }

        guard httpResponse.statusCode == 200 else {
            let message = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error
                ?? "The schedule-reading service returned an error (\(httpResponse.statusCode))."
            throw ImportError.serverError(message)
        }

        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        return decoded.entries.compactMap { entry in
            let weekdays = Set(entry.weekdays.compactMap(Weekday.init(rawValue:)))
            guard !weekdays.isEmpty else { return nil }
            return DetectedScheduleEntry(
                title: entry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Class" : entry.title,
                weekdays: weekdays,
                startTime: DateComponents(hour: entry.startHour, minute: entry.startMinute),
                endTime: DateComponents(hour: entry.endHour, minute: entry.endMinute)
            )
        }
    }

    private struct RequestBody: Encodable {
        let image: String
    }

    private struct ResponseBody: Decodable {
        let entries: [Entry]
    }

    private struct Entry: Decodable {
        let title: String
        let weekdays: [Int]
        let startHour: Int
        let startMinute: Int
        let endHour: Int
        let endMinute: Int
    }

    private struct ErrorBody: Decodable {
        let error: String
    }
}
