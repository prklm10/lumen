<script setup lang="ts">
import { computed, ref } from 'vue'
import { useRouter } from 'vue-router'
import { Flame, Lock, NotebookPen, PenLine } from '@lucide/vue'
import { Button } from '@/components/ui/button'
import { useToday } from '@/composables/useToday'
import { addDays, longDay, relativeDay } from '@/lib/dates'
import EmptyState from '@/features/tasks/components/EmptyState.vue'
import JournalGate from './JournalGate.vue'
import MonthCalendar from './components/MonthCalendar.vue'
import JournalExtras from './components/JournalExtras.vue'
import { excerpt, moodEmoji, useDecryptedEntries, useJournalDates } from './useJournal'
import { journalSession } from './session'

/** Calendar + timeline of a month's entries, decrypted in the browser (JRN-3). */
const router = useRouter()
const { today } = useToday()
const month = ref(today.value.slice(0, 7))
const selected = ref<string | null>(null)
const searching = ref(false)

const { data: dates } = useJournalDates()
const marked = computed(() => new Map((dates.value?.dates ?? []).map((d) => [d.entry_date, d.count])))

const monthStart = computed(() => `${month.value}-01`)
const monthEnd = computed(() => {
  const [y, m] = month.value.split('-').map(Number)
  return new Date(Date.UTC(y!, m!, 0)).toISOString().slice(0, 10)
})
const { entries, isPending } = useDecryptedEntries(monthStart, monthEnd)
const shown = computed(() => (selected.value ? entries.value.filter((e) => e.entry_date === selected.value) : entries.value))

function write(date = today.value) {
  router.push({ name: 'journal-new', query: date === today.value ? {} : { date } })
}

function select(date: string) {
  if (selected.value === date) return (selected.value = null)
  selected.value = date
  if (!marked.value.get(date)) write(date)
}

const monthLabel = computed(() => new Intl.DateTimeFormat('en-US', { month: 'long', timeZone: 'UTC' }).format(new Date(`${monthStart.value}T12:00:00Z`)))
</script>

<template>
  <JournalGate>
    <div class="mx-auto max-w-5xl px-6 pb-24 pt-8 md:px-10">
      <header class="mb-8 flex items-center gap-3">
        <div class="flex-1">
          <h1 class="text-2xl font-semibold tracking-tight">Journal</h1>
          <p class="text-sm text-muted-foreground">End-to-end encrypted. Only you can read it.</p>
        </div>
        <Button variant="ghost" size="sm" title="Lock (⌘⇧L)" @click="journalSession.lock()"><Lock /> Lock</Button>
        <Button size="sm" @click="write()"><PenLine /> Write today</Button>
      </header>

      <div class="grid gap-8 md:grid-cols-[260px_1fr]">
        <aside class="space-y-5">
          <MonthCalendar v-model:month="month" :today="today" :marked="marked" :selected="selected" @select="select" />
          <dl v-if="dates" class="grid grid-cols-2 gap-2">
            <div class="rounded-lg border bg-card px-3 py-2">
              <dt class="text-xs text-muted-foreground">Writing streak</dt>
              <dd class="mt-0.5 flex items-center gap-1 font-semibold tabular-nums">
                <Flame class="size-4" :class="dates.streak ? 'text-orange-500' : 'text-muted-foreground'" /> {{ dates.streak }} {{ dates.streak === 1 ? 'day' : 'days' }}
              </dd>
            </div>
            <div class="rounded-lg border bg-card px-3 py-2">
              <dt class="text-xs text-muted-foreground">Entries</dt>
              <dd class="mt-0.5 font-semibold tabular-nums">{{ dates.total }}</dd>
            </div>
          </dl>
        </aside>

        <section>
          <JournalExtras class="mb-6" :today="today" :dates="(dates?.dates ?? []).map((d) => d.entry_date)" @searching="searching = $event" />
          <template v-if="!searching">
          <div class="mb-3 flex items-baseline justify-between border-b pb-2">
            <h2 class="font-medium">{{ selected ? longDay(selected) : monthLabel }}</h2>
            <button v-if="selected" type="button" class="text-xs text-muted-foreground hover:text-foreground" @click="selected = null">Show whole month</button>
          </div>
          <div v-if="isPending" class="space-y-3"><div v-for="i in 3" :key="i" class="h-24 animate-pulse rounded-xl bg-muted/60" /></div>
          <EmptyState v-else-if="!shown.length" :icon="NotebookPen" :title="selected ? 'Nothing written this day' : `No entries in ${monthLabel}`" body="Write a few lines; it gets easier.">
            <Button class="mt-5" size="sm" @click="write(selected ?? today)"><PenLine /> Write {{ selected && selected !== today ? 'for this day' : 'today' }}</Button>
          </EmptyState>
          <ul v-else class="space-y-3">
            <li v-for="entry in shown" :key="entry.id">
              <RouterLink :to="{ name: 'journal-entry', params: { id: entry.id } }" class="block rounded-xl border bg-card p-4 transition-colors hover:border-primary/40 hover:bg-accent/30">
                <div class="flex items-center gap-2 text-xs text-muted-foreground">
                  <span>{{ relativeDay(entry.entry_date, today) }}</span>
                  <span v-if="relativeDay(entry.entry_date, today) !== longDay(entry.entry_date)">· {{ longDay(entry.entry_date) }}</span>
                  <span v-if="entry.payload?.mood" class="ml-auto text-base">{{ moodEmoji(entry.payload.mood) }}</span>
                </div>
                <template v-if="entry.payload">
                  <p class="mt-1.5 font-medium">{{ entry.payload.title || 'Untitled' }}</p>
                  <p v-if="entry.payload.prompt" class="mt-0.5 text-xs italic text-muted-foreground">{{ entry.payload.prompt }}</p>
                  <p class="mt-1 line-clamp-2 text-sm text-muted-foreground">{{ excerpt(entry.payload) || 'Empty entry' }}</p>
                  <div v-if="entry.payload.tags.length" class="mt-2 flex flex-wrap gap-1">
                    <span v-for="tag in entry.payload.tags" :key="tag" class="rounded bg-secondary px-1.5 py-0.5 text-xs text-muted-foreground">#{{ tag }}</span>
                  </div>
                </template>
                <p v-else class="mt-1.5 text-sm text-destructive">{{ entry.error }}</p>
              </RouterLink>
            </li>
          </ul>
          <p class="mt-6 text-center text-xs text-muted-foreground">
            <button type="button" class="hover:text-foreground" @click="month = addDays(monthStart, -1).slice(0, 7)">← Earlier</button>
          </p>
          </template>
        </section>
      </div>
    </div>
  </JournalGate>
</template>
