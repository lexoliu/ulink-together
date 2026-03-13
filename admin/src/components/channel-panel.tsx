import { useEffect, useMemo, useState } from 'react'
import { MessagesSquare, Plus, Send } from 'lucide-react'

import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { ScrollArea } from '@/components/ui/scroll-area'
import { formatDateTime, shortIdentifier } from '@/lib/format'
import type { ChannelMessage, ChannelResponse } from '@/lib/types'

interface ChannelPanelProps {
  pushUrl: string
  channel: ChannelResponse | null
  initialMessages: ChannelMessage[]
  senderNames: Record<string, string>
  currentUserId: string | null
  canCreateChannel: boolean
  isCreatingChannel: boolean
  isSendingMessage: boolean
  onCreateChannel: () => void
  onSendMessage: (content: string) => Promise<void>
}

export function ChannelPanel({
  pushUrl,
  channel,
  initialMessages,
  senderNames,
  currentUserId,
  canCreateChannel,
  isCreatingChannel,
  isSendingMessage,
  onCreateChannel,
  onSendMessage,
}: ChannelPanelProps) {
  const [composer, setComposer] = useState('')
  const [messages, setMessages] = useState<ChannelMessage[]>(initialMessages)

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
        <div className="flex items-center justify-between gap-4">
          <div>
            <CardTitle>Channel</CardTitle>
            <CardDescription>
              Live coordination for organisers and volunteers.
            </CardDescription>
          </div>
          {channel ? null : canCreateChannel ? (
            <Button onClick={onCreateChannel} disabled={isCreatingChannel}>
              <Plus className="mr-2 size-4" />
              {isCreatingChannel ? 'Creating…' : 'Create channel'}
            </Button>
          ) : null}
        </div>
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
                placeholder="Share an update with the activity team"
              />
              <Button type="submit" disabled={isSendingMessage || !composer.trim()}>
                <Send className="mr-2 size-4" />
                {isSendingMessage ? 'Sending…' : 'Send'}
              </Button>
            </form>
          </>
        ) : (
          <div className="rounded-xl border border-dashed border-border bg-muted/20 p-6 text-sm text-muted-foreground">
            {canCreateChannel
              ? 'This activity has no channel yet. Create one to start live coordination.'
              : 'This activity has no channel yet.'}
          </div>
        )}
      </CardContent>
    </Card>
  )
}
