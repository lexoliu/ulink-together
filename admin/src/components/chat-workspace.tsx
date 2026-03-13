import { useMemo } from 'react'
import {
  BellRing,
  Clock3,
  FolderKanban,
  Lock,
  MapPin,
  MessageSquareMore,
  Search,
  Users,
} from 'lucide-react'

import { ChannelPanel } from '@/components/channel-panel'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { ScrollArea } from '@/components/ui/scroll-area'
import {
  activityStateLabel,
  formatDateOnly,
  formatDateTime,
  formatDuration,
} from '@/lib/format'
import {
  activityChannelIsReadOnly,
  type ActivityDetail,
  type ActivitySummary,
  type ChannelMessage,
  type ChannelResponse,
} from '@/lib/types'

interface ChatWorkspaceProps {
  activities: ActivitySummary[]
  selectedActivityId: string | null
  selectedActivity: ActivityDetail | null
  channel: ChannelResponse | null
  messages: ChannelMessage[]
  senderNames: Record<string, string>
  currentUserId: string | null
  isSendingMessage: boolean
  search: string
  onSearchChange: (value: string) => void
  onSelectActivity: (activityId: string) => void
  onOpenActivities: () => void
  onSendMessage: (content: string) => Promise<void>
  pushUrl: string
}

export function ChatWorkspace({
  activities,
  selectedActivityId,
  selectedActivity,
  channel,
  messages,
  senderNames,
  currentUserId,
  isSendingMessage,
  search,
  onSearchChange,
  onSelectActivity,
  onOpenActivities,
  onSendMessage,
  pushUrl,
}: ChatWorkspaceProps) {
  const groupedActivities = useMemo(
    () => [
      {
        key: 'going',
        title: 'Live now',
        description: 'Activities currently underway.',
        items: activities.filter((activity) => activity.state === 'going'),
      },
      {
        key: 'need_volunteer',
        title: 'Recruiting',
        description: 'Upcoming rooms you may want to monitor.',
        items: activities.filter((activity) => activity.state === 'need_volunteer'),
      },
      {
        key: 'ended',
        title: 'Archived',
        description: 'Read-only conversations after wrap-up.',
        items: activities.filter((activity) => activity.state === 'ended'),
      },
    ].filter((group) => group.items.length > 0),
    [activities],
  )

  return (
    <div className="grid gap-6 xl:grid-cols-[320px_minmax(0,1fr)_280px]">
      <Card className="border-white/70 bg-white/90 shadow-lg shadow-slate-200/40">
        <CardHeader className="gap-4">
          <div>
            <CardDescription>Chats</CardDescription>
            <CardTitle className="text-2xl font-semibold tracking-tight text-slate-950">
              Activity rooms
            </CardTitle>
          </div>

          <div className="relative">
            <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-slate-400" />
            <Input
              className="rounded-2xl border-slate-200 bg-slate-50 pl-9"
              placeholder="Find an activity room"
              value={search}
              onChange={(event) => onSearchChange(event.target.value)}
            />
          </div>
        </CardHeader>

        <CardContent className="pb-0">
          <ScrollArea className="h-[calc(100vh-18rem)] pr-3">
            <div className="space-y-5 pb-5">
              {groupedActivities.length > 0 ? (
                groupedActivities.map((group) => (
                  <div key={group.key}>
                    <div className="mb-3 px-1">
                      <p className="text-xs font-semibold uppercase tracking-[0.22em] text-slate-400">
                        {group.title}
                      </p>
                      <p className="mt-1 text-xs text-slate-500">{group.description}</p>
                    </div>

                    <div className="grid gap-2">
                      {group.items.map((activity) => {
                        const active = activity.id === selectedActivityId

                        return (
                          <button
                            key={activity.id}
                            type="button"
                            onClick={() => onSelectActivity(activity.id)}
                            className={`rounded-[1.4rem] border px-4 py-4 text-left outline-none transition focus-visible:ring-2 focus-visible:ring-slate-300/80 focus-visible:ring-offset-2 ${
                              active
                                ? 'border-white bg-white shadow-[0_18px_40px_-28px_rgba(15,23,42,0.28)] ring-1 ring-slate-200/90'
                                : 'border-slate-200/80 bg-slate-50/70 hover:border-slate-300 hover:bg-white'
                            }`}
                          >
                            <div className="flex items-start justify-between gap-3">
                              <div className="min-w-0">
                                <p className="truncate font-medium text-slate-950">{activity.name}</p>
                                <p className="mt-1 truncate text-sm text-slate-500">
                                  {formatDateOnly(activity.date)} · {activity.location}
                                </p>
                              </div>
                              <Badge variant="secondary">{activityStateLabel(activity.state)}</Badge>
                            </div>
                          </button>
                        )
                      })}
                    </div>
                  </div>
                ))
              ) : (
                <div className="rounded-[1.5rem] border border-dashed border-slate-200 bg-slate-50/70 p-6 text-sm text-slate-500">
                  No rooms match the current search.
                </div>
              )}
            </div>
          </ScrollArea>
        </CardContent>
      </Card>

      {selectedActivity ? (
        <>
          <div className="grid gap-4">
            <Card className="border-white/70 bg-white/94 shadow-lg shadow-slate-200/40">
              <CardHeader className="gap-5">
                <div className="flex flex-wrap items-center gap-2">
                  <Badge variant="secondary">{activityStateLabel(selectedActivity.state)}</Badge>
                  <Badge variant="outline">{formatDuration(selectedActivity.duration)}</Badge>
                  <Badge variant="outline">
                    {selectedActivity.volunteer_num}/{selectedActivity.max_volunteer_num ?? '∞'} joined
                  </Badge>
                </div>

                <div>
                  <CardDescription>Conversation workspace</CardDescription>
                  <CardTitle className="mt-1 text-3xl font-semibold tracking-tight text-slate-950">
                    {selectedActivity.name}
                  </CardTitle>
                </div>
              </CardHeader>
            </Card>

            <ChannelPanel
              pushUrl={pushUrl}
              channel={channel}
              activityState={selectedActivity.state}
              initialMessages={messages}
              senderNames={senderNames}
              currentUserId={currentUserId}
              ownerId={selectedActivity.promoter}
              ownerLabel={selectedActivity.promoter_name}
              isSendingMessage={isSendingMessage}
              onSendMessage={onSendMessage}
            />
          </div>

          <div className="grid gap-4">
            <Card className="border-white/70 bg-white/92 shadow-lg shadow-slate-200/40">
              <CardHeader>
                <CardTitle>Room details</CardTitle>
              </CardHeader>
              <CardContent className="grid gap-4">
                <RailItem
                  icon={<Clock3 className="size-4" />}
                  label="When"
                  value={formatDateTime(selectedActivity.date)}
                />
                <RailItem
                  icon={<MapPin className="size-4" />}
                  label="Where"
                  value={selectedActivity.location}
                />
                <RailItem
                  icon={<Users className="size-4" />}
                  label="People"
                  value={`${selectedActivity.volunteer_num}/${selectedActivity.max_volunteer_num ?? '∞'} volunteers`}
                />
                <RailItem
                  icon={activityChannelIsReadOnly(selectedActivity.state) ? <Lock className="size-4" /> : <BellRing className="size-4" />}
                  label="Status"
                  value={
                    activityChannelIsReadOnly(selectedActivity.state)
                      ? 'Read only archive'
                      : 'Open for live coordination'
                  }
                />
              </CardContent>
            </Card>

            <Card className="border-white/70 bg-white/92 shadow-lg shadow-slate-200/40">
              <CardHeader>
                <CardTitle>Next step</CardTitle>
              </CardHeader>
              <CardContent>
                <Button variant="outline" className="w-full justify-between rounded-2xl" onClick={onOpenActivities}>
                  <span className="flex items-center gap-2">
                    <FolderKanban className="size-4" />
                    Open activity details
                  </span>
                  <MessageSquareMore className="size-4 text-slate-400" />
                </Button>
              </CardContent>
            </Card>
          </div>
        </>
      ) : (
        <Card className="border-white/70 bg-white/92 shadow-lg shadow-slate-200/40 xl:col-span-2">
          <CardContent className="flex min-h-[520px] flex-col items-center justify-center gap-4 text-center">
            <MessageSquareMore className="size-10 text-slate-400" />
            <div>
              <h2 className="text-xl font-semibold text-slate-950">Choose a room</h2>
              <p className="mt-2 max-w-md text-sm leading-7 text-slate-600">
                Select an activity from the rail to open its chat workspace.
              </p>
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  )
}

function RailItem({
  icon,
  label,
  value,
}: {
  icon: React.ReactNode
  label: string
  value: string
}) {
  return (
    <div className="rounded-[1.4rem] border border-slate-200/80 bg-slate-50/80 p-4">
      <div className="flex items-center gap-2 text-sm font-medium text-slate-700">
        {icon}
        {label}
      </div>
      <p className="mt-3 text-sm leading-7 text-slate-950">{value}</p>
    </div>
  )
}
