import { useMemo, useState } from 'react'
import {
  ChevronRight,
  FileUp,
  MoreHorizontal,
  Pencil,
  Plus,
  Save,
  Search,
  Trash2,
  UserPlus,
  Users,
  X,
} from 'lucide-react'
import { toast } from 'sonner'

import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Checkbox } from '@/components/ui/checkbox'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { ScrollArea } from '@/components/ui/scroll-area'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { Skeleton } from '@/components/ui/skeleton'
import { Textarea } from '@/components/ui/textarea'
import { cn } from '@/lib/utils'
import type {
  AdminCreateUserForm,
  UpdateUserForm,
  UserClassSummary,
  UserGroup,
  UserProfile,
} from '@/lib/types'

export interface UsersPageProps {
  search: string
  students: UserProfile[]
  studentsLoading: boolean
  classSummaries: UserClassSummary[]
  classSummariesLoading: boolean
  selectedStudentId: string | null
  selectedStudent: UserProfile | null
  selectedStudentPending: boolean
  canViewStudents: boolean
  canEditStudents: boolean
  canDeleteStudents: boolean
  canCreateUsers: boolean
  savingStudentId: string | null
  deletingStudentId: string | null
  importingStudents: boolean
  batchUpdatingClass: boolean
  batchDeletingClass: boolean
  creatingUser: boolean
  userGroupFilter: 'student' | 'teacher' | 'all'
  onUserGroupFilterChange: (value: 'student' | 'teacher' | 'all') => void
  onCreateUser: (form: AdminCreateUserForm) => Promise<void>
  onSearchChange: (value: string) => void
  onSelectStudent: (studentId: string) => void
  onImportStudents: (csvText: string, defaultPassword: string) => Promise<void>
  onBatchUpdateClass: (fromClassname: string, toClassname: string) => Promise<void>
  onBatchDeleteClass: (classname: string) => Promise<void>
  onSaveStudent: (studentId: string, draft: UpdateUserForm) => Promise<void>
  onDeleteStudent: (studentId: string) => Promise<void>
}

type StudentEditorDraft = {
  realname: string
  gender: string
  classname: string
  description: string
  avatar: string
}

function studentToDraft(student: UserProfile): StudentEditorDraft {
  return {
    realname: student.realname,
    gender: student.gender,
    classname: student.classname,
    description: student.description,
    avatar: student.avatar ?? '',
  }
}

function normalizeStudentDraft(draft: StudentEditorDraft): UpdateUserForm {
  const trimmedAvatar = draft.avatar.trim()
  return {
    realname: draft.realname.trim(),
    gender: draft.gender.trim(),
    classname: draft.classname.trim(),
    description: draft.description.trim(),
    avatar: trimmedAvatar ? trimmedAvatar : null,
  }
}

function studentDraftMatchesProfile(draft: StudentEditorDraft, student: UserProfile): boolean {
  const normalized = normalizeStudentDraft(draft)
  return (
    normalized.realname === student.realname.trim() &&
    normalized.gender === student.gender.trim() &&
    normalized.classname === student.classname.trim() &&
    normalized.description === student.description.trim() &&
    normalized.avatar === (student.avatar?.trim() || null)
  )
}

function initials(user: UserProfile): string {
  const parts = user.realname.split(' ').filter(Boolean)
  if (parts.length === 0) {
    return (user.email[0] ?? '?').toUpperCase()
  }
  return parts
    .map((part) => part[0])
    .slice(0, 2)
    .join('')
    .toUpperCase()
}

type UserTabId = 'student' | 'teacher' | 'all'

const TAB_LABELS: Record<UserTabId, string> = {
  student: 'Students',
  teacher: 'Teachers',
  all: 'All users',
}

const TAB_EMPTY_HINT: Record<UserTabId, string> = {
  student: 'No students match your search.',
  teacher: 'No teachers match your search.',
  all: 'No users match your search.',
}

