import SwiftUI

struct HomeView: View {
    @Environment(ProfileStore.self) private var profileStore
    @Environment(OfferStore.self) private var offerStore
    @Environment(ScheduleStore.self) private var scheduleStore
    @Environment(StandingArrangementStore.self) private var standingStore
    @Environment(ToastCenter.self) private var toastCenter
    @Environment(PaymentHandleStore.self) private var paymentHandleStore

    @State private var showingNewOffer = false
    @State private var pendingQuickDuration: TimeInterval?

    private let quickDurations: [TimeInterval] = [15 * 60, 30 * 60, 60 * 60]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    RoomStatusCard(status: effectiveStatus, myName: profileStore.profile.myName)

                    if effectiveStatus.isOccupied && effectiveStatus.occupantName == profileStore.profile.myName && effectiveStatus.offerID != nil {
                        SecondaryButton(title: "End My Session Now", systemImage: "stop.circle") {
                            endMySessionEarly()
                        }
                    } else if !effectiveStatus.isOccupied {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader(title: "Quick Request", subtitle: "One tap, no form to fill out")
                            HStack(spacing: 10) {
                                ForEach(quickDurations, id: \.self) { duration in
                                    Button {
                                        pendingQuickDuration = duration
                                    } label: {
                                        Text(quickLabel(for: duration))
                                            .font(.shortyHeadline)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .foregroundStyle(DukeTheme.dukeBlue)
                                            .background(DukeTheme.dukeBlue.opacity(0.08))
                                            .clipShape(RoundedRectangle(cornerRadius: DukeTheme.controlCornerRadius, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            SecondaryButton(title: "Custom Request", systemImage: "slider.horizontal.3") {
                                showingNewOffer = true
                            }
                        }
                    }

                    if !todaysBlocks.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader(title: "Right now", subtitle: "From the shared schedule")
                            ForEach(todaysBlocks) { block in
                                ScheduleBlockRow(block: block)
                            }
                        }
                    }

                    if !sessionCounts.isEmpty {
                        ShortyCard {
                            SectionHeader(title: "Room Time So Far", subtitle: "How things have balanced out between you two")
                            HStack(spacing: 16) {
                                ForEach(sessionCounts, id: \.name) { entry in
                                    VStack(spacing: 2) {
                                        Text("\(entry.count)")
                                            .font(.shortyLargeTitle)
                                            .foregroundStyle(DukeTheme.dukeBlue)
                                        Text(entry.name)
                                            .font(.shortyCaption)
                                            .foregroundStyle(DukeTheme.inkMuted)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "Coming up")
                        if offerStore.upcoming.isEmpty {
                            EmptyStateView(systemImage: "clock", title: "Nothing scheduled", message: "Accepted requests will show up here with a countdown to their start time.")
                        } else {
                            ForEach(offerStore.upcoming) { offer in
                                OfferRowView(offer: offer, myName: profileStore.profile.myName)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .refreshable {
                await offerStore.refresh()
                await scheduleStore.refresh()
                await standingStore.refresh()
            }
            .shortyBackground()
            .shortyHeader("Hello, \(profileStore.profile.myName)")
            .sheet(isPresented: $showingNewOffer) {
                NewOfferView()
            }
            .task {
                await offerStore.refresh()
                await scheduleStore.refresh()
                await standingStore.refresh()
                offerStore.startPolling()
                await paymentHandleStore.refresh()
                if !CloudKitManager.shared.isLocalPreview {
                    try? await CloudKitManager.shared.subscribeToIncomingOffers(myName: profileStore.profile.myName)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .shortyOfferRespondedViaPush)) { _ in
                Task { await offerStore.refresh() }
            }
            .onChange(of: effectiveStatus) { _, newStatus in
                if newStatus.isOccupied, newStatus.occupantName == profileStore.profile.myName, let end = newStatus.sessionEnd {
                    NotificationService.scheduleSessionReminders(endingAt: end)
                } else {
                    NotificationService.cancelSessionReminders()
                }
            }
            .confirmationDialog(
                "Send this request?",
                isPresented: Binding(get: { pendingQuickDuration != nil }, set: { if !$0 { pendingQuickDuration = nil } }),
                titleVisibility: .visible
            ) {
                Button("Send") {
                    if let duration = pendingQuickDuration { sendQuickRequest(duration: duration) }
                }
                Button("Cancel", role: .cancel) { pendingQuickDuration = nil }
            } message: {
                if let duration = pendingQuickDuration {
                    Text("Request the room now for \(quickLabel(for: duration)). \(profileStore.profile.roommateName ?? "Your roommate") will get it right away.")
                }
            }
        }
    }

    /// Merges live offer-based occupancy with any standing arrangement in effect right
    /// now, so a recurring ask-once slot shows up the same way an accepted offer does.
    private var effectiveStatus: RoomStatus {
        if offerStore.roomStatus.isOccupied { return offerStore.roomStatus }
        if let standing = standingStore.currentlyActive() {
            return RoomStatus(occupantName: standing.ownerName, sessionEnd: standing.todaysEnd(), purpose: standing.purpose, offerID: nil)
        }
        return .available
    }

    private var todaysBlocks: [ScheduleBlock] {
        scheduleStore.status(at: Date())
    }

    private var sessionCounts: [(name: String, count: Int)] {
        var counts: [String: Int] = [:]
        for offer in offerStore.offers where offer.status == .completed || (offer.status == .accepted && offer.activeEnd < Date()) {
            counts[offer.fromName, default: 0] += 1
        }
        return counts.map { (name: $0.key, count: $0.value) }.sorted { $0.name < $1.name }
    }

    private func quickLabel(for interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        return hours == 1 ? "1 hour" : "\(hours) hours"
    }

    private func sendQuickRequest(duration: TimeInterval) {
        guard let roommate = profileStore.profile.roommateName else { return }
        let start = Date()
        var offer = RentalOffer.draft(from: profileStore.profile.myName, to: roommate)
        offer.purpose = .privateReason
        offer.requestedStart = start
        offer.requestedEnd = start.addingTimeInterval(duration)
        Task {
            await offerStore.send(offer)
            Haptics.success()
            toastCenter.show("Request sent to \(roommate)")
        }
        pendingQuickDuration = nil
    }

    private func endMySessionEarly() {
        guard let offerID = offerStore.roomStatus.offerID,
              let offer = offerStore.offers.first(where: { $0.id == offerID }) else { return }
        Task {
            await offerStore.markCompleted(offer)
            Haptics.success()
            toastCenter.show("Session ended")
        }
    }
}

struct ScheduleBlockRow: View {
    let block: ScheduleBlock

    var body: some View {
        ShortyCard {
            HStack {
                Image(systemName: block.kind == .away ? "figure.walk.motion" : "person.fill")
                    .foregroundStyle(DukeTheme.dukeBlue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(block.title.isEmpty ? (block.kind == .away ? "Away" : "In the room") : block.title)
                        .font(.shortyHeadline)
                    Text(block.ownerName)
                        .font(.shortyCaption)
                        .foregroundStyle(DukeTheme.inkMuted)
                }
                Spacer()
            }
        }
    }
}
