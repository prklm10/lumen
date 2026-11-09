import type { Priority } from '@/api/tasks'
import { addDays } from './dates'
import { weeklyOn } from './recurrence'
import { isoWeekday } from './trackers'

/**
 * Natural-language quick add (TSK-6): "Call mom tomorrow 6pm #family !high @errands every week".
 *   dates     today, tonight, tomorrow, monday…sunday, next week, in 3 days, jan 5, 5 jan, 2026-11-05
 *   times     6pm, 6:30pm, 18:00, at 9
 *   repeat    every day/weekday/week/month/year, every monday, every 2 weeks, daily, weekly…
 *   #tag      tags            !high / !p1…!p4   priority          @project   project (name prefix)
 * Matched words are removed from the title. Everything is optional.
 */
export interface QuickAddResult {
  title: string
  due_date: string | null
  time: string | null
  priority: Priority | null
  tag_names: string[]
  project: string | null
  recurrence_rule: string | null
  /** Human-readable bits that were recognised, for chips under the input. */
  matches: { kind: 'date' | 'time' | 'repeat' | 'priority' | 'tag' | 'project'; text: string }[]
}

const WEEKDAYS = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']
const WD = '(mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun)(?:day|sday|nesday|rsday|urday)?'
const MONTHS = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec']
const MON = '(jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*'
const PRIORITIES: Record<string, Priority> = {
  urgent: 'urgent', high: 'high', medium: 'medium', med: 'medium', low: 'low',
  p1: 'urgent', p2: 'high', p3: 'medium', p4: 'low', '1': 'urgent', '2': 'high', '3': 'medium', '4': 'low',
}

const weekdayIndex = (word: string) => WEEKDAYS.findIndex((d) => d.startsWith(word.slice(0, 3).toLowerCase())) + 1

function nextWeekday(today: string, iso: number, skipThisWeek = false) {
  let diff = (iso - isoWeekday(today) + 7) % 7
  if (diff === 0 || skipThisWeek) diff += 7
  return addDays(today, diff)
}

function pad(n: number) {
  return String(n).padStart(2, '0')
}

function monthDay(today: string, month: number, day: number) {
  const year = Number(today.slice(0, 4))
  let date = `${year}-${pad(month)}-${pad(day)}`
  if (date < today) date = `${year + 1}-${pad(month)}-${pad(day)}` // "jan 5" in December means next year
  return date
}

