<script setup lang="ts">
import { computed } from 'vue'
import { Flame, LockOpen } from '@lucide/vue'
import type { Tracker } from '@/api/trackers'
import { frequencyLabel, isScheduled, targetLabel } from '@/lib/trackers'
import CheckInControl from './CheckInControl.vue'
import WeekStrip from './WeekStrip.vue'

const props = defineProps<{ tracker: Tracker; today: string }>()
const scheduledToday = computed(() => isScheduled(props.tracker, props.today))
const rate = computed(() => (props.tracker.stats.completion_rate === null ? null : Math.round(props.tracker.stats.completion_rate * 100)))
</script>

<template>
  <article class="rounded-xl border bg-card p-4 transition-colors hover:border-border/80">
    <div class="flex items-start gap-3">
      <RouterLink :to="{ name: 'tracker-detail', params: { id: tracker.id } }" class="flex min-w-0 flex-1 items-start gap-3">
        <span class="flex size-10 shrink-0 items-center justify-center rounded-lg bg-muted text-xl">{{ tracker.icon ?? '✅' }}</span>
        <span class="min-w-0">
          <span class="flex items-center gap-1.5 truncate font-medium hover:underline">
            {{ tracker.name }}
            <LockOpen v-if="tracker.system_key === 'mood'" class="size-3 text-muted-foreground" aria-label="Not encrypted" title="Tracker data isn’t encrypted. Mood copied from the journal is stored here as plain numbers." />
          </span>
          <span class="block truncate text-xs text-muted-foreground">
            {{ frequencyLabel(tracker.frequency) }}<template v-if="targetLabel(tracker)"> · {{ targetLabel(tracker) }}</template>
          </span>
        </span>
      </RouterLink>
      <CheckInControl v-if="scheduledToday" :tracker="tracker" :date="today" />
      <span v-else class="mt-2 text-xs text-muted-foreground">Rest day</span>
    </div>

    <div class="mt-4 flex items-end justify-between gap-3">
      <WeekStrip :tracker="tracker" :today="today" />
      <div class="flex shrink-0 items-center gap-3 text-xs text-muted-foreground">
        <span class="inline-flex items-center gap-1" :title="`Longest: ${tracker.stats.longest_streak}`">
          <Flame class="size-3.5" :class="tracker.stats.current_streak ? 'text-orange-500' : ''" />
          <span class="font-medium tabular-nums text-foreground">{{ tracker.stats.current_streak }}</span>
          {{ tracker.frequency.type === 'weekly' ? 'wk' : 'd' }}
        </span>
        <span v-if="rate !== null" title="Completion, last 30 days"><span class="font-medium tabular-nums text-foreground">{{ rate }}%</span> 30d</span>
      </div>
    </div>
  </article>
</template>
