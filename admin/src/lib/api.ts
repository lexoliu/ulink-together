import type {
  ActivityDetail,
  ActivitySummary,
  ActivityDraft,
  ApiMessage,
  AuthorityCheckResponse,
  AuthorityName,
  ChannelCreatedResponse,
  ChannelMessage,
  ChannelResponse,
  ExportBatchResponse,
  RecordEntry,
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
  'create_activity',
  'create_channel',
  'manage_record_anyway',
  'view_user',
  'generate_export',
]

function apiOrigin(): string {
  return import.meta.env.VITE_API_ORIGIN?.replace(/\/$/, '') ?? ''
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

async function readErrorMessage(response: Response): Promise<string> {
  try {
    const body = (await response.json()) as ApiMessage
    return body.message || response.statusText
  } catch {
    return response.statusText || 'Request failed'
  }
}

async function request<T>(
  path: string,
  init?: RequestInit,
  query?: Record<string, string | undefined | null>,
): Promise<T> {
  const response = await fetch(apiURL(path, query), {
    credentials: 'include',
    headers: {
      Accept: 'application/json',
      ...(init?.body ? { 'Content-Type': 'application/json' } : {}),
      ...init?.headers,
    },
    ...init,
  })

  if (!response.ok) {
    throw new ApiError(await readErrorMessage(response), response.status)
  }

  if (response.status === 204) {
    return undefined as T
  }

  return (await response.json()) as T
}

export class AdminApiClient {
  async login(email: string, password: string): Promise<void> {
    await request<ApiMessage>('/login', {
      method: 'POST',
      body: JSON.stringify({ email, password }),
    })
  }

  async logout(): Promise<void> {
    await request<ApiMessage>('/logout', { method: 'POST' })
  }

  async currentUser(): Promise<UserProfile> {
    return request<UserProfile>('/user/me')
  }

  async authorityMap(): Promise<Record<AuthorityName, boolean>> {
    const results = await Promise.all(
      authorityNames.map(async (authority) => {
        const response = await request<AuthorityCheckResponse>(`/auth/check/${authority}`)
        return [authority, response.result] as const
      }),
    )

    return Object.fromEntries(results) as Record<AuthorityName, boolean>
  }

  async activities(params?: { user?: string; displayAll?: boolean }): Promise<ActivitySummary[]> {
    return request<ActivitySummary[]>('/activity', undefined, {
      user: params?.user,
      display_all: params?.displayAll ? '1' : undefined,
    })
  }

  async activity(id: string): Promise<ActivityDetail> {
    return request<ActivityDetail>(`/activity/${id}`)
  }

  async createActivity(draft: ActivityDraft): Promise<ActivityDetail> {
    return request<ActivityDetail>('/activity', {
      method: 'POST',
      body: JSON.stringify(serializeActivityDraft(draft)),
    })
  }

  async updateActivity(id: string, draft: ActivityDraft): Promise<ActivityDetail> {
    return request<ActivityDetail>(`/activity/${id}`, {
      method: 'PUT',
      body: JSON.stringify(serializeActivityDraft(draft)),
    })
  }

  async transitionActivity(id: string, action: 'need_volunteer' | 'go' | 'end' | 'cancel'): Promise<void> {
    await request<ApiMessage>(`/activity/${id}/${action}`, { method: 'POST' })
  }

  async records(activityId: string): Promise<RecordEntry[]> {
    return request<RecordEntry[]>('/record', undefined, { activity: activityId })
  }

  async updateRecord(recordId: string, action: 'done' | 'approve_apply' | 'disapprove_apply'): Promise<void> {
    await request<ApiMessage>(`/record/${recordId}/${action}`, { method: 'POST' })
  }

  async channels(activityId: string): Promise<ChannelResponse[]> {
    return request<ChannelResponse[]>('/channel', undefined, { activity: activityId })
  }

  async createChannel(name: string, activityId: string): Promise<ChannelCreatedResponse> {
    return request<ChannelCreatedResponse>('/channel', {
      method: 'POST',
      body: JSON.stringify({ name, activity: activityId }),
    })
  }

  async messages(channelId: string): Promise<ChannelMessage[]> {
    return request<ChannelMessage[]>('/message', undefined, { channel: channelId })
  }

  async sendMessage(channelId: string, content: string): Promise<ChannelMessage> {
    return request<ChannelMessage>(`/channel/${channelId}`, {
      method: 'POST',
      body: JSON.stringify({ content }),
    })
  }

  async exportBatch(): Promise<ExportBatchResponse> {
    return request<ExportBatchResponse>('/export', { method: 'POST' })
  }

  async userName(userId: string): Promise<string> {
    const user = await request<UserProfile>(`/user/${userId}`)
    return user.realname
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
