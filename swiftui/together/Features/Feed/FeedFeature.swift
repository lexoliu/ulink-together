import SwiftUI

private enum FeedFilter: String, CaseIterable, Identifiable {
    case all
    case recruiting
    case joined
    case inProgress
    case completed

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .all:
            "All"
        case .recruiting:
            "Recruiting"
        case .joined:
            "Joined"
        case .inProgress:
            "In Progress"
        case .completed:
            "Completed"
        }
    }
}

struct FeedHomeView: View {
    @EnvironmentObject private var session: SessionStore

    @State private var activities: [ActivitySummary] = []
    @State private var selectedActivityID: String?
    @State private var searchText = ""
    @State private var filter: FeedFilter = .recruiting
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationSplitView {
            Group {
                if isLoading {
                    List {
                        LoadingCard(title: "Loading activities")
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                } else if filteredActivities.isEmpty {
                    List {
                        EmptyStateCard(
                            title: "No activities here yet",
                            message: "Try a different filter, refresh the feed, or wait for organisers to publish the next opportunity.",
                            systemImage: "calendar.badge.exclamationmark"
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                } else {
                    List(selection: $selectedActivityID) {
                        Section {
                            ForEach(filteredActivities) { activity in
                                NavigationLink(value: activity.id) {
                                    ActivityCard(activity: activity, action: nil)
                                }
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackgroundView())
            .navigationTitle("Feed")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search activities")
            .refreshable {
                await loadFeed()
            }
            .safeAreaInset(edge: .top) {
                filterBar
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    .background(.clear)
            }
        } detail: {
            if let selectedActivityID {
                NavigationStack {
                    ActivityDetailView(activityID: selectedActivityID)
                }
            } else {
                ContentUnavailableView("Choose an Activity", systemImage: "rectangle.and.text.magnifyingglass", description: Text("Browse open opportunities and inspect the full activity plan here."))
                    .background(AppBackgroundView())
            }
        }
        .task {
            await loadFeed()
        }
        .navigationDestination(for: String.self) { activityID in
            ActivityDetailView(activityID: activityID)
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

    private var filteredActivities: [ActivitySummary] {
        activities.filter { activity in
            let matchesSearch = searchText.isEmpty
                || activity.name.localizedCaseInsensitiveContains(searchText)
                || activity.location.localizedCaseInsensitiveContains(searchText)
                || activity.briefDescription.localizedCaseInsensitiveContains(searchText)

            let matchesFilter: Bool = switch filter {
            case .all:
                true
            case .recruiting:
                activity.state == .needVolunteer
            case .joined:
                activity.viewerJoined
            case .inProgress:
                activity.state == .going
            case .completed:
                activity.state == .ended
            }

            return matchesSearch && matchesFilter
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(FeedFilter.allCases) { item in
                    Button(item.title) {
                        filter = item
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(filter == item ? .blue : .gray.opacity(0.25))
                    .buttonBorderShape(.capsule)
                    .foregroundStyle(filter == item ? .white : .primary)
                }
            }
        }
    }

    private func loadFeed() async {
        guard let serverURL = session.serverURL else {
            errorMessage = "The server URL is invalid."
            isLoading = false
            return
        }

        isLoading = true
        defer {
            isLoading = false
        }

        do {
            let loaded = try await session.apiClient.fetchActivities(baseURL: serverURL, displayAll: true)
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
    @State private var exportBatch: ExportBatchResponse?
    @State private var isLoading = true
    @State private var isUpdating = false
    @State private var errorMessage: String?
    @State private var showingEditor = false

    var body: some View {
        PageWidthReader {
            if isLoading {
                LoadingCard(title: "Loading activity")
            } else if let detail {
                header(for: detail)
                detailSummary(for: detail)
                actionPanel(for: detail)
                if canManage(detail: detail) {
                    managementPanel(for: detail)
                    participantPanel
                }
            } else {
                EmptyStateCard(
                    title: "Activity unavailable",
                    message: "The selected activity could not be loaded.",
                    systemImage: "xmark.circle"
                )
            }

            if let message = errorMessage {
                InlineErrorBanner(message: message)
            }
        }
        .navigationTitle(detail?.name ?? "Activity")
        .navigationBarTitleDisplayMode(.inline)
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
                            date: detail.date ?? "",
                            maxVolunteerNum: detail.maxVolunteerNum.map(String.init) ?? "",
                            location: detail.location,
                            briefDescription: String(detail.description.prefix(120)),
                            description: detail.description,
                            durationMinutes: String(detail.duration)
                        )
                    ) { request in
                        try await updateActivity(with: request)
                    }
                }
            }
        }
        .sheet(item: $exportBatch) { batch in
            ExportPreviewView(batch: batch)
        }
    }

    private var participantPanel: some View {
        CardPanel {
            VStack(alignment: .leading, spacing: 16) {
                Text("Participants")
                    .font(.title3.weight(.semibold))

                if records.isEmpty {
                    Text("No participant records yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(records) { record in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(record.activityName ?? "Untitled activity")
                                        .font(.headline)
                                    Text(record.user == session.currentUser?.id ? "You" : "Volunteer")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                StateChip(title: record.state.title, tint: AppTheme.stateTint(for: record.state))
                            }

                            Text("Confirmed: \(DisplayText.hours(minutes: record.confirmedMinutes))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            HStack {
                                Button("Approve") {
                                    Task {
                                        await updateRecord(recordID: record.id, action: "approve_apply")
                                    }
                                }
                                .buttonStyle(.bordered)

                                Button("Mark Done") {
                                    Task {
                                        await updateRecord(recordID: record.id, action: "done")
                                    }
                                }
                                .buttonStyle(.borderedProminent)

                                Button("Cancel", role: .destructive) {
                                    Task {
                                        await updateRecord(recordID: record.id, action: "disapprove_apply")
                                    }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 8)

                        if record.id != (records.last?.id ?? "") {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func header(for detail: ActivityDetail) -> some View {
        CardPanel {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(detail.name)
                            .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        Text(detail.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    StateChip(title: detail.state.title, tint: AppTheme.stateTint(for: detail.state))
                }

                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
                    GridRow {
                        meta("Organiser", systemImage: "person.crop.circle")
                        Text(detail.promoterName)
                    }
                    GridRow {
                        meta("Date", systemImage: "calendar")
                        Text(ServerDate.dateTimeText(detail.date))
                    }
                    GridRow {
                        meta("Location", systemImage: "mappin.and.ellipse")
                        Text(detail.location)
                    }
                    GridRow {
                        meta("Duration", systemImage: "clock")
                        Text(DisplayText.duration(minutes: detail.duration))
                    }
                }

                CapacityBar(current: detail.volunteerNum, limit: detail.maxVolunteerNum)
            }
        }
    }

    private func detailSummary(for detail: ActivityDetail) -> some View {
        CardPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text("Participation")
                    .font(.title3.weight(.semibold))

                if let recordState = detail.viewerRecordState {
                    StateChip(title: recordState.title, tint: AppTheme.stateTint(for: recordState))
                } else {
                    Text("You have not joined this activity yet.")
                        .foregroundStyle(.secondary)
                }

                if detail.state == .needVolunteer && !detail.viewerJoined {
                    Button {
                        Task {
                            await join()
                        }
                    } label: {
                        if isUpdating {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Join Activity")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isUpdating)
                }
            }
        }
    }

    private func actionPanel(for detail: ActivityDetail) -> some View {
        CardPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text("Conversation")
                    .font(.title3.weight(.semibold))
                NavigationLink {
                    CommentsView(activityID: detail.id)
                } label: {
                    labelRow(title: "Comments", subtitle: "Read organiser notes and volunteer replies.", systemImage: "text.bubble")
                }

                NavigationLink {
                    ActivityChannelView(activity: detail)
                } label: {
                    labelRow(title: "Channel", subtitle: "Activity-scoped messaging and coordination.", systemImage: "message")
                }
            }
        }
    }

    private func managementPanel(for detail: ActivityDetail) -> some View {
        CardPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text("Manage Activity")
                    .font(.title3.weight(.semibold))
                Text("Organiser controls stay in the detail screen so state, participant progress, and reporting remain in one place.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Recruiting") {
                        Task {
                            await transition(path: "need_volunteer")
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("Start") {
                        Task {
                            await transition(path: "go")
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("End") {
                        Task {
                            await transition(path: "end")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }

                HStack {
                    Button("Cancel", role: .destructive) {
                        Task {
                            await transition(path: "cancel")
                        }
                    }
                    .buttonStyle(.bordered)

                    if session.canGenerateExport {
                        Button("Export Hours") {
                            Task {
                                await exportHours()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
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

    private func load() async {
        guard let serverURL = session.serverURL else {
            isLoading = false
            errorMessage = "The server URL is invalid."
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
            } else {
                records = []
            }
            errorMessage = nil
        } catch {
            errorMessage = session.readableError(error)
        }
    }

    private func join() async {
        guard let serverURL = session.serverURL else {
            errorMessage = "The server URL is invalid."
            return
        }

        isUpdating = true
        defer {
            isUpdating = false
        }

        do {
            try await session.apiClient.joinActivity(baseURL: serverURL, activityID: activityID)
            await load()
        } catch {
            errorMessage = session.readableError(error)
        }
    }

    private func transition(path: String) async {
        guard let serverURL = session.serverURL else {
            errorMessage = "The server URL is invalid."
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
        guard let serverURL = session.serverURL else {
            errorMessage = "The server URL is invalid."
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
        guard let serverURL = session.serverURL else {
            throw APIError.invalidBaseURL
        }
        _ = try await session.apiClient.updateActivity(baseURL: serverURL, activityID: activityID, request: request)
        await load()
        showingEditor = false
    }

    private func exportHours() async {
        guard let serverURL = session.serverURL else {
            errorMessage = "The server URL is invalid."
            return
        }

        do {
            exportBatch = try await session.apiClient.generateExport(baseURL: serverURL)
        } catch {
            errorMessage = session.readableError(error)
        }
    }

    private func meta(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .foregroundStyle(.secondary)
    }

    private func labelRow(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
    }
}

struct ExportPreviewView: View {
    let batch: ExportBatchResponse
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PageWidthReader {
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
