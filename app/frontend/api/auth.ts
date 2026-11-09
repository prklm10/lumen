import { api } from './client'

export interface User {
  id: number
  email_address: string
  time_zone: string
  settings: UserSettings
}

export interface UserSettings {
  /** Copy each journal entry's mood to the (unencrypted) Mood tracker. */
  journal_mood_mirror?: boolean
}

export const authApi = {
  current: () => api<{ user: User | null; needs_setup: boolean }>('/session'),
  login: (email_address: string, password: string) =>
    api<{ user: User }>('/session', { method: 'POST', body: { email_address, password } }),
  logout: () => api<void>('/session', { method: 'DELETE' }),
  updateMe: (user: { time_zone?: string; settings?: Partial<UserSettings> }) =>
    api<{ user: User }>('/me', { method: 'PATCH', body: { user } }),
  setup: (email_address: string, password: string, time_zone: string) =>
    api<{ user: User }>('/setup', { method: 'POST', body: { email_address, password, time_zone } }),
}
