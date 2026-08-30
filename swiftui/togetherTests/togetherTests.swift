import Foundation
import Testing
import XCTest
@testable import together

struct togetherTests {
    @Test
    @MainActor
    func normalizeServerURLStripsAPISuffix() throws {
        let url = try SessionStore.normalizeServerURL(from: "https://school.example.com/api/v1")
        #expect(url.absoluteString == "https://school.example.com")
    }

    @Test
    @MainActor
    func normalizeServerURLTrimsWhitespaceAndPreservesCustomPaths() throws {
        let url = try SessionStore.normalizeServerURL(from: "  https://school.example.com/portal  ")
        #expect(url.absoluteString == "https://school.example.com/portal")
    }

    @Test
    @MainActor
    func normalizeServerURLRejectsMissingScheme() {
        let didThrowInvalidBaseURL: Bool
        do {
            _ = try SessionStore.normalizeServerURL(from: "school.example.com")
            didThrowInvalidBaseURL = false
        } catch APIError.invalidBaseURL {
            didThrowInvalidBaseURL = true
        } catch {
            didThrowInvalidBaseURL = false
        }

        #expect(didThrowInvalidBaseURL)
    }

    @Test
    @MainActor
    func normalizeServerURLRejectsEmptyInput() {
        let didThrowInvalidBaseURL: Bool
        do {
            _ = try SessionStore.normalizeServerURL(from: "   ")
            didThrowInvalidBaseURL = false
        } catch APIError.invalidBaseURL {
            didThrowInvalidBaseURL = true
        } catch {
            didThrowInvalidBaseURL = false
        }

        #expect(didThrowInvalidBaseURL)
    }

    @Test
    func displayTextFormatsDurationsAndHours() {
        #expect(DisplayText.duration(minutes: 135) == "2h 15m")
        #expect(DisplayText.hours(minutes: 90) == "1.5 hrs")
    }

    @Test
    func displayTextFormatsCapacityAndIdentifiers() {
        #expect(DisplayText.capacity(current: 3, limit: 10) == "3/10")
        #expect(DisplayText.capacity(current: 3, limit: nil) == "3")
        #expect(DisplayText.shortIdentifier("abcdef123456") == "123456")
        #expect(DisplayText.shortIdentifier("abc") == "abc")
    }

    @Test
    func trimmedNilIfEmptyRemovesWhitespaceOnlyStrings() {
        #expect("  hello  ".trimmedNilIfEmpty == "hello")
        #expect(" \n\t ".trimmedNilIfEmpty == nil)
    }

    @Test
    func serverDateParsesAndFallsBackForInvalidValues() {
        #expect(ServerDate.parsed("2026-03-20T09:00:00.000Z") != nil)
        #expect(ServerDate.parsed("2026-03-20T09:00:00Z") != nil)
        #expect(ServerDate.parsed("not-a-date") == nil)
        #expect(ServerDate.dateText(nil) == "To be scheduled")
        #expect(ServerDate.dateTimeText(nil) == "Unavailable")
    }

