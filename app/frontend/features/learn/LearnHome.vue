<script setup lang="ts">
import { computed } from 'vue'
import { BookOpen, FilePlus2, Pin } from '@lucide/vue'
import { Button } from '@/components/ui/button'
import { useNotesList } from '@/composables/useNotes'
import { useToday } from '@/composables/useToday'
import { relativeDay, todayIn } from '@/lib/dates'
import EmptyState from '@/features/tasks/components/EmptyState.vue'
import PageHeader from '@/features/tasks/components/PageHeader.vue'
import { useCreateNote } from './useCreateNote'

/** Learn home: pinned notes and recently edited ones (LRN-15). */
const { data: notes, isPending } = useNotesList()
const { today, timeZone } = useToday()
const createNote = useCreateNote()

const pinned = computed(() => (notes.value ?? []).filter((n) => n.pinned))
const recent = computed(() => [...(notes.value ?? [])].sort((a, b) => Date.parse(b.updated_at) - Date.parse(a.updated_at)).slice(0, 12))
const edited = (iso: string) => relativeDay(todayIn(timeZone.value, new Date(iso)), today.value)
</script>

<template>
  <div class="mx-auto max-w-3xl px-6 pb-24 pt-8 md:px-10">
    <PageHeader title="Learn" subtitle="Notes that link to each other">
      <template #actions>
        <Button size="sm" @click="createNote()"><FilePlus2 /> New note</Button>
      </template>
    </PageHeader>

    <div v-if="isPending" class="grid gap-3 sm:grid-cols-3"><div v-for="i in 3" :key="i" class="h-20 animate-pulse rounded-xl bg-muted/60" /></div>

    <EmptyState v-else-if="!notes?.length" :icon="BookOpen" title="Start your knowledge base" body="Write notes, link them with [[double brackets]], paste images, and tag ideas with #hashtags.">
      <Button class="mt-5" @click="createNote()"><FilePlus2 /> Write your first note</Button>
    </EmptyState>

    <template v-else>
      <section v-if="pinned.length" class="mb-10">
        <h2 class="mb-3 flex items-center gap-1.5 text-xs font-medium uppercase tracking-wide text-muted-foreground"><Pin class="size-3.5" /> Pinned</h2>
        <div class="grid gap-3 sm:grid-cols-3">
          <RouterLink
            v-for="note in pinned"
            :key="note.id"
            :to="{ name: 'note', params: { id: note.id } }"
            class="rounded-xl border bg-card p-4 transition-colors hover:border-primary/40 hover:bg-accent/40"
          >
            <span class="text-lg">{{ note.icon ?? '📄' }}</span>
            <p class="mt-2 line-clamp-2 font-medium">{{ note.title }}</p>
          </RouterLink>
        </div>
      </section>

      <section>
        <h2 class="mb-1 border-b pb-1.5 text-xs font-medium uppercase tracking-wide text-muted-foreground">Recently edited</h2>
        <RouterLink
          v-for="note in recent"
          :key="note.id"
          :to="{ name: 'note', params: { id: note.id } }"
          class="-mx-2 flex items-center gap-3 rounded-md px-2 py-2 hover:bg-accent"
        >
          <span class="text-muted-foreground">{{ note.icon ?? '📄' }}</span>
          <span class="flex-1 truncate">{{ note.title }}</span>
          <span class="text-xs text-muted-foreground">{{ edited(note.updated_at) }}</span>
        </RouterLink>
      </section>
    </template>
  </div>
</template>
