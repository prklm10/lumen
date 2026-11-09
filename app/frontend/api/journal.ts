import { api } from './client'
import type { VaultRecord } from '@/lib/crypto/journal'

export interface StoredEntry {
  id: string
  entry_date: string
  version: number
  ciphertext: string
  iv: string
  created_at: string
  updated_at: string
}

export interface JournalDates {
  dates: { entry_date: string; count: number }[]
  total: number
  streak: number
}

export const journalApi = {
  /** null until the journal has been set up. */
  vault: () => api<{ vault: VaultRecord | null }>('/journal/vault').then((r) => r.vault),
  createVault: (vault: VaultRecord) => api<VaultRecord>('/journal/vault', { method: 'POST', body: { vault } }),
  updateVault: (password: string, vault: Partial<VaultRecord>) =>
    api<VaultRecord>('/journal/vault', { method: 'PATCH', body: { password, vault } }),
  entries: (from: string, to: string) => api<{ entries: StoredEntry[] }>(`/journal/entries?from=${from}&to=${to}`).then((r) => r.entries),
  entry: (id: string) => api<StoredEntry>(`/journal/entries/${id}`),
  dates: () => api<JournalDates>('/journal/entries/dates'),
  create: (entry: { id: string; entry_date: string; ciphertext: string; iv: string }) =>
    api<StoredEntry>('/journal/entries', { method: 'POST', body: { entry } }),
  update: (id: string, entry: { version: number; ciphertext: string; iv: string; entry_date?: string }) =>
    api<StoredEntry>(`/journal/entries/${id}`, { method: 'PUT', body: { entry } }),
  destroy: (id: string) => api<void>(`/journal/entries/${id}`, { method: 'DELETE' }),
}
