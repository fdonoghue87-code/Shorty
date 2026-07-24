import SwiftUI

struct RoomStatusCard: View {
    let status: RoomStatus
    let myName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Circle()
                    .fill(status.isOccupied ? DukeTheme.occupied : DukeTheme.available)
                    .frame(width: 10, height: 10)
                Text(status.isOccupied ? "Occupied" : "Available")
                    .font(.shortyHeadline)
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                if let purpose = status.purpose {
                    PurposeBadge(purpose: purpose)
                        .background(.white.opacity(0.15))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }

            if status.isOccupied, let occupant = status.occupantName, let end = status.sessionEnd {
                Text(occupant == myName ? "You have the room" : "\(occupant) has the room")
                    .font(.shortyLargeTitle)
                    .foregroundStyle(.white)
                HStack {
                    Text("Time left")
                        .font(.shortyBody)
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    CountdownTimerView(endDate: end)
                }
            } else {
                Text("The room is free")
                    .font(.shortyLargeTitle)
                    .foregroundStyle(.white)
                Text("Send an offer to claim it for yourself.")
                    .font(.shortyBody)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: status.isOccupied
                    ? [DukeTheme.occupied, DukeTheme.occupied.opacity(0.85)]
                    : [DukeTheme.dukeBlue, DukeTheme.dukeBlueDeep],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: DukeTheme.cardCornerRadius, style: .continuous))
    }
}
