import SwiftUI

private enum AuthMode: String, CaseIterable, Identifiable {
    case login
    case register

    var id: String {
        rawValue
    }

    var title: String {
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

    private let genders = [
        "Female",
        "Male",
        "Prefer not to say",
    ]

    var body: some View {
        NavigationStack {
            PageWidthReader {
                hero

                Picker("Authentication", selection: $mode) {
                    ForEach(AuthMode.allCases) { authMode in
                        Text(authMode.title).tag(authMode)
                    }
                }
                .pickerStyle(.segmented)

                if let message = localError ?? session.lastError {
                    InlineErrorBanner(message: message)
                }

                switch mode {
                case .login:
                    loginCard
                case .register:
                    registerCard
                }
            }
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private var hero: some View {
        CardPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text("Volunteer coordination that feels built in.")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                Text("Browse activities, join with one tap, follow organiser updates, and keep school hours ready for export.")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        StateChip(title: "iPhone + iPad", tint: .blue)
                        StateChip(title: "Fast Sign-In", tint: .green)
                        StateChip(title: "Export Ready", tint: .orange)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            StateChip(title: "iPhone + iPad", tint: .blue)
                            StateChip(title: "Fast Sign-In", tint: .green)
                        }
                        StateChip(title: "Export Ready", tint: .orange)
                    }
                }
            }
        }
    }

    private var loginCard: some View {
        CardPanel {
            VStack(alignment: .leading, spacing: 16) {
                Text("Sign in with your school account")
                    .font(.title3.weight(.semibold))

                TextField("School email", text: $loginEmail)
                    .textInputAutocapitalization(.never)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textFieldStyle(.roundedBorder)

                SecureField("Password", text: $loginPassword)
                    .textContentType(.password)
                    .textFieldStyle(.roundedBorder)

                Button {
                    localError = validateLogin()
                    guard localError == nil else {
                        return
                    }
                    Task {
                        _ = await session.signIn(email: loginEmail, password: loginPassword)
                    }
                } label: {
                    if session.isAuthenticating {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Sign In")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(session.isAuthenticating)
            }
        }
    }

    private var registerCard: some View {
        CardPanel {
            VStack(alignment: .leading, spacing: 16) {
                Text("Create a volunteer account")
                    .font(.title3.weight(.semibold))

                TextField("School email", text: $registerEmail)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .textFieldStyle(.roundedBorder)

                TextField("Real name", text: $registerRealname)
                    .textFieldStyle(.roundedBorder)

                Picker("Gender", selection: $registerGender) {
                    ForEach(genders, id: \.self) { gender in
                        Text(gender).tag(gender)
                    }
                }
                .pickerStyle(.segmented)

                TextField("Class name", text: $registerClassname)
                    .textFieldStyle(.roundedBorder)

                SecureField("Password", text: $registerPassword)
                    .textFieldStyle(.roundedBorder)

                SecureField("Confirm password", text: $registerConfirmPassword)
                    .textFieldStyle(.roundedBorder)

                TextField("Profile photo link (optional)", text: $registerAvatar)
                    .textFieldStyle(.roundedBorder)

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
                    if session.isAuthenticating {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Create Account")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(session.isAuthenticating)
            }
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

#Preview("Auth") {
    AuthFlowView()
        .environmentObject(SessionStore.previewSignedOut())
}
