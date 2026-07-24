import CloudKit
import SwiftUI
import UIKit

/// Wraps UICloudSharingController so the room owner can invite their roommate
/// through Messages, Mail, or any other share sheet destination.
struct CloudSharingView: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer
    var onCompletion: (() -> Void)?

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.delegate = context.coordinator
        controller.availablePermissions = [.allowReadWrite]
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCompletion: onCompletion)
    }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let onCompletion: (() -> Void)?

        init(onCompletion: (() -> Void)?) {
            self.onCompletion = onCompletion
        }

        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {}

        func itemTitle(for csc: UICloudSharingController) -> String? {
            csc.share?[CKShare.SystemFieldKey.title] as? String
        }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            onCompletion?()
        }

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {}
    }
}
