import SwiftUI

struct NotificationsHomeView: View {
    @EnvironmentObject private var session: SessionStore

    @State private var notifications: [NotificationResponse] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading && notifications.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if notifications.isEmpty {
                ContentUnavailableView(
                    "You're all caught up",
                    systemImage: "bell.slash",
                    description: Text("New messages, activity changes, and hour updates will appear here.")
                )
            } else {
                List {
                    ForEach(notifications) { notification in
                        NotificationRowLink(
                            notification: notification,
                            onTap: {
                                if !notification.isRead {
                                    Task { await markRead([notification.id]) }
                                }
                            }
                        )
                        .listRowBackground(notification.isRead ? Color.clear : AppTheme.accentTint.opacity(0.08))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if !notification.isRead {
                                Button {
                                    Task {
                                        await markRead([notification.id])
                                    }
                                } label: {
                                    Label("Read", systemImage: "checkmark")
                                }
                                .tint(AppTheme.accentTint)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if hasUnread {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Mark All Read") {
                        Task {
                            await markAllRead()
                        }
                    }
                }
            }
        }
        .refreshable {
            await load()
        }
        .task {
            await load()
        }
        .onChange(of: session.unreadNotificationCount) { _, _ in
            Task { await load() }
        }
        .alert("Unable to Load", isPresented: Binding(
            get: { errorMessage != nil },
            set: { newValue in if !newValue { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            if let errorMessage {
                Text(errorMessage)
            }
        }
    }

    private var hasUnread: Bool {
        notifications.contains(where: { !$0.isRead })
    }

    private func load() async {
        guard let serverURL = session.serverURL else {
            isLoading = false
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            notifications = try await session.apiClient.fetchNotifications(
                baseURL: serverURL,
                unreadOnly: false,
                limit: 100
            )
            errorMessage = nil
            await session.refreshUnreadNotificationCount()
        } catch {
            errorMessage = session.readableError(error)
        }
    }

    private func markRead(_ ids: [String]) async {
        guard let serverURL = session.serverURL else { return }
        do {
            try await session.apiClient.markNotificationsRead(baseURL: serverURL, ids: ids)
            session.decrementUnreadNotificationCount(by: ids.count)
            await load()
        } catch {
            errorMessage = session.readableError(error)
        }
    }

    private func markAllRead() async {
        guard let serverURL = session.serverURL else { return }
        do {
            try await session.apiClient.markAllNotificationsRead(baseURL: serverURL)
            session.markUnreadNotificationsCleared()
            await load()
        } catch {
            errorMessage = session.readableError(error)
        }
    }

}

struct NotificationPreferencesView: View {
    @EnvironmentObject private var session: SessionStore

    @State private var preferences: [NotificationPreference] = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Text("Choose which system notifications you want to receive. Disabling a type stops new notifications immediately.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Types") {
                if isLoading {
                    HStack {
                        ProgressView()
                        Text("Loading")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(Array(preferences.enumerated()), id: \.element.notificationType) { index, preference in
                        Toggle(
                            isOn: Binding(
                                get: { preferences[index].enabled },
                                set: { newValue in
                                    preferences[index] = NotificationPreference(
                                        notificationType: preferences[index].notificationType,
                                        enabled: newValue
                                    )
                                    Task { await save() }
                                }
                            )
                        ) {
                            Label(preference.notificationType.title, systemImage: preference.notificationType.systemImage)
                        }
                    }
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await load()
        }
    }

    private func load() async {
        guard let serverURL = session.serverURL else {
            // Fall back to all-enabled defaults for demo / disconnected mode
            preferences = NotificationTypeName.allCases.map {
                NotificationPreference(notificationType: $0, enabled: true)
            }
            isLoading = false
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            preferences = try await session.apiClient.fetchNotificationPreferences(baseURL: serverURL)
            // Ensure every known type is represented (server only returns what user has overridden + defaults)
            var present = Set(preferences.map(\.notificationType))
            for type in NotificationTypeName.allCases where !present.contains(type) {
                preferences.append(NotificationPreference(notificationType: type, enabled: true))
                present.insert(type)
            }
            errorMessage = nil
        } catch {
            errorMessage = session.readableError(error)
        }
    }

    private func save() async {
        guard let serverURL = session.serverURL else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await session.apiClient.updateNotificationPreferences(
                baseURL: serverURL,
                preferences: preferences
            )
            errorMessage = nil
        } catch {
            errorMessage = session.readableError(error)
        }
    }
}

private struct NotificationRowLink: View {
    let notification: NotificationResponse
    let onTap: () -> Void

    var body: some View {
        if let activityID = notification.payload.activityID {
            NavigationLink {
                ActivityDetailView(activityID: activityID)
                    .onAppear { onTap() }
            } label: {
                NotificationRow(notification: notification)
            }
        } else {
            NotificationRow(notification: notification)
                .contentShape(Rectangle())
                .onTapGesture { onTap() }
        }
    }
}

private struct NotificationRow: View {
    let notification: NotificationResponse

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: notification.notificationType.systemImage)
                .font(.title3)
                .frame(width: 36, height: 36)
                .foregroundStyle(iconColor)
                .background(iconColor.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(headline)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if !notification.isRead {
                        Circle()
                            .fill(AppTheme.accentTint)
                            .frame(width: 8, height: 8)
                    }
                }
                Text(bodyText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(ServerDate.dateTimeText(notification.createdAt))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private var iconColor: Color {
        switch notification.notificationType {
        case .newChannelMessage, .teacherChannelPost:
            AppTheme.accentTint
        case .activityStateChange:
            AppTheme.stateTint(for: .going)
        case .recordStateChange:
            AppTheme.stateTint(for: .ended)
        }
    }

    private var headline: String {
        switch notification.notificationType {
        case .newChannelMessage:
            notification.payload.senderName ?? notification.notificationType.title
        case .teacherChannelPost:
            if let senderName = notification.payload.senderName {
                "\(senderName) (teacher)"
            } else {
                notification.notificationType.title
            }
        case .activityStateChange, .recordStateChange:
            notification.payload.activityName ?? notification.notificationType.title
        }
    }

    private var bodyText: String {
        switch notification.notificationType {
        case .newChannelMessage, .teacherChannelPost:
            let activity = notification.payload.activityName.map { "#\($0) · " } ?? ""
            return activity + (notification.payload.messagePreview ?? "")
        case .activityStateChange:
            return "Moved to \(stateLabel(notification.payload.newState))"
        case .recordStateChange:
            return "Your record is now \(stateLabel(notification.payload.newState))"
        }
    }

    private func stateLabel(_ raw: String?) -> String {
        guard let raw else { return "updated" }
        return raw.replacingOccurrences(of: "_", with: " ")
    }
}
