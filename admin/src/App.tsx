import { Suspense, lazy, startTransition, useDeferredValue, useMemo, useState } from 'react'
import {
  ArrowRight,
  CheckCircle2,
  Clock3,
  Download,
  FileSpreadsheet,
  FolderKanban,
  House,
  ListFilter,
  LogOut,
  MessageSquareMore,
  PanelLeftClose,
  PanelLeftOpen,
  Plus,
  Search,
  Sparkles,
} from 'lucide-react'
import { useMutation, useQuery, useQueryClient, type QueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'

import './App.css'
import { ActivityRecordsTable } from '@/components/activity-records-table'
import { ChannelStatusCard } from '@/components/channel-status-card'
import { CommandPalette } from '@/components/command-palette'
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
import { useLocation, useNavigate, useSearchParams } from 'react-router-dom'
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
type AdminView = 'home' | 'activities' | 'chats'

const api = new AdminApiClient()
const ActivityFormDialog = lazy(async () =>
  import('@/components/activity-form-dialog').then((module) => ({
    default: module.ActivityFormDialog,
  })),
)
const ChatWorkspace = lazy(async () =>
  import('@/components/chat-workspace').then((module) => ({
    default: module.ChatWorkspace,
  })),
)
const ExportBatchDialog = lazy(async () =>
  import('@/components/export-batch-dialog').then((module) => ({
    default: module.ExportBatchDialog,
  })),
)
const HomeActivityChart = lazy(async () =>
  import('@/components/home-activity-chart').then((module) => ({
    default: module.HomeActivityChart,
  })),
)
const LoginScreen = lazy(async () =>
  import('@/components/login-screen').then((module) => ({
    default: module.LoginScreen,
  })),
)

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
  const location = useLocation()
  const navigate = useNavigate()
  const [searchParams] = useSearchParams()

  const [authEpoch, setAuthEpoch] = useState(0)
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [loginError, setLoginError] = useState<string | null>(null)
  const [search, setSearch] = useState('')
  const [chatSearch, setChatSearch] = useState('')
  const [scope, setScope] = useState<ActivityScope>('all')
  const [stateFilter, setStateFilter] = useState<ActivityFilter>('all')
  const [formOpen, setFormOpen] = useState(false)
  const [editingActivity, setEditingActivity] = useState<ActivityDetail | null>(null)
  const [exportBatch, setExportBatch] = useState<ExportBatchResponse | null>(null)
  const [recordActionId, setRecordActionId] = useState<string | null>(null)
  const [commandOpen, setCommandOpen] = useState(false)
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false)

  const deferredSearch = useDeferredValue(search)
  const deferredChatSearch = useDeferredValue(chatSearch)

  const currentView = viewFromPath(location.pathname)
  const selectedActivityId = searchParams.get('activity')
  const selectedChatActivityId = searchParams.get('chat')
  const panelTab = (searchParams.get('tab') as PanelTab | null) ?? 'overview'

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

      if (!deferredSearch.trim()) {
        return true
      }

      const query = deferredSearch.toLowerCase()
      return [activity.name, activity.location, activity.brief_description]
        .join(' ')
        .toLowerCase()
        .includes(query)
    })
  }, [activitiesQuery.data, currentUser?.id, deferredSearch, scope, stateFilter])

  const resolvedSelectedActivityId =
    selectedActivityId &&
    filteredActivities.some((activity) => activity.id === selectedActivityId)
      ? selectedActivityId
      : filteredActivities[0]?.id ?? null

  const chatActivities = useMemo(() => {
    return (activitiesQuery.data ?? [])
      .filter((activity) => activity.state !== 'canceled')
      .filter((activity) => {
        if (!deferredChatSearch.trim()) {
          return true
        }

        const query = deferredChatSearch.toLowerCase()
        return [activity.name, activity.location, activity.brief_description]
          .join(' ')
          .toLowerCase()
          .includes(query)
      })
  }, [activitiesQuery.data, deferredChatSearch])

  const resolvedSelectedChatActivityId =
    selectedChatActivityId &&
    chatActivities.some((activity) => activity.id === selectedChatActivityId)
      ? selectedChatActivityId
      : chatActivities[0]?.id ?? null

  const selectedDetailQuery = useQuery({
    queryKey: ['activity-detail', resolvedSelectedActivityId],
    queryFn: () => api.activity(resolvedSelectedActivityId!),
    enabled: Boolean(resolvedSelectedActivityId),
  })

  const selectedDetail = selectedDetailQuery.data ?? null

  const selectedChatDetailQuery = useQuery({
    queryKey: ['chat-activity-detail', resolvedSelectedChatActivityId],
    queryFn: () => api.activity(resolvedSelectedChatActivityId!),
    enabled: Boolean(resolvedSelectedChatActivityId),
  })

  const selectedChatDetail = selectedChatDetailQuery.data ?? null

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

  const chatChannelQuery = useQuery({
    queryKey: ['chat-channels', resolvedSelectedChatActivityId],
    queryFn: async () => {
      const channels = await api.channels(resolvedSelectedChatActivityId!)
      return channels[0] ?? null
    },
    enabled: Boolean(resolvedSelectedChatActivityId),
  })

  const messagesQuery = useQuery({
    queryKey: ['messages', channelQuery.data?.id],
    queryFn: () => api.messages(channelQuery.data!.id),
    enabled: Boolean(channelQuery.data?.id),
  })

  const chatMessagesQuery = useQuery({
    queryKey: ['chat-messages', chatChannelQuery.data?.id],
    queryFn: () => api.messages(chatChannelQuery.data!.id),
    enabled: Boolean(chatChannelQuery.data?.id),
  })

  const chatParticipantIds = useMemo(
    () =>
      Array.from(new Set((chatMessagesQuery.data ?? []).map((message) => message.sender))).filter(
        (userId) => userId !== currentUser?.id,
      ),
    [chatMessagesQuery.data, currentUser?.id],
  )

  const chatMessageNamesQuery = useQuery({
    queryKey: ['chat-message-names', chatParticipantIds],
    queryFn: async () => {
      const names = await Promise.all(
        chatParticipantIds.map(async (userId) => [userId, await api.userName(userId)] as const),
      )
      return Object.fromEntries(names)
    },
    enabled: chatParticipantIds.length > 0 && authorities.view_user === true,
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
      setAuthEpoch((value) => value + 1)
      navigateHome()
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
      navigateActivities(activity.id)
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
      navigateActivities(activity.id, panelTab)
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

  const sendMessageMutation = useMutation({
    mutationFn: async ({
      channelId,
      content,
    }: {
      channelId: string
      content: string
    }) => {
      return api.sendMessage(channelId, content)
    },
    onSuccess: async (_, variables) => {
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: ['messages', variables.channelId] }),
        queryClient.invalidateQueries({ queryKey: ['chat-messages', variables.channelId] }),
      ])
    },
    onError: showMutationError,
  })

  const participantNames = participantNamesQuery.data ?? {}
  const chatSenderNames = {
    ...(chatMessageNamesQuery.data ?? {}),
    ...(currentUser ? { [currentUser.id]: currentUser.realname } : {}),
  }

  const navigateHome = () => {
    startTransition(() => {
      navigate('/')
    })
  }

  const navigateActivities = (activityId?: string, tab?: PanelTab) => {
    const params = new URLSearchParams()
    if (activityId) {
      params.set('activity', activityId)
    }
    if (tab) {
      params.set('tab', tab)
    }
    startTransition(() => {
      navigate({
        pathname: '/activities',
        search: params.toString(),
      })
    })
  }

  const navigateChats = (activityId?: string) => {
    const params = new URLSearchParams()
    if (activityId) {
      params.set('chat', activityId)
    }
    startTransition(() => {
      navigate({
        pathname: '/chats',
        search: params.toString(),
      })
    })
  }

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
      <Suspense fallback={<FullscreenFallback />}>
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
      </Suspense>
    )
  }

  const canCreateActivity = authorities.create_activity === true
  const canGenerateExport = authorities.generate_export === true
  const canManageSelectedActivity =
    selectedDetail !== null &&
    (selectedDetail.promoter === currentUser?.id || authorities.manage_record_anyway === true)

  return (
    <>
      <div className="min-h-screen bg-[radial-gradient(circle_at_top_right,_rgba(148,163,184,0.1),_transparent_28%),radial-gradient(circle_at_bottom_left,_rgba(120,137,128,0.08),_transparent_32%),linear-gradient(to_bottom,_#f7f5f2,_#f1efe9)]">
        <div className="mx-auto flex min-h-screen max-w-[1600px] gap-6 px-6 py-6">
          <aside
            className={`hidden shrink-0 flex-col rounded-[2rem] border border-white/70 bg-white/88 shadow-xl shadow-slate-200/50 backdrop-blur transition-all duration-300 lg:flex ${
              sidebarCollapsed ? 'w-24 p-4' : 'w-72 p-6'
            }`}
          >
            <div className={`flex items-start justify-between gap-3 ${sidebarCollapsed ? 'mb-2' : 'mb-1'}`}>
              {sidebarCollapsed ? (
                <div className="flex size-11 items-center justify-center rounded-2xl bg-slate-950 text-white">
                  <Sparkles className="size-4" />
                </div>
              ) : (
                <div className="space-y-5">
                  <div className="inline-flex items-center gap-2 rounded-full bg-slate-950 px-3 py-1 text-xs font-medium uppercase tracking-[0.18em] text-white">
                    <Sparkles className="size-3.5" />
                    Admin workspace
                  </div>
                  <div>
                    <h1 className="text-2xl font-semibold tracking-tight text-slate-950">
                      Volunteer operations
                    </h1>
                  </div>
                </div>
              )}

              <Button
                variant="ghost"
                size="icon-sm"
                className="shrink-0 rounded-xl text-slate-500"
                onClick={() => setSidebarCollapsed((value) => !value)}
              >
                {sidebarCollapsed ? <PanelLeftOpen className="size-4" /> : <PanelLeftClose className="size-4" />}
                <span className="sr-only">{sidebarCollapsed ? 'Expand sidebar' : 'Collapse sidebar'}</span>
              </Button>
            </div>

            <Separator className="my-6" />

            <nav className="grid gap-2">
              <SidebarItem
                active={currentView === 'home'}
                icon={<House className="size-4" />}
                label="Home"
                collapsed={sidebarCollapsed}
                onClick={navigateHome}
              />
              <SidebarItem
                active={currentView === 'activities'}
                icon={<FolderKanban className="size-4" />}
                label="Activities"
                collapsed={sidebarCollapsed}
                onClick={() => navigateActivities(selectedActivityId ?? undefined, panelTab)}
              />
              <SidebarItem
                active={currentView === 'chats'}
                icon={<MessageSquareMore className="size-4" />}
                label="Chats"
                collapsed={sidebarCollapsed}
                onClick={() => navigateChats(selectedChatActivityId ?? undefined)}
              />
            </nav>

            <Button
              variant="outline"
              className={`mt-4 rounded-2xl border-slate-200 bg-slate-50/90 text-left text-slate-700 ${
                sidebarCollapsed ? 'justify-center px-0' : 'justify-between px-4 py-5'
              }`}
              onClick={() => setCommandOpen(true)}
              title="Quick switch"
            >
              <span className="flex items-center gap-2">
                <Search className="size-4" />
                {sidebarCollapsed ? null : 'Quick switch'}
              </span>
              {sidebarCollapsed ? null : (
                <span className="rounded-full border border-slate-200 bg-white px-2 py-1 text-[11px] font-medium text-slate-400">
                  ⌘K
                </span>
              )}
            </Button>

            <div className={`mt-auto rounded-2xl border border-slate-200/80 bg-slate-50/90 shadow-sm ${sidebarCollapsed ? 'px-3 py-3' : 'px-4 py-4'}`}>
              <div className={`flex ${sidebarCollapsed ? 'justify-center' : 'items-center gap-3'}`}>
                <div className="flex size-10 items-center justify-center rounded-full bg-slate-900 text-sm font-semibold text-white">
                  {initials(currentUser)}
                </div>
                {sidebarCollapsed ? null : (
                  <div className="min-w-0">
                    <p className="truncate font-medium text-slate-950">{currentUser?.realname}</p>
                    <p className="truncate text-sm text-slate-500">{currentUser?.email}</p>
                  </div>
                )}
              </div>

              <Button
                variant="outline"
                className={`mt-4 ${sidebarCollapsed ? 'w-full justify-center px-0' : 'w-full justify-center'}`}
                disabled={logoutMutation.isPending}
                onClick={() => logoutMutation.mutate()}
                title="Sign out"
              >
                <LogOut className={`size-4 ${sidebarCollapsed ? '' : 'mr-2'}`} />
                {sidebarCollapsed ? null : 'Sign out'}
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
                  onClick={navigateHome}
                />
                <SidebarItem
                  active={currentView === 'activities'}
                  icon={<FolderKanban className="size-4" />}
                  label="Activities"
                  onClick={() => navigateActivities(selectedActivityId ?? undefined, panelTab)}
                />
                <SidebarItem
                  active={currentView === 'chats'}
                  icon={<MessageSquareMore className="size-4" />}
                  label="Chats"
                  onClick={() => navigateChats(selectedChatActivityId ?? undefined)}
                />
              </div>

              <Button
                variant="outline"
                className="mt-4 w-full justify-between rounded-2xl border-slate-200 bg-slate-50/90"
                onClick={() => setCommandOpen(true)}
              >
                <span className="flex items-center gap-2">
                  <Search className="size-4" />
                  Quick switch
                </span>
                <span className="text-xs text-slate-400">⌘K</span>
              </Button>
            </header>

            {currentView === 'home' ? (
              <HomePage
                user={currentUser}
                activities={activitiesQuery.data ?? []}
                recentActivities={recentActivities}
                canCreateActivity={canCreateActivity}
                onCreateActivity={() => {
                  setEditingActivity(null)
                  setFormOpen(true)
                }}
                onOpenActivity={(activityId) => {
                  navigateActivities(activityId)
                }}
              />
            ) : currentView === 'chats' ? (
              <Suspense fallback={<WorkspaceFallback />}>
                <ChatWorkspace
                  activities={chatActivities}
                  selectedActivityId={resolvedSelectedChatActivityId}
                  selectedActivity={selectedChatDetail}
                  channel={chatChannelQuery.data ?? null}
                  messages={chatMessagesQuery.data ?? []}
                  senderNames={chatSenderNames}
                  currentUserId={currentUser?.id ?? null}
                  isSendingMessage={sendMessageMutation.isPending}
                  search={chatSearch}
                  onSearchChange={setChatSearch}
                  onSelectActivity={(activityId) => navigateChats(activityId)}
                  onOpenActivities={() => {
                    if (resolvedSelectedChatActivityId) {
                      navigateActivities(resolvedSelectedChatActivityId)
                    } else {
                      navigateActivities()
                    }
                  }}
                  onSendMessage={async (content) => {
                    if (!chatChannelQuery.data) {
                      throw new ApiError('No channel is available yet.', 400)
                    }
                    await sendMessageMutation.mutateAsync({
                      channelId: chatChannelQuery.data.id,
                      content,
                    })
                  }}
                  pushUrl={api.pushURL()}
                />
              </Suspense>
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
                panelTab={panelTab}
                channel={channelQuery.data ?? null}
                messages={messagesQuery.data ?? []}
                recordActionId={recordActionId}
                canCreateActivity={canCreateActivity}
                canGenerateExport={canGenerateExport}
                canManageSelectedActivity={canManageSelectedActivity}
                isExporting={exportMutation.isPending}
                onSearchChange={setSearch}
                onScopeChange={setScope}
                onStateFilterChange={setStateFilter}
                onSelectActivity={(activityId) => navigateActivities(activityId, panelTab)}
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
                onOpenChat={() => {
                  if (selectedDetail) {
                    navigateChats(selectedDetail.id)
                  }
                }}
                onGenerateExport={() => exportMutation.mutate()}
                onTransition={(action) => {
                  if (selectedDetail) {
                    activityActionMutation.mutate({ id: selectedDetail.id, action })
                  }
                }}
                onPanelTabChange={(value) => navigateActivities(selectedDetail?.id, value)}
                onRecordAction={(id, action) => recordActionMutation.mutate({ id, action })}
              />
            )}
          </main>
        </div>
      </div>

      <CommandPalette
        open={commandOpen}
        onOpenChange={setCommandOpen}
        activities={activitiesQuery.data ?? []}
        onOpenHome={navigateHome}
        onOpenActivity={(activityId) => navigateActivities(activityId)}
        onOpenChat={(activityId) => navigateChats(activityId)}
        onCreateActivity={
          canCreateActivity
            ? () => {
                setEditingActivity(null)
                setFormOpen(true)
              }
            : undefined
        }
      />

      <Suspense fallback={null}>
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
      </Suspense>
    </>
  )
}

