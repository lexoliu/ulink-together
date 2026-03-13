import Foundation
import EventSource

struct PushEvent: Sendable {
    let name: String
    let data: String
}

final actor PushClient {
    func stream(baseURL: URL) -> AsyncThrowingStream<PushEvent, Error> {
        let streamURL = ["api", "v1", "push"].reduce(baseURL) { partialResult, component in
            partialResult.appending(path: component)
        }

        return AsyncThrowingStream { continuation in
            let task = Task {
                let eventSource = EventSource()
                let dataTask = eventSource.dataTask(for: makeRequest(url: streamURL))

                for await event in dataTask.events() {
                    switch event {
                    case .open:
                        continue
                    case .closed:
                        continuation.finish()
                        return
                    case let .event(event):
                        continuation.yield(
                            PushEvent(
                                name: event.event ?? "message",
                                data: event.data ?? ""
                            )
                        )
                    case let .error(error):
                        continuation.finish(throwing: error)
                        return
                    }
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func makeRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        if let cookieHeader = HTTPCookieStorage.shared.cookies(for: url).flatMap({ cookies in
            HTTPCookie.requestHeaderFields(with: cookies)["Cookie"]
        }) {
            request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        }
        return request
    }
}
