export type AuthorityName =
  | 'create_activity'
  | 'create_channel'
  | 'manage_record_anyway'
  | 'manage_comment_anyway'
  | 'manage_authority_anyway'
  | 'view_user'
  | 'generate_export'
  | 'update_user_anyway'
  | 'delete_user'
  | 'view_all_activities'

export type UserGroup = 'admin' | 'teacher' | 'student'

export interface AdminCreateUserForm {
  email: string
  realname: string
  password: string
  gender: string
  classname: string
  avatar?: string | null
  group: UserGroup
}

export type NotificationTypeName =
  | 'new_channel_message'
  | 'teacher_channel_post'
  | 'activity_state_change'
  | 'record_state_change'

export interface NotificationResponse {
  id: string
  user_id: string
  notification_type: NotificationTypeName
  payload: Record<string, unknown>
  read_at: string | null
  created_at: string
}

export interface NotificationPreference {
  notification_type: NotificationTypeName
  enabled: boolean
}

export type ActivityState = 'need_volunteer' | 'going' | 'ended' | 'canceled'
export type ActivityTransitionAction = 'need_volunteer' | 'go' | 'end' | 'cancel'

export type RecordState = 'pending_approval' | 'approved' | 'confirmed' | 'canceled'

export interface UserProfile {
  id: string
  email: string
  realname: string
  gender: string
  description: string
  classname: string
  avatar: string | null
  group: string
}

export interface ActivitySummary {
  id: string
  name: string
  location: string
  volunteer_num: number
  max_volunteer_num: number | null
  promoter: string
  promoter_name: string
  date: string | null
  brief_description: string
  duration: number
  state: ActivityState
  viewer_participating: boolean
  viewer_record_state: RecordState | null
}

export interface ActivityDetail {
  id: string
  name: string
  location: string
  volunteer_num: number
  max_volunteer_num: number | null
  promoter: string
  promoter_name: string
  date: string | null
  description: string
  volunteers: string[]
  duration: number
  state: ActivityState
  viewer_participating: boolean
  viewer_record_state: RecordState | null
}

export interface RecordEntry {
  id: string
  user: string
  activity: string
  state: RecordState
  activity_name: string | null
  activity_date: string | null
  activity_duration: number | null
  confirmed_minutes: number
  updated_at: string
  confirmed_at: string | null
}

export interface ChannelResponse {
  id: string
  name: string
  owner: string
  members: string[]
  activity: string | null
}

export interface ChannelMessage {
  id: string
  channel: string
  sender: string
  content: string
  datetime: string
}

export interface ActivityComment {
  id: string
  author: string
  author_name: string
  content: string
  date: string
}

export interface ChannelCreatedResponse {
  message: string
  channel_id: string
}

export interface LeaderboardEntry {
  rank: number
  user: string
  realname: string
  classname: string
  avatar: string | null
  total_minutes: number
}

export interface ExportItem {
  id: string
  user: string
  activity: string
  student_name: string
  class_name: string
  activity_title: string
  activity_date: string | null
  confirmed_minutes: number
  confirmed_at: string | null
}

export interface ExportBatchResponse {
  batch_id: string
  target_format: string
  status: string
  created_at: string
  file_name: string
  content_type: string
  content: string
  items: ExportItem[]
}

export interface ApiMessage {
  message: string
}

export interface AuthorityCheckResponse {
  result: boolean
}

export interface ActivityDraft {
  name: string
  dateEnabled: boolean
  dateValue: string
  hasParticipantLimit: boolean
  maxVolunteerNum: number
  location: string
  briefDescription: string
  description: string
  duration: number
}

export interface UpdateUserForm {
  realname?: string
  gender?: string
  description?: string
  classname?: string
  avatar?: string | null
}

export interface UserBatchResult {
  affected: number
}

export interface UserClassSummary {
  classname: string
  count: number
}

export interface GroupAuthoritySummary {
  code: string
  allow_all_authorities: boolean
  authorities: string[]
}

const activityTransitionsByState = {
  need_volunteer: ['go', 'cancel'],
  going: ['end', 'cancel'],
  ended: [],
  canceled: [],
} as const satisfies Record<ActivityState, readonly ActivityTransitionAction[]>

export function activityTransitionActions(state: ActivityState): readonly ActivityTransitionAction[] {
  return activityTransitionsByState[state]
}

export function activityChannelIsReadOnly(state: ActivityState): boolean {
  return state === 'ended' || state === 'canceled'
}
