import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        Group {
            switch session.phase {
            case .launching:
                LaunchScreenView()
                    .task {
                        await session.bootstrap()
                    }
            case .signedOut:
                AuthFlowView()
            case .signedIn:
                AppShellView()
            }
        }
        .animation(.snappy, value: session.phase)
    }
}

private struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            AppBackgroundView()
            VStack(spacing: 20) {
                Image(systemName: "person.3.sequence.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(.blue)
                VStack(spacing: 8) {
                    Text("Together")
                        .font(.largeTitle.weight(.bold))
                    Text("Preparing your volunteer workspace")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                ProgressView()
                    .controlSize(.large)
            }
            .padding(32)
        }
    }
}

#Preview("Root Signed Out") {
    AppRootView()
        .environmentObject(SessionStore.previewSignedOut())
}

#Preview("Root Organizer") {
    AppRootView()
        .environmentObject(SessionStore.previewOrganizer())
}
