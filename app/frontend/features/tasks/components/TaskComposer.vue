<script setup lang="ts">
import { computed, nextTick, onMounted, reactive, ref } from 'vue'
import { Sparkles } from '@lucide/vue'
import { Button } from '@/components/ui/button'
import type { Priority, TaskInput } from '@/api/tasks'
import { useProjects, useTaskMutations } from '@/composables/useTasks'
import { useToday } from '@/composables/useToday'
import { localDateTime } from '@/lib/dates'
import { matchProject, parseQuickAdd } from '@/lib/quickAdd'
import { textToDoc } from '@/lib/richtext'
import DuePicker from './DuePicker.vue'
import PriorityMenu from './PriorityMenu.vue'
import ProjectMenu from './ProjectMenu.vue'
import RepeatMenu from './RepeatMenu.vue'

/** The "add a task" form used inline in lists and in the quick-add dialog (shortcut `c`). */
const props = withDefaults(defineProps<{ defaults?: TaskInput; keepOpen?: boolean; hideProject?: boolean }>(), {
  defaults: () => ({}),
  keepOpen: true,
})
const emit = defineEmits<{ close: []; created: [] }>()

const { create } = useTaskMutations()
const { data: projects } = useProjects()
const { today } = useToday()
const titleInput = ref<HTMLInputElement>()

const blank = () => ({
  title: '',
  description: '',
  due_date: props.defaults.due_date ?? null,
  time: null as string | null,
  priority: (props.defaults.priority ?? 'none') as Priority,
  project_id: props.defaults.project_id ?? null,
  section_id: props.defaults.section_id ?? null,
  recurrence_rule: null as string | null,
})
const form = reactive(blank())

// Natural-language bits typed into the title ("tomorrow 6pm #home !high @errands every week").
const parsed = computed(() => parseQuickAdd(form.title, today.value))
const parsedProject = computed(() => matchProject(parsed.value.project, projects.value ?? []))

onMounted(() => titleInput.value?.focus())

async function submit() {
  const p = parsed.value
  const title = (p.title || form.title).trim()
  if (!title) return
  const dueDate = p.due_date ?? form.due_date
  const time = p.time ?? form.time
  const projectId = parsedProject.value ? parsedProject.value.id : form.project_id

  // Clear right away so typing the next task during the save isn't wiped when it finishes.
  const description = form.description
  form.title = ''
  form.description = ''
  try {
    await create.mutateAsync({
      ...props.defaults,
      title,
      description: textToDoc(description),
      priority: p.priority ?? form.priority,
      due_date: dueDate,
      due_at: dueDate && time ? localDateTime(dueDate, time) : null,
      project_id: projectId,
      section_id: parsedProject.value ? null : form.section_id,
      recurrence_rule: p.recurrence_rule ?? form.recurrence_rule,
      ...(p.tag_names.length ? { tag_names: p.tag_names } : {}),
    })
  } catch {
    if (!form.title) Object.assign(form, { title, description })
    return
  }
  emit('created')
  if (!props.keepOpen) return emit('close')

  await nextTick()
  titleInput.value?.focus()
}
</script>

<template>
  <form
    class="rounded-lg border bg-card shadow-xs focus-within:border-ring/60"
    @submit.prevent="submit"
    @keydown.esc.stop.prevent="emit('close')"
  >
    <div class="px-3 pt-2.5">
      <input
        ref="titleInput"
        v-model="form.title"
        class="w-full bg-transparent font-medium outline-none placeholder:text-muted-foreground/70"
        placeholder="Task name — try “Call mom tomorrow 6pm #family !high”"
        aria-label="Task name"
        maxlength="500"
      >
      <div v-if="parsed.matches.length" class="mt-1.5 flex flex-wrap items-center gap-1" aria-live="polite">
        <Sparkles class="size-3 text-primary" />
        <span v-for="(m, i) in parsed.matches" :key="i" class="rounded bg-primary/10 px-1.5 py-0.5 text-[11px] text-primary">
          {{ m.kind === 'project' ? (parsedProject ? `@${parsedProject.name}` : `${m.text} (no such project)`) : m.text }}
        </span>
      </div>
      <input
        v-model="form.description"
        class="mt-1 w-full bg-transparent text-xs outline-none placeholder:text-muted-foreground/70"
        placeholder="Description"
        aria-label="Description"
      >
    </div>
    <div class="flex flex-wrap items-center gap-1.5 px-3 py-2">
      <DuePicker :date="form.due_date" :time="form.time" @change="({ date, time }) => { form.due_date = date; form.time = time }" />
      <PriorityMenu v-model="form.priority" />
      <RepeatMenu v-model="form.recurrence_rule" :due-date="form.due_date" />
    </div>
    <div class="flex items-center gap-2 border-t px-3 py-2">
      <ProjectMenu
        v-if="!hideProject"
        :project-id="form.project_id"
        :section-id="form.section_id"
        @change="(v) => Object.assign(form, v)"
      />
      <div class="ml-auto flex gap-2">
        <Button type="button" variant="ghost" size="sm" @click="emit('close')">Cancel</Button>
        <Button type="submit" size="sm" :disabled="!form.title.trim()">Add task</Button>
      </div>
    </div>
  </form>
</template>
