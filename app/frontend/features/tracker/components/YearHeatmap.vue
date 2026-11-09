<script setup lang="ts">
import { computed } from 'vue'
import type { Tracker, TrackerEntry } from '@/api/trackers'
import { addDays, longDay } from '@/lib/dates'
import { colorClasses } from '@/lib/colors'
import { formatValue, intensity, isoWeekday } from '@/lib/trackers'

/** GitHub-style year of check-ins (TRK-5): 53 week columns × 7 weekday rows, Monday first. */
const props = defineProps<{ tracker: Tracker; entries: TrackerEntry[]; today: string }>()

const CELL = 11
const GAP = 3
const LEFT = 28
const TOP = 16
const opacity = [0, 0.3, 0.5, 0.75, 1]

const byDate = computed(() => new Map(props.entries.map((e) => [e.logged_on, e])))
// Start on the Monday 52 weeks before this week's Monday.
const start = computed(() => addDays(props.today, -(isoWeekday(props.today) - 1) - 52 * 7))

const cells = computed(() => {
  const out: { date: string; x: number; y: number; level: number; label: string }[] = []
  for (let i = 0; ; i++) {
    const date = addDays(start.value, i)
    if (date > props.today) break
    const entry = byDate.value.get(date)
    out.push({
      date,
      x: LEFT + Math.floor(i / 7) * (CELL + GAP),
      y: TOP + (i % 7) * (CELL + GAP),
      level: intensity(props.tracker, entry?.value),
      label: `${longDay(date)}: ${entry ? formatValue(props.tracker, entry.value) : 'no check-in'}${entry?.note ? ` — ${entry.note}` : ''}`,
    })
  }
  return out
})

const months = computed(() => {
  const labels: { x: number; text: string }[] = []
  let last = ''
  for (const c of cells.value) {
    const month = c.date.slice(0, 7)
    if (c.y === TOP && month !== last && c.date.slice(8) <= '07') {
      labels.push({ x: c.x, text: new Intl.DateTimeFormat('en-US', { month: 'short', timeZone: 'UTC' }).format(new Date(`${c.date}T12:00:00Z`)) })
      last = month
    }
  }
  return labels
})

const width = LEFT + 53 * (CELL + GAP)
const height = TOP + 7 * (CELL + GAP)
const total = computed(() => props.entries.filter((e) => e.value > 0).length)
</script>

<template>
  <figure>
    <div class="overflow-x-auto">
      <svg :viewBox="`0 0 ${width} ${height}`" :width="width" :height="height" class="block" :class="colorClasses(tracker.color).text" role="img" :aria-label="`${total} check-ins in the last year`">
        <text v-for="m in months" :key="m.x" :x="m.x" :y="10" class="fill-muted-foreground text-[9px]">{{ m.text }}</text>
        <text v-for="(d, i) in ['Mon', '', 'Wed', '', 'Fri', '', '']" :key="i" :x="0" :y="TOP + i * (CELL + GAP) + 9" class="fill-muted-foreground text-[9px]">{{ d }}</text>
        <rect
          v-for="c in cells"
          :key="c.date"
          :x="c.x"
          :y="c.y"
          :width="CELL"
          :height="CELL"
          rx="2.5"
          :fill="c.level ? 'currentColor' : 'var(--muted)'"
          :fill-opacity="c.level ? opacity[c.level] : 1"
          :stroke="c.date === today ? 'var(--foreground)' : 'none'"
          stroke-width="1"
        >
          <title>{{ c.label }}</title>
        </rect>
      </svg>
    </div>
    <figcaption class="mt-2 flex items-center justify-between text-xs text-muted-foreground">
      <span>{{ total }} check-ins in the last year</span>
      <span class="flex items-center gap-1" :class="colorClasses(tracker.color).text">
        <span class="text-muted-foreground">Less</span>
        <svg v-for="level in [0, 1, 2, 3, 4]" :key="level" width="10" height="10"><rect width="10" height="10" rx="2" :fill="level ? 'currentColor' : 'var(--muted)'" :fill-opacity="level ? opacity[level] : 1" /></svg>
        <span class="text-muted-foreground">More</span>
      </span>
    </figcaption>
  </figure>
</template>