    @Test
    func serverDateEncodedProducesParseableOutput() {
        let encoded = ServerDate.encoded(Date(timeIntervalSince1970: 0))
        #expect(ServerDate.parsed(encoded) != nil)
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
    func volunteerDemoBootstrapKeepsManageTabHidden() async {
        let session = SessionStore(runtimeMode: .demoVolunteer)
        await session.bootstrap()

        #expect(session.phase == .signedIn)
        #expect(session.currentUser?.realname == "Alex Chen")
        #expect(session.showsManageTab == false)
        #expect(session.canCreateChannels == false)
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
        #expect(session.participantName(for: AppDemoData.volunteerID) == "You")
        #expect(session.participantName(for: AppDemoData.organizerID) == "Ms. Lin")
    }

    @Test
    @MainActor
    func demoUpdateCurrentUserOnlyChangesProvidedFields() async {
        let session = SessionStore(runtimeMode: .demoVolunteer)
        let updated = await session.updateCurrentUser(
            request: UpdateUserRequest(
                realname: "Taylor Chen",
                gender: nil,
                description: "Updated bio",
                classname: nil,
                avatar: "/resource/avatar.png"
            )
        )

        #expect(updated)
        #expect(session.currentUser?.realname == "Taylor Chen")
        #expect(session.currentUser?.description == "Updated bio")
        #expect(session.currentUser?.classname == "11A")
        #expect(session.currentUser?.avatar == "/resource/avatar.png")
    }

    @Test
    @MainActor
    func demoLogoutClearsCurrentSession() async {
        let session = SessionStore(runtimeMode: .demoOrganizer)
        await session.logout()

        #expect(session.phase == .signedOut)
        #expect(session.currentUser == nil)
        #expect(session.authorityCache.isEmpty)
    }

    @Test
    @MainActor
    func sessionHelpersReflectCurrentUserAndFixtureState() {
        let liveSession = SessionStore(defaultServerURL: "https://school.example.com", runtimeMode: .live)
        #expect(liveSession.usesFixtureData == false)
        #expect(liveSession.hasConfiguredServerURL)

        let demoSession = SessionStore(runtimeMode: .demoVolunteer)
        #expect(demoSession.usesFixtureData)
        #expect(demoSession.isCurrentUser(id: AppDemoData.volunteerID))
        #expect(demoSession.hasAuthority("send_comment"))
        #expect(demoSession.hasAuthority("generate_export") == false)
    }

    @Test
    func activityAndRecordStateExposeExpectedLabels() {
        #expect(ActivityState.needVolunteer.title == "Recruiting")
        #expect(ActivityState.ended.channelIsReadOnly)
        #expect(ActivityState.going.channelIsReadOnly == false)
        #expect(RecordState.pendingApproval.title == "Pending Approval")
        #expect(RecordState.confirmed.title == "Confirmed")
    }

    @Test
    @MainActor
    func activitySummaryDecodesSnakeCasePayload() throws {
        let json = #"{"id":"activity-1","name":"Library Drive","location":"Atrium","volunteer_num":12,"max_volunteer_num":20,"promoter":"user-organizer","promoter_name":"Ms. Lin","date":"2026-03-20T09:00:00Z","brief_description":"Help with sign-in","duration":180,"state":"need_volunteer","viewer_participating":true,"viewer_record_state":"approved"}"#
        let data = try #require(json.data(using: .utf8))

        let summary = try JSONDecoder().decode(ActivitySummary.self, from: data)

        #expect(summary.volunteerNum == 12)
        #expect(summary.maxVolunteerNum == 20)
        #expect(summary.promoterName == "Ms. Lin")
        #expect(summary.state == .needVolunteer)
        #expect(summary.viewerParticipating)
        #expect(summary.viewerRecordState == .approved)
    }

    @Test
    @MainActor
    func recordEntryDecodesAndUsesRecordIdentifierAsID() throws {
        let json = #"{"id":"record-1","user":"user-volunteer","activity":"activity-1","state":"confirmed","activity_name":"Library Drive","activity_date":"2026-03-20T09:00:00Z","activity_duration":180,"confirmed_minutes":120,"updated_at":"2026-03-21T09:00:00Z","confirmed_at":"2026-03-21T10:00:00Z"}"#
        let data = try #require(json.data(using: .utf8))

        let record = try JSONDecoder().decode(RecordEntry.self, from: data)

        #expect(record.recordID == "record-1")
        #expect(record.id == "record-1")
        #expect(record.activityDuration == 180)
        #expect(record.confirmedMinutes == 120)
        #expect(record.state == .confirmed)
    }

    @Test
    @MainActor
    func exportBatchResponseDecodesNestedItems() throws {
        let json = #"{"batch_id":"batch-1","target_format":"csv","status":"generated","created_at":"2026-03-21T10:00:00Z","file_name":"hours.csv","content_type":"text/csv","content":"header\nrow","items":[{"id":"item-1","user":"user-volunteer","activity":"activity-1","student_name":"Alex Chen","class_name":"11A","activity_title":"Library Drive","activity_date":"2026-03-20T09:00:00Z","confirmed_minutes":120,"confirmed_at":"2026-03-21T10:00:00Z"}]}"#
        let data = try #require(json.data(using: .utf8))

        let response = try JSONDecoder().decode(ExportBatchResponse.self, from: data)

        #expect(response.id == "batch-1")
        #expect(response.fileName == "hours.csv")
        #expect(response.items.count == 1)
        #expect(response.items[0].studentName == "Alex Chen")
        #expect(response.items[0].confirmedMinutes == 120)
    }

    @Test
    @MainActor
    func createActivityRequestEncodesSnakeCaseKeys() throws {
        let request = CreateActivityRequest(
            name: "Library Drive",
            date: "2026-03-20T09:00:00Z",
            maxVolunteerNum: 20,
            description: "Help younger readers.",
            location: "Atrium",
            briefDescription: "Check-in and support",
            duration: 180
        )

        let payload = try encodedJSONObject(from: request)

        #expect(payload["max_volunteer_num"] as? Int == 20)
        #expect(payload["brief_description"] as? String == "Check-in and support")
        #expect(payload["duration"] as? Int == 180)
    }

    @Test
    @MainActor
    func passwordRequestsEncodeSnakeCaseKeys() throws {
        let changePayload = try encodedJSONObject(
            from: ChangePasswordRequest(currentPassword: "oldpass", newPassword: "newpass")
        )
        #expect(changePayload["current_password"] as? String == "oldpass")
        #expect(changePayload["new_password"] as? String == "newpass")

        let resetPayload = try encodedJSONObject(
            from: ResetPasswordConfirmRequest(email: "student@school.edu", code: "123456", newPassword: "newpass")
        )
        #expect(resetPayload["email"] as? String == "student@school.edu")
        #expect(resetPayload["code"] as? String == "123456")
        #expect(resetPayload["new_password"] as? String == "newpass")
    }

    private func encodedJSONObject<Value: Encodable>(from value: Value) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        let object = try JSONSerialization.jsonObject(with: data)
        return try #require(object as? [String: Any])
    }
}

