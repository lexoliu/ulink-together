import { useEffect, useMemo, useRef, useState } from 'react'
import { AnimatePresence, motion } from 'motion/react'
import { BellRing, Lock, MessagesSquare, Send, Sparkles, Users } from 'lucide-react'
import TextareaAutosize from 'react-textarea-autosize'

import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { ScrollArea } from '@/components/ui/scroll-area'
import { formatDateTime, shortIdentifier } from '@/lib/format'
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
  ownerLabel?: string | null
  isSendingMessage: boolean
  onSendMessage: (content: string) => Promise<void>
}

interface TimelineEntry {
  type: 'day' | 'message'
  key: string
  dayLabel?: string
  message?: ChannelMessage
}

export function ChannelPanel({
  pushUrl,
  channel,
  activityState,
  initialMessages,
  senderNames,
  currentUserId,
  ownerId,
  ownerLabel,
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

  const timeline = useMemo(() => buildTimeline(orderedMessages), [orderedMessages])

  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: 'smooth', block: 'end' })
  }, [timeline.length])

  return (
    <Card className="border-white/70 bg-white/95 shadow-lg shadow-slate-200/40">
      <CardHeader className="gap-4 border-b border-slate-200/70 pb-5">
        <div className="flex flex-col gap-4 xl:flex-row xl:items-center xl:justify-between">
          <div>
            <CardDescription>Live room</CardDescription>
            <CardTitle className="mt-1 text-2xl font-semibold tracking-tight text-slate-950">
              {channel?.name ?? 'Activity room'}
            </CardTitle>
          </div>

          <div className="flex flex-wrap gap-2">
            <HeaderPill icon={<Users className="size-3.5" />} label={`${channel?.members.length ?? 0} members`} />
            <HeaderPill
              icon={readOnly ? <Lock className="size-3.5" /> : <BellRing className="size-3.5" />}
              label={readOnly ? 'Archived' : 'Live'}
            />
            {ownerId ? (
              <HeaderPill icon={<Sparkles className="size-3.5" />} label={`${ownerLabel ?? 'Organiser'} notices highlighted`} />
            ) : null}
          </div>
        </div>
      </CardHeader>

      <CardContent className="grid gap-4 p-0">
        {channel ? (
          <>
            {readOnly ? (
              <div className="mx-6 mt-6 flex items-start gap-3 rounded-[1.35rem] border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-900">
                <Lock className="mt-0.5 size-4 shrink-0" />
                <div>
                  <p className="font-medium">Room is read only</p>
                  <p className="mt-1 text-amber-800/80">
                    This activity has ended, so the discussion is preserved as an archive.
                  </p>
                </div>
              </div>
            ) : null}

            <ScrollArea className="h-[min(68vh,760px)] px-6">
              <div className="space-y-5 py-6">
                {timeline.length > 0 ? (
                  <AnimatePresence initial={false}>
                    {timeline.map((entry) =>
                      entry.type === 'day' ? (
                        <motion.div
                          key={entry.key}
                          initial={{ opacity: 0, y: 8 }}
                          animate={{ opacity: 1, y: 0 }}
                          exit={{ opacity: 0 }}
                          className="flex items-center gap-3 py-1"
                        >
                          <div className="h-px flex-1 bg-slate-200" />
                          <span className="text-xs font-semibold uppercase tracking-[0.2em] text-slate-400">
                            {entry.dayLabel}
                          </span>
                          <div className="h-px flex-1 bg-slate-200" />
                        </motion.div>
                      ) : (
                        <MessageRow
                          key={entry.key}
                          message={entry.message!}
                          currentUserId={currentUserId}
                          senderNames={senderNames}
                          ownerId={ownerId}
                          ownerLabel={ownerLabel}
                        />
                      ),
                    )}
                  </AnimatePresence>
                ) : (
                  <div className="flex min-h-[360px] flex-col items-center justify-center gap-4 text-center text-sm text-slate-500">
                    <MessagesSquare className="size-9" />
                    <div>
                      <p className="font-medium text-slate-950">No messages yet</p>
                      <p className="mt-2 max-w-sm leading-7">
                        This room is ready for schedule changes, arrival notes, and organiser announcements.
                      </p>
                    </div>
                  </div>
                )}
                <div ref={endRef} />
              </div>
            </ScrollArea>

            <form
              className="border-t border-slate-200/70 bg-white/92 px-6 py-5"
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
              <div className="rounded-[1.6rem] border border-slate-200/80 bg-slate-50/85 p-3 shadow-sm">
                <TextareaAutosize
                  minRows={1}
                  maxRows={6}
                  value={composer}
                  onChange={(event) => setComposer(event.target.value)}
                  placeholder={
                    readOnly
                      ? 'This room is archived after the activity ended'
                      : 'Write an update for the activity team'
                  }
                  disabled={readOnly}
                  className="w-full resize-none border-0 bg-transparent px-1 py-1 text-sm leading-7 text-slate-950 outline-none placeholder:text-slate-400 disabled:cursor-not-allowed"
                />

                <div className="mt-3 flex items-center justify-between gap-3">
                  <p className="text-xs text-slate-500">
                    {readOnly
                      ? 'Archived rooms stay visible but cannot accept new posts.'
                      : 'Organiser posts are surfaced as notices to keep key updates easy to spot.'}
                  </p>
                  <Button
                    type="submit"
                    className="rounded-2xl"
                    disabled={readOnly || isSendingMessage || !composer.trim()}
                  >
                    <Send className="mr-2 size-4" />
                    {isSendingMessage ? 'Sending…' : 'Send'}
                  </Button>
                </div>
              </div>
            </form>
          </>
        ) : (
          <div className="px-6 pb-6">
            <div className="rounded-[1.5rem] border border-dashed border-slate-200 bg-slate-50/70 p-6 text-sm text-slate-500">
              This activity room is not available yet.
            </div>
          </div>
        )}
      </CardContent>
    </Card>
  )
}

