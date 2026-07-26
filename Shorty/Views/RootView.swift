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
    @State private var showingHowItWorks = false

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Room", systemImage: "door.left.hand.closed") }

            OffersListView()
                .tabItem { Label("Room Time", systemImage: "envelope") }

            ScheduleView()
                .tabItem { Label("Schedule", systemImage: "calendar") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(DukeTheme.dukeBlue)
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
}
