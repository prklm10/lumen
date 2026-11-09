<script setup lang="ts">
import { ref } from 'vue'
import { useMutation, useQuery, useQueryClient } from '@tanstack/vue-query'
import { toast } from 'vue-sonner'
import { Brain, Plus, Trash2 } from '@lucide/vue'
import { studyApi } from '@/api/study'
import { errorMessage } from '@/composables/useTasks'

/** A note's flashcards: ones written as "Q :: A" in the text, plus ones added here. */
const props = defineProps<{ noteId: number }>()
const client = useQueryClient()
const { data: cards } = useQuery({ queryKey: ['flashcards', 'note', props.noteId], queryFn: () => studyApi.cards({ note_id: props.noteId }) })
const front = ref('')
const back = ref('')
const refresh = () => client.invalidateQueries({ queryKey: ['flashcards'] })
const create = useMutation({ mutationFn: studyApi.createCard, onSuccess: () => { front.value = back.value = ''; refresh() }, onError: (e) => toast.error(errorMessage(e)) })
const remove = useMutation({ mutationFn: studyApi.destroyCard, onSuccess: refresh })

defineExpose({ refresh })
</script>

<template>
  <section class="mt-10 border-t pt-5">
    <h2 class="mb-2 flex items-center gap-2 text-xs font-medium uppercase tracking-wide text-muted-foreground">
      <Brain class="size-3.5" /> Flashcards <span class="normal-case tracking-normal">{{ cards?.length || '' }}</span>
      <RouterLink v-if="cards?.length" :to="{ name: 'review' }" class="ml-auto normal-case tracking-normal text-primary hover:underline">Review →</RouterLink>
    </h2>
    <ul v-if="cards?.length" class="mb-3 divide-y rounded-lg border text-sm">
      <li v-for="c in cards" :key="c.id" class="group grid grid-cols-[1fr_1fr_auto] gap-3 px-3 py-2">
        <span class="font-medium">{{ c.front }}</span>
        <span class="text-muted-foreground">{{ c.back }}</span>
        <span class="flex items-center gap-2 text-xs text-muted-foreground">
          <span v-if="c.from_note_syntax" title="Written as “Question :: Answer” in this note">::</span>
          <button v-else type="button" class="opacity-0 hover:text-destructive group-hover:opacity-100" aria-label="Delete card" @click="remove.mutate(c.id)"><Trash2 class="size-3.5" /></button>
        </span>
      </li>
    </ul>
    <form class="grid grid-cols-[1fr_1fr_auto] gap-2" @submit.prevent="front.trim() && back.trim() && create.mutate({ note_id: noteId, front: front.trim(), back: back.trim() })">
      <input v-model="front" class="h-8 rounded-md border bg-transparent px-2 text-sm" placeholder="Question" aria-label="Question" maxlength="1000">
      <input v-model="back" class="h-8 rounded-md border bg-transparent px-2 text-sm" placeholder="Answer" aria-label="Answer" maxlength="4000">
      <button type="submit" class="flex size-8 items-center justify-center rounded-md border hover:bg-accent" aria-label="Add card"><Plus class="size-4" /></button>
    </form>
    <p class="mt-2 text-xs text-muted-foreground">Tip: a line like <code class="rounded bg-muted px-1">What is MVCC? :: Multi-version concurrency control</code> in the note becomes a card too.</p>
  </section>
</template>
