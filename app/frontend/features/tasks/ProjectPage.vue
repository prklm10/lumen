<script setup lang="ts">
import { computed, nextTick, ref, watchEffect } from 'vue'
import { useRouter } from 'vue-router'
import { useLocalStorage } from '@vueuse/core'
import { Archive, ArchiveRestore, FolderOpen, KanbanSquare, List, MoreHorizontal, Pencil, Plus, Trash2 } from '@lucide/vue'
import { toast } from 'vue-sonner'
import {
  DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuSeparator, DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import {
  AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent, AlertDialogDescription, AlertDialogFooter,
  AlertDialogHeader, AlertDialogTitle,
} from '@/components/ui/alert-dialog'
import { Button } from '@/components/ui/button'
import { useQuery } from '@tanstack/vue-query'
import { ApiError } from '@/api/client'
import { projectsApi, type Section } from '@/api/tasks'
import { errorMessage, taskKeys, useProjectMutations, useTaskList } from '@/composables/useTasks'
import EmptyState from './components/EmptyState.vue'
import InlineAddTask from './components/InlineAddTask.vue'
import PageHeader from './components/PageHeader.vue'
import ProjectBadge from './components/ProjectBadge.vue'
import ProjectDialog from './components/ProjectDialog.vue'
import TaskList from './components/TaskList.vue'
import BoardView from './components/BoardView.vue'

const props = defineProps<{ id: string }>()
const projectId = computed(() => Number(props.id))
const router = useRouter()

// Fetched on its own (not from the sidebar list) so archived projects open too.
const { data: project, error } = useQuery({
  queryKey: computed(() => [...taskKeys.projects, projectId.value]),
  queryFn: () => projectsApi.get(projectId.value),
})
const showDone = useLocalStorage('lumen-project-show-done', false)
const layouts = useLocalStorage<Record<string, 'list' | 'board'>>('lumen-project-layouts', {})
const layout = computed({
  get: () => layouts.value[props.id] ?? 'list',
  set: (v) => (layouts.value = { ...layouts.value, [props.id]: v }),
})
// The board always shows a Done column, so it needs completed tasks too.
const { data: tasks, isPending } = useTaskList(() => ({ view: 'project', project_id: projectId.value, include_done: showDone.value || layout.value === 'board' }))
const mutations = useProjectMutations()

watchEffect(() => {
  if (project.value) document.title = `${project.value.name} · Lumen`
})

const editOpen = ref(false)
const confirmDelete = ref(false)
const renaming = ref<number | null>(null)
const renameValue = ref('')
const addingSection = ref(false)
const newSection = ref('')
const sectionInput = ref<HTMLInputElement>()

const unsectioned = computed(() => (tasks.value ?? []).filter((t) => t.section_id === null))
const sections = computed(() =>
  (project.value?.sections ?? []).map((section) => ({ section, tasks: (tasks.value ?? []).filter((t) => t.section_id === section.id) })),
)
const total = computed(() => (tasks.value ?? []).filter((t) => t.status !== 'done').length)

async function startAddSection() {
  addingSection.value = true
  await nextTick()
  sectionInput.value?.focus()
}

async function addSection() {
  const name = newSection.value.trim()
  if (!name) return (addingSection.value = false)
  await mutations.createSection.mutateAsync({ projectId: projectId.value, name })
  newSection.value = ''
  addingSection.value = false
}

function startRename(section: Section) {
  renaming.value = section.id
  renameValue.value = section.name
}

async function saveRename(section: Section) {
  const name = renameValue.value.trim()
  renaming.value = null
  if (name && name !== section.name) await mutations.updateSection.mutateAsync({ projectId: projectId.value, id: section.id, name })
}

function toggleArchive() {
  if (!project.value) return
  const archived = !project.value.archived
  mutations.update.mutate(
    { id: project.value.id, input: { archived } },
    { onSuccess: () => toast(archived ? 'Project archived' : 'Project restored') },
  )
}

async function deleteProject() {
  try {
    await mutations.destroy.mutateAsync(projectId.value)
    toast('Project deleted')
    router.push({ name: 'tasks-inbox' })
  } catch (e) {
    toast.error(e instanceof ApiError && e.code === 'project_not_empty' ? 'This project still has tasks. Move or delete them, or archive the project.' : errorMessage(e))
  }
}
</script>

<template>
  <div class="mx-auto px-6 pb-24 pt-8 md:px-10" :class="layout === 'board' ? 'max-w-6xl' : 'max-w-3xl'">
    <EmptyState v-if="error" :icon="FolderOpen" title="Project not found" body="It may have been deleted." />

    <template v-else-if="project">
      <PageHeader :title="project.name" :subtitle="`${total} open ${total === 1 ? 'task' : 'tasks'}${project.archived ? ' · archived' : ''}`">
        <template #icon><ProjectBadge class="mt-2" :project="project" size="lg" /></template>
        <template #actions>
          <div class="mt-0.5 inline-flex rounded-md border p-0.5" role="radiogroup" aria-label="Layout">
            <button
              v-for="o in [{ v: 'list', icon: List, l: 'List' }, { v: 'board', icon: KanbanSquare, l: 'Board' }] as const"
              :key="o.v"
              type="button"
              role="radio"
              :aria-checked="layout === o.v"
              :aria-label="o.l"
              :title="o.l"
              class="rounded p-1"
              :class="layout === o.v ? 'bg-accent text-foreground' : 'text-muted-foreground hover:text-foreground'"
              @click="layout = o.v"
            >
              <component :is="o.icon" class="size-4" />
            </button>
          </div>
          <label v-if="layout === 'list'" class="mt-1.5 flex cursor-pointer select-none items-center gap-2 text-xs text-muted-foreground">
            <input v-model="showDone" type="checkbox" class="accent-primary">
            Show completed
          </label>
          <DropdownMenu>
            <DropdownMenuTrigger as-child>
              <Button variant="ghost" size="icon-sm" aria-label="Project actions"><MoreHorizontal /></Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" class="w-44">
              <DropdownMenuItem @select="editOpen = true"><Pencil /> Edit project</DropdownMenuItem>
              <DropdownMenuItem @select="startAddSection"><Plus /> Add section</DropdownMenuItem>
              <DropdownMenuItem @select="toggleArchive">
                <component :is="project.archived ? ArchiveRestore : Archive" /> {{ project.archived ? 'Restore' : 'Archive' }}
              </DropdownMenuItem>
              <DropdownMenuSeparator />
              <DropdownMenuItem variant="destructive" @select="confirmDelete = true"><Trash2 /> Delete</DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </template>
      </PageHeader>

      <div v-if="isPending" class="space-y-3"><div v-for="i in 4" :key="i" class="h-10 animate-pulse rounded-md bg-muted/60" /></div>
      <BoardView v-else-if="layout === 'board'" :tasks="tasks ?? []" :project-id="project.id" />
      <template v-else>
        <TaskList :tasks="unsectioned" reorderable :section-id="null" :show-project="false" />
        <InlineAddTask v-if="!project.archived" :defaults="{ project_id: project.id, section_id: null }" hide-project />

        <section v-for="{ section, tasks: sectionTasks } in sections" :key="section.id" class="mt-8">
          <div class="group mb-1 flex items-center gap-2 border-b pb-1.5">
            <input
              v-if="renaming === section.id"
              v-model="renameValue"
              class="flex-1 bg-transparent text-sm font-semibold outline-none"
              aria-label="Section name"
              autofocus
              @keydown.enter="saveRename(section)"
              @keydown.esc="renaming = null"
              @blur="saveRename(section)"
            >
            <h2 v-else class="flex-1 text-sm font-semibold" @dblclick="startRename(section)">
              {{ section.name }} <span class="font-normal text-muted-foreground">{{ sectionTasks.filter((t) => t.status !== 'done').length || '' }}</span>
            </h2>
            <DropdownMenu>
              <DropdownMenuTrigger as-child>
                <button type="button" class="rounded p-0.5 text-muted-foreground opacity-0 hover:bg-accent group-hover:opacity-100 data-[state=open]:opacity-100" aria-label="Section actions">
                  <MoreHorizontal class="size-4" />
                </button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end">
                <DropdownMenuItem @select="startRename(section)"><Pencil /> Rename</DropdownMenuItem>
                <DropdownMenuItem variant="destructive" @select="mutations.destroySection.mutate({ projectId: project.id, id: section.id })">
                  <Trash2 /> Delete section
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          </div>
          <TaskList :tasks="sectionTasks" reorderable :section-id="section.id" :show-project="false" />
          <InlineAddTask v-if="!project.archived" :defaults="{ project_id: project.id, section_id: section.id }" hide-project />
        </section>

        <form v-if="addingSection" class="mt-8" @submit.prevent="addSection">
          <input
            ref="sectionInput"
            v-model="newSection"
            class="w-full border-b border-primary bg-transparent pb-1.5 text-sm font-semibold outline-none"
            placeholder="Section name"
            aria-label="New section name"
            maxlength="100"
            @keydown.esc="addingSection = false"
            @blur="addSection"
          >
        </form>
        <button
          v-else-if="!project.archived"
          type="button"
          class="group mt-8 flex w-full items-center gap-3 text-xs font-medium text-muted-foreground hover:text-primary"
          @click="startAddSection"
        >
          <span class="h-px flex-1 bg-border group-hover:bg-primary/40" />
          Add section
          <span class="h-px flex-1 bg-border group-hover:bg-primary/40" />
        </button>
      </template>

      <ProjectDialog v-model:open="editOpen" :project="project" />
      <AlertDialog v-model:open="confirmDelete">
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Delete “{{ project.name }}”?</AlertDialogTitle>
            <AlertDialogDescription>
              Only empty projects can be deleted. If it still has tasks, archive it instead: it disappears from the sidebar but keeps its history.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancel</AlertDialogCancel>
            <AlertDialogAction class="bg-destructive text-white hover:bg-destructive/90" @click="deleteProject">Delete</AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </template>
  </div>
</template>
