import CloudKit
import Foundation

/// Owns the CloudKit plumbing that lets exactly two roommates read and write the same
/// "Room" record hierarchy: one roommate creates the Room and shares it (via CKShare,
/// e.g. through Messages); the other accepts the link and both devices then read/write
/// the same custom zone. Offers and schedule blocks are saved as children of the Room
/// record so they automatically inherit the share's permissions.
@Observable
final class CloudKitManager {
    static let shared = CloudKitManager()

    static let roomRecordType = "Room"
    static let offerRecordType = "Offer"
    static let scheduleRecordType = "ScheduleBlock"
    static let zoneName = "SharedRoomZone"

    private(set) var container = CKContainer.default()

    /// True once this device has a working room reference (either created or accepted).
    private(set) var isReady = false
    private(set) var isOwner = false

    private var zoneID: CKRecordZone.ID?
    private var roomRecordID: CKRecord.ID?
    private var database: CKDatabase?

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let zoneOwnerName = "shorty.zoneOwnerName"
        static let roomRecordName = "shorty.roomRecordName"
        static let isOwner = "shorty.isOwner"
    }

    private init() {
        restoreFromDefaultsIfAvailable()
    }

    // MARK: - Bootstrapping

    /// Call once at launch. If we already know how to reach the shared room, reconnects silently.
    func restoreFromDefaultsIfAvailable() {
        guard let recordName = defaults.string(forKey: Keys.roomRecordName) else { return }
        let owner = defaults.bool(forKey: Keys.isOwner)
        isOwner = owner
        let zoneOwnerName = defaults.string(forKey: Keys.zoneOwnerName) ?? CKCurrentUserDefaultName
        let zone = CKRecordZone.ID(zoneName: Self.zoneName, ownerName: zoneOwnerName)
        zoneID = zone
        roomRecordID = CKRecord.ID(recordName: recordName, zoneID: zone)
        database = owner ? container.privateCloudDatabase : container.sharedCloudDatabase
        isReady = true
    }

    /// Roommate A: create the room + zone in the private database and return a CKShare
    /// ready to be presented in a UICloudSharingController.
    func createRoomAndShare(roomName: String) async throws -> (share: CKShare, container: CKContainer) {
        let privateDB = container.privateCloudDatabase
        let zone = CKRecordZone(zoneID: CKRecordZone.ID(zoneName: Self.zoneName, ownerName: CKCurrentUserDefaultName))
        _ = try await privateDB.save(zone)

        let roomRecord = CKRecord(recordType: Self.roomRecordType, recordID: CKRecord.ID(recordName: UUID().uuidString, zoneID: zone.zoneID))
        roomRecord["roomName"] = roomName as CKRecordValue

        let share = CKShare(rootRecord: roomRecord)
        share[CKShare.SystemFieldKey.title] = "Shorty: \(roomName)" as CKRecordValue
        share.publicPermission = .none

        let saveOp = CKModifyRecordsOperation(recordsToSave: [roomRecord, share], recordIDsToDelete: nil)
        saveOp.savePolicy = .allKeys
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            saveOp.modifyRecordsResultBlock = { result in
                switch result {
                case .success: continuation.resume()
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
            privateDB.add(saveOp)
        }

        isOwner = true
        zoneID = zone.zoneID
        roomRecordID = roomRecord.recordID
        database = privateDB
        isReady = true
        persist(zoneOwnerName: CKCurrentUserDefaultName, roomRecordName: roomRecord.recordID.recordName, owner: true)

        return (share, container)
    }

    /// Roommate B: call from the app-delegate hook that receives an accepted share's metadata.
    func acceptShare(metadata: CKShare.Metadata) async throws {
        let operation = CKAcceptSharesOperation(shareMetadatas: [metadata])
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            operation.perShareResultBlock = { _, result in
                if case .failure(let error) = result {
                    continuation.resume(throwing: error)
                }
            }
            operation.acceptSharesResultBlock = { result in
                switch result {
                case .success: continuation.resume()
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
            container.add(operation)
        }

        let rootRecordID = metadata.rootRecordID
        isOwner = false
        zoneID = rootRecordID.zoneID
        roomRecordID = rootRecordID
        database = container.sharedCloudDatabase
        isReady = true
        persist(zoneOwnerName: rootRecordID.zoneID.ownerName, roomRecordName: rootRecordID.recordName, owner: false)
    }

    func forgetRoom() {
        defaults.removeObject(forKey: Keys.roomRecordName)
        defaults.removeObject(forKey: Keys.zoneOwnerName)
        defaults.removeObject(forKey: Keys.isOwner)
        isReady = false
        zoneID = nil
        roomRecordID = nil
        database = nil
    }

    private func persist(zoneOwnerName: String, roomRecordName: String, owner: Bool) {
        defaults.set(zoneOwnerName, forKey: Keys.zoneOwnerName)
        defaults.set(roomRecordName, forKey: Keys.roomRecordName)
        defaults.set(owner, forKey: Keys.isOwner)
    }

    // MARK: - Record access shared by the stores

    struct NotReadyError: Error {}

    func currentDatabase() throws -> CKDatabase {
        guard let database else { throw NotReadyError() }
        return database
    }

    func currentZoneID() throws -> CKRecordZone.ID {
        guard let zoneID else { throw NotReadyError() }
        return zoneID
    }

    func parentReference() throws -> CKRecord.Reference {
        guard let roomRecordID else { throw NotReadyError() }
        return CKRecord.Reference(recordID: roomRecordID, action: .none)
    }

    func fetchAllRecords(ofType type: String) async throws -> [CKRecord] {
        let db = try currentDatabase()
        let query = CKQuery(recordType: type, predicate: NSPredicate(value: true))
        var results: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?

        repeat {
            let response: (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?)
            if let cursor {
                response = try await db.records(continuingMatchFrom: cursor)
            } else {
                response = try await db.records(matching: query, inZoneWith: try currentZoneID())
            }
            for (_, result) in response.matchResults {
                if case .success(let record) = result {
                    results.append(record)
                }
            }
            cursor = response.queryCursor
        } while cursor != nil

        return results
    }

    func save(_ record: CKRecord) async throws {
        _ = try await currentDatabase().save(record)
    }

    func delete(_ recordID: CKRecord.ID) async throws {
        _ = try await currentDatabase().deleteRecord(withID: recordID)
    }
}
