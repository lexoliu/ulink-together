import SwiftUI

private enum RecordsFilter: String, CaseIterable, Identifiable {
    case all
    case joined
    case completed
    case cancelled

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .all:
            "All"
        case .joined:
            "Joined"
        case .completed:
            "Completed"
        case .cancelled:
            "Cancelled"
        }
    }
}

struct RecordsHomeView: View {
    @EnvironmentObject private var session: SessionStore

    @State private var records: [RecordEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var filter: RecordsFilter = .all

    var body: some View {
        PageWidthReader {
            summaryCard

            Picker("Filter", selection: $filter) {
                ForEach(RecordsFilter.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)

            if isLoading {
                LoadingCard(title: "Loading participation records")
            } else if filteredRecords.isEmpty {
                EmptyStateCard(
                    title: "No records yet",
                    message: "Your joined and completed volunteer work will appear here.",
                    systemImage: "clock.badge.questionmark"
                )
            } else {
                ForEach(filteredRecords) { record in
                    CardPanel {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(record.activityName ?? "Untitled activity")
                                        .font(.headline)
                                    Text(ServerDate.dateText(record.activityDate))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                StateChip(title: record.state.title, tint: AppTheme.stateTint(for: record.state))
                            }

                            HStack {
                                Label(DisplayText.duration(minutes: record.activityDuration ?? 0), systemImage: "clock")
                                Spacer()
                                Text("Confirmed \(DisplayText.hours(minutes: record.confirmedMinutes))")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if let errorMessage {
                InlineErrorBanner(message: errorMessage)
            }
        }
        .navigationTitle("Records")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await load()
        }
        .refreshable {
            await load()
        }
    }

    private var filteredRecords: [RecordEntry] {
        records.filter { record in
            switch filter {
            case .all:
                true
            case .joined:
                record.state == .todo
            case .completed:
                record.state == .done
            case .cancelled:
                record.state == .canceled
            }
        }
    }

    private var summaryCard: some View {
        let completedMinutes = records
            .filter { $0.state == .done }
            .reduce(into: 0) { partialResult, record in
                partialResult += record.confirmedMinutes
            }

        return CardPanel {
            VStack(alignment: .leading, spacing: 10) {
                Text("Volunteer Hours")
                    .font(.headline)
                Text(DisplayText.hours(minutes: completedMinutes))
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                Text("Confirmed school-report time across all completed activities.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func load() async {
        if let demoData = session.demoData {
            records = demoData.userRecords
            errorMessage = nil
            isLoading = false
            return
        }

        guard let serverURL = session.serverURL, let currentUser = session.currentUser else {
            errorMessage = "You must sign in before loading records."
            isLoading = false
            return
        }

        isLoading = true
        defer {
            isLoading = false
        }

        do {
            records = try await session.apiClient.fetchRecords(baseURL: serverURL, user: currentUser.id)
            errorMessage = nil
        } catch {
            errorMessage = session.readableError(error)
        }
    }
}

#Preview("Records") {
    NavigationStack {
        RecordsHomeView()
    }
    .environmentObject(SessionStore.previewVolunteer())
}
