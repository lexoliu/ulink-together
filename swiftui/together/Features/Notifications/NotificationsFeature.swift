import SwiftUI

struct NotificationsHomeView: View {
    @EnvironmentObject private var session: SessionStore

    @State private var notifications: [NotificationEntry] = []
    @State private var isLoading = true
    @State private var markingID: String?
    @State private var markAllPending = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if notifications.isEmpty {
                ContentUnavailableView(
                    "No Notifications",
                    systemImage: "bell.slash",
                    description: Text("You're all caught up.")
                )
            } else {
                ForEach(notifications) { notification in
                    HStack(alignment: .top, spacing: 12) {
                        if notification.readAt == nil {
                            Circle()
                                .fill(AppTheme.accentTint)
                                .frame(width: 8, height: 8)
                                .padding(.top, 7)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(notification.title)
                                .font(notification.readAt == nil ? .headline : .subheadline.weight(.medium))
                            Text(notification.content)
                                .font(.subheadline)
                                .foregroundStyle(notification.readAt == nil ? .primary : .secondary)
                                .lineLimit(3)
                            Text(ServerDate.dateTimeText(notification.createdAt))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        if notification.readAt == nil {
                            Button {
                                Task { await markRead(notificationID: notification.id) }
                            } label: {
                                Label("Read", systemImage: "envelope.open")
                            }
                            .tint(AppTheme.accentTint)
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
        .navigationTitle("Notifications")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await markAllRead() }
                } label: {
                    Text(markAllPending ? "Marking..." : "Read All")
                }
                .disabled(markAllPending || notifications.isEmpty || notifications.allSatisfy { $0.readAt != nil })
            }
        }
        .task {
            await load()
        }
        .refreshable {
            await load()
        }
    }

    private func load() async {
        if session.demoData != nil {
            notifications = []
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
            notifications = try await session.apiClient.fetchNotifications(baseURL: serverURL)
            errorMessage = nil
        } catch {
            errorMessage = session.readableError(error)
        }
    }

    private func markRead(notificationID: String) async {
        guard let serverURL = session.serverURL else {
            errorMessage = "Enter a valid service address."
            return
        }

        markingID = notificationID
        defer {
            markingID = nil
        }

        do {
            try await session.apiClient.markNotificationRead(
                baseURL: serverURL,
                notificationID: notificationID
            )
            await load()
        } catch {
            errorMessage = session.readableError(error)
        }
    }

    private func markAllRead() async {
        guard let serverURL = session.serverURL else {
            errorMessage = "Enter a valid service address."
            return
        }

        markAllPending = true
        defer {
            markAllPending = false
        }

        do {
            try await session.apiClient.markAllNotificationsRead(baseURL: serverURL)
            await load()
        } catch {
            errorMessage = session.readableError(error)
        }
    }
}

#Preview("Notifications") {
    NavigationStack {
        NotificationsHomeView()
    }
    .environmentObject(SessionStore.previewVolunteer())
}
