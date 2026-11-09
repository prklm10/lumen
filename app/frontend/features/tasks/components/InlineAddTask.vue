<script setup lang="ts">
import { ref } from 'vue'
import { Plus } from '@lucide/vue'
import type { TaskInput } from '@/api/tasks'
import TaskComposer from './TaskComposer.vue'

defineProps<{ defaults?: TaskInput; hideProject?: boolean; label?: string }>()
const open = ref(false)
</script>

<template>
  <TaskComposer v-if="open" :defaults="defaults" :hide-project="hideProject" class="my-1" @close="open = false" />
  <button
    v-else
    type="button"
    class="group flex w-full items-center gap-2.5 rounded-md px-1 py-2 text-muted-foreground hover:text-primary"
    @click="open = true"
  >
    <span class="flex size-[18px] items-center justify-center rounded-full text-primary group-hover:bg-primary group-hover:text-primary-foreground">
      <Plus class="size-4" />
    </span>
    {{ label ?? 'Add task' }}
  </button>
</template>
