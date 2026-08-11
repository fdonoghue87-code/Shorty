import CloudKit
import Foundation

/// Reads and writes payment-app usernames on the shared Room record, keyed by name, so
/// each roommate's Venmo/Cash App handle -- entered once in Settings -- is visible on the
/// other roommate's device for pre-filling the payment deep links, without Shorty ever
/// running its own server to broker that.
@Observable
final class PaymentHandleStore {
    var handlesByName: [String: PaymentHandle] = [:]
    var isLoading = false
    var lastError: String?

    private let cloud = CloudKitManager.shared
    private static let fieldKey = "paymentHandlesJSON"

    func refresh() async {
        guard cloud.isReady, !cloud.isLocalPreview else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let record = try await cloud.fetchRoomRecord()
            handlesByName = Self.decode(record[Self.fieldKey] as? String)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func save(name: String, handle: PaymentHandle) async {
        guard !cloud.isLocalPreview else {
            handlesByName[name] = handle
            return
        }
        do {
            let record = try await cloud.fetchRoomRecord()
            var handles = Self.decode(record[Self.fieldKey] as? String)
            handles[name] = handle
            record[Self.fieldKey] = Self.encode(handles) as CKRecordValue
            try await cloud.save(record)
            handlesByName = handles
        } catch {
            lastError = error.localizedDescription
        }
    }

    private static func decode(_ json: String?) -> [String: PaymentHandle] {
        guard let json, let data = json.data(using: .utf8) else { return [:] }
        return (try? JSONDecoder().decode([String: PaymentHandle].self, from: data)) ?? [:]
    }

    private static func encode(_ handles: [String: PaymentHandle]) -> String {
        guard let data = try? JSONEncoder().encode(handles), let json = String(data: data, encoding: .utf8) else { return "{}" }
        return json
    }
}
