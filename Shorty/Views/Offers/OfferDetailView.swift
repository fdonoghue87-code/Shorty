import SwiftUI
import UIKit

struct OfferDetailView: View {
    let offer: RentalOffer

    @Environment(\.dismiss) private var dismiss
    @Environment(ProfileStore.self) private var profileStore
    @Environment(OfferStore.self) private var offerStore
    @Environment(ToastCenter.self) private var toastCenter
    @Environment(PaymentHandleStore.self) private var paymentHandleStore

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
            .task {
                await paymentHandleStore.refresh()
            }
        }
    }

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 10) {
            if iAmRecipient && (offer.status == .pending) {
                PrimaryButton(title: "Accept", systemImage: "checkmark", isLoading: isWorking) {
                    respond(toast: "Accepted") { await offerStore.accept(offer) }
                }
                SecondaryButton(title: "Propose Different Terms", systemImage: "arrow.left.arrow.right") {
                    Haptics.tap()
                    isCountering = true
                }
                Button(role: .destructive) {
                    respond(toast: "Declined", isWarning: true) { await offerStore.decline(offer) }
                } label: {
                    Text("Decline").font(.shortyHeadline)
                }
            } else if iAmSender && offer.status == .countered {
                PrimaryButton(title: "Accept New Terms", systemImage: "checkmark", isLoading: isWorking) {
                    respond(toast: "Accepted") { await offerStore.acceptCounter(offer) }
                }
                Button(role: .destructive) {
                    respond(toast: "Offer withdrawn", isWarning: true) { await offerStore.cancel(offer) }
                } label: {
                    Text("Withdraw Offer").font(.shortyHeadline)
                }
            } else if offer.status == .accepted, offer.isUpcoming || offer.isActiveNow {
                Button(role: .destructive) {
                    respond(toast: "Rental cancelled", isWarning: true) { await offerStore.cancel(offer) }
                } label: {
                    Text("Cancel Rental").font(.shortyHeadline)
                }
            }
        }
    }

    /// Shorty never touches the money itself -- it just hands off to whatever payment
    /// app the roommate already has, with the amount (and, if the recipient saved one
    /// in Settings, their Venmo/Cash App handle) pre-filled where each app's URL scheme
    /// allows it.
    @ViewBuilder
    private func paymentCard(price: Double) -> some View {
        ShortyCard {
            if iAmSender {
                let handle = paymentHandleStore.handlesByName[offer.toName]
                Text("Send $\(Int(price)) to \(offer.toName)")
                    .font(.shortyHeadline)
                HStack(spacing: 10) {
                    PaymentAppButton(title: "Venmo", systemImage: "dollarsign.circle.fill") {
                        Haptics.tap()
                        openVenmo(amount: price, to: handle)
                    }
                    PaymentAppButton(title: "Cash App", systemImage: "dollarsign.square.fill") {
                        Haptics.tap()
                        openCashApp(amount: price, to: handle)
                    }
                    PaymentAppButton(title: "Apple Cash", systemImage: "message.fill") {
                        Haptics.tap()
                        openMessagesForApplePay()
                    }
                }
                Text(paymentHint(for: handle, price: price))
                    .font(.shortyCaption)
                    .foregroundStyle(DukeTheme.inkMuted)
            } else {
                Text("Ask \(offer.fromName) to send you $\(Int(price)) via Venmo, Cash App, or Apple Cash.")
                    .font(.shortyBody)
                    .foregroundStyle(DukeTheme.inkMuted)
            }
        }
    }

    /// Describes what's actually going to happen when the sender taps each button --
    /// only Venmo and Cash App can be pre-addressed, and only once the recipient has
    /// saved a handle for that specific app in their own Settings.
    private func paymentHint(for handle: PaymentHandle?, price: Double) -> String {
        let venmoKnown = handle?.venmoIsSet ?? false
        let cashtagKnown = handle?.cashtagIsSet ?? false
        if venmoKnown && cashtagKnown {
            return "Venmo and Cash App both open ready to send to \(offer.toName) with the amount filled in. For Apple Cash, pick \(offer.toName) in Messages and enter $\(Int(price))."
        } else if venmoKnown {
            return "Venmo opens ready to send to \(offer.toName) with the amount filled in. \(offer.toName) hasn't added a Cash App tag yet -- for that and Apple Cash, pick them manually and enter $\(Int(price))."
        } else if cashtagKnown {
            return "Cash App opens ready to send to \(offer.toName) with the amount filled in. \(offer.toName) hasn't added a Venmo username yet -- for that and Apple Cash, pick them manually and enter $\(Int(price))."
        } else {
            return "Venmo opens with the amount pre-filled. For Cash App and Apple Cash, just pick \(offer.toName) and enter $\(Int(price)) once the app's open. (\(offer.toName) can save a Venmo/Cash App handle in Settings to skip this.)"
        }
    }

    private func openVenmo(amount: Double, to handle: PaymentHandle?) {
        let amountString = String(format: "%.2f", amount)
        let note = "Shorty room time".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Shorty"
        var urlString = "venmo://paycharge?txn=pay&amount=\(amountString)&note=\(note)"
        if let username = handle?.venmoUsername?.trimmingCharacters(in: .whitespaces), !username.isEmpty {
            let cleaned = username.hasPrefix("@") ? String(username.dropFirst()) : username
            if let encoded = cleaned.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                urlString += "&recipients=\(encoded)"
            }
        }
        guard let venmoURL = URL(string: urlString) else { return }
        UIApplication.shared.open(venmoURL, options: [:]) { success in
            if !success, let fallback = URL(string: "https://venmo.com") {
                UIApplication.shared.open(fallback)
            }
        }
    }

    private func openCashApp(amount: Double, to handle: PaymentHandle?) {
        if let cashtag = handle?.cashtag?.trimmingCharacters(in: .whitespaces), !cashtag.isEmpty {
            let cleaned = cashtag.hasPrefix("$") ? cashtag : "$\(cashtag)"
            let amountString = String(format: "%.2f", amount)
            if let encodedTag = cleaned.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
               let url = URL(string: "https://cash.app/\(encodedTag)/\(amountString)") {
                UIApplication.shared.open(url)
                return
            }
        }
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
                respond(toast: "Counter sent") {
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
        Haptics.tap()
        let duration = counterEnd.timeIntervalSince(counterStart)
        counterStart = counterStart.addingTimeInterval(shift)
        counterEnd = counterStart.addingTimeInterval(duration)
    }

    private func applyTomorrowSameTime() {
        Haptics.tap()
        let duration = counterEnd.timeIntervalSince(counterStart)
        guard let newStart = Calendar.current.date(byAdding: .day, value: 1, to: counterStart) else { return }
        counterStart = newStart
        counterEnd = newStart.addingTimeInterval(duration)
    }

    private func respond(toast: String, isWarning: Bool = false, _ action: @escaping () async -> Void) {
        isWorking = true
        Task {
            await action()
            isWorking = false
            isWarning ? Haptics.warning() : Haptics.success()
            toastCenter.show(toast)
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
