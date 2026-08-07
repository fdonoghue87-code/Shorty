import CloudKit
import SwiftUI

final class AppDelegate: NSObject, UIApplicationDelegate {
    /// Called automatically when the roommate taps the invite link and accepts the share.
    func application(_ application: UIApplication, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        Task {
            try? await CloudKitManager.shared.acceptShare(metadata: cloudKitShareMetadata)
            NotificationCenter.default.post(name: .shortyDidAcceptShare, object: nil)
        }
    }
}

extension Notification.Name {
    static let shortyDidAcceptShare = Notification.Name("shortyDidAcceptShare")
}

@main
struct ShortyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var profileStore = ProfileStore()
    @State private var offerStore = OfferStore()
    @State private var scheduleStore = ScheduleStore()
    @State private var standingStore = StandingArrangementStore()
    @State private var subscriptionStore = SubscriptionStore()
    @State private var toastCenter = ToastCenter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(profileStore)
                .environment(offerStore)
                .environment(scheduleStore)
                .environment(standingStore)
                .environment(subscriptionStore)
                .environment(toastCenter)
                .tint(DukeTheme.dukeBlue)
                .preferredColorScheme(profileStore.profile.appearanceMode.colorScheme)
                .task {
                    NotificationService.requestAuthorizationIfNeeded()
                }
        }
    }
}
