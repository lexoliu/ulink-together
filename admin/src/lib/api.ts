import axios, { type AxiosInstance } from 'axios'

import type {
  ActivityComment,
  ActivityDetail,
  ActivityDraft,
  ActivitySummary,
  ActivityTransitionAction,
  AdminCreateUserForm,
  ApiMessage,
  AuthorityCheckResponse,
  AuthorityName,
  ChannelCreatedResponse,
  ChannelMessage,
  ChannelResponse,
  ExportBatchResponse,
  NotificationPreference,
  NotificationResponse,
  RecordEntry,
  UpdateUserForm,
  UserBatchResult,
  UserClassSummary,
  UserGroup,
  UserProfile,
} from '@/lib/types'

export class ApiError extends Error {
  readonly status: number

  constructor(message: string, status = 500) {
    super(message)
    this.name = 'ApiError'
    this.status = status
  }
}

const authorityNames: AuthorityName[] = [
  'view_user',
  'update_user_anyway',
  'delete_user',
  'create_activity',
  'manage_activity_anyway',
  'delete_activity_anyway',
  'view_all_activities',
  'manage_record_anyway',
  'view_record_anyway',
  'manage_comment_anyway',
  'create_channel',
  'view_channel_anyway',
  'delete_channel_anyway',
  'send_message_anyway',
  'delete_message_anyway',
  'generate_export',
]

function apiOrigin(): string {
  return import.meta.env.VITE_BACKEND_ORIGIN?.replace(/\/$/, '') ?? ''
}

function normalizeApiMessage(message: string): string {
  const prefix = 'Endpoint error: '
  let normalized = message.trim()
  while (normalized.startsWith(prefix)) {
    normalized = normalized.slice(prefix.length).trimStart()
  }
  return normalized
}

function apiBaseURL(): string {
  return new URL(`${apiOrigin()}/api/v1`, window.location.origin).toString().replace(/\/$/, '')
}

function apiURL(path: string, query?: Record<string, string | undefined | null>): string {
  const url = new URL(`${apiOrigin()}/api/v1${path}`, window.location.origin)
  if (query) {
    for (const [key, value] of Object.entries(query)) {
      if (value) {
        url.searchParams.set(key, value)
      }
    }
  }
  return url.toString()
}

type QueryParams = Record<string, string | number | undefined | null>

function createHttpClient(): AxiosInstance {
  return axios.create({
    baseURL: apiBaseURL(),
    withCredentials: true,
    headers: {
      Accept: 'application/json',
    },
  })
}

function readAxiosErrorMessage(error: unknown): ApiError {
  if (!axios.isAxiosError(error)) {
    return new ApiError('Request failed')
  }

  const status = error.response?.status ?? 500
  const data = error.response?.data as ApiMessage | undefined
  const rawMessage =
    typeof data?.message === 'string' ? data.message : error.response?.statusText ?? error.message
  return new ApiError(normalizeApiMessage(rawMessage || 'Request failed'), status)
}

async function request<T>(
  client: AxiosInstance,
  path: string,
  options?: {
    method?: 'GET' | 'POST' | 'PUT' | 'DELETE'
    query?: QueryParams
    data?: unknown
  },
): Promise<T> {
  try {
    const response = await client.request<T>({
      url: path,
      method: options?.method ?? 'GET',
      params: options?.query,
      data: options?.data,
    })

    if (response.status === 204) {
      return undefined as T
    }

    return response.data
  } catch (error) {
    throw readAxiosErrorMessage(error)
  }
}

export class AdminApiClient {
  private readonly client: AxiosInstance

  constructor(client: AxiosInstance = createHttpClient()) {
    this.client = client
  }

  async login(email: string, password: string): Promise<void> {
    await request<ApiMessage>(this.client, '/login', {
      method: 'POST',
      data: { email, password },
    })
  }

  async logout(): Promise<void> {
    await request<ApiMessage>(this.client, '/logout', { method: 'POST' })
  }

  async currentUser(): Promise<UserProfile> {
    return request<UserProfile>(this.client, '/user/me')
  }

  async authorityMap(): Promise<Record<AuthorityName, boolean>> {
    const results = await Promise.all(
      authorityNames.map(async (authority) => {
        const response = await request<AuthorityCheckResponse>(this.client, `/auth/check/${authority}`)
        return [authority, response.result] as const
      }),
    )

    return Object.fromEntries(results) as Record<AuthorityName, boolean>
  }

  async activities(params?: { user?: string; displayAll?: boolean }): Promise<ActivitySummary[]> {
    return request<ActivitySummary[]>(this.client, '/activity', {
      query: {
        user: params?.user,
        display_all: params?.displayAll ? '1' : undefined,
      },
    })
  }

  async activity(id: string): Promise<ActivityDetail> {
    return request<ActivityDetail>(this.client, `/activity/${id}`)
  }

  async createActivity(draft: ActivityDraft): Promise<ActivityDetail> {
    return request<ActivityDetail>(this.client, '/activity', {
      method: 'POST',
      data: serializeActivityDraft(draft),
    })
  }

  async updateActivity(id: string, draft: ActivityDraft): Promise<ActivityDetail> {
    return request<ActivityDetail>(this.client, `/activity/${id}`, {
      method: 'PUT',
      data: serializeActivityDraft(draft),
    })
  }

  async transitionActivity(id: string, action: ActivityTransitionAction): Promise<void> {
    await request<ApiMessage>(this.client, `/activity/${id}/${action}`, { method: 'POST' })
  }

  async records(activityId: string): Promise<RecordEntry[]> {
    return request<RecordEntry[]>(this.client, '/record', {
      query: { activity: activityId },
    })
  }

