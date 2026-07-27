import SwiftUI
import UIKit

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

                    if let price = offer.activePrice, price > 0, offer.status == .accepted || offer.status == .completed {
                        paymentCard(price: price)
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

    /// Shorty never touches the money itself -- it just hands off to whatever payment
    /// app the roommate already has, with the amount pre-filled where the app's URL
    /// scheme allows it. The recipient still has to be picked manually since Shorty
    /// doesn't collect Venmo/Cash App usernames or phone numbers.
    @ViewBuilder
    private func paymentCard(price: Double) -> some View {
        ShortyCard {
            if iAmSender {
                Text("Send $\(Int(price)) to \(offer.toName)")
                    .font(.shortyHeadline)
                HStack(spacing: 10) {
                    PaymentAppButton(title: "Venmo", systemImage: "dollarsign.circle.fill") {
                        openVenmo(amount: price)
                    }
                    PaymentAppButton(title: "Cash App", systemImage: "dollarsign.square.fill") {
                        openCashApp()
                    }
                    PaymentAppButton(title: "Apple Cash", systemImage: "message.fill") {
                        openMessagesForApplePay()
                    }
                }
                Text("Venmo opens with the amount pre-filled. For Cash App and Apple Cash, just pick \(offer.toName) and enter $\(Int(price)) once the app's open.")
                    .font(.shortyCaption)
                    .foregroundStyle(DukeTheme.inkMuted)
            } else {
                Text("Ask \(offer.fromName) to send you $\(Int(price)) via Venmo, Cash App, or Apple Cash.")
                    .font(.shortyBody)
                    .foregroundStyle(DukeTheme.inkMuted)
            }
        }
    }

    private func openVenmo(amount: Double) {
        let amountString = String(format: "%.2f", amount)
        let note = "Shorty room time".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Shorty"
        guard let venmoURL = URL(string: "venmo://paycharge?txn=pay&amount=\(amountString)&note=\(note)") else { return }
        UIApplication.shared.open(venmoURL, options: [:]) { success in
            if !success, let fallback = URL(string: "https://venmo.com") {
                UIApplication.shared.open(fallback)
            }
        }
    }

    private func openCashApp() {
        guard let url = URL(string: "https://cash.app/") else { return }
        UIApplication.shared.open(url)
    }

    private func openMessagesForApplePay() {
        guard let url = URL(string: "sms:") else { return }
        UIApplication.shared.open(url)
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
                DatePicker("New start", selection: $counterStart, in: Date()..., displayedComponents: [.date, .hourAndMinute])
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

private struct PaymentAppButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.title3)
                Text(title)
                    .font(.shortyCaption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundStyle(DukeTheme.dukeBlue)
            .background(DukeTheme.dukeBlue.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: DukeTheme.controlCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
