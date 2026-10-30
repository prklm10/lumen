import { api } from './client'

export interface User {
  id: number
  email_address: string
  time_zone: string
  settings: Record<string, unknown>
}

export const authApi = {
  current: () => api<{ user: User | null; needs_setup: boolean }>('/session'),
  login: (email_address: string, password: string) =>
    api<{ user: User }>('/session', { method: 'POST', body: { email_address, password } }),
  logout: () => api<void>('/session', { method: 'DELETE' }),
  setup: (email_address: string, password: string, time_zone: string) =>
    api<{ user: User }>('/setup', { method: 'POST', body: { email_address, password, time_zone } }),
}
