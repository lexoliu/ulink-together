import XCTest

final class togetherUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSignedOutFlowShowsWelcomeSurface() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demo-signed-out"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Welcome"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Volunteer coordination that feels built in."].exists)
        XCTAssertTrue(app.buttons["Sign In"].exists)
    }

    @MainActor
    func testOrganizerDemoShowsManageAndAccountSurfaces() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demo-organizer"]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Manage"].waitForExistence(timeout: 3))
        app.tabBars.buttons["Manage"].tap()
        XCTAssertTrue(app.navigationBars["Manage"].waitForExistence(timeout: 3))

        app.tabBars.buttons["Account"].tap()
        XCTAssertTrue(app.staticTexts["Ms. Lin"].waitForExistence(timeout: 3))
        let editButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Edit'"))
        XCTAssertGreaterThan(editButtons.count, 0)
    }
}