export function UsersPage(props: UsersPageProps) {
  const {
    search,
    students,
    studentsLoading,
    classSummaries,
    classSummariesLoading,
    selectedStudentId,
    selectedStudent,
    selectedStudentPending,
    canViewStudents,
    canEditStudents,
    canDeleteStudents,
    canCreateUsers,
    savingStudentId,
    deletingStudentId,
    importingStudents,
    batchUpdatingClass,
    batchDeletingClass,
    creatingUser,
    userGroupFilter,
    onUserGroupFilterChange,
    onCreateUser,
    onSearchChange,
    onSelectStudent,
    onImportStudents,
    onBatchUpdateClass,
    onBatchDeleteClass,
    onSaveStudent,
    onDeleteStudent,
  } = props

  const [createUserOpen, setCreateUserOpen] = useState(false)
  const [importOpen, setImportOpen] = useState(false)
  const [renameClassOpen, setRenameClassOpen] = useState(false)
  const [deleteClassOpen, setDeleteClassOpen] = useState(false)

  const [selectionMode, setSelectionMode] = useState(false)
  const [rawCheckedIds, setRawCheckedIds] = useState<Set<string>>(new Set())

  // Derive "visible checked ids" so a stale checked id (e.g. a user filtered out
  // by a tab switch) does not participate in bulk actions. No effect needed.
  const visibleIds = useMemo(() => new Set(students.map((student) => student.id)), [students])
  const checkedIds = useMemo(() => {
    if (rawCheckedIds.size === 0) {
      return rawCheckedIds
    }
    const next = new Set<string>()
    for (const id of rawCheckedIds) {
      if (visibleIds.has(id)) {
        next.add(id)
      }
    }
    return next
  }, [rawCheckedIds, visibleIds])

  const activeTab: UserTabId = userGroupFilter

  // Backend already filters `students` by the active tab via its `group` query
  // param (`student` / `teacher` / `all`), so `students.length` is the count
  // for whichever tab is currently active. We don't try to cross-count the
  // other tabs from this single list — their counts are simply unknown until
  // the user visits that tab — which is honest and avoids showing "0".
  const visibleCount = students.length
  const tabLabelWord =
    activeTab === 'teacher' ? 'teachers' : activeTab === 'all' ? 'users' : 'students'

  const toggleChecked = (id: string) => {
    setRawCheckedIds((current) => {
      const next = new Set(current)
      if (next.has(id)) {
        next.delete(id)
      } else {
        next.add(id)
      }
      return next
    })
  }

  const clearSelection = () => {
    setRawCheckedIds(new Set())
  }

  const exitSelectionMode = () => {
    setRawCheckedIds(new Set())
    setSelectionMode(false)
  }

  const selectAllVisible = () => {
    setRawCheckedIds(new Set(students.map((student) => student.id)))
  }

  const toggleSelectionMode = () => {
    setSelectionMode((value) => {
      if (value) {
        setRawCheckedIds(new Set())
      }
      return !value
    })
  }

  if (!canViewStudents) {
    return (
      <Card className="h-full border bg-white">
        <CardContent className="flex min-h-[520px] items-center justify-center">
          <p className="text-sm text-slate-600">
            You do not have permission to view user profiles.
          </p>
        </CardContent>
      </Card>
    )
  }

  return (
    <div className="flex h-full min-h-0 flex-col gap-4">
      {/* Header: title + counts + actions */}
      <div className="shrink-0">
        <div className="flex flex-col gap-4 rounded-2xl border border-slate-200/80 bg-white px-5 py-4 xl:flex-row xl:items-center xl:justify-between">
          <div className="min-w-0">
            <div className="flex items-center gap-2 text-[11px] font-semibold uppercase tracking-[0.2em] text-slate-400">
              <Users className="size-3.5" />
              Directory
            </div>
            <h1 className="mt-1 text-2xl font-semibold tracking-tight text-slate-950">
              People on the platform
            </h1>
            <p className="mt-1 text-sm text-slate-500">
              {studentsLoading
                ? 'Loading…'
                : `${visibleCount.toLocaleString()} ${tabLabelWord}`}
            </p>
          </div>

          <div className="flex flex-wrap items-center justify-end gap-2">
            <TabSegmented active={activeTab} onChange={onUserGroupFilterChange} />
            {canCreateUsers ? (
              <Button onClick={() => setCreateUserOpen(true)} className="shrink-0">
                <UserPlus className="mr-2 size-4" />
                New user
              </Button>
            ) : null}

            {canEditStudents ? (
              <DropdownMenu>
                <DropdownMenuTrigger asChild>
                  <Button variant="outline" size="icon" aria-label="More actions">
                    <MoreHorizontal className="size-4" />
                  </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent>
                  <DropdownMenuLabel>Batch actions</DropdownMenuLabel>
                  <DropdownMenuItem onSelect={() => setImportOpen(true)}>
                    <FileUp className="size-4" />
                    Import users from CSV…
                  </DropdownMenuItem>
                  <DropdownMenuSeparator />
                  <DropdownMenuLabel>By class</DropdownMenuLabel>
                  <DropdownMenuItem
                    onSelect={() => setRenameClassOpen(true)}
                    disabled={classSummaries.length === 0}
                  >
                    <Pencil className="size-4" />
                    Rename class…
                  </DropdownMenuItem>
                  <DropdownMenuItem
                    destructive
                    onSelect={() => setDeleteClassOpen(true)}
                    disabled={classSummaries.length === 0}
                  >
                    <Trash2 className="size-4" />
                    Remove all users in a class…
                  </DropdownMenuItem>
                </DropdownMenuContent>
              </DropdownMenu>
            ) : null}
          </div>
        </div>
      </div>

      {/* Main: rail + detail */}
      <div className="grid min-h-0 flex-1 gap-3 rounded-2xl border border-slate-200/80 bg-white p-3 xl:grid-cols-[340px_minmax(0,1fr)]">
        <aside className="flex min-h-0 flex-col rounded-xl bg-[linear-gradient(180deg,rgba(240,245,250,0.98),rgba(234,240,246,0.84))] p-4">
          <div className="shrink-0">
            <div className="flex items-center justify-between gap-2">
              <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-slate-400">
                {TAB_LABELS[activeTab]}
              </p>
              {canEditStudents ? (
                <Button
                  variant="ghost"
                  size="sm"
                  className="h-7 px-2 text-[11px] uppercase tracking-[0.14em] text-slate-500"
                  onClick={toggleSelectionMode}
                >
                  {selectionMode ? 'Done' : 'Select'}
                </Button>
              ) : null}
            </div>
            <div className="relative mt-3">
              <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
              <Input
                className="rounded-lg border-slate-200/80 bg-white/90 pl-9"
                placeholder="Search by name, class, or email"
                value={search}
                onChange={(event) => onSearchChange(event.target.value)}
              />
            </div>
            {selectionMode ? (
              <div className="mt-3 flex items-center justify-between text-xs text-slate-500">
                <span>{checkedIds.size} selected</span>
                <button
                  type="button"
                  className="font-medium text-slate-700 underline-offset-2 hover:underline"
                  onClick={
                    checkedIds.size === students.length ? clearSelection : selectAllVisible
                  }
                >
                  {checkedIds.size === students.length ? 'Clear all' : 'Select all visible'}
                </button>
              </div>
            ) : null}
          </div>

          <div className="mt-3 min-h-0 flex-1 rounded-xl bg-white/70 p-1.5 ring-1 ring-white/80">
            <ScrollArea className="h-full pr-1">
              <div className="grid gap-1.5 p-1 pb-3">
                {studentsLoading ? (
                  <>
                    <Skeleton className="h-20 rounded-lg" />
                    <Skeleton className="h-20 rounded-lg" />
                    <Skeleton className="h-20 rounded-lg" />
                  </>
                ) : students.length > 0 ? (
                  students.map((student) => {
                    const isSelected = student.id === selectedStudentId
                    const isChecked = checkedIds.has(student.id)
                    return (
                      <div
                        key={student.id}
                        className={cn(
                          'group flex items-center gap-2 rounded-xl border px-3 py-3 transition',
                          isSelected
                            ? 'border-white bg-white shadow-[0_18px_40px_-26px_rgba(15,23,42,0.28)] ring-1 ring-slate-200/90'
                            : 'border-transparent bg-transparent hover:bg-white/85',
                        )}
                      >
                        {selectionMode ? (
                          <Checkbox
                            checked={isChecked}
                            onCheckedChange={() => toggleChecked(student.id)}
                            aria-label={`Select ${student.realname}`}
                          />
                        ) : null}
                        <button
                          type="button"
                          onClick={() => {
                            if (selectionMode) {
                              toggleChecked(student.id)
                              return
                            }
                            onSelectStudent(student.id)
                          }}
                          className="flex min-w-0 flex-1 items-center gap-3 text-left focus:outline-none"
                        >
                          <AvatarBubble user={student} />
                          <div className="min-w-0 flex-1">
                            <p className="truncate text-sm font-semibold leading-5 text-slate-950">
                              {student.realname || 'Unnamed'}
                            </p>
                            <p className="truncate text-xs text-slate-500">{student.email}</p>
                          </div>
                          {!selectionMode ? (
                            <Badge
                              variant="secondary"
                              className="shrink-0 bg-slate-100 text-slate-600"
                            >
                              {student.classname || '—'}
                            </Badge>
                          ) : null}
                        </button>
                      </div>
                    )
                  })
                ) : (
                  <div className="rounded-lg border border-dashed border-slate-200 bg-white/80 p-6 text-sm text-slate-500">
                    {TAB_EMPTY_HINT[activeTab]}
                  </div>
                )}
              </div>
            </ScrollArea>
          </div>
        </aside>

        <div className="relative min-h-0 overflow-hidden rounded-xl bg-white">
          {selectedStudent ? (
            <StudentDetailPane
              key={selectedStudent.id}
              student={selectedStudent}
              canEdit={canEditStudents}
              canDelete={canDeleteStudents}
              saving={savingStudentId === selectedStudent.id}
              deleting={deletingStudentId === selectedStudent.id}
              onSave={onSaveStudent}
              onDelete={onDeleteStudent}
            />
          ) : selectedStudentPending ? (
            <Card className="h-full border-slate-200/70 bg-slate-50/60 shadow-none">
              <CardContent className="flex h-full min-h-[480px] flex-col gap-4 p-6">
                <Skeleton className="h-28 rounded-3xl" />
                <Skeleton className="h-full rounded-3xl" />
              </CardContent>
            </Card>
          ) : (
            <EmptyDetail activeTab={activeTab} />
          )}
        </div>
      </div>

      {/* Floating bulk action bar */}
      {selectionMode && checkedIds.size > 0 ? (
        <BulkActionBar
          count={checkedIds.size}
          onClear={clearSelection}
          onExit={exitSelectionMode}
        />
      ) : null}

      {/* Dialogs — use a key tied to open so internal state resets on reopen without effects. */}
      {createUserOpen ? (
        <CreateUserDialog
          key={`create-${createUserOpen}`}
          open={createUserOpen}
          initialGroup={userGroupFilter === 'all' ? 'student' : userGroupFilter}
          submitting={creatingUser}
          onOpenChange={setCreateUserOpen}
          onSubmit={async (form) => {
            try {
              await onCreateUser(form)
              setCreateUserOpen(false)
            } catch {
              // caller surfaces error via toast
            }
          }}
        />
      ) : null}

      {importOpen ? (
        <ImportUsersDialog
          key={`import-${importOpen}`}
          open={importOpen}
          onOpenChange={setImportOpen}
          submitting={importingStudents}
          onSubmit={async (csvText, password) => {
            try {
              await onImportStudents(csvText, password)
              setImportOpen(false)
            } catch {
              // caller surfaces error via toast
            }
          }}
        />
      ) : null}

      {renameClassOpen ? (
        <RenameClassDialog
          key={`rename-${renameClassOpen}`}
          open={renameClassOpen}
          onOpenChange={setRenameClassOpen}
          classSummaries={classSummaries}
          classSummariesLoading={classSummariesLoading}
          submitting={batchUpdatingClass}
          onSubmit={async (from, to) => {
            try {
              await onBatchUpdateClass(from, to)
              setRenameClassOpen(false)
            } catch {
              // caller surfaces error via toast
            }
          }}
        />
      ) : null}

      {deleteClassOpen ? (
        <DeleteClassDialog
          key={`delete-${deleteClassOpen}`}
          open={deleteClassOpen}
          onOpenChange={setDeleteClassOpen}
          classSummaries={classSummaries}
          classSummariesLoading={classSummariesLoading}
          submitting={batchDeletingClass}
          onSubmit={async (classname) => {
            try {
              await onBatchDeleteClass(classname)
              setDeleteClassOpen(false)
            } catch {
              // caller surfaces error via toast
            }
          }}
        />
      ) : null}
    </div>
  )
}

