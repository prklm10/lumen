<script setup lang="ts">
import { computed, nextTick, ref } from 'vue'
import { ChevronRight, FilePlus2, Folder, FolderOpen, FolderPlus, MoreHorizontal, Pencil, Trash2 } from '@lucide/vue'
import {
  DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuSeparator, DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import type { FolderNode } from '@/composables/useNotes'
import NoteTreeItem from './NoteTreeItem.vue'
import { dragged, dropTarget, endDrag, startDrag } from './treeDrag'

/** A folder row (recursive). Drop a note or folder on it to move it inside. */
const props = defineProps<{ folder: FolderNode; depth: number; expanded: Set<number> }>()
const emit = defineEmits<{
  toggle: [id: number]
  newNote: [folderId: number]
  newFolder: [parentId: number]
  rename: [id: number, name: string]
  remove: [id: number]
  moveNote: [noteId: number, folderId: number | null, beforeNoteId?: number]
  moveFolder: [folderId: number, parentId: number | null]
}>()

const open = computed(() => props.expanded.has(props.folder.id))
const renaming = ref(false)
const draft = ref('')
const input = ref<HTMLInputElement>()
const count = computed(() => props.folder.notes.length)

async function startRename() {
  draft.value = props.folder.name
  renaming.value = true
  await nextTick()
  input.value?.select()
}

function finishRename() {
  if (!renaming.value) return
  renaming.value = false
  const name = draft.value.trim()
  if (name && name !== props.folder.name) emit('rename', props.folder.id, name)
}

function contains(folder: FolderNode, id: number): boolean {
  return folder.id === id || folder.children.some((c) => contains(c, id))
}

const canDrop = () => dragged.value && !(dragged.value.kind === 'folder' && contains(props.folder, dragged.value.id))

function onDragOver(event: DragEvent) {
  if (!canDrop()) return
  event.preventDefault()
  dropTarget.value = `folder-${props.folder.id}`
}

function onDrop(event: DragEvent) {
  if (!canDrop()) return
  event.preventDefault()
  event.stopPropagation()
  const item = dragged.value!
  if (item.kind === 'note') emit('moveNote', item.id, props.folder.id)
  else emit('moveFolder', item.id, props.folder.id)
  if (!open.value) emit('toggle', props.folder.id)
  endDrag()
}
</script>

<template>
  <div>
    <div
      class="group/folder flex items-center gap-1 rounded-md py-1 pr-1 text-[13px] hover:bg-sidebar-accent hover:text-sidebar-accent-foreground"
      :class="dropTarget === `folder-${folder.id}` && 'bg-primary/10 ring-1 ring-primary/40'"
      :style="{ paddingLeft: `${depth * 12 + 8}px` }"
      draggable="true"
      @dragstart="startDrag($event, { kind: 'folder', id: folder.id })"
      @dragend="endDrag"
      @dragover="onDragOver"
      @dragleave="dropTarget === `folder-${folder.id}` && (dropTarget = null)"
      @drop="onDrop"
    >
      <button type="button" class="flex min-w-0 flex-1 items-center gap-1.5" :aria-expanded="open" @click="emit('toggle', folder.id)" @dblclick="startRename">
        <ChevronRight class="size-3 shrink-0 text-muted-foreground transition-transform" :class="open && 'rotate-90'" />
        <component :is="open ? FolderOpen : Folder" class="size-3.5 shrink-0 text-muted-foreground" />
        <input
          v-if="renaming"
          ref="input"
          v-model="draft"
          class="min-w-0 flex-1 rounded bg-background px-1 outline-none ring-1 ring-ring"
          aria-label="Folder name"
          maxlength="100"
          @click.stop
          @keydown.enter="finishRename"
          @keydown.esc="renaming = false"
          @blur="finishRename"
        >
        <span v-else class="truncate">{{ folder.name }}</span>
      </button>
      <span v-if="count && !renaming" class="text-[11px] tabular-nums text-muted-foreground group-hover/folder:hidden">{{ count }}</span>
      <button
        type="button"
        class="hidden rounded p-0.5 text-muted-foreground hover:bg-background hover:text-foreground group-hover/folder:block"
        aria-label="New note in folder"
        title="New note"
        @click="emit('newNote', folder.id)"
      >
        <FilePlus2 class="size-3.5" />
      </button>
      <DropdownMenu>
        <DropdownMenuTrigger as-child>
          <button type="button" class="hidden rounded p-0.5 text-muted-foreground hover:bg-background hover:text-foreground group-hover/folder:block data-[state=open]:block" aria-label="Folder actions">
            <MoreHorizontal class="size-3.5" />
          </button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="start" class="w-44">
          <DropdownMenuItem @select="emit('newNote', folder.id)"><FilePlus2 /> New note</DropdownMenuItem>
          <DropdownMenuItem @select="emit('newFolder', folder.id)"><FolderPlus /> New subfolder</DropdownMenuItem>
          <DropdownMenuItem @select="startRename"><Pencil /> Rename</DropdownMenuItem>
          <DropdownMenuSeparator />
          <DropdownMenuItem variant="destructive" @select="emit('remove', folder.id)"><Trash2 /> Delete folder</DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    </div>

    <template v-if="open">
      <FolderTreeItem
        v-for="child in folder.children"
        :key="child.id"
        :folder="child"
        :depth="depth + 1"
        :expanded="expanded"
        @toggle="(id) => emit('toggle', id)"
        @new-note="(id) => emit('newNote', id)"
        @new-folder="(id) => emit('newFolder', id)"
        @rename="(id, name) => emit('rename', id, name)"
        @remove="(id) => emit('remove', id)"
        @move-note="(n, f, b) => emit('moveNote', n, f, b)"
        @move-folder="(f, p) => emit('moveFolder', f, p)"
      />
      <NoteTreeItem
        v-for="note in folder.notes"
        :key="note.id"
        :note="note"
        :depth="depth + 1"
        @drop-before="(id) => emit('moveNote', id, folder.id, note.id)"
      />
      <p v-if="!folder.children.length && !folder.notes.length" class="py-1 text-[12px] text-muted-foreground/70" :style="{ paddingLeft: `${(depth + 1) * 12 + 30}px` }">
        Empty
      </p>
    </template>
  </div>
</template>
