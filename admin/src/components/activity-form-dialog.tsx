import { useEffect } from 'react'
import { useForm, useWatch } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'

import { Button } from '@/components/ui/button'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Switch } from '@/components/ui/switch'
import { Textarea } from '@/components/ui/textarea'
import type { ActivityDraft } from '@/lib/types'

const activityDraftSchema = z.object({
  name: z.string().trim().min(1, 'Activity name is required.'),
  dateEnabled: z.boolean(),
  dateValue: z.string(),
  hasParticipantLimit: z.boolean(),
  maxVolunteerNum: z.number().int().min(1).max(500),
  location: z.string().trim().min(1, 'Location is required.'),
  briefDescription: z.string().trim().min(1, 'Short summary is required.').max(180),
  description: z.string().trim().min(1, 'Full description is required.'),
  duration: z.number().int().min(30).max(480),
}).superRefine((value, context) => {
  if (value.dateEnabled && !value.dateValue) {
    context.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['dateValue'],
      message: 'Choose a date and time.',
    })
  }
})

type ActivityDraftForm = z.infer<typeof activityDraftSchema>

interface ActivityFormDialogProps {
  open: boolean
  title: string
  description: string
  initialValue: ActivityDraft
  onOpenChange: (open: boolean) => void
  onSubmit: (draft: ActivityDraft) => Promise<void>
}

export function ActivityFormDialog({
  open,
  title,
  description,
  initialValue,
  onOpenChange,
  onSubmit,
}: ActivityFormDialogProps) {
  const form = useForm<ActivityDraftForm>({
    resolver: zodResolver(activityDraftSchema),
    defaultValues: initialValue,
  })

  useEffect(() => {
    if (open) {
      form.reset(initialValue)
    }
  }, [form, initialValue, open])

  const submitting = form.formState.isSubmitting
  const dateEnabled = useWatch({ control: form.control, name: 'dateEnabled' })
  const hasParticipantLimit = useWatch({
    control: form.control,
    name: 'hasParticipantLimit',
  })

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-2xl p-0 sm:max-w-2xl">
        <DialogHeader className="px-6 pt-6">
          <DialogTitle>{title}</DialogTitle>
          <DialogDescription>{description}</DialogDescription>
        </DialogHeader>

        <form
          className="grid gap-6 px-6 pb-6"
          onSubmit={form.handleSubmit(async (values) => {
            await onSubmit(values)
          })}
        >
          <section className="grid gap-4 sm:grid-cols-2">
            <div className="grid gap-2 sm:col-span-2">
              <Label htmlFor="name">Activity name</Label>
              <Input id="name" {...form.register('name')} />
              <FieldError message={form.formState.errors.name?.message} />
            </div>

            <div className="grid gap-3 rounded-xl border border-border/70 bg-muted/20 p-4 sm:col-span-2">
              <div className="flex items-center justify-between gap-4">
                <div>
                  <p className="text-sm font-medium">Scheduled date</p>
                  <p className="text-xs text-muted-foreground">
                    Leave this off for drafts that are still being coordinated.
                  </p>
                </div>
                <Switch
                  checked={dateEnabled}
                  onCheckedChange={(checked) => form.setValue('dateEnabled', checked)}
                />
              </div>
              {dateEnabled ? (
                <div className="grid gap-2">
                  <Label htmlFor="dateValue">Date and time</Label>
                  <Input
                    id="dateValue"
                    type="datetime-local"
                    {...form.register('dateValue')}
                  />
                  <FieldError message={form.formState.errors.dateValue?.message} />
                </div>
              ) : null}
            </div>

            <div className="grid gap-2">
              <Label htmlFor="location">Location</Label>
              <Input id="location" {...form.register('location')} />
              <FieldError message={form.formState.errors.location?.message} />
            </div>

            <div className="grid gap-2">
              <Label htmlFor="duration">Duration in minutes</Label>
              <Input
                id="duration"
                type="number"
                min={30}
                step={30}
                {...form.register('duration', { valueAsNumber: true })}
              />
              <FieldError message={form.formState.errors.duration?.message} />
            </div>

            <div className="grid gap-3 rounded-xl border border-border/70 bg-muted/20 p-4 sm:col-span-2">
              <div className="flex items-center justify-between gap-4">
                <div>
                  <p className="text-sm font-medium">Participant limit</p>
                  <p className="text-xs text-muted-foreground">
                    Turn this on when the activity has a fixed capacity.
                  </p>
                </div>
                <Switch
                  checked={hasParticipantLimit}
                  onCheckedChange={(checked) => form.setValue('hasParticipantLimit', checked)}
                />
              </div>
              {hasParticipantLimit ? (
                <div className="grid gap-2">
                  <Label htmlFor="maxVolunteerNum">Max participants</Label>
                  <Input
                    id="maxVolunteerNum"
                    type="number"
                    min={1}
                    max={500}
                    {...form.register('maxVolunteerNum', { valueAsNumber: true })}
                  />
                  <FieldError message={form.formState.errors.maxVolunteerNum?.message} />
                </div>
              ) : null}
            </div>
          </section>

          <section className="grid gap-4">
            <div className="grid gap-2">
              <Label htmlFor="briefDescription">Short summary</Label>
              <Textarea
                id="briefDescription"
                rows={3}
                {...form.register('briefDescription')}
              />
              <FieldError message={form.formState.errors.briefDescription?.message} />
            </div>

            <div className="grid gap-2">
              <Label htmlFor="description">Full description</Label>
              <Textarea id="description" rows={6} {...form.register('description')} />
              <FieldError message={form.formState.errors.description?.message} />
            </div>
          </section>

          <DialogFooter className="rounded-b-none border-t-0 bg-transparent px-0 pb-0 pt-2">
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              Cancel
            </Button>
            <Button type="submit" disabled={submitting}>
              {submitting ? 'Saving…' : 'Save activity'}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

function FieldError({ message }: { message?: string }) {
  if (!message) {
    return null
  }

  return <p className="text-xs text-destructive">{message}</p>
}
