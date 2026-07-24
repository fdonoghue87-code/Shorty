import SwiftUI

struct PrimaryButton: View {
    var title: String
    var systemImage: String?
    var isDestructive: Bool = false
    var isLoading: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().tint(.white)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .font(.shortyHeadline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(isDestructive ? DukeTheme.occupied : DukeTheme.dukeBlue)
            .clipShape(RoundedRectangle(cornerRadius: DukeTheme.controlCornerRadius, style: .continuous))
        }
        .disabled(isLoading)
    }
}

struct SecondaryButton: View {
    var title: String
    var systemImage: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title).font(.shortyHeadline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(DukeTheme.dukeBlue)
            .background(DukeTheme.dukeBlue.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: DukeTheme.controlCornerRadius, style: .continuous))
        }
    }
}
