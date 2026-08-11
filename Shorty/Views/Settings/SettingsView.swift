import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(ProfileStore.self) private var profileStore
    @Environment(SubscriptionStore.self) private var subscriptionStore
    @Environment(PaymentHandleStore.self) private var paymentHandleStore
    @Environment(ToastCenter.self) private var toastCenter

    @State private var showingLeaveConfirmation = false
    @State private var showingHowItWorks = false
    @State private var showingSubscription = false
    @State private var venmoUsername = ""
    @State private var cashtag = ""
    @State private var isSavingHandles = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Your Info") {
                    LabeledContent("Your name", value: profileStore.profile.myName)
                    LabeledContent("Roommate", value: profileStore.profile.roommateName ?? "—")
                }

                Section {
                    TextField("Venmo username (e.g. @yourname)", text: $venmoUsername)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Cash App $Cashtag (e.g. $yourname)", text: $cashtag)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button(isSavingHandles ? "Saving…" : "Save") {
                        saveHandles()
                    }
                    .disabled(isSavingHandles)
                } header: {
                    Text("Payment Handles")
                } footer: {
                    Text("Optional. Saving these lets your roommate's Venmo/Cash App buttons jump straight to you with the amount pre-filled, instead of searching for you by hand. Only visible to your roommate.")
                }

                Section("Appearance") {
                    Picker("Appearance", selection: appearanceModeBinding) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Button {
                        showingSubscription = true
                    } label: {
                        HStack {
                            Label("Shorty Plus", systemImage: "sparkles")
                            Spacer()
                            if subscriptionStore.isPlus {
                                Text("Subscribed")
                                    .font(.shortyCaption)
                                    .foregroundStyle(DukeTheme.available)
                            }
                        }
                    }
                }

                Section {
                    Button {
                        showingHowItWorks = true
                    } label: {
                        Label("How Shorty Works", systemImage: "questionmark.circle")
                    }
                    Button {
                        openNotificationSettings()
                    } label: {
                        Label("Notification Settings", systemImage: "bell")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showingLeaveConfirmation = true
                    } label: {
                        Label("Leave This Room", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } footer: {
                    Text(CloudKitManager.shared.isLocalPreview
                         ? "You're in local preview mode — nothing is synced yet. Leaving just resets this device."
                         : "This disconnects this device from the shared room. Your roommate keeps their own access.")
                }

                Section {
                    LabeledContent("Version", value: appVersion)
                }
            }
            .shortyBackground()
            .scrollContentBackground(.hidden)
            .shortyHeader("Settings")
            .confirmationDialog("Leave this room?", isPresented: $showingLeaveConfirmation, titleVisibility: .visible) {
                Button("Leave", role: .destructive) { leaveRoom() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll need to create a new room or accept a new invite to use Shorty again.")
            }
            .sheet(isPresented: $showingHowItWorks) {
                HowItWorksView()
            }
            .sheet(isPresented: $showingSubscription) {
                SubscriptionView()
            }
            .task {
                await paymentHandleStore.refresh()
                loadHandleFields()
            }
        }
    }

    private func loadHandleFields() {
        let handle = paymentHandleStore.handlesByName[profileStore.profile.myName] ?? .empty
        venmoUsername = handle.venmoUsername ?? ""
        cashtag = handle.cashtag ?? ""
    }

    private func saveHandles() {
        isSavingHandles = true
        let handle = PaymentHandle(
            venmoUsername: venmoUsername.trimmingCharacters(in: .whitespaces).isEmpty ? nil : venmoUsername.trimmingCharacters(in: .whitespaces),
            cashtag: cashtag.trimmingCharacters(in: .whitespaces).isEmpty ? nil : cashtag.trimmingCharacters(in: .whitespaces)
        )
        Task {
            await paymentHandleStore.save(name: profileStore.profile.myName, handle: handle)
            isSavingHandles = false
            Haptics.success()
            toastCenter.show("Payment handles saved")
        }
    }

    private var appearanceModeBinding: Binding<AppearanceMode> {
        Binding(
            get: { profileStore.profile.appearanceMode },
            set: { profileStore.profile.appearanceMode = $0 }
        )
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private func openNotificationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func leaveRoom() {
        CloudKitManager.shared.forgetRoom()
        profileStore.reset()
    }
}
