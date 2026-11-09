<script setup lang="ts">
import { computed } from 'vue'
import { CircleCheckBig } from '@lucide/vue'
import { Button } from '@/components/ui/button'
import type { Task } from '@/api/tasks'
import { useCompletedTasks } from '@/composables/useTasks'
import { useToday } from '@/composables/useToday'
import { relativeDay, todayIn } from '@/lib/dates'
import EmptyState from './components/EmptyState.vue'
import PageHeader from './components/PageHeader.vue'
import TaskList from './components/TaskList.vue'

/** Completed log (TSK-4), newest first, grouped by the day it was finished. */
const { today, timeZone } = useToday()
const { data, isPending, hasNextPage, fetchNextPage, isFetchingNextPage } = useCompletedTasks()

const groups = computed(() => {
  const byDay = new Map<string, Task[]>()
  for (const task of data.value?.pages.flatMap((p) => p.tasks) ?? []) {
    const day = todayIn(timeZone.value, new Date(task.completed_at!))
    byDay.set(day, [...(byDay.get(day) ?? []), task])
  }
  return [...byDay].map(([day, tasks]) => ({ day, tasks }))
})
</script>

<template>
  <div class="mx-auto max-w-3xl px-6 pb-24 pt-8 md:px-10">
    <PageHeader title="Completed" subtitle="Everything you've finished" />
    <div v-if="isPending" class="space-y-3"><div v-for="i in 4" :key="i" class="h-10 animate-pulse rounded-md bg-muted/60" /></div>
    <EmptyState v-else-if="!groups.length" :icon="CircleCheckBig" title="Nothing completed yet" body="Finished tasks show up here, so you can see how far you've come." />
    <section v-for="group in groups" :key="group.day" class="mb-6">
      <h2 class="mb-1 border-b pb-1.5 text-sm font-semibold">
        {{ relativeDay(group.day, today) }} <span class="font-normal text-muted-foreground">· {{ group.tasks.length }}</span>
      </h2>
      <TaskList :tasks="group.tasks" :show-due="false" />
    </section>
    <div v-if="hasNextPage" class="flex justify-center">
      <Button variant="outline" size="sm" :disabled="isFetchingNextPage" @click="fetchNextPage()">
        {{ isFetchingNextPage ? 'Loading…' : 'Load more' }}
      </Button>
    </div>
  </div>
</template>
