import SwiftUI

@main
struct togetherApp: App {
    @StateObject private var session = SessionStore()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(session)
        }
    }
}
