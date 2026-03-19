import SwiftUI

struct NotificationsHomeView: View {
    @EnvironmentObject private var session: SessionStore

    @State private var notifications: [NotificationEntry] = []
    @State private var isLoading = true
    @State private var markingID: String?
    @State private var markAllPending = false
    @State private var errorMessage: String?

    var body: some View {
        PageWidthReader {
            if isLoading {
                LoadingCard(title: "Loading notifications")
            } else if notifications.isEmpty {
                EmptyStateCard(
                    title: "No notifications yet",
                    message: "When teachers send updates, they will appear here.",
                    systemImage: "bell.slash"
                )
            } else {
                ForEach(notifications) { notification in
                    CardPanel {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(notification.title)
                                        .font(.headline)
                                    Text(ServerDate.dateTimeText(notification.createdAt))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if notification.readAt == nil {
                                    Button(markingID == notification.id ? "Marking..." : "Mark Read") {
                                        Task {
                                            await markRead(notificationID: notification.id)
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(markingID == notification.id)
                                } else {
                                    Label("Read", systemImage: "checkmark.circle.fill")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.green)
                                }
                            }

                            Text(notification.content)
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            CardPanel {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Notification Actions")
                        .font(.headline)
                    Button(markAllPending ? "Marking..." : "Mark All Read") {
                        Task {
                            await markAllRead()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(markAllPending || notifications.isEmpty)
                }
            }

            if let errorMessage {
                InlineErrorBanner(message: errorMessage)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.large)
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
