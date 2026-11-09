<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { refDebounced } from '@vueuse/core'
import { History, Loader2, Search, X } from '@lucide/vue'
import type { StoredEntry } from '@/api/journal'
import type { EntryPayload } from '@/lib/crypto/journal'
import { docToText } from '@/lib/richtext'
import { longDay } from '@/lib/dates'
import { excerpt, loadAllEntries, moodEmoji } from '../useJournal'

/**
 * Journal search (JRN-8) and "On this day" (JRN-9), both done here in the browser on decrypted
 * entries: the server only has ciphertext. Decrypted entries live in this component's memory
 * and vanish with it when the journal locks.
 */
const props = defineProps<{ today: string; dates: string[] }>()
const emit = defineEmits<{ searching: [active: boolean] }>()

const all = ref<{ entry: StoredEntry; payload: EntryPayload }[] | null>(null)
const loading = ref(false)
const query = ref('')
const debounced = refDebounced(query, 200)

async function ensureLoaded() {
  if (all.value || loading.value || !props.dates.length) return
  loading.value = true
  try {
    all.value = await loadAllEntries([...props.dates].sort()[0]!, props.today)
  } finally {
    loading.value = false
  }
}

// "On this day": same month and day, earlier years. Only needs the dates to know if there are any.
const monthDay = computed(() => props.today.slice(5))
const hasPast = computed(() => props.dates.some((d) => d.slice(5) === monthDay.value && d < props.today))
watch(hasPast, (yes) => yes && ensureLoaded(), { immediate: true })
const onThisDay = computed(() => (all.value ?? []).filter((e) => e.entry.entry_date.slice(5) === monthDay.value && e.entry.entry_date < props.today))

const results = computed(() => {
  const words = debounced.value.toLowerCase().split(/\s+/).filter(Boolean)
  if (!words.length || !all.value) return []
  return all.value.filter(({ payload }) => {
    const haystack = `${payload.title} ${docToText(payload.doc)} ${payload.tags.join(' ')} ${payload.prompt ?? ''}`.toLowerCase()
    return words.every((w) => haystack.includes(w))
  })
})
watch(query, (q) => {
  emit('searching', !!q.trim())
  if (q.trim()) ensureLoaded()
})

const yearsAgo = (date: string) => Number(props.today.slice(0, 4)) - Number(date.slice(0, 4))
</script>

<template>
  <div class="space-y-4">
    <label class="relative block">
      <Search class="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
      <input v-model="query" class="h-9 w-full rounded-lg border bg-card pl-9 pr-8 text-sm outline-none focus:border-ring" placeholder="Search your journal…" aria-label="Search your journal">
      <button v-if="query" type="button" class="absolute right-2 top-1/2 -translate-y-1/2 text-muted-foreground" aria-label="Clear search" @click="query = ''"><X class="size-4" /></button>
    </label>

    <template v-if="query.trim()">
      <p v-if="loading" class="flex items-center gap-2 text-sm text-muted-foreground"><Loader2 class="size-4 animate-spin" /> Decrypting your journal to search it…</p>
      <p v-else class="text-xs text-muted-foreground">{{ results.length }} {{ results.length === 1 ? 'entry' : 'entries' }} · searched on this device</p>
      <ul class="space-y-2">
        <li v-for="r in results" :key="r.entry.id">
          <RouterLink :to="{ name: 'journal-entry', params: { id: r.entry.id } }" class="block rounded-lg border bg-card p-3 hover:border-primary/40">
            <p class="text-xs text-muted-foreground">{{ longDay(r.entry.entry_date) }}, {{ r.entry.entry_date.slice(0, 4) }} {{ moodEmoji(r.payload.mood) }}</p>
            <p class="font-medium">{{ r.payload.title || 'Untitled' }}</p>
            <p class="line-clamp-2 text-sm text-muted-foreground">{{ excerpt(r.payload) }}</p>
          </RouterLink>
        </li>
      </ul>
    </template>

    <section v-else-if="onThisDay.length" class="rounded-xl border border-primary/20 bg-primary/5 p-4">
      <h3 class="mb-2 flex items-center gap-2 text-sm font-medium"><History class="size-4 text-primary" /> On this day</h3>
      <ul class="space-y-2">
        <li v-for="r in onThisDay" :key="r.entry.id">
          <RouterLink :to="{ name: 'journal-entry', params: { id: r.entry.id } }" class="block text-sm hover:underline">
            <span class="text-muted-foreground">{{ yearsAgo(r.entry.entry_date) }} {{ yearsAgo(r.entry.entry_date) === 1 ? 'year' : 'years' }} ago · </span>{{ r.payload.title || excerpt(r.payload, 80) }}
          </RouterLink>
        </li>
      </ul>
    </section>
  </div>
</template>
