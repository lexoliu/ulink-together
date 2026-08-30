import SwiftUI

struct OrganiserHomeView: View {
    @EnvironmentObject private var session: SessionStore

    @State private var activities: [ActivitySummary] = []
    @State private var exportBatch: ExportBatchResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingCreateSheet = false

    var body: some View {
        List {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if activities.isEmpty {
                EmptyStateCard(
                    title: "No managed activities",
                    systemImage: "square.and.pencil"
                )
            } else {
                ForEach(activities) { activity in
                    NavigationLink {
                        ActivityDetailView(activityID: activity.id)
                    } label: {
                        ActivityListRow(activity: activity)
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
        .navigationTitle("Manage")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if session.canCreateActivities {
                        Button {
                            showingCreateSheet = true
                        } label: {
                            Label("Create Activity", systemImage: "plus")
                        }
                    }
                    if session.canGenerateExport {
                        Button {
                            Task { await exportHours() }
                        } label: {
                            Label("Export Hours", systemImage: "square.and.arrow.up")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task {
            await load()
        }
        .refreshable {
            await load()
        }
        .sheet(isPresented: $showingCreateSheet) {
            NavigationStack {
                ActivityEditorView(title: "Create Activity", initialDraft: ActivityDraft()) { request in
                    try await createActivity(with: request)
                }
            }
        }
        .sheet(item: $exportBatch) { batch in
            ExportPreviewView(batch: batch)
        }
    }

    private func load() async {
        if let demoData = session.demoData {
            activities = demoData.feedActivities.filter { $0.promoter == session.currentUser?.id }
            errorMessage = nil
            isLoading = false
            return
        }

        guard let serverURL = session.serverURL, let currentUser = session.currentUser else {
            errorMessage = "You must sign in before managing activities."
            isLoading = false
            return
        }

        isLoading = true
        defer {
            isLoading = false
        }

        do {
            activities = try await session.apiClient.fetchActivities(
                baseURL: serverURL,
                user: currentUser.id,
                displayAll: true
            )
            errorMessage = nil
        } catch {
            errorMessage = session.readableError(error)
        }
    }

    private func createActivity(with request: CreateActivityRequest) async throws {
        if session.demoData != nil {
            throw APIError.transport(code: nil, message: "Creating activities is disabled in demo mode.")
        }
        guard let serverURL = session.serverURL else {
            throw APIError.invalidBaseURL
        }
        _ = try await session.apiClient.createActivity(baseURL: serverURL, request: request)
        await load()
        showingCreateSheet = false
    }

    private func exportHours() async {
        if let batch = session.demoData?.exportBatch {
            exportBatch = batch
            return
        }

        guard let serverURL = session.serverURL else {
            errorMessage = "Enter a valid service address."
            return
        }

        do {
            exportBatch = try await session.apiClient.generateExport(baseURL: serverURL)
        } catch {
            errorMessage = session.readableError(error)
        }
    }
}

#Preview("Manage", traits: .landscapeLeft) {
    NavigationStack {
        OrganiserHomeView()
    }
    .environmentObject(SessionStore.previewOrganizer())
}

struct ActivityEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let initialDraft: ActivityDraft
    let onSubmit: @Sendable (CreateActivityRequest) async throws -> Void

    @State private var draft: ActivityDraft
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name
        case location
        case summary
        case details
    }

    init(
        title: String,
        initialDraft: ActivityDraft,
        onSubmit: @escaping @Sendable (CreateActivityRequest) async throws -> Void
    ) {
        self.title = title
        self.initialDraft = initialDraft
        self.onSubmit = onSubmit
        _draft = State(initialValue: initialDraft)
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.title2.weight(.bold))
                }
            }

            Section("Details") {
                TextField("Activity name", text: $draft.name)
                    .focused($focusedField, equals: .name)

                Toggle("Set a scheduled date", isOn: $draft.hasScheduledDate)
                    .animation(.snappy, value: draft.hasScheduledDate)
                if draft.hasScheduledDate {
                    DatePicker("Date", selection: $draft.scheduledDate, displayedComponents: [.date, .hourAndMinute])
                }

                TextField("Location", text: $draft.location)
                    .focused($focusedField, equals: .location)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text(DisplayText.duration(minutes: draft.durationMinutes))
                            .foregroundStyle(.secondary)
                    }
                    Stepper(value: $draft.durationMinutes, in: 15 ... 480, step: 15) {
                        EmptyView()
                    }
                }

                Toggle("Limit participants", isOn: $draft.hasParticipantLimit)
                    .animation(.snappy, value: draft.hasParticipantLimit)
                if draft.hasParticipantLimit {
                    Stepper(value: $draft.maxVolunteerNum, in: 1 ... 500) {
                        HStack {
                            Text("Max participants")
                            Spacer()
                            Text("\(draft.maxVolunteerNum)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Descriptions") {
                TextField("Short summary", text: $draft.briefDescription, axis: .vertical)
                    .lineLimit(2 ... 4)
                    .focused($focusedField, equals: .summary)
                TextField("Full description", text: $draft.description, axis: .vertical)
                    .lineLimit(5 ... 10)
                    .focused($focusedField, equals: .details)
            }

            if let errorMessage {
                Section {
                    InlineErrorBanner(message: errorMessage)
                        .listRowInsets(EdgeInsets())
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        #if !os(visionOS)
        .scrollDismissesKeyboard(.interactively)
        #endif
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(isSubmitting ? "Saving..." : "Save") {
                    Task {
                        await submit()
                    }
                }
                .disabled(isSubmitting)
            }
        }
    }

    private func submit() async {
        do {
            let request = try validatedRequest()
            isSubmitting = true
            defer {
                isSubmitting = false
            }
            try await onSubmit(request)
            dismiss()
        } catch {
            if let apiError = error as? APIError {
                errorMessage = apiError.errorDescription
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func validatedRequest() throws -> CreateActivityRequest {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let location = draft.location.trimmingCharacters(in: .whitespacesAndNewlines)
        let briefDescription = draft.briefDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = draft.description.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty, !location.isEmpty, !briefDescription.isEmpty, !description.isEmpty else {
            throw APIError.transport(code: nil, message: "All activity details are required.")
        }

        let duration = draft.durationMinutes
        guard duration > 0 else {
            throw APIError.transport(code: nil, message: "Duration must be a positive number of minutes.")
        }

        return CreateActivityRequest(
            name: name,
            date: draft.hasScheduledDate ? ServerDate.encoded(draft.scheduledDate) : nil,
            maxVolunteerNum: draft.hasParticipantLimit ? draft.maxVolunteerNum : nil,
            description: description,
            location: location,
            briefDescription: briefDescription,
            duration: duration
        )
    }
}
