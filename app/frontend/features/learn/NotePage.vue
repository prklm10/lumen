<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, ref, shallowRef, watch } from 'vue'
import { onBeforeRouteLeave, onBeforeRouteUpdate, useRouter } from 'vue-router'
import { useEventListener, useTextareaAutosize } from '@vueuse/core'
import { useQueryClient } from '@tanstack/vue-query'
import { toast } from 'vue-sonner'
import { ChevronRight, FileQuestion, Folder, Hash, Link2, MoreHorizontal, Pin, PinOff, Trash2 } from '@lucide/vue'
import {
  DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuSeparator, DropdownMenuSub, DropdownMenuSubContent,
  DropdownMenuSubTrigger, DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import { Button } from '@/components/ui/button'
import RichEditor from '@/components/editor/RichEditor.vue'
import { ApiError } from '@/api/client'
import { notesApi, type Note } from '@/api/notes'
import type { RichDoc } from '@/api/tasks'
import { folderPath, noteKeys, useFolders, useNote, useNoteMutations } from '@/composables/useNotes'
import { useNoteLinks } from '@/composables/useNoteLinks'
import { errorMessage } from '@/composables/useTasks'
import EmptyState from '@/features/tasks/components/EmptyState.vue'
import NoteFlashcards from './study/NoteFlashcards.vue'

const props = defineProps<{ id: string }>()
const noteId = computed(() => Number(props.id))
const router = useRouter()
const client = useQueryClient()

const { data: note, error, refetch } = useNote(noteId)
const { data: folders } = useFolders()
const mutations = useNoteMutations()
const links = useNoteLinks(() => noteId.value)

// The editor owns the document while it's open: it's seeded once per note and never
// overwritten by save responses (that would clobber whatever was typed meanwhile).
const initialDoc = shallowRef<RichDoc | null>(null)
const title = ref('')
const lockVersion = ref(0)
const tags = ref<Note['tags']>([])
const editor = ref<InstanceType<typeof RichEditor>>()
const { textarea: titleArea } = useTextareaAutosize({ input: title })

type Status = 'saved' | 'dirty' | 'saving' | 'conflict' | 'error'
const status = ref<Status>('saved')
let pending: { title?: string; content?: RichDoc } = {}
let timer: ReturnType<typeof setTimeout> | undefined
let inFlight: Promise<void> | null = null

let loadedId: number | null = null
watch(note, (n) => {
  if (!n || (initialDoc.value && n.id === loadedId)) return
  loadedId = n.id
  initialDoc.value = n.content
  title.value = n.title === 'Untitled' ? '' : n.title
  lockVersion.value = n.lock_version
  tags.value = n.tags
  status.value = 'saved'
  document.title = `${n.title} · Lumen`
  if (n.title === 'Untitled' && !n.content.content?.length) nextTick(() => titleArea.value?.focus())
}, { immediate: true })

function schedule(change: typeof pending) {
  pending = { ...pending, ...change }
  status.value = 'dirty'
  clearTimeout(timer)
  timer = setTimeout(save, 700)
}

// One save at a time, so each carries the lock_version the previous one returned.
async function save(): Promise<void> {
  clearTimeout(timer)
  if (inFlight) {
    await inFlight
    return Object.keys(pending).length ? save() : undefined
  }
  if (!Object.keys(pending).length || status.value === 'conflict') return
  if (editor.value?.hasPendingUploads()) {
    timer = setTimeout(save, 500) // don't store an image's temporary local preview URL
    return
  }

  const id = noteId.value
  const change = pending
  pending = {}
  status.value = 'saving'
  inFlight = (async () => {
    try {
      const saved = await notesApi.update(id, { ...change, lock_version: lockVersion.value })
      if (id !== noteId.value) return
      lockVersion.value = saved.lock_version
      tags.value = saved.tags
      client.setQueryData(noteKeys.detail(id), saved)
      if (change.title !== undefined || saved.tags.length) client.invalidateQueries({ queryKey: noteKeys.list })
      if (change.title !== undefined) document.title = `${saved.title} · Lumen`
      status.value = Object.keys(pending).length ? 'dirty' : 'saved'
    } catch (e) {
      pending = { ...change, ...pending }
      if (e instanceof ApiError && e.code === 'stale_note') {
        status.value = 'conflict'
        toast.error('This note changed somewhere else', {
          description: 'Reload to get the latest version. Your unsaved edits here will be lost.',
          action: { label: 'Reload', onClick: reload },
          duration: Infinity,
        })
      } else {
        status.value = 'error'
        toast.error(errorMessage(e))
      }
    } finally {
      inFlight = null
    }
  })()
  await inFlight
}

async function reload() {
  pending = {}
  initialDoc.value = null
  loadedId = null
  await refetch()
}

const flush = () => (Object.keys(pending).length ? save() : undefined)
onBeforeRouteLeave(flush)
onBeforeRouteUpdate(async () => {
  await flush()
  initialDoc.value = null
  loadedId = null
})
onBeforeUnmount(flush)
useEventListener(window, 'beforeunload', (e) => {
  if (Object.keys(pending).length || inFlight) e.preventDefault()
})

function onTitleInput() {
  schedule({ title: title.value.replace(/\n/g, ' ').trim() || 'Untitled' })
}

const breadcrumb = computed(() => (note.value && folders.value ? folderPath(folders.value, note.value.folder_id) : []))
const statusLabel = computed(() => ({ saved: 'Saved', dirty: 'Editing…', saving: 'Saving…', conflict: 'Not saved: changed elsewhere', error: 'Not saved' })[status.value])

function moveTo(folderId: number | null) {
  if (!note.value) return
  mutations.update.mutate({ id: note.value.id, input: { folder_id: folderId } })
}

function togglePin() {
  if (!note.value) return
  mutations.update.mutate({ id: note.value.id, input: { pinned: !note.value.pinned } })
}

async function remove() {
  if (!note.value) return
  pending = {}
  await mutations.destroy.mutateAsync(note.value.id)
  toast('Note deleted', { description: note.value.title })
  router.push({ name: 'learn' })
}
</script>

<template>
  <div class="mx-auto max-w-3xl px-6 pb-32 pt-6 md:px-12">
    <EmptyState v-if="error" :icon="FileQuestion" title="Note not found" body="It may have been deleted." />

    <template v-else-if="note && initialDoc">
      <div class="mb-8 flex items-center gap-2 text-xs text-muted-foreground">
        <nav class="flex min-w-0 flex-1 items-center gap-1" aria-label="Breadcrumb">
          <RouterLink :to="{ name: 'learn' }" class="hover:text-foreground">Learn</RouterLink>
          <template v-for="f in breadcrumb" :key="f.id">
            <ChevronRight class="size-3 shrink-0" />
            <span class="truncate">{{ f.name }}</span>
          </template>
        </nav>
        <span :class="status === 'conflict' || status === 'error' ? 'text-destructive' : ''" aria-live="polite">{{ statusLabel }}</span>
        <Pin v-if="note.pinned" class="size-3.5 text-primary" aria-label="Pinned" />
        <DropdownMenu>
          <DropdownMenuTrigger as-child>
            <Button variant="ghost" size="icon-sm" aria-label="Note actions"><MoreHorizontal /></Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end" class="w-48">
            <DropdownMenuItem @select="togglePin">
              <component :is="note.pinned ? PinOff : Pin" /> {{ note.pinned ? 'Unpin' : 'Pin' }}
            </DropdownMenuItem>
            <DropdownMenuSub>
              <DropdownMenuSubTrigger><Folder class="size-4 text-muted-foreground" /> Move to</DropdownMenuSubTrigger>
              <DropdownMenuSubContent class="max-h-72 overflow-y-auto">
                <DropdownMenuItem :disabled="note.folder_id === null" @select="moveTo(null)">No folder</DropdownMenuItem>
                <DropdownMenuItem v-for="f in folders" :key="f.id" :disabled="note.folder_id === f.id" @select="moveTo(f.id)">
                  {{ folderPath(folders!, f.id).map((x) => x.name).join(' / ') }}
                </DropdownMenuItem>
              </DropdownMenuSubContent>
            </DropdownMenuSub>
            <DropdownMenuSeparator />
            <DropdownMenuItem variant="destructive" @select="remove"><Trash2 /> Delete</DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>

      <textarea
        ref="titleArea"
        v-model="title"
        rows="1"
        class="w-full resize-none bg-transparent text-4xl font-bold leading-tight tracking-tight outline-none placeholder:text-muted-foreground/40"
        placeholder="Untitled"
        aria-label="Note title"
        maxlength="200"
        @input="onTitleInput"
        @keydown.enter.prevent="editor?.focus('start')"
      />

      <div v-if="tags.length" class="mt-3 flex flex-wrap gap-1.5">
        <span v-for="tag in tags" :key="tag.id" class="inline-flex items-center rounded bg-secondary px-1.5 py-0.5 text-xs text-muted-foreground">
          <Hash class="size-3" />{{ tag.name }}
        </span>
      </div>

      <RichEditor
        :key="note.id"
        ref="editor"
        class="mt-6"
        :content="initialDoc"
        :links="links"
        @update="(doc) => schedule({ content: doc })"
      />

      <NoteFlashcards :key="`cards-${note.id}-${lockVersion}`" class="mt-16" :note-id="note.id" />

      <section class="mt-10 border-t pt-5">
        <h2 class="mb-2 flex items-center gap-2 text-xs font-medium uppercase tracking-wide text-muted-foreground">
          <Link2 class="size-3.5" /> Backlinks <span class="normal-case tracking-normal">{{ note.backlinks.length || '' }}</span>
        </h2>
        <p v-if="!note.backlinks.length" class="text-sm text-muted-foreground">
          No notes link here yet. Type <kbd class="rounded border px-1 font-mono text-xs">[[{{ note.title }}]]</kbd> in another note.
        </p>
        <ul v-else class="space-y-0.5">
          <li v-for="b in note.backlinks" :key="b.id">
            <RouterLink :to="{ name: 'note', params: { id: b.id } }" class="-mx-2 flex items-center gap-2 rounded-md px-2 py-1.5 text-sm hover:bg-accent">
              <span class="text-muted-foreground">{{ b.icon ?? '📄' }}</span> {{ b.title }}
            </RouterLink>
          </li>
        </ul>
      </section>
    </template>

    <div v-else class="space-y-4 pt-14" aria-busy="true">
      <div class="h-10 w-2/3 animate-pulse rounded bg-muted/60" />
      <div class="h-4 w-full animate-pulse rounded bg-muted/50" />
      <div class="h-4 w-5/6 animate-pulse rounded bg-muted/50" />
    </div>
  </div>
</template>
