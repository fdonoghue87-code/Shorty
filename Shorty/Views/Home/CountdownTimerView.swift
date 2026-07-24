import SwiftUI

/// A live countdown to `endDate`, ticking every second so both roommates stay in sync
/// on exactly when a session ends.
struct CountdownTimerView: View {
    let endDate: Date
    var tint: Color = .white

    @State private var now = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(remainingString)
            .font(.system(.title, design: .rounded).monospacedDigit().weight(.bold))
            .foregroundStyle(tint)
            .onReceive(timer) { now = $0 }
    }

    private var remainingString: String {
        let remaining = max(0, endDate.timeIntervalSince(now))
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        let seconds = Int(remaining) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
