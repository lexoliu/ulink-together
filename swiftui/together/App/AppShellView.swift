import SwiftUI

struct AppShellView: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        TabView {
            FeedHomeView()
                .tabItem {
                    Label("Feed", systemImage: "square.grid.2x2.fill")
                }

            NavigationStack {
                RecordsHomeView()
            }
            .tabItem {
                Label("Records", systemImage: "clock.badge.checkmark.fill")
            }

            if session.showsManageTab {
                NavigationStack {
                    OrganiserHomeView()
                }
                .tabItem {
                    Label("Manage", systemImage: "slider.horizontal.3")
                }
            }

            NavigationStack {
                LeaderboardHomeView()
            }
            .tabItem {
                Label("Leaderboard", systemImage: "trophy.fill")
            }

            NavigationStack {
                AccountHomeView()
            }
            .tabItem {
                Label("Account", systemImage: "person.crop.circle.fill")
            }
        }
        .tint(.blue)
    }
}
