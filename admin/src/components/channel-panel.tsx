import { useEffect, useMemo, useRef, useState } from 'react'
import { Lock, MessagesSquare, Send, Users } from 'lucide-react'
import TextareaAutosize from 'react-textarea-autosize'

import { Button } from '@/components/ui/button'
import { ScrollArea } from '@/components/ui/scroll-area'
import { formatDateOnly, formatDateTime } from '@/lib/format'
import {
  activityChannelIsReadOnly,
  type ActivityState,
  type ChannelMessage,
  type ChannelResponse,
} from '@/lib/types'

interface ChannelPanelProps {
  pushUrl: string
  channel: ChannelResponse | null
  activityState: ActivityState
  initialMessages: ChannelMessage[]
  senderNames: Record<string, string>
  currentUserId: string | null
  ownerId?: string | null
  isSendingMessage: boolean
  onSendMessage: (content: string) => Promise<void>
}

interface MessageGroup {
  senderID: string
  isCurrentUser: boolean
  isOwner: boolean
  senderLabel: string
  dayLabel: string
  firstTimestamp: string
  messages: ChannelMessage[]
}

interface TimelineEntry {
  type: 'day' | 'group'
  key: string
  dayLabel?: string
  group?: MessageGroup
}

export function ChannelPanel({
  pushUrl,
  channel,
  activityState,
  initialMessages,
  senderNames,
  currentUserId,
  ownerId,
  isSendingMessage,
  onSendMessage,
}: ChannelPanelProps) {
  const [composer, setComposer] = useState('')
  const [messages, setMessages] = useState<ChannelMessage[]>(initialMessages)
  const endRef = useRef<HTMLDivElement | null>(null)
  const readOnly = activityChannelIsReadOnly(activityState)

  useEffect(() => {
    setMessages(initialMessages)
  }, [initialMessages])

  useEffect(() => {
    if (!channel) {
      return
    }

    const source = new EventSource(pushUrl, { withCredentials: true })
    source.addEventListener('message', (event) => {
      const next = JSON.parse((event as MessageEvent).data) as ChannelMessage
      if (next.channel !== channel.id) {
        return
      }
      setMessages((current) => {
        if (current.some((message) => message.id === next.id)) {
          return current
        }
        return [...current, next]
      })
    })

    source.onerror = () => {
      source.close()
    }

    return () => {
      source.close()
    }
  }, [channel, pushUrl])

  const orderedMessages = useMemo(
    () => [...messages].sort((left, right) => left.datetime.localeCompare(right.datetime)),
    [messages],
  )

  const timeline = useMemo(
    () => buildTimeline(orderedMessages, currentUserId, senderNames, ownerId ?? null),
    [orderedMessages, currentUserId, senderNames, ownerId],
  )

  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: 'smooth', block: 'end' })
  }, [timeline.length])

  return (
    <div className="flex min-h-0 flex-1 flex-col overflow-hidden rounded-xl border border-slate-200 bg-white">
      <header className="shrink-0 flex items-center justify-between border-b border-slate-200 px-5 py-3">
        <div className="flex items-center gap-2">
          <span className="text-slate-400">#</span>
          <span className="text-base font-semibold text-slate-950">
            {channel?.name ?? 'Channel'}
          </span>
        </div>
        <div className="flex items-center gap-3 text-xs text-slate-500">
          <span className="inline-flex items-center gap-1">
            <Users className="size-3.5" />
            {channel?.members.length ?? 0}
          </span>
          {readOnly ? (
            <span className="inline-flex items-center gap-1 rounded-full bg-amber-50 px-2 py-0.5 text-amber-700">
              <Lock className="size-3" /> Archived
            </span>
          ) : null}
        </div>
      </header>

      <div className="flex min-h-0 flex-1 flex-col">
        {channel ? (
          <>
            {timeline.length > 0 ? (
              <ScrollArea className="min-h-0 flex-1">
                <div className="flex flex-col gap-1 px-5 py-4">
                  {timeline.map((entry) =>
                    entry.type === 'day' ? (
                      <div
                        key={entry.key}
                        className="my-3 flex items-center gap-3 text-[11px] font-semibold uppercase tracking-wider text-slate-400"
                      >
                        <div className="h-px flex-1 bg-slate-200" />
                        <span>{entry.dayLabel}</span>
                        <div className="h-px flex-1 bg-slate-200" />
                      </div>
                    ) : (
                      <MessageGroupRow key={entry.key} group={entry.group!} />
                    ),
                  )}
                  <div ref={endRef} />
                </div>
              </ScrollArea>
            ) : (
              <div className="flex min-h-0 flex-1 items-center justify-center px-6 py-10">
                <div className="flex flex-col items-center gap-3 text-center text-sm text-slate-500">
                  <MessagesSquare className="size-8" />
                  <p className="text-slate-700">No messages yet</p>
                </div>
              </div>
            )}

            <form
              className="shrink-0 border-t border-slate-200 px-4 py-3"
              onSubmit={async (event) => {
                event.preventDefault()
                if (readOnly) {
                  return
                }
                const content = composer.trim()
                if (!content) {
                  return
                }
                await onSendMessage(content)
                setComposer('')
              }}
            >
              <div className="flex items-end gap-2 rounded-lg border border-slate-200 bg-slate-50 px-3 py-2">
                <TextareaAutosize
                  minRows={1}
                  maxRows={5}
                  value={composer}
                  onChange={(event) => setComposer(event.target.value)}
                  placeholder={readOnly ? 'Archived' : `Message #${channel.name}`}
                  disabled={readOnly}
                  className="flex-1 resize-none border-0 bg-transparent py-1 text-sm leading-6 text-slate-950 outline-none placeholder:text-slate-400 disabled:cursor-not-allowed"
                />
                <Button
                  type="submit"
                  size="sm"
                  disabled={readOnly || isSendingMessage || !composer.trim()}
                >
                  <Send className="size-4" />
                </Button>
              </div>
            </form>
          </>
        ) : (
          <div className="px-5 py-6 text-sm text-slate-500">
            This activity channel is not available yet.
          </div>
        )}
      </div>
    </div>
  )
}

