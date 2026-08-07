import SwiftUI

struct RootView: View {
    @Environment(ProfileStore.self) private var profileStore

    var body: some View {
        Group {
            if profileStore.profile.isPaired {
                MainTabView()
            } else {
                WelcomeView()
            }
        }
        .animation(.default, value: profileStore.profile.isPaired)
    }
}

struct MainTabView: View {
    @Environment(ProfileStore.self) private var profileStore
    @Environment(OfferStore.self) private var offerStore
    @Environment(ToastCenter.self) private var toastCenter
    @State private var showingHowItWorks = false

    var body: some View {
        @Bindable var toastCenter = toastCenter
        TabView {
            HomeView()
                .tabItem { Label("Room", systemImage: "door.left.hand.closed") }

            OffersListView()
                .tabItem { Label("Room Time", systemImage: "envelope") }
                .badge(pendingIncomingCount)

            ScheduleView()
                .tabItem { Label("Schedule", systemImage: "calendar") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(DukeTheme.dukeBlue)
        .shortyToast($toastCenter.message)
        .task {
            if !profileStore.profile.hasSeenHowItWorks {
                showingHowItWorks = true
            }
        }
        .sheet(isPresented: $showingHowItWorks, onDismiss: {
            profileStore.profile.hasSeenHowItWorks = true
        }) {
            HowItWorksView()
        }
    }

    /// Offers your roommate sent that are waiting on you specifically -- the same set
    /// the Room Time tab's "Incoming" section shows -- surfaced as a tab badge so a
    /// pending ask doesn't get missed just because the tab wasn't opened.
    private var pendingIncomingCount: Int {
        offerStore.needsMyResponse.filter { $0.fromName != profileStore.profile.myName }.count
    }
}