/**
 * Detail pane for the currently selected user. Rendered with `key={student.id}`
 * by the parent so that switching users cleanly remounts the editor and all
 * local draft/armed-delete state is reset without useEffect plumbing.
 */
function StudentDetailPane({
  student,
  canEdit,
  canDelete,
  saving,
  deleting,
  onSave,
  onDelete,
}: {
  student: UserProfile
  canEdit: boolean
  canDelete: boolean
  saving: boolean
  deleting: boolean
  onSave: (studentId: string, draft: UpdateUserForm) => Promise<void>
  onDelete: (studentId: string) => Promise<void>
}) {
  const [draft, setDraft] = useState<StudentEditorDraft>(() => studentToDraft(student))
  const [deleteArmed, setDeleteArmed] = useState(false)

  const draftChanged = !studentDraftMatchesProfile(draft, student)

  return (
    <div className="flex h-full min-h-0 flex-col">
      <div className="sticky top-0 z-10 border-b border-slate-100 bg-white/90 px-6 py-4 backdrop-blur">
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div className="flex min-w-0 items-center gap-4">
            <AvatarBubble user={student} size="lg" />
            <div className="min-w-0">
              <Badge variant="secondary" className="bg-slate-100 text-slate-700">
                {student.classname || '—'}
              </Badge>
              <h2 className="mt-1 truncate text-2xl font-semibold tracking-tight text-slate-950">
                {student.realname || 'Unnamed user'}
              </h2>
              <p className="truncate text-sm text-slate-500">{student.email}</p>
            </div>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <Button
              size="sm"
              disabled={!canEdit || !draftChanged || saving || deleting}
              onClick={async () => {
                const normalized = normalizeStudentDraft(draft)
                if (!normalized.realname || !normalized.gender || !normalized.classname) {
                  toast.error('Name, gender, and class are required.')
                  return
                }
                await onSave(student.id, normalized)
              }}
            >
              <Save className="mr-2 size-4" />
              {saving ? 'Saving…' : 'Save changes'}
            </Button>
            {canDelete ? (
              <Button
                size="sm"
                variant={deleteArmed ? 'destructive' : 'outline'}
                disabled={saving || deleting}
                onClick={async () => {
                  if (!deleteArmed) {
                    setDeleteArmed(true)
                    return
                  }
                  await onDelete(student.id)
                  setDeleteArmed(false)
                }}
              >
                <Trash2 className="mr-2 size-4" />
                {deleting ? 'Deleting…' : deleteArmed ? 'Confirm delete' : 'Delete'}
              </Button>
            ) : null}
          </div>
        </div>
      </div>

      <ScrollArea className="min-h-0 flex-1 px-6 py-5">
        <div className="grid gap-4 pb-6 md:grid-cols-2">
          <Card className="border-slate-200/70 bg-slate-50/60 shadow-none">
            <CardHeader className="p-5">
              <CardTitle>Identity</CardTitle>
            </CardHeader>
            <CardContent className="grid gap-4 px-5 pb-5 pt-0">
              <LabeledField label="Real name">
                <Input
                  value={draft.realname}
                  disabled={!canEdit || deleting}
                  onChange={(event) =>
                    setDraft((current) => ({ ...current, realname: event.target.value }))
                  }
                />
              </LabeledField>
              <LabeledField label="Gender">
                <Input
                  value={draft.gender}
                  disabled={!canEdit || deleting}
                  onChange={(event) =>
                    setDraft((current) => ({ ...current, gender: event.target.value }))
                  }
                />
              </LabeledField>
              <LabeledField label="Class">
                <Input
                  value={draft.classname}
                  disabled={!canEdit || deleting}
                  onChange={(event) =>
                    setDraft((current) => ({ ...current, classname: event.target.value }))
                  }
                />
              </LabeledField>
            </CardContent>
          </Card>

          <Card className="border-slate-200/70 bg-slate-50/60 shadow-none">
            <CardHeader className="p-5">
              <CardTitle>Profile</CardTitle>
            </CardHeader>
            <CardContent className="grid gap-4 px-5 pb-5 pt-0">
              <LabeledField label="Avatar URL">
                <Input
                  value={draft.avatar}
                  disabled={!canEdit || deleting}
                  placeholder="/api/v1/resource/…"
                  onChange={(event) =>
                    setDraft((current) => ({ ...current, avatar: event.target.value }))
                  }
                />
              </LabeledField>
              <LabeledField label="Description">
                <Textarea
                  value={draft.description}
                  disabled={!canEdit || deleting}
                  rows={8}
                  onChange={(event) =>
                    setDraft((current) => ({ ...current, description: event.target.value }))
                  }
                />
              </LabeledField>
            </CardContent>
          </Card>
        </div>
      </ScrollArea>
    </div>
  )
}

