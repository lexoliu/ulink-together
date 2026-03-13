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
            "Use your school account to continue."
        case .register:
            "Create a volunteer profile in a few steps."
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

    @State private var mode: AuthMode = .login
    @State private var loginEmail = ""
    @State private var loginPassword = ""

    @State private var registerEmail = ""
    @State private var registerRealname = ""
    @State private var registerGender = "Prefer not to say"
    @State private var registerClassname = ""
    @State private var registerPassword = ""
    @State private var registerConfirmPassword = ""
    @State private var registerAvatar = ""
    @State private var localError: String?
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case loginEmail
        case loginPassword
        case registerEmail
        case registerRealname
        case registerClassname
        case registerPassword
        case registerConfirmPassword
        case registerAvatar
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
                    HStack(alignment: .top, spacing: 18) {
                        introPanel
                            .frame(maxWidth: 360, alignment: .leading)
                        formPanel
                    }

                    VStack(spacing: 18) {
                        introPanel
                        formPanel
                    }
                }
            }
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var introPanel: some View {
        CardPanel {
            VStack(alignment: .leading, spacing: 20) {
                Label("Volunteer Hours", systemImage: "person.3.sequence.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.accentTint)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Volunteer work, organised like a system app.")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    Text("Join activities, follow organiser updates, and keep your school service record in one place.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    AuthFeatureRow(
                        systemImage: "sparkles",
                        title: "Clean activity browsing",
                        detail: "See what is open now, what is already underway, and what you joined."
                    )
                    AuthFeatureRow(
                        systemImage: "message.badge.waveform",
                        title: "Per-activity rooms",
                        detail: "Stay inside the discussion thread for each event without switching tools."
                    )
                    AuthFeatureRow(
                        systemImage: "checklist.checked",
                        title: "Records that stay ready",
                        detail: "Completed hours and organiser confirmations stay easy to review."
                    )
                }
            }
        }
    }

    private var formPanel: some View {
        CardPanel {
            VStack(alignment: .leading, spacing: 18) {
                Picker("Authentication", selection: $mode) {
                    ForEach(AuthMode.allCases) { authMode in
                        Text(authMode.title).tag(authMode)
                    }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 6) {
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

    private var loginForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("School email", text: $loginEmail)
                .textInputAutocapitalization(.never)
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .loginEmail)

            SecureField("Password", text: $loginPassword)
                .textContentType(.password)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .loginPassword)

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
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(AppTheme.accentTint)
            .disabled(session.isAuthenticating)
        }
    }

    private var registerForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("School email", text: $registerEmail)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .registerEmail)

            TextField("Real name", text: $registerRealname)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .registerRealname)

            Picker("Gender", selection: $registerGender) {
                ForEach(genders, id: \.self) { gender in
                    Text(gender).tag(gender)
                }
            }
            .pickerStyle(.segmented)

            TextField("Class name", text: $registerClassname)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .registerClassname)

            SecureField("Password", text: $registerPassword)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .registerPassword)

            SecureField("Confirm password", text: $registerConfirmPassword)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .registerConfirmPassword)

            TextField("Profile photo link (optional)", text: $registerAvatar)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .registerAvatar)

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
                        avatar: registerAvatar.trimmedNilIfEmpty
                    )
                    _ = await session.registerAndSignIn(request: request)
                }
            } label: {
                submitLabel(title: AuthMode.register.actionTitle)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(AppTheme.accentTint)
            .disabled(session.isAuthenticating)
        }
    }

    @ViewBuilder
    private func submitLabel(title: String) -> some View {
        if session.isAuthenticating {
            ProgressView()
                .frame(maxWidth: .infinity)
        } else {
            Text(title)
                .frame(maxWidth: .infinity)
        }
    }

    private func validateLogin() -> String? {
        if loginEmail.isEmpty || loginPassword.isEmpty {
            return "Email and password are required."
        }
        return nil
    }

    private func validateRegistration() -> String? {
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

private struct AuthFeatureRow: View {
    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.accentTint)
                .frame(width: 28, height: 28)
                .background(AppTheme.accentTint.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview("Auth") {
    AuthFlowView()
        .environmentObject(SessionStore.previewSignedOut())
}
