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
        List {
            // MARK: - Hero stat
            Section {
                VStack(spacing: 6) {
                    Text(DisplayText.hours(minutes: overview.completedMinutes))
                        .font(.system(.largeTitle, design: .rounded).bold())
                    Text("Total Volunteer Hours")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 12)

                HStack(spacing: 0) {
                    statusCount("Pending", count: overview.pendingCount, tint: AppTheme.stateTint(for: .pendingApproval))
                    Divider().frame(height: 32)
                    statusCount("Approved", count: overview.approvedCount, tint: AppTheme.stateTint(for: .approved))
                    Divider().frame(height: 32)
                    statusCount("Confirmed", count: overview.confirmedCount, tint: AppTheme.stateTint(for: .confirmed))
                }
            }

            // MARK: - Filter
            Section {
                Picker("Filter", selection: $filter) {
                    ForEach(RecordsFilter.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            // MARK: - Records
            if isLoading {
                Section {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } else if filteredRecords.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Records",
                        systemImage: "clock.badge.questionmark",
                        description: Text("You have no participation records matching this filter.")
                    )
                }
            } else {
                Section {
                    ForEach(filteredRecords) { record in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.activityName ?? "Untitled activity")
                                    .font(.headline)
                                Text([ServerDate.dateText(record.activityDate), DisplayText.duration(minutes: record.activityDuration ?? 0)].joined(separator: " · "))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            VStack(alignment: .trailing, spacing: 4) {
                                StateChip(title: record.state.title, tint: AppTheme.stateTint(for: record.state))
                                if record.confirmedMinutes > 0 {
                                    Text(DisplayText.hours(minutes: record.confirmedMinutes))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 2)
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
        .navigationTitle("Records")
        .task {
            await load()
        }
        .refreshable {
            await load()
        }
    }

    private func statusCount(_ label: String, count: Int, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title3.bold())
                .foregroundStyle(tint)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
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

#Preview("Records", traits: .landscapeLeft) {
    NavigationStack {
        RecordsHomeView()
    }
    .environmentObject(SessionStore.previewVolunteer())
}
