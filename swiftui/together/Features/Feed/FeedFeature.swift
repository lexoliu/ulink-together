import SwiftUI

private enum FeedFilter: String, CaseIterable, Identifiable {
    case all
    case recruiting
    case pendingApproval
    case participating
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
        case .pendingApproval:
            "Pending"
        case .participating:
            "Participating"
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
            case .pendingApproval:
                activity.viewerRecordState == .pendingApproval
            case .participating:
                activity.viewerParticipating
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
    @State private var participantNames: [String: String] = [:]
    @State private var isLoading = true
    @State private var isUpdating = false
    @State private var errorMessage: String?
    @State private var showingEditor = false
    @State private var isManagementExpanded = false
    @State private var isParticipantsExpanded = false

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

    private var participantPanel: some View {
        return CardPanel {
            DisclosureGroup(isExpanded: $isParticipantsExpanded) {
                VStack(alignment: .leading, spacing: 16) {
                    if records.isEmpty {
                        Text("No application or participation records yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(records) { record in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(participantTitle(for: record))
                                            .font(.headline)
                                        Text(record.activityName ?? "Untitled activity")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    StateChip(title: record.state.title, tint: AppTheme.stateTint(for: record.state))
                                }

                                Text("Confirmed: \(DisplayText.hours(minutes: record.confirmedMinutes))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                participantControls(for: record)
                            }
                            .padding(.top, 14)
                            .padding(.bottom, record.id == records.last?.id ? 0 : 14)

                            if record.id != (records.last?.id ?? "") {
                                Divider()
                            }
                        }
                    }
                }
                .padding(.top, 14)
            } label: {
                Text("Participants (\(records.count))")
                    .font(.title3.weight(.semibold))
            }
            .tint(.primary)
        }
    }

    private func header(for detail: ActivityDetail) -> some View {
        CardPanel {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(detail.name)
                            .font(.system(.largeTitle, design: .rounded).weight(.bold))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(detail.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
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
                    Text("You have not applied to this activity yet.")
                        .foregroundStyle(.secondary)
                }

                if detail.viewerRecordState == .pendingApproval && detail.state == .needVolunteer {
                    Button(role: .destructive) {
                        Task {
                            await withdraw()
                        }
                    } label: {
                        if isUpdating {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Withdraw Application")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isUpdating)
                } else if detail.state == .needVolunteer && !detail.viewerParticipating && detail.viewerRecordState != .pendingApproval {
                    Button {
                        Task {
                            await apply()
                        }
                    } label: {
                        if isUpdating {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(detail.viewerRecordState == .canceled ? "Reapply Activity" : "Apply Activity")
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
                Text("Communication")
                    .font(.title3.weight(.semibold))
                NavigationLink {
                    CommentsView(activityID: detail.id)
                } label: {
                    labelRow(
                        title: "Public Notes",
                        subtitle: "Announcements and questions visible to everyone.",
                        systemImage: "text.bubble"
                    )
                }

                if canAccessChannel(detail: detail) {
                    NavigationLink {
                        ActivityChannelView(activity: detail)
                    } label: {
                        labelRow(
                            title: "Team Chat",
                            subtitle: "Live messaging for approved volunteers.",
                            systemImage: "message"
                        )
                    }
                } else {
                    labelRow(
                        title: "Team Chat",
                        subtitle: "Join this activity before opening live team chat.",
                        systemImage: "lock.message"
                    )
                    .opacity(0.6)
                }
            }
        }
    }

    private func managementPanel(for detail: ActivityDetail) -> some View {
        CardPanel {
            DisclosureGroup(isExpanded: $isManagementExpanded) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Update the activity state here while keeping participant progress in the same workflow.")
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
                    }
                }
                .padding(.top, 14)
            } label: {
                Text("Manage Activity")
                    .font(.title3.weight(.semibold))
            }
            .tint(.primary)
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

    private func meta(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .foregroundStyle(.secondary)
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

    private func labelRow(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.accentTint)
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

#Preview("Feed") {
    FeedHomeView()
        .environmentObject(SessionStore.previewVolunteer())
}

#Preview("Activity Detail") {
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
