import CloudKit
import Foundation

/// Fetches, sends, and responds to rental offers in the shared CloudKit zone.
/// Also derives the room's live occupied/available status from whichever accepted
/// offer is active right now, since that's the single source of truth for both roommates.
@Observable
final class OfferStore {
    var offers: [RentalOffer] = []
    var isLoading = false
    var lastError: String?

    private let cloud = CloudKitManager.shared
    private var pollTask: Task<Void, Never>?

    var roomStatus: RoomStatus {
        guard let active = offers.first(where: \.isActiveNow) else { return .available }
        return RoomStatus(occupantName: active.fromName, sessionEnd: active.activeEnd, purpose: active.purpose, offerID: active.id)
    }

    var upcoming: [RentalOffer] {
        offers.filter(\.isUpcoming).sorted { $0.activeStart < $1.activeStart }
    }

    var needsMyResponse: [RentalOffer] {
        offers.filter { $0.status == .pending || $0.status == .countered }
    }

    var history: [RentalOffer] {
        offers.filter { [.declined, .completed, .cancelled].contains($0.status) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func refresh() async {
        guard cloud.isReady else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let records = try await cloud.fetchAllRecords(ofType: CloudKitManager.offerRecordType)
            offers = records.compactMap(RentalOffer.init(record:))
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Lightweight periodic refresh while the app is in the foreground.
    /// A phase-1.5 improvement is replacing this with CKQuerySubscription push notifications.
    func startPolling(interval: TimeInterval = 12) {
        stopPolling()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    func send(_ offer: RentalOffer) async {
        do {
            let id = CKRecord.ID(recordName: offer.id, zoneID: try cloud.currentZoneID())
            let record = try makeRecord(for: offer, id: id)
            try await cloud.save(record)
            offers.append(offer)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func accept(_ offer: RentalOffer) async {
        await update(offer) { $0.status = .accepted; $0.respondedAt = Date() }
    }

    func decline(_ offer: RentalOffer) async {
        await update(offer) { $0.status = .declined; $0.respondedAt = Date() }
    }

    func counter(_ offer: RentalOffer, start: Date, end: Date, price: Double?, note: String?) async {
        await update(offer) {
            $0.status = .countered
            $0.counterStart = start
            $0.counterEnd = end
            $0.counterPrice = price
            $0.counterNote = note
            $0.respondedAt = Date()
        }
    }

    func acceptCounter(_ offer: RentalOffer) async {
        await update(offer) { $0.status = .accepted }
    }

    func cancel(_ offer: RentalOffer) async {
        await update(offer) { $0.status = .cancelled }
    }

    func markCompleted(_ offer: RentalOffer) async {
        await update(offer) { $0.status = .completed }
    }

    private func update(_ offer: RentalOffer, _ mutate: (inout RentalOffer) -> Void) async {
        var updated = offer
        mutate(&updated)
        do {
            let record = try makeRecord(for: updated, id: CKRecord.ID(recordName: updated.id, zoneID: cloud.currentZoneID()))
            try await cloud.save(record)
            if let index = offers.firstIndex(where: { $0.id == updated.id }) {
                offers[index] = updated
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func makeRecord(for offer: RentalOffer, id: CKRecord.ID) throws -> CKRecord {
        let record = CKRecord(recordType: CloudKitManager.offerRecordType, recordID: id)
        record.parent = try cloud.parentReference()
        record["id"] = offer.id as CKRecordValue
        record["fromName"] = offer.fromName as CKRecordValue
        record["toName"] = offer.toName as CKRecordValue
        record["purposeRaw"] = offer.purpose.rawValue as CKRecordValue
        record["note"] = offer.note as CKRecordValue?
        record["requestedStart"] = offer.requestedStart as CKRecordValue
        record["requestedEnd"] = offer.requestedEnd as CKRecordValue
        record["price"] = offer.price as CKRecordValue?
        record["statusRaw"] = offer.status.rawValue as CKRecordValue
        record["counterStart"] = offer.counterStart as CKRecordValue?
        record["counterEnd"] = offer.counterEnd as CKRecordValue?
        record["counterPrice"] = offer.counterPrice as CKRecordValue?
        record["counterNote"] = offer.counterNote as CKRecordValue?
        record["createdAt"] = offer.createdAt as CKRecordValue
        record["respondedAt"] = offer.respondedAt as CKRecordValue?
        return record
    }
}

private extension RentalOffer {
    init?(record: CKRecord) {
        guard
            let id = record["id"] as? String,
            let fromName = record["fromName"] as? String,
            let toName = record["toName"] as? String,
            let purposeRaw = record["purposeRaw"] as? String,
            let purpose = Purpose(rawValue: purposeRaw),
            let requestedStart = record["requestedStart"] as? Date,
            let requestedEnd = record["requestedEnd"] as? Date,
            let statusRaw = record["statusRaw"] as? String,
            let status = OfferStatus(rawValue: statusRaw),
            let createdAt = record["createdAt"] as? Date
        else { return nil }

        self.init(
            id: id,
            fromName: fromName,
            toName: toName,
            purpose: purpose,
            note: record["note"] as? String,
            requestedStart: requestedStart,
            requestedEnd: requestedEnd,
            price: record["price"] as? Double,
            status: status,
            counterStart: record["counterStart"] as? Date,
            counterEnd: record["counterEnd"] as? Date,
            counterPrice: record["counterPrice"] as? Double,
            counterNote: record["counterNote"] as? String,
            createdAt: createdAt,
            respondedAt: record["respondedAt"] as? Date
        )
    }
}
