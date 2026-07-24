import SwiftUI

struct SectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.shortyTitle)
                .foregroundStyle(DukeTheme.ink)
            if let subtitle {
                Text(subtitle)
                    .font(.shortyCaption)
                    .foregroundStyle(DukeTheme.inkMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 32))
                .foregroundStyle(DukeTheme.dukeBlueLight)
            Text(title).font(.shortyHeadline)
            Text(message)
                .font(.shortyCaption)
                .foregroundStyle(DukeTheme.inkMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}
