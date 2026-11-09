<script setup lang="ts">
import { useRouter } from 'vue-router'
import { Brain, CalendarCheck, FilePlus2, LogOut, Monitor, Moon, Plus, Sun } from '@lucide/vue'
import {
  CommandDialog, CommandGroup, CommandInput, CommandItem, CommandList, CommandSeparator, CommandShortcut,
} from '@/components/ui/command'
import ProjectBadge from '@/features/tasks/components/ProjectBadge.vue'
import SearchResults from '@/components/layout/SearchResults.vue'
import { useCreateNote } from '@/features/learn/useCreateNote'
import { useProjects } from '@/composables/useTasks'
import { useTaskPanel } from '@/stores/taskPanel'
import { primaryNav, settingsNav, type NavItem } from '@/lib/navigation'
import { useTheme, type ThemeMode } from '@/composables/useTheme'
import { useAuthStore } from '@/stores/auth'

const open = defineModel<boolean>('open', { required: true })
const router = useRouter()
const auth = useAuthStore()
const { store: theme } = useTheme()
const taskPanel = useTaskPanel()
const { data: projects } = useProjects()
const createNote = useCreateNote()

const themes: { mode: ThemeMode; label: string; icon: typeof Sun }[] = [
  { mode: 'light', label: 'Light theme', icon: Sun },
  { mode: 'dark', label: 'Dark theme', icon: Moon },
  { mode: 'auto', label: 'System theme', icon: Monitor },
]

function run(action: () => unknown) {
  open.value = false
  action()
}

function go(item: NavItem) {
  run(() => router.push(item.path))
}

async function signOut() {
  await auth.logout()
  router.push({ name: 'login' })
}
</script>

<template>
  <CommandDialog v-model:open="open" title="Command palette" description="Jump anywhere or run an action">
    <CommandInput placeholder="Search notes and tasks, or type a command…" />
    <CommandList>
      <CommandGroup heading="Actions">
        <CommandItem value="New task" @select="run(() => taskPanel.quickAdd())">
          <Plus /> New task
          <CommandShortcut>C</CommandShortcut>
        </CommandItem>
        <CommandItem value="New note" @select="run(() => createNote())">
          <FilePlus2 /> New note
        </CommandItem>
        <CommandItem value="Weekly review" @select="run(() => router.push({ name: 'weekly-review' }))">
          <CalendarCheck /> Weekly review
        </CommandItem>
        <CommandItem value="Review flashcards" @select="run(() => router.push({ name: 'review' }))">
          <Brain /> Review flashcards
        </CommandItem>
      </CommandGroup>
      <SearchResults
        @note="(id) => run(() => router.push({ name: 'note', params: { id } }))"
        @task="(id) => run(() => taskPanel.openTask(id))"
      />
      <CommandGroup heading="Go to">
        <CommandItem v-for="item in [...primaryNav, settingsNav]" :key="item.name" :value="`Go to ${item.label}`" @select="go(item)">
          <component :is="item.icon" />
          {{ item.label }}
          <CommandShortcut v-if="item.shortcut">G {{ item.shortcut.toUpperCase() }}</CommandShortcut>
        </CommandItem>
        <CommandItem
          v-for="project in projects"
          :key="`project-${project.id}`"
          :value="`project ${project.name}`"
          @select="run(() => router.push({ name: 'project', params: { id: project.id } }))"
        >
          <ProjectBadge :project="project" />
          {{ project.name }}
        </CommandItem>
      </CommandGroup>
      <CommandSeparator />
      <CommandGroup heading="Preferences">
        <CommandItem v-for="t in themes" :key="t.mode" :value="t.label" @select="run(() => (theme = t.mode))">
          <component :is="t.icon" />
          {{ t.label }}
        </CommandItem>
      </CommandGroup>
      <CommandSeparator />
      <CommandGroup heading="Account">
        <CommandItem value="Sign out" @select="run(signOut)"><LogOut /> Sign out</CommandItem>
      </CommandGroup>
    </CommandList>
  </CommandDialog>
</template>
