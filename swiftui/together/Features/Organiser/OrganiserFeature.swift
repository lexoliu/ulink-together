import SwiftUI

struct OrganiserHomeView: View {
    @EnvironmentObject private var session: SessionStore

    @State private var activities: [ActivitySummary] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingCreateSheet = false

    var body: some View {
        PageWidthReader {
            CardPanel {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Organiser Workspace")
                        .font(.title3.weight(.semibold))
                    Text("Create activities, revise published details, guide participation, and generate school-ready hour exports.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if session.canCreateActivities {
                        Button("Create Activity") {
                            showingCreateSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }

            if isLoading {
                LoadingCard(title: "Loading managed activities")
            } else if activities.isEmpty {
                EmptyStateCard(
                    title: "No managed activities",
                    message: "Published activities you own will appear here.",
                    systemImage: "square.and.pencil"
                )
            } else {
                ForEach(activities) { activity in
                    NavigationLink {
                        ActivityDetailView(activityID: activity.id)
                    } label: {
                        ActivityCard(activity: activity, action: nil)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let errorMessage {
                InlineErrorBanner(message: errorMessage)
            }
        }
        .navigationTitle("Manage")
        .navigationBarTitleDisplayMode(.large)
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
            throw APIError.transport("Creating activities is disabled in demo mode.")
        }
        guard let serverURL = session.serverURL else {
            throw APIError.invalidBaseURL
        }
        _ = try await session.apiClient.createActivity(baseURL: serverURL, request: request)
        await load()
        showingCreateSheet = false
    }
}

#Preview("Manage") {
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
            Section("Details") {
                TextField("Name", text: $draft.name)
                TextField("Date (RFC3339 optional)", text: $draft.date)
                    .textInputAutocapitalization(.never)
                TextField("Location", text: $draft.location)
                TextField("Duration in minutes", text: $draft.durationMinutes)
                    .keyboardType(.numberPad)
                TextField("Max participants", text: $draft.maxVolunteerNum)
                    .keyboardType(.numberPad)
            }

            Section("Descriptions") {
                TextField("Brief description", text: $draft.briefDescription, axis: .vertical)
                    .lineLimit(2 ... 4)
                TextField("Full description", text: $draft.description, axis: .vertical)
                    .lineLimit(4 ... 10)
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
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
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
            throw APIError.transport("All activity details are required.")
        }

        guard let duration = Int(draft.durationMinutes), duration > 0 else {
            throw APIError.transport("Duration must be a positive number of minutes.")
        }

        let maxVolunteerNum = draft.maxVolunteerNum.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsedMax = maxVolunteerNum.isEmpty ? nil : Int(maxVolunteerNum)
        if maxVolunteerNum.isEmpty == false && parsedMax == nil {
            throw APIError.transport("Max participants must be a whole number.")
        }

        return CreateActivityRequest(
            name: name,
            date: draft.date.trimmedNilIfEmpty,
            maxVolunteerNum: parsedMax,
            description: description,
            location: location,
            briefDescription: briefDescription,
            duration: duration
        )
    }
}
