<script setup lang="ts">
import { ref } from 'vue'
import { toast } from 'vue-sonner'
import { Download, FileArchive, FileJson, Loader2, Lock } from '@lucide/vue'
import { Button } from '@/components/ui/button'
import { journalApi } from '@/api/journal'
import { useToday } from '@/composables/useToday'
import { errorMessage } from '@/composables/useTasks'
import { docToText } from '@/lib/richtext'
import { longDay } from '@/lib/dates'
import { journalSession } from '@/features/journal/session'
import { fetchAllStored, loadAllEntries, moodEmoji } from '@/features/journal/useJournal'

/** Exports (PRD §11 "no lock-in", JRN-12). Journal exports are built in the browser. */
const { today } = useToday()
const busy = ref<string | null>(null)

function download(name: string, content: BlobPart, type: string) {
  const url = URL.createObjectURL(new Blob([content], { type }))
  Object.assign(document.createElement('a'), { href: url, download: name }).click()
  setTimeout(() => URL.revokeObjectURL(url), 1000)
}

async function journalEntries() {
  const { dates } = await journalApi.dates()
  return dates.length ? loadAllEntries(dates[0]!.entry_date, today.value) : []
}

// Still encrypted: restorable/decryptable later with the passphrase or recovery key.
async function exportEncrypted() {
  busy.value = 'encrypted'
  try {
    const vault = await journalApi.vault()
    const { dates } = await journalApi.dates()
    const entries = dates.length ? await fetchAllStored(dates[0]!.entry_date, today.value) : []
    download(`lumen-journal-${today.value}.lumenvault`, JSON.stringify({ format: 'lumenvault/v1', vault, entries }, null, 2), 'application/json')
  } catch (e) {
    toast.error(errorMessage(e))
  } finally {
    busy.value = null
  }
}

// Decrypted, as one Markdown file. Only possible while unlocked — and the file is plaintext.
async function exportMarkdown() {
  busy.value = 'markdown'
  try {
    const all = await journalEntries()
    const md = all.map(({ entry, payload }) => [
      `## ${longDay(entry.entry_date)}, ${entry.entry_date.slice(0, 4)}${payload.title ? ` — ${payload.title}` : ''} ${moodEmoji(payload.mood) ?? ''}`.trim(),
      payload.prompt ? `> ${payload.prompt}` : null,
      docToText(payload.doc),
      payload.tags.length ? payload.tags.map((t) => `#${t}`).join(' ') : null,
    ].filter(Boolean).join('\n\n')).join('\n\n---\n\n')
    download(`lumen-journal-${today.value}.md`, `# Journal\n\n${md}\n`, 'text/markdown')
  } catch (e) {
    toast.error(errorMessage(e))
  } finally {
    busy.value = null
  }
}
</script>

<template>
  <section class="mt-10">
    <h2 class="font-medium">Your data</h2>
    <div class="mt-3 divide-y rounded-lg border bg-card">
      <div class="flex flex-wrap items-center justify-between gap-3 px-4 py-3">
        <span><span class="block">Everything</span><span class="text-xs text-muted-foreground">Tasks, notes, trackers, learning — one JSON file (journal stays encrypted)</span></span>
        <Button as="a" href="/api/v1/export" variant="outline" size="sm"><FileJson /> Download JSON</Button>
      </div>
      <div class="flex flex-wrap items-center justify-between gap-3 px-4 py-3">
        <span><span class="block">Notes as Markdown</span><span class="text-xs text-muted-foreground">One .md file per note, in your folders (Obsidian-compatible)</span></span>
        <Button as="a" href="/api/v1/export/notes" variant="outline" size="sm"><FileArchive /> Download .tar.gz</Button>
      </div>
      <div class="flex flex-wrap items-center justify-between gap-3 px-4 py-3">
        <span><span class="block">Journal (encrypted)</span><span class="text-xs text-muted-foreground">A .lumenvault file: unreadable without your passphrase or recovery key</span></span>
        <Button variant="outline" size="sm" :disabled="busy !== null" @click="exportEncrypted"><Loader2 v-if="busy === 'encrypted'" class="animate-spin" /><Download v-else /> Download</Button>
      </div>
      <div class="flex flex-wrap items-center justify-between gap-3 px-4 py-3">
        <span>
          <span class="block">Journal (decrypted Markdown)</span>
          <span class="text-xs text-muted-foreground">Decrypted on this device. <strong class="font-medium text-amber-600 dark:text-amber-500">The file is readable by anyone who gets it.</strong></span>
        </span>
        <Button v-if="journalSession.state.unlocked" variant="outline" size="sm" :disabled="busy !== null" @click="exportMarkdown"><Loader2 v-if="busy === 'markdown'" class="animate-spin" /><Download v-else /> Download</Button>
        <RouterLink v-else :to="{ name: 'journal' }" class="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground"><Lock class="size-3.5" /> Unlock the journal first</RouterLink>
      </div>
    </div>
    <p class="mt-2 text-xs text-muted-foreground">Full backups (database + uploads) are made from the terminal: <code class="rounded bg-muted px-1">make backup</code>.</p>
  </section>
</template>
