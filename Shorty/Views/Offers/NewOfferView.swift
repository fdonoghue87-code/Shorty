import SwiftUI

struct NewOfferView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ProfileStore.self) private var profileStore
    @Environment(OfferStore.self) private var offerStore

    @State private var purpose: Purpose = .study
    @State private var start = Date().addingTimeInterval(15 * 60)
    @State private var duration: TimeInterval = 60 * 60
    @State private var wantsPrice = false
    @State private var price: Double = 5
    @State private var note = ""
    @State private var isSending = false

    private let durations: [TimeInterval] = [15 * 60, 30 * 60, 60 * 60, 2 * 60 * 60, 4 * 60 * 60]

    var body: some View {
        NavigationStack {
            Form {
                Section("What's it for?") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(Purpose.allCases) { option in
                            Button {
                                purpose = option
                            } label: {
                                PurposeChip(purpose: option, isSelected: purpose == option)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, 8)
                }

                Section("When") {
                    DatePicker("Starts", selection: $start, in: Date()..., displayedComponents: [.date, .hourAndMinute])

                    Text("How long")
                        .font(.shortyCaption)
                        .foregroundStyle(DukeTheme.inkMuted)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(durations, id: \.self) { value in
                            Button {
                                duration = value
                            } label: {
                                DurationChip(label: label(for: value), isSelected: duration == value)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, 4)
                }

                Section("Sweeten the deal (optional)") {
                    Toggle("Offer a price", isOn: $wantsPrice)
                    if wantsPrice {
                        Stepper(value: $price, in: 0...100, step: 1) {
                            Text("$\(Int(price))")
                        }
                    }
                    TextField("Add a note for \(profileStore.profile.roommateName ?? "your roommate")", text: $note, axis: .vertical)
                }
            }
            .navigationTitle("Request Room Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSending ? "Sending…" : "Send") { send() }
                        .disabled(isSending)
                }
            }
        }
    }

    private func label(for interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        return hours == 1 ? "1 hour" : "\(hours) hours"
    }

    private func send() {
        guard let roommate = profileStore.profile.roommateName else { return }
        isSending = true
        var offer = RentalOffer.draft(from: profileStore.profile.myName, to: roommate)
        offer.purpose = purpose
        offer.requestedStart = start
        offer.requestedEnd = start.addingTimeInterval(duration)
        offer.price = wantsPrice ? price : nil
        offer.note = note.isEmpty ? nil : note
        Task {
            await offerStore.send(offer)
            isSending = false
            dismiss()
        }
    }
}

private struct DurationChip: View {
    let label: String
    var isSelected: Bool = false

    var body: some View {
        Text(label)
            .font(.shortyHeadline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(isSelected ? .white : DukeTheme.dukeBlue)
            .background(isSelected ? DukeTheme.dukeBlue : DukeTheme.dukeBlue.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: DukeTheme.controlCornerRadius, style: .continuous))
    }
}
