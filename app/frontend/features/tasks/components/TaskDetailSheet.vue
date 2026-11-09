<script setup lang="ts">
import { computed, nextTick, ref, watch } from 'vue'
import { useTextareaAutosize } from '@vueuse/core'
import { CircleDot, Clock, Folder, Flag, Hash, Loader2, Plus, Repeat, Trash2, CalendarDays } from '@lucide/vue'
import { Sheet, SheetContent, SheetDescription, SheetTitle } from '@/components/ui/sheet'
import { Button } from '@/components/ui/button'
import type { Task, TaskInput, TaskStatus } from '@/api/tasks'
import { useTask, useTaskMutations } from '@/composables/useTasks'
import { useToday } from '@/composables/useToday'
import { localDateTime, longDay, timeInputValue } from '@/lib/dates'
import { docToText, textToDoc } from '@/lib/richtext'
import { formatMinutes } from '@/lib/dates'
import { useTaskPanel } from '@/stores/taskPanel'
import DuePicker from './DuePicker.vue'
import PriorityMenu from './PriorityMenu.vue'
import ProjectMenu from './ProjectMenu.vue'
import RepeatMenu from './RepeatMenu.vue'
import TagInput from './TagInput.vue'
import TaskCheckbox from './TaskCheckbox.vue'

const panel = useTaskPanel()
const { timeZone } = useToday()
const open = computed({ get: () => panel.openTaskId !== null, set: (v) => !v && panel.closeTask() })
const { data: task, isPending } = useTask(() => panel.openTaskId)
const { update, setDone, destroy, create } = useTaskMutations()

const title = ref('')
const description = ref('')
const { textarea: titleArea } = useTextareaAutosize({ input: title })
const { textarea: descriptionArea } = useTextareaAutosize({ input: description })
const newSubtask = ref('')

watch(task, (t, old) => {
  if (!t || t.id === old?.id && document.activeElement && [titleArea.value, descriptionArea.value].includes(document.activeElement as HTMLTextAreaElement)) return
  title.value = t.title
  description.value = docToText(t.description)
}, { immediate: true })

const statuses: { value: TaskStatus; label: string }[] = [
  { value: 'todo', label: 'To do' },
  { value: 'in_progress', label: 'In progress' },
  { value: 'done', label: 'Done' },
  { value: 'cancelled', label: 'Cancelled' },
]

function save(input: TaskInput) {
  if (task.value) update.mutate({ id: task.value.id, input })
}

function saveTitle() {
  const value = title.value.replace(/\n/g, ' ').trim()
  if (!task.value) return
  if (!value) return (title.value = task.value.title)
  if (value !== task.value.title) save({ title: value })
}

function saveDescription() {
  if (task.value && description.value !== docToText(task.value.description)) save({ description: textToDoc(description.value) })
}

function saveDue({ date, time }: { date: string | null; time: string | null }) {
  save({ due_date: date, due_at: date && time ? localDateTime(date, time) : null })
}

function saveEstimate(event: Event) {
  const raw = (event.target as HTMLInputElement).value
  const minutes = raw ? Math.max(1, Math.round(Number(raw))) : null
  if (minutes !== task.value?.estimate_minutes) save({ estimate_minutes: minutes })
}

async function addSubtask() {
  const name = newSubtask.value.trim()
  if (!name || !task.value) return
  newSubtask.value = ''
  await create.mutateAsync({ title: name, parent_id: task.value.id })
}

function remove(t: Task) {
  destroy.mutate(t)
  if (t.id === task.value?.id) panel.closeTask()
}

const dueTime = computed(() => (task.value?.due_at ? timeInputValue(task.value.due_at, timeZone.value) : null))
const createdLabel = computed(() => task.value && longDay(task.value.created_at.slice(0, 10)))

async function openParent() {
  if (task.value?.parent_id) {
    panel.openTask(task.value.parent_id)
    await nextTick()
  }
}
</script>