function TabSegmented({
  active,
  onChange,
}: {
  active: UserTabId
  onChange: (value: UserTabId) => void
}) {
  const tabs: UserTabId[] = ['student', 'teacher', 'all']
  return (
    <div className="inline-flex rounded-lg border border-slate-200 bg-white p-1 text-sm">
      {tabs.map((tab) => {
        const label = tab === 'student' ? 'Students' : tab === 'teacher' ? 'Teachers' : 'All'
        const isActive = active === tab
        return (
          <button
            key={tab}
            type="button"
            onClick={() => onChange(tab)}
            className={cn(
              'inline-flex items-center gap-1.5 rounded-md px-3 py-1.5 transition',
              isActive ? 'bg-slate-900 text-white' : 'text-slate-600 hover:text-slate-900',
            )}
          >
            {label}
          </button>
        )
      })}
    </div>
  )
}

function EmptyDetail({ activeTab }: { activeTab: UserTabId }) {
  return (
    <Card className="h-full border-slate-200/70 bg-slate-50/60 shadow-none">
      <CardContent className="flex h-full min-h-[480px] flex-col items-center justify-center gap-4 text-center">
        <div className="flex size-14 items-center justify-center rounded-2xl bg-slate-950 text-white">
          <Users className="size-6" />
        </div>
        <div className="max-w-sm">
          <h2 className="text-xl font-semibold text-slate-950">
            Pick a{' '}
            {activeTab === 'teacher'
              ? 'teacher'
              : activeTab === 'all'
              ? 'user'
              : 'student'}{' '}
            to get started
          </h2>
          <p className="mt-1 text-sm text-slate-500">
            Choose someone from the list on the left to view and edit their profile.
          </p>
        </div>
      </CardContent>
    </Card>
  )
}

