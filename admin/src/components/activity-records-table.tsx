import { useState } from 'react'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import { activityStateLabel, formatDateTime, formatHours, recordStateLabel, shortIdentifier } from '@/lib/format'
import type { ActivityState, RecordEntry } from '@/lib/types'

interface ActivityRecordsTableProps {
  activityState: ActivityState
  records: RecordEntry[]
  names: Record<string, string>
  canManage: boolean
  pendingActionId?: string
  onRecordAction: (
    recordId: string,
    action: 'approve' | 'confirm' | 'cancel',
    options?: { confirmedMinutes?: number },
  ) => void
}

export function ActivityRecordsTable({
  activityState,
  records,
  names,
  canManage,
  pendingActionId,
  onRecordAction,
}: ActivityRecordsTableProps) {
  const canConfirmHours = activityState === 'ended'
  const [confirmingId, setConfirmingId] = useState<string | null>(null)
  const [confirmMinutes, setConfirmMinutes] = useState('')

  const handleConfirmSubmit = (recordId: string) => {
    const trimmed = confirmMinutes.trim()
    if (!trimmed) {
      onRecordAction(recordId, 'confirm')
    } else {
      const parsed = Number.parseInt(trimmed, 10)
      if (Number.isFinite(parsed) && parsed >= 0) {
        onRecordAction(recordId, 'confirm', { confirmedMinutes: parsed })
      }
    }
    setConfirmingId(null)
    setConfirmMinutes('')
  }

  return (
    <div>
      {records.length === 0 ? (
        <p className="py-8 text-center text-sm text-muted-foreground">
          No participant records.
        </p>
      ) : (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Volunteer</TableHead>
              <TableHead>Status</TableHead>
              <TableHead>Hours</TableHead>
              <TableHead>Updated</TableHead>
              <TableHead className="text-right">Actions</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {records.map((record) => (
              <TableRow key={record.id}>
                <TableCell>
                  <span className="text-sm font-medium">
                    {names[record.user] ?? `Volunteer · ${shortIdentifier(record.user)}`}
                  </span>
                </TableCell>
                <TableCell>
                  <Badge variant="secondary">{recordStateLabel(record.state)}</Badge>
                </TableCell>
                <TableCell className="text-sm">{formatHours(record.confirmed_minutes)}</TableCell>
                <TableCell className="text-sm text-muted-foreground">{formatDateTime(record.updated_at)}</TableCell>
                <TableCell className="text-right">
                  {canManage ? (
                    <div className="flex items-center justify-end gap-1.5">
                      {confirmingId === record.id ? (
                        <form
                          className="flex items-center gap-1.5"
                          onSubmit={(e) => {
                            e.preventDefault()
                            handleConfirmSubmit(record.id)
                          }}
                        >
                          <Input
                            type="number"
                            min={0}
                            placeholder="minutes"
                            className="h-7 w-20 text-sm"
                            value={confirmMinutes}
                            onChange={(e) => setConfirmMinutes(e.target.value)}
                            autoFocus
                          />
                          <Button type="submit" size="sm" className="h-7">
                            OK
                          </Button>
                          <Button
                            type="button"
                            size="sm"
                            variant="ghost"
                            className="h-7"
                            onClick={() => {
                              setConfirmingId(null)
                              setConfirmMinutes('')
                            }}
                          >
                            Cancel
                          </Button>
                        </form>
                      ) : (
                        <>
                          <Button
                            size="sm"
                            variant="outline"
                            className="h-7"
                            disabled={pendingActionId === record.id}
                            onClick={() => onRecordAction(record.id, 'approve')}
                          >
                            Approve
                          </Button>
                          <Button
                            size="sm"
                            className="h-7"
                            disabled={pendingActionId === record.id || !canConfirmHours}
                            onClick={() => {
                              setConfirmingId(record.id)
                              setConfirmMinutes('')
                            }}
                          >
                            {canConfirmHours ? 'Confirm' : `${activityStateLabel(activityState)} first`}
                          </Button>
                          <Button
                            size="sm"
                            variant="destructive"
                            className="h-7"
                            disabled={pendingActionId === record.id}
                            onClick={() => onRecordAction(record.id, 'cancel')}
                          >
                            Cancel
                          </Button>
                        </>
                      )}
                    </div>
                  ) : (
                    <span className="text-xs text-muted-foreground">Read only</span>
                  )}
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      )}
    </div>
  )
}
