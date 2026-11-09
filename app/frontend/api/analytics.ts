import { api } from './client'
import type { Frequency, TrackerKind } from './trackers'

export type RangeKey = '7d' | '30d' | '90d' | '1y'
export interface AnalyticsRange { key: RangeKey; from: string; to: string; days: number; unit: 'day' | 'week' }

export interface TaskAnalytics {
  range: AnalyticsRange
  kpis: {
    completed: number; created: number; previous_completed: number; completion_rate: number | null
    on_time_rate: number | null; avg_hours_to_complete: number | null; overdue_open: number
  }
  series: { date: string; created: number; completed: number }[]
  by_project: { project_id: number | null; name: string; color: string | null; completed: number }[]
  by_priority: { priority: string; completed: number; avg_hours: number | null }[]
  hours: [number, number, number][]
  backlog: { date: string; overdue: number }[]
}

export interface TrackerAnalytics {
  range: AnalyticsRange
  trackers: {
    id: number; name: string; icon: string | null; color: string; kind: TrackerKind; unit: string | null; target: number | null
    frequency: Frequency; consistency: number | null; periods_met: number; periods_total: number
    current_streak: number; longest_streak: number; weekdays: (number | null)[]
    values: { date: string; value: number | null; avg7: number | null }[] | null
  }[]
}

export interface LearningAnalytics {
  range: AnalyticsRange
  totals: { notes: number; links: number; tags: number; notes_created: number; journal_entries: number; journal_days: number; journal_streak: number }
  series: { date: string; notes_created: number; notes_edited: number; journal_days: number }[]
}

export const analyticsApi = {
  tasks: (range: RangeKey) => api<TaskAnalytics>(`/analytics/tasks?range=${range}`),
  trackers: (range: RangeKey) => api<TrackerAnalytics>(`/analytics/trackers?range=${range}`),
  learning: (range: RangeKey) => api<LearningAnalytics>(`/analytics/learning?range=${range}`),
}
