import Foundation

struct APIMessageResponse: Decodable, Sendable {
    let message: String
}

struct ServiceHealthResponse: Decodable, Sendable {
    let status: String
}

struct ResourceCreatedResponse: Decodable, Sendable {
    let id: String
    let filename: String
    let path: String
}

struct AuthorityCheckResponse: Decodable, Sendable {
    let result: Bool
}

struct UserProfile: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let email: String
    let realname: String
    let gender: String
    let description: String
    let classname: String
    let avatar: String?
    let group: String
}

enum ActivityState: String, Codable, CaseIterable, Sendable {
    case going
    case needVolunteer = "need_volunteer"
    case ended
    case canceled

    var title: String {
        switch self {
        case .going:
            "In Progress"
        case .needVolunteer:
            "Recruiting"
        case .ended:
            "Completed"
        case .canceled:
            "Cancelled"
        }
    }

    var channelIsReadOnly: Bool {
        switch self {
        case .needVolunteer, .going:
            false
        case .ended, .canceled:
            true
        }
    }
}

enum RecordState: String, Codable, CaseIterable, Sendable {
    case pendingApproval = "pending_approval"
    case approved
    case confirmed
    case canceled

    var title: String {
        switch self {
        case .pendingApproval:
            "Pending Approval"
        case .approved:
            "Approved"
        case .confirmed:
            "Confirmed"
        case .canceled:
            "Cancelled"
        }
    }
}

struct ActivitySummary: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let location: String
    let volunteerNum: Int
    let maxVolunteerNum: Int?
    let promoter: String
    let promoterName: String
    let date: String?
    let briefDescription: String
    let duration: Int
    let state: ActivityState
    let viewerParticipating: Bool
    let viewerRecordState: RecordState?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case location
        case volunteerNum = "volunteer_num"
        case maxVolunteerNum = "max_volunteer_num"
        case promoter
        case promoterName = "promoter_name"
        case date
        case briefDescription = "brief_description"
        case duration
        case state
        case viewerParticipating = "viewer_participating"
        case viewerRecordState = "viewer_record_state"
    }
}

struct ActivityDetail: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let location: String
    let volunteerNum: Int
    let maxVolunteerNum: Int?
    let promoter: String
    let promoterName: String
    let date: String?
    let description: String
    let volunteers: [String]
    let duration: Int
    let state: ActivityState
    let viewerParticipating: Bool
    let viewerRecordState: RecordState?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case location
        case volunteerNum = "volunteer_num"
        case maxVolunteerNum = "max_volunteer_num"
        case promoter
        case promoterName = "promoter_name"
        case date
        case description
        case volunteers
        case duration
        case state
        case viewerParticipating = "viewer_participating"
        case viewerRecordState = "viewer_record_state"
    }
}

struct CommentEntry: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let author: String
    let authorName: String
    let content: String
    let date: String

    enum CodingKeys: String, CodingKey {
        case id
        case author
        case authorName = "author_name"
        case content
        case date
    }
}

struct ChannelResponse: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let owner: String
    let members: [String]
    let activity: String?
}

struct ChannelCreatedResponse: Codable, Sendable {
    let message: String
    let channelID: String

    enum CodingKeys: String, CodingKey {
        case message
        case channelID = "channel_id"
    }
}

struct ChannelMessage: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let channel: String
    let sender: String
    let content: String
    let datetime: String
}

struct RecordEntry: Codable, Identifiable, Hashable, Sendable {
    let recordID: String
    let user: String
    let activity: String
    let state: RecordState
    let activityName: String?
    let activityDate: String?
    let activityDuration: Int?
    let confirmedMinutes: Int
    let updatedAt: String
    let confirmedAt: String?

    var id: String {
        recordID
    }

    enum CodingKeys: String, CodingKey {
        case recordID = "id"
        case user
        case activity
        case state
        case activityName = "activity_name"
        case activityDate = "activity_date"
        case activityDuration = "activity_duration"
        case confirmedMinutes = "confirmed_minutes"
        case updatedAt = "updated_at"
        case confirmedAt = "confirmed_at"
    }
}

struct LeaderboardEntry: Codable, Identifiable, Hashable, Sendable {
    let rank: Int
    let user: String
    let realname: String
    let classname: String
    let avatar: String?
    let totalMinutes: Int

    var id: String {
        user
    }

    enum CodingKeys: String, CodingKey {
        case rank
        case user
        case realname
        case classname
        case avatar
        case totalMinutes = "total_minutes"
    }
}

struct ExportBatchResponse: Codable, Identifiable, Sendable {
    struct Item: Codable, Identifiable, Sendable {
        let id: String
        let user: String
        let activity: String
        let studentName: String
        let className: String
        let activityTitle: String
        let activityDate: String?
        let confirmedMinutes: Int
        let confirmedAt: String?

        enum CodingKeys: String, CodingKey {
            case id
            case user
            case activity
            case studentName = "student_name"
            case className = "class_name"
            case activityTitle = "activity_title"
            case activityDate = "activity_date"
            case confirmedMinutes = "confirmed_minutes"
            case confirmedAt = "confirmed_at"
        }
    }

    let batchID: String
    let targetFormat: String
    let status: String
    let createdAt: String
    let fileName: String
    let contentType: String
    let content: String
    let items: [Item]

    var id: String {
        batchID
    }

