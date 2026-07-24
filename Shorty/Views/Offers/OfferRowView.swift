import SwiftUI

struct OfferRowView: View {
    let offer: RentalOffer
    let myName: String
    var onTap: (() -> Void)?

    var body: some View {
        Button {
            onTap?()
        } label: {
            ShortyCard {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: offer.purpose.icon)
                        .font(.title3)
                        .foregroundStyle(DukeTheme.dukeBlue)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(offer.fromName == myName ? "You → \(offer.toName)" : "\(offer.fromName) → You")
                            .font(.shortyHeadline)
                        Text(rangeText)
                            .font(.shortyCaption)
                            .foregroundStyle(DukeTheme.inkMuted)
                        if let price = offer.activePrice {
                            Text("$\(Int(price))")
                                .font(.shortyCaption)
                                .foregroundStyle(DukeTheme.dukeBlue)
                        }
                    }

                    Spacer()

                    StatusPill(status: offer.status)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var rangeText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return "\(formatter.string(from: offer.activeStart)) – \(DateFormatter.localizedString(from: offer.activeEnd, dateStyle: .none, timeStyle: .short))"
    }
}

struct StatusPill: View {
    let status: OfferStatus

    var body: some View {
        Text(text)
            .font(.shortyCaption)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(.white)
            .background(color)
            .clipShape(Capsule())
    }

    private var text: String {
        switch status {
        case .pending: return "Pending"
        case .accepted: return "Accepted"
        case .declined: return "Declined"
        case .countered: return "Countered"
        case .cancelled: return "Cancelled"
        case .completed: return "Completed"
        }
    }

    private var color: Color {
        switch status {
        case .pending, .countered: return DukeTheme.pending
        case .accepted, .completed: return DukeTheme.available
        case .declined, .cancelled: return DukeTheme.inkMuted
        }
    }
}
