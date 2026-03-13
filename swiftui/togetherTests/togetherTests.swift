import Foundation
import Testing
@testable import together

struct togetherTests {
    @Test
    @MainActor
    func normalizeServerURLStripsAPISuffix() throws {
        let url = try SessionStore.normalizeServerURL(from: "https://school.example.com/api/v1")
        #expect(url.absoluteString == "https://school.example.com")
    }

    @Test
    func displayTextFormatsDurationsAndHours() {
        #expect(DisplayText.duration(minutes: 135) == "2h 15m")
        #expect(DisplayText.hours(minutes: 90) == "1.5 hrs")
    }

    @Test
    @MainActor
    func organizerDemoBootstrapPublishesAuthorities() async {
        let session = SessionStore(runtimeMode: .demoOrganizer)
        await session.bootstrap()

        #expect(session.phase == .signedIn)
        #expect(session.canCreateActivities)
        #expect(session.canGenerateExport)
        #expect(session.currentUser?.realname == "Ms. Lin")
    }

    @Test
    @MainActor
    func signedOutDemoCanPromoteIntoVolunteerSession() async {
        let session = SessionStore(runtimeMode: .demoSignedOut)
        await session.bootstrap()
        #expect(session.phase == .signedOut)

        let didSignIn = await session.signIn(email: "demo@school.edu", password: "password")
        #expect(didSignIn)
        #expect(session.phase == .signedIn)
        #expect(session.currentUser?.realname == "Alex Chen")
    }
}
