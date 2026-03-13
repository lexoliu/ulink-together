import { useMemo, useState } from 'react'
import {
  CheckCircle2,
  ChevronRight,
  Clock3,
  Download,
  FileSpreadsheet,
  FolderKanban,
  House,
  ListFilter,
  LogOut,
  Plus,
  Search,
  Sparkles,
} from 'lucide-react'
import { useMutation, useQuery, useQueryClient, type QueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'

import './App.css'
import { ActivityFormDialog } from '@/components/activity-form-dialog'
import { ActivityRecordsTable } from '@/components/activity-records-table'
import { ChannelPanel } from '@/components/channel-panel'
import { ExportBatchDialog } from '@/components/export-batch-dialog'
import { LoginScreen } from '@/components/login-screen'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { ScrollArea } from '@/components/ui/scroll-area'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { Separator } from '@/components/ui/separator'
import { Skeleton } from '@/components/ui/skeleton'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { AdminApiClient, ApiError } from '@/lib/api'
import {
  activityStateLabel,
  formatDateOnly,
  formatDateTime,
  formatDuration,
} from '@/lib/format'
import type {
  ActivityDetail,
  ActivityDraft,
  ActivitySummary,
  AuthorityName,
  ChannelMessage,
  ChannelResponse,
  ExportBatchResponse,
  RecordEntry,
  UserProfile,
} from '@/lib/types'

type PanelTab = 'overview' | 'records' | 'channel'
type ActivityScope = 'all' | 'mine'
type ActivityFilter = 'all' | 'need_volunteer' | 'going' | 'ended' | 'canceled'
type AdminView = 'home' | 'activities'

const api = new AdminApiClient()

const emptyDraft: ActivityDraft = {
  name: '',
  dateEnabled: true,
  dateValue: '',
  hasParticipantLimit: true,
  maxVolunteerNum: 20,
  location: '',
  briefDescription: '',
  description: '',
  duration: 120,
}

function App() {
  const queryClient = useQueryClient()

  const [authEpoch, setAuthEpoch] = useState(0)
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [loginError, setLoginError] = useState<string | null>(null)
  const [selectedActivityId, setSelectedActivityId] = useState<string | null>(null)
  const [panelTab, setPanelTab] = useState<PanelTab>('overview')
  const [currentView, setCurrentView] = useState<AdminView>('home')
  const [search, setSearch] = useState('')
  const [scope, setScope] = useState<ActivityScope>('all')
  const [stateFilter, setStateFilter] = useState<ActivityFilter>('all')
  const [formOpen, setFormOpen] = useState(false)
  const [editingActivity, setEditingActivity] = useState<ActivityDetail | null>(null)
  const [exportBatch, setExportBatch] = useState<ExportBatchResponse | null>(null)
  const [recordActionId, setRecordActionId] = useState<string | null>(null)

  const currentUserQuery = useQuery({
    queryKey: ['current-user', authEpoch],
    queryFn: () => api.currentUser(),
    retry: false,
    staleTime: 60_000,
  })

  const currentUser = currentUserQuery.data ?? null
  const authError = currentUserQuery.error as ApiError | undefined
  const isSignedOut = !currentUser && currentUserQuery.isFetched
  const backgroundError =
    authError && ![401, 403].includes(authError.status) ? authError.message : null

  const authoritiesQuery = useQuery({
    queryKey: ['authorities', currentUser?.id],
    queryFn: () => api.authorityMap(),
    enabled: Boolean(currentUser),
    staleTime: 5 * 60_000,
  })

  const authorities = authoritiesQuery.data ?? ({} as Record<AuthorityName, boolean>)

  const activitiesQuery = useQuery({
    queryKey: ['activities', currentUser?.id],
    queryFn: () => api.activities({ displayAll: true }),
    enabled: Boolean(currentUser),
  })

  const filteredActivities = useMemo(() => {
    const activities = activitiesQuery.data ?? []

    return activities.filter((activity) => {
      if (scope === 'mine' && activity.promoter !== currentUser?.id) {
        return false
      }

      if (stateFilter !== 'all' && activity.state !== stateFilter) {
        return false
      }

      if (!search.trim()) {
        return true
      }

      const query = search.toLowerCase()
      return [activity.name, activity.location, activity.brief_description]
        .join(' ')
        .toLowerCase()
        .includes(query)
    })
  }, [activitiesQuery.data, currentUser?.id, scope, search, stateFilter])

  const resolvedSelectedActivityId =
    selectedActivityId &&
    filteredActivities.some((activity) => activity.id === selectedActivityId)
      ? selectedActivityId
      : filteredActivities[0]?.id ?? null

  const selectedDetailQuery = useQuery({
    queryKey: ['activity-detail', resolvedSelectedActivityId],
    queryFn: () => api.activity(resolvedSelectedActivityId!),
    enabled: Boolean(resolvedSelectedActivityId),
  })

  const selectedDetail = selectedDetailQuery.data ?? null

  const recordsQuery = useQuery({
    queryKey: ['activity-records', resolvedSelectedActivityId],
    queryFn: () => api.records(resolvedSelectedActivityId!),
    enabled: Boolean(resolvedSelectedActivityId),
  })

  const participantIds = useMemo(
    () => Array.from(new Set((recordsQuery.data ?? []).map((record) => record.user))),
    [recordsQuery.data],
  )

  const participantNamesQuery = useQuery({
    queryKey: ['participant-names', participantIds],
    queryFn: async () => {
      const names = await Promise.all(
        participantIds.map(async (userId) => [userId, await api.userName(userId)] as const),
      )
      return Object.fromEntries(names)
    },
    enabled: participantIds.length > 0 && authorities.view_user === true,
  })

  const channelQuery = useQuery({
    queryKey: ['channels', resolvedSelectedActivityId],
    queryFn: async () => {
      const channels = await api.channels(resolvedSelectedActivityId!)
      return channels[0] ?? null
    },
    enabled: Boolean(resolvedSelectedActivityId),
  })

  const messagesQuery = useQuery({
    queryKey: ['messages', channelQuery.data?.id],
    queryFn: () => api.messages(channelQuery.data!.id),
    enabled: Boolean(channelQuery.data?.id),
  })

  const channelParticipantIds = useMemo(
    () =>
      Array.from(new Set((messagesQuery.data ?? []).map((message) => message.sender))).filter(
        (userId) => userId !== currentUser?.id,
      ),
    [currentUser?.id, messagesQuery.data],
  )

  const messageNamesQuery = useQuery({
    queryKey: ['message-names', channelParticipantIds],
    queryFn: async () => {
      const names = await Promise.all(
        channelParticipantIds.map(async (userId) => [userId, await api.userName(userId)] as const),
      )
      return Object.fromEntries(names)
    },
    enabled: channelParticipantIds.length > 0 && authorities.view_user === true,
  })

  const loginMutation = useMutation({
    mutationFn: async () => {
      if (!email.trim() || !password.trim()) {
        throw new ApiError('Email and password are required.', 400)
      }

      await api.login(email.trim(), password)
    },
    onSuccess: async () => {
      setLoginError(null)
      setPassword('')
      await queryClient.invalidateQueries({ queryKey: ['current-user'] })
      setAuthEpoch((value) => value + 1)
      toast.success('Signed in.')
    },
    onError: (error) => {
      setLoginError(error instanceof ApiError ? error.message : 'Sign-in failed.')
    },
  })

  const logoutMutation = useMutation({
    mutationFn: () => api.logout(),
    onSuccess: async () => {
      queryClient.clear()
      setSelectedActivityId(null)
      setCurrentView('home')
      setAuthEpoch((value) => value + 1)
      toast.success('Signed out.')
    },
    onError: showMutationError,
  })

  const createActivityMutation = useMutation({
    mutationFn: (draft: ActivityDraft) => api.createActivity(draft),
    onSuccess: async (activity) => {
      toast.success('Activity created.')
      setFormOpen(false)
      setEditingActivity(null)
      setSelectedActivityId(activity.id)
      setCurrentView('activities')
      await queryClient.invalidateQueries({ queryKey: ['activities'] })
      await queryClient.invalidateQueries({ queryKey: ['activity-detail'] })
    },
    onError: showMutationError,
  })

  const updateActivityMutation = useMutation({
    mutationFn: ({ id, draft }: { id: string; draft: ActivityDraft }) =>
      api.updateActivity(id, draft),
    onSuccess: async (activity) => {
      toast.success('Activity updated.')
      setFormOpen(false)
      setEditingActivity(null)
      setSelectedActivityId(activity.id)
      await queryClient.invalidateQueries({ queryKey: ['activities'] })
      await queryClient.invalidateQueries({ queryKey: ['activity-detail', activity.id] })
    },
    onError: showMutationError,
  })

  const activityActionMutation = useMutation({
    mutationFn: ({
      id,
      action,
    }: {
      id: string
      action: 'need_volunteer' | 'go' | 'end' | 'cancel'
    }) => api.transitionActivity(id, action),
    onSuccess: async () => {
      toast.success('Activity status updated.')
      await invalidateSelectedActivity(queryClient, resolvedSelectedActivityId)
    },
    onError: showMutationError,
  })

  const recordActionMutation = useMutation({
    mutationFn: async ({
      id,
      action,
    }: {
      id: string
      action: 'approve_apply' | 'done' | 'disapprove_apply'
    }) => {
      setRecordActionId(id)
      await api.updateRecord(id, action)
    },
    onSuccess: async () => {
      setRecordActionId(null)
      toast.success('Record updated.')
      await invalidateSelectedActivity(queryClient, resolvedSelectedActivityId)
    },
    onError: (error) => {
      setRecordActionId(null)
      showMutationError(error)
    },
  })

  const exportMutation = useMutation({
    mutationFn: () => api.exportBatch(),
    onSuccess: (batch) => {
      setExportBatch(batch)
      toast.success('Export batch generated.')
    },
    onError: showMutationError,
  })

  const createChannelMutation = useMutation({
    mutationFn: async () => {
      if (!resolvedSelectedActivityId || !selectedDetail) {
        throw new ApiError('Choose an activity first.', 400)
      }
      return api.createChannel(`${selectedDetail.name} Channel`, resolvedSelectedActivityId)
    },
    onSuccess: async () => {
      toast.success('Channel created.')
      await queryClient.invalidateQueries({ queryKey: ['channels', resolvedSelectedActivityId] })
    },
    onError: showMutationError,
  })

  const sendMessageMutation = useMutation({
    mutationFn: async (content: string) => {
      if (!channelQuery.data) {
        throw new ApiError('No channel is available yet.', 400)
      }
      return api.sendMessage(channelQuery.data.id, content)
    },
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ['messages', channelQuery.data?.id] })
    },
    onError: showMutationError,
  })

  const participantNames = participantNamesQuery.data ?? {}
  const senderNames = {
    ...participantNames,
    ...(messageNamesQuery.data ?? {}),
    ...(currentUser ? { [currentUser.id]: currentUser.realname } : {}),
  }

  const metrics = useMemo(
    () => deriveMetrics(activitiesQuery.data ?? []),
    [activitiesQuery.data],
  )

  const recentActivities = useMemo(
    () =>
      (activitiesQuery.data ?? [])
        .slice()
        .sort((a, b) => (a.date ?? '').localeCompare(b.date ?? ''))
        .slice(0, 5),
    [activitiesQuery.data],
  )

  if (!currentUser && currentUserQuery.isLoading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-slate-50">
        <div className="grid w-full max-w-sm gap-3">
          <Skeleton className="h-8 w-40" />
          <Skeleton className="h-32 w-full rounded-2xl" />
        </div>
      </div>
    )
  }

  if (isSignedOut) {
    return (
      <LoginScreen
        email={email}
        password={password}
        pending={loginMutation.isPending}
        errorMessage={loginError ?? backgroundError}
        onEmailChange={setEmail}
        onPasswordChange={setPassword}
        onSubmit={async () => {
          await loginMutation.mutateAsync()
        }}
      />
    )
  }

  const canCreateActivity = authorities.create_activity === true
  const canCreateChannel = authorities.create_channel === true
  const canGenerateExport = authorities.generate_export === true
  const canManageSelectedActivity =
    selectedDetail !== null &&
    (selectedDetail.promoter === currentUser?.id || authorities.manage_record_anyway === true)

  return (
    <>
      <div className="min-h-screen bg-[radial-gradient(circle_at_top_right,_rgba(14,165,233,0.16),_transparent_28%),radial-gradient(circle_at_bottom_left,_rgba(20,184,166,0.14),_transparent_32%),linear-gradient(to_bottom,_#f8fafc,_#eef2ff)]">
        <div className="mx-auto flex min-h-screen max-w-[1600px] gap-6 px-6 py-6">
          <aside className="hidden w-72 shrink-0 flex-col rounded-[2rem] border border-white/70 bg-white/88 p-6 shadow-xl shadow-slate-200/50 backdrop-blur lg:flex">
            <div className="space-y-4">
              <div className="inline-flex items-center gap-2 rounded-full bg-slate-950 px-3 py-1 text-xs font-medium uppercase tracking-[0.18em] text-white">
                <Sparkles className="size-3.5" />
                Admin workspace
              </div>
              <div>
                <h1 className="text-2xl font-semibold tracking-tight text-slate-950">
                  Volunteer operations
                </h1>
                <p className="mt-2 text-sm leading-6 text-slate-600">
                  A calmer control room for schedules, attendance, messaging, and reporting.
                </p>
              </div>
            </div>

            <Separator className="my-6" />

            <nav className="grid gap-2">
              <SidebarItem
                active={currentView === 'home'}
                icon={<House className="size-4" />}
                label="Home"
                onClick={() => setCurrentView('home')}
              />
              <SidebarItem
                active={currentView === 'activities'}
                icon={<FolderKanban className="size-4" />}
                label="Activities"
                onClick={() => setCurrentView('activities')}
              />
            </nav>

            <Separator className="my-6" />

            <div className="grid gap-3">
              {metrics.map(([title, value, description]) => (
                <MetricPill key={title} title={title} value={value} description={description} />
              ))}
            </div>

            <div className="mt-auto rounded-2xl border border-slate-200/80 bg-slate-50/90 px-4 py-4 shadow-sm">
              <div className="flex items-center gap-3">
                <div className="flex size-10 items-center justify-center rounded-full bg-slate-900 text-sm font-semibold text-white">
                  {initials(currentUser)}
                </div>
                <div className="min-w-0">
                  <p className="truncate font-medium text-slate-950">{currentUser?.realname}</p>
                  <p className="truncate text-sm text-slate-500">{currentUser?.email}</p>
                </div>
              </div>

              <Button
                variant="outline"
                className="mt-4 w-full justify-center"
                disabled={logoutMutation.isPending}
                onClick={() => logoutMutation.mutate()}
              >
                <LogOut className="mr-2 size-4" />
                Sign out
              </Button>
            </div>
          </aside>

          <main className="flex min-w-0 flex-1 flex-col gap-6">
            <header className="rounded-[2rem] border border-white/70 bg-white/80 px-6 py-5 shadow-lg shadow-slate-200/45 backdrop-blur lg:hidden">
              <div className="flex items-center justify-between gap-3">
                <div>
                  <p className="text-sm font-medium text-slate-500">Admin</p>
                  <h1 className="text-2xl font-semibold tracking-tight text-slate-950">
                    Volunteer operations
                  </h1>
                </div>
                <Button
                  variant="outline"
                  size="sm"
                  disabled={logoutMutation.isPending}
                  onClick={() => logoutMutation.mutate()}
                >
                  <LogOut className="mr-2 size-4" />
                  Sign out
                </Button>
              </div>

              <div className="mt-4 flex gap-2">
                <SidebarItem
                  active={currentView === 'home'}
                  icon={<House className="size-4" />}
                  label="Home"
                  onClick={() => setCurrentView('home')}
                />
                <SidebarItem
                  active={currentView === 'activities'}
                  icon={<FolderKanban className="size-4" />}
                  label="Activities"
                  onClick={() => setCurrentView('activities')}
                />
              </div>
            </header>

            {currentView === 'home' ? (
              <HomePage
                user={currentUser}
                metrics={metrics}
                recentActivities={recentActivities}
                canCreateActivity={canCreateActivity}
                canGenerateExport={canGenerateExport}
                isExporting={exportMutation.isPending}
                onCreateActivity={() => {
                  setEditingActivity(null)
                  setFormOpen(true)
                }}
                onGenerateExport={() => exportMutation.mutate()}
                onOpenActivity={(activityId) => {
                  setSelectedActivityId(activityId)
                  setCurrentView('activities')
                }}
              />
            ) : (
              <ActivitiesPage
                search={search}
                scope={scope}
                stateFilter={stateFilter}
                filteredActivities={filteredActivities}
                selectedActivityId={resolvedSelectedActivityId}
                activitiesLoading={activitiesQuery.isLoading}
                selectedDetail={selectedDetail}
                records={recordsQuery.data ?? []}
                participantNames={participantNames}
                senderNames={senderNames}
                currentUserId={currentUser?.id ?? null}
                panelTab={panelTab}
                channel={channelQuery.data ?? null}
                messages={messagesQuery.data ?? []}
                recordActionId={recordActionId}
                canCreateActivity={canCreateActivity}
                canCreateChannel={canCreateChannel}
                canGenerateExport={canGenerateExport}
                canManageSelectedActivity={canManageSelectedActivity}
                isCreatingChannel={createChannelMutation.isPending}
                isSendingMessage={sendMessageMutation.isPending}
                isExporting={exportMutation.isPending}
                onSearchChange={setSearch}
                onScopeChange={setScope}
                onStateFilterChange={setStateFilter}
                onSelectActivity={setSelectedActivityId}
                onCreateActivity={() => {
                  setEditingActivity(null)
                  setFormOpen(true)
                }}
                onEditActivity={() => {
                  if (selectedDetail) {
                    setEditingActivity(selectedDetail)
                    setFormOpen(true)
                  }
                }}
                onGenerateExport={() => exportMutation.mutate()}
                onTransition={(action) => {
                  if (selectedDetail) {
                    activityActionMutation.mutate({ id: selectedDetail.id, action })
                  }
                }}
                onPanelTabChange={setPanelTab}
                onRecordAction={(id, action) => recordActionMutation.mutate({ id, action })}
                onCreateChannel={() => createChannelMutation.mutate()}
                onSendMessage={async (content) => {
                  await sendMessageMutation.mutateAsync(content)
                }}
                pushUrl={api.pushURL()}
              />
            )}
          </main>
        </div>
      </div>

      <ActivityFormDialog
        open={formOpen}
        title={editingActivity ? 'Edit activity' : 'Create activity'}
        description={
          editingActivity
            ? 'Refine the activity plan without leaving the dashboard.'
            : 'Publish a new volunteer opportunity with clean, complete details.'
        }
        initialValue={draftFromActivity(editingActivity)}
        onOpenChange={(open) => {
          setFormOpen(open)
          if (!open) {
            setEditingActivity(null)
          }
        }}
        onSubmit={async (draft) => {
          if (editingActivity) {
            await updateActivityMutation.mutateAsync({ id: editingActivity.id, draft })
          } else {
            await createActivityMutation.mutateAsync(draft)
          }
        }}
      />

      <ExportBatchDialog
        open={Boolean(exportBatch)}
        batch={exportBatch}
        onOpenChange={(open) => {
          if (!open) {
            setExportBatch(null)
          }
        }}
      />
    </>
  )
}

