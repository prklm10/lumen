import { describe, expect, it } from 'vitest'
import { addDays, daysBetween, formatMinutes, relativeDay, timeInputValue, todayIn } from '@/lib/dates'
import { docToText, textToDoc } from '@/lib/richtext'

describe('dates', () => {
  it('computes today in the user zone, not the browser zone', () => {
    const lateUtc = new Date('2026-11-01T20:00:00Z') // already Nov 2 in Kolkata
    expect(todayIn('Asia/Kolkata', lateUtc)).toBe('2026-11-02')
    expect(todayIn('America/New_York', lateUtc)).toBe('2026-11-01')
  })

  it('adds days across month and DST boundaries', () => {
    expect(addDays('2026-10-31', 1)).toBe('2026-11-01')
    expect(addDays('2026-03-08', 1)).toBe('2026-03-09')
    expect(daysBetween('2026-12-30', '2027-01-02')).toBe(3)
  })

  it('labels days relative to today', () => {
    const today = '2026-11-02' // a Monday
    expect(relativeDay('2026-11-02', today)).toBe('Today')
    expect(relativeDay('2026-11-03', today)).toBe('Tomorrow')
    expect(relativeDay('2026-11-01', today)).toBe('Yesterday')
    expect(relativeDay('2026-11-06', today)).toBe('Friday')
    expect(relativeDay('2026-11-20', today)).toBe('Nov 20')
    expect(relativeDay('2027-01-05', today)).toBe('Jan 5, 2027')
  })

  it('formats times and durations', () => {
    expect(timeInputValue('2026-11-02T12:30:00Z', 'Asia/Kolkata')).toBe('18:00')
    expect(formatMinutes(45)).toBe('45m')
    expect(formatMinutes(90)).toBe('1h 30m')
    expect(formatMinutes(120)).toBe('2h')
  })
})

describe('richtext', () => {
  it('round-trips plain text through a TipTap doc', () => {
    const doc = textToDoc('First line\n\nThird line')
    expect(doc?.content).toHaveLength(3)
    expect(docToText(doc)).toBe('First line\n\nThird line')
  })

  it('treats blank text as no description', () => {
    expect(textToDoc('  \n ')).toBeNull()
    expect(docToText(null)).toBe('')
  })
})
