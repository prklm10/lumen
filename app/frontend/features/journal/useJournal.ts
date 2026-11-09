import { computed, ref, toValue, watch, type MaybeRefOrGetter } from 'vue'
import { useQuery, useQueryClient } from '@tanstack/vue-query'
import { journalApi, type StoredEntry } from '@/api/journal'
import { DecryptError, decryptEntry, type EntryPayload } from '@/lib/crypto/journal'
import { docToText } from '@/lib/richtext'
import { addDays } from '@/lib/dates'
import { journalSession } from './session'

export const journalKeys = {
  vault: ['journal', 'vault'] as const,
  dates: ['journal', 'dates'] as const,
  entries: (from: string, to: string) => ['journal', 'entries', from, to] as const,
  entry: (id: string) => ['journal', 'entry', id] as const,
}

export function useVault() {
  return useQuery({ queryKey: journalKeys.vault, queryFn: journalApi.vault, staleTime: Infinity })
}

export function useJournalDates() {
  return useQuery({ queryKey: journalKeys.dates, queryFn: journalApi.dates })
}

export function useInvalidateJournal() {
  const client = useQueryClient()
  return () => client.invalidateQueries({ queryKey: ['journal'], predicate: (q) => q.queryKey[1] !== 'vault' })
}

export interface DecryptedEntry {
  id: string
  entry_date: string
  version: number
  payload: EntryPayload | null
  error: string | null
  updated_at: string
}

/**
 * Ciphertext from the server (cached by vue-query), decrypted in the browser while unlocked.
 * Decrypted copies live only in this component's state and are dropped when the journal locks.
 */
export function useDecryptedEntries(from: MaybeRefOrGetter<string>, to: MaybeRefOrGetter<string>) {
  const query = useQuery({
    queryKey: computed(() => journalKeys.entries(toValue(from), toValue(to))),
    queryFn: () => journalApi.entries(toValue(from), toValue(to)),
    enabled: () => journalSession.state.unlocked,
  })
  const entries = ref<DecryptedEntry[]>([])
  const decrypting = ref(false)

  watch([query.data, () => journalSession.state.unlocked], async ([data, unlocked]) => {
    if (!unlocked || !data) {
      entries.value = []
      return
    }
    decrypting.value = true
    const key = journalSession.key()
    entries.value = await Promise.all((data as StoredEntry[]).map(async (e) => {
      try {
        return { id: e.id, entry_date: e.entry_date, version: e.version, payload: await decryptEntry(key, e), error: null, updated_at: e.updated_at }
      } catch (err) {
        return { id: e.id, entry_date: e.entry_date, version: e.version, payload: null, error: err instanceof DecryptError ? err.message : 'Couldn’t read this entry', updated_at: e.updated_at }
      }
    }))
    decrypting.value = false
  }, { immediate: true })

  return { entries, isPending: computed(() => query.isPending.value || decrypting.value), refetch: query.refetch }
}

/**
 * Every entry, fetched in 400-day chunks (the API's range limit) and decrypted here. Used for
 * search, "On this day" and export: the server can't search ciphertext, so the browser does.
 */
export async function fetchAllStored(firstDate: string, today: string) {
  const stored: StoredEntry[] = []
  for (let to = today; to >= firstDate; to = addDays(to, -400)) {
    const from = addDays(to, -399) < firstDate ? firstDate : addDays(to, -399)
    stored.push(...(await journalApi.entries(from, to)))
  }
  return stored
}

export async function loadAllEntries(firstDate: string, today: string) {
  const key = journalSession.key()
  const stored = await fetchAllStored(firstDate, today)
  const out: { entry: StoredEntry; payload: EntryPayload }[] = []
  for (const entry of stored) {
    try {
      out.push({ entry, payload: await decryptEntry(key, entry) })
    } catch {
      // Unreadable entries are skipped here; the timeline shows them with an error.
    }
  }
  return out.sort((a, b) => b.entry.entry_date.localeCompare(a.entry.entry_date))
}

export const moods = [
  { value: 1, emoji: '😞', label: 'Awful' },
  { value: 2, emoji: '🙁', label: 'Bad' },
  { value: 3, emoji: '😐', label: 'Okay' },
  { value: 4, emoji: '🙂', label: 'Good' },
  { value: 5, emoji: '😄', label: 'Great' },
] as const

export const prompts = [
  'What am I grateful for today?',
  'What went well, and why?',
  'What’s on my mind right now?',
  'What did I learn today?',
  'What would make tomorrow great?',
  'What drained me, and what gave me energy?',
]

export function moodEmoji(mood: number | null | undefined) {
  return moods.find((m) => m.value === mood)?.emoji ?? null
}

export function excerpt(payload: EntryPayload, length = 160) {
  const text = docToText(payload.doc).replace(/\s+/g, ' ').trim()
  return text.length > length ? `${text.slice(0, length).trimEnd()}…` : text
}

export function countWords(text: string) {
  return text.trim() ? text.trim().split(/\s+/).length : 0
}
