import { useMemo } from 'react'
import { Search } from 'lucide-react'

import { ChannelPanel } from '@/components/channel-panel'
import { Badge } from '@/components/ui/badge'
import { Input } from '@/components/ui/input'
import { ScrollArea } from '@/components/ui/scroll-area'
import {
  activityStateLabel,
  formatDateOnly,
  formatDateTime,
  formatDuration,
} from '@/lib/format'
import {
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
    <div className="grid h-full min-h-0 gap-3 xl:grid-cols-[280px_minmax(0,1fr)] xl:items-stretch">
      <div className="flex min-h-0 flex-col rounded-xl border bg-white">
        <div className="shrink-0 border-b p-3">
          <div className="relative">
            <Search className="pointer-events-none absolute left-2.5 top-1/2 size-3.5 -translate-y-1/2 text-muted-foreground" />
            <Input
              className="h-8 pl-8 text-sm"
              placeholder="Search rooms"
              value={search}
              onChange={(event) => onSearchChange(event.target.value)}
            />
          </div>
        </div>

        <ScrollArea className="min-h-0 flex-1 p-2">
          <div className="space-y-4">
            {groupedActivities.length > 0 ? (
              groupedActivities.map((group) => (
                <div key={group.key}>
                  <p className="mb-1.5 px-2 text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">
                    {group.title}
                  </p>
                  <div className="grid gap-1">
                    {group.items.map((activity) => {
                      const active = activity.id === selectedActivityId
                      return (
                        <button
                          key={activity.id}
                          type="button"
                          onClick={() => onSelectActivity(activity.id)}
                          className={`rounded-lg px-3 py-2.5 text-left transition ${
                            active ? 'bg-accent' : 'hover:bg-muted/50'
                          }`}
                        >
                          <div className="flex items-start justify-between gap-2">
                            <p className="text-sm font-medium text-slate-950 line-clamp-1">{activity.name}</p>
                            <Badge variant="secondary" className="shrink-0 text-[10px]">
                              {activityStateLabel(activity.state)}
                            </Badge>
                          </div>
                          <p className="mt-0.5 text-xs text-muted-foreground">
                            {formatDateOnly(activity.date)} · {activity.location}
                          </p>
                        </button>
                      )
                    })}
                  </div>
                </div>
              ))
            ) : (
              <p className="px-3 py-6 text-center text-sm text-muted-foreground">No rooms.</p>
            )}
          </div>
        </ScrollArea>
      </div>

      {selectedActivity ? (
          <div className="grid min-h-0 grid-rows-[auto_minmax(0,1fr)] gap-3">
            <div className="shrink-0 rounded-xl border bg-white px-4 py-3">
              <div className="flex items-center gap-2">
                <h3 className="text-base font-semibold text-slate-950 truncate">{selectedActivity.name}</h3>
                <Badge variant="secondary">{activityStateLabel(selectedActivity.state)}</Badge>
              </div>
              <p className="mt-1 text-xs text-muted-foreground">
                {formatDateTime(selectedActivity.date)} · {selectedActivity.location} · {selectedActivity.volunteer_num}/{selectedActivity.max_volunteer_num ?? '∞'} volunteers · {formatDuration(selectedActivity.duration)}
              </p>
            </div>

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
        <div className="flex min-h-[520px] flex-col gap-3 rounded-xl border bg-white p-4">
          <div className="h-16 animate-pulse rounded-lg bg-muted" />
          <div className="min-h-0 flex-1 animate-pulse rounded-lg bg-muted" />
        </div>
      ) : (
        <div className="flex min-h-[520px] items-center justify-center rounded-xl border bg-white text-center text-muted-foreground">
          <p className="text-sm">Select a room to start chatting.</p>
        </div>
      )}
    </div>
  )
}