  async updateRecord(
    recordId: string,
    action: 'confirm' | 'approve' | 'cancel',
    options?: { confirmedMinutes?: number },
  ): Promise<void> {
    if (action === 'confirm' && options?.confirmedMinutes !== undefined) {
      await request<ApiMessage>(this.client, `/record/${recordId}/confirm_custom`, {
        method: 'POST',
        data: {
          confirmed_minutes: options.confirmedMinutes,
        },
      })
      return
    }

    await request<ApiMessage>(this.client, `/record/${recordId}/${action}`, { method: 'POST' })
  }

  async activityComments(activityId: string): Promise<ActivityComment[]> {
    return request<ActivityComment[]>(this.client, `/activity/${activityId}/comment`)
  }

  async deleteActivityComment(activityId: string, commentId: string): Promise<void> {
    await request<ApiMessage>(this.client, `/activity/${activityId}/comment/${commentId}`, {
      method: 'DELETE',
    })
  }

  async channels(activityId: string): Promise<ChannelResponse[]> {
    return request<ChannelResponse[]>(this.client, '/channel', {
      query: { activity: activityId },
    })
  }

  async createChannel(name: string, activityId: string): Promise<ChannelCreatedResponse> {
    return request<ChannelCreatedResponse>(this.client, '/channel', {
      method: 'POST',
      data: { name, activity: activityId },
    })
  }

  async messages(channelId: string): Promise<ChannelMessage[]> {
    return request<ChannelMessage[]>(this.client, '/message', {
      query: { channel: channelId },
    })
  }

  async sendMessage(channelId: string, content: string): Promise<ChannelMessage> {
    return request<ChannelMessage>(this.client, `/channel/${channelId}`, {
      method: 'POST',
      data: { content },
    })
  }

  async exportBatch(): Promise<ExportBatchResponse> {
    return request<ExportBatchResponse>(this.client, '/export', { method: 'POST' })
  }

  async userName(userId: string): Promise<string> {
    const user = await request<UserProfile>(this.client, `/user/${userId}`)
    return user.realname
  }

  async users(params?: {
    group?: UserGroup | 'all'
    search?: string
    limit?: number
  }): Promise<UserProfile[]> {
    return request<UserProfile[]>(this.client, '/user', {
      query: {
        group: params?.group,
        search: params?.search,
        limit: params?.limit,
      },
    })
  }

  async adminCreateUser(form: AdminCreateUserForm): Promise<ApiMessage> {
    return request<ApiMessage>(this.client, '/user/admin_create', {
      method: 'POST',
      data: form,
    })
  }

  async notifications(params?: {
    unreadOnly?: boolean
    limit?: number
    before?: string
  }): Promise<NotificationResponse[]> {
    return request<NotificationResponse[]>(this.client, '/notification', {
      query: {
        unread_only: params?.unreadOnly ? '1' : undefined,
        limit: params?.limit,
        before: params?.before,
      },
    })
  }

  async notificationUnreadCount(): Promise<number> {
    const response = await request<{ count: number }>(
      this.client,
      '/notification/unread_count',
    )
    return response.count
  }

  async markNotificationsRead(ids: string[]): Promise<void> {
    await request<ApiMessage>(this.client, '/notification/read', {
      method: 'POST',
      data: { ids },
    })
  }

  async markAllNotificationsRead(): Promise<void> {
    await request<ApiMessage>(this.client, '/notification/read', {
      method: 'POST',
      data: { all: true },
    })
  }

  async notificationPreferences(): Promise<NotificationPreference[]> {
    return request<NotificationPreference[]>(this.client, '/notification/preferences')
  }

  async updateNotificationPreferences(
    preferences: NotificationPreference[],
  ): Promise<void> {
    await request<ApiMessage>(this.client, '/notification/preferences', {
      method: 'PUT',
      data: { preferences },
    })
  }

  async updateUser(userId: string, form: UpdateUserForm): Promise<UserProfile> {
    return request<UserProfile>(this.client, `/user/${userId}`, {
      method: 'PUT',
      data: form,
    })
  }

  async userClasses(params?: { group?: string }): Promise<UserClassSummary[]> {
    return request<UserClassSummary[]>(this.client, '/user/classes', {
      query: {
        group: params?.group,
      },
    })
  }

  async importUsersCsv(csvText: string, defaultPassword: string): Promise<UserBatchResult> {
    return request<UserBatchResult>(this.client, '/user/batch/import_csv', {
      method: 'POST',
      data: {
        csv_text: csvText,
        default_password: defaultPassword,
      },
    })
  }

  async batchUpdateClass(fromClassname: string, toClassname: string): Promise<UserBatchResult> {
    return request<UserBatchResult>(this.client, '/user/batch/update_class', {
      method: 'POST',
      data: {
        from_classname: fromClassname,
        to_classname: toClassname,
      },
    })
  }

  async batchDeleteClass(classname: string): Promise<UserBatchResult> {
    return request<UserBatchResult>(this.client, '/user/batch/delete_class', {
      method: 'POST',
      data: {
        classname,
      },
    })
  }

  async deleteUser(userId: string): Promise<void> {
    await request<ApiMessage>(this.client, `/user/${userId}`, { method: 'DELETE' })
  }

  pushURL(): string {
    return apiURL('/push')
  }
}

function serializeActivityDraft(draft: ActivityDraft) {
  return {
    name: draft.name,
    date: draft.dateEnabled && draft.dateValue ? new Date(draft.dateValue).toISOString() : null,
    max_volunteer_num: draft.hasParticipantLimit ? draft.maxVolunteerNum : null,
    description: draft.description,
    location: draft.location,
    brief_description: draft.briefDescription,
    duration: draft.duration,
  }
}
