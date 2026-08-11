import CloudKit
import Foundation
import Observation

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
    static let standingArrangementRecordType = "StandingArrangement"
    static let zoneName = "SharedRoomZone"

    /// Lazy (and excluded from Observation tracking, since @Observable can't apply its
    /// tracking transform to a lazy property) because CKContainer.default() checks the
    /// app's iCloud entitlement the instant it's created and crashes immediately if it's
    /// missing -- local-preview mode must never touch this at all, so it can't be created
    /// eagerly at singleton init time.
    @ObservationIgnored
    private(set) lazy var container = CKContainer.default()

    /// True once this device has a working room reference (either created or accepted).
    private(set) var isReady = false
    private(set) var isOwner = false

    /// True when running with no real iCloud container -- lets someone click through the
    /// whole app on a free Apple ID (CloudKit itself requires a paid Developer Program
    /// membership to provision) before they're ready to test the real two-device sync.
    private(set) var isLocalPreview = false
    private var localPreviewStorage: [CKRecord.ID: CKRecord] = [:]

    private var zoneID: CKRecordZone.ID?
    private var roomRecordID: CKRecord.ID?
    private var database: CKDatabase?

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let zoneOwnerName = "shorty.zoneOwnerName"
        static let roomRecordName = "shorty.roomRecordName"
        static let isOwner = "shorty.isOwner"
        static let isLocalPreview = "shorty.isLocalPreview"
    }

    private init() {
        restoreFromDefaultsIfAvailable()
    }

    // MARK: - Bootstrapping

    /// Call once at launch. If we already know how to reach the shared room, reconnects silently.
    func restoreFromDefaultsIfAvailable() {
        if defaults.bool(forKey: Keys.isLocalPreview) {
            enableLocalPreview()
            return
        }
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

    /// Skips real CloudKit entirely: everything lives in memory on this one device, so
    /// there's nobody to sync with, but every screen in the app works right away.
    func enableLocalPreview() {
        let zone = CKRecordZone.ID(zoneName: Self.zoneName, ownerName: "local-preview")
        isLocalPreview = true
        isOwner = true
        zoneID = zone
        roomRecordID = CKRecord.ID(recordName: "local-preview-room", zoneID: zone)
        isReady = true
        defaults.set(true, forKey: Keys.isLocalPreview)
    }

    func forgetRoom() {
        defaults.removeObject(forKey: Keys.roomRecordName)
        defaults.removeObject(forKey: Keys.zoneOwnerName)
        defaults.removeObject(forKey: Keys.isOwner)
        defaults.removeObject(forKey: Keys.isLocalPreview)
        isReady = false
        isLocalPreview = false
        localPreviewStorage.removeAll()
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
        if isLocalPreview {
            return localPreviewStorage.values.filter { $0.recordType == type }
        }

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
        if isLocalPreview {
            localPreviewStorage[record.recordID] = record
            return
        }
        _ = try await currentDatabase().save(record)
    }

    func delete(_ recordID: CKRecord.ID) async throws {
        if isLocalPreview {
            localPreviewStorage.removeValue(forKey: recordID)
            return
        }
        _ = try await currentDatabase().deleteRecord(withID: recordID)
    }

    func fetchRecord(withID id: CKRecord.ID) async throws -> CKRecord {
        if isLocalPreview {
            guard let record = localPreviewStorage[id] else { throw NotReadyError() }
            return record
        }
        return try await currentDatabase().record(for: id)
    }

    /// The shared Room record itself, for small pieces of state that belong to the pair as
    /// a whole rather than to any single offer/schedule item -- e.g. payment handles.
    func fetchRoomRecord() async throws -> CKRecord {
        guard let roomRecordID else { throw NotReadyError() }
        return try await fetchRecord(withID: roomRecordID)
    }

    // MARK: - Push notifications for incoming requests

    private static let incomingOfferSubscriptionID = "shorty-incoming-offer-subscription"

    /// Registers (or re-registers, harmlessly) a CloudKit push subscription so this device
    /// gets a system notification -- with Accept/Decline actions right on it -- the moment
    /// a roommate sends a new request addressed to `myName`. No backend of our own: CloudKit
    /// itself is the push provider, the same as everything else this app does.
    func subscribeToIncomingOffers(myName: String) async throws {
        guard !isLocalPreview else { return }
        let db = try currentDatabase()

        let predicate = NSPredicate(format: "toName == %@", myName)
        let subscription = CKQuerySubscription(
            recordType: Self.offerRecordType,
            predicate: predicate,
            subscriptionID: Self.incomingOfferSubscriptionID,
            options: [.firesOnRecordCreation]
        )

        let info = CKSubscription.NotificationInfo()
        info.alertBody = "New room time request -- tap to respond"
        info.soundName = "default"
        info.shouldBadge = true
        info.category = "OFFER_REQUEST"
        subscription.notificationInfo = info

        _ = try await db.save(subscription)
    }

    /// Called when the recipient taps Accept/Decline directly on the push notification --
    /// patches just the status fields on the existing record rather than needing a full
    /// OfferStore instance, since this can run with no view hierarchy alive at all.
    func respondToOffer(recordID: CKRecord.ID, accept: Bool) async throws {
        let record = try await fetchRecord(withID: recordID)
        record["statusRaw"] = (accept ? OfferStatus.accepted : OfferStatus.declined).rawValue as CKRecordValue
        record["respondedAt"] = Date() as CKRecordValue
        try await save(record)
    }
}
