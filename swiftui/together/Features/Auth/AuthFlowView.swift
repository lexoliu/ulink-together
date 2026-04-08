import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
#endif

private enum AuthMode: String, CaseIterable, Identifiable {
    case login
    case register

    var id: String { rawValue }

    var title: String {
        switch self {
        case .login:
            "Sign In"
        case .register:
            "Create Account"
        }
    }

    var actionTitle: String {
        switch self {
        case .login:
            "Sign In"
        case .register:
            "Create Account"
        }
    }
}

private enum AuthStep: Int, CaseIterable, Identifiable {
    case serviceAddress
    case credentials

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .serviceAddress:
            "Service address"
        case .credentials:
            "Account"
        }
    }
}

struct AuthFlowView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.scenePhase) private var scenePhase

    @State private var step: AuthStep
    @State private var mode: AuthMode
    @State private var loginEmail = ""
    @State private var loginPassword = ""

    @State private var registerEmail = ""
    @State private var registerRealname = ""
    @State private var registerGender = "Prefer not to say"
    @State private var registerClassname = ""
    @State private var registerPassword = ""
    @State private var registerConfirmPassword = ""
    @State private var selectedRegisterAvatarItem: PhotosPickerItem?
    @State private var pendingRegisterAvatarUpload: RegistrationAvatarUpload?
    @State private var isLoadingRegisterAvatar = false
    @State private var showingPasswordReset = false
    @State private var localError: String?
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case serviceAddress
        case loginEmail
        case loginPassword
        case registerEmail
        case registerRealname
        case registerClassname
        case registerPassword
        case registerConfirmPassword
    }

    private let genders = [
        "Female",
        "Male",
        "Prefer not to say",
    ]

    init() {
        _step = State(initialValue: AppEnvironment.hasBundledServerURL ? .credentials : .serviceAddress)
        _mode = State(initialValue: .login)
    }

    fileprivate init(previewStep: AuthStep, previewMode: AuthMode = .login) {
        _step = State(initialValue: previewStep)
        _mode = State(initialValue: previewMode)
    }

    var body: some View {
        ZStack {
            AuthSceneBackground()

            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        stepIndicator
                        formPanel
                    }
                    .frame(maxWidth: 760, alignment: .leading)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: proxy.size.height - 48, alignment: .center)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 24)
                }
                .scrollIndicators(.hidden)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .animation(.snappy, value: step)
        .onChange(of: mode) { _, _ in
            localError = nil
            session.clearLastError()
            guard step == .credentials else {
                return
            }
            focusedField = mode == .login ? .loginEmail : .registerEmail
        }
        .onChange(of: selectedRegisterAvatarItem) { _, newValue in
            Task {
                await loadRegisterAvatarSelection(from: newValue)
            }
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else {
                return
            }
            Task {
                await session.revalidateServiceAddressIfNeeded()
            }
        }
        .onAppear {
            if session.usesBundledServerURL && step == .serviceAddress {
                step = .credentials
            }
        }
        .sheet(isPresented: $showingPasswordReset) {
            PasswordResetSheet()
                .environmentObject(session)
        }
    }

    private var stepIndicator: some View {
        Group {
            if visibleSteps.count > 1 {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 14) {
                        ForEach(visibleSteps) { authStep in
                            authStepBadge(for: authStep)
                        }
                    }

                    VStack(spacing: 12) {
                        ForEach(visibleSteps) { authStep in
                            authStepBadge(for: authStep)
                        }
                    }
                }
            }
        }
    }

    private var formPanel: some View {
        CardPanel {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    if let stepIndexTitle {
                        Text(stepIndexTitle)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.accentTint)
                            .textCase(.uppercase)
                            .tracking(1.1)
                    }

                    Text(step.title)
                        .font(.title2.weight(.bold))
                }

                if let message = localError ?? session.lastError {
                    InlineErrorBanner(message: message)
                }

                switch step {
                case .serviceAddress:
                    serviceAddressStep
                case .credentials:
                    credentialsStep
                }
            }
        }
    }

    private var serviceAddressStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            AuthFieldShell(
                title: "Service address",
                isFocused: focusedField == .serviceAddress
            ) {
                TextField(
                    "https://volunteer.ulink.edu.cn",
                    text: Binding(
                        get: { session.serverURLText },
                        set: { session.updateServerURL($0) }
                    )
                )
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .serviceAddress)
            }

            Button {
                advanceToCredentials()
            } label: {
                submitLabel(title: "Next")
            }
            .buttonStyle(AuthPrimaryButtonStyle())
        }
        .onAppear {
            focusedField = .serviceAddress
        }
    }

    private var credentialsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            if session.usesBundledServerURL == false {
                confirmedAddressPanel
            }

            Picker("Authentication", selection: $mode) {
                ForEach(AuthMode.allCases) { authMode in
                    Text(authMode.title).tag(authMode)
                }
            }
            .pickerStyle(.segmented)
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(uiColor: .tertiarySystemGroupedBackground))
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(mode.title)
                    .font(.title2.weight(.semibold))
            }

            switch mode {
            case .login:
                loginForm
            case .register:
                registerForm
            }
        }
    }

    private var confirmedAddressPanel: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(session.serverURLText)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if session.usesBundledServerURL == false {
                Button("Change") {
                    localError = nil
                    session.clearLastError()
                    step = .serviceAddress
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .systemBackground).opacity(0.72))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(AppTheme.accentTint.opacity(0.12), lineWidth: 1)
        }
    }

    private var loginForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            AuthFieldShell(title: "School email", isFocused: focusedField == .loginEmail) {
                TextField("Enter your school email", text: $loginEmail)
                    .textInputAutocapitalization(.never)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .loginEmail)
            }

            AuthFieldShell(title: "Password", isFocused: focusedField == .loginPassword) {
                SecureField("Enter password", text: $loginPassword)
                    .textContentType(.password)
                    .focused($focusedField, equals: .loginPassword)
            }

            Button {
                localError = validateLogin()
                guard localError == nil else {
                    return
                }
                Task {
                    _ = await session.signIn(email: loginEmail, password: loginPassword)
                }
            } label: {
                submitLabel(title: AuthMode.login.actionTitle)
            }
            .buttonStyle(AuthPrimaryButtonStyle())
            .disabled(session.isAuthenticating)

            Button("Forgot password?") {
                showingPasswordReset = true
            }
            .font(.footnote.weight(.semibold))
            .buttonStyle(.plain)
        }
    }

    private var registerForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            pairedFields {
                AuthFieldShell(title: "School email", isFocused: focusedField == .registerEmail) {
                    TextField("Enter your school email", text: $registerEmail)
                        .textInputAutocapitalization(.never)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .registerEmail)
                }
            } second: {
                AuthFieldShell(title: "Real name", isFocused: focusedField == .registerRealname) {
                    TextField("Enter your name", text: $registerRealname)
                        .focused($focusedField, equals: .registerRealname)
                }
            }

            AuthFieldShell(title: "Class name", isFocused: focusedField == .registerClassname) {
                TextField("For example: G11-2", text: $registerClassname)
                    .focused($focusedField, equals: .registerClassname)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Gender")
                    .font(.subheadline.weight(.medium))

                Picker("Gender", selection: $registerGender) {
                    ForEach(genders, id: \.self) { gender in
                        Text(gender).tag(gender)
                    }
                }
                .pickerStyle(.segmented)
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                )
            }

            pairedFields {
                AuthFieldShell(title: "Password", isFocused: focusedField == .registerPassword) {
                    SecureField("At least 6 characters", text: $registerPassword)
                        .focused($focusedField, equals: .registerPassword)
                }
            } second: {
                AuthFieldShell(title: "Confirm password", isFocused: focusedField == .registerConfirmPassword) {
                    SecureField("Enter password again", text: $registerConfirmPassword)
                        .focused($focusedField, equals: .registerConfirmPassword)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Profile photo")
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 12) {
                    registerAvatarPreview
                    PhotosPicker(selection: $selectedRegisterAvatarItem, matching: .images) {
                        Label(
                            pendingRegisterAvatarUpload == nil ? "Choose photo" : "Change photo",
                            systemImage: "photo.on.rectangle"
                        )
                    }
                    .buttonStyle(.bordered)
                    if isLoadingRegisterAvatar {
                        ProgressView()
                    }
                }
            }

            Button {
                localError = validateRegistration()
                guard localError == nil else {
                    return
                }

                Task {
                    let request = RegisterRequest(
                        email: registerEmail,
                        realname: registerRealname,
                        password: registerPassword,
                        gender: registerGender,
                        classname: registerClassname,
                        avatar: nil
                    )
                    _ = await session.registerAndSignIn(
                        request: request,
                        avatarUpload: pendingRegisterAvatarUpload
                    )
                }
            } label: {
                submitLabel(title: AuthMode.register.actionTitle)
            }
            .buttonStyle(AuthPrimaryButtonStyle())
            .disabled(session.isAuthenticating || isLoadingRegisterAvatar)
        }
    }

    @ViewBuilder
    private func submitLabel(title: String) -> some View {
        if session.isAuthenticating {
            ProgressView()
                .tint(.white)
                .frame(maxWidth: .infinity)
        } else {
            Text(title)
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func pairedFields<First: View, Second: View>(
        @ViewBuilder first: () -> First,
        @ViewBuilder second: () -> Second
    ) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 14) {
                first()
                    .frame(maxWidth: .infinity, alignment: .leading)
                second()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(spacing: 14) {
                first()
                second()
            }
        }
    }

    @ViewBuilder
    private var registerAvatarPreview: some View {
        if let registerAvatarImage {
            registerAvatarImage
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 64)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Color(uiColor: .tertiarySystemFill))
                .frame(width: 64, height: 64)
                .overlay {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
        }
    }

    private var registerAvatarImage: Image? {
        guard let pendingRegisterAvatarUpload else {
            return nil
        }
        #if canImport(UIKit)
        guard let image = UIImage(data: pendingRegisterAvatarUpload.data) else {
            return nil
        }
        return Image(uiImage: image)
        #else
        return nil
        #endif
    }

    private func loadRegisterAvatarSelection(from item: PhotosPickerItem?) async {
        guard let item else {
            pendingRegisterAvatarUpload = nil
            return
        }

        isLoadingRegisterAvatar = true
        defer {
            isLoadingRegisterAvatar = false
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self), !data.isEmpty else {
                throw APIError.transport(code: nil, message: "The selected photo could not be loaded.")
            }
            let contentType = item.supportedContentTypes.first(where: { $0.conforms(to: .image) }) ?? .jpeg
            pendingRegisterAvatarUpload = RegistrationAvatarUpload(
                filename: "avatar.\(contentType.preferredFilenameExtension ?? "jpg")",
                data: data,
                mimeType: contentType.preferredMIMEType
            )
        } catch {
            localError = session.readableError(error)
        }
    }

    private func validateLogin() -> String? {
        if session.hasConfiguredServerURL == false {
            return "Service address is required."
        }
        if loginEmail.isEmpty || loginPassword.isEmpty {
            return "Email and password are required."
        }
        return nil
    }

    private func validateRegistration() -> String? {
        if session.hasConfiguredServerURL == false {
            return "Service address is required."
        }
        if registerEmail.isEmpty || registerRealname.isEmpty || registerClassname.isEmpty {
            return "Email, real name, and class name are required."
        }
        if registerPassword.count < 6 {
            return "Passwords should be at least 6 characters."
        }
        if registerPassword != registerConfirmPassword {
            return "The password confirmation does not match."
        }
        if session.demoData == nil && pendingRegisterAvatarUpload == nil {
            return "Profile photo is required during registration."
        }
        return nil
    }

    private func validateServiceAddress() -> String? {
        do {
            _ = try SessionStore.normalizeServerURL(from: session.serverURLText)
            return nil
        } catch {
            return "Enter a valid service address."
        }
    }

    private func advanceToCredentials() {
        localError = validateServiceAddress()
        guard localError == nil else {
            return
        }
        session.clearLastError()
        step = .credentials
        focusedField = mode == .login ? .loginEmail : .registerEmail
    }

    private var visibleSteps: [AuthStep] {
        session.usesBundledServerURL ? [.credentials] : AuthStep.allCases
    }

    private var stepIndexTitle: String? {
        guard visibleSteps.count > 1,
              let index = visibleSteps.firstIndex(of: step) else {
            return nil
        }
        return "Step \(index + 1)"
    }

    private func authStepBadge(for authStep: AuthStep) -> some View {
        let isCurrent = authStep == step
        let isComplete = authStep.rawValue < step.rawValue

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        isCurrent || isComplete
                            ? AppTheme.accentTint
                            : Color(uiColor: .tertiarySystemFill)
                    )
                    .frame(width: 34, height: 34)

                Image(systemName: isComplete ? "checkmark" : "\(authStep.rawValue + 1).circle.fill")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(isCurrent || isComplete ? .white : .secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(authStep.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isCurrent ? Color(uiColor: .systemBackground).opacity(0.84) : Color.white.opacity(0.44))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    isCurrent ? AppTheme.accentTint.opacity(0.26) : Color.white.opacity(0.30),
                    lineWidth: 1
                )
        }
    }
}

