<script setup lang="ts">
import { computed, ref } from 'vue'
import type { Task } from '@/api/tasks'
import { useTaskMutations } from '@/composables/useTasks'
import TaskRow from './TaskRow.vue'

/**
 * A list of task rows with drag-to-reorder (native HTML drag and drop, no library).
 * Positions are fractional, so a drop only updates the moved task: it gets the midpoint of
 * its new neighbours. With `sectionId` set, tasks dragged in from another section join this one.
 */
const props = withDefaults(defineProps<{
  tasks: Task[]
  reorderable?: boolean
  sectionId?: number | null
  showProject?: boolean
  showDue?: boolean
}>(), { showProject: true, showDue: true, sectionId: undefined })

const { reorder } = useTaskMutations()
const dragId = ref<number | null>(null)
const dropIndex = ref<number | null>(null)
const ordered = computed(() => props.tasks)

function onDragStart(event: DragEvent, task: Task) {
  dragId.value = task.id
  event.dataTransfer!.effectAllowed = 'move'
  event.dataTransfer!.setData('application/x-lumen-task', JSON.stringify({ id: task.id, position: task.position }))
}

function onDragOver(event: DragEvent, index: number) {
  if (!props.reorderable || !event.dataTransfer?.types.includes('application/x-lumen-task')) return
  event.preventDefault()
  const row = event.currentTarget as HTMLElement
  const after = event.offsetY > row.offsetHeight / 2
  dropIndex.value = index + (after ? 1 : 0)
}

function positionFor(index: number, movingId: number) {
  const others = ordered.value.filter((t) => t.id !== movingId)
  const before = others[index - 1]?.position
  const after = others[index]?.position
  if (before === undefined && after === undefined) return 1
  if (before === undefined) return after! - 1
  if (after === undefined) return before + 1
  return (before + after) / 2
}

function onDrop(event: DragEvent) {
  const raw = event.dataTransfer?.getData('application/x-lumen-task')
  const index = dropIndex.value
  dropIndex.value = null
  dragId.value = null
  if (!raw || index === null) return
  event.preventDefault()

  const { id } = JSON.parse(raw) as { id: number }
  const currentIndex = ordered.value.findIndex((t) => t.id === id)
  // Index among the *other* tasks: dropping below yourself shifts by one.
  const target = currentIndex !== -1 && currentIndex < index ? index - 1 : index
  if (currentIndex === target && currentIndex !== -1) return

  const move: { id: number; position: number; section_id?: number | null } = { id, position: positionFor(target, id) }
  if (props.sectionId !== undefined) move.section_id = props.sectionId
  reorder.mutate([move])
}

function onDragEnd() {
  dragId.value = null
  dropIndex.value = null
}
</script>

<template>
  <div
    class="relative"
    @dragover.prevent="reorderable && tasks.length === 0 && (dropIndex = 0)"
    @dragleave.self="dropIndex = null"
    @drop="onDrop"
  >
    <TransitionGroup
      tag="div"
      move-class="transition-transform duration-200"
      leave-active-class="transition-all duration-200 absolute w-full"
      leave-to-class="opacity-0 -translate-x-2"
    >
      <div
        v-for="(task, index) in ordered"
        :key="task.id"
        :draggable="reorderable"
        class="relative"
        :class="dragId === task.id && 'opacity-40'"
        @dragstart="onDragStart($event, task)"
        @dragover="onDragOver($event, index)"
        @dragend="onDragEnd"
      >
        <div v-if="dropIndex === index" class="pointer-events-none absolute -top-px left-0 right-0 z-10 h-0.5 rounded bg-primary" />
        <TaskRow :task="task" :show-project="showProject" :show-due="showDue" :draggable="reorderable" />
        <div
          v-if="dropIndex === ordered.length && index === ordered.length - 1"
          class="pointer-events-none absolute -bottom-px left-0 right-0 z-10 h-0.5 rounded bg-primary"
        />
      </div>
    </TransitionGroup>
    <div v-if="reorderable && tasks.length === 0 && dropIndex === 0" class="h-0.5 rounded bg-primary" />
  </div>
</template>
