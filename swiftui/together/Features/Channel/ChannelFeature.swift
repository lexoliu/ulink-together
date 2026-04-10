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
        Group {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !canAccessChannel {
                ContentUnavailableView(
                    "Join Required",
                    systemImage: "lock.fill",
                    description: Text("Apply to the activity to join the team chat.")
                )
            } else if channel != nil {
                messageTimeline
            } else {
                ContentUnavailableView(
                    "Channel Unavailable",
                    systemImage: "bubble.left.and.bubble.right"
                )
            }
        }
        .navigationTitle(activity.name)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            if canAccessChannel {
                await load()
            }
        }
        .safeAreaInset(edge: .bottom) {
            if channel != nil && !activity.state.channelIsReadOnly {
                composerBar
            } else if channel != nil {
                archivedFooter
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

    private var messageTimeline: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if sortedMessages.isEmpty {
                        ContentUnavailableView(
                            "No Messages Yet",
                            systemImage: "message",
                            description: Text("Be the first to say hello.")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 80)
                    } else {
                        let grouped = groupedMessages
                        ForEach(Array(grouped.enumerated()), id: \.offset) { index, group in
                            if index == 0 || grouped[index - 1].dayLabel != group.dayLabel {
                                DayDivider(label: group.dayLabel)
                                    .padding(.vertical, 8)
                            }
                            MessageGroupView(
                                group: group,
                                isCurrentUser: session.isCurrentUser(id: group.senderID),
                                senderName: senderLabel(for: group.senderID)
                            )
                            .id(group.firstID)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .onChange(of: sortedMessages.last?.id) { _, newValue in
                guard let newValue else { return }
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

    private var groupedMessages: [MessageGroup] {
        var groups: [MessageGroup] = []
        for message in sortedMessages {
            let day = ServerDate.dateText(message.datetime)
            if let last = groups.last,
               last.senderID == message.sender,
               last.dayLabel == day,
               minutesBetween(last.lastTimestamp, message.datetime) < 5 {
                var updated = last
                updated.messages.append(message)
                updated.lastTimestamp = message.datetime
                groups[groups.count - 1] = updated
            } else {
                groups.append(
                    MessageGroup(
                        senderID: message.sender,
                        dayLabel: day,
                        firstID: message.id,
                        firstTimestamp: message.datetime,
                        lastTimestamp: message.datetime,
                        messages: [message]
                    )
                )
            }
        }
        return groups
    }

    private func minutesBetween(_ lhs: String, _ rhs: String) -> Int {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let left = formatter.date(from: lhs) ?? ISO8601DateFormatter().date(from: lhs)
        let right = formatter.date(from: rhs) ?? ISO8601DateFormatter().date(from: rhs)
        guard let left, let right else { return 999 }
        return Int(right.timeIntervalSince(left) / 60)
    }

    private var composerBar: some View {
        HStack(spacing: 10) {
            TextField("Message", text: $composer, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1 ... 5)

            Button {
                Task { await sendMessage() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
                    .foregroundStyle(canSend ? AppTheme.accentTint : Color.gray.opacity(0.5))
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var archivedFooter: some View {
        Text("This channel is archived.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.bar)
    }

    private var canSend: Bool {
        !composer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !activity.state.channelIsReadOnly
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
        return "Member"
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
        defer { isLoading = false }

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
        guard !content.isEmpty else { return }

        if session.demoData != nil, let channel {
            messages.append(
                ChannelMessage(
                    id: UUID().uuidString,
                    channel: channel.id,
                    sender: session.currentUser?.id ?? "demo-user",
                    content: content,
                    datetime: "2026-04-10T12:15:00Z"
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
                    guard event.name == "message" else { continue }
                    guard let data = event.data.data(using: .utf8) else { continue }

                    let pushed = try JSONDecoder().decode(ChannelMessage.self, from: data)
                    guard pushed.channel == channelID else { continue }

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
        guard session.canViewUserDetails else { return }

        for senderID in Set(messages.map(\.sender)) where senderNames[senderID] == nil && !session.isCurrentUser(id: senderID) {
            do {
                let name = try await session.apiClient.loadDisplayNameIfPossible(baseURL: serverURL, userID: senderID)
                await MainActor.run {
                    senderNames[senderID] = name
                }
            } catch {
                await MainActor.run {
                    senderNames[senderID] = "Member"
                }
            }
        }
    }
}

private struct MessageGroup {
    let senderID: String
    let dayLabel: String
    let firstID: String
    let firstTimestamp: String
    var lastTimestamp: String
    var messages: [ChannelMessage]
}

private struct MessageGroupView: View {
    let group: MessageGroup
    let isCurrentUser: Bool
    let senderName: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(avatarColor)
                .overlay(
                    Text(senderInitial)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                )
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(senderName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isCurrentUser ? AppTheme.accentTint : .primary)
                    Text(ServerDate.dateTimeText(group.firstTimestamp))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                ForEach(group.messages, id: \.id) { message in
                    Text(message.content)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var senderInitial: String {
        guard let first = senderName.first else { return "?" }
        return String(first).uppercased()
    }

    private var avatarColor: Color {
        let hash = senderName.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let palette: [Color] = [
            .blue, .purple, .pink, .orange, .teal, .indigo, .mint, .cyan,
        ]
        return palette[hash % palette.count]
    }
}

private struct DayDivider: View {
    let label: String

    var body: some View {
        HStack(spacing: 10) {
            Rectangle().fill(.quaternary).frame(height: 1)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Rectangle().fill(.quaternary).frame(height: 1)
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