function HomePage({
  user,
  activities,
  recentActivities,
  canCreateActivity,
  onCreateActivity,
  onOpenActivity,
}: {
  user: UserProfile | null
  activities: ActivitySummary[]
  recentActivities: ActivitySummary[]
  canCreateActivity: boolean
  onCreateActivity: () => void
  onOpenActivity: (activityId: string) => void
}) {
  const totalActivities = activities.length
  const recruitingCount = activities.filter((activity) => activity.state === 'need_volunteer').length
  const liveCount = activities.filter((activity) => activity.state === 'going').length
  const completedCount = activities.filter((activity) => activity.state === 'ended').length

  return (
    <div className="grid gap-6">
      <Card className="overflow-hidden border-white/70 bg-white/88 shadow-xl shadow-slate-200/45">
        <CardHeader className="gap-5 lg:flex-row lg:items-start lg:justify-between">
          <div>
            <CardDescription>Home</CardDescription>
            <CardTitle className="mt-1 text-3xl font-semibold tracking-tight text-slate-950">
              Welcome back, {user?.realname ?? 'admin'}
            </CardTitle>
          </div>

          <div className="flex flex-wrap gap-2">
            {canCreateActivity ? (
              <Button onClick={onCreateActivity}>
                <Plus className="mr-2 size-4" />
                New activity
              </Button>
            ) : null}
          </div>
        </CardHeader>
      </Card>

      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        <HomeStatCard label="Activities" value={totalActivities.toString()} />
        <HomeStatCard label="Recruiting" value={recruitingCount.toString()} />
        <HomeStatCard label="Live" value={liveCount.toString()} />
        <HomeStatCard label="Completed" value={completedCount.toString()} />
      </div>

      <div className="grid gap-6 xl:grid-cols-[0.9fr_1.1fr]">
        <Card className="border-white/70 bg-white/88 shadow-lg shadow-slate-200/40">
          <CardHeader>
            <CardTitle>Recent activities</CardTitle>
          </CardHeader>
          <CardContent className="grid gap-3">
            {recentActivities.length > 0 ? (
              recentActivities.map((activity) => (
                <button
                  key={activity.id}
                  type="button"
                  className="flex items-center justify-between rounded-2xl border border-border/70 bg-background px-4 py-4 text-left outline-none transition hover:border-slate-300 hover:bg-slate-50 focus-visible:ring-2 focus-visible:ring-slate-300/80 focus-visible:ring-offset-2"
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
                    <ArrowRight className="size-4 text-slate-400" />
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

        <Suspense fallback={<WorkspaceFallback />}>
          <HomeActivityChart activities={activities} />
        </Suspense>
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
  panelTab,
  channel,
  messages,
  recordActionId,
  canCreateActivity,
  canGenerateExport,
  canManageSelectedActivity,
  isExporting,
  onSearchChange,
  onScopeChange,
  onStateFilterChange,
  onSelectActivity,
  onCreateActivity,
  onEditActivity,
  onOpenChat,
  onGenerateExport,
  onTransition,
  onPanelTabChange,
  onRecordAction,
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
  panelTab: PanelTab
  channel: ChannelResponse | null
  messages: ChannelMessage[]
  recordActionId: string | null
  canCreateActivity: boolean
  canGenerateExport: boolean
  canManageSelectedActivity: boolean
  isExporting: boolean
  onSearchChange: (value: string) => void
  onScopeChange: (value: ActivityScope) => void
  onStateFilterChange: (value: ActivityFilter) => void
  onSelectActivity: (value: string) => void
  onCreateActivity: () => void
  onEditActivity: () => void
  onOpenChat: () => void
  onGenerateExport: () => void
  onTransition: (action: 'need_volunteer' | 'go' | 'end' | 'cancel') => void
  onPanelTabChange: (value: PanelTab) => void
  onRecordAction: (id: string, action: 'approve_apply' | 'done' | 'disapprove_apply') => void
}) {
  return (
    <>
      <div className="rounded-[2.3rem] border border-white/75 bg-white/76 px-7 py-6 shadow-[0_28px_80px_-34px_rgba(15,23,42,0.24)] backdrop-blur-xl">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <p className="text-[11px] font-semibold uppercase tracking-[0.24em] text-slate-400">Activities</p>
            <h2 className="mt-2 text-3xl font-semibold tracking-tight text-slate-950">
              Manage publishing, records, and readiness
            </h2>
          </div>
          {canCreateActivity ? (
            <Button className="rounded-2xl px-4" onClick={onCreateActivity}>
              <Plus className="mr-2 size-4" />
              New activity
            </Button>
          ) : null}
        </div>
      </div>

      <div className="rounded-[2.4rem] border border-white/70 bg-white/70 p-2 shadow-[0_34px_100px_-42px_rgba(15,23,42,0.3)] backdrop-blur-xl">
        <div className="grid gap-2 xl:grid-cols-[340px_minmax(0,1fr)]">
          <aside className="rounded-[2rem] bg-[linear-gradient(180deg,rgba(240,245,250,0.98),rgba(234,240,246,0.84))] p-5">
            <div>
              <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-slate-400">Activity rail</p>
              <h3 className="mt-2 text-lg font-semibold text-slate-950">Pick the event you want to work on.</h3>
            </div>

            <div className="mt-5 grid gap-3">
              <div className="relative">
                <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
                <Input
                  className="rounded-2xl border-slate-200/80 bg-white/90 pl-9"
                  placeholder="Search activity name or location"
                  value={search}
                  onChange={(event) => onSearchChange(event.target.value)}
                />
              </div>

              <div className="grid gap-3 sm:grid-cols-2">
                <Select value={scope} onValueChange={(value) => onScopeChange(value as ActivityScope)}>
                  <SelectTrigger className="w-full rounded-2xl border-slate-200/80 bg-white/90">
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
                  <SelectTrigger className="w-full rounded-2xl border-slate-200/80 bg-white/90">
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

            <div className="mt-5 rounded-[1.8rem] bg-white/72 p-2 ring-1 ring-white/80">
              <ScrollArea className="h-[calc(100vh-22rem)] pr-2">
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
                      className={`rounded-[1.6rem] border px-4 py-4 text-left outline-none transition focus-visible:ring-2 focus-visible:ring-slate-300/80 focus-visible:ring-offset-2 ${
                        activity.id === selectedActivityId
                          ? 'border-white bg-white shadow-[0_18px_40px_-26px_rgba(15,23,42,0.28)] ring-1 ring-slate-200/90'
                          : 'border-transparent bg-transparent hover:bg-white/85'
                      }`}
                    >
                      <div className="flex items-start justify-between gap-3">
                        <div>
                          <h3 className="text-[15px] font-semibold leading-6 text-slate-950">{activity.name}</h3>
                          <p className="mt-1 line-clamp-2 text-sm leading-6 text-slate-500">
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
                  <div className="rounded-[1.5rem] border border-dashed border-slate-200 bg-white/80 p-6 text-sm text-slate-500">
                    No activities match the current filters.
                  </div>
                )}
              </div>
              </ScrollArea>
            </div>
          </aside>

        <div className="rounded-[2rem] bg-white px-6 py-6 shadow-[inset_0_1px_0_rgba(255,255,255,0.75)]">
          <div className="grid gap-6">
          {selectedDetail ? (
            <>
              <Card className="overflow-hidden border-slate-200/70 bg-[linear-gradient(180deg,rgba(255,255,255,1),rgba(248,251,255,0.96))] shadow-none">
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
                        <CardDescription className="mt-3 max-w-3xl text-sm leading-7">{selectedDetail.description}</CardDescription>
                      </div>

                      <div className="flex flex-wrap gap-x-8 gap-y-4 text-sm">
                        <InlineMeta label="Organiser" value={selectedDetail.promoter_name} />
                        <InlineMeta label="Date" value={formatDateTime(selectedDetail.date)} />
                        <InlineMeta label="Location" value={selectedDetail.location} />
                      </div>
                    </div>

                    <div className="flex flex-wrap gap-2">
                      {canManageSelectedActivity ? (
                        <Button variant="outline" onClick={onEditActivity}>
                          Edit
                        </Button>
                      ) : null}

                      <Button variant="outline" onClick={onOpenChat}>
                        <MessageSquareMore className="mr-2 size-4" />
                        Open chat
                      </Button>

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
                <TabsList variant="line" className="rounded-2xl bg-slate-50 p-1.5 shadow-none">
                  <TabsTrigger value="overview">Overview</TabsTrigger>
                  <TabsTrigger value="records">Records</TabsTrigger>
                  <TabsTrigger value="channel">Coordination</TabsTrigger>
                </TabsList>

                <TabsContent value="overview">
                  <Card className="border-slate-200/70 bg-slate-50/65 shadow-none">
                    <CardHeader>
                      <CardTitle>Activity snapshot</CardTitle>
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
                  <ChannelStatusCard
                    activityName={selectedDetail.name}
                    channel={channel}
                    activityState={selectedDetail.state}
                    messages={messages}
                    onOpenChat={onOpenChat}
                  />
                </TabsContent>
              </Tabs>
            </>
          ) : (
            <Card className="border-slate-200/70 bg-slate-50/65 shadow-none">
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
      </div>
      </div>
    </>
  )
}

function SidebarItem({
  active,
  icon,
  label,
  collapsed = false,
  onClick,
}: {
  active: boolean
  icon: React.ReactNode
  label: string
  collapsed?: boolean
  onClick: () => void
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      title={label}
      className={`flex items-center rounded-2xl px-4 py-3 text-left text-sm font-medium outline-none transition focus-visible:ring-2 focus-visible:ring-slate-300/80 ${
        active
          ? 'bg-slate-950 text-white shadow-sm'
          : 'bg-transparent text-slate-600 hover:bg-slate-100 hover:text-slate-950'
      } ${collapsed ? 'justify-center' : 'gap-3'}`}
    >
      {icon}
      {collapsed ? null : <span>{label}</span>}
    </button>
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

function HomeStatCard({
  label,
  value,
}: {
  label: string
  value: string
}) {
  return (
    <div className="rounded-[1.7rem] border border-white/70 bg-white/88 px-5 py-5 shadow-lg shadow-slate-200/35">
      <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-slate-400">{label}</p>
      <p className="mt-3 text-3xl font-semibold tracking-tight text-slate-950">{value}</p>
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

function FullscreenFallback() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-slate-50">
      <div className="grid w-full max-w-sm gap-3">
        <Skeleton className="h-8 w-40" />
        <Skeleton className="h-32 w-full rounded-2xl" />
      </div>
    </div>
  )
}

function WorkspaceFallback() {
  return (
    <div className="grid gap-6 xl:grid-cols-[320px_minmax(0,1fr)]">
      <Skeleton className="h-[70vh] rounded-[2rem]" />
      <Skeleton className="h-[70vh] rounded-[2rem]" />
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

function viewFromPath(pathname: string): AdminView {
  if (pathname.startsWith('/activities')) {
    return 'activities'
  }
  if (pathname.startsWith('/chats')) {
    return 'chats'
  }
  return 'home'
}

export default App
