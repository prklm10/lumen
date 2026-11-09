<script setup lang="ts">
import { computed, ref } from 'vue'
import { formatNumber, niceTicks, useChartWidth } from './useChartWidth'

/**
 * Lines over time on one shared y-axis (never two scales). Crosshair + tooltip on hover;
 * a legend for 2+ series plus direct labels at the line ends. `dots` draws a series as
 * points only (e.g. raw daily values under a moving-average line); `area` fills a single series.
 */
export interface LineSeries {
  key: string
  label: string
  color: string
  values: (number | null)[]
  dots?: boolean
}

const props = withDefaults(defineProps<{
  labels: string[]
  series: LineSeries[]
  height?: number
  area?: boolean
  format?: (n: number | null) => string
  /** Accessible description of what the chart shows. */
  summary: string
}>(), { height: 220, format: (n: number | null) => formatNumber(n) })

const root = ref<HTMLElement>()
const width = useChartWidth(root)
const pad = { top: 12, right: 64, bottom: 24, left: 36 }
const hover = ref<number | null>(null)

const yMax = computed(() => Math.max(0, ...props.series.flatMap((s) => s.values.filter((v): v is number => v !== null))))
const scale = computed(() => niceTicks(yMax.value))
const innerW = computed(() => width.value - pad.left - pad.right)
const innerH = computed(() => props.height - pad.top - pad.bottom)
const x = (i: number) => pad.left + (props.labels.length <= 1 ? innerW.value / 2 : (i / (props.labels.length - 1)) * innerW.value)
const y = (v: number) => pad.top + innerH.value - (v / scale.value.max) * innerH.value

function path(values: (number | null)[]) {
  let d = ''
  let pen = false
  values.forEach((v, i) => {
    if (v === null) return (pen = false)
    d += `${pen ? 'L' : 'M'}${x(i).toFixed(1)},${y(v).toFixed(1)}`
    pen = true
  })
  return d
}

function areaPath(values: (number | null)[]) {
  const line = path(values.map((v) => v ?? 0))
  return `${line}L${x(values.length - 1)},${y(0)}L${x(0)},${y(0)}Z`
}

// Show ~6 x labels at most, always including the last.
const xTicks = computed(() => {
  const n = props.labels.length
  const every = Math.max(1, Math.ceil(n / 6))
  return props.labels.map((l, i) => ({ i, l })).filter(({ i }) => i % every === 0 || i === n - 1).filter((t, idx, arr) => idx === arr.length - 1 || arr[arr.length - 1]!.i - t.i >= every * 0.6)
})

function onMove(event: PointerEvent) {
  const rect = (event.currentTarget as SVGElement).getBoundingClientRect()
  const px = event.clientX - rect.left
  const n = props.labels.length
  hover.value = n <= 1 ? 0 : Math.min(n - 1, Math.max(0, Math.round(((px - pad.left) / innerW.value) * (n - 1))))
}

// Direct labels at the right end, nudged apart so they don't collide.
const endLabels = computed(() => {
  const items = props.series.filter((s) => !s.dots).map((s) => {
    const last = [...s.values].reverse().find((v) => v !== null) ?? 0
    return { key: s.key, label: s.label, color: s.color, y: y(last) }
  }).sort((a, b) => a.y - b.y)
  for (let i = 1; i < items.length; i++) items[i]!.y = Math.max(items[i]!.y, items[i - 1]!.y + 14)
  return items
})

const tooltipLeft = computed(() => (hover.value === null ? 0 : Math.min(x(hover.value) + 10, width.value - 160)))
</script>

<template>
  <div ref="root" class="relative w-full">
    <div v-if="series.length > 1" class="mb-2 flex flex-wrap gap-x-4 gap-y-1 text-xs text-muted-foreground">
      <span v-for="s in series" :key="s.key" class="inline-flex items-center gap-1.5">
        <span v-if="s.dots" class="size-2 rounded-full" :style="{ background: s.color }" />
        <span v-else class="h-0.5 w-3 rounded-full" :style="{ background: s.color }" />
        {{ s.label }}
      </span>
    </div>
    <svg :width="width" :height="height" role="img" :aria-label="summary" class="block touch-none select-none" @pointermove="onMove" @pointerleave="hover = null">
      <g class="text-[10px]">
        <template v-for="t in scale.ticks" :key="t">
          <line :x1="pad.left" :x2="width - pad.right" :y1="y(t)" :y2="y(t)" stroke="var(--border)" :stroke-dasharray="t === 0 ? undefined : '2 3'" />
          <text :x="pad.left - 6" :y="y(t) + 3" text-anchor="end" class="fill-muted-foreground">{{ format(t) }}</text>
        </template>
        <text v-for="t in xTicks" :key="t.i" :x="x(t.i)" :y="height - 6" text-anchor="middle" class="fill-muted-foreground">{{ t.l }}</text>
      </g>

      <path v-if="area && series[0]" :d="areaPath(series[0].values)" :fill="series[0].color" fill-opacity="0.12" />
      <template v-for="s in series" :key="s.key">
        <g v-if="s.dots">
          <circle v-for="(v, i) in s.values" v-show="v !== null" :key="i" :cx="x(i)" :cy="v === null ? 0 : y(v)" r="3" :fill="s.color" fill-opacity="0.45" />
        </g>
        <path v-else :d="path(s.values)" fill="none" :stroke="s.color" stroke-width="2" stroke-linejoin="round" stroke-linecap="round" />
      </template>

      <text v-for="l in endLabels" v-show="series.length > 1" :key="l.key" :x="width - pad.right + 6" :y="l.y + 3" class="fill-muted-foreground text-[10px]">{{ l.label }}</text>

      <g v-if="hover !== null">
        <line :x1="x(hover)" :x2="x(hover)" :y1="pad.top" :y2="pad.top + innerH" stroke="var(--muted-foreground)" stroke-opacity="0.4" />
        <template v-for="s in series" :key="s.key">
          <circle v-if="s.values[hover] !== null" :cx="x(hover)" :cy="y(s.values[hover]!)" r="4" :fill="s.color" stroke="var(--card)" stroke-width="2" />
        </template>
      </g>
    </svg>
    <div
      v-if="hover !== null"
      class="pointer-events-none absolute top-6 z-10 min-w-36 rounded-md border bg-popover px-2.5 py-1.5 text-xs shadow-md"
      :style="{ left: `${tooltipLeft}px` }"
    >
      <p class="mb-1 font-medium">{{ labels[hover] }}</p>
      <p v-for="s in series" :key="s.key" class="flex items-center gap-2 text-muted-foreground">
        <span class="size-2 rounded-full" :style="{ background: s.color }" />
        <span class="flex-1">{{ s.label }}</span>
        <span class="font-medium tabular-nums text-foreground">{{ format(s.values[hover] ?? null) }}</span>
      </p>
    </div>
  </div>
</template>