final class StudentAppXCTests: XCTestCase {
    func testVolunteerFixtureProvidesFeedDetailContent() {
        let demoData = AppDemoData.volunteer()

        XCTAssertEqual(demoData.feedActivities.count, 2)
        XCTAssertEqual(demoData.feedActivities.first?.id, AppDemoData.primaryActivityID)
        XCTAssertEqual(demoData.activityDetails[AppDemoData.primaryActivityID]?.name, "Library Reading Drive")
        XCTAssertEqual(demoData.commentsByActivity[AppDemoData.primaryActivityID]?.count, 2)
        XCTAssertEqual(demoData.channelsByActivity[AppDemoData.primaryActivityID]?.id, AppDemoData.channelID)
        XCTAssertEqual(demoData.messagesByChannel[AppDemoData.channelID]?.count, 2)
    }

    func testRecordsOverviewSummarizesVolunteerFixture() {
        let demoData = AppDemoData.volunteer()
        let overview = RecordsOverview(records: demoData.userRecords)

        XCTAssertEqual(overview.pendingCount, 1)
        XCTAssertEqual(overview.approvedCount, 0)
        XCTAssertEqual(overview.confirmedCount, 1)
        XCTAssertEqual(overview.completedMinutes, 120)
    }

    func testVolunteerFixtureRecordHistorySupportsStudentRecordsScreen() {
        let demoData = AppDemoData.volunteer()

        XCTAssertEqual(demoData.userRecords.map(\.activityName), ["Library Reading Drive", "River Cleanup"])
        XCTAssertEqual(demoData.userRecords.map(\.state), [.pendingApproval, .confirmed])
        XCTAssertEqual(DisplayText.hours(minutes: demoData.userRecords.last?.confirmedMinutes ?? 0), "2.0 hrs")
    }
}