private struct PasswordResetSheet: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var code = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var issuedCode: String?
    @State private var errorMessage: String?
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    TextField("School email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                }

                Section("Request reset code") {
                    Button(isSubmitting ? "Requesting..." : "Request Code") {
                        Task {
                            await requestCode()
                        }
                    }
                    .disabled(isSubmitting || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if let issuedCode {
                        Text("Reset code: \(issuedCode)")
                            .font(.footnote.monospaced())
                    }
                }

                Section("Confirm reset") {
                    TextField("Reset code", text: $code)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("New password", text: $newPassword)
                    SecureField("Confirm password", text: $confirmPassword)

                    Button(isSubmitting ? "Submitting..." : "Confirm Reset") {
                        Task {
                            await confirmReset()
                        }
                    }
                    .disabled(isSubmitting)
                }

                if let errorMessage {
                    Section {
                        InlineErrorBanner(message: errorMessage)
                            .listRowInsets(EdgeInsets())
                    }
                }
            }
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func requestCode() async {
        guard let serverURL = session.serverURL else {
            errorMessage = "Enter a valid service address first."
            return
        }
        isSubmitting = true
        defer {
            isSubmitting = false
        }

        do {
            let issued = try await session.apiClient.requestPasswordReset(
                baseURL: serverURL,
                email: email.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            issuedCode = issued
            errorMessage = nil
        } catch {
            errorMessage = session.readableError(error)
        }
    }

    private func confirmReset() async {
        guard let serverURL = session.serverURL else {
            errorMessage = "Enter a valid service address first."
            return
        }
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedEmail.isEmpty || normalizedCode.isEmpty {
            errorMessage = "Email and reset code are required."
            return
        }
        if newPassword.count < 6 {
            errorMessage = "New password must be at least 6 characters."
            return
        }
        if newPassword != confirmPassword {
            errorMessage = "Password confirmation does not match."
            return
        }

        isSubmitting = true
        defer {
            isSubmitting = false
        }

        do {
            try await session.apiClient.confirmPasswordReset(
                baseURL: serverURL,
                email: normalizedEmail,
                code: normalizedCode,
                newPassword: newPassword
            )
            errorMessage = nil
            dismiss()
        } catch {
            errorMessage = session.readableError(error)
        }
    }
}

private struct AuthSceneBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.98, blue: 1.00),
                    Color(red: 0.93, green: 0.95, blue: 0.99),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(AppTheme.accentTint.opacity(0.18))
                .frame(width: 420, height: 420)
                .blur(radius: 110)
                .offset(x: -240, y: -220)

            Circle()
                .fill(Color(red: 0.56, green: 0.70, blue: 0.86).opacity(0.22))
                .frame(width: 520, height: 520)
                .blur(radius: 130)
                .offset(x: 260, y: 250)

            RoundedRectangle(cornerRadius: 140, style: .continuous)
                .fill(Color.white.opacity(0.28))
                .frame(width: 880, height: 420)
                .rotationEffect(.degrees(-12))
                .blur(radius: 4)
                .offset(x: 180, y: -40)
        }
        .ignoresSafeArea()
    }
}

private struct AuthFieldShell<Content: View>: View {
    let title: String
    let detail: String?
    let isFocused: Bool
    @ViewBuilder let content: Content

    init(
        title: String,
        detail: String? = nil,
        isFocused: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.detail = detail
        self.isFocused = isFocused
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))

            content
                .font(.body)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(uiColor: .systemBackground))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            isFocused ? AppTheme.accentTint.opacity(0.55) : Color(uiColor: .separator).opacity(0.22),
                            lineWidth: isFocused ? 1.5 : 1
                        )
                }

            if let detail {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct AuthPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.accentTint.opacity(isEnabled ? 1 : 0.45))
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

#Preview("Auth Step 1", traits: .landscapeLeft) {
    AuthFlowView(previewStep: .serviceAddress)
        .environmentObject(SessionStore.previewSignedOut())
}

#Preview("Auth Step 2", traits: .landscapeLeft) {
    AuthFlowView(previewStep: .credentials)
        .environmentObject(SessionStore.previewSignedOut())
}
