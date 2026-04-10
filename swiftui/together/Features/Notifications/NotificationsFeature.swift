import SwiftUI

struct NotificationsHomeView: View {
    @EnvironmentObject private var session: SessionStore

    @State private var notifications: [NotificationResponse] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var pushTask: Task<Void, Never>?

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
                        NotificationRow(notification: notification)
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
            subscribeToPush()
        }
        .onDisappear {
            pushTask?.cancel()
            pushTask = nil
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
        } catch {
            errorMessage = session.readableError(error)
        }
    }

    private func markRead(_ ids: [String]) async {
        guard let serverURL = session.serverURL else { return }
        do {
            try await session.apiClient.markNotificationsRead(baseURL: serverURL, ids: ids)
            await load()
        } catch {
            errorMessage = session.readableError(error)
        }
    }

    private func markAllRead() async {
        guard let serverURL = session.serverURL else { return }
        do {
            try await session.apiClient.markAllNotificationsRead(baseURL: serverURL)
            await load()
        } catch {
            errorMessage = session.readableError(error)
        }
    }

    private func subscribeToPush() {
        guard let serverURL = session.serverURL else { return }
        pushTask?.cancel()
        pushTask = Task {
            do {
                let stream = await session.pushClient.stream(baseURL: serverURL)
                for try await event in stream {
                    guard event.name == "notification" else { continue }
                    await load()
                }
            } catch {
                // Swallow — push stream may be cancelled when view disappears
            }
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
