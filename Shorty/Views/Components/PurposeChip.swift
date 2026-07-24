import SwiftUI

struct PurposeChip: View {
    let purpose: Purpose
    var isSelected: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: purpose.icon)
                .font(.title3)
            Text(purpose.label)
                .font(.shortyCaption)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .foregroundStyle(isSelected ? .white : DukeTheme.dukeBlue)
        .background(isSelected ? DukeTheme.dukeBlue : DukeTheme.dukeBlue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DukeTheme.controlCornerRadius, style: .continuous))
    }
}

struct PurposeBadge: View {
    let purpose: Purpose

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: purpose.icon)
            Text(purpose.label)
        }
        .font(.shortyCaption)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .foregroundStyle(DukeTheme.dukeBlue)
        .background(DukeTheme.dukeBlue.opacity(0.1))
        .clipShape(Capsule())
    }
}
