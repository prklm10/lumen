<script setup lang="ts">
import { computed } from 'vue'
import { BookOpen, CheckSquare, LineChart, Lock } from '@lucide/vue'
import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()
const timeZone = computed(() => auth.user?.time_zone ?? 'UTC')
const now = new Date()

const greeting = computed(() => {
  const hour = Number(new Intl.DateTimeFormat('en-US', { hour: 'numeric', hourCycle: 'h23', timeZone: timeZone.value }).format(now))
  if (hour < 5) return 'Good night'
  if (hour < 12) return 'Good morning'
  if (hour < 18) return 'Good afternoon'
  return 'Good evening'
})

const dateLabel = computed(() =>
  new Intl.DateTimeFormat('en-US', { weekday: 'long', month: 'long', day: 'numeric', timeZone: timeZone.value }).format(now),
)

const cards = [
  { title: 'Tasks', icon: CheckSquare, empty: 'Nothing due today.', phase: 1 },
  { title: 'Habits', icon: LineChart, empty: 'No habits to check in.', phase: 3 },
  { title: 'Learning', icon: BookOpen, empty: 'No flashcards due.', phase: 2 },
]
</script>

<template>
  <div class="mx-auto max-w-3xl px-6 pb-16 pt-10 md:px-10">
    <p class="text-sm text-muted-foreground">{{ dateLabel }}</p>
    <h1 class="mt-1 text-3xl font-semibold tracking-tight">{{ greeting }}</h1>

    <div class="mt-8 flex items-center gap-3 rounded-lg border bg-card px-3 py-2.5 text-muted-foreground">
      <span class="text-lg leading-none text-primary">+</span>
      <span>Quick add a task… <span class="text-xs">(arrives in Phase 1)</span></span>
    </div>

    <section class="mt-6 overflow-hidden rounded-xl border bg-card">
      <div class="flex items-center gap-3 p-5">
        <div class="flex size-9 items-center justify-center rounded-lg bg-primary/10 text-primary">
          <Lock class="size-4" />
        </div>
        <div class="flex-1">
          <h2 class="font-medium">Today's journal</h2>
          <p class="text-muted-foreground">Encrypted on this device before it's saved. Arrives in Phase 4.</p>
        </div>
      </div>
    </section>

    <div class="mt-4 grid gap-4 sm:grid-cols-3">
      <section v-for="card in cards" :key="card.title" class="rounded-xl border bg-card p-5">
        <div class="flex items-center gap-2 font-medium">
          <component :is="card.icon" class="size-4 text-muted-foreground" />
          {{ card.title }}
        </div>
        <p class="mt-3 text-muted-foreground">{{ card.empty }}</p>
        <p class="mt-4 text-xs text-muted-foreground/80">Phase {{ card.phase }}</p>
      </section>
    </div>
  </div>
</template>
