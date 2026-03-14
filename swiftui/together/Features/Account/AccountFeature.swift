import SwiftUI

struct AccountHomeView: View {
    @EnvironmentObject private var session: SessionStore

    @State private var showingProfileEditor = false

    var body: some View {
        PageWidthReader {
            if let currentUser = session.currentUser {
                profileCard(for: currentUser)
                profileDetails(for: currentUser)
                actionCard
            } else {
                EmptyStateCard(
                    title: "No profile loaded",
                    message: "Sign in again to refresh your account details.",
                    systemImage: "person.crop.circle.badge.exclamationmark"
                )
            }

            if let message = session.lastError {
                InlineErrorBanner(message: message)
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingProfileEditor) {
            if let currentUser = session.currentUser {
                NavigationStack {
                    ProfileEditorView(user: currentUser)
                }
            }
        }
    }

    private func profileCard(for user: UserProfile) -> some View {
        CardPanel {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) {
                    AvatarBadge(
                        title: user.realname,
                        imageURL: session.serverURL.flatMap { session.apiClient.avatarURL(baseURL: $0, path: user.avatar) },
                        size: 72
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        Text(user.realname)
                            .font(.title2.weight(.bold))
                        Text(user.email)
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Text(user.classname)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Edit") {
                        showingProfileEditor = true
                    }
                    .buttonStyle(.borderedProminent)
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 14) {
                        AvatarBadge(
                            title: user.realname,
                            imageURL: session.serverURL.flatMap { session.apiClient.avatarURL(baseURL: $0, path: user.avatar) },
                            size: 72
                        )

                        VStack(alignment: .leading, spacing: 6) {
                            Text(user.realname)
                                .font(.title2.weight(.bold))
                            Text(user.classname)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(user.email)
                        .font(.body)
                        .foregroundStyle(.secondary)

                    Button("Edit Profile") {
                        showingProfileEditor = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func profileDetails(for user: UserProfile) -> some View {
        CardPanel {
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 12) {
                GridRow {
                    Label("Gender", systemImage: "person")
                        .foregroundStyle(.secondary)
                    Text(user.gender)
                }
                GridRow {
                    Label("Description", systemImage: "text.alignleft")
                        .foregroundStyle(.secondary)
                    Text(user.description.isEmpty ? "No profile description yet." : user.description)
                }
            }
        }
    }

    private var actionCard: some View {
        CardPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text("Account")
                    .font(.headline)
                TextField(
                    "Server URL",
                    text: Binding(
                        get: { session.serverURLText },
                        set: { session.updateServerURL($0) }
                    )
                )
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .textFieldStyle(.roundedBorder)

                Button("Reconnect") {
                    Task {
                        await session.reconnect()
                    }
                }
                .buttonStyle(.bordered)

                Button("Refresh Details") {
                    Task {
                        await session.refreshCurrentUser()
                    }
                }
                .buttonStyle(.bordered)

                Button("Sign Out", role: .destructive) {
                    Task {
                        await session.logout()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

struct ProfileEditorView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    let user: UserProfile

    @State private var realname: String
    @State private var gender: String
    @State private var descriptionText: String
    @State private var classname: String
    @State private var avatar: String
    @State private var errorMessage: String?

    init(user: UserProfile) {
        self.user = user
        _realname = State(initialValue: user.realname)
        _gender = State(initialValue: user.gender)
        _descriptionText = State(initialValue: user.description)
        _classname = State(initialValue: user.classname)
        _avatar = State(initialValue: user.avatar ?? "")
    }

    var body: some View {
        Form {
            Section("Profile") {
                TextField("Real name", text: $realname)
                TextField("Gender", text: $gender)
                TextField("Class name", text: $classname)
                TextField("Description", text: $descriptionText, axis: .vertical)
                    .lineLimit(3 ... 6)
                TextField("Avatar path", text: $avatar)
            }

            if let errorMessage {
                Section {
                    InlineErrorBanner(message: errorMessage)
                        .listRowInsets(EdgeInsets())
                }
            }
        }
        .navigationTitle("Edit Profile")
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
                        await save()
                    }
                }
            }
        }
    }

    private func save() async {
        let request = UpdateUserRequest(
            realname: realname.trimmingCharacters(in: .whitespacesAndNewlines),
            gender: gender.trimmingCharacters(in: .whitespacesAndNewlines),
            description: descriptionText.trimmingCharacters(in: .whitespacesAndNewlines),
            classname: classname.trimmingCharacters(in: .whitespacesAndNewlines),
            avatar: avatar.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : avatar.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let updated = await session.updateCurrentUser(request: request)
        if updated {
            dismiss()
        } else {
            errorMessage = session.lastError
        }
    }
}

#Preview("Account") {
    NavigationStack {
        AccountHomeView()
    }
    .environmentObject(SessionStore.previewOrganizer())
}
