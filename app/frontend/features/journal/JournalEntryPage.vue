<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, ref, shallowRef, watch } from 'vue'
import { onBeforeRouteLeave, useRoute, useRouter } from 'vue-router'
import { useEventListener, useTextareaAutosize } from '@vueuse/core'
import { toast } from 'vue-sonner'
import { ChevronLeft, Loader2, Lock, MessageSquareQuote, MoreHorizontal, ShieldCheck, Trash2 } from '@lucide/vue'
import {
  DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuSeparator, DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import { Button } from '@/components/ui/button'
import RichEditor from '@/components/editor/RichEditor.vue'
import TagInput from '@/features/tasks/components/TagInput.vue'
import { ApiError } from '@/api/client'
import { journalApi } from '@/api/journal'
import type { RichDoc } from '@/api/tasks'
import { decryptEntry, encryptEntry, type EntryPayload } from '@/lib/crypto/journal'
import { docToText } from '@/lib/richtext'
import { longDay } from '@/lib/dates'
import { useToday } from '@/composables/useToday'
import { errorMessage } from '@/composables/useTasks'
import { api } from '@/api/client'
import { trackersApi, type Tracker } from '@/api/trackers'
import { useAuthStore } from '@/stores/auth'
import JournalGate from './JournalGate.vue'
import MoodPicker from './components/MoodPicker.vue'
import { countWords, prompts, useInvalidateJournal } from './useJournal'
import { journalSession } from './session'

/** Write or edit one entry. Autosaves 2 s after you stop typing — as ciphertext only (JRN-6). */
const props = defineProps<{ id?: string }>()
const route = useRoute()
const router = useRouter()
const { today } = useToday()
const invalidate = useInvalidateJournal()
const auth = useAuthStore()

const entryId = ref(props.id ?? crypto.randomUUID())
const version = ref(0) // 0 = not saved yet
const date = ref(typeof route.query.date === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(route.query.date) ? route.query.date : today.value)
const title = ref(typeof route.query.title === 'string' ? route.query.title.slice(0, 200) : '')
const mood = ref<number | null>(null)
const tags = ref<string[]>([])
const prompt = ref<string | null>(typeof route.query.prompt === 'string' ? route.query.prompt.slice(0, 200) : null)
const doc = shallowRef<RichDoc>({ type: 'doc', content: [] })
const initialDoc = shallowRef<RichDoc | null>(props.id ? null : { type: 'doc', content: [] })
const loadError = ref<string | null>(null)
const { textarea: titleArea } = useTextareaAutosize({ input: title })

type Status = 'idle' | 'dirty' | 'saving' | 'saved' | 'conflict' | 'error'
const status = ref<Status>('idle')
let timer: ReturnType<typeof setTimeout> | undefined
let inFlight: Promise<void> | null = null
let dirty = false
let hydrating = false // filling the fields programmatically isn't an edit

const words = computed(() => countWords(docToText(doc.value)))

// Load and decrypt an existing entry once unlocked.
watch(() => journalSession.state.unlocked, async (unlocked) => {
  if (!unlocked || !props.id || initialDoc.value) return
  try {
    const stored = await journalApi.entry(props.id)
    const payload = await decryptEntry(journalSession.key(), stored)
    version.value = stored.version
    await fill(stored.entry_date, payload)
    mirrored = { date: stored.entry_date, mood: payload.mood }
    initialDoc.value = payload.doc
    status.value = 'saved'
  } catch (e) {
    loadError.value = e instanceof ApiError && e.status === 404 ? 'This entry no longer exists.' : errorMessage(e)
  }
}, { immediate: true })

async function fill(entryDate: string, p: Pick<EntryPayload, 'title' | 'mood' | 'tags' | 'prompt' | 'doc'>) {
  hydrating = true
  date.value = entryDate
  title.value = p.title
  mood.value = p.mood
  tags.value = p.tags
  prompt.value = p.prompt
  doc.value = p.doc
  await nextTick()
  hydrating = false
}

function changed() {
  if (hydrating) return
  dirty = true
  status.value = 'dirty'
  clearTimeout(timer)
  timer = setTimeout(() => save(), 2000)
}

function payload(): EntryPayload {
  return { v: 1, title: title.value.trim(), doc: doc.value, mood: mood.value, tags: tags.value, prompt: prompt.value, word_count: words.value }
}

/**
 * Encrypts and sends the entry. While locking, `key` and a `snapshot` of the content are
 * passed in, because the session key and the on-screen fields are about to be wiped.
 */
async function save(key?: CryptoKey, snapshot?: EntryPayload): Promise<void> {
  clearTimeout(timer)
  if (inFlight) {
    await inFlight
    if (dirty) return save(key, snapshot)
    return
  }
  if (!dirty || status.value === 'conflict') return
  const sessionKey = key ?? (journalSession.state.unlocked ? journalSession.key() : null)
  if (!sessionKey) return

  dirty = false
  status.value = 'saving'
  const next = version.value + 1
  inFlight = (async () => {
    try {
      const { ciphertext, iv } = await encryptEntry(sessionKey, entryId.value, next, snapshot ?? payload())
      const saved = version.value === 0
        ? await journalApi.create({ id: entryId.value, entry_date: date.value, ciphertext, iv })
        : await journalApi.update(entryId.value, { version: version.value, ciphertext, iv, entry_date: date.value })
      const wasNew = version.value === 0
      version.value = saved.version
      mirrorMood()
      status.value = dirty ? 'dirty' : 'saved'
      invalidate()
      if (wasNew && route.name === 'journal-new') router.replace({ name: 'journal-entry', params: { id: entryId.value } })
    } catch (e) {
      dirty = true
      if (e instanceof ApiError && e.code === 'stale_entry') {
        status.value = 'conflict'
        toast.error('This entry changed in another tab', { description: 'Reload it to see the latest version.', duration: Infinity })
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

// Opt-in (Settings → Journal): copy just the mood value to the unencrypted Mood tracker (JRN-5).
let mirrored: { date: string; mood: number | null } | null = null
async function mirrorMood() {
  if (!auth.user?.settings.journal_mood_mirror) return
  const current = { date: date.value, mood: mood.value }
  if (mirrored && mirrored.date === current.date && mirrored.mood === current.mood) return
  if (!mirrored && current.mood === null) return
  try {
    const tracker = await api<Tracker>('/trackers/mood', { method: 'POST' })
    if (mirrored && mirrored.date !== current.date && mirrored.mood !== null) await trackersApi.clear(tracker.id, mirrored.date)
    if (current.mood === null) await trackersApi.clear(tracker.id, current.date)
    else await trackersApi.checkIn(tracker.id, current.date, { value: current.mood })
    mirrored = current
  } catch (e) {
    toast.error(`Mood not copied to the tracker: ${errorMessage(e)}`)
  }
}

// Manual or automatic lock: save what's pending with the key we're handed, wipe the decrypted
// fields from memory, and go to the lock screen (PRD §7.3 "Lock").
const offLock = journalSession.onBeforeLock((key) => {
  if (dirty) save(key, payload())
  initialDoc.value = null
  fill(date.value, { title: '', mood: null, tags: [], prompt: null, doc: { type: 'doc', content: [] } })
  router.replace({ name: 'journal' })
})
onBeforeUnmount(() => {
  offLock()
  if (dirty) save()
})
onBeforeRouteLeave(() => (dirty ? save() : undefined))
useEventListener(window, 'beforeunload', (e) => {
  if (dirty || inFlight) e.preventDefault()
})

watch([title, mood, tags, prompt, date], changed, { deep: true })

async function remove() {
  dirty = false
  clearTimeout(timer)
  if (version.value > 0) await journalApi.destroy(entryId.value)
  invalidate()
  toast('Entry deleted')
  router.push({ name: 'journal' })
}

const statusLabel = computed(() => ({
  idle: 'Not saved yet', dirty: 'Editing…', saving: 'Encrypting & saving…', saved: 'Encrypted · saved', conflict: 'Not saved: changed elsewhere', error: 'Not saved',
})[status.value])
</script>

<template>
  <JournalGate>
    <div class="mx-auto max-w-3xl px-6 pb-32 pt-6 md:px-12">
      <div class="mb-8 flex items-center gap-2 text-xs text-muted-foreground">
        <RouterLink :to="{ name: 'journal' }" class="inline-flex items-center gap-1 hover:text-foreground"><ChevronLeft class="size-3.5" /> Journal</RouterLink>
        <span class="ml-auto inline-flex items-center gap-1" :class="status === 'conflict' || status === 'error' ? 'text-destructive' : ''" aria-live="polite">
          <Loader2 v-if="status === 'saving'" class="size-3 animate-spin" /><ShieldCheck v-else-if="status === 'saved'" class="size-3.5 text-green-600" />
          {{ statusLabel }}
        </span>
        <Button variant="ghost" size="icon-sm" title="Lock (⌘⇧L)" aria-label="Lock journal" @click="journalSession.lock()"><Lock /></Button>
        <DropdownMenu>
          <DropdownMenuTrigger as-child>
            <Button variant="ghost" size="icon-sm" aria-label="Entry actions"><MoreHorizontal /></Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end" class="w-60">
            <DropdownMenuItem v-for="p in prompts" :key="p" @select="prompt = p"><MessageSquareQuote /> {{ p }}</DropdownMenuItem>
            <DropdownMenuItem v-if="prompt" @select="prompt = null">Remove prompt</DropdownMenuItem>
            <DropdownMenuSeparator />
            <DropdownMenuItem variant="destructive" @select="remove"><Trash2 /> Delete entry</DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>

      <p v-if="loadError" class="pt-10 text-center text-muted-foreground">{{ loadError }}</p>
      <div v-else-if="!initialDoc" class="flex justify-center pt-16 text-muted-foreground"><Loader2 class="size-5 animate-spin" /></div>

      <template v-else>
        <div class="flex flex-wrap items-center justify-between gap-3">
          <label class="text-sm text-muted-foreground">
            <span class="sr-only">Entry date</span>
            <input v-model="date" type="date" :max="today" class="rounded-md bg-transparent px-1 py-0.5 hover:bg-accent" aria-label="Entry date">
            <span class="ml-1 hidden sm:inline">{{ longDay(date) }}</span>
          </label>
          <MoodPicker v-model="mood" />
        </div>

        <textarea
          ref="titleArea"
          v-model="title"
          rows="1"
          maxlength="200"
          class="mt-4 w-full resize-none bg-transparent text-3xl font-bold leading-tight tracking-tight outline-none placeholder:text-muted-foreground/40"
          placeholder="Title (optional)"
          aria-label="Entry title"
          @keydown.enter.prevent
        />
        <p v-if="prompt" class="mt-2 flex items-center gap-2 text-sm italic text-muted-foreground">
          <MessageSquareQuote class="size-4" /> {{ prompt }}
        </p>

        <RichEditor
          :key="entryId"
          class="mt-6"
          journal
          :content="initialDoc"
          placeholder="Write freely. Type / for blocks."
          @update="(d) => { doc = d; changed() }"
        />

        <div class="mt-10 flex flex-wrap items-center gap-3 border-t pt-4 text-xs text-muted-foreground">
          <div class="min-w-48 flex-1"><TagInput v-model="tags" /></div>
          <span class="tabular-nums">{{ words }} {{ words === 1 ? 'word' : 'words' }}</span>
        </div>
      </template>
    </div>
  </JournalGate>
</template>
