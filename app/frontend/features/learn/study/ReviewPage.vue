<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useQuery, useQueryClient } from '@tanstack/vue-query'
import { onKeyStroke } from '@vueuse/core'
import { toast } from 'vue-sonner'
import { Brain, PartyPopper } from '@lucide/vue'
import { Button } from '@/components/ui/button'
import { studyApi, type Flashcard } from '@/api/study'
import { errorMessage } from '@/composables/useTasks'
import EmptyState from '@/features/tasks/components/EmptyState.vue'
import PageHeader from '@/features/tasks/components/PageHeader.vue'

/** Spaced-repetition review (LRN-11). Space shows the answer; 1–4 grade it. */
const client = useQueryClient()
const { data, isPending } = useQuery({ queryKey: ['flashcards', 'due'], queryFn: studyApi.due, refetchOnWindowFocus: false })

const queue = ref<Flashcard[]>([])
const revealed = ref(false)
const done = ref(0)
const busy = ref(false)
watch(data, (d) => d && (queue.value = [...d.flashcards]), { immediate: true })
const card = computed(() => queue.value[0])

const grades = [
  { grade: 1, label: 'Again', key: '1' },
  { grade: 3, label: 'Hard', key: '2' },
  { grade: 4, label: 'Good', key: '3' },
  { grade: 5, label: 'Easy', key: '4' },
]
const days = (n: number | undefined) => (n === undefined ? '' : n === 1 ? '1 day' : n < 30 ? `${n} days` : n < 365 ? `${Math.round(n / 30)} mo` : `${(n / 365).toFixed(1)} yr`)

async function grade(g: number) {
  if (!card.value || !revealed.value || busy.value) return
  busy.value = true
  const current = card.value
  try {
    await studyApi.review(current.id, g)
    queue.value.shift()
    if (g < 3) queue.value.push(current) // a lapse comes back in this session
    else done.value++
    revealed.value = false
    if (!queue.value.length) client.invalidateQueries({ queryKey: ['flashcards'] })
  } catch (e) {
    toast.error(errorMessage(e))
  } finally {
    busy.value = false
  }
}

onKeyStroke(' ', (e) => {
  if (card.value && !revealed.value && !(e.target as HTMLElement).closest('input, textarea')) {
    e.preventDefault()
    revealed.value = true
  }
})
for (const g of grades) onKeyStroke(g.key, () => grade(g.grade))
</script>

<template>
  <div class="mx-auto max-w-2xl px-6 pb-24 pt-8 md:px-10">
    <PageHeader title="Review" :subtitle="data ? `${data.due_count} due · ${data.total} ${data.total === 1 ? 'card' : 'cards'} in total` : undefined" />
    <div v-if="isPending" class="h-64 animate-pulse rounded-2xl bg-muted/60" />
    <EmptyState v-else-if="!data?.total" :icon="Brain" title="No flashcards yet" body="Write “Question :: Answer” on a line in any note, or add cards from a note’s Flashcards section." />
    <EmptyState v-else-if="!card" :icon="PartyPopper" :title="done ? `Done: ${done} reviewed` : 'All caught up'" :body="data.upcoming.length ? `Next up: ${data.upcoming.map((u) => `${u.count} on ${u.date.slice(5)}`).join(', ')}` : 'Nothing due this week.'" />
    <template v-else>
      <p class="mb-3 text-center text-xs text-muted-foreground">{{ queue.length }} left in this session</p>
      <article class="rounded-2xl border bg-card p-8 text-center shadow-xs">
        <p class="whitespace-pre-wrap text-xl font-medium leading-relaxed">{{ card.front }}</p>
        <template v-if="revealed">
          <div class="mx-auto my-6 h-px w-16 bg-border" />
          <p class="whitespace-pre-wrap text-lg leading-relaxed text-muted-foreground">{{ card.back }}</p>
        </template>
        <RouterLink v-if="card.note_id" :to="{ name: 'note', params: { id: card.note_id } }" class="mt-6 inline-block text-xs text-muted-foreground hover:text-foreground">From a note →</RouterLink>
      </article>
      <div class="mt-6">
        <Button v-if="!revealed" class="w-full" size="lg" @click="revealed = true">Show answer <kbd class="ml-2 rounded border border-primary-foreground/30 px-1 text-xs">Space</kbd></Button>
        <div v-else class="grid grid-cols-4 gap-2">
          <Button v-for="g in grades" :key="g.grade" variant="outline" class="h-auto flex-col gap-0.5 py-2" :disabled="busy" @click="grade(g.grade)">
            <span>{{ g.label }}</span>
            <span class="text-xs font-normal text-muted-foreground">{{ days(card.preview?.[g.grade]) }} · {{ g.key }}</span>
          </Button>
        </div>
      </div>
    </template>
  </div>
</template>
