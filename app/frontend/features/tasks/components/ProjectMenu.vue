<script setup lang="ts">
import { computed } from 'vue'
import { Check, Hash, Inbox } from '@lucide/vue'
import {
  DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuSeparator, DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import { useProjects } from '@/composables/useTasks'
import { colorClasses } from '@/lib/colors'

/** Picks a project (or the Inbox) and optionally one of its sections. */
const props = defineProps<{ projectId: number | null; sectionId: number | null; compact?: boolean }>()
const emit = defineEmits<{ change: [value: { project_id: number | null; section_id: number | null }] }>()

const { data: projects } = useProjects()
const current = computed(() => projects.value?.find((p) => p.id === props.projectId))
const section = computed(() => current.value?.sections.find((s) => s.id === props.sectionId))
</script>

<template>
  <DropdownMenu>
    <DropdownMenuTrigger as-child>
      <button type="button" class="inline-flex h-7 max-w-52 items-center gap-1.5 rounded-md border px-2 text-xs hover:bg-accent">
        <span v-if="current" class="size-2 shrink-0 rounded-full" :class="colorClasses(current.color).dot" />
        <Inbox v-else class="size-3.5 text-muted-foreground" />
        <span class="truncate">{{ current ? current.name : 'Inbox' }}<template v-if="section"> / {{ section.name }}</template></span>
      </button>
    </DropdownMenuTrigger>
    <DropdownMenuContent align="start" class="max-h-80 w-56 overflow-y-auto">
      <DropdownMenuItem @select="emit('change', { project_id: null, section_id: null })">
        <Inbox /> Inbox
        <Check v-if="projectId === null" class="ml-auto" />
      </DropdownMenuItem>
      <DropdownMenuSeparator v-if="projects?.length" />
      <template v-for="project in projects" :key="project.id">
        <DropdownMenuItem @select="emit('change', { project_id: project.id, section_id: null })">
          <span class="mx-1 size-2 rounded-full" :class="colorClasses(project.color).dot" />
          <span class="truncate">{{ project.name }}</span>
          <Check v-if="projectId === project.id && sectionId === null" class="ml-auto" />
        </DropdownMenuItem>
        <DropdownMenuItem
          v-for="s in project.sections"
          :key="s.id"
          class="pl-8 text-muted-foreground"
          @select="emit('change', { project_id: project.id, section_id: s.id })"
        >
          <Hash class="size-3" />
          <span class="truncate">{{ s.name }}</span>
          <Check v-if="sectionId === s.id" class="ml-auto" />
        </DropdownMenuItem>
      </template>
    </DropdownMenuContent>
  </DropdownMenu>
</template>
