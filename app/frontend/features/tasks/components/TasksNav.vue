<script setup lang="ts">
import { computed, ref } from 'vue'
import { CalendarRange, ChevronRight, CircleCheckBig, Inbox, Plus, Sun } from '@lucide/vue'
import { useStorage } from '@vueuse/core'
import { useProjects, useTaskCounts } from '@/composables/useTasks'
import ProjectBadge from './ProjectBadge.vue'
import ProjectDialog from './ProjectDialog.vue'

/** The Tasks part of the sidebar: views with count badges, then projects. */
const { data: counts } = useTaskCounts()
const { data: projects } = useProjects()
const projectsOpen = useStorage('lumen-sidebar-projects-open', true)
const creating = ref(false)

const views = computed(() => [
  { name: 'tasks-inbox', label: 'Inbox', icon: Inbox, count: counts.value?.inbox },
  { name: 'tasks-today', label: 'Today', icon: Sun, count: counts.value?.today, alert: !!counts.value?.overdue },
  { name: 'tasks-upcoming', label: 'Upcoming', icon: CalendarRange, count: counts.value?.upcoming },
  { name: 'tasks-completed', label: 'Completed', icon: CircleCheckBig },
])

const linkClass = 'flex items-center gap-2 rounded-md py-1 pl-8 pr-2 text-[13px] hover:bg-sidebar-accent hover:text-sidebar-accent-foreground'
const activeClass = 'bg-sidebar-accent text-sidebar-accent-foreground font-medium'
</script>

<template>
  <div class="space-y-0.5 pb-1">
    <RouterLink v-for="view in views" :key="view.name" :to="{ name: view.name }" :class="linkClass" :exact-active-class="activeClass">
      <component :is="view.icon" class="size-3.5 opacity-70" />
      <span class="flex-1">{{ view.label }}</span>
      <span v-if="view.count" class="text-[11px] tabular-nums" :class="view.alert ? 'text-red-500' : 'text-muted-foreground'">{{ view.count }}</span>
    </RouterLink>

    <div class="group/projects flex items-center pl-6 pr-1 pt-2">
      <button
        type="button"
        class="flex flex-1 items-center gap-1 rounded px-1 py-0.5 text-[11px] font-medium uppercase tracking-wide text-muted-foreground hover:text-foreground"
        :aria-expanded="projectsOpen"
        @click="projectsOpen = !projectsOpen"
      >
        <ChevronRight class="size-3 transition-transform" :class="projectsOpen && 'rotate-90'" />
        Projects
      </button>
      <button
        type="button"
        class="rounded p-0.5 text-muted-foreground opacity-0 hover:bg-sidebar-accent hover:text-foreground focus-visible:opacity-100 group-hover/projects:opacity-100"
        aria-label="New project"
        title="New project"
        @click="creating = true"
      >
        <Plus class="size-3.5" />
      </button>
    </div>
    <template v-if="projectsOpen">
      <RouterLink
        v-for="project in projects"
        :key="project.id"
        :to="{ name: 'project', params: { id: project.id } }"
        :class="linkClass"
        :exact-active-class="activeClass"
      >
        <ProjectBadge :project="project" class="size-3.5" />
        <span class="flex-1 truncate">{{ project.name }}</span>
        <span v-if="counts?.projects[project.id]" class="text-[11px] tabular-nums text-muted-foreground">{{ counts.projects[project.id] }}</span>
      </RouterLink>
      <button v-if="!projects?.length" type="button" :class="[linkClass, 'w-full text-muted-foreground']" @click="creating = true">
        <Plus class="size-3.5" /> Add a project
      </button>
    </template>
    <ProjectDialog v-model:open="creating" />
  </div>
</template>
