<script setup lang="ts">
import { computed, ref } from 'vue'
import { CalendarDays, ListChecks, Repeat } from '@lucide/vue'
import type { Task, TaskStatus } from '@/api/tasks'
import { useTaskMutations } from '@/composables/useTasks'
import { useToday } from '@/composables/useToday'
import { relativeDay } from '@/lib/dates'
import { priorityStyles } from '@/lib/colors'
import { useTaskPanel } from '@/stores/taskPanel'
import InlineAddTask from './InlineAddTask.vue'

/** Kanban board for a project (TSK-5): drag cards between status columns or within one. */
const props = defineProps<{ tasks: Task[]; projectId: number }>()
const { update, reorder } = useTaskMutations()
const panel = useTaskPanel()
const { today } = useToday()

const columns: { status: TaskStatus; label: string }[] = [
  { status: 'todo', label: 'To do' },
  { status: 'in_progress', label: 'In progress' },
  { status: 'done', label: 'Done' },
]
const byStatus = computed(() =>
  Object.fromEntries(columns.map((c) => [c.status, props.tasks.filter((t) => t.status === c.status).sort((a, b) => a.position - b.position)])) as Record<TaskStatus, Task[]>)

const dragging = ref<Task | null>(null)
const target = ref<{ status: TaskStatus; before: number | null } | null>(null)

function onDragOver(event: DragEvent, status: TaskStatus, before: number | null) {
  if (!dragging.value) return
  event.preventDefault()
  event.stopPropagation()
  target.value = { status, before }
}

function onDrop(event: DragEvent) {
  const task = dragging.value
  const t = target.value
  dragging.value = null
  target.value = null
  if (!task || !t) return
  event.preventDefault()

  const list = byStatus.value[t.status].filter((x) => x.id !== task.id)
  const index = t.before === null ? list.length : list.findIndex((x) => x.id === t.before)
  const prev = list[index - 1]?.position
  const next = list[index]?.position
  const position = prev === undefined && next === undefined ? 1 : prev === undefined ? next! - 1 : next === undefined ? prev + 1 : (prev + next) / 2

  if (t.status !== task.status) update.mutate({ id: task.id, input: { status: t.status } })
  reorder.mutate([{ id: task.id, position }])
}
</script>

<template>
  <div class="grid gap-4 md:grid-cols-3" @dragend="dragging = null; target = null">
    <section
      v-for="col in columns"
      :key="col.status"
      class="flex min-h-48 flex-col rounded-xl bg-muted/40 p-2"
      :class="target?.status === col.status && target.before === null && 'ring-2 ring-primary/40'"
      @dragover="onDragOver($event, col.status, null)"
      @drop="onDrop"
    >
      <h3 class="flex items-center gap-2 px-2 py-1.5 text-sm font-medium">
        {{ col.label }} <span class="text-xs font-normal text-muted-foreground">{{ byStatus[col.status].length }}</span>
      </h3>
      <div class="flex flex-1 flex-col gap-2">
        <article
          v-for="task in byStatus[col.status]"
          :key="task.id"
          draggable="true"
          class="relative cursor-grab rounded-lg border bg-card p-3 text-sm shadow-xs transition hover:border-primary/40 active:cursor-grabbing"
          :class="dragging?.id === task.id && 'opacity-40'"
          role="button"
          tabindex="0"
          @dragstart="(e) => { dragging = task; e.dataTransfer!.effectAllowed = 'move' }"
          @dragover="onDragOver($event, col.status, task.id)"
          @click="panel.openTask(task.id)"
          @keydown.enter="panel.openTask(task.id)"
        >
          <span v-if="target?.before === task.id" class="pointer-events-none absolute inset-x-1 -top-1.5 h-0.5 rounded bg-primary" />
          <p :class="task.status === 'done' && 'text-muted-foreground line-through'">{{ task.title }}</p>
          <div class="mt-2 flex flex-wrap items-center gap-2 text-xs text-muted-foreground empty:hidden">
            <span v-if="task.priority !== 'none'" class="font-medium" :class="priorityStyles[task.priority].text">{{ priorityStyles[task.priority].label }}</span>
            <span v-if="task.due_date" class="inline-flex items-center gap-1" :class="task.overdue && 'text-red-500'"><CalendarDays class="size-3" />{{ relativeDay(task.due_date, today) }}</span>
            <Repeat v-if="task.recurrence_rule" class="size-3" />
            <span v-if="task.subtask_count" class="inline-flex items-center gap-1"><ListChecks class="size-3" />{{ task.subtask_done_count }}/{{ task.subtask_count }}</span>
            <span v-for="tag in task.tags" :key="tag.id">#{{ tag.name }}</span>
          </div>
        </article>
      </div>
      <InlineAddTask v-if="col.status !== 'done'" class="mt-1" :defaults="{ project_id: projectId, status: col.status }" hide-project />
    </section>
  </div>
</template>
