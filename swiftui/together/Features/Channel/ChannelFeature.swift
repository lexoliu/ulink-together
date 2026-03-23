import SwiftUI

struct ActivityChannelView: View {
    @EnvironmentObject private var session: SessionStore

    let activity: ActivityDetail

    @State private var channel: ChannelResponse?
    @State private var messages: [ChannelMessage] = []
    @State private var senderNames: [String: String] = [:]
    @State private var composer = ""
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var pushTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            AppBackgroundView()

            VStack(spacing: 16) {
                if isLoading {
                    LoadingCard(title: "Loading channel")
                } else if !canAccessChannel {
                    EmptyStateCard(
                        title: "Join Required",
                        message: "Join this activity before opening its coordination room.",
                        systemImage: "lock.fill"
                    )
                } else if let channel {
                    VStack(alignment: .leading, spacing: 16) {
                        channelHeader(channel: channel)

                        if activity.state.channelIsReadOnly {
                            InlineErrorBanner(message: "This room is archived because the activity has already ended.")
                        }

                        if !session.canViewUserDetails {
                            InlineErrorBanner(message: "Sender names are limited on this account.")
                        }
                    }

                    messageTimeline
                } else {
                    EmptyStateCard(
                        title: "Channel unavailable",
                        message: "This activity room is not available yet.",
                        systemImage: "bubble.left.and.bubble.right"
                    )
                }
            }
            .frame(maxWidth: AppTheme.contentWidth, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)
        }
        .navigationTitle("Team Chat")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            if canAccessChannel {
                await load()
            }
        }
        .safeAreaInset(edge: .bottom) {
            if channel != nil {
                composerBar
            }
        }
        .task {
            if canAccessChannel {
                await load()
            } else {
                isLoading = false
            }
        }
        .onDisappear {
            pushTask?.cancel()
            pushTask = nil
        }
    }

    private var sortedMessages: [ChannelMessage] {
        messages.sorted { $0.datetime < $1.datetime }
    }

    private var canAccessChannel: Bool {
        activity.viewerParticipating || canManageActivity
    }

    private var canManageActivity: Bool {
        activity.promoter == session.currentUser?.id || session.canManageRecords || session.canCreateActivities
    }

    private func channelHeader(channel: ChannelResponse) -> some View {
        CardPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(channel.name)
                            .font(.title2.weight(.semibold))
                        Text(activity.name)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    StateChip(
                        title: activity.state.channelIsReadOnly ? "Archive" : "Live",
                        tint: activity.state.channelIsReadOnly ? AppTheme.neutralTint : AppTheme.accentTint
                    )
                }

                HStack(spacing: 10) {
                    StateChip(title: "\(channel.members.count) members", tint: AppTheme.neutralTint)
                    StateChip(title: activity.state.title, tint: AppTheme.stateTint(for: activity.state))
                }
            }
        }
    }

    private var messageTimeline: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if sortedMessages.isEmpty {
                        ContentUnavailableView(
                            "No Messages Yet",
                            systemImage: "message.badge.waveform",
                            description: Text("Updates and volunteer replies will appear here.")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else {
                        ForEach(Array(sortedMessages.enumerated()), id: \.element.id) { index, message in
                            if dayLabel(at: index) != dayLabel(at: index - 1) {
                                dayDivider(for: message.datetime)
                            }

                            MessageBubbleRow(
                                message: message,
                                isCurrentUser: session.isCurrentUser(id: message.sender),
                                senderName: senderLabel(for: message.sender)
                            )
                            .id(message.id)
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .onChange(of: sortedMessages.last?.id) { _, newValue in
                guard let newValue else {
                    return
                }

                withAnimation(.snappy) {
                    proxy.scrollTo(newValue, anchor: .bottom)
                }
            }
            .onAppear {
                if let lastID = sortedMessages.last?.id {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
        }
    }

    private var composerBar: some View {
        VStack(spacing: 0) {
            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text(activity.state.channelIsReadOnly ? "Channel archive" : "New message")
                    .font(.headline)

                TextField(
                    activity.state.channelIsReadOnly ? "This room is archived" : "Write an update for this activity",
                    text: $composer,
                    axis: .vertical
                )
                .lineLimit(1 ... 5)
                .textFieldStyle(.roundedBorder)
                .disabled(activity.state.channelIsReadOnly)

                if let errorMessage {
                    InlineErrorBanner(message: errorMessage)
                }

                HStack {
                    Text(activity.state.channelIsReadOnly ? "Read only" : "Visible to everyone in this activity room")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        Task {
                            await sendMessage()
                        }
                    } label: {
                        if session.demoData == nil && composer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Send")
                        } else {
                            Label("Send", systemImage: "arrow.up.circle.fill")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accentTint)
                    .disabled(activity.state.channelIsReadOnly || composer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .frame(maxWidth: AppTheme.contentWidth, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 12)
        }
        .background(.ultraThinMaterial)
    }

    private func dayDivider(for value: String) -> some View {
        HStack(spacing: 12) {
            Capsule()
                .fill(.quaternary)
                .frame(height: 1)
            Text(ServerDate.dateText(value))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Capsule()
                .fill(.quaternary)
                .frame(height: 1)
        }
        .padding(.vertical, 2)
    }

    private func dayLabel(at index: Int) -> String {
        guard sortedMessages.indices.contains(index) else {
            return ""
        }
        return ServerDate.dateText(sortedMessages[index].datetime)
    }

    private func senderLabel(for senderID: String) -> String {
        if session.isCurrentUser(id: senderID) {
            return "You"
        }
        if let demoName = session.demoDisplayName(for: senderID) {
            return demoName
        }
        if let senderName = senderNames[senderID] {
            return senderName
        }
        return "Member • \(DisplayText.shortIdentifier(senderID))"
    }

    private func load() async {
        if let demoData = session.demoData {
            channel = demoData.channelsByActivity[activity.id]
            if let channel {
                messages = demoData.messagesByChannel[channel.id] ?? []
                senderNames = demoData.userDisplayNames
            } else {
                messages = []
                senderNames = [:]
            }
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
            let channels = try await session.apiClient.fetchChannels(baseURL: serverURL, activityID: activity.id)
            channel = channels.first
            if let channel {
                messages = try await session.apiClient.fetchMessages(baseURL: serverURL, channelID: channel.id)
                await hydrateNamesIfNeeded(serverURL: serverURL)
                subscribeToPush(baseURL: serverURL, channelID: channel.id)
            } else {
                messages = []
                senderNames = [:]
                pushTask?.cancel()
                pushTask = nil
            }
            errorMessage = nil
        } catch {
            errorMessage = session.readableError(error)
        }
    }

    private func sendMessage() async {
        let content = composer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            return
        }

        if session.demoData != nil, let channel {
            messages.append(
                ChannelMessage(
                    id: UUID().uuidString,
                    channel: channel.id,
                    sender: session.currentUser?.id ?? "demo-user",
                    content: content,
                    datetime: "2026-03-13T12:15:00Z"
                )
            )
            composer = ""
            errorMessage = nil
            return
        }

        guard let serverURL = session.serverURL, let channel else {
            errorMessage = "The channel is unavailable."
            return
        }

        do {
            let message = try await session.apiClient.postMessage(baseURL: serverURL, channelID: channel.id, content: content)
            messages.append(message)
            composer = ""
            errorMessage = nil
        } catch {
            errorMessage = session.readableError(error)
        }
    }

    private func subscribeToPush(baseURL: URL, channelID: String) {
        pushTask?.cancel()
        pushTask = Task {
            do {
                let stream = await session.pushClient.stream(baseURL: baseURL)
                for try await event in stream {
                    guard event.name == "message" else {
                        continue
                    }
                    guard let data = event.data.data(using: .utf8) else {
                        continue
                    }

                    let pushed = try JSONDecoder().decode(ChannelMessage.self, from: data)
                    guard pushed.channel == channelID else {
                        continue
                    }

                    await MainActor.run {
                        if !messages.contains(where: { $0.id == pushed.id }) {
                            messages.append(pushed)
                        }
                    }

                    await hydrateNamesIfNeeded(serverURL: baseURL)
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        errorMessage = session.readableError(error)
                    }
                }
            }
        }
    }

    private func hydrateNamesIfNeeded(serverURL: URL) async {
        guard session.canViewUserDetails else {
            return
        }

        for senderID in Set(messages.map(\.sender)) where senderNames[senderID] == nil && !session.isCurrentUser(id: senderID) {
            do {
                let name = try await session.apiClient.loadDisplayNameIfPossible(baseURL: serverURL, userID: senderID)
                await MainActor.run {
                    senderNames[senderID] = name
                }
            } catch {
                await MainActor.run {
                    senderNames[senderID] = "Member • \(DisplayText.shortIdentifier(senderID))"
                }
            }
        }
    }
}

private struct MessageBubbleRow: View {
    let message: ChannelMessage
    let isCurrentUser: Bool
    let senderName: String

    var body: some View {
        HStack {
            if isCurrentUser {
                Spacer(minLength: 40)
            }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(senderName)
                        .font(.caption.weight(.semibold))
                    Text(ServerDate.dateTimeText(message.datetime))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(message.content)
                    .font(.body)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        isCurrentUser
                            ? AppTheme.accentTint.opacity(0.14)
                            : Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: AppTheme.compactCardRadius, style: .continuous)
                    )
            }

            if !isCurrentUser {
                Spacer(minLength: 40)
            }
        }
    }
}

#Preview("Channel") {
    NavigationStack {
        ActivityChannelView(
            activity: AppDemoData.organizer().activityDetails[AppDemoData.primaryActivityID]!
        )
    }
    .environmentObject(SessionStore.previewOrganizer())
}
