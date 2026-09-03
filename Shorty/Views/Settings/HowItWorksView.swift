import SwiftUI

/// Shown once automatically right after onboarding, and reachable anytime from Settings.
struct HowItWorksView: View {
    @Environment(\.dismiss) private var dismiss

    private struct Item {
        let icon: String
        let title: String
        let body: String
    }

    private let items: [Item] = [
        Item(icon: "bolt.fill", title: "Quick Request", body: "Tap a duration on the Room tab to ask for the room right now — one tap, no form."),
        Item(icon: "repeat", title: "Standing Arrangements", body: "Propose a recurring time slot in the Schedule tab. Once your roommate approves it, it repeats automatically — you never have to ask again."),
        Item(icon: "lock.fill", title: "Personal Time", body: "Don't want to say why? Pick \"Personal Time\" as the purpose instead of one of the specific reasons."),
        Item(icon: "arrow.left.arrow.right", title: "Negotiating", body: "Any request can be accepted, declined, or countered with different terms — including quick +15 min / +1 hour adjustments instead of retyping everything."),
        Item(icon: "square.and.arrow.down", title: "Schedule Import", body: "Pull your schedule in from your phone's calendar (Google, Outlook, iCloud) or snap a photo of a printed one on the Schedule tab — you always review before it saves."),
    ]

    var body: some View {
        NavigationStack {
            List(items, id: \.title) { item in
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: item.icon)
                        .font(.title3)
                        .foregroundStyle(DukeTheme.dukeBlue)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title).font(.shortyHeadline)
                        Text(item.body).font(.shortyCaption).foregroundStyle(DukeTheme.inkMuted)
                    }
                }
                .padding(.vertical, 4)
            }
            .listStyle(.plain)
            .shortyBackground()
            .scrollContentBackground(.hidden)
            .navigationTitle("How Shorty Works")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
