<script setup lang="ts">
import { computed, nextTick, watch } from 'vue'
import { refDebounced } from '@vueuse/core'
import { useQuery } from '@tanstack/vue-query'
import { injectListboxRootContext, ListboxGroup, ListboxGroupLabel, ListboxItem } from 'reka-ui'
import { CheckSquare, CircleCheckBig, FileText } from '@lucide/vue'
import { useCommand } from '@/components/ui/command'
import { searchApi } from '@/api/notes'

/**
 * Server-side search (notes + tasks, never the journal) inside the ⌘K palette. Rendered with
 * plain Listbox parts rather than CommandGroup/CommandItem: those are filtered client-side,
 * which would hide results that arrive after the filter ran.
 */
const emit = defineEmits<{ note: [id: number]; task: [id: number] }>()
const { filterState } = useCommand()
const search = computed(() => filterState.search.trim())
const debounced = refDebounced(search, 150)
const enabled = computed(() => debounced.value.length >= 2)

const { data, isFetching } = useQuery({
  queryKey: computed(() => ['search', debounced.value]),
  queryFn: () => searchApi.search(debounced.value),
  enabled,
  placeholderData: (previous) => previous,
})

const results = computed(() => (enabled.value && search.value.length >= 2 ? data.value : undefined))
const count = computed(() => (results.value?.notes.length ?? 0) + (results.value?.tasks.length ?? 0))

// Snippets mark matches with \u0002…\u0003; split them into parts instead of rendering HTML.
function highlight(snippet: string) {
  return snippet.split(/(\u0002[^\u0003]*\u0003)/).filter(Boolean).map((part) =>
    part.startsWith('\u0002') ? { text: part.slice(1, -1), mark: true } : { text: part, mark: false })
}

// Results arrive after the input's own "highlight first match" ran; redo it so Enter opens the top hit.
const listbox = injectListboxRootContext()
watch(count, async () => {
  await nextTick() // items register with the listbox on mount, a tick after they render
  const current = listbox.highlightedElement.value
  // The highlighted item may be one the filter just removed (detached) or hid.
  if (count.value && (!current?.isConnected || current.offsetParent === null)) listbox.highlightFirstItem()
})

const nothing = computed(() => search.value && filterState.filtered.count === 0 && !count.value && !isFetching.value)
const itemClass = 'relative flex cursor-default items-start gap-2 rounded-sm px-2 py-1.5 text-sm outline-hidden select-none data-[highlighted]:bg-accent data-[highlighted]:text-accent-foreground [&_svg]:mt-0.5 [&_svg]:size-4 [&_svg]:shrink-0 [&_svg]:text-muted-foreground'
</script>

<template>
  <ListboxGroup v-if="results?.notes.length" class="overflow-hidden p-1 text-foreground">
    <ListboxGroupLabel class="px-2 py-1.5 text-xs font-medium text-muted-foreground">Notes</ListboxGroupLabel>
    <ListboxItem v-for="note in results.notes" :key="`n${note.id}`" :value="`note-${note.id}`" :class="itemClass" @select="emit('note', note.id)">
      <FileText />
      <span class="min-w-0 flex-1">
        <span class="block truncate">{{ note.title }}</span>
        <span v-if="note.snippet" class="line-clamp-2 text-xs text-muted-foreground">
          <template v-for="(part, i) in highlight(note.snippet)" :key="i">
            <mark v-if="part.mark" class="rounded-sm bg-primary/15 px-0.5 text-foreground">{{ part.text }}</mark>
            <template v-else>{{ part.text }}</template>
          </template>
        </span>
      </span>
    </ListboxItem>
  </ListboxGroup>
  <ListboxGroup v-if="results?.tasks.length" class="overflow-hidden p-1 text-foreground">
    <ListboxGroupLabel class="px-2 py-1.5 text-xs font-medium text-muted-foreground">Tasks</ListboxGroupLabel>
    <ListboxItem v-for="task in results.tasks" :key="`t${task.id}`" :value="`task-${task.id}`" :class="itemClass" @select="emit('task', task.id)">
      <component :is="task.status === 'done' ? CircleCheckBig : CheckSquare" />
      <span class="truncate" :class="task.status === 'done' && 'text-muted-foreground line-through'">{{ task.title }}</span>
    </ListboxItem>
  </ListboxGroup>
  <p v-if="nothing" class="py-6 text-center text-sm">No results.</p>
</template>
