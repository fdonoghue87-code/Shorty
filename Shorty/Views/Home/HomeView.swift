import SwiftUI

struct HomeView: View {
    @Environment(ProfileStore.self) private var profileStore
    @Environment(OfferStore.self) private var offerStore
    @Environment(ScheduleStore.self) private var scheduleStore

    @State private var showingNewOffer = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    RoomStatusCard(status: offerStore.roomStatus, myName: profileStore.profile.myName)

                    if offerStore.roomStatus.isOccupied && offerStore.roomStatus.occupantName == profileStore.profile.myName {
                        SecondaryButton(title: "End My Session Now", systemImage: "stop.circle") {
                            endMySessionEarly()
                        }
                    } else if !offerStore.roomStatus.isOccupied {
                        PrimaryButton(title: "Send an Offer", systemImage: "paperplane.fill") {
                            showingNewOffer = true
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

                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "Coming up")
                        if offerStore.upcoming.isEmpty {
                            EmptyStateView(systemImage: "clock", title: "Nothing scheduled", message: "Accepted offers will show up here with a countdown to their start time.")
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
            }
            .shortyBackground()
            .shortyHeader("Shorty")
            .sheet(isPresented: $showingNewOffer) {
                NewOfferView()
            }
            .task {
                await offerStore.refresh()
                await scheduleStore.refresh()
                offerStore.startPolling()
            }
        }
    }

    private var todaysBlocks: [ScheduleBlock] {
        scheduleStore.status(at: Date())
    }

    private func endMySessionEarly() {
        guard let offerID = offerStore.roomStatus.offerID,
              let offer = offerStore.offers.first(where: { $0.id == offerID }) else { return }
        Task { await offerStore.markCompleted(offer) }
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
