import Alamofire
import Foundation

enum APIError: LocalizedError, Sendable {
    case invalidBaseURL
    case invalidResponse
    case http(statusCode: Int, message: String)
    case decoding(String)
    case transport(code: URLError.Code?, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            "Enter a valid service address."
        case .invalidResponse:
            "The service did not respond correctly. Make sure the Together server is running."
        case let .http(_, message):
            Self.normalizeServerMessage(message)
        case .decoding:
            "The address responded, but it did not look like a Together server."
        case let .transport(code, message):
            switch code {
            case .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed, .networkConnectionLost, .notConnectedToInternet, .timedOut:
                "Could not reach the service. Check the address and make sure the server is running."
            case .secureConnectionFailed, .serverCertificateHasBadDate, .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid, .serverCertificateUntrusted:
                "Could not establish a secure connection to the service."
            default:
                message
            }
        }
    }

    var isAuthorizationFailure: Bool {
        switch self {
        case let .http(statusCode, _):
            statusCode == 401 || statusCode == 403
        default:
            false
        }
    }

    static func normalizeServerMessage(_ message: String) -> String {
        let prefix = "Endpoint error: "
        var normalized = message.trimmingCharacters(in: .whitespacesAndNewlines)
        while normalized.hasPrefix(prefix) {
            normalized = String(normalized.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return normalized
    }
}

enum AppHTTPMethod: String, Sendable {
    case delete = "DELETE"
    case get = "GET"
    case post = "POST"
    case put = "PUT"

    var alamofireMethod: Alamofire.HTTPMethod {
        switch self {
        case .delete:
            .delete
        case .get:
            .get
        case .post:
            .post
        case .put:
            .put
        }
    }
}

struct APIClient: Sendable {
    private let decoder: JSONDecoder
    private let session: Session

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = HTTPCookieStorage.shared
        configuration.httpShouldSetCookies = true
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 10
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        self.decoder = JSONDecoder()
        self.session = Session(configuration: configuration)
    }

    func login(baseURL: URL, email: String, password: String) async throws {
        _ = try await request(
            baseURL: baseURL,
            path: "/login",
            method: .post,
            body: LoginRequest(email: email, password: password)
        ) as APIMessageResponse
    }

    func healthCheck(baseURL: URL) async throws {
        let response: ServiceHealthResponse = try await request(baseURL: baseURL, path: "/health")
        guard response.status == "ok" else {
            throw APIError.decoding("Unexpected health status.")
        }
    }

    func logout(baseURL: URL) async throws {
        _ = try await request(baseURL: baseURL, path: "/logout", method: .post) as APIMessageResponse
    }

    func deleteResource(baseURL: URL, filename: String) async throws {
        _ = try await request(baseURL: baseURL, path: "/resource/\(filename)", method: .delete) as APIMessageResponse
    }

    func register(baseURL: URL, request payload: RegisterRequest) async throws {
        _ = try await request(baseURL: baseURL, path: "/user", method: .post, body: payload) as APIMessageResponse
    }

    func uploadResource(
        baseURL: URL,
        filename: String,
        data: Data,
        mimeType: String?
    ) async throws -> ResourceCreatedResponse {
        let url = try makeURL(
            baseURL: baseURL,
            path: "/resource",
            queryItems: [URLQueryItem(name: "name", value: filename)]
        )
        var headers: HTTPHeaders = [.accept("application/json")]
        if let mimeType {
            headers.add(.contentType(mimeType))
        }

        let request = session.upload(data, to: url, method: .post, headers: headers)
        do {
            let response = await request.serializingData().response
            guard let httpResponse = response.response else {
                throw APIError.invalidResponse
            }
            let responseData = response.data ?? Data()
            guard (200 ..< 300).contains(httpResponse.statusCode) else {
                let message = decodeErrorMessage(from: responseData) ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
                throw APIError.http(statusCode: httpResponse.statusCode, message: message)
            }

            do {
                return try decoder.decode(ResourceCreatedResponse.self, from: responseData)
            } catch {
                throw APIError.decoding(error.localizedDescription)
            }
        } catch let error as APIError {
            throw error
        } catch let error as AFError {
            let urlError = error.underlyingError as? URLError
            throw APIError.transport(code: urlError?.code, message: error.localizedDescription)
        } catch {
            let urlError = error as? URLError
            throw APIError.transport(code: urlError?.code, message: error.localizedDescription)
        }
    }

    func fetchCurrentUser(baseURL: URL) async throws -> UserProfile {
        try await request(baseURL: baseURL, path: "/user/me")
    }

    func updateCurrentUser(baseURL: URL, request payload: UpdateUserRequest) async throws -> UserProfile {
        try await request(baseURL: baseURL, path: "/user/me", method: .put, body: payload)
    }

    func checkAuthority(baseURL: URL, authority: String) async throws -> Bool {
        let response: AuthorityCheckResponse = try await request(
            baseURL: baseURL,
            path: "/auth/check/\(authority)"
        )
        return response.result
    }

    func fetchActivities(
        baseURL: URL,
        user: String? = nil,
        displayAll: Bool
    ) async throws -> [ActivitySummary] {
        var queryItems = [URLQueryItem]()
        if let user {
            queryItems.append(URLQueryItem(name: "user", value: user))
        }
        if displayAll {
            queryItems.append(URLQueryItem(name: "display_all", value: "1"))
        }
        return try await request(baseURL: baseURL, path: "/activity", queryItems: queryItems)
    }

    func fetchActivity(baseURL: URL, activityID: String) async throws -> ActivityDetail {
        try await request(baseURL: baseURL, path: "/activity/\(activityID)")
    }

    func createActivity(baseURL: URL, request payload: CreateActivityRequest) async throws -> ActivityDetail {
        try await request(baseURL: baseURL, path: "/activity", method: .post, body: payload)
    }

    func updateActivity(
        baseURL: URL,
        activityID: String,
        request payload: CreateActivityRequest
    ) async throws -> ActivityDetail {
        try await request(baseURL: baseURL, path: "/activity/\(activityID)", method: .put, body: payload)
    }

    func applyActivity(baseURL: URL, activityID: String) async throws {
        _ = try await request(baseURL: baseURL, path: "/activity/\(activityID)/apply", method: .post) as APIMessageResponse
    }

    func withdrawActivity(baseURL: URL, activityID: String) async throws {
        _ = try await request(baseURL: baseURL, path: "/activity/\(activityID)/withdraw", method: .post) as APIMessageResponse
    }

    func transitionActivity(baseURL: URL, activityID: String, pathComponent: String) async throws {
        _ = try await request(
            baseURL: baseURL,
            path: "/activity/\(activityID)/\(pathComponent)",
            method: .post
        ) as APIMessageResponse
    }

    func fetchComments(baseURL: URL, activityID: String) async throws -> [CommentEntry] {
        try await request(baseURL: baseURL, path: "/activity/\(activityID)/comment")
    }

    func postComment(baseURL: URL, activityID: String, content: String) async throws -> CommentEntry {
        try await request(
            baseURL: baseURL,
            path: "/activity/\(activityID)/comment",
            method: .post,
            body: PostCommentRequest(content: content)
        )
    }

    func fetchChannels(baseURL: URL, activityID: String) async throws -> [ChannelResponse] {
        try await request(
            baseURL: baseURL,
            path: "/channel",
            queryItems: [URLQueryItem(name: "activity", value: activityID)]
        )
    }

    func createChannel(
        baseURL: URL,
        name: String,
        activityID: String
    ) async throws -> ChannelCreatedResponse {
        try await request(
            baseURL: baseURL,
            path: "/channel",
            method: .post,
            body: CreateChannelRequest(name: name, activity: activityID)
        )
    }

    func fetchMessages(baseURL: URL, channelID: String) async throws -> [ChannelMessage] {
        try await request(
            baseURL: baseURL,
            path: "/message",
            queryItems: [URLQueryItem(name: "channel", value: channelID)]
        )
    }

    func postMessage(
        baseURL: URL,
        channelID: String,
        content: String
    ) async throws -> ChannelMessage {
        try await request(
            baseURL: baseURL,
            path: "/channel/\(channelID)",
            method: .post,
            body: PostMessageRequest(content: content)
        )
    }

    func changePassword(
        baseURL: URL,
        currentPassword: String,
        newPassword: String
    ) async throws {
        _ = try await request(
            baseURL: baseURL,
            path: "/password/change",
            method: .post,
            body: ChangePasswordRequest(
                currentPassword: currentPassword,
                newPassword: newPassword
            )
        ) as APIMessageResponse
    }

    func requestPasswordReset(baseURL: URL, email: String) async throws -> String {
        let response: ResetPasswordRequestResult = try await request(
            baseURL: baseURL,
            path: "/password/reset/request",
            method: .post,
            body: ResetPasswordRequestPayload(email: email)
        )
        return response.code
    }

    func confirmPasswordReset(
        baseURL: URL,
        email: String,
        code: String,
        newPassword: String
    ) async throws {
        _ = try await request(
            baseURL: baseURL,
            path: "/password/reset/confirm",
            method: .post,
            body: ResetPasswordConfirmRequest(
                email: email,
                code: code,
                newPassword: newPassword
            )
        ) as APIMessageResponse
    }

    func fetchRecords(
        baseURL: URL,
        user: String? = nil,
        activity: String? = nil
    ) async throws -> [RecordEntry] {
        var queryItems = [URLQueryItem]()
        if let user {
            queryItems.append(URLQueryItem(name: "user", value: user))
        }
        if let activity {
            queryItems.append(URLQueryItem(name: "activity", value: activity))
        }
        return try await request(baseURL: baseURL, path: "/record", queryItems: queryItems)
    }

    func updateRecord(baseURL: URL, recordID: String, action: String) async throws {
        _ = try await request(
            baseURL: baseURL,
            path: "/record/\(recordID)/\(action)",
            method: .post
        ) as APIMessageResponse
    }

    func fetchLeaderboard(baseURL: URL) async throws -> [LeaderboardEntry] {
        try await request(baseURL: baseURL, path: "/leaderboard")
    }

    func generateExport(baseURL: URL) async throws -> ExportBatchResponse {
        try await request(baseURL: baseURL, path: "/export", method: .post)
    }

    func fetchNotifications(
        baseURL: URL,
        unreadOnly: Bool = false,
        limit: Int? = nil
    ) async throws -> [NotificationResponse] {
        var queryItems = [URLQueryItem]()
        if unreadOnly {
            queryItems.append(URLQueryItem(name: "unread_only", value: "1"))
        }
        if let limit {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        return try await request(baseURL: baseURL, path: "/notification", queryItems: queryItems)
    }

    func fetchNotificationUnreadCount(baseURL: URL) async throws -> Int {
        let response: NotificationUnreadCountResponse = try await request(
            baseURL: baseURL,
            path: "/notification/unread_count"
        )
        return response.count
    }

    func markNotificationsRead(baseURL: URL, ids: [String]) async throws {
        _ = try await request(
            baseURL: baseURL,
            path: "/notification/read",
            method: .post,
            body: MarkNotificationsReadRequest(ids: ids, all: nil)
        ) as APIMessageResponse
    }

    func markAllNotificationsRead(baseURL: URL) async throws {
        _ = try await request(
            baseURL: baseURL,
            path: "/notification/read",
            method: .post,
            body: MarkNotificationsReadRequest(ids: nil, all: true)
        ) as APIMessageResponse
    }

    func fetchNotificationPreferences(baseURL: URL) async throws -> [NotificationPreference] {
        try await request(baseURL: baseURL, path: "/notification/preferences")
    }

    func updateNotificationPreferences(
        baseURL: URL,
        preferences: [NotificationPreference]
    ) async throws {
        _ = try await request(
            baseURL: baseURL,
            path: "/notification/preferences",
            method: .put,
            body: UpdateNotificationPreferencesRequest(preferences: preferences)
        ) as APIMessageResponse
    }

    func loadDisplayNameIfPossible(baseURL: URL, userID: String) async throws -> String {
        let user: UserProfile = try await request(baseURL: baseURL, path: "/user/\(userID)")
        return user.realname
    }

    func avatarURL(baseURL: URL, path: String?) -> URL? {
        guard let path, !path.isEmpty else {
            return nil
        }
        if let directURL = URL(string: path), directURL.scheme != nil {
            return directURL
        }
        if path.hasPrefix("/") {
            return path
                .split(separator: "/")
                .reduce(baseURL) { partialResult, component in
                    partialResult.appending(path: String(component))
                }
        }
        return ["api", "v1", "resource"]
            .appending(path.split(separator: "/").map(String.init), to: baseURL)
    }

    private func request<Response: Decodable>(
        baseURL: URL,
        path: String,
        method: AppHTTPMethod = .get,
        queryItems: [URLQueryItem] = []
    ) async throws -> Response {
        try await request(
            baseURL: baseURL,
            path: path,
            method: method,
            queryItems: queryItems,
            body: Optional<String>.none
        )
    }

    private func request<Response: Decodable, Body: Encodable>(
        baseURL: URL,
        path: String,
        method: AppHTTPMethod = .get,
        queryItems: [URLQueryItem] = [],
        body: Body?
    ) async throws -> Response {
        let url = try makeURL(baseURL: baseURL, path: path, queryItems: queryItems)
        let headers: HTTPHeaders = [.accept("application/json")]
        let request: DataRequest
        if let body {
            request = session.request(
                url,
                method: method.alamofireMethod,
                parameters: body,
                encoder: JSONParameterEncoder.default,
                headers: headers
            )
        } else {
            request = session.request(url, method: method.alamofireMethod, headers: headers)
        }
        do {
            let response = await request.serializingData().response
            guard let httpResponse = response.response else {
                throw APIError.invalidResponse
            }
            let data = response.data ?? Data()
            guard (200 ..< 300).contains(httpResponse.statusCode) else {
                let message = decodeErrorMessage(from: data) ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
                throw APIError.http(statusCode: httpResponse.statusCode, message: message)
            }

            do {
                return try decoder.decode(Response.self, from: data)
            } catch {
                throw APIError.decoding(error.localizedDescription)
            }
        } catch let error as APIError {
            throw error
        } catch let error as AFError {
            let urlError = error.underlyingError as? URLError
            throw APIError.transport(code: urlError?.code, message: error.localizedDescription)
        } catch {
            let urlError = error as? URLError
            throw APIError.transport(code: urlError?.code, message: error.localizedDescription)
        }
    }

    private func makeURL(
        baseURL: URL,
        path: String,
        queryItems: [URLQueryItem]
    ) throws -> URL {
        guard var components = URLComponents(
            url: ["api", "v1"]
                .appending(
                    path
                        .split(separator: "/")
                        .map(String.init),
                    to: baseURL
                ),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.invalidBaseURL
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw APIError.invalidBaseURL
        }
        return url
    }

    private func decodeErrorMessage(from data: Data) -> String? {
        (try? decoder.decode(APIMessageResponse.self, from: data))?.message
    }
}

private extension Array where Element == String {
    func appending(_ extra: [String], to baseURL: URL) -> URL {
        (self + extra).reduce(baseURL) { partialResult, component in
            partialResult.appending(path: component)
        }
    }
}