export function parseQuickAdd(input: string, today: string): QuickAddResult {
  let text = ` ${input} `
  const result: QuickAddResult = { title: '', due_date: null, time: null, priority: null, tag_names: [], project: null, recurrence_rule: null, matches: [] }

  const take = (pattern: RegExp, handle: (m: RegExpExecArray) => string | false | void) => {
    const re = new RegExp(`(?<=\\s)${pattern.source}(?=\\s)`, pattern.flags.includes('u') ? 'iu' : 'i')
    const m = re.exec(text)
    if (!m) return false
    const label = handle(m)
    if (label === false) return false
    text = text.slice(0, m.index) + text.slice(m.index + m[0].length)
    return true
  }
  const match = (kind: QuickAddResult['matches'][number]['kind'], label: string) => result.matches.push({ kind, text: label })

  // Repeat first, so "every monday" isn't read as a plain date.
  take(new RegExp(`(?:every|each) (\\d+ )?(day|weekday|week|month|year|${WD})s?`), (m) => {
    const n = Math.max(1, Number(m[1] ?? 1))
    const unit = m[2]!.toLowerCase()
    if (unit === 'weekday') result.recurrence_rule = 'FREQ=WEEKLY;INTERVAL=1;BYDAY=MO,TU,WE,TH,FR'
    else if (['day', 'week', 'month', 'year'].includes(unit)) {
      const freq = { day: 'DAILY', week: 'WEEKLY', month: 'MONTHLY', year: 'YEARLY' }[unit]
      result.recurrence_rule = `FREQ=${freq};INTERVAL=${n}`
    } else {
      const iso = weekdayIndex(unit)
      result.recurrence_rule = weeklyOn([iso])
      result.due_date ??= nextWeekday(today, iso)
    }
    match('repeat', m[0])
  }) || take(/(daily|weekly|monthly|yearly)/, (m) => {
    result.recurrence_rule = `FREQ=${m[1]!.toUpperCase()};INTERVAL=1`
    match('repeat', m[0])
  })

  // Time: "6pm", "6:30 pm", "at 18:00", "at 9".
  take(/(?:at )?(\d{1,2})(?::(\d{2}))? ?(am|pm)/, (m) => {
    let h = Number(m[1]) % 12
    if (m[3]!.toLowerCase() === 'pm') h += 12
    const min = Number(m[2] ?? 0)
    if (min > 59) return false
    result.time = `${pad(h)}:${pad(min)}`
    match('time', m[0].trim())
  }) || take(/(?:at )?([01]?\d|2[0-3]):([0-5]\d)/, (m) => {
    result.time = `${pad(Number(m[1]))}:${m[2]}`
    match('time', m[0].trim())
  }) || take(/at (\d{1,2})/, (m) => {
    const h = Number(m[1])
    if (h > 23) return false
    result.time = `${pad(h)}:00`
    match('time', m[0])
  })

  // Dates.
  const setDate = (date: string, label: string) => {
    result.due_date = date
    match('date', label)
  }
  take(/(today|tod)/, (m) => setDate(today, m[0])) ||
    take(/tonight/, (m) => {
      setDate(today, m[0])
      result.time ??= '20:00'
    }) ||
    take(/(tomorrow|tmrw?|tmw)/, (m) => setDate(addDays(today, 1), m[0])) ||
    take(/next week/, (m) => setDate(nextWeekday(today, 1), m[0])) ||
    take(/in (\d{1,3}) (day|week|month)s?/, (m) => {
      const n = Number(m[1])
      const unit = m[2]!.toLowerCase()
      setDate(unit === 'day' ? addDays(today, n) : unit === 'week' ? addDays(today, n * 7) : addDays(today, n * 30), m[0])
    }) ||
    take(new RegExp(`(next |this )?${WD}`), (m) => setDate(nextWeekday(today, weekdayIndex(m[2]!), m[1]?.trim().toLowerCase() === 'next'), m[0])) ||
    take(/(\d{4})-(\d{2})-(\d{2})/, (m) => setDate(`${m[1]}-${m[2]}-${m[3]}`, m[0])) ||
    take(new RegExp(`${MON} (\\d{1,2})(?:st|nd|rd|th)?`), (m) => setDate(monthDay(today, MONTHS.indexOf(m[1]!.slice(0, 3).toLowerCase()) + 1, Number(m[2])), m[0])) ||
    take(new RegExp(`(\\d{1,2})(?:st|nd|rd|th)? ${MON}`), (m) => setDate(monthDay(today, MONTHS.indexOf(m[2]!.slice(0, 3).toLowerCase()) + 1, Number(m[1])), m[0]))
  if (result.time && !result.due_date) setDate(today, '')

  // !priority, #tags, @project.
  take(/!(urgent|high|medium|med|low|p[1-4]|[1-4])/, (m) => {
    result.priority = PRIORITIES[m[1]!.toLowerCase()]!
    match('priority', m[0])
  })
  while (take(/#([\p{L}\p{N}_/-]+)/u, (m) => {
    if (!result.tag_names.some((t) => t.toLowerCase() === m[1]!.toLowerCase())) result.tag_names.push(m[1]!)
    match('tag', m[0])
  }));
  take(/@([\p{L}\p{N}_-]+)/u, (m) => {
    result.project = m[1]!.replace(/[-_]/g, ' ')
    match('project', m[0])
  })

  result.title = text.replace(/\s+/g, ' ').trim()
  result.matches = result.matches.filter((m) => m.text)
  return result
}

/** Finds a project by the @word: exact name first, then a prefix ("@learn" → "Learn Rails"). */
export function matchProject<T extends { name: string }>(word: string | null, projects: T[]) {
  if (!word) return undefined
  const q = word.toLowerCase()
  return projects.find((p) => p.name.toLowerCase() === q) ?? projects.find((p) => p.name.toLowerCase().startsWith(q))
}
