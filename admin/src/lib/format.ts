import { format, isValid, parseISO } from 'date-fns'

import type { ActivityState, RecordState } from '@/lib/types'

export function formatDateTime(value: string | null | undefined): string {
  if (!value) {
    return 'Unscheduled'
  }

  try {
    return format(parseKnownDate(value), 'MMM d, yyyy h:mm a')
  } catch {
    return value
  }
}

export function formatDateOnly(value: string | null | undefined): string {
  if (!value) {
    return 'Unscheduled'
  }

  try {
    return format(parseKnownDate(value), 'MMM d, yyyy')
  } catch {
    return value
  }
}

export function formatDuration(minutes: number): string {
  const hours = Math.floor(minutes / 60)
  const remainder = minutes % 60

  if (hours > 0 && remainder > 0) {
    return `${hours}h ${remainder}m`
  }

  if (hours > 0) {
    return `${hours}h`
  }

  return `${remainder}m`
}

export function formatHours(minutes: number): string {
  return `${(minutes / 60).toFixed(1)} hrs`
}

export function activityStateLabel(state: ActivityState): string {
  switch (state) {
    case 'need_volunteer':
      return 'Recruiting'
    case 'going':
      return 'In Progress'
    case 'ended':
      return 'Completed'
    case 'canceled':
      return 'Cancelled'
  }
}

export function recordStateLabel(state: RecordState): string {
  switch (state) {
    case 'pending_approval':
      return 'Pending approval'
    case 'approved':
      return 'Approved'
    case 'confirmed':
      return 'Confirmed'
    case 'canceled':
      return 'Cancelled'
  }
}

export function toDateTimeLocalInput(value: string | null | undefined): string {
  if (!value) {
    return ''
  }

  try {
    return format(parseISO(value), "yyyy-MM-dd'T'HH:mm")
  } catch {
    return ''
  }
}

export function shortIdentifier(value: string): string {
  return value.slice(-6)
}

function parseKnownDate(value: string): Date {
  const direct = parseISO(value)
  if (isValid(direct)) {
    return direct
  }

  const normalized = parseISO(normalizeServerTimestamp(value))
  if (isValid(normalized)) {
    return normalized
  }

  throw new Error(`Invalid date: ${value}`)
}

function normalizeServerTimestamp(value: string): string {
  if (value.includes('T')) {
    return value
  }

  const normalizedOffset = value.replace(/ ([+-]\d{2}:\d{2}):\d{2}$/, '$1')
  return normalizedOffset.replace(' ', 'T')
}
