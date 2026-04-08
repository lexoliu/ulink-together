import { Download, Files } from 'lucide-react'
import { toast } from 'sonner'

import { Button } from '@/components/ui/button'
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { ScrollArea } from '@/components/ui/scroll-area'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import { formatDateTime, formatHours } from '@/lib/format'
import type { ExportBatchResponse } from '@/lib/types'

interface ExportBatchDialogProps {
  open: boolean
  batch: ExportBatchResponse | null
  onOpenChange: (open: boolean) => void
}

export function ExportBatchDialog({
  open,
  batch,
  onOpenChange,
}: ExportBatchDialogProps) {
  if (!batch) {
    return null
  }

  const download = () => {
    const blob = new Blob([batch.content], { type: batch.content_type })
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = batch.file_name
    link.click()
    URL.revokeObjectURL(url)
  }

  const copy = async () => {
    await navigator.clipboard.writeText(batch.content)
    toast.success('CSV copied to clipboard.')
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-5xl p-0 sm:max-w-5xl">
        <DialogHeader className="px-6 pt-6">
          <DialogTitle>Export batch</DialogTitle>
        </DialogHeader>

        <div className="grid gap-6 px-6 pb-6">
          <div className="grid gap-2 rounded-xl border border-border/70 bg-muted/20 p-4 text-sm sm:grid-cols-3">
            <Metadata label="File" value={batch.file_name} />
            <Metadata label="Generated" value={formatDateTime(batch.created_at)} />
            <Metadata label="Rows" value={String(batch.items.length)} />
          </div>

          <ScrollArea className="h-[360px] rounded-xl border border-border/70">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Student</TableHead>
                  <TableHead>Class</TableHead>
                  <TableHead>Activity</TableHead>
                  <TableHead>Date</TableHead>
                  <TableHead>Confirmed</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {batch.items.map((item) => (
                  <TableRow key={item.id}>
                    <TableCell>{item.student_name}</TableCell>
                    <TableCell>{item.class_name}</TableCell>
                    <TableCell>{item.activity_title}</TableCell>
                    <TableCell>{formatDateTime(item.activity_date)}</TableCell>
                    <TableCell>{formatHours(item.confirmed_minutes)}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </ScrollArea>

          <div className="rounded-xl border border-border/70 bg-zinc-950 p-4">
            <pre className="overflow-x-auto whitespace-pre-wrap text-xs leading-6 text-zinc-100">
              {batch.content}
            </pre>
          </div>

          <DialogFooter className="rounded-b-none border-t-0 bg-transparent px-0 pb-0 pt-0">
            <Button type="button" variant="outline" onClick={copy}>
              <Files className="mr-2 size-4" />
              Copy CSV
            </Button>
            <Button type="button" onClick={download}>
              <Download className="mr-2 size-4" />
              Download
            </Button>
          </DialogFooter>
        </div>
      </DialogContent>
    </Dialog>
  )
}

function Metadata({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <p className="text-xs uppercase tracking-[0.18em] text-muted-foreground">
        {label}
      </p>
      <p className="mt-1 text-sm font-medium text-foreground">{value}</p>
    </div>
  )
}
