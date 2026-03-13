import { useEffect, useMemo, useState } from 'react'
import { Lock, MessagesSquare, Send } from 'lucide-react'

import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { ScrollArea } from '@/components/ui/scroll-area'
import { formatDateTime, shortIdentifier } from '@/lib/format'
import { activityChannelIsReadOnly, type ActivityState, type ChannelMessage, type ChannelResponse } from '@/lib/types'

interface ChannelPanelProps {
  pushUrl: string
  channel: ChannelResponse | null
  activityState: ActivityState
  initialMessages: ChannelMessage[]
  senderNames: Record<string, string>
  currentUserId: string | null
  isSendingMessage: boolean
  onSendMessage: (content: string) => Promise<void>
}

export function ChannelPanel({
  pushUrl,
  channel,
  activityState,
  initialMessages,
  senderNames,
  currentUserId,
  isSendingMessage,
  onSendMessage,
}: ChannelPanelProps) {
  const [composer, setComposer] = useState('')
  const [messages, setMessages] = useState<ChannelMessage[]>(initialMessages)
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

  return (
    <Card className="border-border/70 shadow-none">
      <CardHeader>
        <CardTitle>Channel</CardTitle>
        <CardDescription>
          Live coordination for organisers and volunteers.
        </CardDescription>
      </CardHeader>
      <CardContent className="grid gap-4">
        {channel ? (
          <>
            <div className="rounded-xl border border-border/70 bg-muted/20 px-4 py-3 text-sm">
              <span className="font-medium text-foreground">{channel.name}</span>
              <span className="ml-2 text-muted-foreground">
                {channel.members.length} members
              </span>
            </div>

            {readOnly ? (
              <div className="flex items-start gap-3 rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-900">
                <Lock className="mt-0.5 size-4 shrink-0" />
                <div>
                  <p className="font-medium">Channel is read only</p>
                  <p className="mt-1 text-amber-800/80">
                    This activity has ended, so the discussion is now archived.
                  </p>
                </div>
              </div>
            ) : null}

            <ScrollArea className="h-[320px] rounded-xl border border-border/70 bg-background">
              <div className="space-y-3 p-4">
                {orderedMessages.length > 0 ? (
                  orderedMessages.map((message) => {
                    const isCurrentUser = message.sender === currentUserId

                    return (
                      <div
                        key={message.id}
                        className={`flex ${isCurrentUser ? 'justify-end' : 'justify-start'}`}
                      >
                        <div
                          className={`max-w-[85%] rounded-2xl px-4 py-3 text-sm ${
                            isCurrentUser
                              ? 'bg-primary text-primary-foreground'
                              : 'border border-border bg-muted/30 text-foreground'
                          }`}
                        >
                          <div className="mb-1 flex items-center gap-2 text-xs opacity-80">
                            <span className="font-medium">
                              {senderNames[message.sender] ??
                                `Member · ${shortIdentifier(message.sender)}`}
                            </span>
                            <span>{formatDateTime(message.datetime)}</span>
                          </div>
                          <p className="whitespace-pre-wrap leading-6">{message.content}</p>
                        </div>
                      </div>
                    )
                  })
                ) : (
                  <div className="flex h-full min-h-[200px] flex-col items-center justify-center gap-3 text-center text-sm text-muted-foreground">
                    <MessagesSquare className="size-8" />
                    <div>
                      <p className="font-medium text-foreground">No messages yet</p>
                      <p>Use the channel for live coordination once this activity is underway.</p>
                    </div>
                  </div>
                )}
              </div>
            </ScrollArea>

            <form
              className="flex gap-3"
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
              <Input
                value={composer}
                onChange={(event) => setComposer(event.target.value)}
                placeholder={readOnly ? 'Archived after activity completion' : 'Share an update with the activity team'}
                disabled={readOnly}
              />
              <Button type="submit" disabled={readOnly || isSendingMessage || !composer.trim()}>
                <Send className="mr-2 size-4" />
                {isSendingMessage ? 'Sending…' : 'Send'}
              </Button>
            </form>
          </>
        ) : (
          <div className="rounded-xl border border-dashed border-border bg-muted/20 p-6 text-sm text-muted-foreground">
            This activity channel is not ready yet. Refresh after the activity is created.
          </div>
        )}
      </CardContent>
    </Card>
  )
}