function HomePage({
  user,
  metrics,
  recentActivities,
  canCreateActivity,
  canGenerateExport,
  isExporting,
  onCreateActivity,
  onGenerateExport,
  onOpenActivity,
}: {
  user: UserProfile | null
  metrics: readonly (readonly [string, string, string])[]
  recentActivities: ActivitySummary[]
  canCreateActivity: boolean
  canGenerateExport: boolean
  isExporting: boolean
  onCreateActivity: () => void
  onGenerateExport: () => void
  onOpenActivity: (activityId: string) => void
}) {
  return (
    <div className="grid gap-6">
      <Card className="border-white/70 bg-white/88 shadow-xl shadow-slate-200/45">
        <CardHeader className="gap-5 lg:flex-row lg:items-start lg:justify-between">
          <div>
            <CardDescription>Home</CardDescription>
            <CardTitle className="mt-1 text-3xl font-semibold tracking-tight text-slate-950">
              Welcome back, {user?.realname ?? 'admin'}
            </CardTitle>
            <CardDescription className="mt-2 max-w-3xl text-sm leading-7">
              Start from the overview, then jump into activities when you need to update publishing state, confirm records, or watch channel traffic.
            </CardDescription>
          </div>

          <div className="flex flex-wrap gap-2">
            {canCreateActivity ? (
              <Button onClick={onCreateActivity}>
                <Plus className="mr-2 size-4" />
                New activity
              </Button>
            ) : null}
            {canGenerateExport ? (
              <Button variant="outline" disabled={isExporting} onClick={onGenerateExport}>
                <Download className="mr-2 size-4" />
                {isExporting ? 'Preparing…' : 'Generate export'}
              </Button>
            ) : null}
          </div>
        </CardHeader>
        <CardContent className="grid gap-4 md:grid-cols-3">
          {metrics.map(([title, value, description]) => (
            <OverviewMetric
              key={title}
              label={title}
              value={value}
              description={description}
              icon={<Sparkles className="size-4" />}
            />
          ))}
        </CardContent>
      </Card>

      <div className="grid gap-6 xl:grid-cols-[1.2fr_0.8fr]">
        <Card className="border-white/70 bg-white/88 shadow-lg shadow-slate-200/40">
          <CardHeader>
            <CardTitle>Recent activities</CardTitle>
            <CardDescription>
              Open a workspace for the event you want to manage now.
            </CardDescription>
          </CardHeader>
          <CardContent className="grid gap-3">
            {recentActivities.length > 0 ? (
              recentActivities.map((activity) => (
                <button
                  key={activity.id}
                  type="button"
                  className="flex items-center justify-between rounded-2xl border border-border/70 bg-background px-4 py-4 text-left transition hover:border-slate-300 hover:bg-slate-50"
                  onClick={() => onOpenActivity(activity.id)}
                >
                  <div>
                    <p className="font-medium text-slate-950">{activity.name}</p>
                    <p className="mt-1 text-sm text-slate-600">
                      {formatDateOnly(activity.date)} · {activity.location}
                    </p>
                  </div>
                  <div className="flex items-center gap-3">
                    <Badge variant="secondary">{activityStateLabel(activity.state)}</Badge>
                    <ChevronRight className="size-4 text-slate-400" />
                  </div>
                </button>
              ))
            ) : (
              <div className="rounded-2xl border border-dashed border-border bg-muted/20 p-6 text-sm text-muted-foreground">
                No activities have been published yet.
              </div>
            )}
          </CardContent>
        </Card>

        <Card className="border-white/70 bg-white/88 shadow-lg shadow-slate-200/40">
          <CardHeader>
            <CardTitle>Admin notes</CardTitle>
            <CardDescription>
              A quick reminder of what this surface is optimized for.
            </CardDescription>
          </CardHeader>
          <CardContent className="grid gap-4 text-sm text-slate-600">
            <div className="rounded-2xl border border-border/70 bg-muted/20 p-4">
              Keep activity details crisp so volunteers can commit without follow-up clarification.
            </div>
            <div className="rounded-2xl border border-border/70 bg-muted/20 p-4">
              Confirm records promptly after activities end so export batches stay current.
            </div>
            <div className="rounded-2xl border border-border/70 bg-muted/20 p-4">
              Use the channel tab when you need to verify real-time organiser and volunteer coordination.
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}

function ActivitiesPage({
  search,
  scope,
  stateFilter,
  filteredActivities,
  selectedActivityId,
  activitiesLoading,
  selectedDetail,
  records,
  participantNames,
  senderNames,
  currentUserId,
  panelTab,
  channel,
  messages,
  recordActionId,
  canCreateActivity,
  canCreateChannel,
  canGenerateExport,
  canManageSelectedActivity,
  isCreatingChannel,
  isSendingMessage,
  isExporting,
  onSearchChange,
  onScopeChange,
  onStateFilterChange,
  onSelectActivity,
  onCreateActivity,
  onEditActivity,
  onGenerateExport,
  onTransition,
  onPanelTabChange,
  onRecordAction,
  onCreateChannel,
  onSendMessage,
  pushUrl,
}: {
  search: string
  scope: ActivityScope
  stateFilter: ActivityFilter
  filteredActivities: ActivitySummary[]
  selectedActivityId: string | null
  activitiesLoading: boolean
  selectedDetail: ActivityDetail | null
  records: RecordEntry[]
  participantNames: Record<string, string>
  senderNames: Record<string, string>
  currentUserId: string | null
  panelTab: PanelTab
  channel: ChannelResponse | null
  messages: ChannelMessage[]
  recordActionId: string | null
  canCreateActivity: boolean
  canCreateChannel: boolean
  canGenerateExport: boolean
  canManageSelectedActivity: boolean
  isCreatingChannel: boolean
  isSendingMessage: boolean
  isExporting: boolean
  onSearchChange: (value: string) => void
  onScopeChange: (value: ActivityScope) => void
  onStateFilterChange: (value: ActivityFilter) => void
  onSelectActivity: (value: string) => void
  onCreateActivity: () => void
  onEditActivity: () => void
  onGenerateExport: () => void
  onTransition: (action: 'need_volunteer' | 'go' | 'end' | 'cancel') => void
  onPanelTabChange: (value: PanelTab) => void
  onRecordAction: (id: string, action: 'approve_apply' | 'done' | 'disapprove_apply') => void
  onCreateChannel: () => void
  onSendMessage: (content: string) => Promise<void>
  pushUrl: string
}) {
  return (
    <>
      <div className="rounded-[2rem] border border-white/70 bg-white/88 px-6 py-5 shadow-lg shadow-slate-200/40">
        <div className="flex flex-col gap-2 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <p className="text-sm font-medium text-slate-500">Activities</p>
            <h2 className="text-2xl font-semibold tracking-tight text-slate-950">
              Manage publishing, records, and live coordination
            </h2>
          </div>
          {canCreateActivity ? (
            <Button onClick={onCreateActivity}>
              <Plus className="mr-2 size-4" />
              New activity
            </Button>
          ) : null}
        </div>
      </div>

      <div className="grid gap-8 xl:grid-cols-[340px_minmax(0,1fr)]">
        <Card className="border-white/70 bg-white/88 shadow-lg shadow-slate-200/40">
          <CardHeader className="gap-4">
            <div>
              <CardTitle>Activity list</CardTitle>
              <CardDescription>Pick the event you want to work on.</CardDescription>
            </div>
            <div className="grid gap-3">
              <div className="relative">
                <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
                <Input
                  className="pl-9"
                  placeholder="Search activity name or location"
                  value={search}
                  onChange={(event) => onSearchChange(event.target.value)}
                />
              </div>

              <div className="grid gap-3 sm:grid-cols-2">
                <Select value={scope} onValueChange={(value) => onScopeChange(value as ActivityScope)}>
                  <SelectTrigger className="w-full">
                    <SelectValue placeholder="Scope" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">All activities</SelectItem>
                    <SelectItem value="mine">My activities</SelectItem>
                  </SelectContent>
                </Select>

                <Select
                  value={stateFilter}
                  onValueChange={(value) => onStateFilterChange(value as ActivityFilter)}
                >
                  <SelectTrigger className="w-full">
                    <ListFilter className="size-4" />
                    <SelectValue placeholder="State" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">All states</SelectItem>
                    <SelectItem value="need_volunteer">Recruiting</SelectItem>
                    <SelectItem value="going">In progress</SelectItem>
                    <SelectItem value="ended">Completed</SelectItem>
                    <SelectItem value="canceled">Cancelled</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </div>
          </CardHeader>

          <CardContent className="pb-0">
            <ScrollArea className="h-[calc(100vh-20rem)] pr-3">
              <div className="grid gap-4 pb-4">
                {activitiesLoading ? (
                  <>
                    <Skeleton className="h-32 rounded-2xl" />
                    <Skeleton className="h-32 rounded-2xl" />
                  </>
                ) : filteredActivities.length > 0 ? (
                  filteredActivities.map((activity) => (
                    <button
                      key={activity.id}
                      type="button"
                      onClick={() => onSelectActivity(activity.id)}
                      className={`rounded-2xl border p-5 text-left transition ${
                        activity.id === selectedActivityId
                          ? 'border-sky-400 bg-sky-50 shadow-sm'
                          : 'border-border/70 bg-background hover:border-slate-300 hover:bg-slate-50'
                      }`}
                    >
                      <div className="flex items-start justify-between gap-3">
                        <div>
                          <h3 className="text-base font-semibold text-slate-950">{activity.name}</h3>
                          <p className="mt-1 line-clamp-2 text-sm leading-6 text-slate-600">
                            {activity.brief_description}
                          </p>
                        </div>
                        <Badge variant="secondary">{activityStateLabel(activity.state)}</Badge>
                      </div>

                      <div className="mt-4 grid gap-2 text-xs text-slate-500">
                        <div className="flex items-center justify-between">
                          <span>{formatDateOnly(activity.date)}</span>
                          <span>
                            {activity.volunteer_num}/{activity.max_volunteer_num ?? '∞'}
                          </span>
                        </div>
                        <div className="flex items-center justify-between">
                          <span>{activity.location}</span>
                          <span>{formatDuration(activity.duration)}</span>
                        </div>
                      </div>
                    </button>
                  ))
                ) : (
                  <div className="rounded-2xl border border-dashed border-border bg-muted/20 p-6 text-sm text-muted-foreground">
                    No activities match the current filters.
                  </div>
                )}
              </div>
            </ScrollArea>
          </CardContent>
        </Card>

        <div className="grid gap-6">
          {selectedDetail ? (
            <>
              <Card className="border-white/70 bg-white/92 shadow-lg shadow-slate-200/40">
                <CardHeader className="gap-5">
                  <div className="flex flex-col gap-5 xl:flex-row xl:items-start xl:justify-between">
                    <div className="space-y-4">
                      <div className="flex flex-wrap items-center gap-2">
                        <Badge variant="secondary">{activityStateLabel(selectedDetail.state)}</Badge>
                        <Badge variant="outline">{formatDuration(selectedDetail.duration)}</Badge>
                        <Badge variant="outline">
                          {selectedDetail.volunteer_num}/{selectedDetail.max_volunteer_num ?? '∞'} volunteers
                        </Badge>
                      </div>

                      <div>
                        <CardTitle className="text-4xl font-semibold tracking-tight text-slate-950">
                          {selectedDetail.name}
                        </CardTitle>
                        <CardDescription className="mt-3 max-w-3xl text-sm leading-7">
                          {selectedDetail.description}
                        </CardDescription>
                      </div>

                      <div className="flex flex-wrap gap-x-8 gap-y-4 text-sm">
                        <InlineMeta label="Organiser" value={selectedDetail.promoter_name} />
                        <InlineMeta label="Date" value={formatDateTime(selectedDetail.date)} />
                        <InlineMeta label="Location" value={selectedDetail.location} />
                      </div>
                    </div>

                    <div className="flex flex-wrap gap-2">
                      {canCreateActivity ? (
                        <Button variant="outline" onClick={onEditActivity}>
                          Edit
                        </Button>
                      ) : null}

                      {canGenerateExport ? (
                        <Button variant="outline" disabled={isExporting} onClick={onGenerateExport}>
                          <Download className="mr-2 size-4" />
                          {isExporting ? 'Preparing…' : 'Export'}
                        </Button>
                      ) : null}
                    </div>
                  </div>

                  <div className="flex flex-wrap gap-2">
                    <Button
                      variant={selectedDetail.state === 'need_volunteer' ? 'default' : 'outline'}
                      disabled={!canManageSelectedActivity}
                      onClick={() => onTransition('need_volunteer')}
                    >
                      Recruiting
                    </Button>
                    <Button
                      variant={selectedDetail.state === 'going' ? 'default' : 'outline'}
                      disabled={!canManageSelectedActivity}
                      onClick={() => onTransition('go')}
                    >
                      Start
                    </Button>
                    <Button
                      variant={selectedDetail.state === 'ended' ? 'default' : 'outline'}
                      disabled={!canManageSelectedActivity}
                      onClick={() => onTransition('end')}
                    >
                      Complete
                    </Button>
                    <Button
                      variant="destructive"
                      disabled={!canManageSelectedActivity}
                      onClick={() => onTransition('cancel')}
                    >
                      Cancel
                    </Button>
                  </div>
                </CardHeader>
              </Card>

              <Tabs value={panelTab} onValueChange={(value) => onPanelTabChange(value as PanelTab)} className="gap-5">
                <TabsList variant="line" className="rounded-2xl bg-white/82 p-1.5 shadow-sm">
                  <TabsTrigger value="overview">Overview</TabsTrigger>
                  <TabsTrigger value="records">Records</TabsTrigger>
                  <TabsTrigger value="channel">Channel</TabsTrigger>
                </TabsList>

                <TabsContent value="overview">
                  <Card className="border-white/70 bg-white/92 shadow-lg shadow-slate-200/40">
                    <CardHeader>
                      <CardTitle>Activity snapshot</CardTitle>
                      <CardDescription>
                        Keep organisers aligned on recruiting pressure, timing, and readiness.
                      </CardDescription>
                    </CardHeader>
                    <CardContent className="grid gap-4 md:grid-cols-3">
                      <OverviewMetric
                        label="Scheduled"
                        value={formatDateTime(selectedDetail.date)}
                        description="The next confirmed start time."
                        icon={<Clock3 className="size-4" />}
                      />
                      <OverviewMetric
                        label="Participants"
                        value={`${selectedDetail.volunteer_num}/${selectedDetail.max_volunteer_num ?? '∞'}`}
                        description="Joined volunteers against available capacity."
                        icon={<CheckCircle2 className="size-4" />}
                      />
                      <OverviewMetric
                        label="Export readiness"
                        value={canGenerateExport ? 'Ready' : 'Unavailable'}
                        description={
                          canGenerateExport
                            ? 'Generate CSV once records are confirmed.'
                            : 'This account cannot export batches.'
                        }
                        icon={<FileSpreadsheet className="size-4" />}
                      />
                    </CardContent>
                  </Card>
                </TabsContent>

                <TabsContent value="records">
                  <ActivityRecordsTable
                    records={records}
                    names={participantNames}
                    canManage={canManageSelectedActivity}
                    pendingActionId={recordActionId ?? undefined}
                    onRecordAction={onRecordAction}
                  />
                </TabsContent>

                <TabsContent value="channel">
                  <ChannelPanel
                    pushUrl={pushUrl}
                    channel={channel}
                    initialMessages={messages}
                    senderNames={senderNames}
                    currentUserId={currentUserId}
                    canCreateChannel={canCreateChannel}
                    isCreatingChannel={isCreatingChannel}
                    isSendingMessage={isSendingMessage}
                    onCreateChannel={onCreateChannel}
                    onSendMessage={onSendMessage}
                  />
                </TabsContent>
              </Tabs>
            </>
          ) : (
            <Card className="border-white/70 bg-white/92 shadow-lg shadow-slate-200/40">
              <CardContent className="flex min-h-[480px] flex-col items-center justify-center gap-4 text-center">
                <div className="flex size-14 items-center justify-center rounded-2xl bg-slate-950 text-white">
                  <FileSpreadsheet className="size-6" />
                </div>
                <div>
                  <h2 className="text-xl font-semibold text-slate-950">Choose an activity</h2>
                  <p className="mt-2 max-w-md text-sm leading-6 text-slate-600">
                    Activity detail, participant records, channel traffic, and export controls appear here.
                  </p>
                </div>
              </CardContent>
            </Card>
          )}
        </div>
      </div>
    </>
  )
}

function SidebarItem({
  active,
  icon,
  label,
  onClick,
}: {
  active: boolean
  icon: React.ReactNode
  label: string
  onClick: () => void
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`flex items-center gap-3 rounded-2xl px-4 py-3 text-left text-sm font-medium transition ${
        active
          ? 'bg-slate-950 text-white shadow-sm'
          : 'bg-transparent text-slate-600 hover:bg-slate-100 hover:text-slate-950'
      }`}
    >
      {icon}
      <span>{label}</span>
    </button>
  )
}

