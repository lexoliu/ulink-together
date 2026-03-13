import { BellRing, FolderKanban, Lock, MessageSquareMore, Send } from 'lucide-react'

import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { activityStateLabel, formatDateTime } from '@/lib/format'
import { activityChannelIsReadOnly, type ActivityState, type ChannelMessage, type ChannelResponse } from '@/lib/types'

interface ChannelStatusCardProps {
  activityName: string
  activityState: ActivityState
  channel: ChannelResponse | null
  messages: ChannelMessage[]
  onOpenChat: () => void
}

export function ChannelStatusCard({
  activityName,
  activityState,
  channel,
  messages,
  onOpenChat,
}: ChannelStatusCardProps) {
  const readOnly = activityChannelIsReadOnly(activityState)
  const lastMessage = messages
    .slice()
    .sort((left, right) => left.datetime.localeCompare(right.datetime))
    .at(-1)

  return (
    <Card className="border-white/70 bg-white/92 shadow-lg shadow-slate-200/40">
      <CardHeader className="gap-4 lg:flex-row lg:items-start lg:justify-between">
        <div>
          <CardDescription>Coordination</CardDescription>
          <CardTitle className="mt-1 text-2xl font-semibold tracking-tight text-slate-950">
            {activityName}
          </CardTitle>
        </div>

        <Button onClick={onOpenChat}>
          <MessageSquareMore className="mr-2 size-4" />
          Open dedicated chat
        </Button>
      </CardHeader>

      <CardContent className="grid gap-4 lg:grid-cols-[1.2fr_0.8fr]">
        <div className="grid gap-4 md:grid-cols-3">
          <StatusTile
            icon={<FolderKanban className="size-4" />}
            label="Room"
            value={channel?.name ?? 'Pending'}
            description={channel ? `${channel.members.length} people in this room.` : 'The activity room has not been prepared yet.'}
          />
          <StatusTile
            icon={readOnly ? <Lock className="size-4" /> : <Send className="size-4" />}
            label="Posting"
            value={readOnly ? 'Read only' : 'Open'}
            description={`${activityStateLabel(activityState)} activities ${readOnly ? 'archive chat automatically.' : 'stay live for quick coordination.'}`}
          />
          <StatusTile
            icon={<BellRing className="size-4" />}
            label="Traffic"
            value={`${messages.length}`}
            description={messages.length > 0 ? 'Messages already in the room.' : 'No activity updates have been posted yet.'}
          />
        </div>

        <div className="rounded-[1.6rem] border border-slate-200/80 bg-slate-50/85 p-5">
          <p className="text-xs font-semibold uppercase tracking-[0.2em] text-slate-400">Latest note</p>
          {lastMessage ? (
            <div className="mt-3 space-y-3">
              <p className="line-clamp-4 text-sm leading-7 text-slate-700">{lastMessage.content}</p>
              <p className="text-xs text-slate-500">{formatDateTime(lastMessage.datetime)}</p>
            </div>
          ) : (
            <p className="mt-3 text-sm leading-7 text-slate-500">
              Move into the dedicated chat workspace when the team is ready to coordinate.
            </p>
          )}
        </div>
      </CardContent>
    </Card>
  )
}

function StatusTile({
  icon,
  label,
  value,
  description,
}: {
  icon: React.ReactNode
  label: string
  value: string
  description: string
}) {
  return (
    <div className="rounded-[1.5rem] border border-slate-200/80 bg-slate-50/85 p-4">
      <div className="flex items-center gap-2 text-sm font-medium text-slate-700">
        {icon}
        {label}
      </div>
      <p className="mt-3 text-2xl font-semibold tracking-tight text-slate-950">{value}</p>
      <p className="mt-2 text-sm leading-6 text-slate-600">{description}</p>
    </div>
  )
}
