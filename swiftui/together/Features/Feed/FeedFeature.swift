import SwiftUI

private enum FeedFilter: String, CaseIterable, Identifiable {
    case openForSignup
    case notYetApplied

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .openForSignup:
            "Open for sign up"
        case .notYetApplied:
            "New to me"
        }
    }
}

struct FeedHomeView: View {
    @EnvironmentObject private var session: SessionStore

    @State private var activities: [ActivitySummary] = []
    @State private var selectedActivityID: String?
    @State private var searchText = ""
    @State private var filter: FeedFilter = .openForSignup
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedActivityID) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowSeparator(.hidden)
                } else if filteredActivities.isEmpty {
                    ContentUnavailableView(
                        "No Activities",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("Nothing matches the current filter.")
                    )
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(filteredActivities) { activity in
                        ActivityListRow(activity: activity)
                            .tag(activity.id)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Feed")
            .searchable(text: $searchText, prompt: "Search activities")
            .refreshable {
                await loadFeed()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Filter", selection: $filter) {
                            ForEach(FeedFilter.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }
                    } label: {
                        Label(filter.title, systemImage: "line.3.horizontal.decrease.circle")
                            .symbolVariant(.fill)
                    }
                }
            }
        } detail: {
            if let resolvedSelectedActivityID {
                NavigationStack {
                    ActivityDetailView(activityID: resolvedSelectedActivityID)
                }
            } else {
                ContentUnavailableView(
                    "Select an Activity",
                    systemImage: "rectangle.and.text.magnifyingglass",
                    description: Text("Choose an activity from the list to view its details.")
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
        .task {
            await loadFeed()
        }
        .alert("Unable to Load Feed", isPresented: Binding(get: {
            errorMessage != nil
        }, set: { presented in
            if !presented {
                errorMessage = nil
            }
        })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var resolvedSelectedActivityID: String? {
        selectedActivityID ?? filteredActivities.first?.id ?? activities.first?.id
    }

    private var filteredActivities: [ActivitySummary] {
        activities.filter { activity in
            let matchesSearch = searchText.isEmpty
                || activity.name.localizedCaseInsensitiveContains(searchText)
                || activity.location.localizedCaseInsensitiveContains(searchText)
                || activity.briefDescription.localizedCaseInsensitiveContains(searchText)

            let matchesFilter: Bool = switch filter {
            case .openForSignup:
                // The server only returns activities in the `need_volunteer` state
                // when `display_all` is not set, so every row in `activities` is
                // open for sign up; this filter is here for labeling consistency.
                true
            case .notYetApplied:
                activity.viewerRecordState == nil
            }

            return matchesSearch && matchesFilter
        }
    }

    private func loadFeed() async {
        if let demoData = session.demoData {
            activities = demoData.feedActivities
            selectedActivityID = selectedActivityID ?? demoData.feedActivities.first?.id
            errorMessage = nil
            isLoading = false
            return
        }

        guard let serverURL = session.serverURL else {
            errorMessage = "Enter a valid service address."
            isLoading = false
            return
        }

        isLoading = true
        defer {
            isLoading = false
        }

        do {
            // Explore is the public recruiting feed. We must not pass
            // `displayAll: true` because the backend scopes that to the viewer's
            // own promoted activities for non-admin users, which would hide
            // everything from students. With `displayAll: false` the backend
            // returns every activity currently in the `need_volunteer` state.
            let loaded = try await session.apiClient.fetchActivities(baseURL: serverURL, displayAll: false)
            activities = loaded
            if selectedActivityID == nil {
                selectedActivityID = loaded.first?.id
            }
        } catch {
            errorMessage = session.readableError(error)
        }
    }

}

struct ActivityDetailView: View {
    @EnvironmentObject private var session: SessionStore

    let activityID: String

    @State private var detail: ActivityDetail?
    @State private var records: [RecordEntry] = []
    @State private var participantNames: [String: String] = [:]
    @State private var isLoading = true
    @State private var isUpdating = false
    @State private var errorMessage: String?
    @State private var showingEditor = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let detail {
                detailList(for: detail)
            } else {
                ContentUnavailableView(
                    "Activity Unavailable",
                    systemImage: "xmark.circle",
                    description: Text(errorMessage ?? "This activity could not be loaded.")
                )
            }
        }
        .navigationTitle(detail?.name ?? "Activity")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await load()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if canEditCurrentActivity {
                    Button("Edit") {
                        showingEditor = true
                    }
                }
            }
        }
        .task(id: activityID) {
            await load()
        }
        .sheet(isPresented: $showingEditor) {
            if let detail {
                NavigationStack {
                    ActivityEditorView(
                        title: "Edit Activity",
                        initialDraft: ActivityDraft(
                            name: detail.name,
                            scheduledDate: ServerDate.parsed(detail.date) ?? .now,
                            hasScheduledDate: detail.date != nil,
                            hasParticipantLimit: detail.maxVolunteerNum != nil,
                            maxVolunteerNum: detail.maxVolunteerNum ?? 20,
                            location: detail.location,
                            briefDescription: String(detail.description.prefix(120)),
                            description: detail.description,
                            durationMinutes: detail.duration
                        )
                    ) { request in
                        try await updateActivity(with: request)
                    }
                }
            }
        }
    }

    private func detailList(for detail: ActivityDetail) -> some View {
        List {
            // MARK: - Header
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(detail.name)
                            .font(.title2.bold())
                        Spacer()
                        StateChip(title: detail.state.title, tint: AppTheme.stateTint(for: detail.state))
                    }

                    Text(detail.description)
                        .font(.body)
                        .foregroundStyle(.secondary)

                    Text(headerMetadata(for: detail))
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)

                    CapacityBar(current: detail.volunteerNum, limit: detail.maxVolunteerNum)
                }
            }

            // MARK: - Participation
            Section("Participation") {
                HStack {
                    Text("Your status")
                    Spacer()
                    if let recordState = detail.viewerRecordState {
                        StateChip(title: recordState.title, tint: AppTheme.stateTint(for: recordState))
                    } else {
                        Text("Not applied")
                            .foregroundStyle(.secondary)
                    }
                }

                if detail.viewerRecordState == .pendingApproval && detail.state == .needVolunteer {
                    Button(role: .destructive) {
                        Task { await withdraw() }
                    } label: {
                        HStack {
                            Spacer()
                            if isUpdating { ProgressView() } else { Text("Withdraw Application") }
                            Spacer()
                        }
                    }
                    .disabled(isUpdating)
                } else if detail.state == .needVolunteer && !detail.viewerParticipating && detail.viewerRecordState != .pendingApproval {
                    Button {
                        Task { await apply() }
                    } label: {
                        HStack {
                            Spacer()
                            if isUpdating {
                                ProgressView()
                            } else {
                                Text(detail.viewerRecordState == .canceled ? "Reapply" : "Apply")
                            }
                            Spacer()
                        }
                    }
                    .disabled(isUpdating)
                }
            }

            // MARK: - Communication
            Section("Communication") {
                NavigationLink {
                    CommentsView(activityID: detail.id)
                } label: {
                    Label("Public Notes", systemImage: "text.bubble")
                }

                if canAccessChannel(detail: detail) {
                    NavigationLink {
                        ActivityChannelView(activity: detail)
                    } label: {
                        Label("Team Chat", systemImage: "message")
                    }
                } else {
                    Label("Team Chat", systemImage: "lock.message")
                        .foregroundStyle(.tertiary)
                }
            }

            // MARK: - Management
            if canManage(detail: detail) {
                Section("Manage") {
                    Button("Recruiting") { Task { await transition(path: "need_volunteer") } }
                    Button("Start") { Task { await transition(path: "go") } }
                    Button("End") { Task { await transition(path: "end") } }
                    Button("Cancel", role: .destructive) { Task { await transition(path: "cancel") } }
                }

                // MARK: - Participants
                Section("Participants (\(records.count))") {
                    if records.isEmpty {
                        Text("No records yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(records) { record in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(participantTitle(for: record))
                                        .font(.headline)
                                    Spacer()
                                    StateChip(title: record.state.title, tint: AppTheme.stateTint(for: record.state))
                                }
                                Text("Confirmed: \(DisplayText.hours(minutes: record.confirmedMinutes))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                participantControls(for: record)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }

            // MARK: - Error
            if let message = errorMessage {
                Section {
                    InlineErrorBanner(message: message)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func headerMetadata(for detail: ActivityDetail) -> String {
        let date = ServerDate.dateTimeText(detail.date)
        let duration = DisplayText.duration(minutes: detail.duration)
        return [detail.promoterName, date, detail.location, duration].joined(separator: " · ")
    }

    private var canEditCurrentActivity: Bool {
        guard let detail else {
            return false
        }
        return canManage(detail: detail)
    }

    private func canManage(detail: ActivityDetail) -> Bool {
        detail.promoter == session.currentUser?.id || session.canManageRecords || session.canCreateActivities
    }

    private func canAccessChannel(detail: ActivityDetail) -> Bool {
        detail.viewerParticipating || canManage(detail: detail)
    }

    private func load() async {
        if let demoData = session.demoData {
            detail = demoData.activityDetails[activityID]
            records = demoData.recordsByActivity[activityID] ?? []
            participantNames = demoData.userDisplayNames
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
            let loadedDetail = try await session.apiClient.fetchActivity(baseURL: serverURL, activityID: activityID)
            detail = loadedDetail
            if canManage(detail: loadedDetail) {
                records = try await session.apiClient.fetchRecords(baseURL: serverURL, activity: activityID)
                await hydrateParticipantNames(serverURL: serverURL)
            } else {
                records = []
                participantNames = [:]
            }
            errorMessage = nil
        } catch {
            errorMessage = session.readableError(error)
        }
    }

    private func apply() async {
        if session.demoData != nil {
            errorMessage = "Applying is disabled in demo mode."
            return
        }

        guard let serverURL = session.serverURL else {
            errorMessage = "Enter a valid service address."
            return
        }

        isUpdating = true
        defer {
            isUpdating = false
        }

        do {
            try await session.apiClient.applyActivity(baseURL: serverURL, activityID: activityID)
            await load()
        } catch {
            errorMessage = session.readableError(error)
        }
    }

    private func withdraw() async {
        if session.demoData != nil {
            errorMessage = "Withdrawal is disabled in demo mode."
            return
        }

        guard let serverURL = session.serverURL else {
            errorMessage = "Enter a valid service address."
            return
        }

        isUpdating = true
        defer {
            isUpdating = false
        }

        do {
            try await session.apiClient.withdrawActivity(baseURL: serverURL, activityID: activityID)
            await load()
        } catch {
            errorMessage = session.readableError(error)
        }
    }

    private func transition(path: String) async {
        if session.demoData != nil {
            errorMessage = "State changes are disabled in demo mode."
            return
        }

        guard let serverURL = session.serverURL else {
            errorMessage = "Enter a valid service address."
            return
        }

        do {
            try await session.apiClient.transitionActivity(baseURL: serverURL, activityID: activityID, pathComponent: path)
            await load()
        } catch {
            errorMessage = session.readableError(error)
        }
    }

    private func updateRecord(recordID: String, action: String) async {
        if session.demoData != nil {
            errorMessage = "Record changes are disabled in demo mode."
            return
        }

        guard let serverURL = session.serverURL else {
            errorMessage = "Enter a valid service address."
            return
        }

        do {
            try await session.apiClient.updateRecord(baseURL: serverURL, recordID: recordID, action: action)
            await load()
        } catch {
            errorMessage = session.readableError(error)
        }
    }

    private func updateActivity(with request: CreateActivityRequest) async throws {
        if session.demoData != nil {
            throw APIError.transport(code: nil, message: "Editing is disabled in demo mode.")
        }

        guard let serverURL = session.serverURL else {
            throw APIError.invalidBaseURL
        }
        _ = try await session.apiClient.updateActivity(baseURL: serverURL, activityID: activityID, request: request)
        await load()
        showingEditor = false
    }

    private func participantTitle(for record: RecordEntry) -> String {
        if let cached = participantNames[record.user] {
            return cached
        }
        if let resolved = session.participantName(for: record.user) {
            return resolved
        }
        return "Volunteer • \(DisplayText.shortIdentifier(record.user))"
    }

    private func hydrateParticipantNames(serverURL: URL) async {
        guard session.canViewUserDetails else {
            participantNames = [:]
            return
        }

        var nextNames: [String: String] = [:]
        for userID in Set(records.map(\.user)) {
            if let demoName = session.participantName(for: userID) {
                nextNames[userID] = demoName
                continue
            }
            do {
                nextNames[userID] = try await session.apiClient.loadDisplayNameIfPossible(baseURL: serverURL, userID: userID)
            } catch {
                nextNames[userID] = "Volunteer • \(DisplayText.shortIdentifier(userID))"
            }
        }
        participantNames = nextNames
    }

    @ViewBuilder
    private func participantControls(for record: RecordEntry) -> some View {
        switch record.state {
        case .pendingApproval:
            HStack(spacing: 12) {
                Button("Approve") {
                    Task {
                        await updateRecord(recordID: record.id, action: "approve")
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("Reject", role: .destructive) {
                    Task {
                        await updateRecord(recordID: record.id, action: "cancel")
                    }
                }
                .buttonStyle(.bordered)
            }
        case .approved:
            HStack(spacing: 12) {
                if detail?.state == .ended {
                    Button("Confirm") {
                        Task {
                            await updateRecord(recordID: record.id, action: "confirm")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button("Cancel", role: .destructive) {
                    Task {
                        await updateRecord(recordID: record.id, action: "cancel")
                    }
                }
                .buttonStyle(.bordered)
            }
        case .confirmed:
            recordStatusLabel(title: "Confirmed", systemImage: "checkmark.circle.fill", tint: AppTheme.stateTint(for: RecordState.confirmed))
        case .canceled:
            recordStatusLabel(title: "Cancelled", systemImage: "xmark.circle.fill", tint: AppTheme.stateTint(for: RecordState.canceled))
        }
    }

    private func recordStatusLabel(title: String, systemImage: String, tint: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
    }
}

#Preview("Feed", traits: .landscapeLeft) {
    FeedHomeView()
        .environmentObject(SessionStore.previewVolunteer())
}

#Preview("Activity Detail", traits: .landscapeLeft) {
    NavigationStack {
        ActivityDetailView(activityID: AppDemoData.primaryActivityID)
    }
    .environmentObject(SessionStore.previewOrganizer())
}

struct ExportPreviewView: View {
    let batch: ExportBatchResponse
    @Environment(\.dismiss) private var dismiss
    @State private var exportFileURL: URL?

    var body: some View {
        NavigationStack {
            PageWidthReader {
                CardPanel {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                        GridRow {
                            Label("Rows", systemImage: "list.bullet.rectangle")
                                .foregroundStyle(.secondary)
                            Text("\(batch.items.count)")
                        }
                        GridRow {
                            Label("Format", systemImage: "doc.text")
                                .foregroundStyle(.secondary)
                            Text(batch.targetFormat.uppercased())
                        }
                        GridRow {
                            Label("Created", systemImage: "calendar")
                                .foregroundStyle(.secondary)
                            Text(ServerDate.dateTimeText(batch.createdAt))
                        }
                    }
                }

                CardPanel {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(batch.fileName)
                            .font(.title3.weight(.semibold))
                        Text("Generated \(ServerDate.dateTimeText(batch.createdAt))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(batch.content)
                            .font(.footnote.monospaced())
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                if exportFileURL == nil {
                    exportFileURL = try? createTemporaryExportFile()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if let exportFileURL {
                        ShareLink(item: exportFileURL) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func createTemporaryExportFile() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "together-export", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appending(path: batch.fileName)
        try batch.content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}
