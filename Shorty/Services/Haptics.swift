import UIKit

/// Centralized haptic feedback so the moments that matter -- sending a request, getting
/// a yes or no, picking an option -- feel physically confirmed, not just visually.
enum Haptics {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
