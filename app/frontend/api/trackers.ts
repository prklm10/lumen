import { api } from './client'

export type TrackerKind = 'boolean' | 'count' | 'duration' | 'numeric' | 'scale'
export type Frequency = { type: 'daily' } | { type: 'weekdays'; days: number[] } | { type: 'weekly'; times: number }

export interface TrackerEntry {
  logged_on: string
  value: number
  note: string | null
}

export interface TrackerStats {
  current_streak: number
  longest_streak: number
  completion_rate: number | null
  periods_met: number
  periods_total: number
}

export interface Tracker {
  id: number
  name: string
  icon: string | null
  color: string
  kind: TrackerKind
  unit: string | null
  target: number | null
  frequency: Frequency
  position: number
  archived: boolean
  archived_at: string | null
  system_key: string | null
  stats: TrackerStats
  /** The last 14 days. */
  recent_entries: TrackerEntry[]
}

export interface TrackerInput {
  name?: string
  icon?: string | null
  color?: string
  kind?: TrackerKind
  unit?: string | null
  target?: number | null
  frequency?: Frequency
  position?: number
  archived?: boolean
}

export const trackersApi = {
  list: (includeArchived = false) =>
    api<{ trackers: Tracker[] }>(`/trackers${includeArchived ? '?include_archived=true' : ''}`).then((r) => r.trackers),
  get: (id: number) => api<Tracker>(`/trackers/${id}`),
  create: (tracker: TrackerInput) => api<Tracker>('/trackers', { method: 'POST', body: { tracker } }),
  update: (id: number, tracker: TrackerInput) => api<Tracker>(`/trackers/${id}`, { method: 'PATCH', body: { tracker } }),
  destroy: (id: number) => api<void>(`/trackers/${id}`, { method: 'DELETE' }),
  entries: (id: number, from: string, to: string) =>
    api<{ entries: TrackerEntry[] }>(`/trackers/${id}/entries?from=${from}&to=${to}`).then((r) => r.entries),
  checkIn: (id: number, date: string, entry: { value: number; note?: string | null }) =>
    api<TrackerEntry>(`/trackers/${id}/entries/${date}`, { method: 'PUT', body: { entry } }),
  clear: (id: number, date: string) => api<void>(`/trackers/${id}/entries/${date}`, { method: 'DELETE' }),
}
