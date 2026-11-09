import { defineStore } from 'pinia'
import { ref } from 'vue'
import type { TaskInput } from '@/api/tasks'

/** App-wide task UI state: the detail sheet and the quick-add dialog, openable from anywhere. */
export const useTaskPanel = defineStore('taskPanel', () => {
  const openTaskId = ref<number | null>(null)
  const quickAddOpen = ref(false)
  const quickAddDefaults = ref<TaskInput>({})

  function openTask(id: number) {
    openTaskId.value = id
  }

  function closeTask() {
    openTaskId.value = null
  }

  function quickAdd(defaults: TaskInput = {}) {
    quickAddDefaults.value = defaults
    quickAddOpen.value = true
  }

  return { openTaskId, quickAddOpen, quickAddDefaults, openTask, closeTask, quickAdd }
})