function BulkActionBar({
  count,
  onClear,
  onExit,
}: {
  count: number
  onClear: () => void
  onExit: () => void
}) {
  return (
    <div className="pointer-events-none fixed inset-x-0 bottom-6 z-40 flex justify-center px-4">
      <div className="pointer-events-auto flex items-center gap-3 rounded-full border border-slate-200 bg-white px-4 py-2 shadow-[0_32px_64px_-32px_rgba(15,23,42,0.34)]">
        <span className="text-sm font-medium text-slate-900">{count} selected</span>
        <div className="h-5 w-px bg-slate-200" />
        <Button variant="ghost" size="sm" onClick={onClear} className="h-8">
          Clear
        </Button>
        <Button variant="ghost" size="sm" onClick={onExit} className="h-8 text-slate-500">
          <X className="mr-1 size-4" />
          Exit
        </Button>
      </div>
    </div>
  )
}

function AvatarBubble({ user, size = 'md' }: { user: UserProfile; size?: 'md' | 'lg' }) {
  const classes = size === 'lg' ? 'size-14 text-base' : 'size-10 text-xs'
  return (
    <div
      className={cn(
        'flex shrink-0 items-center justify-center rounded-full bg-slate-900 font-semibold text-white',
        classes,
      )}
      aria-hidden
    >
      {initials(user)}
    </div>
  )
}

