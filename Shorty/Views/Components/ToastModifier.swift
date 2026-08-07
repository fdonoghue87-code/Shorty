import SwiftUI

private struct ToastModifier: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let message {
                    Text(message)
                        .font(.shortyHeadline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(DukeTheme.dukeBlue, in: Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .task(id: message) {
                            try? await Task.sleep(nanoseconds: 1_600_000_000)
                            if self.message == message {
                                withAnimation { self.message = nil }
                            }
                        }
                }
            }
            .animation(.spring(duration: 0.35), value: message)
    }
}

extension View {
    /// Shows a small banner at the top of this view whenever `message` is non-nil,
    /// then auto-dismisses it after a couple seconds -- used to confirm actions
    /// (offer sent, accepted, etc.) without blocking with a full alert.
    func shortyToast(_ message: Binding<String?>) -> some View {
        modifier(ToastModifier(message: message))
    }
}
