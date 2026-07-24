import CloudKit
import Foundation

/// Fetches and manages the shared weekly schedule: predictable "away" and "in room" blocks
/// each roommate posts so the other can see, at a glance, when the room is likely to be free
/// and when a rental request probably isn't even necessary.
@Observable
final class ScheduleStore {
    var blocks: [ScheduleBlock] = []
    var isLoading = false
    var lastError: String?

    private let cloud = CloudKitManager.shared

    func refresh() async {
        guard cloud.isReady else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let records = try await cloud.fetchAllRecords(ofType: CloudKitManager.scheduleRecordType)
            blocks = records.compactMap(ScheduleBlock.init(record:))
        } catch {
            lastError = error.localizedDescription
        }
    }

    func save(_ block: ScheduleBlock) async {
        do {
            let id = CKRecord.ID(recordName: block.id, zoneID: try cloud.currentZoneID())
            let record = try makeRecord(for: block, id: id)
            try await cloud.save(record)
            if let index = blocks.firstIndex(where: { $0.id == block.id }) {
                blocks[index] = block
            } else {
                blocks.append(block)
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func delete(_ block: ScheduleBlock) async {
        do {
            let id = CKRecord.ID(recordName: block.id, zoneID: try cloud.currentZoneID())
            try await cloud.delete(id)
            blocks.removeAll { $0.id == block.id }
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Roommates the given moment is predictably occupied by, and whether that's because
    /// they're reliably away (room likely free even without a rental) or reliably in the room.
    func status(at date: Date = Date()) -> [ScheduleBlock] {
        blocks.filter { $0.covers(date) }
    }

    private func makeRecord(for block: ScheduleBlock, id: CKRecord.ID) throws -> CKRecord {
        let record = CKRecord(recordType: CloudKitManager.scheduleRecordType, recordID: id)
        record.parent = try cloud.parentReference()
        record["id"] = block.id as CKRecordValue
        record["ownerName"] = block.ownerName as CKRecordValue
        record["title"] = block.title as CKRecordValue
        record["kindRaw"] = block.kind.rawValue as CKRecordValue
        record["date"] = block.date as CKRecordValue?
        record["weekdaysRaw"] = block.recurringWeekdays.map(\.rawValue) as CKRecordValue
        record["startHour"] = block.startTime?.hour as CKRecordValue?
        record["startMinute"] = block.startTime?.minute as CKRecordValue?
        record["endHour"] = block.endTime?.hour as CKRecordValue?
        record["endMinute"] = block.endTime?.minute as CKRecordValue?
        record["createdAt"] = block.createdAt as CKRecordValue
        return record
    }
}

private extension ScheduleBlock {
    init?(record: CKRecord) {
        guard
            let id = record["id"] as? String,
            let ownerName = record["ownerName"] as? String,
            let title = record["title"] as? String,
            let kindRaw = record["kindRaw"] as? String,
            let kind = Kind(rawValue: kindRaw),
            let createdAt = record["createdAt"] as? Date
        else { return nil }

        let weekdaysRaw = record["weekdaysRaw"] as? [Int] ?? []
        let weekdays = Set(weekdaysRaw.compactMap(Weekday.init(rawValue:)))

        var start: DateComponents?
        if let h = record["startHour"] as? Int, let m = record["startMinute"] as? Int {
            start = DateComponents(hour: h, minute: m)
        }
        var end: DateComponents?
        if let h = record["endHour"] as? Int, let m = record["endMinute"] as? Int {
            end = DateComponents(hour: h, minute: m)
        }

        self.init(
            id: id,
            ownerName: ownerName,
            title: title,
            kind: kind,
            date: record["date"] as? Date,
            recurringWeekdays: weekdays,
            startTime: start,
            endTime: end,
            createdAt: createdAt
        )
    }
}
