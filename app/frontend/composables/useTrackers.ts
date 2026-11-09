import { computed, toValue, type MaybeRefOrGetter } from 'vue'
import { useMutation, useQuery, useQueryClient } from '@tanstack/vue-query'
import { toast } from 'vue-sonner'
import { trackersApi, type Tracker, type TrackerEntry, type TrackerInput } from '@/api/trackers'
import { errorMessage } from './useTasks'

export const trackerKeys = {
  all: ['trackers'] as const,
  list: (archived: boolean) => ['trackers', 'list', archived] as const,
  detail: (id: number) => ['trackers', 'detail', id] as const,
  entries: (id: number, from: string, to: string) => ['trackers', 'entries', id, from, to] as const,
}

export function useTrackers(includeArchived: MaybeRefOrGetter<boolean> = false) {
  return useQuery({
    queryKey: computed(() => trackerKeys.list(toValue(includeArchived))),
    queryFn: () => trackersApi.list(toValue(includeArchived)),
  })
}

export function useTracker(id: MaybeRefOrGetter<number>) {
  return useQuery({ queryKey: computed(() => trackerKeys.detail(toValue(id))), queryFn: () => trackersApi.get(toValue(id)) })
}

export function useTrackerEntries(id: MaybeRefOrGetter<number>, from: MaybeRefOrGetter<string>, to: MaybeRefOrGetter<string>) {
  return useQuery({
    queryKey: computed(() => trackerKeys.entries(toValue(id), toValue(from), toValue(to))),
    queryFn: () => trackersApi.entries(toValue(id), toValue(from), toValue(to)),
  })
}

/** Writes a day's value into every cached copy of the tracker, so taps feel instant. */
function patchEntry(client: ReturnType<typeof useQueryClient>, trackerId: number, date: string, entry: TrackerEntry | null) {
  const apply = (list: TrackerEntry[]) => {
    const rest = list.filter((e) => e.logged_on !== date)
    return entry ? [...rest, entry].sort((a, b) => a.logged_on.localeCompare(b.logged_on)) : rest
  }
  const patchTracker = (t: Tracker) => (t.id === trackerId ? { ...t, recent_entries: apply(t.recent_entries) } : t)
  client.setQueriesData<Tracker[]>({ queryKey: ['trackers', 'list'] }, (old) => old?.map(patchTracker))
  client.setQueriesData<Tracker>({ queryKey: trackerKeys.detail(trackerId) }, (old) => (old ? patchTracker(old) : old))
  client.setQueriesData<TrackerEntry[]>({ queryKey: ['trackers', 'entries', trackerId] }, (old) => (old ? apply(old) : old))
}

export function useTrackerMutations() {
  const client = useQueryClient()
  const refresh = () => client.invalidateQueries({ queryKey: trackerKeys.all })
  const onError = (error: unknown) => {
    toast.error(errorMessage(error))
    refresh()
  }

  return {
    create: useMutation({ mutationFn: (input: TrackerInput) => trackersApi.create(input), onSuccess: refresh, onError }),
    update: useMutation({
      mutationFn: ({ id, input }: { id: number; input: TrackerInput }) => trackersApi.update(id, input),
      onSuccess: refresh,
      onError,
    }),
    destroy: useMutation({ mutationFn: (id: number) => trackersApi.destroy(id), onSuccess: refresh, onError }),
    /** Set (or clear, with value null) one day's check-in. */
    checkIn: useMutation({
      mutationFn: async ({ tracker, date, value, note }: { tracker: Tracker; date: string; value: number | null; note?: string | null }) => {
        if (value === null) await trackersApi.clear(tracker.id, date)
        else await trackersApi.checkIn(tracker.id, date, { value, note })
      },
      onMutate: ({ tracker, date, value, note }) =>
        patchEntry(client, tracker.id, date, value === null ? null : { logged_on: date, value, note: note ?? null }),
      onSuccess: refresh, // streaks and rates are computed server-side
      onError,
    }),
  }
}
