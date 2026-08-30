import XCTest

final class togetherUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchVolunteerDemo() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-demo-volunteer"]
        app.launch()
        return app
    }

    private func openPrimaryNavigationItem(named title: String, in app: XCUIApplication) {
        let candidates = [
            app.tabBars.buttons[title].firstMatch,
            app.buttons[title].firstMatch,
            app.collectionViews.buttons[title].firstMatch,
            app.otherElements.buttons[title].firstMatch,
        ]

        for candidate in candidates where candidate.waitForExistence(timeout: 3) {
            candidate.tap()
            return
        }

        XCTFail("Unable to open navigation item named \(title)")
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

    @MainActor
    func testVolunteerDemoRecordsShowOverviewTilesAndEntries() throws {
        let app = launchVolunteerDemo()

        openPrimaryNavigationItem(named: "Records", in: app)

        XCTAssertTrue(app.navigationBars["Records"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Volunteer Hours"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["2.0 hrs"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Pending"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Approved"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Confirmed"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Library Reading Drive"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["River Cleanup"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testVolunteerDemoRecordsConfirmedFilterShowsOnlyConfirmedHistory() throws {
        let app = launchVolunteerDemo()

        openPrimaryNavigationItem(named: "Records", in: app)

        let confirmedFilter = app.buttons["Confirmed"].firstMatch
        XCTAssertTrue(confirmedFilter.waitForExistence(timeout: 5))
        confirmedFilter.tap()

        XCTAssertTrue(app.staticTexts["River Cleanup"].waitForExistence(timeout: 5))
        let pendingRecord = app.staticTexts["Library Reading Drive"].firstMatch
        let pendingRecordGone = NSPredicate(format: "exists == false")
        expectation(for: pendingRecordGone, evaluatedWith: pendingRecord)
        waitForExpectations(timeout: 5)
    }
}