function MessageGroupRow({ group }: { group: MessageGroup }) {
  const avatarColor = avatarColorFor(group.senderLabel)
  return (
    <div className="flex items-start gap-3 py-1">
      <div
        className="flex size-9 shrink-0 items-center justify-center rounded-full text-xs font-semibold text-white"
        style={{ backgroundColor: avatarColor }}
      >
        {initialOf(group.senderLabel)}
      </div>
      <div className="min-w-0 flex-1">
        <div className="flex items-baseline gap-2">
          <span
            className={`text-sm font-semibold ${
              group.isOwner ? 'text-amber-800' : group.isCurrentUser ? 'text-slate-950' : 'text-slate-900'
            }`}
          >
            {group.senderLabel}
          </span>
          {group.isOwner ? (
            <span className="rounded-full bg-amber-100 px-1.5 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-amber-800">
              Teacher
            </span>
          ) : null}
          <span className="text-xs text-slate-400">
            {formatDateTime(group.firstTimestamp)}
          </span>
        </div>
        <div className="mt-0.5 space-y-0.5">
          {group.messages.map((message) => (
            <p
              key={message.id}
              className="whitespace-pre-wrap text-sm leading-6 text-slate-800"
            >
              {message.content}
            </p>
          ))}
        </div>
      </div>
    </div>
  )
}

function buildTimeline(
  messages: ChannelMessage[],
  currentUserId: string | null,
  senderNames: Record<string, string>,
  ownerId: string | null,
): TimelineEntry[] {
  const entries: TimelineEntry[] = []
  let lastDay = ''
  let currentGroup: MessageGroup | null = null

  const flushGroup = () => {
    if (currentGroup) {
      entries.push({
        type: 'group',
        key: `group-${currentGroup.messages[0].id}`,
        group: currentGroup,
      })
      currentGroup = null
    }
  }

  for (const message of messages) {
    const dayKey = formatDateOnly(message.datetime)

    if (dayKey !== lastDay) {
      flushGroup()
      lastDay = dayKey
      entries.push({
        type: 'day',
        key: `day-${dayKey}`,
        dayLabel: dayKey,
      })
    }

    if (
      currentGroup
      && currentGroup.senderID === message.sender
      && minutesBetween(
        currentGroup.messages[currentGroup.messages.length - 1].datetime,
        message.datetime,
      ) < 5
    ) {
      currentGroup.messages.push(message)
    } else {
      flushGroup()
      const isCurrentUser = currentUserId !== null && message.sender === currentUserId
      const isOwner = ownerId !== null && message.sender === ownerId
      currentGroup = {
        senderID: message.sender,
        isCurrentUser,
        isOwner,
        senderLabel: isCurrentUser
          ? 'You'
          : senderNames[message.sender] ?? 'Member',
        dayLabel: dayKey,
        firstTimestamp: message.datetime,
        messages: [message],
      }
    }
  }

  flushGroup()
  return entries
}

function minutesBetween(lhs: string, rhs: string): number {
  const left = Date.parse(lhs)
  const right = Date.parse(rhs)
  if (Number.isNaN(left) || Number.isNaN(right)) {
    return 999
  }
  return Math.abs((right - left) / 60000)
}

function initialOf(name: string): string {
  const trimmed = name.trim()
  if (!trimmed) {
    return '?'
  }
  return trimmed.charAt(0).toUpperCase()
}

const AVATAR_PALETTE = [
  '#3b82f6',
  '#8b5cf6',
  '#ec4899',
  '#f97316',
  '#14b8a6',
  '#6366f1',
  '#22c55e',
  '#06b6d4',
]

function avatarColorFor(name: string): string {
  let hash = 0
  for (let i = 0; i < name.length; i += 1) {
    hash = (hash + name.charCodeAt(i)) % AVATAR_PALETTE.length
  }
  return AVATAR_PALETTE[hash]
}
