<script setup lang="ts">
import type { NoteSummary } from '@/api/notes'
import { dragged, dropTarget, endDrag, startDrag } from './treeDrag'

/** A note row in the sidebar tree. Dropping another note on it places that note just above. */
const props = defineProps<{ note: NoteSummary; depth: number }>()
const emit = defineEmits<{ dropBefore: [noteId: number] }>()

function onDragOver(event: DragEvent) {
  if (dragged.value?.kind !== 'note' || dragged.value.id === props.note.id) return
  event.preventDefault()
  event.stopPropagation()
  dropTarget.value = `note-${props.note.id}`
}

function onDrop(event: DragEvent) {
  if (dragged.value?.kind !== 'note' || dragged.value.id === props.note.id) return
  event.preventDefault()
  event.stopPropagation()
  emit('dropBefore', dragged.value.id)
  endDrag()
}
</script>

<template>
  <RouterLink
    :to="{ name: 'note', params: { id: note.id } }"
    draggable="true"
    class="relative flex items-center gap-1.5 rounded-md py-1 pr-2 text-[13px] hover:bg-sidebar-accent hover:text-sidebar-accent-foreground"
    exact-active-class="bg-sidebar-accent text-sidebar-accent-foreground font-medium"
    :style="{ paddingLeft: `${depth * 12 + 30}px` }"
    @dragstart="startDrag($event, { kind: 'note', id: note.id })"
    @dragend="endDrag"
    @dragover="onDragOver"
    @dragleave="dropTarget === `note-${note.id}` && (dropTarget = null)"
    @drop="onDrop"
  >
    <span v-if="dropTarget === `note-${note.id}`" class="pointer-events-none absolute inset-x-1 -top-px h-0.5 rounded bg-primary" />
    <span class="w-4 shrink-0 text-center text-xs opacity-70">{{ note.icon ?? '📄' }}</span>
    <span class="truncate">{{ note.title }}</span>
  </RouterLink>
</template>