<template>
  <Sheet v-model:open="open">
    <SheetContent class="w-full gap-0 overflow-y-auto p-0 sm:max-w-lg" @open-auto-focus.prevent>
      <SheetTitle class="sr-only">Task details</SheetTitle>
      <SheetDescription class="sr-only">Edit the task's title, schedule, priority, tags and subtasks.</SheetDescription>

      <div v-if="isPending || !task" class="flex flex-1 items-center justify-center text-muted-foreground">
        <Loader2 class="size-5 animate-spin" />
      </div>

      <template v-else>
        <div class="border-b px-6 pb-4 pt-5">
          <button v-if="task.parent_id" type="button" class="mb-2 text-xs text-muted-foreground hover:text-foreground" @click="openParent">
            ← Parent task
          </button>
          <div class="flex items-start gap-3 pr-6">
            <TaskCheckbox class="mt-1.5" :checked="task.status === 'done'" :priority="task.priority" @toggle="setDone.mutate({ task, done: task.status !== 'done' })" />
            <textarea
              ref="titleArea"
              v-model="title"
              rows="1"
              class="w-full resize-none bg-transparent text-lg font-semibold leading-snug outline-none"
              aria-label="Task title"
              maxlength="500"
              @keydown.enter.prevent="($event.target as HTMLTextAreaElement).blur()"
              @blur="saveTitle"
            />
          </div>
          <textarea
            ref="descriptionArea"
            v-model="description"
            rows="2"
            class="mt-2 w-full resize-none bg-transparent pl-[30px] text-sm leading-relaxed text-foreground/90 outline-none placeholder:text-muted-foreground/70"
            placeholder="Add a description…"
            aria-label="Description"
            @blur="saveDescription"
          />
        </div>

        <dl class="grid grid-cols-[7.5rem_1fr] items-center gap-x-2 gap-y-1.5 px-6 py-4 text-sm">
          <dt class="flex items-center gap-2 text-muted-foreground"><CircleDot class="size-4" />Status</dt>
          <dd>
            <select
              class="h-7 rounded-md border bg-transparent px-1.5 text-xs"
              :value="task.status"
              aria-label="Status"
              @change="save({ status: ($event.target as HTMLSelectElement).value as TaskStatus })"
            >
              <option v-for="s in statuses" :key="s.value" :value="s.value">{{ s.label }}</option>
            </select>
          </dd>

          <dt class="flex items-center gap-2 text-muted-foreground"><Folder class="size-4" />Project</dt>
          <dd>
            <ProjectMenu v-if="!task.parent_id" :project-id="task.project_id" :section-id="task.section_id" @change="save" />
            <span v-else class="text-xs text-muted-foreground">Same as parent task</span>
          </dd>

          <dt class="flex items-center gap-2 text-muted-foreground"><CalendarDays class="size-4" />Due</dt>
          <dd><DuePicker :date="task.due_date" :time="dueTime" @change="saveDue" /></dd>

          <dt class="flex items-center gap-2 text-muted-foreground"><Repeat class="size-4" />Repeat</dt>
          <dd><RepeatMenu :model-value="task.recurrence_rule" :due-date="task.due_date" @update:model-value="save({ recurrence_rule: $event })" /></dd>

          <dt class="flex items-center gap-2 text-muted-foreground"><Flag class="size-4" />Priority</dt>
          <dd><PriorityMenu :model-value="task.priority" @update:model-value="save({ priority: $event })" /></dd>

          <dt class="flex items-center gap-2 text-muted-foreground"><Clock class="size-4" />Estimate</dt>
          <dd class="flex items-center gap-2">
            <input
              type="number"
              min="1"
              max="10080"
              step="5"
              class="h-7 w-20 rounded-md border bg-transparent px-2 text-xs"
              placeholder="min"
              aria-label="Estimate in minutes"
              :value="task.estimate_minutes ?? ''"
              @change="saveEstimate"
            >
            <span v-if="task.estimate_minutes" class="text-xs text-muted-foreground">{{ formatMinutes(task.estimate_minutes) }}</span>
          </dd>

          <dt class="flex items-center gap-2 self-start pt-1.5 text-muted-foreground"><Hash class="size-4" />Tags</dt>
          <dd><TagInput :model-value="task.tags.map((t) => t.name)" @update:model-value="save({ tag_names: $event })" /></dd>
        </dl>

        <section v-if="!task.parent_id" class="border-t px-6 py-4">
          <h3 class="mb-2 flex items-center gap-2 text-xs font-medium uppercase tracking-wide text-muted-foreground">
            Subtasks
            <span v-if="task.subtasks?.length" class="normal-case tracking-normal">
              {{ task.subtasks.filter((s) => s.status === 'done').length }}/{{ task.subtasks.length }}
            </span>
          </h3>
          <ul>
            <li v-for="sub in task.subtasks" :key="sub.id" class="group flex items-center gap-2.5 rounded-md py-1.5">
              <TaskCheckbox size="sm" :checked="sub.status === 'done'" :priority="sub.priority" @toggle="setDone.mutate({ task: sub, done: sub.status !== 'done' })" />
              <button
                type="button"
                class="flex-1 truncate text-left"
                :class="sub.status === 'done' && 'text-muted-foreground line-through'"
                @click="panel.openTask(sub.id)"
              >
                {{ sub.title }}
              </button>
              <button type="button" class="text-muted-foreground opacity-0 hover:text-destructive group-hover:opacity-100" aria-label="Delete subtask" @click="remove(sub)">
                <Trash2 class="size-3.5" />
              </button>
            </li>
          </ul>
          <form class="mt-1 flex items-center gap-2.5" @submit.prevent="addSubtask">
            <Plus class="size-4 text-muted-foreground" />
            <input v-model="newSubtask" class="flex-1 bg-transparent py-1 outline-none placeholder:text-muted-foreground/70" placeholder="Add a subtask" aria-label="Add a subtask">
          </form>
        </section>

        <footer class="mt-auto flex items-center justify-between border-t px-6 py-3 text-xs text-muted-foreground">
          <span>Created {{ createdLabel }}</span>
          <Button variant="ghost" size="sm" class="text-destructive hover:text-destructive" @click="remove(task)">
            <Trash2 /> Delete
          </Button>
        </footer>
      </template>
    </SheetContent>
  </Sheet>
</template>
