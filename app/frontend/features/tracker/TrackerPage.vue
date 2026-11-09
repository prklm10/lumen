<script setup lang="ts">
import { ref } from 'vue'
import { LineChart, Plus } from '@lucide/vue'
import { Button } from '@/components/ui/button'
import { useTrackers } from '@/composables/useTrackers'
import { useToday } from '@/composables/useToday'
import EmptyState from '@/features/tasks/components/EmptyState.vue'
import PageHeader from '@/features/tasks/components/PageHeader.vue'
import TrackerCard from './components/TrackerCard.vue'
import TrackerDialog from './components/TrackerDialog.vue'

const { today } = useToday()
const { data: trackers, isPending } = useTrackers()
const creating = ref(false)
</script>

<template>
  <div class="mx-auto max-w-4xl px-6 pb-24 pt-8 md:px-10">
    <PageHeader title="Tracker" subtitle="Check in once a day; click a past day to fill it in.">
      <template #actions>
        <Button size="sm" @click="creating = true"><Plus /> New tracker</Button>
      </template>
    </PageHeader>

    <div v-if="isPending" class="grid gap-4 md:grid-cols-2"><div v-for="i in 4" :key="i" class="h-36 animate-pulse rounded-xl bg-muted/60" /></div>
    <EmptyState
      v-else-if="!trackers?.length"
      :icon="LineChart"
      title="Track a habit or a number"
      body="Water, workouts, sleep, reading, energy: anything you want to see trends and streaks for."
    >
      <Button class="mt-5" @click="creating = true"><Plus /> Create your first tracker</Button>
    </EmptyState>
    <div v-else class="grid gap-4 md:grid-cols-2">
      <TrackerCard v-for="tracker in trackers" :key="tracker.id" :tracker="tracker" :today="today" />
    </div>

    <TrackerDialog v-model:open="creating" />
  </div>
</template>
