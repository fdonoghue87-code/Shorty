import SwiftUI

struct PurposeChip: View {
    let purpose: Purpose
    var isSelected: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: purpose.icon)
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
            Text(purpose.label)
                .font(.shortyCaption)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .foregroundStyle(isSelected ? .white : DukeTheme.dukeBlue)
        .shortyChip(RoundedRectangle(cornerRadius: DukeTheme.controlCornerRadius, style: .continuous), isSelected: isSelected)
    }
}

struct PurposeBadge: View {
    let purpose: Purpose

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: purpose.icon)
                .symbolRenderingMode(.hierarchical)
            Text(purpose.label)
        }
        .font(.shortyCaption)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }
}
