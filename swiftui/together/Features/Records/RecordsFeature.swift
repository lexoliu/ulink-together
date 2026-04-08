import SwiftUI

struct RecordsOverview: Equatable {
    let pendingCount: Int
    let approvedCount: Int
    let confirmedCount: Int
    let completedMinutes: Int

    init(records: [RecordEntry]) {
        pendingCount = records.filter { $0.state == .pendingApproval }.count
        approvedCount = records.filter { $0.state == .approved }.count
        confirmedCount = records.filter { $0.state == .confirmed }.count
        completedMinutes = records
            .filter { $0.state == .confirmed }
            .reduce(into: 0) { partialResult, record in
                partialResult += record.confirmedMinutes
            }
    }
}

private enum RecordsFilter: String, CaseIterable, Identifiable {
    case all
    case pendingApproval
    case approved
    case confirmed
    case cancelled

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .all:
            "All"
        case .pendingApproval:
            "Pending"
        case .approved:
            "Approved"
        case .confirmed:
            "Confirmed"
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
            statusOverview

            Picker("Filter", selection: $filter) {
                ForEach(RecordsFilter.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)

            if isLoading {
                ComposedStateCard(
                    title: "Loading participation records",
                    systemImage: "clock.badge.checkmark",
                    minHeight: 220
                )
            } else if filteredRecords.isEmpty {
                ComposedStateCard(
                    title: "No records yet",
                    systemImage: "clock.badge.questionmark",
                    minHeight: 220
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
            case .pendingApproval:
                record.state == .pendingApproval
            case .approved:
                record.state == .approved
            case .confirmed:
                record.state == .confirmed
            case .cancelled:
                record.state == .canceled
            }
        }
    }

    private var overview: RecordsOverview {
        RecordsOverview(records: records)
    }

    private var summaryCard: some View {
        return CardPanel {
            HStack(alignment: .top, spacing: 18) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.accentTint.opacity(0.12))
                    .frame(width: 58, height: 58)
                    .overlay {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(AppTheme.accentTint)
                    }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Volunteer Hours")
                        .font(.headline)
                    Text(DisplayText.hours(minutes: overview.completedMinutes))
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var statusOverview: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 14)], spacing: 14) {
            InsightMetricTile(
                eyebrow: "Pending",
                value: "\(overview.pendingCount)"
            )
            InsightMetricTile(
                eyebrow: "Approved",
                value: "\(overview.approvedCount)"
            )
            InsightMetricTile(
                eyebrow: "Confirmed",
                value: "\(overview.confirmedCount)"
            )
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
