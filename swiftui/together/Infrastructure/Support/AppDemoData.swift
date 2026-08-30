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
        // MARK: - Activities

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

        let gardenSummary = ActivitySummary(
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

        let seniorSummary = ActivitySummary(
            id: "activity-senior-help",
            name: "Senior Center Digital Help",
            location: "Innovation Lab",
            volunteerNum: 6,
            maxVolunteerNum: 10,
            promoter: organizerID,
            promoterName: "Mr. Tan",
            date: "2026-03-24T07:00:00Z",
            briefDescription: "Help seniors set up email, video calls, and photo sharing on their tablets.",
            duration: 120,
            state: .needVolunteer,
            viewerParticipating: true,
            viewerRecordState: .approved
        )

        let foodBankSummary = ActivitySummary(
            id: "activity-food-bank",
            name: "Weekend Food Bank Packing",
            location: "Shanghai Community Center",
            volunteerNum: 14,
            maxVolunteerNum: 16,
            promoter: organizerID,
            promoterName: "Ms. Lin",
            date: "2026-03-27T02:00:00Z",
            briefDescription: "Pack weekend family food parcels for local distribution partners.",
            duration: 180,
            state: .needVolunteer,
            viewerParticipating: false,
            viewerRecordState: nil
        )

        let museumSummary = ActivitySummary(
            id: "activity-museum-guide",
            name: "Museum Visitor Guide",
            location: "Performing Arts Hall",
            volunteerNum: 9,
            maxVolunteerNum: 12,
            promoter: organizerID,
            promoterName: "Mr. Tan",
            date: "2026-03-29T06:00:00Z",
            briefDescription: "Greet primary school visitors and lead short guided tours of the exhibit.",
            duration: 150,
            state: .going,
            viewerParticipating: false,
            viewerRecordState: nil
        )

        let parkSummary = ActivitySummary(
            id: "activity-park-cleanup",
            name: "Neighborhood Park Cleanup",
            location: "Garden Terrace",
            volunteerNum: 10,
            maxVolunteerNum: 14,
            promoter: organizerID,
            promoterName: "Ms. Lin",
            date: "2026-04-02T05:00:00Z",
            briefDescription: "Clear litter, prune overgrowth, and restock benches after the rainy season.",
            duration: 150,
            state: .needVolunteer,
            viewerParticipating: false,
            viewerRecordState: nil
        )

        let sportsSummary = ActivitySummary(
            id: "activity-sports-day",
            name: "Sports Day Logistics",
            location: "Sports Dome",
            volunteerNum: 18,
            maxVolunteerNum: 24,
            promoter: organizerID,
            promoterName: "Coach Wu",
            date: "2026-04-05T01:30:00Z",
            briefDescription: "Run the relay timing booth and assist with equipment turnover between events.",
            duration: 240,
            state: .needVolunteer,
            viewerParticipating: true,
            viewerRecordState: .pendingApproval
        )

        let artSummary = ActivitySummary(
            id: "activity-art-showcase",
            name: "Charity Art Showcase",
            location: "Learning Commons",
            volunteerNum: 7,
            maxVolunteerNum: 10,
            promoter: organizerID,
            promoterName: "Ms. Lin",
            date: "2026-04-08T08:30:00Z",
            briefDescription: "Hang student artwork, staff the welcome desk, and help close the exhibition.",
            duration: 180,
            state: .needVolunteer,
            viewerParticipating: false,
            viewerRecordState: nil
        )

        let feedActivities = [
            primarySummary, gardenSummary, seniorSummary, foodBankSummary,
            museumSummary, parkSummary, sportsSummary, artSummary,
        ]

        // MARK: - Activity details

        let primaryDetail = ActivityDetail(
            id: primaryActivityID,
            name: primarySummary.name,
            location: primarySummary.location,
            volunteerNum: primarySummary.volunteerNum,
            maxVolunteerNum: primarySummary.maxVolunteerNum,
            promoter: organizerID,
            promoterName: primarySummary.promoterName,
            date: primarySummary.date,
            description: "Support check-in at the main entrance, escort visiting classes to each reading corner, and help close the venue with the organiser team. Volunteers rotate between the welcome desk, the story station, and the take-home book counter every forty minutes.",
            volunteers: [volunteerID, teammateID, "user-demo-3", "user-demo-4", "user-demo-5"],
            duration: primarySummary.duration,
            state: .needVolunteer,
            viewerParticipating: true,
            viewerRecordState: .pendingApproval
        )

        let gardenDetail = ActivityDetail(
            id: gardenSummary.id,
            name: gardenSummary.name,
            location: gardenSummary.location,
            volunteerNum: gardenSummary.volunteerNum,
            maxVolunteerNum: gardenSummary.maxVolunteerNum,
            promoter: organizerID,
            promoterName: gardenSummary.promoterName,
            date: gardenSummary.date,
            description: "Prepare seasonal beds, plant saplings at the north border, and document biodiversity observations for the termly environmental report.",
            volunteers: [teammateID, "user-demo-6", "user-demo-7"],
            duration: gardenSummary.duration,
            state: .needVolunteer,
            viewerParticipating: false,
            viewerRecordState: nil
        )

        // MARK: - Volunteer profile

        let volunteerProfile = UserProfile(
            id: volunteerID,
            email: "alex.chen@ulink.edu.cn",
            realname: "Alex Chen",
            gender: "Prefer not to say",
            description: "Year 11 student focused on literacy, student support projects, and environmental volunteering.",
            classname: "11A",
            avatar: nil,
            group: "student"
        )

        // MARK: - User records (for the Records screen)

        let userRecords = [
            RecordEntry(
                recordID: "record-sports-day",
                user: volunteerID,
                activity: sportsSummary.id,
                state: .pendingApproval,
                activityName: sportsSummary.name,
                activityDate: sportsSummary.date,
                activityDuration: sportsSummary.duration,
                confirmedMinutes: 0,
                updatedAt: "2026-03-18T08:00:00Z",
                confirmedAt: nil
            ),
            RecordEntry(
                recordID: "record-senior-help",
                user: volunteerID,
                activity: seniorSummary.id,
                state: .approved,
                activityName: seniorSummary.name,
                activityDate: seniorSummary.date,
                activityDuration: seniorSummary.duration,
                confirmedMinutes: 0,
                updatedAt: "2026-03-17T10:30:00Z",
                confirmedAt: nil
            ),
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
            ),
            RecordEntry(
                recordID: "record-book-sort",
                user: volunteerID,
                activity: "activity-book-sort",
                state: .confirmed,
                activityName: "Library Book Sorting",
                activityDate: "2026-02-08T07:00:00Z",
                activityDuration: 90,
                confirmedMinutes: 90,
                updatedAt: "2026-02-08T09:00:00Z",
                confirmedAt: "2026-02-08T09:00:00Z"
            ),
            RecordEntry(
                recordID: "record-reading-buddy",
                user: volunteerID,
                activity: "activity-reading-buddy",
                state: .confirmed,
                activityName: "Primary Reading Buddy Session",
                activityDate: "2026-01-24T06:00:00Z",
                activityDuration: 150,
                confirmedMinutes: 150,
                updatedAt: "2026-01-24T09:00:00Z",
                confirmedAt: "2026-01-24T09:00:00Z"
            ),
            RecordEntry(
                recordID: "record-food-packing-past",
                user: volunteerID,
                activity: "activity-food-packing-past",
                state: .confirmed,
                activityName: "Weekend Food Packing",
                activityDate: "2026-01-17T03:00:00Z",
                activityDuration: 180,
                confirmedMinutes: 180,
                updatedAt: "2026-01-17T06:30:00Z",
                confirmedAt: "2026-01-17T06:30:00Z"
            ),
            RecordEntry(
                recordID: "record-campus-tour",
                user: volunteerID,
                activity: "activity-campus-tour",
                state: .canceled,
                activityName: "Open House Campus Tour",
                activityDate: "2026-01-10T06:00:00Z",
                activityDuration: 120,
                confirmedMinutes: 0,
                updatedAt: "2026-01-09T12:00:00Z",
                confirmedAt: nil
            ),
        ]

        // MARK: - Comments (public, on activity detail)

        let primaryComments = [
            CommentEntry(
                id: "comment-1",
                author: organizerID,
                authorName: "Ms. Lin",
                content: "Please arrive 15 minutes early so we can brief each station lead and distribute lanyards.",
                date: "2026-03-13T09:00:00Z"
            ),
            CommentEntry(
                id: "comment-2",
                author: teammateID,
                authorName: "Jordan Wu",
                content: "Can volunteers wear house shirts, or should we use the event apron this round?",
                date: "2026-03-13T10:15:00Z"
            ),
            CommentEntry(
                id: "comment-3",
                author: organizerID,
                authorName: "Ms. Lin",
                content: "House shirts are fine, aprons are only needed for the younger-reader station. I'll bring spares.",
                date: "2026-03-13T10:32:00Z"
            ),
            CommentEntry(
                id: "comment-4",
                author: "user-demo-3",
                authorName: "Priya Shen",
                content: "Is the take-home book counter restocked yet? I can swing by the storeroom on my way.",
                date: "2026-03-13T11:05:00Z"
            ),
            CommentEntry(
                id: "comment-5",
                author: "user-demo-4",
                authorName: "Kai Zhang",
                content: "Adding a reminder that we need one adult volunteer per four children at the story station.",
                date: "2026-03-14T02:10:00Z"
            ),
        ]

        // MARK: - Channel + messages

        let channel = ChannelResponse(
            id: channelID,
            name: "Library Reading Drive Channel",
            owner: organizerID,
            members: [organizerID, volunteerID, teammateID, "user-demo-3", "user-demo-4", "user-demo-5"],
            activity: primaryActivityID
        )

        let messages = [
            ChannelMessage(
                id: "message-1",
                channel: channelID,
                sender: organizerID,
                content: "Room assignments are now posted in the latest comment. Please double-check your station before heading in.",
                datetime: "2026-03-13T09:45:00Z"
            ),
            ChannelMessage(
                id: "message-2",
                channel: channelID,
                sender: organizerID,
                content: "Lanyards and name cards will be on the welcome desk from 08:40.",
                datetime: "2026-03-13T09:46:30Z"
            ),
            ChannelMessage(
                id: "message-3",
                channel: channelID,
                sender: volunteerID,
                content: "I can help with the younger-reader station if needed.",
                datetime: "2026-03-13T10:00:00Z"
            ),
            ChannelMessage(
                id: "message-4",
                channel: channelID,
                sender: teammateID,
                content: "I'll cover the take-home counter with Priya, we've worked that booth before.",
                datetime: "2026-03-13T10:04:00Z"
            ),
            ChannelMessage(
                id: "message-5",
                channel: channelID,
                sender: "user-demo-3",
                content: "Confirmed on take-home counter 👍",
                datetime: "2026-03-13T10:05:20Z"
            ),
            ChannelMessage(
                id: "message-6",
                channel: channelID,
                sender: organizerID,
                content: "Great. Reminder: no phones on the floor during the first rotation --- photos are fine on break.",
                datetime: "2026-03-13T11:20:00Z"
            ),
            ChannelMessage(
                id: "message-7",
                channel: channelID,
                sender: "user-demo-4",
                content: "What do we do if the younger readers finish their book early?",
                datetime: "2026-03-13T11:32:00Z"
            ),
            ChannelMessage(
                id: "message-8",
                channel: channelID,
                sender: organizerID,
                content: "Walk them over to the craft corner or hand them a second book --- we have plenty of backups in the storage cart.",
                datetime: "2026-03-13T11:34:00Z"
            ),
            ChannelMessage(
                id: "message-9",
                channel: channelID,
                sender: volunteerID,
                content: "Weather looks dry tomorrow so we won't need the indoor overflow plan.",
                datetime: "2026-03-13T14:12:00Z"
            ),
            ChannelMessage(
                id: "message-10",
                channel: channelID,
                sender: organizerID,
                content: "Thanks everyone. See you at 08:40 sharp. Safe travel!",
                datetime: "2026-03-13T14:30:00Z"
            ),
        ]

        // MARK: - Leaderboard

        let leaderboard = [
            LeaderboardEntry(rank: 1, user: teammateID, realname: "Jordan Wu", classname: "11B", avatar: nil, totalMinutes: 1_340),
            LeaderboardEntry(rank: 2, user: "user-demo-3", realname: "Priya Shen", classname: "12A", avatar: nil, totalMinutes: 1_180),
            LeaderboardEntry(rank: 3, user: volunteerID, realname: "Alex Chen", classname: "11A", avatar: nil, totalMinutes: 960),
            LeaderboardEntry(rank: 4, user: "user-demo-4", realname: "Kai Zhang", classname: "11A", avatar: nil, totalMinutes: 900),
            LeaderboardEntry(rank: 5, user: "user-demo-5", realname: "Harper Liu", classname: "10C", avatar: nil, totalMinutes: 810),
            LeaderboardEntry(rank: 6, user: "user-demo-6", realname: "Taylor Lin", classname: "12B", avatar: nil, totalMinutes: 720),
            LeaderboardEntry(rank: 7, user: "user-demo-7", realname: "Morgan Xu", classname: "10A", avatar: nil, totalMinutes: 690),
            LeaderboardEntry(rank: 8, user: "user-demo-8", realname: "Riley Sun", classname: "11B", avatar: nil, totalMinutes: 630),
            LeaderboardEntry(rank: 9, user: "user-demo-9", realname: "Casey Zhao", classname: "10B", avatar: nil, totalMinutes: 570),
            LeaderboardEntry(rank: 10, user: "user-demo-10", realname: "Avery Hu", classname: "12C", avatar: nil, totalMinutes: 510),
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
            feedActivities: feedActivities,
            activityDetails: [
                primaryActivityID: primaryDetail,
                gardenSummary.id: gardenDetail,
            ],
            commentsByActivity: [
                primaryActivityID: primaryComments,
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
                        state: .approved,
                        activityName: primarySummary.name,
                        activityDate: primarySummary.date,
                        activityDuration: primarySummary.duration,
                        confirmedMinutes: 0,
                        updatedAt: "2026-03-13T08:30:00Z",
                        confirmedAt: nil
                    ),
                    RecordEntry(
                        recordID: "record-organizer-view-3",
                        user: "user-demo-3",
                        activity: primaryActivityID,
                        state: .approved,
                        activityName: primarySummary.name,
                        activityDate: primarySummary.date,
                        activityDuration: primarySummary.duration,
                        confirmedMinutes: 0,
                        updatedAt: "2026-03-13T08:45:00Z",
                        confirmedAt: nil
                    ),
                    RecordEntry(
                        recordID: "record-organizer-view-4",
                        user: "user-demo-4",
                        activity: primaryActivityID,
                        state: .pendingApproval,
                        activityName: primarySummary.name,
                        activityDate: primarySummary.date,
                        activityDuration: primarySummary.duration,
                        confirmedMinutes: 0,
                        updatedAt: "2026-03-13T09:00:00Z",
                        confirmedAt: nil
                    ),
                    RecordEntry(
                        recordID: "record-organizer-view-5",
                        user: "user-demo-5",
                        activity: primaryActivityID,
                        state: .approved,
                        activityName: primarySummary.name,
                        activityDate: primarySummary.date,
                        activityDuration: primarySummary.duration,
                        confirmedMinutes: 0,
                        updatedAt: "2026-03-13T09:10:00Z",
                        confirmedAt: nil
                    ),
                ],
            ],
            userRecords: userRecords,
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
                "user-demo-3": "Priya Shen",
                "user-demo-4": "Kai Zhang",
                "user-demo-5": "Harper Liu",
                "user-demo-6": "Taylor Lin",
                "user-demo-7": "Morgan Xu",
                "user-demo-8": "Riley Sun",
                "user-demo-9": "Casey Zhao",
                "user-demo-10": "Avery Hu",
            ],
            exportBatch: nil
        )
    }

    static func organizer() -> AppDemoData {
        let volunteerData = volunteer()
        let organizerProfile = UserProfile(
            id: organizerID,
            email: "ms.lin@ulink.edu.cn",
            realname: "Ms. Lin",
            gender: "Female",
            description: "Faculty coordinator for student service programmes and the weekend volunteer lane.",
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
            content: "student_identifier,student_name,class_name,activity_title,activity_date,confirmed_minutes,organiser_confirmation_timestamp\n\"user-volunteer\",\"Alex Chen\",\"11A\",\"River Cleanup\",\"2026-02-18T08:00:00Z\",120,\"2026-02-18T12:30:00Z\"\n\"user-volunteer\",\"Alex Chen\",\"11A\",\"Library Book Sorting\",\"2026-02-08T07:00:00Z\",90,\"2026-02-08T09:00:00Z\"\n\"user-volunteer\",\"Alex Chen\",\"11A\",\"Primary Reading Buddy Session\",\"2026-01-24T06:00:00Z\",150,\"2026-01-24T09:00:00Z\"\n\"user-teammate\",\"Jordan Wu\",\"11B\",\"River Cleanup\",\"2026-02-18T08:00:00Z\",120,\"2026-02-18T12:30:00Z\"\n",
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
                .init(
                    id: "export-item-2",
                    user: volunteerID,
                    activity: "activity-book-sort",
                    studentName: "Alex Chen",
                    className: "11A",
                    activityTitle: "Library Book Sorting",
                    activityDate: "2026-02-08T07:00:00Z",
                    confirmedMinutes: 90,
                    confirmedAt: "2026-02-08T09:00:00Z"
                ),
                .init(
                    id: "export-item-3",
                    user: volunteerID,
                    activity: "activity-reading-buddy",
                    studentName: "Alex Chen",
                    className: "11A",
                    activityTitle: "Primary Reading Buddy Session",
                    activityDate: "2026-01-24T06:00:00Z",
                    confirmedMinutes: 150,
                    confirmedAt: "2026-01-24T09:00:00Z"
                ),
                .init(
                    id: "export-item-4",
                    user: teammateID,
                    activity: "activity-river-cleanup",
                    studentName: "Jordan Wu",
                    className: "11B",
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
