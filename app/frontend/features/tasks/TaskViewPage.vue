<script setup lang="ts">
import { computed } from 'vue'
import { useLocalStorage } from '@vueuse/core'
import { CalendarRange, Inbox, PartyPopper, Sun } from '@lucide/vue'
import type { Task, TaskView } from '@/api/tasks'
import { useTaskList } from '@/composables/useTasks'
import { useToday } from '@/composables/useToday'
import { addDays, longDay, relativeDay, weekdayName } from '@/lib/dates'
import EmptyState from './components/EmptyState.vue'
import InlineAddTask from './components/InlineAddTask.vue'
import PageHeader from './components/PageHeader.vue'
import TaskList from './components/TaskList.vue'

/** Inbox, Today and Upcoming (TSK-4). */
const props = defineProps<{ view: Extract<TaskView, 'inbox' | 'today' | 'upcoming'> }>()

const { today } = useToday()
const showDone = useLocalStorage('lumen-inbox-show-done', false)
const params = computed(() => ({ view: props.view, include_done: props.view === 'inbox' && showDone.value }))
const { data: tasks, isPending } = useTaskList(params)

const list = computed<Task[]>(() => tasks.value ?? [])
const open = computed(() => list.value.filter((t) => t.status !== 'done'))

const todayGroups = computed(() => ({
  overdue: open.value.filter((t) => t.overdue),
  today: open.value.filter((t) => !t.overdue),
  done: list.value.filter((t) => t.status === 'done'),
}))

const upcomingDays = computed(() =>
  Array.from({ length: 7 }, (_, i) => {
    const date = addDays(today.value, i)
    return { date, tasks: open.value.filter((t) => t.due_date === date) }
  }),
)

const header = computed(() => {
  if (props.view === 'today') return { title: 'Today', subtitle: longDay(today.value), icon: Sun }
  if (props.view === 'upcoming') return { title: 'Upcoming', subtitle: 'The next seven days', icon: CalendarRange }
  return { title: 'Inbox', subtitle: 'Tasks without a project', icon: Inbox }
})
</script>

<template>
  <div class="mx-auto max-w-3xl px-6 pb-24 pt-8 md:px-10">
    <PageHeader :title="header.title" :subtitle="header.subtitle">
      <template v-if="view === 'inbox'" #actions>
        <label class="mt-1.5 flex cursor-pointer select-none items-center gap-2 text-xs text-muted-foreground">
          <input v-model="showDone" type="checkbox" class="accent-primary">
          Show completed
        </label>
      </template>
    </PageHeader>

    <div v-if="isPending" class="space-y-3" aria-busy="true">
      <div v-for="i in 4" :key="i" class="h-10 animate-pulse rounded-md bg-muted/60" />
    </div>

    <!-- Today -->
    <template v-else-if="view === 'today'">
      <section v-if="todayGroups.overdue.length" class="mb-6">
        <h2 class="mb-1 border-b pb-1.5 text-sm font-semibold text-red-500">Overdue</h2>
        <TaskList :tasks="todayGroups.overdue" />
      </section>
      <section>
        <h2 v-if="todayGroups.overdue.length" class="mb-1 border-b pb-1.5 text-sm font-semibold">
          Today <span class="font-normal text-muted-foreground">· {{ weekdayName(today) }}</span>
        </h2>
        <TaskList :tasks="todayGroups.today" />
        <InlineAddTask :defaults="{ due_date: today }" />
      </section>
      <EmptyState
        v-if="!open.length && !todayGroups.done.length"
        :icon="PartyPopper"
        title="Nothing due today"
        body="Enjoy the calm, or plan ahead in Upcoming."
      />
      <section v-if="todayGroups.done.length" class="mt-8">
        <h2 class="mb-1 border-b pb-1.5 text-sm font-semibold text-muted-foreground">Completed today · {{ todayGroups.done.length }}</h2>
        <TaskList :tasks="todayGroups.done" />
      </section>
    </template>

    <!-- Upcoming -->
    <template v-else-if="view === 'upcoming'">
      <section v-for="day in upcomingDays" :key="day.date" class="mb-6">
        <h2 class="mb-1 flex items-baseline gap-2 border-b pb-1.5 text-sm font-semibold">
          {{ relativeDay(day.date, today) }}
          <span class="font-normal text-muted-foreground">{{ longDay(day.date).split(', ')[1] }}</span>
        </h2>
        <TaskList :tasks="day.tasks" :show-due="false" />
        <InlineAddTask :defaults="{ due_date: day.date }" />
      </section>
    </template>

    <!-- Inbox -->
    <template v-else>
      <TaskList :tasks="list" reorderable :show-project="false" />
      <InlineAddTask :defaults="{ project_id: null }" hide-project />
      <EmptyState v-if="!list.length" :icon="Inbox" title="Inbox zero" body="New tasks without a project land here. Press C to add one from anywhere." />
    </template>
  </div>
</template>
