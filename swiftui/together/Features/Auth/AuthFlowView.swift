import SwiftUI

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

    var subtitle: String {
        switch self {
        case .login:
            "Use your school email and password."
        case .register:
            "Set up your volunteer profile."
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

struct AuthFlowView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.scenePhase) private var scenePhase

    @State private var mode: AuthMode = .login
    @State private var loginEmail = ""
    @State private var loginPassword = ""

    @State private var registerEmail = ""
    @State private var registerRealname = ""
    @State private var registerGender = "Prefer not to say"
    @State private var registerClassname = ""
    @State private var registerPassword = ""
    @State private var registerConfirmPassword = ""
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

    var body: some View {
        NavigationStack {
            PageWidthReader {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 24) {
                        guidancePanel
                            .frame(maxWidth: 312, alignment: .leading)
                        formPanel
                            .frame(maxWidth: 560, alignment: .leading)
                    }

                    VStack(spacing: 18) {
                        guidancePanel
                        formPanel
                    }
                }
            }
            .navigationTitle("Student Access")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: mode) { _, _ in
            localError = nil
            session.clearLastError()
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else {
                return
            }
            Task {
                await session.revalidateServiceAddressIfNeeded()
            }
        }
    }

    private var guidancePanel: some View {
        CardPanel {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("For Students")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Text("Sign in with your school account")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.primary)

                    Text("Join activities and check confirmed service hours in one place.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                VStack(spacing: 16) {
                    AuthGuidanceRow(
                        systemImage: "envelope",
                        title: "School email",
                        detail: "Use the email address provided by your school."
                    )
                    AuthGuidanceRow(
                        systemImage: "link",
                        title: "Service address",
                        detail: "Enter the address your teacher or school office gave you."
                    )
                    AuthGuidanceRow(
                        systemImage: "arrow.trianglehead.clockwise",
                        title: "Change it later",
                        detail: "You can update the address again from Account if it changes."
                    )
                }
            }
        }
    }

    private var formPanel: some View {
        CardPanel {
            VStack(alignment: .leading, spacing: 20) {
                serviceAddressPanel

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
                    Text(mode.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let message = localError ?? session.lastError {
                    InlineErrorBanner(message: message)
                }

                switch mode {
                case .login:
                    loginForm
                case .register:
                    registerForm
                }
            }
        }
    }

    private var serviceAddressPanel: some View {
        AuthFieldShell(
            title: "School service address",
            detail: "Only needed the first time you sign in on this iPad.",
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

            Text("You can add a profile photo after signing in.")
                .font(.footnote)
                .foregroundStyle(.secondary)

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
                    _ = await session.registerAndSignIn(request: request)
                }
            } label: {
                submitLabel(title: AuthMode.register.actionTitle)
            }
            .buttonStyle(AuthPrimaryButtonStyle())
            .disabled(session.isAuthenticating)
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
        return nil
    }
}

private struct AuthGuidanceRow: View {
    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.accentTint)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(uiColor: .systemBackground))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
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

#Preview("Auth") {
    AuthFlowView()
        .environmentObject(SessionStore.previewSignedOut())
}