function LabeledField({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="grid gap-2">
      <span className="text-xs font-medium uppercase tracking-[0.2em] text-slate-400">{label}</span>
      {children}
    </label>
  )
}

// ---- Dialogs ----

function CreateUserDialog({
  open,
  initialGroup,
  submitting,
  onOpenChange,
  onSubmit,
}: {
  open: boolean
  initialGroup: UserGroup
  submitting: boolean
  onOpenChange: (value: boolean) => void
  onSubmit: (form: AdminCreateUserForm) => Promise<void>
}) {
  const [form, setForm] = useState<AdminCreateUserForm>(() => ({
    email: '',
    realname: '',
    password: '',
    gender: 'other',
    classname: '',
    avatar: null,
    group: initialGroup,
  }))

  const canSubmit =
    !submitting &&
    form.email.trim().length > 0 &&
    form.realname.trim().length > 0 &&
    form.password.trim().length > 0

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>Create a new user</DialogTitle>
          <DialogDescription>
            New users can sign in immediately with the email and password you set here.
          </DialogDescription>
        </DialogHeader>

        <div className="grid gap-3 md:grid-cols-2">
          <div className="grid gap-1 md:col-span-2">
            <Label>Role</Label>
            <Select
              value={form.group}
              onValueChange={(value) =>
                setForm((prev) => ({ ...prev, group: value as UserGroup }))
              }
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="student">Student</SelectItem>
                <SelectItem value="teacher">Teacher</SelectItem>
                <SelectItem value="admin">Administrator</SelectItem>
              </SelectContent>
            </Select>
          </div>

          <div className="grid gap-1">
            <Label>Real name</Label>
            <Input
              value={form.realname}
              onChange={(event) =>
                setForm((prev) => ({ ...prev, realname: event.target.value }))
              }
              placeholder="Alex Liu"
            />
          </div>
          <div className="grid gap-1">
            <Label>Email</Label>
            <Input
              type="email"
              value={form.email}
              onChange={(event) => setForm((prev) => ({ ...prev, email: event.target.value }))}
              placeholder="alex.liu@ulink.cn"
            />
          </div>
          <div className="grid gap-1">
            <Label>Temporary password</Label>
            <Input
              type="password"
              value={form.password}
              onChange={(event) =>
                setForm((prev) => ({ ...prev, password: event.target.value }))
              }
              placeholder="At least 8 characters"
            />
          </div>
          <div className="grid gap-1">
            <Label>Class</Label>
            <Input
              value={form.classname}
              onChange={(event) =>
                setForm((prev) => ({ ...prev, classname: event.target.value }))
              }
              placeholder={form.group === 'teacher' ? 'Faculty' : '10A'}
            />
          </div>
          <div className="grid gap-1 md:col-span-2">
            <Label>Gender</Label>
            <Select
              value={form.gender}
              onValueChange={(value) => setForm((prev) => ({ ...prev, gender: value }))}
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="female">Female</SelectItem>
                <SelectItem value="male">Male</SelectItem>
                <SelectItem value="other">Other</SelectItem>
              </SelectContent>
            </Select>
          </div>
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)} disabled={submitting}>
            Cancel
          </Button>
          <Button
            disabled={!canSubmit}
            onClick={async () => {
              await onSubmit(form)
            }}
          >
            <Plus className="mr-2 size-4" />
            {submitting ? 'Creating…' : 'Create user'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

function ImportUsersDialog({
  open,
  submitting,
  onOpenChange,
  onSubmit,
}: {
  open: boolean
  submitting: boolean
  onOpenChange: (value: boolean) => void
  onSubmit: (csvText: string, defaultPassword: string) => Promise<void>
}) {
  const [file, setFile] = useState<File | null>(null)
  const [password, setPassword] = useState('change-me-2026')

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Import users from CSV</DialogTitle>
          <DialogDescription>
            Upload a CSV file with columns for email, real name, class, and (optionally) password.
            Rows without a password will use the default you set below.
          </DialogDescription>
        </DialogHeader>

        <div className="grid gap-3">
          <div className="grid gap-1">
            <Label>CSV file</Label>
            <Input
              type="file"
              accept=".csv,text/csv"
              disabled={submitting}
              onChange={(event) => setFile(event.target.files?.[0] ?? null)}
            />
          </div>
          <div className="grid gap-1">
            <Label>Default password</Label>
            <Input
              type="password"
              value={password}
              disabled={submitting}
              onChange={(event) => setPassword(event.target.value)}
            />
          </div>
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)} disabled={submitting}>
            Cancel
          </Button>
          <Button
            disabled={submitting || !file || !password.trim()}
            onClick={async () => {
              if (!file) {
                toast.error('Please choose a CSV file first.')
                return
              }
              const trimmed = password.trim()
              if (!trimmed) {
                toast.error('Default password cannot be empty.')
                return
              }
              const csvText = await file.text()
              await onSubmit(csvText, trimmed)
            }}
          >
            <FileUp className="mr-2 size-4" />
            {submitting ? 'Importing…' : 'Import users'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

function RenameClassDialog({
  open,
  classSummaries,
  classSummariesLoading,
  submitting,
  onOpenChange,
  onSubmit,
}: {
  open: boolean
  classSummaries: UserClassSummary[]
  classSummariesLoading: boolean
  submitting: boolean
  onOpenChange: (value: boolean) => void
  onSubmit: (fromClassname: string, toClassname: string) => Promise<void>
}) {
  const [from, setFrom] = useState('')
  const [to, setTo] = useState('')

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Rename a class</DialogTitle>
          <DialogDescription>
            Move every user in one class over to a new class name in a single step.
          </DialogDescription>
        </DialogHeader>

        <div className="grid gap-3">
          <div className="grid gap-1">
            <Label>From class</Label>
            <Select
              value={from || undefined}
              onValueChange={setFrom}
              disabled={classSummariesLoading || classSummaries.length === 0}
            >
              <SelectTrigger>
                <SelectValue placeholder="Choose class" />
              </SelectTrigger>
              <SelectContent>
                {classSummaries.map((entry) => (
                  <SelectItem key={entry.classname} value={entry.classname}>
                    {entry.classname} ({entry.count})
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <div className="flex items-center justify-center text-slate-400">
            <ChevronRight className="size-4" />
          </div>
          <div className="grid gap-1">
            <Label>To class</Label>
            <Input
              value={to}
              onChange={(event) => setTo(event.target.value)}
              placeholder="New class name"
            />
          </div>
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)} disabled={submitting}>
            Cancel
          </Button>
          <Button
            disabled={submitting || !from.trim() || !to.trim() || from.trim() === to.trim()}
            onClick={async () => {
              await onSubmit(from.trim(), to.trim())
            }}
          >
            {submitting ? 'Renaming…' : 'Rename class'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

function DeleteClassDialog({
  open,
  classSummaries,
  classSummariesLoading,
  submitting,
  onOpenChange,
  onSubmit,
}: {
  open: boolean
  classSummaries: UserClassSummary[]
  classSummariesLoading: boolean
  submitting: boolean
  onOpenChange: (value: boolean) => void
  onSubmit: (classname: string) => Promise<void>
}) {
  const [classname, setClassname] = useState('')
  const [confirmText, setConfirmText] = useState('')

  const selectedSummary = classSummaries.find((entry) => entry.classname === classname)
  const confirmed = confirmText.trim() === classname.trim() && classname.trim().length > 0

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Remove all users in a class</DialogTitle>
          <DialogDescription>
            This deletes every user in the chosen class. The action cannot be undone. Type the
            class name to confirm.
          </DialogDescription>
        </DialogHeader>

        <div className="grid gap-3">
          <div className="grid gap-1">
            <Label>Class</Label>
            <Select
              value={classname || undefined}
              onValueChange={(value) => {
                setClassname(value)
                setConfirmText('')
              }}
              disabled={classSummariesLoading || classSummaries.length === 0}
            >
              <SelectTrigger>
                <SelectValue placeholder="Choose class" />
              </SelectTrigger>
              <SelectContent>
                {classSummaries.map((entry) => (
                  <SelectItem key={entry.classname} value={entry.classname}>
                    {entry.classname} ({entry.count})
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          {selectedSummary ? (
            <p className="rounded-lg bg-rose-50 px-3 py-2 text-xs text-rose-700 ring-1 ring-rose-100">
              This will permanently remove {selectedSummary.count} user
              {selectedSummary.count === 1 ? '' : 's'}.
            </p>
          ) : null}
          <div className="grid gap-1">
            <Label>Type &ldquo;{classname || 'class name'}&rdquo; to confirm</Label>
            <Input
              value={confirmText}
              disabled={!classname}
              onChange={(event) => setConfirmText(event.target.value)}
            />
          </div>
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)} disabled={submitting}>
            Cancel
          </Button>
          <Button
            variant="destructive"
            disabled={submitting || !confirmed}
            onClick={async () => {
              await onSubmit(classname.trim())
            }}
          >
            {submitting ? 'Removing…' : 'Remove users'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
