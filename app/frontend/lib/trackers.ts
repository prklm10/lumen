import type { Frequency, Tracker, TrackerKind } from '@/api/trackers'
import { formatMinutes } from './dates'

export const WEEKDAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'] as const

export const kindLabels: Record<TrackerKind, { label: string; hint: string }> = {
  boolean: { label: 'Yes / no', hint: 'Did it or didn’t' },
  count: { label: 'Count', hint: 'Glasses of water, pages…' },
  duration: { label: 'Duration', hint: 'Minutes of exercise' },
  numeric: { label: 'Number', hint: 'Weight, hours of sleep' },
  scale: { label: 'Scale 1–5', hint: 'Energy, focus, mood' },
}

/** ISO weekday (1 = Monday … 7 = Sunday) of a YYYY-MM-DD date. */
export function isoWeekday(iso: string) {
  return ((new Date(`${iso}T12:00:00Z`).getUTCDay() + 6) % 7) + 1
}

export function frequencyLabel(f: Frequency) {
  if (f.type === 'daily') return 'Every day'
  if (f.type === 'weekly') return f.times === 1 ? 'Once a week' : `${f.times}× a week`
  if (f.days.length === 5 && f.days.every((d) => d <= 5)) return 'Weekdays'
  if (f.days.length === 2 && f.days.includes(6) && f.days.includes(7)) return 'Weekends'
  return f.days.map((d) => WEEKDAYS[d - 1]).join(', ')
}

/** Is a check-in expected on this day? Weekly trackers accept any day. */
export function isScheduled(tracker: Pick<Tracker, 'frequency'>, iso: string) {
  return tracker.frequency.type !== 'weekdays' || tracker.frequency.days.includes(isoWeekday(iso))
}

/** Same rule as the server (Tracker#met?): a check-in counts once it reaches the target. */
export function isMet(tracker: Pick<Tracker, 'kind' | 'target'>, value: number | null | undefined) {
  if (value === null || value === undefined) return false
  if (tracker.kind === 'boolean') return value >= 1
  return tracker.target ? value >= tracker.target : true
}

export function formatValue(tracker: Pick<Tracker, 'kind' | 'unit'>, value: number) {
  if (tracker.kind === 'boolean') return value >= 1 ? 'Done' : 'Not done'
  if (tracker.kind === 'duration') return formatMinutes(value)
  if (tracker.kind === 'scale') return `${value}/5`
  const number = Number.isInteger(value) ? String(value) : value.toFixed(1)
  return tracker.unit ? `${number} ${tracker.unit}` : number
}

export function targetLabel(tracker: Pick<Tracker, 'kind' | 'unit' | 'target'>) {
  if (!tracker.target || tracker.kind === 'boolean') return null
  return `Goal: ${formatValue(tracker, tracker.target)}`
}

/** 0–4 for heatmap shading: how far toward the target a day got. */
export function intensity(tracker: Pick<Tracker, 'kind' | 'target'>, value: number | undefined) {
  if (value === undefined || value <= 0) return 0
  if (tracker.kind === 'boolean') return 4
  if (tracker.kind === 'scale') return Math.min(4, Math.max(1, Math.round(value - 1)))
  if (!tracker.target) return 3
  return Math.min(4, Math.max(1, Math.ceil((value / tracker.target) * 4)))
}
