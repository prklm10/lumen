<script setup lang="ts">
import { computed } from 'vue'
import type { Project } from '@/api/tasks'
import { colorClasses } from '@/lib/colors'
import { projectIcons } from '@/lib/projectIcons'

const props = defineProps<{ project: Pick<Project, 'color' | 'icon'>; size?: 'sm' | 'lg' }>()
const icon = computed(() => (props.project.icon ? projectIcons[props.project.icon] : null))
</script>

<template>
  <component :is="icon" v-if="icon" :class="[size === 'lg' ? 'size-5' : 'size-4', colorClasses(project.color).text]" />
  <span v-else class="flex items-center justify-center" :class="size === 'lg' ? 'size-5' : 'size-4'">
    <span class="rounded-full" :class="[size === 'lg' ? 'size-2.5' : 'size-2', colorClasses(project.color).dot]" />
  </span>
</template>
