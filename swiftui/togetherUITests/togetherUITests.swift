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

        XCTAssertTrue(app.navigationBars["Student Access"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Sign in with your school account"].exists)
        XCTAssertTrue(app.buttons["Sign In"].exists)
    }

    @MainActor
    func testSignedOutDemoCanReachSignedInShell() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demo-signed-out"]
        app.launch()

        let signInActionButton = app.scrollViews.buttons["Sign In"].firstMatch
        XCTAssertTrue(signInActionButton.waitForExistence(timeout: 3))
        let emailField = app.textFields["Enter your school email"]
        let passwordField = app.secureTextFields["Enter password"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 3))
        XCTAssertTrue(passwordField.waitForExistence(timeout: 3))
        emailField.tap()
        emailField.typeText("demo@school.edu")
        passwordField.tap()
        passwordField.typeText("password")
        signInActionButton.tap()

        let signedOutPredicate = NSPredicate(format: "exists == false")
        expectation(for: signedOutPredicate, evaluatedWith: app.navigationBars["Student Access"])
        expectation(for: signedOutPredicate, evaluatedWith: app.secureTextFields.firstMatch)
        waitForExpectations(timeout: 5)
    }

    @MainActor
    func testVolunteerDemoShowsFeedDetailWithoutManageControls() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demo-volunteer"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Feed"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Participation"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Communication"].exists)
        XCTAssertFalse(app.staticTexts["Manage Activity"].waitForExistence(timeout: 1))
    }

    @MainActor
    func testOrganizerDemoShowsManageControlsInFeedDetail() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demo-organizer"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Feed"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Participation"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Communication"].exists)
        XCTAssertTrue(app.staticTexts["Manage Activity"].waitForExistence(timeout: 5))
    }
}
