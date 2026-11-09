<script setup lang="ts">
import { computed } from 'vue'
import { ArrowRight, BookOpen, CheckCheck, Flame, LineChart, Lock, LockOpen } from '@lucide/vue'
import { useTaskList } from '@/composables/useTasks'
import { useTrackers } from '@/composables/useTrackers'
import { useNotesList } from '@/composables/useNotes'
import { useQuery } from '@tanstack/vue-query'
import { studyApi } from '@/api/study'
import { isScheduled } from '@/lib/trackers'
import CheckInControl from '@/features/tracker/components/CheckInControl.vue'
import { useJournalDates, useVault } from '@/features/journal/useJournal'
import { journalSession } from '@/features/journal/session'
import { useToday } from '@/composables/useToday'
import { longDay } from '@/lib/dates'
import InlineAddTask from '@/features/tasks/components/InlineAddTask.vue'
import TaskList from '@/features/tasks/components/TaskList.vue'

const { timeZone, today, now } = useToday()

const greeting = computed(() => {
  const hour = Number(new Intl.DateTimeFormat('en-US', { hour: 'numeric', hourCycle: 'h23', timeZone: timeZone.value }).format(now.value))
  if (hour < 5) return 'Good night'
  if (hour < 12) return 'Good morning'
  if (hour < 18) return 'Good afternoon'
  return 'Good evening'
})

const { data: tasks, isPending } = useTaskList({ view: 'today' })
const open = computed(() => (tasks.value ?? []).filter((t) => t.status !== 'done'))
const doneToday = computed(() => (tasks.value ?? []).filter((t) => t.status === 'done').length)
const overdue = computed(() => open.value.filter((t) => t.overdue).length)

const { data: trackers } = useTrackers()
const dueTrackers = computed(() => (trackers.value ?? []).filter((t) => isScheduled(t, today.value)))
const { data: vault } = useVault()
const { data: journalDates } = useJournalDates()
// Only dates are visible without unlocking, so this card never shows entry content (PRD §4.7).
const journalCard = computed(() => {
  if (vault.value === null) return { title: 'Your private journal', body: 'Set it up in a minute: it’s encrypted on this device before it’s saved.', cta: 'Set up', to: { name: 'journal' } }
  const wroteToday = journalDates.value?.dates.some((d) => d.entry_date === today.value)
  const streak = journalDates.value?.streak ?? 0
  const body = `${wroteToday ? 'You’ve written today.' : 'Nothing written yet today.'}${streak > 1 ? ` ${streak}-day streak.` : ''}`
  return wroteToday
    ? { title: 'Today’s journal', body, cta: 'Open journal', to: { name: 'journal' } }
    : { title: 'Today’s journal', body, cta: journalSession.state.unlocked ? 'Write' : 'Unlock & write', to: { name: 'journal-new' } }
})
const { data: notes } = useNotesList()
const { data: due } = useQuery({ queryKey: ['flashcards', 'due'], queryFn: studyApi.due, staleTime: 60_000 })
const recentNotes = computed(() => [...(notes.value ?? [])].sort((a, b) => Date.parse(b.updated_at) - Date.parse(a.updated_at)).slice(0, 4))
</script>

