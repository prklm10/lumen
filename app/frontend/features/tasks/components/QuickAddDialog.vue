<script setup lang="ts">
import { Dialog, DialogContent, DialogDescription, DialogTitle } from '@/components/ui/dialog'
import { useTaskPanel } from '@/stores/taskPanel'
import TaskComposer from './TaskComposer.vue'

const panel = useTaskPanel()
</script>

<template>
  <Dialog v-model:open="panel.quickAddOpen">
    <DialogContent class="top-[20%] translate-y-0 gap-0 border-0 bg-transparent p-0 shadow-none sm:max-w-xl" :show-close-button="false">
      <DialogTitle class="sr-only">Quick add task</DialogTitle>
      <DialogDescription class="sr-only">Type a task name and press Enter.</DialogDescription>
      <TaskComposer
        v-if="panel.quickAddOpen"
        class="shadow-xl"
        :defaults="panel.quickAddDefaults"
        :keep-open="false"
        @close="panel.quickAddOpen = false"
      />
    </DialogContent>
  </Dialog>
</template>
