import Foundation

struct AppDemoData {
    let currentUser: UserProfile?
    let authorities: [String: Bool]
    let feedActivities: [ActivitySummary]
    let activityDetails: [String: ActivityDetail]
    let commentsByActivity: [String: [CommentEntry]]
    let recordsByActivity: [String: [RecordEntry]]
    let userRecords: [RecordEntry]
    let leaderboard: [LeaderboardEntry]
    let channelsByActivity: [String: ChannelResponse]
    let messagesByChannel: [String: [ChannelMessage]]
    let userDisplayNames: [String: String]
    let exportBatch: ExportBatchResponse?

    static let primaryActivityID = "activity-library-drive"
    static let channelID = "channel-library-drive"
    static let organizerID = "user-organizer"
    static let volunteerID = "user-volunteer"
    static let teammateID = "user-teammate"

    static func signedOut() -> AppDemoData {
        AppDemoData(
            currentUser: nil,
            authorities: [:],
            feedActivities: [],
            activityDetails: [:],
            commentsByActivity: [:],
            recordsByActivity: [:],
            userRecords: [],
            leaderboard: [],
            channelsByActivity: [:],
            messagesByChannel: [:],
            userDisplayNames: [:],
            exportBatch: nil
        )
    }

    static func volunteer() -> AppDemoData {
        let primarySummary = ActivitySummary(
            id: primaryActivityID,
            name: "Library Reading Drive",
            location: "City Library Atrium",
            volunteerNum: 12,
            maxVolunteerNum: 20,
            promoter: organizerID,
            promoterName: "Ms. Lin",
            date: "2026-03-20T09:00:00Z",
            briefDescription: "Guide younger readers through story stations and check-in.",
            duration: 180,
            state: .needVolunteer,
            viewerParticipating: true,
            viewerRecordState: .pendingApproval
        )

        let secondarySummary = ActivitySummary(
            id: "activity-campus-garden",
            name: "Campus Garden Renewal",
            location: "North Quad",
            volunteerNum: 8,
            maxVolunteerNum: 12,
            promoter: organizerID,
            promoterName: "Ms. Lin",
            date: "2026-03-22T05:30:00Z",
            briefDescription: "Prepare seasonal beds and document biodiversity for the school report.",
            duration: 150,
            state: .needVolunteer,
            viewerParticipating: false,
            viewerRecordState: nil
        )

        let detail = ActivityDetail(
            id: primaryActivityID,
            name: primarySummary.name,
            location: primarySummary.location,
            volunteerNum: primarySummary.volunteerNum,
            maxVolunteerNum: primarySummary.maxVolunteerNum,
            promoter: organizerID,
            promoterName: primarySummary.promoterName,
            date: primarySummary.date,
            description: "Support check-in, escort visiting classes to each reading corner, and help close the venue with the organiser team.",
            volunteers: [volunteerID, teammateID],
            duration: primarySummary.duration,
            state: .needVolunteer,
            viewerParticipating: true,
            viewerRecordState: .pendingApproval
        )

        let volunteerProfile = UserProfile(
            id: volunteerID,
            email: "student@school.edu",
            realname: "Alex Chen",
            gender: "Prefer not to say",
            description: "Focused on literacy and student support projects.",
            classname: "11A",
            avatar: nil,
            group: "student"
        )

        let records = [
            RecordEntry(
                recordID: "record-library-drive",
                user: volunteerID,
                activity: primaryActivityID,
                state: .pendingApproval,
                activityName: primarySummary.name,
                activityDate: primarySummary.date,
                activityDuration: primarySummary.duration,
                confirmedMinutes: 0,
                updatedAt: "2026-03-13T08:00:00Z",
                confirmedAt: nil
            ),
            RecordEntry(
                recordID: "record-river-cleanup",
                user: volunteerID,
                activity: "activity-river-cleanup",
                state: .confirmed,
                activityName: "River Cleanup",
                activityDate: "2026-02-18T08:00:00Z",
                activityDuration: 120,
                confirmedMinutes: 120,
                updatedAt: "2026-02-18T12:30:00Z",
                confirmedAt: "2026-02-18T12:30:00Z"
            )
        ]

        let comments = [
            CommentEntry(
                id: "comment-1",
                author: organizerID,
                authorName: "Ms. Lin",
                content: "Please arrive 15 minutes early so we can brief each station lead.",
                date: "2026-03-13T09:00:00Z"
            ),
            CommentEntry(
                id: "comment-2",
                author: teammateID,
                authorName: "Jordan Wu",
                content: "Can volunteers wear house shirts, or should we use the event apron?",
                date: "2026-03-13T10:15:00Z"
            )
        ]

        let channel = ChannelResponse(
            id: channelID,
            name: "Library Reading Drive Channel",
            owner: organizerID,
            members: [organizerID, volunteerID, teammateID],
            activity: primaryActivityID
        )

        let messages = [
            ChannelMessage(
                id: "message-1",
                channel: channelID,
                sender: organizerID,
                content: "Room assignments are now posted in the latest comment.",
                datetime: "2026-03-13T09:45:00Z"
            ),
            ChannelMessage(
                id: "message-2",
                channel: channelID,
                sender: volunteerID,
                content: "I can help with the younger-reader station if needed.",
                datetime: "2026-03-13T10:00:00Z"
            )
        ]

        let leaderboard = [
            LeaderboardEntry(rank: 1, user: teammateID, realname: "Jordan Wu", classname: "11B", avatar: nil, totalMinutes: 720),
            LeaderboardEntry(rank: 2, user: volunteerID, realname: "Alex Chen", classname: "11A", avatar: nil, totalMinutes: 510),
            LeaderboardEntry(rank: 3, user: organizerID, realname: "Ms. Lin", classname: "Faculty", avatar: nil, totalMinutes: 420),
        ]

        return AppDemoData(
            currentUser: volunteerProfile,
            authorities: [
                "create_activity": false,
                "create_channel": false,
                "send_comment": true,
                "send_message_anyway": false,
                "manage_record_anyway": false,
                "view_user": false,
                "generate_export": false,
            ],
            feedActivities: [primarySummary, secondarySummary],
            activityDetails: [
                primaryActivityID: detail,
            ],
            commentsByActivity: [
                primaryActivityID: comments,
            ],
            recordsByActivity: [
                primaryActivityID: [
                    RecordEntry(
                        recordID: "record-organizer-view-1",
                        user: volunteerID,
                        activity: primaryActivityID,
                        state: .pendingApproval,
                        activityName: primarySummary.name,
                        activityDate: primarySummary.date,
                        activityDuration: primarySummary.duration,
                        confirmedMinutes: 0,
                        updatedAt: "2026-03-13T08:00:00Z",
                        confirmedAt: nil
                    ),
                    RecordEntry(
                        recordID: "record-organizer-view-2",
                        user: teammateID,
                        activity: primaryActivityID,
                        state: .pendingApproval,
                        activityName: primarySummary.name,
                        activityDate: primarySummary.date,
                        activityDuration: primarySummary.duration,
                        confirmedMinutes: 0,
                        updatedAt: "2026-03-13T08:30:00Z",
                        confirmedAt: nil
                    ),
                ],
            ],
            userRecords: records,
            leaderboard: leaderboard,
            channelsByActivity: [
                primaryActivityID: channel,
            ],
            messagesByChannel: [
                channelID: messages,
            ],
            userDisplayNames: [
                organizerID: "Ms. Lin",
                volunteerID: "Alex Chen",
                teammateID: "Jordan Wu",
            ],
            exportBatch: nil
        )
    }

