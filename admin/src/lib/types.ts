export type AuthorityName =
  | 'create_activity'
  | 'create_channel'
  | 'manage_record_anyway'
  | 'view_user'
  | 'generate_export'

export type ActivityState = 'need_volunteer' | 'going' | 'ended' | 'canceled'

export type RecordState = 'todo' | 'done' | 'canceled'

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
  viewer_joined: boolean
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
  viewer_joined: boolean
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

export function activityChannelIsReadOnly(state: ActivityState): boolean {
  return state === 'ended' || state === 'canceled'
}
