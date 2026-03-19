import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
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
    action: 'approve_apply' | 'done' | 'disapprove_apply',
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

  return (
    <Card className="border-border/70 shadow-none">
      <CardHeader>
        <CardTitle>Participant records</CardTitle>
        <CardDescription>
          Review who joined, confirm completed hours, and close out attendance.
        </CardDescription>
      </CardHeader>
      <CardContent>
        {records.length === 0 ? (
          <div className="rounded-xl border border-dashed border-border bg-muted/20 p-6 text-sm text-muted-foreground">
            No participant records have been created for this activity yet.
          </div>
        ) : (
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Volunteer</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>Confirmed hours</TableHead>
                <TableHead>Updated</TableHead>
                <TableHead className="text-right">Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {records.map((record) => (
                <TableRow key={record.id}>
                  <TableCell>
                    <div className="flex flex-col">
                      <span className="font-medium">
                        {names[record.user] ?? `Volunteer · ${shortIdentifier(record.user)}`}
                      </span>
                      <span className="text-xs text-muted-foreground">
                        ID · {shortIdentifier(record.user)}
                      </span>
                    </div>
                  </TableCell>
                  <TableCell>
                    <Badge variant="secondary">{recordStateLabel(record.state)}</Badge>
                  </TableCell>
                  <TableCell>{formatHours(record.confirmed_minutes)}</TableCell>
                  <TableCell>{formatDateTime(record.updated_at)}</TableCell>
                  <TableCell className="text-right">
                    {canManage ? (
                      <div className="flex justify-end gap-2">
                        <Button
                          size="sm"
                          variant="outline"
                          disabled={pendingActionId === record.id}
                          onClick={() => onRecordAction(record.id, 'approve_apply')}
                        >
                          Approve
                        </Button>
                        <Button
                          size="sm"
                          disabled={pendingActionId === record.id || !canConfirmHours}
                          onClick={() => {
                            const input = window.prompt(
                              'Confirmed minutes (leave empty to use activity duration).',
                              '',
                            )
                            if (input === null) {
                              return
                            }
                            const trimmed = input.trim()
                            if (!trimmed) {
                              onRecordAction(record.id, 'done')
                              return
                            }
                            const parsedMinutes = Number.parseInt(trimmed, 10)
                            if (
                              Number.isFinite(parsedMinutes) === false
                              || Number.isNaN(parsedMinutes)
                              || parsedMinutes < 0
                            ) {
                              window.alert('Please enter a non-negative integer minute value.')
                              return
                            }
                            onRecordAction(record.id, 'done', {
                              confirmedMinutes: parsedMinutes,
                            })
                          }}
                        >
                          {canConfirmHours ? 'Mark done' : `${activityStateLabel(activityState)} first`}
                        </Button>
                        <Button
                          size="sm"
                          variant="destructive"
                          disabled={pendingActionId === record.id}
                          onClick={() => onRecordAction(record.id, 'disapprove_apply')}
                        >
                          Cancel
                        </Button>
                      </div>
                    ) : (
                      <span className="text-xs text-muted-foreground">
                        Read only
                      </span>
                    )}
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        )}
      </CardContent>
    </Card>
  )
}
