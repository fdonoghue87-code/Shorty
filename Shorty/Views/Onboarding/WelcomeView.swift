import CloudKit
import SwiftUI

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
                         : "Rent the room from your roommate, minus the awkward ask.")
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

                if cloudIsReady {
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

                    Text("You'll get a share sheet to send \(roommateName.isEmpty ? "your roommate" : roommateName) a link over Messages. Already got a link from them instead? Just open it — you'll land right back here, connected.")
                        .font(.shortyCaption)
                        .foregroundStyle(DukeTheme.inkMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
            }
            .padding(20)
        }
        .shortyBackground()
        .sheet(item: $pendingShare) { box in
            CloudSharingView(share: box.share, container: box.container) {
                profileStore.completeOnboarding(myName: myName, roommateName: roommateName)
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
