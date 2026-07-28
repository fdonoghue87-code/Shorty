import SwiftUI

struct OffersListView: View {
    @Environment(ProfileStore.self) private var profileStore
    @Environment(OfferStore.self) private var offerStore

    @State private var selectedOffer: RentalOffer?

    var body: some View {
        NavigationStack {
            List {
                if !incoming.isEmpty {
                    Section("Incoming") {
                        offerRows(incoming)
                    }
                }

                if !outbound.isEmpty {
                    Section("Outbound") {
                        offerRows(outbound)
                    }
                }

                if !offerStore.upcoming.isEmpty {
                    Section("Upcoming") {
                        offerRows(offerStore.upcoming)
                    }
                }

                if !offerStore.history.isEmpty {
                    Section("Past") {
                        offerRows(offerStore.history)
                    }
                }

                if incoming.isEmpty && outbound.isEmpty && offerStore.upcoming.isEmpty && offerStore.history.isEmpty {
                    EmptyStateView(systemImage: "envelope", title: "No offers yet", message: "Send one from the Room tab to get started.")
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .shortyBackground()
            .scrollContentBackground(.hidden)
            .shortyHeader("Room Time")
            .refreshable { await offerStore.refresh() }
            .sheet(item: $selectedOffer) { offer in
                OfferDetailView(offer: offer)
            }
        }
    }

    /// Requests your roommate originated -- these are the ones most likely to need
    /// your response (accept/decline/counter).
    private var incoming: [RentalOffer] {
        offerStore.needsMyResponse.filter { $0.fromName != profileStore.profile.myName }
    }

    /// Requests you sent -- shown separately so it's clear you're the one waiting,
    /// not the one who owes a response.
    private var outbound: [RentalOffer] {
        offerStore.needsMyResponse.filter { $0.fromName == profileStore.profile.myName }
    }

    @ViewBuilder
    private func offerRows(_ offers: [RentalOffer]) -> some View {
        ForEach(offers) { offer in
            OfferRowView(offer: offer, myName: profileStore.profile.myName) {
                selectedOffer = offer
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .listRowSeparator(.hidden)
        }
    }
}
