import CloudKit
import Foundation

/// Fetches, proposes, and responds to standing (recurring, ask-once) room arrangements.
@Observable
final class StandingArrangementStore {
    var arrangements: [StandingArrangement] = []
    var isLoading = false
    var lastError: String?

    private let cloud = CloudKitManager.shared

    var pending: [StandingArrangement] {
        arrangements.filter { $0.status == .pending }
    }

    var active: [StandingArrangement] {
        arrangements.filter { $0.status == .active }
    }

    func refresh() async {
        guard cloud.isReady else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let records = try await cloud.fetchAllRecords(ofType: CloudKitManager.standingArrangementRecordType)
            arrangements = records.compactMap(StandingArrangement.init(record:))
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// The active arrangement (if any) in effect right now.
    func currentlyActive(at date: Date = Date()) -> StandingArrangement? {
        arrangements.first { $0.isActive(at: date) }
    }

    func propose(_ arrangement: StandingArrangement) async {
        do {
            let id = CKRecord.ID(recordName: arrangement.id, zoneID: try cloud.currentZoneID())
            let record = try makeRecord(for: arrangement, id: id)
            try await cloud.save(record)
            arrangements.append(arrangement)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func accept(_ arrangement: StandingArrangement) async {
        await update(arrangement) { $0.status = .active }
    }

    func decline(_ arrangement: StandingArrangement) async {
        await update(arrangement) { $0.status = .declined }
    }

    func cancel(_ arrangement: StandingArrangement) async {
        await update(arrangement) { $0.status = .cancelled }
    }

    private func update(_ arrangement: StandingArrangement, _ mutate: (inout StandingArrangement) -> Void) async {
        var updated = arrangement
        mutate(&updated)
        do {
            let id = CKRecord.ID(recordName: updated.id, zoneID: try cloud.currentZoneID())
            let record = try makeRecord(for: updated, id: id)
            try await cloud.save(record)
            if let index = arrangements.firstIndex(where: { $0.id == updated.id }) {
                arrangements[index] = updated
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func makeRecord(for arrangement: StandingArrangement, id: CKRecord.ID) throws -> CKRecord {
        let record = CKRecord(recordType: CloudKitManager.standingArrangementRecordType, recordID: id)
        record.parent = try cloud.parentReference()
        record["id"] = arrangement.id as CKRecordValue
        record["ownerName"] = arrangement.ownerName as CKRecordValue
        record["otherName"] = arrangement.otherName as CKRecordValue
        record["title"] = arrangement.title as CKRecordValue
        record["purposeRaw"] = arrangement.purpose.rawValue as CKRecordValue
        record["weekdaysRaw"] = arrangement.weekdays.map(\.rawValue) as CKRecordValue
        record["startHour"] = arrangement.startTime.hour as CKRecordValue?
        record["startMinute"] = arrangement.startTime.minute as CKRecordValue?
        record["endHour"] = arrangement.endTime.hour as CKRecordValue?
        record["endMinute"] = arrangement.endTime.minute as CKRecordValue?
        record["statusRaw"] = arrangement.status.rawValue as CKRecordValue
        record["createdAt"] = arrangement.createdAt as CKRecordValue
        return record
    }
}

private extension StandingArrangement {
    init?(record: CKRecord) {
        guard
            let id = record["id"] as? String,
            let ownerName = record["ownerName"] as? String,
            let otherName = record["otherName"] as? String,
            let title = record["title"] as? String,
            let purposeRaw = record["purposeRaw"] as? String,
            let purpose = Purpose(rawValue: purposeRaw),
            let statusRaw = record["statusRaw"] as? String,
            let status = StandingStatus(rawValue: statusRaw),
            let createdAt = record["createdAt"] as? Date
        else { return nil }

        let weekdaysRaw = record["weekdaysRaw"] as? [Int] ?? []
        let weekdays = Set(weekdaysRaw.compactMap(Weekday.init(rawValue:)))

        let startTime = DateComponents(hour: record["startHour"] as? Int, minute: record["startMinute"] as? Int)
        let endTime = DateComponents(hour: record["endHour"] as? Int, minute: record["endMinute"] as? Int)

        self.init(
            id: id,
            ownerName: ownerName,
            otherName: otherName,
            title: title,
            purpose: purpose,
            weekdays: weekdays,
            startTime: startTime,
            endTime: endTime,
            status: status,
            createdAt: createdAt
        )
    }
}
