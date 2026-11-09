<script setup lang="ts">
import { computed, ref, watchEffect } from 'vue'
import { useRouter } from 'vue-router'
import { toast } from 'vue-sonner'
import { Archive, ArchiveRestore, ChevronLeft, MoreHorizontal, Pencil, SearchX, Trash2 } from '@lucide/vue'
import {
  DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuSeparator, DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import {
  AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent, AlertDialogDescription, AlertDialogFooter,
  AlertDialogHeader, AlertDialogTitle,
} from '@/components/ui/alert-dialog'
import { Button } from '@/components/ui/button'
import { useTracker, useTrackerEntries, useTrackerMutations } from '@/composables/useTrackers'
import { useToday } from '@/composables/useToday'
import { addDays, relativeDay } from '@/lib/dates'
import { formatValue, frequencyLabel, isScheduled, targetLabel } from '@/lib/trackers'
import EmptyState from '@/features/tasks/components/EmptyState.vue'
import CheckInControl from './components/CheckInControl.vue'
import TrackerDialog from './components/TrackerDialog.vue'
import WeekStrip from './components/WeekStrip.vue'
import YearHeatmap from './components/YearHeatmap.vue'

const props = defineProps<{ id: string }>()
const trackerId = computed(() => Number(props.id))
const router = useRouter()
const { today } = useToday()

const { data: tracker, error } = useTracker(trackerId)
const from = computed(() => addDays(today.value, -370))
const { data: entries } = useTrackerEntries(trackerId, from, today)
const mutations = useTrackerMutations()
const editing = ref(false)
const confirmDelete = ref(false)

watchEffect(() => {
  if (tracker.value) document.title = `${tracker.value.name} · Lumen`
})

const history = computed(() => [...(entries.value ?? [])].reverse().slice(0, 30))
const stats = computed(() => {
  const s = tracker.value?.stats
  if (!s) return []
  const unit = tracker.value?.frequency.type === 'weekly' ? 'weeks' : 'days'
  return [
    { label: 'Current streak', value: `${s.current_streak} ${unit}` },
    { label: 'Longest streak', value: `${s.longest_streak} ${unit}` },
    { label: 'Last 30 days', value: s.completion_rate === null ? '—' : `${Math.round(s.completion_rate * 100)}%` },
    { label: 'Check-ins (1y)', value: String((entries.value ?? []).filter((e) => e.value > 0).length) },
  ]
})

function toggleArchive() {
  if (!tracker.value) return
  const archived = !tracker.value.archived
  mutations.update.mutate({ id: tracker.value.id, input: { archived } }, { onSuccess: () => toast(archived ? 'Tracker archived' : 'Tracker restored') })
}

async function remove() {
  await mutations.destroy.mutateAsync(trackerId.value)
  toast('Tracker deleted')
  router.push({ name: 'tracker' })
}
</script>

<template>
  <div class="mx-auto max-w-4xl px-6 pb-24 pt-6 md:px-10">
    <RouterLink :to="{ name: 'tracker' }" class="mb-4 inline-flex items-center gap-1 text-xs text-muted-foreground hover:text-foreground">
      <ChevronLeft class="size-3.5" /> All trackers
    </RouterLink>

    <EmptyState v-if="error" :icon="SearchX" title="Tracker not found" />

    <template v-else-if="tracker">
      <header class="mb-6 flex items-start gap-4">
        <span class="flex size-12 shrink-0 items-center justify-center rounded-xl bg-muted text-2xl">{{ tracker.icon ?? '✅' }}</span>
        <div class="min-w-0 flex-1">
          <h1 class="truncate text-2xl font-semibold tracking-tight">{{ tracker.name }}</h1>
          <p class="text-sm text-muted-foreground">
            {{ frequencyLabel(tracker.frequency) }}<template v-if="targetLabel(tracker)"> · {{ targetLabel(tracker) }}</template>
            <template v-if="tracker.archived"> · archived</template>
          </p>
        </div>
        <CheckInControl v-if="!tracker.archived && isScheduled(tracker, today)" :tracker="tracker" :date="today" />
        <DropdownMenu>
          <DropdownMenuTrigger as-child>
            <Button variant="ghost" size="icon-sm" aria-label="Tracker actions"><MoreHorizontal /></Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end" class="w-44">
            <DropdownMenuItem @select="editing = true"><Pencil /> Edit</DropdownMenuItem>
            <DropdownMenuItem @select="toggleArchive">
              <component :is="tracker.archived ? ArchiveRestore : Archive" /> {{ tracker.archived ? 'Restore' : 'Archive' }}
            </DropdownMenuItem>
            <DropdownMenuSeparator />
            <DropdownMenuItem variant="destructive" @select="confirmDelete = true"><Trash2 /> Delete</DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </header>

      <dl class="mb-6 grid grid-cols-2 gap-3 sm:grid-cols-4">
        <div v-for="s in stats" :key="s.label" class="rounded-xl border bg-card px-4 py-3">
          <dt class="text-xs text-muted-foreground">{{ s.label }}</dt>
          <dd class="mt-1 text-xl font-semibold tabular-nums">{{ s.value }}</dd>
        </div>
      </dl>

      <section class="mb-6 rounded-xl border bg-card p-5">
        <YearHeatmap :tracker="tracker" :entries="entries ?? []" :today="today" />
      </section>

      <section class="grid gap-6 md:grid-cols-[auto_1fr]">
        <div>
          <h2 class="mb-2 text-sm font-medium">This week</h2>
          <WeekStrip :tracker="tracker" :today="today" />
        </div>
        <div>
          <h2 class="mb-2 text-sm font-medium">History</h2>
          <p v-if="!history.length" class="text-sm text-muted-foreground">No check-ins yet.</p>
          <ul v-else class="divide-y rounded-xl border bg-card">
            <li v-for="e in history" :key="e.logged_on" class="flex items-baseline gap-3 px-4 py-2 text-sm">
              <span class="w-24 shrink-0 text-muted-foreground">{{ relativeDay(e.logged_on, today) }}</span>
              <span class="font-medium tabular-nums">{{ formatValue(tracker, e.value) }}</span>
              <span v-if="e.note" class="truncate text-muted-foreground">{{ e.note }}</span>
            </li>
          </ul>
        </div>
      </section>

      <TrackerDialog v-model:open="editing" :tracker="tracker" />
      <AlertDialog v-model:open="confirmDelete">
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Delete “{{ tracker.name }}” and its history?</AlertDialogTitle>
            <AlertDialogDescription>This removes every check-in. To keep the history but hide the tracker, archive it instead.</AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancel</AlertDialogCancel>
            <AlertDialogAction class="bg-destructive text-white hover:bg-destructive/90" @click="remove">Delete</AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </template>
  </div>
</template>
