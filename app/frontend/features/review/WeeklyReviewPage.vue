<script setup lang="ts">
import { computed, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useQuery } from '@tanstack/vue-query'
import { BookOpen, Brain, CheckCircle2, ChevronLeft, ChevronRight, LineChart, NotebookPen, PenLine } from '@lucide/vue'
import { Button } from '@/components/ui/button'
import { api } from '@/api/client'
import { useToday } from '@/composables/useToday'
import { addDays, formatMinutes, weekdayName } from '@/lib/dates'
import { isoWeekday } from '@/lib/trackers'

/**
 * Weekly Review (PRD §4.8): the week across modules, regenerated from live data, plus a
 * nudge to write a reflection. Only the reflection is saved, as an encrypted journal entry.
 */
interface Review {
  week: { from: string; to: string }
  tasks: { completed: { id: number; title: string; project: string | null; completed_on: string }[]; created: number; still_overdue: number }
  habits: { id: number; name: string; icon: string | null; met: number; logged: number }[]
  notes: { id: number; title: string; created: boolean }[]
  study: { minutes: number; by_topic: { topic: string; minutes: number }[] }
  flashcards_reviewed: number
  journal_days: string[]
}

const router = useRouter()
const { today } = useToday()
const weekStart = ref(addDays(today.value, -(isoWeekday(today.value) - 1)))
const { data } = useQuery({ queryKey: computed(() => ['weekly_review', weekStart.value]), queryFn: () => api<Review>(`/weekly_review?week=${weekStart.value}`) })

const label = computed(() => {
  if (!data.value) return ''
  const f = (d: string) => new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', timeZone: 'UTC' }).format(new Date(`${d}T12:00:00Z`))
  return `${f(data.value.week.from)} – ${f(data.value.week.to)}`
})
const isCurrent = computed(() => weekStart.value === addDays(today.value, -(isoWeekday(today.value) - 1)))
const byDay = computed(() => {
  const groups = new Map<string, Review['tasks']['completed']>()
  for (const t of data.value?.tasks.completed ?? []) groups.set(t.completed_on, [...(groups.get(t.completed_on) ?? []), t])
  return [...groups]
})

function reflect() {
  router.push({ name: 'journal-new', query: { title: `Week of ${label.value}`, prompt: 'What went well this week, what didn’t, and what will I change next week?' } })
}
</script>

<template>
  <div class="mx-auto max-w-3xl px-6 pb-24 pt-8 md:px-10">
    <header class="mb-8 flex flex-wrap items-center gap-3">
      <div class="flex-1">
        <h1 class="text-2xl font-semibold tracking-tight">Weekly review</h1>
        <p class="text-sm text-muted-foreground">{{ label }}{{ isCurrent ? ' · this week' : '' }}</p>
      </div>
      <div class="flex items-center gap-1">
        <Button variant="ghost" size="icon-sm" aria-label="Previous week" @click="weekStart = addDays(weekStart, -7)"><ChevronLeft /></Button>
        <Button variant="ghost" size="icon-sm" aria-label="Next week" :disabled="isCurrent" @click="weekStart = addDays(weekStart, 7)"><ChevronRight /></Button>
      </div>
      <Button size="sm" @click="reflect"><PenLine /> Write a reflection</Button>
    </header>

    <div v-if="!data" class="space-y-4"><div v-for="i in 3" :key="i" class="h-28 animate-pulse rounded-xl bg-muted/60" /></div>
    <div v-else class="space-y-5">
      <section class="rounded-xl border bg-card p-5">
        <h2 class="mb-3 flex items-center gap-2 font-medium"><CheckCircle2 class="size-4 text-muted-foreground" /> {{ data.tasks.completed.length }} tasks done</h2>
        <p class="mb-3 text-sm text-muted-foreground">{{ data.tasks.created }} created this week · {{ data.tasks.still_overdue }} overdue right now</p>
        <div v-for="[day, tasks] in byDay" :key="day" class="mb-3">
          <p class="text-xs font-medium text-muted-foreground">{{ weekdayName(day) }}</p>
          <ul class="mt-1 space-y-0.5 text-sm">
            <li v-for="t in tasks" :key="t.id" class="flex gap-2"><span class="text-muted-foreground">✓</span> {{ t.title }} <span v-if="t.project" class="text-muted-foreground">· {{ t.project }}</span></li>
          </ul>
        </div>
        <p v-if="!data.tasks.completed.length" class="text-sm text-muted-foreground">Nothing completed this week.</p>
      </section>

      <div class="grid gap-5 sm:grid-cols-2">
        <section class="rounded-xl border bg-card p-5">
          <h2 class="mb-3 flex items-center gap-2 font-medium"><LineChart class="size-4 text-muted-foreground" /> Habits</h2>
          <p v-if="!data.habits.length" class="text-sm text-muted-foreground">No trackers.</p>
          <ul v-else class="space-y-1.5 text-sm">
            <li v-for="h in data.habits" :key="h.id" class="flex items-center gap-2">
              <span>{{ h.icon ?? '✅' }}</span><span class="flex-1 truncate">{{ h.name }}</span>
              <span class="tabular-nums text-muted-foreground">{{ h.met }}/7 days</span>
            </li>
          </ul>
        </section>
        <section class="rounded-xl border bg-card p-5">
          <h2 class="mb-3 flex items-center gap-2 font-medium"><BookOpen class="size-4 text-muted-foreground" /> Learning</h2>
          <ul class="space-y-1.5 text-sm">
            <li>{{ formatMinutes(data.study.minutes) }} studied<span v-if="data.study.by_topic.length" class="text-muted-foreground"> · {{ data.study.by_topic.map((t) => `${t.topic} ${formatMinutes(t.minutes)}`).join(', ') }}</span></li>
            <li class="flex items-center gap-1.5"><Brain class="size-3.5 text-muted-foreground" /> {{ data.flashcards_reviewed }} flashcards reviewed</li>
            <li v-for="n in data.notes.slice(0, 6)" :key="n.id">
              <RouterLink :to="{ name: 'note', params: { id: n.id } }" class="hover:underline">{{ n.title }}</RouterLink>
              <span class="text-xs text-muted-foreground"> · {{ n.created ? 'new' : 'edited' }}</span>
            </li>
          </ul>
        </section>
      </div>

      <section class="rounded-xl border bg-card p-5">
        <h2 class="mb-2 flex items-center gap-2 font-medium"><NotebookPen class="size-4 text-muted-foreground" /> Journal</h2>
        <p class="text-sm text-muted-foreground">You wrote on {{ data.journal_days.length }} of 7 days. Your reflection is saved as an encrypted journal entry; this summary isn’t copied into it.</p>
      </section>
    </div>
  </div>
</template>
