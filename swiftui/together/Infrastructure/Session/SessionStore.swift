import Combine
import Foundation

struct RegistrationAvatarUpload: Sendable {
    let filename: String
    let data: Data
    let mimeType: String?
}

@MainActor
final class SessionStore: ObservableObject {
    private enum LastErrorCategory {
        case connectivity
        case authentication
        case validation
        case general
    }

    enum RuntimeMode: Equatable, Sendable {
        case live
        case demoSignedOut
        case demoVolunteer
        case demoOrganizer
    }

    enum Phase: Sendable {
        case launching
        case signedOut
        case signedIn
    }

    let apiClient = APIClient()
    let pushClient = PushClient()
    let runtimeMode: RuntimeMode

    @Published var phase: Phase = .launching
    @Published var currentUser: UserProfile?
    @Published var lastError: String?
    @Published var authorityCache: [String: Bool] = [:]
    @Published var serverURLText: String
    @Published var isAuthenticating = false
    var demoData: AppDemoData?
    private var lastErrorCategory: LastErrorCategory?

    init(defaultServerURL: String? = nil, runtimeMode: RuntimeMode? = nil) {
        let resolvedMode = runtimeMode ?? Self.runtimeModeFromProcessInfo()
        self.runtimeMode = resolvedMode
        switch resolvedMode {
        case .live:
            self.serverURLText = UserDefaults.standard.string(forKey: Self.serverURLDefaultsKey)
                ?? defaultServerURL
                ?? AppEnvironment.bundledServerURL()
                ?? ""
            self.demoData = nil
        case .demoSignedOut:
            self.serverURLText = "http://demo.local"
            self.demoData = .signedOut()
        case .demoVolunteer:
            self.serverURLText = "http://demo.local"
            self.demoData = .volunteer()
        case .demoOrganizer:
            self.serverURLText = "http://demo.local"
            self.demoData = .organizer()
        }

        if let demoData {
            currentUser = demoData.currentUser
            authorityCache = demoData.authorities
            phase = demoData.currentUser == nil ? .signedOut : .signedIn
            clearLastError()
        }
    }

    var serverURL: URL? {
        try? Self.normalizeServerURL(from: serverURLText)
    }

