/**
 * Calendar helpers. Dates are ISO strings ("2026-11-02") and "today" is computed in the
 * user's time zone (users.time_zone), matching the server's views.
 */
export function todayIn(timeZone: string, now = new Date()): string {
  // en-CA formats as YYYY-MM-DD.
  return new Intl.DateTimeFormat('en-CA', { timeZone, year: 'numeric', month: '2-digit', day: '2-digit' }).format(now)
}

export function addDays(iso: string, days: number): string {
  const [y, m, d] = iso.split('-').map(Number)
  const date = new Date(Date.UTC(y!, m! - 1, d! + days))
  return date.toISOString().slice(0, 10)
}

export function daysBetween(from: string, to: string): number {
  return Math.round((Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / 86_400_000)
}

function utcDate(iso: string) {
  return new Date(`${iso}T12:00:00Z`)
}

export function weekdayName(iso: string, style: 'long' | 'short' = 'long') {
  return new Intl.DateTimeFormat('en-US', { weekday: style, timeZone: 'UTC' }).format(utcDate(iso))
}

/** "Today", "Tomorrow", "Yesterday", "Friday" (within a week), else "Nov 4" / "Nov 4, 2027". */
export function relativeDay(iso: string, today: string): string {
  const diff = daysBetween(today, iso)
  if (diff === 0) return 'Today'
  if (diff === 1) return 'Tomorrow'
  if (diff === -1) return 'Yesterday'
  if (diff > 1 && diff < 7) return weekdayName(iso)
  const sameYear = iso.slice(0, 4) === today.slice(0, 4)
  return new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: sameYear ? undefined : 'numeric', timeZone: 'UTC' })
    .format(utcDate(iso))
}

export function longDay(iso: string) {
  return new Intl.DateTimeFormat('en-US', { weekday: 'long', month: 'long', day: 'numeric', timeZone: 'UTC' }).format(utcDate(iso))
}

/** "6:00 PM" for a timestamp, shown in the user's zone. */
export function timeOfDay(timestamp: string, timeZone: string) {
  return new Intl.DateTimeFormat('en-US', { hour: 'numeric', minute: '2-digit', timeZone }).format(new Date(timestamp))
}

/** "18:00" (for <input type="time">) for a timestamp in the user's zone. */
export function timeInputValue(timestamp: string, timeZone: string) {
  return new Intl.DateTimeFormat('en-GB', { hour: '2-digit', minute: '2-digit', hourCycle: 'h23', timeZone }).format(new Date(timestamp))
}

/**
 * A local date + time with no offset ("2026-11-02T18:00"). Rails parses offset-less times
 * in the request's zone (the user's), so the browser never has to do zone math.
 */
export function localDateTime(date: string, time: string) {
  return `${date}T${time}`
}

export function formatMinutes(minutes: number) {
  if (minutes < 60) return `${minutes}m`
  const h = Math.floor(minutes / 60)
  const m = minutes % 60
  return m ? `${h}h ${m}m` : `${h}h`
}
