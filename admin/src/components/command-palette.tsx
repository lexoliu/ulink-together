import { useEffect } from 'react'
import { Command as CommandPrimitive } from 'cmdk'
import { Download, FolderKanban, House, MessageSquareMore, Plus, ShieldCheck, Users } from 'lucide-react'

import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { activityStateLabel, formatDateOnly } from '@/lib/format'
import type { ActivitySummary } from '@/lib/types'

interface CommandPaletteProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  activities: ActivitySummary[]
  onOpenHome: () => void
  onOpenStudents?: () => void
  onOpenOperations?: () => void
  onOpenActivity: (activityId: string) => void
  onOpenChat: (activityId: string) => void
  onCreateActivity?: () => void
  onGenerateExport?: () => void
}

export function CommandPalette({
  open,
  onOpenChange,
  activities,
  onOpenHome,
  onOpenStudents,
  onOpenOperations,
  onOpenActivity,
  onOpenChat,
  onCreateActivity,
  onGenerateExport,
}: CommandPaletteProps) {
  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key.toLowerCase() !== 'k' || (!event.metaKey && !event.ctrlKey)) {
        return
      }

      event.preventDefault()
      onOpenChange(!open)
    }

    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [onOpenChange, open])

  const shortcutLabel = navigator.platform.toLowerCase().includes('mac') ? '⌘K' : 'Ctrl K'

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
        <DialogContent className="max-w-2xl overflow-hidden rounded-[2rem] border-white/70 bg-white/95 p-0 shadow-2xl shadow-slate-300/35 backdrop-blur-xl sm:max-w-2xl" showCloseButton={false}>
        <DialogHeader className="border-b border-slate-200/70 px-5 pt-5 pb-4">
          <DialogTitle className="text-lg font-semibold text-slate-950">Quick switch</DialogTitle>
        </DialogHeader>

        <CommandPrimitive
          label="Global command menu"
          className="flex max-h-[70vh] flex-col overflow-hidden"
        >
          <div className="border-b border-slate-200/70 px-4 py-3">
            <CommandPrimitive.Input
              autoFocus
              placeholder="Search activities, chats, or actions"
              className="h-11 w-full rounded-2xl border border-slate-200 bg-slate-50 px-4 text-sm text-slate-950 outline-none placeholder:text-slate-400"
            />
          </div>

          <CommandPrimitive.List className="max-h-[56vh] overflow-y-auto px-3 py-3">
            <CommandPrimitive.Empty className="rounded-2xl px-4 py-10 text-center text-sm text-slate-500">
              Nothing matched your search.
            </CommandPrimitive.Empty>

            <CommandGroup heading="Go to">
              <CommandItem
                icon={<House className="size-4" />}
                title="Home"
                hint={shortcutLabel}
                onSelect={() => {
                  onOpenChange(false)
                  onOpenHome()
                }}
              />
              {onOpenStudents ? (
                <CommandItem
                  icon={<Users className="size-4" />}
                  title="Students"
                  onSelect={() => {
                    onOpenChange(false)
                    onOpenStudents()
                  }}
                />
              ) : null}
              {onOpenOperations ? (
                <CommandItem
                  icon={<ShieldCheck className="size-4" />}
                  title="Operations"
                  onSelect={() => {
                    onOpenChange(false)
                    onOpenOperations()
                  }}
                />
              ) : null}
            </CommandGroup>

            {onCreateActivity || onGenerateExport ? (
              <CommandGroup heading="Actions">
                {onCreateActivity ? (
                  <CommandItem
                    icon={<Plus className="size-4" />}
                    title="Create activity"
                    onSelect={() => {
                      onOpenChange(false)
                      onCreateActivity()
                    }}
                  />
                ) : null}
                {onGenerateExport ? (
                  <CommandItem
                    icon={<Download className="size-4" />}
                    title="Generate export batch"
                    onSelect={() => {
                      onOpenChange(false)
                      onGenerateExport()
                    }}
                  />
                ) : null}
              </CommandGroup>
            ) : null}

            <CommandGroup heading="Activities">
              {activities.slice(0, 8).map((activity) => (
                <CommandItem
                  key={`activity-${activity.id}`}
                  icon={<FolderKanban className="size-4" />}
                  title={activity.name}
                  subtitle={`${formatDateOnly(activity.date)} · ${activity.location}`}
                  trailing={activityStateLabel(activity.state)}
                  onSelect={() => {
                    onOpenChange(false)
                    onOpenActivity(activity.id)
                  }}
                />
              ))}
            </CommandGroup>

            <CommandGroup heading="Chats">
              {activities.slice(0, 8).map((activity) => (
                <CommandItem
                  key={`chat-${activity.id}`}
                  icon={<MessageSquareMore className="size-4" />}
                  title={activity.name}
                  subtitle={`Open ${activityStateLabel(activity.state).toLowerCase()} room`}
                  trailing={formatDateOnly(activity.date)}
                  onSelect={() => {
                    onOpenChange(false)
                    onOpenChat(activity.id)
                  }}
                />
              ))}
            </CommandGroup>
          </CommandPrimitive.List>
        </CommandPrimitive>
      </DialogContent>
    </Dialog>
  )
}

function CommandGroup({
  heading,
  children,
}: {
  heading: string
  children: React.ReactNode
}) {
  return (
    <CommandPrimitive.Group
      heading={heading}
      className="mb-4 overflow-hidden rounded-2xl border border-slate-200/70 bg-slate-50/60 p-2 text-slate-600 [&_[cmdk-group-heading]]:px-2 [&_[cmdk-group-heading]]:pb-2 [&_[cmdk-group-heading]]:text-[11px] [&_[cmdk-group-heading]]:font-semibold [&_[cmdk-group-heading]]:uppercase [&_[cmdk-group-heading]]:tracking-[0.22em] [&_[cmdk-group-heading]]:text-slate-400"
    >
      {children}
    </CommandPrimitive.Group>
  )
}

function CommandItem({
  icon,
  title,
  subtitle,
  trailing,
  hint,
  onSelect,
}: {
  icon: React.ReactNode
  title: string
  subtitle?: string
  trailing?: string
  hint?: string
  onSelect: () => void
}) {
  return (
    <CommandPrimitive.Item
      value={[title, subtitle, trailing].filter(Boolean).join(' ')}
      onSelect={onSelect}
      className="flex cursor-pointer items-center gap-3 rounded-[1.15rem] px-3 py-3 text-sm outline-none transition data-[selected=true]:bg-white data-[selected=true]:shadow-sm"
    >
      <div className="flex size-10 shrink-0 items-center justify-center rounded-2xl bg-white text-slate-700 shadow-sm ring-1 ring-slate-200/70">
        {icon}
      </div>
      <div className="min-w-0 flex-1">
        <p className="truncate font-medium text-slate-950">{title}</p>
        {subtitle ? <p className="truncate text-xs text-slate-500">{subtitle}</p> : null}
      </div>
      {trailing ? <span className="text-xs font-medium text-slate-400">{trailing}</span> : null}
      {hint ? (
        <span className="rounded-full border border-slate-200 px-2 py-1 text-[11px] font-medium text-slate-400">
          {hint}
        </span>
      ) : null}
    </CommandPrimitive.Item>
  )
}
