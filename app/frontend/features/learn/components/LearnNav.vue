<script setup lang="ts">
import { computed, watch } from 'vue'
import { useRoute } from 'vue-router'
import { useStorage } from '@vueuse/core'
import { toast } from 'vue-sonner'
import { Brain, FilePlus2, FolderPlus, Library, Pin } from '@lucide/vue'
import { useQuery } from '@tanstack/vue-query'
import { studyApi } from '@/api/study'
import type { NoteSummary } from '@/api/notes'
import { buildTree, folderPath, useFolderMutations, useFolders, useNoteMutations, useNotesList } from '@/composables/useNotes'
import { useCreateNote } from '../useCreateNote'
import FolderTreeItem from './FolderTreeItem.vue'
import NoteTreeItem from './NoteTreeItem.vue'
import { dragged, dropTarget, endDrag } from './treeDrag'

/** The Learn part of the sidebar: pinned notes, then the folder tree (LRN-3, LRN-15). */
const route = useRoute()
const { data: notes } = useNotesList()
const { data: folders } = useFolders()
const noteMutations = useNoteMutations()
const folderMutations = useFolderMutations()
const createNote = useCreateNote()
const { data: due } = useQuery({ queryKey: ['flashcards', 'due'], queryFn: studyApi.due, staleTime: 60_000 })

const expandedIds = useStorage<number[]>('lumen-learn-expanded', [])
const expanded = computed(() => new Set(expandedIds.value))
const tree = computed(() => buildTree(folders.value ?? [], notes.value ?? []))
const pinned = computed(() => (notes.value ?? []).filter((n) => n.pinned))

function toggle(id: number) {
  expandedIds.value = expanded.value.has(id) ? expandedIds.value.filter((x) => x !== id) : [...expandedIds.value, id]
}

// Reveal the open note in the tree.
watch([() => route.params.id, notes, folders], () => {
  if (route.name !== 'note' || !notes.value || !folders.value) return
  const note = notes.value.find((n) => n.id === Number(route.params.id))
  const missing = folderPath(folders.value, note?.folder_id ?? null).map((f) => f.id).filter((id) => !expanded.value.has(id))
  if (missing.length) expandedIds.value = [...expandedIds.value, ...missing]
}, { immediate: true })

async function newFolder(parentId: number | null = null) {
  const folder = await folderMutations.create.mutateAsync({ name: 'New folder', parent_id: parentId })
  if (parentId && !expanded.value.has(parentId)) toggle(parentId)
  toast('Folder created', { description: 'Double-click a folder to rename it.' })
  return folder
}

function siblingsOf(folderId: number | null): NoteSummary[] {
  return folderId ? tree.value.byId.get(folderId)?.notes ?? [] : tree.value.looseNotes
}

function moveNote(noteId: number, folderId: number | null, beforeNoteId?: number) {
  const input: { folder_id: number | null; position?: number } = { folder_id: folderId }
  if (beforeNoteId) {
    const siblings = siblingsOf(folderId).filter((n) => n.id !== noteId)
    const index = siblings.findIndex((n) => n.id === beforeNoteId)
    const before = siblings[index - 1]?.position
    const target = siblings[index]!.position
    input.position = before === undefined ? target - 1 : (before + target) / 2
  }
  noteMutations.update.mutate({ id: noteId, input })
}

function moveFolder(folderId: number, parentId: number | null) {
  folderMutations.update.mutate({ id: folderId, input: { parent_id: parentId } })
}

function renameFolder(id: number, name: string) {
  folderMutations.update.mutate({ id, input: { name } })
}

function removeFolder(id: number) {
  folderMutations.destroy.mutate(id, { onSuccess: () => toast('Folder deleted', { description: 'Its notes moved up a level.' }) })
}

// Dropping on the empty area below the tree moves things back to the top level.
function onRootDragOver(event: DragEvent) {
  if (!dragged.value) return
  event.preventDefault()
  dropTarget.value = 'root'
}

function onRootDrop(event: DragEvent) {
  const item = dragged.value
  if (!item) return
  event.preventDefault()
  if (item.kind === 'note') moveNote(item.id, null)
  else moveFolder(item.id, null)
  endDrag()
}

const linkClass = 'flex items-center gap-1.5 rounded-md py-1 pl-[30px] pr-2 text-[13px] hover:bg-sidebar-accent hover:text-sidebar-accent-foreground'
</script>

<template>
  <div class="pb-1">
    <div class="flex gap-0.5 pb-1 pl-6 pr-1">
      <button type="button" :class="[linkClass, 'flex-1 pl-2 text-muted-foreground']" @click="createNote()">
        <FilePlus2 class="size-3.5" /> New note
      </button>
      <button
        type="button"
        class="rounded-md px-1.5 text-muted-foreground hover:bg-sidebar-accent hover:text-foreground"
        aria-label="New folder"
        title="New folder"
        @click="newFolder()"
      >
        <FolderPlus class="size-3.5" />
      </button>
    </div>

    <RouterLink :to="{ name: 'resources' }" :class="[linkClass, 'pl-8']" exact-active-class="bg-sidebar-accent text-sidebar-accent-foreground font-medium">
      <Library class="size-3.5 opacity-70" /> Resources
    </RouterLink>
    <RouterLink :to="{ name: 'review' }" :class="[linkClass, 'pl-8']" exact-active-class="bg-sidebar-accent text-sidebar-accent-foreground font-medium">
      <Brain class="size-3.5 opacity-70" /> <span class="flex-1">Review</span>
      <span v-if="due?.due_count" class="text-[11px] tabular-nums text-primary">{{ due.due_count }}</span>
    </RouterLink>

    <template v-if="pinned.length">
      <p class="flex items-center gap-1 pb-0.5 pl-8 pt-1 text-[11px] font-medium uppercase tracking-wide text-muted-foreground">
        <Pin class="size-3" /> Pinned
      </p>
      <RouterLink
        v-for="note in pinned"
        :key="`pinned-${note.id}`"
        :to="{ name: 'note', params: { id: note.id } }"
        :class="linkClass"
        exact-active-class="bg-sidebar-accent text-sidebar-accent-foreground font-medium"
      >
        <span class="w-4 shrink-0 text-center text-xs opacity-70">{{ note.icon ?? '📄' }}</span>
        <span class="truncate">{{ note.title }}</span>
      </RouterLink>
      <div class="mx-8 my-1.5 h-px bg-sidebar-border" />
    </template>

    <div class="pl-4">
      <FolderTreeItem
        v-for="folder in tree.roots"
        :key="folder.id"
        :folder="folder"
        :depth="0"
        :expanded="expanded"
        @toggle="toggle"
        @new-note="(id) => createNote(id)"
        @new-folder="newFolder"
        @rename="renameFolder"
        @remove="removeFolder"
        @move-note="moveNote"
        @move-folder="moveFolder"
      />
      <NoteTreeItem
        v-for="note in tree.looseNotes"
        :key="note.id"
        :note="note"
        :depth="-1"
        @drop-before="(id) => moveNote(id, null, note.id)"
      />
      <div
        v-if="dragged"
        class="mx-1 mt-1 rounded-md border border-dashed px-2 py-1.5 text-center text-[11px] text-muted-foreground"
        :class="dropTarget === 'root' && 'border-primary bg-primary/10 text-primary'"
        @dragover="onRootDragOver"
        @dragleave="dropTarget === 'root' && (dropTarget = null)"
        @drop="onRootDrop"
      >
        Move to top level
      </div>
    </div>
  </div>
</template>
