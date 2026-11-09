<script setup lang="ts">
import { computed } from 'vue'
import { AlignLeft, CalendarDays, GripVertical, Hash, Inbox, ListChecks, MoreHorizontal, Pencil, Repeat, Trash2 } from '@lucide/vue'
import {
  DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuSeparator, DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import type { Task } from '@/api/tasks'
import { useProjects, useTaskMutations } from '@/composables/useTasks'
import { useToday } from '@/composables/useToday'
import { colorClasses } from '@/lib/colors'
import { relativeDay, timeOfDay } from '@/lib/dates'
import { recurrenceLabel } from '@/lib/recurrence'
import { useTaskPanel } from '@/stores/taskPanel'
import TaskCheckbox from './TaskCheckbox.vue'

const props = withDefaults(defineProps<{ task: Task; showProject?: boolean; showDue?: boolean; draggable?: boolean }>(), {
  showProject: true,
  showDue: true,
})

const panel = useTaskPanel()
const { today, timeZone } = useToday()
const { data: projects } = useProjects()
const { setDone, destroy } = useTaskMutations()

const done = computed(() => props.task.status === 'done')
const project = computed(() => projects.value?.find((p) => p.id === props.task.project_id))
const section = computed(() => project.value?.sections.find((s) => s.id === props.task.section_id))

const due = computed(() => {
  const { due_date, due_at } = props.task
  if (!due_date) return null
  const label = relativeDay(due_date, today.value)
  const time = due_at ? timeOfDay(due_at, timeZone.value) : null
  return { text: time ? `${label} ${time}` : label }
})
const dueTone = computed(() => {
  if (done.value) return 'text-muted-foreground'
  if (props.task.overdue) return 'text-red-500'
  if (props.task.due_date === today.value) return 'text-green-600 dark:text-green-500'
  return 'text-muted-foreground'
})
const hasDescription = computed(() => !!props.task.description?.content?.length)
</script>

<template>
  <div
    class="group/row relative flex items-start gap-2.5 border-b border-border/60 py-2.5 pl-1 pr-1"
    :class="done && 'opacity-60'"
    role="button"
    tabindex="0"
    @click="panel.openTask(task.id)"
    @keydown.enter.self="panel.openTask(task.id)"
  >
    <GripVertical
      v-if="draggable"
      class="absolute -left-5 top-3 size-4 cursor-grab text-muted-foreground/60 opacity-0 group-hover/row:opacity-100"
      aria-hidden="true"
    />
    <TaskCheckbox class="mt-px" :checked="done" :priority="task.priority" @toggle="setDone.mutate({ task, done: !done })" />

    <div class="min-w-0 flex-1">
      <p class="leading-snug" :class="done && 'text-muted-foreground line-through decoration-muted-foreground/50'">{{ task.title }}</p>
      <div class="mt-1 flex flex-wrap items-center gap-x-3 gap-y-1 text-xs empty:hidden">
        <span v-if="showDue && due" class="inline-flex items-center gap-1" :class="dueTone">
          <CalendarDays class="size-3" />{{ due.text }}
        </span>
        <Repeat v-if="task.recurrence_rule" class="size-3 text-muted-foreground" :aria-label="recurrenceLabel(task.recurrence_rule) ?? ''" />
        <span v-if="task.subtask_count" class="inline-flex items-center gap-1 text-muted-foreground">
          <ListChecks class="size-3" />{{ task.subtask_done_count }}/{{ task.subtask_count }}
        </span>
        <AlignLeft v-if="hasDescription" class="size-3 text-muted-foreground" aria-label="Has description" />
        <span v-for="tag in task.tags" :key="tag.id" class="inline-flex items-center text-muted-foreground" :class="tag.color && colorClasses(tag.color).text">
          <Hash class="size-3" />{{ tag.name }}
        </span>
      </div>
    </div>

    <span v-if="showProject" class="mt-0.5 hidden max-w-40 shrink-0 items-center gap-1.5 truncate text-xs text-muted-foreground sm:inline-flex">
      <template v-if="project">
        <span class="truncate">{{ project.name }}<template v-if="section"> / {{ section.name }}</template></span>
        <span class="size-2 shrink-0 rounded-full" :class="colorClasses(project.color).dot" />
      </template>
      <template v-else><span>Inbox</span><Inbox class="size-3" /></template>
    </span>

    <DropdownMenu>
      <DropdownMenuTrigger as-child>
        <button
          type="button"
          class="rounded p-0.5 text-muted-foreground opacity-0 hover:bg-accent focus-visible:opacity-100 group-hover/row:opacity-100 data-[state=open]:opacity-100"
          aria-label="Task actions"
          @click.stop
        >
          <MoreHorizontal class="size-4" />
        </button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" @click.stop>
        <DropdownMenuItem @select="panel.openTask(task.id)"><Pencil /> Open</DropdownMenuItem>
        <DropdownMenuSeparator />
        <DropdownMenuItem variant="destructive" @select="destroy.mutate(task)"><Trash2 /> Delete</DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  </div>
</template>