function MetricPill({
  title,
  value,
  description,
}: {
  title: string
  value: string
  description: string
}) {
  return (
    <div className="rounded-2xl border border-slate-200/80 bg-slate-50/80 px-4 py-4">
      <p className="text-xs font-medium uppercase tracking-[0.18em] text-slate-500">{title}</p>
      <p className="mt-2 text-2xl font-semibold tracking-tight text-slate-950">{value}</p>
      <p className="mt-1 text-sm text-slate-600">{description}</p>
    </div>
  )
}

function OverviewMetric({
  label,
  value,
  description,
  icon,
}: {
  label: string
  value: string
  description: string
  icon: React.ReactNode
}) {
  return (
    <div className="rounded-2xl border border-border/70 bg-muted/20 p-5">
      <div className="flex items-center gap-2 text-sm font-medium text-slate-700">
        {icon}
        {label}
      </div>
      <p className="mt-3 text-2xl font-semibold tracking-tight text-slate-950">{value}</p>
      <p className="mt-2 text-sm leading-6 text-slate-600">{description}</p>
    </div>
  )
}

function InlineMeta({ label, value }: { label: string; value: string }) {
  return (
    <div className="min-w-[180px]">
      <p className="text-[11px] uppercase tracking-[0.18em] text-slate-400">{label}</p>
      <p className="mt-1 font-medium text-slate-900">{value}</p>
    </div>
  )
}