    static func organizer() -> AppDemoData {
        let volunteerData = volunteer()
        let organizerProfile = UserProfile(
            id: organizerID,
            email: "organizer@school.edu",
            realname: "Ms. Lin",
            gender: "Female",
            description: "Faculty coordinator for student service programmes.",
            classname: "Faculty",
            avatar: nil,
            group: "organizer"
        )

        let export = ExportBatchResponse(
            batchID: "batch-demo-1",
            targetFormat: "csv",
            status: "generated",
            createdAt: "2026-03-13T11:30:00Z",
            fileName: "volunteer-hours-demo.csv",
            contentType: "text/csv",
            content: "student_identifier,student_name,class_name,activity_title,activity_date,confirmed_minutes,organiser_confirmation_timestamp\n\"user-volunteer\",\"Alex Chen\",\"11A\",\"River Cleanup\",\"2026-02-18T08:00:00Z\",120,\"2026-02-18T12:30:00Z\"\n",
            items: [
                .init(
                    id: "export-item-1",
                    user: volunteerID,
                    activity: "activity-river-cleanup",
                    studentName: "Alex Chen",
                    className: "11A",
                    activityTitle: "River Cleanup",
                    activityDate: "2026-02-18T08:00:00Z",
                    confirmedMinutes: 120,
                    confirmedAt: "2026-02-18T12:30:00Z"
                ),
            ]
        )

        return AppDemoData(
            currentUser: organizerProfile,
            authorities: [
                "create_activity": true,
                "create_channel": true,
                "send_comment": true,
                "send_message_anyway": true,
                "manage_record_anyway": true,
                "view_user": true,
                "generate_export": true,
            ],
            feedActivities: volunteerData.feedActivities,
            activityDetails: volunteerData.activityDetails,
            commentsByActivity: volunteerData.commentsByActivity,
            recordsByActivity: volunteerData.recordsByActivity,
            userRecords: volunteerData.userRecords,
            leaderboard: volunteerData.leaderboard,
            channelsByActivity: volunteerData.channelsByActivity,
            messagesByChannel: volunteerData.messagesByChannel,
            userDisplayNames: volunteerData.userDisplayNames,
            exportBatch: export
        )
    }
}
