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
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Room", systemImage: "door.left.hand.closed") }

            OffersListView()
                .tabItem { Label("Room Time", systemImage: "envelope") }

            ScheduleView()
                .tabItem { Label("Schedule", systemImage: "calendar") }
        }
        .tint(DukeTheme.dukeBlue)
    }
}
