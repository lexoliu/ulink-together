import Combine
import Foundation

@MainActor
final class SessionStore: ObservableObject {
    enum Phase: Sendable {
        case launching
        case signedOut
        case signedIn
    }

    let apiClient = APIClient()

    @Published var phase: Phase = .launching
    @Published var currentUser: UserProfile?
    @Published var lastError: String?
    @Published var authorityCache: [String: Bool] = [:]
    @Published var serverURLText: String
    @Published var isAuthenticating = false

    init(defaultServerURL: String = "http://127.0.0.1:8000") {
        self.serverURLText = UserDefaults.standard.string(forKey: Self.serverURLDefaultsKey) ?? defaultServerURL
    }

    var serverURL: URL? {
        try? Self.normalizeServerURL(from: serverURLText)
    }

    var canCreateActivities: Bool {
        authorityCache["create_activity"] == true
    }

    var canCreateChannels: Bool {
        authorityCache["create_channel"] == true
    }

    var canManageRecords: Bool {
        authorityCache["manage_record_anyway"] == true
    }

    var canGenerateExport: Bool {
        authorityCache["generate_export"] == true
    }

    var canViewUserDetails: Bool {
        authorityCache["view_user"] == true
    }

    var showsManageTab: Bool {
        canCreateActivities || canManageRecords
    }

    func bootstrap() async {
        guard let serverURL else {
            phase = .signedOut
            lastError = "Enter a valid server URL to connect the app."
            return
        }

        do {
            currentUser = try await apiClient.fetchCurrentUser(baseURL: serverURL)
            phase = .signedIn
            lastError = nil
            await refreshAuthorities()
        } catch let error as APIError {
            phase = .signedOut
            currentUser = nil
            authorityCache = [:]
            if !error.isAuthorizationFailure {
                lastError = error.errorDescription
            }
        } catch {
            phase = .signedOut
            currentUser = nil
            authorityCache = [:]
            lastError = error.localizedDescription
        }
    }

    func signIn(email: String, password: String) async -> Bool {
        guard let serverURL else {
            lastError = "Enter a valid server URL before signing in."
            return false
        }

        isAuthenticating = true
        defer {
            isAuthenticating = false
        }

        do {
            try await apiClient.login(baseURL: serverURL, email: email, password: password)
            currentUser = try await apiClient.fetchCurrentUser(baseURL: serverURL)
            phase = .signedIn
            lastError = nil
            await refreshAuthorities()
            return true
        } catch {
            lastError = readableError(error)
            return false
        }
    }

    func registerAndSignIn(request: RegisterRequest) async -> Bool {
        guard let serverURL else {
            lastError = "Enter a valid server URL before creating an account."
            return false
        }

        isAuthenticating = true
        defer {
            isAuthenticating = false
        }

        do {
            try await apiClient.register(baseURL: serverURL, request: request)
            try await apiClient.login(baseURL: serverURL, email: request.email, password: request.password)
            currentUser = try await apiClient.fetchCurrentUser(baseURL: serverURL)
            phase = .signedIn
            lastError = nil
            await refreshAuthorities()
            return true
        } catch {
            lastError = readableError(error)
            return false
        }
    }

    func refreshCurrentUser() async {
        guard let serverURL else {
            return
        }

        do {
            currentUser = try await apiClient.fetchCurrentUser(baseURL: serverURL)
        } catch {
            lastError = readableError(error)
        }
    }

    func refreshAuthorities() async {
        guard let serverURL else {
            authorityCache = [:]
            return
        }

        let authorities = [
            "create_activity",
            "create_channel",
            "send_comment",
            "send_message_anyway",
            "manage_record_anyway",
            "view_user",
            "generate_export",
        ]

        var nextCache: [String: Bool] = [:]
        for authority in authorities {
            do {
                nextCache[authority] = try await apiClient.checkAuthority(baseURL: serverURL, authority: authority)
            } catch {
                nextCache[authority] = false
            }
        }
        authorityCache = nextCache
    }

    func updateCurrentUser(request: UpdateUserRequest) async -> Bool {
        guard let serverURL else {
            lastError = "Enter a valid server URL before updating your profile."
            return false
        }

        do {
            currentUser = try await apiClient.updateCurrentUser(baseURL: serverURL, request: request)
            lastError = nil
            return true
        } catch {
            lastError = readableError(error)
            return false
        }
    }

    func logout() async {
        guard let serverURL else {
            resetSession()
            return
        }

        do {
            try await apiClient.logout(baseURL: serverURL)
        } catch {
            lastError = readableError(error)
        }
        resetSession()
    }

    func updateServerURL(_ value: String) {
        serverURLText = value.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(serverURLText, forKey: Self.serverURLDefaultsKey)
    }

    func reconnect() async {
        phase = .launching
        await bootstrap()
    }

    func readableError(_ error: Error) -> String {
        if let apiError = error as? APIError, let description = apiError.errorDescription {
            return description
        }
        if let localizedError = error as? LocalizedError, let description = localizedError.errorDescription {
            return description
        }
        return error.localizedDescription
    }

    func isCurrentUser(id: String) -> Bool {
        currentUser?.id == id
    }

    func hasAuthority(_ authority: String) -> Bool {
        authorityCache[authority] == true
    }

    static func normalizeServerURL(from value: String) throws -> URL {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw APIError.invalidBaseURL
        }
        guard var components = URLComponents(string: trimmed), components.scheme != nil else {
            throw APIError.invalidBaseURL
        }
        if components.path == "/api/v1" {
            components.path = ""
        } else if components.path.hasSuffix("/api/v1") {
            components.path = String(components.path.dropLast("/api/v1".count))
        }
        if components.path == "/" {
            components.path = ""
        }
        guard let url = components.url else {
            throw APIError.invalidBaseURL
        }
        return url
    }

    private func resetSession() {
        phase = .signedOut
        currentUser = nil
        authorityCache = [:]
    }

    private static let serverURLDefaultsKey = "server_base_url"
}
