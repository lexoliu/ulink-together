import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

struct AccountHomeView: View {
    @EnvironmentObject private var session: SessionStore

    @State private var showingProfileEditor = false
    @State private var showingChangePassword = false

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
        .sheet(isPresented: $showingChangePassword) {
            NavigationStack {
                ChangePasswordView()
            }
            .environmentObject(session)
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
                Text("Service address")
                    .font(.subheadline.weight(.medium))
                TextField(
                    "https://volunteer.ulink.edu.cn",
                    text: Binding(
                        get: { session.serverURLText },
                        set: { session.updateServerURL($0) }
                    )
                )
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .autocorrectionDisabled()
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(uiColor: .systemBackground))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color(uiColor: .separator).opacity(0.22), lineWidth: 1)
                }

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

                Button("Change Password") {
                    showingChangePassword = true
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

private struct ChangePasswordView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false

    var body: some View {
        Form {
            Section("Current password") {
                SecureField("Current password", text: $currentPassword)
            }

            Section("New password") {
                SecureField("New password", text: $newPassword)
                SecureField("Confirm new password", text: $confirmPassword)
            }

            Section {
                Button(isSubmitting ? "Updating..." : "Update Password") {
                    Task {
                        await submit()
                    }
                }
                .disabled(isSubmitting)
            }

            if let errorMessage {
                Section {
                    InlineErrorBanner(message: errorMessage)
                        .listRowInsets(EdgeInsets())
                }
            }
        }
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }

    private func submit() async {
        guard let serverURL = session.serverURL else {
            errorMessage = "Enter a valid service address first."
            return
        }
        let normalizedCurrent = currentPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNew = newPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedCurrent.isEmpty || normalizedNew.isEmpty {
            errorMessage = "Current and new passwords are required."
            return
        }
        if normalizedNew.count < 6 {
            errorMessage = "New password must be at least 6 characters."
            return
        }
        if normalizedNew != confirmPassword.trimmingCharacters(in: .whitespacesAndNewlines) {
            errorMessage = "Password confirmation does not match."
            return
        }

        isSubmitting = true
        defer {
            isSubmitting = false
        }

        do {
            try await session.apiClient.changePassword(
                baseURL: serverURL,
                currentPassword: normalizedCurrent,
                newPassword: normalizedNew
            )
            errorMessage = nil
            dismiss()
        } catch {
            errorMessage = session.readableError(error)
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
    @State private var selectedAvatarItem: PhotosPickerItem?
    @State private var pendingAvatarUpload: PendingAvatarUpload?
    @State private var errorMessage: String?
    @State private var isLoadingAvatar = false
    @State private var isSaving = false

    init(user: UserProfile) {
        self.user = user
        _realname = State(initialValue: user.realname)
        _gender = State(initialValue: user.gender)
        _descriptionText = State(initialValue: user.description)
        _classname = State(initialValue: user.classname)
    }

    var body: some View {
        Form {
            Section("Profile") {
                avatarEditor
                TextField("Real name", text: $realname)
                TextField("Gender", text: $gender)
                TextField("Class name", text: $classname)
                TextField("Description", text: $descriptionText, axis: .vertical)
                    .lineLimit(3 ... 6)
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
        .onChange(of: selectedAvatarItem) { _, newValue in
            Task {
                await loadAvatarSelection(from: newValue)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(isSaving ? "Saving..." : "Save") {
                    Task {
                        await save()
                    }
                }
                .disabled(isSaving || isLoadingAvatar)
            }
        }
    }

    private var avatarEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                avatarPreview

                VStack(alignment: .leading, spacing: 6) {
                    Text("Profile photo")
                        .font(.headline)

                    if pendingAvatarUpload != nil {
                        Text("Selected photo will upload when you save.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else if user.avatar == nil {
                        Text("Add a photo after account creation.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Choose a new photo to replace the current one.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }

            PhotosPicker(selection: $selectedAvatarItem, matching: .images) {
                Label(user.avatar == nil && pendingAvatarUpload == nil ? "Choose Photo" : "Replace Photo", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(.bordered)

            if isLoadingAvatar {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Loading selected photo...")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var avatarPreview: some View {
        if let selectedAvatarPreviewImage {
            selectedAvatarPreviewImage
                .resizable()
                .scaledToFill()
                .frame(width: 84, height: 84)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .strokeBorder(.white.opacity(0.7), lineWidth: 1)
                }
        } else {
            AvatarBadge(
                title: realname.isEmpty ? user.realname : realname,
                imageURL: session.serverURL.flatMap { session.apiClient.avatarURL(baseURL: $0, path: user.avatar) },
                size: 84
            )
        }
    }

    private var selectedAvatarPreviewImage: Image? {
        guard let pendingAvatarUpload else {
            return nil
        }
        #if canImport(UIKit)
        guard let image = UIImage(data: pendingAvatarUpload.data) else {
            return nil
        }
        return Image(uiImage: image)
        #elseif canImport(AppKit)
        guard let image = NSImage(data: pendingAvatarUpload.data) else {
            return nil
        }
        return Image(nsImage: image)
        #else
        return nil
        #endif
    }

    private func loadAvatarSelection(from item: PhotosPickerItem?) async {
        guard let item else {
            return
        }

        isLoadingAvatar = true
        defer {
            isLoadingAvatar = false
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self), !data.isEmpty else {
                throw APIError.transport(code: nil, message: "The selected photo could not be loaded.")
            }
            let contentType = preferredImageType(from: item)
            pendingAvatarUpload = PendingAvatarUpload(
                data: data,
                filename: "avatar.\(contentType.preferredFilenameExtension ?? "jpg")",
                mimeType: contentType.preferredMIMEType
            )
            errorMessage = nil
        } catch {
            errorMessage = session.readableError(error)
        }
    }

    private func preferredImageType(from item: PhotosPickerItem) -> UTType {
        item.supportedContentTypes.first(where: { $0.conforms(to: .image) }) ?? .jpeg
    }

    private func save() async {
        isSaving = true
        defer {
            isSaving = false
        }

        let previousAvatarPath = user.avatar
        var uploadedAvatarPath: String?

        do {
            let profileRequest = UpdateUserRequest(
                realname: realname.trimmingCharacters(in: .whitespacesAndNewlines),
                gender: gender.trimmingCharacters(in: .whitespacesAndNewlines),
                description: descriptionText.trimmingCharacters(in: .whitespacesAndNewlines),
                classname: classname.trimmingCharacters(in: .whitespacesAndNewlines),
                avatar: previousAvatarPath
            )

            let profileUpdated = await session.updateCurrentUser(request: profileRequest)
            guard profileUpdated else {
                errorMessage = session.lastError
                return
            }

            guard pendingAvatarUpload != nil else {
                dismiss()
                return
            }

            uploadedAvatarPath = try await uploadAvatar()
            let avatarUpdated = await session.updateCurrentUser(
                request: UpdateUserRequest(
                    realname: nil,
                    gender: nil,
                    description: nil,
                    classname: nil,
                    avatar: uploadedAvatarPath
                )
            )
            if avatarUpdated {
                await deleteManagedResourceIfNeeded(at: previousAvatarPath, preserving: uploadedAvatarPath)
                dismiss()
                return
            }

            await deleteManagedResourceIfNeeded(at: uploadedAvatarPath)
            errorMessage = session.lastError
        } catch {
            await deleteManagedResourceIfNeeded(at: uploadedAvatarPath)
            errorMessage = session.readableError(error)
        }
    }

    private func uploadAvatar() async throws -> String {
        guard let pendingAvatarUpload else {
            throw APIError.transport(code: nil, message: "No avatar upload is pending.")
        }
        if session.demoData != nil {
            throw APIError.transport(code: nil, message: "Avatar upload is unavailable in preview mode.")
        }
        guard let serverURL = session.serverURL else {
            throw APIError.invalidBaseURL
        }

        let resource = try await session.apiClient.uploadResource(
            baseURL: serverURL,
            filename: pendingAvatarUpload.filename,
            data: pendingAvatarUpload.data,
            mimeType: pendingAvatarUpload.mimeType
        )
        return resource.path
    }

    private func deleteManagedResourceIfNeeded(at path: String?, preserving preservedPath: String? = nil) async {
        guard path != preservedPath,
              session.demoData == nil,
              let serverURL = session.serverURL,
              let filename = managedResourceFilename(from: path) else {
            return
        }

        do {
            try await session.apiClient.deleteResource(baseURL: serverURL, filename: filename)
        } catch {
            // Cleanup failure should not hide the main profile-save result.
        }
    }

    private func managedResourceFilename(from path: String?) -> String? {
        guard let path else {
            return nil
        }

        let resourcePath: String
        if let url = URL(string: path), let scheme = url.scheme, !scheme.isEmpty {
            resourcePath = url.path
        } else {
            resourcePath = path
        }

        let marker = "/api/v1/resource/"
        if let range = resourcePath.range(of: marker) {
            let filename = String(resourcePath[range.upperBound...])
            return filename.isEmpty ? nil : filename
        }
        return nil
    }
}

private struct PendingAvatarUpload {
    let data: Data
    let filename: String
    let mimeType: String?
}

#Preview("Account") {
    NavigationStack {
        AccountHomeView()
    }
    .environmentObject(SessionStore.previewOrganizer())
}