    enum CodingKeys: String, CodingKey {
        case batchID = "batch_id"
        case targetFormat = "target_format"
        case status
        case createdAt = "created_at"
        case fileName = "file_name"
        case contentType = "content_type"
        case content
        case items
    }
}

struct LoginRequest: Encodable, Sendable {
    let email: String
    let password: String
}

struct RegisterRequest: Encodable, Sendable {
    let email: String
    let realname: String
    let password: String
    let gender: String
    let classname: String
    let avatar: String?
}

struct ActivityDraft: Codable, Equatable, Sendable {
    var name: String = ""
    var scheduledDate: Date = .now
    var hasScheduledDate = true
    var hasParticipantLimit = true
    var maxVolunteerNum = 20
    var location: String = ""
    var briefDescription: String = ""
    var description: String = ""
    var durationMinutes = 120

    init(
        name: String = "",
        scheduledDate: Date = .now,
        hasScheduledDate: Bool = true,
        hasParticipantLimit: Bool = true,
        maxVolunteerNum: Int = 20,
        location: String = "",
        briefDescription: String = "",
        description: String = "",
        durationMinutes: Int = 120
    ) {
        self.name = name
        self.scheduledDate = scheduledDate
        self.hasScheduledDate = hasScheduledDate
        self.hasParticipantLimit = hasParticipantLimit
        self.maxVolunteerNum = maxVolunteerNum
        self.location = location
        self.briefDescription = briefDescription
        self.description = description
        self.durationMinutes = durationMinutes
    }
}

struct CreateActivityRequest: Encodable, Sendable {
    let name: String
    let date: String?
    let maxVolunteerNum: Int?
    let description: String
    let location: String
    let briefDescription: String
    let duration: Int

    enum CodingKeys: String, CodingKey {
        case name
        case date
        case maxVolunteerNum = "max_volunteer_num"
        case description
        case location
        case briefDescription = "brief_description"
        case duration
    }
}

struct PostCommentRequest: Encodable, Sendable {
    let content: String
}

struct CreateChannelRequest: Encodable, Sendable {
    let name: String
    let activity: String?
}

struct PostMessageRequest: Encodable, Sendable {
    let content: String
}

struct UpdateUserRequest: Encodable, Sendable {
    let realname: String?
    let gender: String?
    let description: String?
    let classname: String?
    let avatar: String?
}

struct ChangePasswordRequest: Encodable, Sendable {
    let currentPassword: String
    let newPassword: String

    enum CodingKeys: String, CodingKey {
        case currentPassword = "current_password"
        case newPassword = "new_password"
    }
}

struct ResetPasswordRequestPayload: Encodable, Sendable {
    let email: String
}

struct ResetPasswordRequestResult: Decodable, Sendable {
    let code: String
}

struct ResetPasswordConfirmRequest: Encodable, Sendable {
    let email: String
    let code: String
    let newPassword: String

    enum CodingKeys: String, CodingKey {
        case email
        case code
        case newPassword = "new_password"
    }
}

// MARK: - Notifications

enum NotificationTypeName: String, Codable, CaseIterable, Sendable {
    case newChannelMessage = "new_channel_message"
    case teacherChannelPost = "teacher_channel_post"
    case activityStateChange = "activity_state_change"
    case recordStateChange = "record_state_change"

    var title: String {
        switch self {
        case .newChannelMessage:
            "New Message"
        case .teacherChannelPost:
            "Teacher Update"
        case .activityStateChange:
            "Activity Update"
        case .recordStateChange:
            "Record Update"
        }
    }

    var systemImage: String {
        switch self {
        case .newChannelMessage:
            "bubble.left.fill"
        case .teacherChannelPost:
            "megaphone.fill"
        case .activityStateChange:
            "calendar.badge.clock"
        case .recordStateChange:
            "checkmark.seal.fill"
        }
    }
}

/// Lightweight decoded payload — all fields optional so decoding never fails.
struct NotificationPayload: Decodable, Sendable {
    let channelID: String?
    let activityID: String?
    let activityName: String?
    let senderName: String?
    let messagePreview: String?
    let recordID: String?
    let newState: String?

    enum CodingKeys: String, CodingKey {
        case channelID = "channel_id"
        case activityID = "activity_id"
        case activityName = "activity_name"
        case senderName = "sender_name"
        case messagePreview = "message_preview"
        case recordID = "record_id"
        case newState = "new_state"
    }
}

struct NotificationResponse: Decodable, Identifiable, Sendable {
    let id: String
    let userID: String
    let notificationType: NotificationTypeName
    let payload: NotificationPayload
    let readAt: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case notificationType = "notification_type"
        case payload
        case readAt = "read_at"
        case createdAt = "created_at"
    }

    var isRead: Bool {
        readAt != nil
    }
}

struct NotificationUnreadCountResponse: Decodable, Sendable {
    let count: Int
}

struct NotificationPreference: Codable, Sendable {
    let notificationType: NotificationTypeName
    let enabled: Bool

    enum CodingKeys: String, CodingKey {
        case notificationType = "notification_type"
        case enabled
    }
}

struct MarkNotificationsReadRequest: Encodable, Sendable {
    let ids: [String]?
    let all: Bool?
}

struct UpdateNotificationPreferencesRequest: Encodable, Sendable {
    let preferences: [NotificationPreference]
}