function MessageRow({
  message,
  currentUserId,
  senderNames,
  ownerId,
  ownerLabel,
}: {
  message: ChannelMessage
  currentUserId: string | null
  senderNames: Record<string, string>
  ownerId?: string | null
  ownerLabel?: string | null
}) {
  const isCurrentUser = message.sender === currentUserId
  const isOwnerNotice = ownerId !== undefined && ownerId !== null && message.sender === ownerId
  const senderLabel = isCurrentUser
    ? 'You'
    : senderNames[message.sender] ?? `Member · ${shortIdentifier(message.sender)}`

  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0 }}
      className={`flex ${isCurrentUser ? 'justify-end' : 'justify-start'}`}
    >
      <div className={`max-w-[min(86%,44rem)] space-y-2 ${isCurrentUser ? 'items-end' : 'items-start'}`}>
        <div
          className={`flex items-center gap-2 px-1 text-xs ${
            isCurrentUser ? 'justify-end text-slate-400' : 'justify-start text-slate-500'
          }`}
        >
          <span className="font-medium text-slate-700">{senderLabel}</span>
          {isOwnerNotice ? (
            <span className="rounded-full bg-amber-100 px-2 py-0.5 font-medium text-amber-800">
              {ownerLabel ?? 'Organiser'} notice
            </span>
          ) : null}
          <span>{formatDateTime(message.datetime)}</span>
        </div>

        <div
          className={`rounded-[1.45rem] px-4 py-3 text-sm leading-7 shadow-sm ring-1 ${
            isCurrentUser
              ? 'bg-slate-950 text-white ring-slate-950/10'
              : isOwnerNotice
                ? 'bg-amber-50 text-amber-950 ring-amber-200/80'
                : 'bg-slate-50 text-slate-900 ring-slate-200/80'
          }`}
        >
          <p className="whitespace-pre-wrap">{message.content}</p>
        </div>
      </div>
    </motion.div>
  )
}

function HeaderPill({
  icon,
  label,
}: {
  icon: React.ReactNode
  label: string
}) {
  return (
    <div className="inline-flex items-center gap-2 rounded-full border border-slate-200/80 bg-slate-50 px-3 py-1.5 text-xs font-medium text-slate-600">
      {icon}
      <span>{label}</span>
    </div>
  )
}

function buildTimeline(messages: ChannelMessage[]): TimelineEntry[] {
  let lastDay = ''

  return messages.flatMap((message) => {
    const date = new Date(message.datetime)
    const dayKey = Number.isNaN(date.getTime())
      ? message.datetime.slice(0, 10)
      : date.toLocaleDateString(undefined, {
          month: 'short',
          day: 'numeric',
          year: 'numeric',
        })
    const entries: TimelineEntry[] = []

    if (dayKey !== lastDay) {
      lastDay = dayKey
      entries.push({
        type: 'day',
        key: `day-${dayKey}`,
        dayLabel: dayKey,
      })
    }

    entries.push({
      type: 'message',
      key: message.id,
      message,
    })

    return entries
  })
}
