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
                LoadingCard(title: "Loading comments")
            } else if comments.isEmpty {
                EmptyStateCard(
                    title: "No comments yet",
                    message: "Be the first volunteer to ask a question or leave a planning note.",
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
                    Text("Add a comment")
                        .font(.headline)
                    TextField("Share a question or update", text: $composer, axis: .vertical)
                        .lineLimit(3 ... 6)
                        .textFieldStyle(.roundedBorder)

                    if let errorMessage {
                        InlineErrorBanner(message: errorMessage)
                    }

                    Button("Post Comment") {
                        Task {
                            await postComment()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(composer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .navigationTitle("Comments")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await load()
        }
    }

    private func load() async {
        guard let serverURL = session.serverURL else {
            isLoading = false
            errorMessage = "The server URL is invalid."
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
        guard let serverURL = session.serverURL else {
            errorMessage = "The server URL is invalid."
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