    var hasConfiguredServerURL: Bool {
        serverURLText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var usesFixtureData: Bool {
        demoData != nil
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
        if let demoData {
            currentUser = demoData.currentUser
            authorityCache = demoData.authorities
            phase = demoData.currentUser == nil ? .signedOut : .signedIn
            clearLastError()
            return
        }

        guard let serverURL else {
            phase = .signedOut
            setLastError("Enter a valid service address to continue.", category: .validation)
            return
        }

        do {
            currentUser = try await apiClient.fetchCurrentUser(baseURL: serverURL)
            phase = .signedIn
            clearLastError()
            await refreshAuthorities()
        } catch let error as APIError {
            phase = .signedOut
            currentUser = nil
            authorityCache = [:]
            if !error.isAuthorizationFailure {
                setLastError(error.errorDescription, category: .connectivity)
            }
        } catch {
            phase = .signedOut
            currentUser = nil
            authorityCache = [:]
            setLastError(error.localizedDescription, category: .general)
        }
    }

    func signIn(email: String, password: String) async -> Bool {
        if runtimeMode == .demoSignedOut {
            let demoData = AppDemoData.volunteer()
            self.demoData = demoData
            currentUser = demoData.currentUser
            authorityCache = demoData.authorities
            phase = .signedIn
            clearLastError()
            return true
        }
        if let demoData {
            currentUser = demoData.currentUser
            authorityCache = demoData.authorities
            phase = demoData.currentUser == nil ? .signedOut : .signedIn
            clearLastError()
            return demoData.currentUser != nil
        }

        guard let serverURL else {
            setLastError("Enter a valid service address before signing in.", category: .validation)
            return false
        }

        clearLastError()
        isAuthenticating = true
        defer {
            isAuthenticating = false
        }

        do {
            try await apiClient.healthCheck(baseURL: serverURL)
        } catch {
            setLastError(readableHealthCheckError(error), category: .connectivity)
            return false
        }

        do {
            try await apiClient.login(baseURL: serverURL, email: email, password: password)
        } catch {
            setLastError(readableAuthenticationError(error), category: .authentication)
            return false
        }

        do {
            currentUser = try await apiClient.fetchCurrentUser(baseURL: serverURL)
            phase = .signedIn
            clearLastError()
            await refreshAuthorities()
            return true
        } catch {
            setLastError(readableError(error), category: .general)
            return false
        }
    }

    func registerAndSignIn(
        request: RegisterRequest,
        avatarUpload: RegistrationAvatarUpload? = nil
    ) async -> Bool {
        if runtimeMode == .demoSignedOut {
            let demoData = AppDemoData.volunteer()
            self.demoData = demoData
            currentUser = demoData.currentUser
            authorityCache = demoData.authorities
            phase = .signedIn
            clearLastError()
            return true
        }
        if let demoData {
            currentUser = demoData.currentUser
            authorityCache = demoData.authorities
            phase = demoData.currentUser == nil ? .signedOut : .signedIn
            clearLastError()
            return demoData.currentUser != nil
        }

        guard let serverURL else {
            setLastError("Enter a valid service address before creating an account.", category: .validation)
            return false
        }

        clearLastError()
        isAuthenticating = true
        defer {
            isAuthenticating = false
        }

        do {
            try await apiClient.healthCheck(baseURL: serverURL)
        } catch {
            setLastError(readableHealthCheckError(error), category: .connectivity)
            return false
        }

        do {
            try await apiClient.register(baseURL: serverURL, request: request)
            try await apiClient.login(baseURL: serverURL, email: request.email, password: request.password)
            if let avatarUpload {
                let uploaded = try await apiClient.uploadResource(
                    baseURL: serverURL,
                    filename: avatarUpload.filename,
                    data: avatarUpload.data,
                    mimeType: avatarUpload.mimeType
                )
                _ = try await apiClient.updateCurrentUser(
                    baseURL: serverURL,
                    request: UpdateUserRequest(
                        realname: nil,
                        gender: nil,
                        description: nil,
                        classname: nil,
                        avatar: uploaded.path
                    )
                )
            }
            currentUser = try await apiClient.fetchCurrentUser(baseURL: serverURL)
            phase = .signedIn
            clearLastError()
            await refreshAuthorities()
            return true
        } catch {
            setLastError(readableError(error), category: .general)
            return false
        }
    }

    func refreshCurrentUser() async {
        if let demoData {
            currentUser = demoData.currentUser
            clearLastError()
            return
        }

        guard let serverURL else {
            return
        }

        do {
            currentUser = try await apiClient.fetchCurrentUser(baseURL: serverURL)
        } catch {
            setLastError(readableError(error), category: .general)
        }
    }

    func refreshAuthorities() async {
        if let demoData {
            authorityCache = demoData.authorities
            return
        }

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
        if demoData != nil {
            guard let existingUser = currentUser else {
                setLastError("No current user exists in demo mode.", category: .general)
                return false
            }
            currentUser = UserProfile(
                id: existingUser.id,
                email: existingUser.email,
                realname: request.realname ?? existingUser.realname,
                gender: request.gender ?? existingUser.gender,
                description: request.description ?? existingUser.description,
                classname: request.classname ?? existingUser.classname,
                avatar: request.avatar ?? existingUser.avatar,
                group: existingUser.group
            )
            clearLastError()
            return true
        }

        guard let serverURL else {
            setLastError("Enter a valid service address before updating your profile.", category: .validation)
            return false
        }

        do {
            currentUser = try await apiClient.updateCurrentUser(baseURL: serverURL, request: request)
            clearLastError()
            return true
        } catch {
            setLastError(readableError(error), category: .general)
            return false
        }
    }

    func logout() async {
        if demoData != nil {
            resetSession()
            return
        }

        guard let serverURL else {
            resetSession()
            return
        }

        do {
            try await apiClient.logout(baseURL: serverURL)
        } catch {
            setLastError(readableError(error), category: .general)
        }
        resetSession()
    }

    func updateServerURL(_ value: String) {
        guard runtimeMode == .live else {
            serverURLText = value.trimmingCharacters(in: .whitespacesAndNewlines)
            clearLastError()
            return
        }
        serverURLText = value.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(serverURLText, forKey: Self.serverURLDefaultsKey)
        clearLastError()
    }

    func clearLastError() {
        setLastError(nil)
    }

    func revalidateServiceAddressIfNeeded() async {
        guard runtimeMode == .live,
              phase == .signedOut,
              lastErrorCategory == .connectivity,
              let serverURL else {
            return
        }

        do {
            try await apiClient.healthCheck(baseURL: serverURL)
            clearLastError()
        } catch {
            setLastError(readableHealthCheckError(error), category: .connectivity)
        }
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

    private func readableHealthCheckError(_ error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case let .http(statusCode, _):
                if statusCode == 404 {
                    return "The address responded, but it is not a Together server."
                }
                return readableError(apiError)
            case .decoding, .invalidResponse:
                return "The address responded, but it is not a Together server."
            default:
                return readableError(apiError)
            }
        }
        return readableError(error)
    }

    private func readableAuthenticationError(_ error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case let .http(statusCode, message):
                let normalized = APIError.normalizeServerMessage(message)
                if statusCode == 403 || statusCode == 404 {
                    if normalized == "Wrong email or password" || normalized == "User not exists" {
                        return "Wrong email or password."
                    }
                }
                return normalized
            default:
                return readableError(apiError)
            }
        }
        return readableError(error)
    }

    private func setLastError(_ message: String?, category: LastErrorCategory? = nil) {
        lastError = message
        lastErrorCategory = message == nil ? nil : category
    }

    func isCurrentUser(id: String) -> Bool {
        currentUser?.id == id
    }

    func hasAuthority(_ authority: String) -> Bool {
        authorityCache[authority] == true
    }

    func demoDisplayName(for userID: String) -> String? {
        demoData?.userDisplayNames[userID]
    }

    func participantName(for userID: String) -> String? {
        if currentUser?.id == userID {
            return "You"
        }
        return demoData?.userDisplayNames[userID]
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

    private static func runtimeModeFromProcessInfo() -> RuntimeMode {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-demo-signed-out") {
            return .demoSignedOut
        }
        if arguments.contains("-demo-volunteer") {
            return .demoVolunteer
        }
        if arguments.contains("-demo-organizer") {
            return .demoOrganizer
        }
        return .live
    }

    private static let serverURLDefaultsKey = "server_base_url"
}

extension SessionStore {
    static func previewSignedOut() -> SessionStore {
        SessionStore(runtimeMode: .demoSignedOut)
    }

    static func previewVolunteer() -> SessionStore {
        SessionStore(runtimeMode: .demoVolunteer)
    }

    static func previewOrganizer() -> SessionStore {
        SessionStore(runtimeMode: .demoOrganizer)
    }
}
