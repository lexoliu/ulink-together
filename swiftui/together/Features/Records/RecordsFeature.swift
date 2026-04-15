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
    case upcoming
    case completed
    case all

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .upcoming:
            "Upcoming"
        case .completed:
            "Completed"
        case .all:
            "All"
        }
    }
}

/// Human-friendly copy for each record state, tuned for students looking at
/// their own participation history rather than an administrator looking at a
/// raw database field.
private struct RecordStatusPresentation {
    let label: String
    let detail: String
    let systemImage: String
    let tint: Color
}

private func recordStatusPresentation(for state: RecordState) -> RecordStatusPresentation {
    switch state {
    case .pendingApproval:
        RecordStatusPresentation(
            label: "Awaiting approval",
            detail: "A teacher will review your application shortly.",
            systemImage: "hourglass",
            tint: AppTheme.stateTint(for: RecordState.pendingApproval)
        )
    case .approved:
        RecordStatusPresentation(
            label: "You're in",
            detail: "You've been approved. Show up and take part.",
            systemImage: "checkmark.seal.fill",
            tint: AppTheme.stateTint(for: RecordState.approved)
        )
    case .confirmed:
        RecordStatusPresentation(
            label: "Hours confirmed",
            detail: "Your service hours have been added to your record.",
            systemImage: "clock.badge.checkmark.fill",
            tint: AppTheme.stateTint(for: RecordState.confirmed)
        )
    case .canceled:
        RecordStatusPresentation(
            label: "Cancelled",
            detail: "This participation was withdrawn or rejected.",
            systemImage: "xmark.circle.fill",
            tint: AppTheme.stateTint(for: RecordState.canceled)
        )
    }
}

struct RecordsHomeView: View {
    @EnvironmentObject private var session: SessionStore

    @State private var records: [RecordEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var filter: RecordsFilter = .upcoming

    var body: some View {
        List {
            // MARK: - Hero stat
            Section {
                VStack(spacing: 6) {
                    Text(DisplayText.hours(minutes: overview.completedMinutes))
                        .font(.system(.largeTitle, design: .rounded).bold())
                    Text("Total confirmed hours")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 12)

                HStack(spacing: 0) {
                    statusCount("Awaiting", count: overview.pendingCount, tint: AppTheme.stateTint(for: .pendingApproval))
                    Divider().frame(height: 32)
                    statusCount("Approved", count: overview.approvedCount, tint: AppTheme.stateTint(for: .approved))
                    Divider().frame(height: 32)
                    statusCount("Confirmed", count: overview.confirmedCount, tint: AppTheme.stateTint(for: .confirmed))
                }
            } footer: {
                Text("Every activity you have applied to lives here. Tap a row to see the details and current progress.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
                        emptyStateTitle,
                        systemImage: "clock.badge.questionmark",
                        description: Text(emptyStateMessage)
                    )
                }
            } else {
                Section(filter.title) {
                    ForEach(filteredRecords) { record in
                        NavigationLink(value: record.activity) {
                            RecordRow(record: record)
                        }
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
        .navigationTitle("My Activities")
        .navigationDestination(for: String.self) { activityID in
            ActivityDetailView(activityID: activityID)
        }
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
            case .upcoming:
                record.state == .pendingApproval || record.state == .approved
            case .completed:
                record.state == .confirmed
            case .all:
                true
            }
        }
    }

    private var emptyStateTitle: String {
        switch filter {
        case .upcoming:
            "Nothing upcoming"
        case .completed:
            "No completed hours yet"
        case .all:
            "No activities yet"
        }
    }

    private var emptyStateMessage: String {
        switch filter {
        case .upcoming:
            "Activities you apply to from Explore will appear here while you wait for approval or attend."
        case .completed:
            "Once a teacher confirms your service hours they will show up in this list."
        case .all:
            "Go to Explore to find something to sign up for."
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

/// Non-interactive status indicator for the Records list. Uses an SF Symbol
/// on a filled pastille so it reads as a label, not as a toggle. The row as a
/// whole is wrapped in a `NavigationLink` by the parent, so there is no risk
/// of this element eating a tap.
private struct RecordStatusBadge: View {
    let presentation: RecordStatusPresentation

    var body: some View {
        Label {
            Text(presentation.label)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        } icon: {
            Image(systemName: presentation.systemImage)
                .font(.caption.weight(.bold))
        }
        .labelStyle(.titleAndIcon)
        .foregroundStyle(presentation.tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(presentation.tint.opacity(0.12), in: Capsule(style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status: \(presentation.label)")
    }
}

private struct RecordRow: View {
    let record: RecordEntry

    var body: some View {
        let presentation = recordStatusPresentation(for: record.state)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.activityName ?? "Untitled activity")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(metadataLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
                RecordStatusBadge(presentation: presentation)
            }

            Text(presentation.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if record.confirmedMinutes > 0 {
                Label(DisplayText.hours(minutes: record.confirmedMinutes), systemImage: "clock.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(presentation.tint)
            }
        }
        .padding(.vertical, 4)
    }

    private var metadataLine: String {
        let date = ServerDate.dateText(record.activityDate)
        let duration = DisplayText.duration(minutes: record.activityDuration ?? 0)
        return [date, duration].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

#Preview("Records", traits: .landscapeLeft) {
    NavigationStack {
        RecordsHomeView()
    }
    .environmentObject(SessionStore.previewVolunteer())
}
