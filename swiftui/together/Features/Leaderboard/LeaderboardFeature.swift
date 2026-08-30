import SwiftUI

struct LeaderboardHomeView: View {
    @EnvironmentObject private var session: SessionStore

    @State private var entries: [LeaderboardEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        List {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if entries.isEmpty {
                ContentUnavailableView(
                    "No Rankings",
                    systemImage: "trophy",
                    description: Text("Rankings will appear once volunteers log hours.")
                )
            } else {
                // MARK: - Podium
                if entries.count >= 3 {
                    Section {
                        podiumView
                            .listRowInsets(EdgeInsets(top: 16, leading: 0, bottom: 16, trailing: 0))
                            .listRowBackground(Color.clear)
                    }
                }

                // MARK: - Full rankings
                Section {
                    ForEach(entries) { entry in
                        let isCurrentUser = entry.id == session.currentUser?.id
                        RankingRow(
                            entry: entry,
                            avatarURL: session.serverURL.flatMap { session.apiClient.avatarURL(baseURL: $0, path: entry.avatar) }
                        )
                        .listRowBackground(isCurrentUser ? AppTheme.accentTint.opacity(0.08) : nil)
                    }
                }
            }

            if let errorMessage {
                Section {
                    InlineErrorBanner(message: errorMessage)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Leaderboard")
        .task {
            await load()
        }
        .refreshable {
            await load()
        }
    }

    private var podiumView: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if entries.count >= 2 {
                podiumPillar(entry: entries[1], rank: 2, height: 90, medal: Color(red: 0.60, green: 0.62, blue: 0.65))
            }
            if entries.count >= 1 {
                podiumPillar(entry: entries[0], rank: 1, height: 120, medal: Color(red: 0.85, green: 0.65, blue: 0.13))
            }
            if entries.count >= 3 {
                podiumPillar(entry: entries[2], rank: 3, height: 70, medal: Color(red: 0.72, green: 0.45, blue: 0.20))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func podiumPillar(entry: LeaderboardEntry, rank: Int, height: CGFloat, medal: Color) -> some View {
        VStack(spacing: 8) {
            AvatarBadge(
                title: entry.realname,
                imageURL: session.serverURL.flatMap { session.apiClient.avatarURL(baseURL: $0, path: entry.avatar) },
                size: rank == 1 ? 64 : 52
            )

            Text(entry.realname)
                .font(rank == 1 ? .headline : .subheadline.weight(.medium))
                .lineLimit(1)

            Text(DisplayText.hours(minutes: entry.totalMinutes))
                .font(.caption.weight(.semibold))
                .foregroundStyle(medal)

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(medal.opacity(0.15))
                .frame(height: height)
                .overlay(alignment: .top) {
                    Text("#\(rank)")
                        .font(.title3.bold())
                        .foregroundStyle(medal)
                        .padding(.top, 10)
                }
        }
        .frame(maxWidth: .infinity)
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

#Preview("Leaderboard", traits: .landscapeLeft) {
    NavigationStack {
        LeaderboardHomeView()
    }
    .environmentObject(SessionStore.previewVolunteer())
}
