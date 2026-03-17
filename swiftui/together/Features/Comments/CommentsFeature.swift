import SwiftUI

struct CommentsView: View {
    @EnvironmentObject private var session: SessionStore

    let activityID: String

    @State private var comments: [CommentEntry] = []
    @State private var composer = ""
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        PageWidthReader {
            if isLoading {
                LoadingCard(title: "Loading public notes")
            } else if comments.isEmpty {
                EmptyStateCard(
                    title: "No public notes yet",
                    message: "Be the first to share an announcement or question for everyone.",
                    systemImage: "text.bubble"
                )
            } else {
                ForEach(comments) { comment in
                    CardPanel {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(comment.authorName)
                                    .font(.headline)
                                Spacer()
                                Text(ServerDate.dateTimeText(comment.date))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Text(comment.content)
                                .font(.body)
                        }
                    }
                }
            }

            CardPanel {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Add a public note")
                        .font(.headline)
                    TextField("Share an announcement or question", text: $composer, axis: .vertical)
                        .lineLimit(3 ... 6)
                        .textFieldStyle(.roundedBorder)

                    if let errorMessage {
                        InlineErrorBanner(message: errorMessage)
                    }

                    Button("Post Note") {
                        Task {
                            await postComment()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(composer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .navigationTitle("Public Notes")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await load()
        }
        .refreshable {
            await load()
        }
    }

    private func load() async {
        if let demoData = session.demoData {
            comments = demoData.commentsByActivity[activityID] ?? []
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
            comments = try await session.apiClient.fetchComments(baseURL: serverURL, activityID: activityID)
            errorMessage = nil
        } catch {
            errorMessage = session.readableError(error)
        }
    }

    private func postComment() async {
        if session.demoData != nil {
            let content = composer.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !content.isEmpty else {
                return
            }
            comments.insert(
                CommentEntry(
                    id: UUID().uuidString,
                    author: session.currentUser?.id ?? "demo-user",
                    authorName: session.currentUser?.realname ?? "You",
                    content: content,
                    date: "2026-03-13T12:00:00Z"
                ),
                at: 0
            )
            composer = ""
            errorMessage = nil
            return
        }

        guard let serverURL = session.serverURL else {
            errorMessage = "Enter a valid service address."
            return
        }
        let content = composer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            return
        }

        do {
            let created = try await session.apiClient.postComment(baseURL: serverURL, activityID: activityID, content: content)
            comments.insert(created, at: 0)
            composer = ""
            errorMessage = nil
        } catch {
            errorMessage = session.readableError(error)
        }
    }
}

#Preview("Comments") {
    NavigationStack {
        CommentsView(activityID: AppDemoData.primaryActivityID)
    }
    .environmentObject(SessionStore.previewVolunteer())
}
