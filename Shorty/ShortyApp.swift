import CloudKit
import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private static let acceptActionID = "ACCEPT_OFFER"
    private static let declineActionID = "DECLINE_OFFER"

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        registerOfferNotificationCategory()
        application.registerForRemoteNotifications()
        return true
    }

    /// Called automatically when the roommate taps the invite link and accepts the share.
    func application(_ application: UIApplication, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        Task {
            try? await CloudKitManager.shared.acceptShare(metadata: cloudKitShareMetadata)
            NotificationCenter.default.post(name: .shortyDidAcceptShare, object: nil)
        }
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        completionHandler(.noData)
    }

    private func registerOfferNotificationCategory() {
        let accept = UNNotificationAction(identifier: Self.acceptActionID, title: "Accept", options: [])
        let decline = UNNotificationAction(identifier: Self.declineActionID, title: "Decline", options: [.destructive])
        let category = UNNotificationCategory(identifier: "OFFER_REQUEST", actions: [accept, decline], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    /// Lets the "New room time request" banner still show while the app is open, not just
    /// when it's backgrounded (the default UNUserNotificationCenterDelegate behavior
    /// otherwise swallows foreground notifications silently).
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }

    /// Handles a tap on the Accept/Decline action right on the push notification -- runs
    /// with no view hierarchy guaranteed to exist, so it talks to CloudKit directly.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        guard response.actionIdentifier == Self.acceptActionID || response.actionIdentifier == Self.declineActionID,
              let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) as? CKQueryNotification,
              let recordID = notification.recordID else {
            completionHandler()
            return
        }
        let accept = response.actionIdentifier == Self.acceptActionID
        Task {
            try? await CloudKitManager.shared.respondToOffer(recordID: recordID, accept: accept)
            NotificationCenter.default.post(name: .shortyOfferRespondedViaPush, object: nil)
            completionHandler()
        }
    }
}

extension Notification.Name {
    static let shortyDidAcceptShare = Notification.Name("shortyDidAcceptShare")
    static let shortyOfferRespondedViaPush = Notification.Name("shortyOfferRespondedViaPush")
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
