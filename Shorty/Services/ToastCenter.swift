import Foundation

/// A tiny app-wide toast bus. Any view can call `show(_:)` to surface a one-line
/// confirmation (e.g. "Request sent") without needing to thread state through
/// whichever sheet happens to be presented at the time -- the banner is rendered once,
/// above the tab bar, in MainTabView.
@Observable
final class ToastCenter {
    var message: String?

    func show(_ message: String) {
        self.message = message
    }
}
