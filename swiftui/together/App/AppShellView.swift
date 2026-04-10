import SwiftUI

private enum AppDestination: Hashable {
    case feed
    case records
    case notifications
    case manage
    case leaderboard
    case account
}

struct AppShellView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var selection: AppDestination = .feed

    var body: some View {
        Group {
            if #available(iOS 18, *) {
                configuredTabs
                    .tabViewStyle(.sidebarAdaptable)
            } else {
                configuredTabs
            }
        }
        .tint(AppTheme.accentTint)
    }

    private var configuredTabs: some View {
        TabView(selection: $selection) {
            Tab("Explore", systemImage: "square.grid.2x2.fill", value: .feed) {
                FeedHomeView()
            }

            Tab("Records", systemImage: "clock.badge.checkmark.fill", value: .records) {
                NavigationStack {
                    RecordsHomeView()
                }
            }

            Tab("Notifications", systemImage: "bell.fill", value: .notifications) {
                NavigationStack {
                    NotificationsHomeView()
                }
            }
            .badge(session.unreadNotificationCount)

            if session.showsManageTab {
                Tab("Manage", systemImage: "slider.horizontal.3", value: .manage) {
                    NavigationStack {
                        OrganiserHomeView()
                    }
                }
            }

            Tab("Leaderboard", systemImage: "trophy.fill", value: .leaderboard) {
                NavigationStack {
                    LeaderboardHomeView()
                }
            }

            Tab("Account", systemImage: "person.crop.circle.fill", value: .account) {
                NavigationStack {
                    AccountHomeView()
                }
            }
        }
    }
}