<template>
  <div class="mx-auto max-w-3xl px-6 pb-16 pt-10 md:px-10">
    <p class="text-sm text-muted-foreground">{{ longDay(today) }}</p>
    <h1 class="mt-1 text-3xl font-semibold tracking-tight">{{ greeting }}</h1>

    <section class="mt-8">
      <div class="mb-1 flex items-baseline gap-3 border-b pb-2">
        <h2 class="font-medium">Today's tasks</h2>
        <span class="text-xs text-muted-foreground">
          {{ open.length }} to do<template v-if="overdue"> · <span class="text-red-500">{{ overdue }} overdue</span></template>
          <template v-if="doneToday"> · {{ doneToday }} done</template>
        </span>
        <RouterLink :to="{ name: 'tasks-today' }" class="ml-auto inline-flex items-center gap-1 text-xs text-muted-foreground hover:text-foreground">
          Open <ArrowRight class="size-3" />
        </RouterLink>
      </div>
      <div v-if="isPending" class="space-y-3 py-2"><div v-for="i in 3" :key="i" class="h-9 animate-pulse rounded-md bg-muted/60" /></div>
      <template v-else>
        <TaskList :tasks="open" />
        <p v-if="!open.length && doneToday" class="flex items-center gap-2 py-3 text-muted-foreground">
          <CheckCheck class="size-4 text-green-500" /> All done for today. Nice work.
        </p>
        <InlineAddTask :defaults="{ due_date: today }" />
      </template>
    </section>

    <section class="mt-8 overflow-hidden rounded-xl border bg-card">
      <div class="flex items-center gap-3 p-5">
        <div class="flex size-9 items-center justify-center rounded-lg bg-primary/10 text-primary">
          <component :is="journalSession.state.unlocked ? LockOpen : Lock" class="size-4" />
        </div>
        <div class="min-w-0 flex-1">
          <h2 class="font-medium">{{ journalCard.title }}</h2>
          <p class="text-muted-foreground">{{ journalCard.body }}</p>
        </div>
        <RouterLink :to="journalCard.to" class="rounded-md border px-3 py-1.5 text-sm font-medium hover:bg-accent">{{ journalCard.cta }}</RouterLink>
      </div>
    </section>

    <div class="mt-4 grid gap-4 sm:grid-cols-2">
      <section class="rounded-xl border bg-card p-5">
        <div class="flex items-center gap-2 font-medium">
          <LineChart class="size-4 text-muted-foreground" /> Habits
          <RouterLink :to="{ name: 'tracker' }" class="ml-auto text-xs font-normal text-muted-foreground hover:text-foreground">All</RouterLink>
        </div>
        <p v-if="!dueTrackers.length" class="mt-3 text-muted-foreground">
          No habits to check in. <RouterLink :to="{ name: 'tracker' }" class="text-primary hover:underline">Add one</RouterLink>
        </p>
        <ul v-else class="mt-3 space-y-2.5">
          <li v-for="tracker in dueTrackers" :key="tracker.id" class="flex items-center gap-2.5">
            <span class="text-base">{{ tracker.icon ?? '✅' }}</span>
            <RouterLink :to="{ name: 'tracker-detail', params: { id: tracker.id } }" class="min-w-0 flex-1 truncate hover:underline">{{ tracker.name }}</RouterLink>
            <span v-if="tracker.stats.current_streak" class="inline-flex items-center gap-0.5 text-xs tabular-nums text-muted-foreground">
              <Flame class="size-3 text-orange-500" />{{ tracker.stats.current_streak }}
            </span>
            <CheckInControl :tracker="tracker" :date="today" />
          </li>
        </ul>
      </section>
      <section class="rounded-xl border bg-card p-5">
        <div class="flex items-center gap-2 font-medium">
          <BookOpen class="size-4 text-muted-foreground" /> Learning
          <RouterLink :to="{ name: 'learn' }" class="ml-auto text-xs font-normal text-muted-foreground hover:text-foreground">All</RouterLink>
        </div>
        <RouterLink v-if="due?.due_count" :to="{ name: 'review' }" class="mt-3 flex items-center justify-between rounded-lg bg-primary/10 px-3 py-2 text-sm text-primary hover:bg-primary/15">
          {{ due.due_count }} flashcard{{ due.due_count === 1 ? '' : 's' }} due <span>Review →</span>
        </RouterLink>
        <p v-if="!recentNotes.length" class="mt-3 text-muted-foreground">No notes yet.</p>
        <ul v-else class="mt-2">
          <li v-for="note in recentNotes" :key="note.id">
            <RouterLink :to="{ name: 'note', params: { id: note.id } }" class="-mx-2 flex items-center gap-2 rounded-md px-2 py-1.5 hover:bg-accent">
              <span class="text-muted-foreground">{{ note.icon ?? '📄' }}</span><span class="truncate">{{ note.title }}</span>
            </RouterLink>
          </li>
        </ul>
      </section>
    </div>
  </div>
</template>
