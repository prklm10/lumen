import { ref } from 'vue'

/** Shared drag state for the notes tree: what's being dragged and where it would land. */
export type Dragged = { kind: 'note' | 'folder'; id: number }

export const dragged = ref<Dragged | null>(null)
export const dropTarget = ref<string | null>(null)

export function startDrag(event: DragEvent, item: Dragged) {
  dragged.value = item
  event.dataTransfer!.effectAllowed = 'move'
  event.dataTransfer!.setData('application/x-lumen-tree', JSON.stringify(item))
}

export function endDrag() {
  dragged.value = null
  dropTarget.value = null
}
