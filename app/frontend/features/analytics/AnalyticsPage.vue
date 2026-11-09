<script setup lang="ts">
import { computed } from 'vue'
import { useStorage } from '@vueuse/core'
import { keepPreviousData, useQuery } from '@tanstack/vue-query'
import { Flame } from '@lucide/vue'
import { analyticsApi, type AnalyticsRange, type RangeKey } from '@/api/analytics'
import BarList from '@/components/charts/BarList.vue'
import ChartTable from '@/components/charts/ChartTable.vue'
import ColumnChart from '@/components/charts/ColumnChart.vue'
import HourHeatmap from '@/components/charts/HourHeatmap.vue'
import LineChart from '@/components/charts/LineChart.vue'
import StatTile from '@/components/charts/StatTile.vue'
import { formatNumber } from '@/components/charts/useChartWidth'
import { colorClasses, priorityStyles } from '@/lib/colors'
import { formatValue, frequencyLabel, WEEKDAYS } from '@/lib/trackers'
import type { Priority } from '@/api/tasks'

/** Analytics v1 (PRD §4.8): tasks, habits, learning and journal consistency. */
const ranges: { key: RangeKey; label: string }[] = [
  { key: '7d', label: '7 days' }, { key: '30d', label: '30 days' }, { key: '90d', label: '90 days' }, { key: '1y', label: 'Year' },
]
const stored = useStorage<string>('lumen-analytics-range', '30d')
const range = computed<RangeKey>({
  get: () => (ranges.some((r) => r.key === stored.value) ? (stored.value as RangeKey) : '30d'),
  set: (key) => (stored.value = key),
})

const opts = { placeholderData: keepPreviousData, staleTime: 60_000 }
const { data: tasks } = useQuery({ queryKey: computed(() => ['analytics', 'tasks', range.value]), queryFn: () => analyticsApi.tasks(range.value), ...opts })
const { data: habits } = useQuery({ queryKey: computed(() => ['analytics', 'trackers', range.value]), queryFn: () => analyticsApi.trackers(range.value), ...opts })
const { data: learning } = useQuery({ queryKey: computed(() => ['analytics', 'learning', range.value]), queryFn: () => analyticsApi.learning(range.value), ...opts })

const percent = (n: number | null | undefined) => (n === null || n === undefined ? '—' : `${Math.round(n * 100)}%`)
const hours = (h: number | null | undefined) => (h === null || h === undefined ? '—' : h < 24 ? `${formatNumber(h)} h` : `${formatNumber(h / 24)} d`)

function dateLabel(iso: string, r: AnalyticsRange | undefined) {
  const d = new Date(`${iso}T12:00:00Z`)
  const opts: Intl.DateTimeFormatOptions = { month: 'short', day: 'numeric', timeZone: 'UTC' }
  return (r?.unit === 'week' ? 'Wk of ' : '') + new Intl.DateTimeFormat('en-US', opts).format(d)
}
const bucketWord = computed(() => (tasks.value?.range.unit === 'week' ? 'week' : 'day'))

const completedDelta = computed(() => {
  const k = tasks.value?.kpis
  if (!k) return null
  const diff = k.completed - k.previous_completed
  if (!k.previous_completed && !k.completed) return null
  return { value: diff, label: `${diff >= 0 ? '+' : ''}${diff} vs previous ${tasks.value!.range.days} days` }
})

const taskLabels = computed(() => (tasks.value?.series ?? []).map((d) => dateLabel(d.date, tasks.value?.range)))
const learnLabels = computed(() => (learning.value?.series ?? []).map((d) => dateLabel(d.date, learning.value?.range)))
const priorityOrder: Priority[] = ['urgent', 'high', 'medium', 'low', 'none']
const byPriority = computed(() =>
  [...(tasks.value?.by_priority ?? [])]
    .sort((a, b) => priorityOrder.indexOf(a.priority as Priority) - priorityOrder.indexOf(b.priority as Priority))
    .map((p) => ({ key: p.priority, label: `${priorityStyles[p.priority as Priority].label} (${p.completed})`, value: p.avg_hours ?? 0 })))
</script>

