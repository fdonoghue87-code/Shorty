import SwiftUI

struct OffersListView: View {
    @Environment(ProfileStore.self) private var profileStore
    @Environment(OfferStore.self) private var offerStore

    @State private var selectedOffer: RentalOffer?

    var body: some View {
        NavigationStack {
            List {
                let needsResponse = offerStore.needsMyResponse
                if !needsResponse.isEmpty {
                    Section("Needs a response") {
                        ForEach(needsResponse) { offer in
                            OfferRowView(offer: offer, myName: profileStore.profile.myName) {
                                selectedOffer = offer
                            }
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowSeparator(.hidden)
                        }
                    }
                }

                if !offerStore.upcoming.isEmpty {
                    Section("Upcoming") {
                        ForEach(offerStore.upcoming) { offer in
                            OfferRowView(offer: offer, myName: profileStore.profile.myName) {
                                selectedOffer = offer
                            }
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowSeparator(.hidden)
                        }
                    }
                }

                if !offerStore.history.isEmpty {
                    Section("Past") {
                        ForEach(offerStore.history) { offer in
                            OfferRowView(offer: offer, myName: profileStore.profile.myName) {
                                selectedOffer = offer
                            }
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowSeparator(.hidden)
                        }
                    }
                }

                if needsResponse.isEmpty && offerStore.upcoming.isEmpty && offerStore.history.isEmpty {
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
}
