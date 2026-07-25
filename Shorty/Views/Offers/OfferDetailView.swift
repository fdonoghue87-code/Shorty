import SwiftUI

struct OfferDetailView: View {
    let offer: RentalOffer

    @Environment(\.dismiss) private var dismiss
    @Environment(ProfileStore.self) private var profileStore
    @Environment(OfferStore.self) private var offerStore

    @State private var isCountering = false
    @State private var counterStart: Date
    @State private var counterEnd: Date
    @State private var counterPrice: Double
    @State private var counterNote = ""
    @State private var isWorking = false

    init(offer: RentalOffer) {
        self.offer = offer
        _counterStart = State(initialValue: offer.activeStart)
        _counterEnd = State(initialValue: offer.activeEnd)
        _counterPrice = State(initialValue: offer.activePrice ?? 0)
    }

    private var myName: String { profileStore.profile.myName }
    private var iAmRecipient: Bool { offer.toName == myName }
    private var iAmSender: Bool { offer.fromName == myName }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ShortyCard {
                        HStack {
                            Image(systemName: offer.purpose.icon)
                                .foregroundStyle(DukeTheme.dukeBlue)
                            Text(offer.purpose.label).font(.shortyHeadline)
                            Spacer()
                            StatusPill(status: offer.status)
                        }
                        Divider()
                        DetailRow(label: "From", value: offer.fromName)
                        DetailRow(label: "To", value: offer.toName)
                        DetailRow(label: "Starts", value: full(offer.activeStart))
                        DetailRow(label: "Ends", value: full(offer.activeEnd))
                        if let price = offer.activePrice {
                            DetailRow(label: "Price", value: "$\(Int(price))")
                        }
                        if let note = offer.counterStart != nil ? offer.counterNote : offer.note, !note.isEmpty {
                            DetailRow(label: "Note", value: note)
                        }
                    }

                    if isCountering {
                        counterForm
                    } else {
                        actions
                    }
                }
                .padding(20)
            }
            .shortyBackground()
            .navigationTitle("Offer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 10) {
            if iAmRecipient && (offer.status == .pending) {
                PrimaryButton(title: "Accept", systemImage: "checkmark", isLoading: isWorking) {
                    respond { await offerStore.accept(offer) }
                }
                SecondaryButton(title: "Propose Different Terms", systemImage: "arrow.left.arrow.right") {
                    isCountering = true
                }
                Button(role: .destructive) {
                    respond { await offerStore.decline(offer) }
                } label: {
                    Text("Decline").font(.shortyHeadline)
                }
            } else if iAmSender && offer.status == .countered {
                PrimaryButton(title: "Accept New Terms", systemImage: "checkmark", isLoading: isWorking) {
                    respond { await offerStore.acceptCounter(offer) }
                }
                Button(role: .destructive) {
                    respond { await offerStore.cancel(offer) }
                } label: {
                    Text("Withdraw Offer").font(.shortyHeadline)
                }
            } else if offer.status == .accepted, offer.isUpcoming || offer.isActiveNow {
                Button(role: .destructive) {
                    respond { await offerStore.cancel(offer) }
                } label: {
                    Text("Cancel Rental").font(.shortyHeadline)
                }
            }
        }
    }

    private var counterForm: some View {
        VStack(spacing: 14) {
            ShortyCard {
                Text("Quick adjust").font(.shortyCaption).foregroundStyle(DukeTheme.inkMuted)
                HStack(spacing: 8) {
                    quickAdjustButton("+15 min") { applyQuickAdjust(15 * 60) }
                    quickAdjustButton("+1 hour") { applyQuickAdjust(60 * 60) }
                    quickAdjustButton("Tomorrow") { applyTomorrowSameTime() }
                }
                Divider()
                DatePicker("New start", selection: $counterStart, displayedComponents: [.date, .hourAndMinute])
                DatePicker("New end", selection: $counterEnd, in: counterStart..., displayedComponents: [.date, .hourAndMinute])
                Stepper(value: $counterPrice, in: 0...100, step: 1) {
                    Text("Price: $\(Int(counterPrice))")
                }
                TextField("Why the change? (optional)", text: $counterNote, axis: .vertical)
            }
            PrimaryButton(title: "Send Counter", systemImage: "paperplane.fill", isLoading: isWorking) {
                respond {
                    await offerStore.counter(offer, start: counterStart, end: counterEnd, price: counterPrice, note: counterNote.isEmpty ? nil : counterNote)
                }
            }
            SecondaryButton(title: "Cancel", systemImage: "xmark") {
                isCountering = false
            }
        }
    }

    private func quickAdjustButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.shortyCaption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .foregroundStyle(DukeTheme.dukeBlue)
                .background(DukeTheme.dukeBlue.opacity(0.08))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func applyQuickAdjust(_ shift: TimeInterval) {
        let duration = counterEnd.timeIntervalSince(counterStart)
        counterStart = counterStart.addingTimeInterval(shift)
        counterEnd = counterStart.addingTimeInterval(duration)
    }

    private func applyTomorrowSameTime() {
        let duration = counterEnd.timeIntervalSince(counterStart)
        guard let newStart = Calendar.current.date(byAdding: .day, value: 1, to: counterStart) else { return }
        counterStart = newStart
        counterEnd = newStart.addingTimeInterval(duration)
    }

    private func respond(_ action: @escaping () async -> Void) {
        isWorking = true
        Task {
            await action()
            isWorking = false
            dismiss()
        }
    }

    private func full(_ date: Date) -> String {
        DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)
    }
}

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).font(.shortyCaption).foregroundStyle(DukeTheme.inkMuted)
            Spacer()
            Text(value).font(.shortyBody)
        }
    }
}