<template>
  <div class="mx-auto max-w-5xl px-6 pb-24 pt-8 md:px-10">
    <header class="mb-6 flex flex-wrap items-end justify-between gap-4">
      <div>
        <h1 class="text-2xl font-semibold tracking-tight">Analytics</h1>
        <p class="text-sm text-muted-foreground">Computed in Postgres from your tasks, trackers and notes. Journal content is never analysed on the server.</p>
        <RouterLink :to="{ name: 'weekly-review' }" class="mt-1 inline-block text-sm text-primary hover:underline">Open this week’s review →</RouterLink>
      </div>
      <div class="inline-flex rounded-lg border bg-muted/50 p-1 text-sm" role="radiogroup" aria-label="Date range">
        <button
          v-for="r in ranges"
          :key="r.key"
          type="button"
          role="radio"
          :aria-checked="range === r.key"
          class="rounded-md px-3 py-1 text-muted-foreground"
          :class="range === r.key && 'bg-background font-medium text-foreground shadow-xs'"
          @click="range = r.key"
        >
          {{ r.label }}
        </button>
      </div>
    </header>

    <!-- Tasks -->
    <section v-if="tasks" class="space-y-4">
      <h2 class="text-sm font-medium uppercase tracking-wide text-muted-foreground">Tasks</h2>
      <div class="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <StatTile label="Completed" :value="formatNumber(tasks.kpis.completed)" :delta="completedDelta" :hint="`${tasks.kpis.created} created`" />
        <StatTile label="Completion rate" :value="percent(tasks.kpis.completion_rate)" :hint="`${tasks.kpis.overdue_open} due in this period still open`" />
        <StatTile label="On time" :value="percent(tasks.kpis.on_time_rate)" hint="Of completed tasks that had a due date" />
        <StatTile label="Avg. time to done" :value="hours(tasks.kpis.avg_hours_to_complete)" hint="From created to completed" />
      </div>

      <div class="rounded-xl border bg-card p-5">
        <h3 class="font-medium">Created vs completed</h3>
        <p class="mb-3 text-xs text-muted-foreground">Tasks per {{ bucketWord }}. When “created” runs above “completed”, the list is growing.</p>
        <LineChart
          :labels="taskLabels"
          :series="[
            { key: 'completed', label: 'Completed', color: 'var(--viz-1)', values: tasks.series.map((d) => d.completed) },
            { key: 'created', label: 'Created', color: 'var(--viz-2)', values: tasks.series.map((d) => d.created) },
          ]"
          summary="Tasks created and completed over time"
        />
        <ChartTable :columns="['Period', 'Completed', 'Created']" :rows="tasks.series.map((d, i) => [taskLabels[i]!, d.completed, d.created])" />
      </div>

      <div class="grid gap-4 lg:grid-cols-2">
        <div class="rounded-xl border bg-card p-5">
          <h3 class="mb-4 font-medium">Completed by project</h3>
          <p v-if="!tasks.by_project.length" class="text-sm text-muted-foreground">Nothing completed in this period.</p>
          <BarList v-else :items="tasks.by_project.map((p) => ({ key: p.project_id ?? 'inbox', label: p.name, value: p.completed, dot: p.color ? colorClasses(p.color).dot : 'bg-muted-foreground/50' }))" />
        </div>
        <div class="rounded-xl border bg-card p-5">
          <h3 class="mb-4 font-medium">Time to complete, by priority</h3>
          <p v-if="!byPriority.length" class="text-sm text-muted-foreground">Nothing completed in this period.</p>
          <BarList v-else :items="byPriority" :format="hours" />
        </div>
      </div>

      <div class="rounded-xl border bg-card p-5">
        <h3 class="font-medium">When you get things done</h3>
        <p class="mb-3 text-xs text-muted-foreground">Completions by weekday and hour, in your time zone.</p>
        <HourHeatmap :cells="tasks.hours" />
      </div>

      <div class="rounded-xl border bg-card p-5">
        <h3 class="font-medium">Overdue backlog</h3>
        <p class="mb-3 text-xs text-muted-foreground">Open tasks past their due date at the end of each {{ bucketWord }}. Now: {{ tasks.backlog.at(-1)?.overdue ?? 0 }}.</p>
        <LineChart :labels="taskLabels" area :height="160" :series="[{ key: 'overdue', label: 'Overdue', color: 'var(--viz-1)', values: tasks.backlog.map((d) => d.overdue) }]" summary="Overdue tasks over time" />
        <ChartTable :columns="['Period', 'Overdue']" :rows="tasks.backlog.map((d, i) => [taskLabels[i]!, d.overdue])" />
      </div>
    </section>

    <!-- Habits -->
    <section v-if="habits" class="mt-12 space-y-4">
      <h2 class="text-sm font-medium uppercase tracking-wide text-muted-foreground">Habits</h2>
      <p v-if="!habits.trackers.length" class="rounded-xl border bg-card p-5 text-sm text-muted-foreground">
        No trackers yet. <RouterLink :to="{ name: 'tracker' }" class="text-primary hover:underline">Create one</RouterLink> to see consistency and streaks here.
      </p>
      <div v-else class="overflow-hidden rounded-xl border bg-card">
        <table class="w-full text-sm">
          <thead class="border-b text-xs text-muted-foreground">
            <tr>
              <th class="px-4 py-2 text-left font-medium">Tracker</th>
              <th class="px-4 py-2 text-left font-medium">Consistency</th>
              <th class="px-4 py-2 text-left font-medium">Streak</th>
              <th class="hidden px-4 py-2 text-left font-medium sm:table-cell">By weekday</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="t in habits.trackers" :key="t.id" class="border-b last:border-0">
              <td class="px-4 py-3">
                <RouterLink :to="{ name: 'tracker-detail', params: { id: t.id } }" class="flex items-center gap-2 hover:underline">
                  <span>{{ t.icon ?? '✅' }}</span><span class="font-medium">{{ t.name }}</span>
                </RouterLink>
                <span class="text-xs text-muted-foreground">{{ frequencyLabel(t.frequency) }}</span>
              </td>
              <td class="px-4 py-3">
                <div class="flex items-center gap-2">
                  <span class="h-2 w-24 rounded-full bg-muted/60"><span class="block h-full rounded-full" :style="{ width: `${(t.consistency ?? 0) * 100}%`, background: 'var(--viz-1)' }" /></span>
                  <span class="tabular-nums">{{ percent(t.consistency) }}</span>
                </div>
                <span class="text-xs text-muted-foreground">{{ t.periods_met }} of {{ t.periods_total }} {{ t.frequency.type === 'weekly' ? 'weeks' : 'days' }}</span>
              </td>
              <td class="px-4 py-3 tabular-nums">
                <span class="inline-flex items-center gap-1"><Flame class="size-3.5" :class="t.current_streak ? 'text-orange-500' : 'text-muted-foreground'" />{{ t.current_streak }}</span>
                <span class="block text-xs text-muted-foreground">best {{ t.longest_streak }}</span>
              </td>
              <td class="hidden px-4 py-3 sm:table-cell">
                <div v-if="t.frequency.type !== 'weekly'" class="flex items-end gap-1" :aria-label="`${t.name} consistency by weekday`">
                  <span v-for="(r, i) in t.weekdays" :key="i" class="flex flex-col items-center gap-1" :title="`${WEEKDAYS[i]}: ${r === null ? 'not scheduled' : percent(r)}`">
                    <span class="flex h-8 w-3 items-end rounded-sm bg-muted/50">
                      <span v-if="r !== null" class="block w-full rounded-sm" :style="{ height: `${Math.max(8, r * 100)}%`, background: 'var(--viz-1)', opacity: r === 0 ? 0.25 : 1 }" />
                    </span>
                    <span class="text-[9px] text-muted-foreground">{{ WEEKDAYS[i]!.slice(0, 1) }}</span>
                  </span>
                </div>
                <span v-else class="text-xs text-muted-foreground">Weekly goal</span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div class="grid gap-4 lg:grid-cols-2">
        <div v-for="t in habits.trackers.filter((x) => x.values?.some((v) => v.value !== null))" :key="t.id" class="rounded-xl border bg-card p-5">
          <h3 class="font-medium">{{ t.icon }} {{ t.name }}</h3>
          <p class="mb-3 text-xs text-muted-foreground">Daily values and the 7-day moving average{{ t.target ? ` · goal ${formatValue(t, t.target)}` : '' }}</p>
          <LineChart
            :labels="t.values!.map((v) => dateLabel(v.date, habits!.range))"
            :height="170"
            :format="(n) => (n === null ? '—' : formatValue(t, n))"
            :series="[
              { key: 'value', label: 'Daily', color: 'var(--viz-1)', values: t.values!.map((v) => v.value), dots: true },
              { key: 'avg7', label: '7-day average', color: 'var(--viz-1)', values: t.values!.map((v) => v.avg7) },
            ]"
            :summary="`${t.name} daily values with 7-day average`"
          />
        </div>
      </div>
    </section>

    <!-- Learning & journal -->
    <section v-if="learning" class="mt-12 space-y-4">
      <h2 class="text-sm font-medium uppercase tracking-wide text-muted-foreground">Learning & journal</h2>
      <div class="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <StatTile label="Notes" :value="formatNumber(learning.totals.notes)" :hint="`${learning.totals.notes_created} new in this period`" />
        <StatTile label="Links between notes" :value="formatNumber(learning.totals.links)" :hint="`${learning.totals.tags} tags in use`" />
        <StatTile label="Journal days" :value="formatNumber(learning.totals.journal_days)" :hint="`${learning.totals.journal_entries} entries in this period`" />
        <StatTile label="Writing streak" :value="`${learning.totals.journal_streak} ${learning.totals.journal_streak === 1 ? 'day' : 'days'}`" hint="From entry dates only" />
      </div>
      <div class="grid gap-4 lg:grid-cols-2">
        <div class="rounded-xl border bg-card p-5">
          <h3 class="mb-3 font-medium">Notes written and edited</h3>
          <LineChart
            :labels="learnLabels"
            :height="180"
            :series="[
              { key: 'created', label: 'Created', color: 'var(--viz-1)', values: learning.series.map((d) => d.notes_created) },
              { key: 'edited', label: 'Edited', color: 'var(--viz-2)', values: learning.series.map((d) => d.notes_edited) },
            ]"
            summary="Notes created and edited over time"
          />
          <ChartTable :columns="['Period', 'Created', 'Edited']" :rows="learning.series.map((d, i) => [learnLabels[i]!, d.notes_created, d.notes_edited])" />
        </div>
        <div class="rounded-xl border bg-card p-5">
          <h3 class="mb-3 font-medium">Days with a journal entry</h3>
          <ColumnChart :labels="learnLabels" :values="learning.series.map((d) => d.journal_days)" label="Days journaled" summary="Days with a journal entry per period" />
          <ChartTable :columns="['Period', 'Days']" :rows="learning.series.map((d, i) => [learnLabels[i]!, d.journal_days])" />
        </div>
      </div>
    </section>
  </div>
</template>
