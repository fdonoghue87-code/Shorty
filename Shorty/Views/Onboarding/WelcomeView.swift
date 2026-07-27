import CloudKit
import SwiftUI
import UIKit

/// First-run screen. Handles both roles: the roommate who creates the room and
/// invites the other, and the roommate who opens the invite link and just needs
/// to introduce themselves once CloudKit has already connected their device.
struct WelcomeView: View {
    @Environment(ProfileStore.self) private var profileStore

    @State private var myName = ""
    @State private var roommateName = ""
    @State private var roomName = "Our Room"
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var pendingShare: CKShareBox?
    @State private var showingSystemShareSheet = false
    @State private var didCopyLink = false
    @State private var cloudIsReady = CloudKitManager.shared.isReady

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    Image(systemName: "door.left.hand.closed")
                        .font(.system(size: 44))
                        .foregroundStyle(DukeTheme.dukeBlue)
                    Text("Shorty")
                        .font(.shortyLargeTitle)
                        .foregroundStyle(DukeTheme.dukeBlue)
                    Text(cloudIsReady
                         ? "You're connected. Just need your names."
                         : "Get the room to yourself for a while, minus the awkward ask.")
                        .font(.shortyBody)
                        .foregroundStyle(DukeTheme.inkMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)

                ShortyCard {
                    VStack(alignment: .leading, spacing: 14) {
                        LabeledField(label: "Your name", text: $myName, placeholder: "e.g. Frank")
                        LabeledField(label: "Roommate's name", text: $roommateName, placeholder: "e.g. Sam")
                        if !cloudIsReady {
                            LabeledField(label: "Nickname for your room", text: $roomName, placeholder: "e.g. Room 214")
                        }
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.shortyCaption)
                        .foregroundStyle(DukeTheme.occupied)
                }

                if let box = pendingShare {
                    inviteReadyCard(box)
                } else if cloudIsReady {
                    PrimaryButton(title: "Continue", systemImage: "checkmark") {
                        profileStore.completeOnboarding(myName: myName, roommateName: roommateName)
                    }
                    .disabled(!canContinue)
                    .opacity(canContinue ? 1 : 0.5)
                } else {
                    PrimaryButton(title: "Create Room & Invite", systemImage: "person.badge.plus", isLoading: isCreating) {
                        createAndShare()
                    }
                    .disabled(!canCreate)
                    .opacity(canCreate ? 1 : 0.5)

                    Text("You'll get a link to send \(roommateName.isEmpty ? "your roommate" : roommateName). Already got a link from them instead? Just open it — you'll land right back here, connected.")
                        .font(.shortyCaption)
                        .foregroundStyle(DukeTheme.inkMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)

                    SecondaryButton(title: "Just Explore (No iCloud Needed)", systemImage: "eye") {
                        exploreLocally()
                    }
                    .disabled(myName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(myName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)

                    Text("Click around solo on this device — nothing syncs, and it resets if you relaunch. Good for previewing the app before your CloudKit setup is ready.")
                        .font(.shortyCaption)
                        .foregroundStyle(DukeTheme.inkMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
            }
            .padding(20)
        }
        .shortyBackground()
        .sheet(isPresented: $showingSystemShareSheet) {
            if let box = pendingShare {
                CloudSharingView(share: box.share, container: box.container) {}
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .shortyDidAcceptShare)) { _ in
            cloudIsReady = true
        }
    }

    private var canContinue: Bool {
        !myName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !roommateName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var canCreate: Bool { canContinue && !roomName.trimmingCharacters(in: .whitespaces).isEmpty }

    private func createAndShare() {
        isCreating = true
        errorMessage = nil
        Task {
            do {
                let result = try await CloudKitManager.shared.createRoomAndShare(roomName: roomName)
                pendingShare = CKShareBox(share: result.share, container: result.container)
            } catch {
                errorMessage = "Couldn't create the room: \(error.localizedDescription)"
            }
            isCreating = false
        }
    }

    @ViewBuilder
    private func inviteReadyCard(_ box: CKShareBox) -> some View {
        VStack(spacing: 14) {
            ShortyCard {
                Text("Room created 🎉")
                    .font(.shortyHeadline)
                Text("Send this link to \(roommateName.isEmpty ? "your roommate" : roommateName) however's easiest — text, AirDrop, email, anything.")
                    .font(.shortyCaption)
                    .foregroundStyle(DukeTheme.inkMuted)
                if let url = box.share.url {
                    Text(url.absoluteString)
                        .font(.shortyCaption)
                        .foregroundStyle(DukeTheme.dukeBlue)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            PrimaryButton(title: didCopyLink ? "Copied!" : "Copy Invite Link", systemImage: didCopyLink ? "checkmark" : "doc.on.doc") {
                copyLink(box)
            }

            SecondaryButton(title: "Share via Messages, Mail…", systemImage: "square.and.arrow.up") {
                showingSystemShareSheet = true
            }

            Text("On the Simulator, Messages/Mail/AirDrop don't actually send — Copy Invite Link and paste it wherever the other device can open it (Notes, Safari, etc.). On a real device, either option works normally.")
                .font(.shortyCaption)
                .foregroundStyle(DukeTheme.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            PrimaryButton(title: "I've Sent It — Continue", systemImage: "checkmark") {
                profileStore.completeOnboarding(myName: myName, roommateName: roommateName)
            }
        }
    }

    private func copyLink(_ box: CKShareBox) {
        guard let url = box.share.url else {
            errorMessage = "The link isn't ready quite yet — wait a second and try again."
            return
        }
        UIPasteboard.general.string = url.absoluteString
        didCopyLink = true
        errorMessage = nil
    }

    private func exploreLocally() {
        CloudKitManager.shared.enableLocalPreview()
        let name = myName.trimmingCharacters(in: .whitespaces)
        let roommate = roommateName.trimmingCharacters(in: .whitespaces)
        profileStore.completeOnboarding(myName: name, roommateName: roommate.isEmpty ? "Sample Roommate" : roommate)
    }
}

private struct LabeledField: View {
    let label: String
    @Binding var text: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.shortyCaption).foregroundStyle(DukeTheme.inkMuted)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(DukeTheme.paper)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

/// Identifiable wrapper so `.sheet(item:)` can present the CKShare + container together.
private struct CKShareBox: Identifiable {
    let id = UUID()
    let share: CKShare
    let container: CKContainer
}