function draftFromActivity(activity: ActivityDetail | null): ActivityDraft {
  if (!activity) {
    return emptyDraft
  }

  return {
    name: activity.name,
    dateEnabled: Boolean(activity.date),
    dateValue: activity.date ? toDatetimeLocal(activity.date) : '',
    hasParticipantLimit: activity.max_volunteer_num !== null,
    maxVolunteerNum: activity.max_volunteer_num ?? 20,
    location: activity.location,
    briefDescription: activity.description.slice(0, 180),
    description: activity.description,
    duration: activity.duration,
  }
}

function toDatetimeLocal(value: string): string {
  const date = new Date(value)
  const year = date.getFullYear()
  const month = `${date.getMonth() + 1}`.padStart(2, '0')
  const day = `${date.getDate()}`.padStart(2, '0')
  const hours = `${date.getHours()}`.padStart(2, '0')
  const minutes = `${date.getMinutes()}`.padStart(2, '0')
  return `${year}-${month}-${day}T${hours}:${minutes}`
}

function deriveMetrics(
  activities: ActivitySummary[],
): readonly (readonly [string, string, string])[] {
  const recruiting = activities.filter((activity) => activity.state === 'need_volunteer').length
  const inProgress = activities.filter((activity) => activity.state === 'going').length
  const completed = activities.filter((activity) => activity.state === 'ended').length

  return [
    ['Activities', activities.length.toString(), 'Published opportunities in the current dataset.'],
    ['Recruiting', recruiting.toString(), 'Activities still open for volunteer sign-up.'],
    ['Completed', completed.toString(), `${inProgress} currently in progress.`],
  ] as const
}

async function invalidateSelectedActivity(queryClient: QueryClient, activityId: string | null) {
  await queryClient.invalidateQueries({ queryKey: ['activities'] })
  if (activityId) {
    await queryClient.invalidateQueries({ queryKey: ['activity-detail', activityId] })
    await queryClient.invalidateQueries({ queryKey: ['activity-records', activityId] })
    await queryClient.invalidateQueries({ queryKey: ['channels', activityId] })
  }
}

function showMutationError(error: unknown) {
  const message = error instanceof ApiError ? error.message : 'Request failed.'
  toast.error(message)
}

function initials(user: UserProfile | null): string {
  if (!user) {
    return 'AD'
  }
  const parts = user.realname.split(' ').filter(Boolean)
  return parts.map((part) => part[0]).slice(0, 2).join('').toUpperCase()
}

export default App
