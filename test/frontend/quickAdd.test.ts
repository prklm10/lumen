import { describe, expect, it } from 'vitest'
import { matchProject, parseQuickAdd } from '@/lib/quickAdd'
import { recurrenceLabel } from '@/lib/recurrence'

const today = '2026-11-02' // a Monday

describe('parseQuickAdd', () => {
  it('reads the PRD example', () => {
    const r = parseQuickAdd('Call mom tomorrow 6pm #family !high @errands', today)
    expect(r).toMatchObject({ title: 'Call mom', due_date: '2026-11-03', time: '18:00', priority: 'high', tag_names: ['family'], project: 'errands' })
  })

  it('understands weekdays, next week, relative and absolute dates', () => {
    expect(parseQuickAdd('Report friday', today).due_date).toBe('2026-11-06')
    expect(parseQuickAdd('Report monday', today).due_date).toBe('2026-11-09') // today is Monday → next one
    expect(parseQuickAdd('Plan next week', today).due_date).toBe('2026-11-09')
    expect(parseQuickAdd('Renew in 3 days', today).due_date).toBe('2026-11-05')
    expect(parseQuickAdd('Taxes jan 15', today).due_date).toBe('2027-01-15')
    expect(parseQuickAdd('Party 24th dec', today).due_date).toBe('2026-12-24')
    expect(parseQuickAdd('Ship 2026-12-01', today).due_date).toBe('2026-12-01')
  })

  it('reads times, and a time alone means today', () => {
    expect(parseQuickAdd('Standup at 9:30am', today)).toMatchObject({ title: 'Standup', time: '09:30', due_date: today })
    expect(parseQuickAdd('Gym 18:00 tomorrow', today)).toMatchObject({ time: '18:00', due_date: '2026-11-03' })
    expect(parseQuickAdd('Read tonight', today)).toMatchObject({ due_date: today, time: '20:00' })
    expect(parseQuickAdd('Pay 12am', today).time).toBe('00:00')
  })

  it('reads repeat rules', () => {
    expect(parseQuickAdd('Water plants every monday', today)).toMatchObject({ title: 'Water plants', recurrence_rule: 'FREQ=WEEKLY;INTERVAL=1;BYDAY=MO', due_date: '2026-11-09' })
    expect(parseQuickAdd('Stretch every day', today).recurrence_rule).toBe('FREQ=DAILY;INTERVAL=1')
    expect(parseQuickAdd('Review every 2 weeks', today).recurrence_rule).toBe('FREQ=WEEKLY;INTERVAL=2')
    expect(parseQuickAdd('Standup every weekday 9am', today)).toMatchObject({ recurrence_rule: 'FREQ=WEEKLY;INTERVAL=1;BYDAY=MO,TU,WE,TH,FR', time: '09:00' })
    expect(parseQuickAdd('Rent monthly', today).recurrence_rule).toBe('FREQ=MONTHLY;INTERVAL=1')
  })

  it('collects several tags and leaves ordinary words alone', () => {
    const r = parseQuickAdd('Fix #bug in the #api today !p1', today)
    expect(r).toMatchObject({ title: 'Fix in the', tag_names: ['bug', 'api'], priority: 'urgent' })
    expect(parseQuickAdd('Read Monday Night Football recap', today).title).toBe('Read Night Football recap')
    expect(parseQuickAdd('email bob@example.com', today).title).toBe('email bob@example.com')
  })

  it('leaves plain text alone', () => {
    expect(parseQuickAdd('Buy milk', today)).toMatchObject({ title: 'Buy milk', due_date: null, matches: [] })
  })
})

describe('helpers', () => {
  it('matches projects by name or prefix', () => {
    const projects = [{ name: 'Learn Rails' }, { name: 'Home' }]
    expect(matchProject('home', projects)?.name).toBe('Home')
    expect(matchProject('learn', projects)?.name).toBe('Learn Rails')
    expect(matchProject('work', projects)).toBeUndefined()
  })

  it('labels repeat rules', () => {
    expect(recurrenceLabel('FREQ=WEEKLY;INTERVAL=1;BYDAY=MO,TU,WE,TH,FR')).toBe('Every weekday')
    expect(recurrenceLabel('FREQ=WEEKLY;INTERVAL=2;BYDAY=MO')).toBe('Every 2 weeks on Mon')
    expect(recurrenceLabel('FREQ=DAILY;INTERVAL=1')).toBe('Every day')
  })
})
