/** Repeat rules (RRULE subset, see app/models/recurrence.rb) and their human labels. */
const DAYS = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'] as const
const NAMES = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']

export const repeatPresets = [
  { label: 'Every day', rule: 'FREQ=DAILY;INTERVAL=1' },
  { label: 'Every weekday', rule: 'FREQ=WEEKLY;INTERVAL=1;BYDAY=MO,TU,WE,TH,FR' },
  { label: 'Every week', rule: 'FREQ=WEEKLY;INTERVAL=1' },
  { label: 'Every 2 weeks', rule: 'FREQ=WEEKLY;INTERVAL=2' },
  { label: 'Every month', rule: 'FREQ=MONTHLY;INTERVAL=1' },
  { label: 'Every year', rule: 'FREQ=YEARLY;INTERVAL=1' },
]

export function weeklyOn(days: number[]) {
  return `FREQ=WEEKLY;INTERVAL=1;BYDAY=${[...new Set(days)].sort().map((d) => DAYS[d - 1]).join(',')}`
}

export function recurrenceLabel(rule: string | null | undefined) {
  if (!rule) return null
  const parts = Object.fromEntries(rule.split(';').map((p) => p.split('=')))
  const n = Number(parts.INTERVAL ?? 1)
  const unit = { DAILY: 'day', WEEKLY: 'week', MONTHLY: 'month', YEARLY: 'year' }[parts.FREQ as string] ?? 'time'
  const days: string[] = parts.BYDAY ? parts.BYDAY.split(',') : []
  if (days.length === 5 && !days.includes('SA') && !days.includes('SU') && n === 1) return 'Every weekday'
  const on = days.length ? ` on ${days.map((d) => NAMES[DAYS.indexOf(d as (typeof DAYS)[number])]!.slice(0, 3)).join(', ')}` : ''
  return `Every ${n === 1 ? unit : `${n} ${unit}s`}${on}`
}
