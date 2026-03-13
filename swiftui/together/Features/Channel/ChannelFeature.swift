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

    var body: some View {
        PageWidthReader {
            if isLoading {
                LoadingCard(title: "Loading channel")
            } else if let channel {
                CardPanel {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(channel.name)
                            .font(.title3.weight(.semibold))
                        Text("Members: \(channel.members.count)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if !session.canViewUserDetails {
                    ContractNoteCard(
                        title: "Sender Names Limited by Authority",
                        message: "The message payload only includes sender ids. This screen resolves real names when the current account is allowed to view user details."
                    )
                }

                if messages.isEmpty {
                    EmptyStateCard(
                        title: "No messages yet",
                        message: "Start the activity conversation when timing, location, or last-minute changes need coordination.",
                        systemImage: "message"
                    )
                } else {
                    ForEach(messages.reversed()) { message in
                        CardPanel {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(senderLabel(for: message.sender))
                                        .font(.headline)
                                    Spacer()
                                    Text(ServerDate.dateTimeText(message.datetime))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                Text(message.content)
                            }
                        }
                    }
                }

                CardPanel {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Send a message")
                            .font(.headline)
                        TextField("Coordinate with the activity team", text: $composer, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2 ... 5)
                        if let errorMessage {
                            InlineErrorBanner(message: errorMessage)
                        }
                        Button("Send") {
                            Task {
                                await sendMessage()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(composer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            } else if session.canCreateChannels {
                EmptyStateCard(
                    title: "No activity channel yet",
                    message: "Create the activity chat when this event needs dedicated coordination.",
                    systemImage: "message.badge.circle"
                )

                CardPanel {
                    Button("Create Channel") {
                        Task {
                            await createChannel()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                EmptyStateCard(
                    title: "Channel unavailable",
                    message: "This activity does not have a channel yet, and the current account is not allowed to create one.",
                    systemImage: "bubble.left.and.bubble.right"
                )
            }
        }
        .navigationTitle("Channel")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await load()
        }
        .task {
            await load()
        }
    }

    private func senderLabel(for senderID: String) -> String {
        if session.isCurrentUser(id: senderID) {
            return "You"
        }
        if let senderName = senderNames[senderID] {
            return senderName
        }
        return "Member • \(DisplayText.shortIdentifier(senderID))"
    }

    private func load() async {
        guard let serverURL = session.serverURL else {
            errorMessage = "The server URL is invalid."
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
            } else {
                messages = []
            }
            errorMessage = nil
        } catch {
            errorMessage = session.readableError(error)
        }
    }

    private func createChannel() async {
        guard let serverURL = session.serverURL else {
            errorMessage = "The server URL is invalid."
            return
        }

        do {
            _ = try await session.apiClient.createChannel(
                baseURL: serverURL,
                name: "\(activity.name) Channel",
                activityID: activity.id
            )
            await load()
        } catch {
            errorMessage = session.readableError(error)
        }
    }

    private func sendMessage() async {
        guard let serverURL = session.serverURL, let channel else {
            errorMessage = "The channel is unavailable."
            return
        }
        let content = composer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
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

    private func hydrateNamesIfNeeded(serverURL: URL) async {
        guard session.canViewUserDetails else {
            return
        }

        for senderID in Set(messages.map(\.sender)) where senderNames[senderID] == nil && !session.isCurrentUser(id: senderID) {
            do {
                senderNames[senderID] = try await session.apiClient.loadDisplayNameIfPossible(baseURL: serverURL, userID: senderID)
            } catch {
                senderNames[senderID] = "Member • \(DisplayText.shortIdentifier(senderID))"
            }
        }
    }
}
