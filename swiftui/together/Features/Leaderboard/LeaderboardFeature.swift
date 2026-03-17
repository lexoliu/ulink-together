import SwiftUI

struct LeaderboardHomeView: View {
    @EnvironmentObject private var session: SessionStore

    @State private var entries: [LeaderboardEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        PageWidthReader {
            CardPanel {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Leaderboard")
                        .font(.title3.weight(.semibold))
                    Text("Confirmed volunteer hours ranked across the current school dataset.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if isLoading {
                LoadingCard(title: "Loading rankings")
            } else if entries.isEmpty {
                EmptyStateCard(
                    title: "No rankings yet",
                    message: "The leaderboard will populate when confirmed records exist.",
                    systemImage: "trophy"
                )
            } else {
                CardPanel {
                    VStack(spacing: 0) {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                            RankingRow(
                                entry: entry,
                                avatarURL: session.serverURL.flatMap { session.apiClient.avatarURL(baseURL: $0, path: entry.avatar) }
                            )
                            .padding(.vertical, 10)

                            if index < entries.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }

            if let errorMessage {
                InlineErrorBanner(message: errorMessage)
            }
        }
        .navigationTitle("Leaderboard")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await load()
        }
        .refreshable {
            await load()
        }
    }

    private func load() async {
        if let demoData = session.demoData {
            entries = demoData.leaderboard
            errorMessage = nil
            isLoading = false
            return
        }

        guard let serverURL = session.serverURL else {
            isLoading = false
            errorMessage = "Enter a valid service address."
            return
        }

        isLoading = true
        defer {
            isLoading = false
        }

        do {
            entries = try await session.apiClient.fetchLeaderboard(baseURL: serverURL)
            errorMessage = nil
        } catch {
            errorMessage = session.readableError(error)
        }
    }
}

#Preview("Leaderboard") {
    NavigationStack {
        LeaderboardHomeView()
    }
    .environmentObject(SessionStore.previewVolunteer())
}
