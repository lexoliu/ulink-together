import { useMemo } from 'react'
import {
  Clock3,
  Lock,
  MapPin,
  Search,
  Users,
} from 'lucide-react'

import { ChannelPanel } from '@/components/channel-panel'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
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
  selectedActivityPending: boolean
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
  selectedActivityPending,
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
        title: 'Current',
        items: activities.filter((activity) => activity.state === 'going'),
      },
      {
        key: 'need_volunteer',
        title: 'Upcoming',
        items: activities.filter((activity) => activity.state === 'need_volunteer'),
      },
      {
        key: 'ended',
        title: 'Archived',
        items: activities.filter((activity) => activity.state === 'ended'),
      },
    ].filter((group) => group.items.length > 0),
    [activities],
  )

  return (
    <div className="grid h-full min-h-0 gap-4 xl:grid-cols-[300px_minmax(0,1fr)] xl:items-stretch">
      <Card className="flex min-h-0 flex-col border-white/70 bg-white/90 shadow-lg shadow-slate-200/40">
        <CardHeader className="gap-4">
          <div>
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

        <CardContent className="min-h-0 flex-1 pb-3">
          <ScrollArea className="h-full pr-3">
            <div className="space-y-5 pb-5">
              {groupedActivities.length > 0 ? (
                groupedActivities.map((group) => (
                  <div key={group.key}>
                    <div className="mb-3 px-1">
                      <p className="text-xs font-semibold uppercase tracking-[0.22em] text-slate-400">
                        {group.title}
                      </p>
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
                            <div className="min-w-0">
                              <div className="flex min-w-0 items-start gap-3">
                                <p className="min-w-0 flex-1 text-sm font-medium leading-6 text-slate-950">
                                  {activity.name}
                                </p>
                                <Badge variant="secondary" className="shrink-0">
                                  {activityStateLabel(activity.state)}
                                </Badge>
                              </div>
                              <p className="mt-1 truncate text-sm text-slate-500">
                                {formatDateOnly(activity.date)} · {activity.location}
                              </p>
                            </div>
                          </button>
                        )
                      })}
                    </div>
                  </div>
                ))
              ) : (
                <div className="rounded-[1.5rem] border border-dashed border-slate-200 bg-slate-50/70 p-6 text-sm text-slate-500">
                  No rooms.
                </div>
              )}
            </div>
          </ScrollArea>
        </CardContent>
      </Card>

      {selectedActivity ? (
          <div className="grid min-h-0 grid-rows-[auto_minmax(0,1fr)] gap-4">
            <Card className="shrink-0 border-white/70 bg-white/94 shadow-lg shadow-slate-200/40">
              <CardHeader className="gap-5">
                <div className="flex flex-col gap-5 xl:flex-row xl:items-start xl:justify-between">
                  <div className="space-y-4">
                    <div className="flex flex-wrap items-center gap-2">
                      <Badge variant="secondary">{activityStateLabel(selectedActivity.state)}</Badge>
                      <Badge variant="outline">{formatDuration(selectedActivity.duration)}</Badge>
                      <Badge variant="outline">
                        {selectedActivity.volunteer_num}/{selectedActivity.max_volunteer_num ?? '∞'} volunteers
                      </Badge>
                    </div>

                    <CardTitle className="text-3xl font-semibold tracking-tight text-slate-950">
                      {selectedActivity.name}
                    </CardTitle>

                    <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-4">
                      <SummaryChip icon={<Clock3 className="size-4" />} label="When" value={formatDateTime(selectedActivity.date)} />
                      <SummaryChip icon={<MapPin className="size-4" />} label="Where" value={selectedActivity.location} />
                      <SummaryChip
                        icon={<Users className="size-4" />}
                        label="People"
                        value={`${selectedActivity.volunteer_num}/${selectedActivity.max_volunteer_num ?? '∞'} volunteers`}
                      />
                      <SummaryChip
                        icon={<Lock className="size-4" />}
                        label="Status"
                        value={activityChannelIsReadOnly(selectedActivity.state) ? 'Archived' : 'Available'}
                      />
                    </div>
                  </div>

                  <Button variant="outline" className="rounded-2xl" onClick={onOpenActivities}>
                    Open activity
                  </Button>
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
              isSendingMessage={isSendingMessage}
              onSendMessage={onSendMessage}
            />
          </div>
      ) : selectedActivityPending ? (
        <Card className="border-white/70 bg-white/92 shadow-lg shadow-slate-200/40">
          <CardContent className="flex min-h-[520px] flex-col gap-4 p-6">
            <div className="h-28 animate-pulse rounded-[1.7rem] bg-slate-100" />
            <div className="min-h-0 flex-1 animate-pulse rounded-[1.7rem] bg-slate-100" />
          </CardContent>
        </Card>
      ) : (
        <Card className="border-white/70 bg-white/92 shadow-lg shadow-slate-200/40">
          <CardContent className="flex min-h-[520px] flex-col items-center justify-center gap-4 text-center">
            <div>
              <h2 className="text-xl font-semibold text-slate-950">Choose a room</h2>
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  )
}

function SummaryChip({
  icon,
  label,
  value,
}: {
  icon: React.ReactNode
  label: string
  value: string
}) {
  return (
    <div className="rounded-[1.35rem] border border-slate-200/80 bg-slate-50/80 p-4">
      <div className="flex items-center gap-2 text-sm font-medium text-slate-700">
        {icon}
        {label}
      </div>
      <p className="mt-3 text-sm leading-6 text-slate-950">{value}</p>
    </div>
  )
}
