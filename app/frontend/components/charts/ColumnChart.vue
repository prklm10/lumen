<script setup lang="ts">
import { computed, ref } from 'vue'
import { formatNumber, niceTicks, useChartWidth } from './useChartWidth'

/** One series of vertical bars (counts per period): thin, rounded data-end, 2px gaps, hover tooltip. */
const props = withDefaults(defineProps<{
  labels: string[]
  values: number[]
  color?: string
  label: string
  height?: number
  /** Accessible description of what the chart shows. */
  summary: string
}>(), { color: 'var(--viz-1)', height: 180 })

const root = ref<HTMLElement>()
const width = useChartWidth(root)
const pad = { top: 10, right: 8, bottom: 24, left: 32 }
const hover = ref<number | null>(null)

const scale = computed(() => niceTicks(Math.max(0, ...props.values)))
const innerW = computed(() => width.value - pad.left - pad.right)
const innerH = computed(() => props.height - pad.top - pad.bottom)
const slot = computed(() => innerW.value / Math.max(1, props.values.length))
const barW = computed(() => Math.max(2, Math.min(24, slot.value - 2)))
const y = (v: number) => pad.top + innerH.value - (v / scale.value.max) * innerH.value

function bar(i: number, v: number) {
  const x0 = pad.left + i * slot.value + (slot.value - barW.value) / 2
  const top = y(v)
  const h = pad.top + innerH.value - top
  if (h <= 0) return ''
  const r = Math.min(4, barW.value / 2, h)
  return `M${x0},${top + h}V${top + r}Q${x0},${top} ${x0 + r},${top}H${x0 + barW.value - r}Q${x0 + barW.value},${top} ${x0 + barW.value},${top + r}V${top + h}Z`
}

const every = computed(() => Math.max(1, Math.ceil(props.values.length / 6)))
</script>

<template>
  <div ref="root" class="relative w-full">
    <svg :width="width" :height="height" role="img" :aria-label="summary" class="block select-none" @pointerleave="hover = null">
      <g class="text-[10px]">
        <template v-for="t in scale.ticks" :key="t">
          <line :x1="pad.left" :x2="width - pad.right" :y1="y(t)" :y2="y(t)" stroke="var(--border)" :stroke-dasharray="t === 0 ? undefined : '2 3'" />
          <text :x="pad.left - 6" :y="y(t) + 3" text-anchor="end" class="fill-muted-foreground">{{ formatNumber(t) }}</text>
        </template>
        <template v-for="(l, i) in labels" :key="i">
          <text v-if="i % every === 0" :x="pad.left + i * slot + slot / 2" :y="height - 6" text-anchor="middle" class="fill-muted-foreground">{{ l }}</text>
        </template>
      </g>
      <g v-for="(v, i) in values" :key="i" @pointerenter="hover = i">
        <!-- Hit target: the whole column, bigger than the bar. -->
        <rect :x="pad.left + i * slot" :y="pad.top" :width="slot" :height="innerH" fill="transparent" />
        <path :d="bar(i, v)" :fill="color" :fill-opacity="hover === null || hover === i ? 1 : 0.55" />
      </g>
    </svg>
    <div
      v-if="hover !== null"
      class="pointer-events-none absolute top-2 z-10 rounded-md border bg-popover px-2.5 py-1.5 text-xs shadow-md"
      :style="{ left: `${Math.min(pad.left + hover * slot + slot, width - 140)}px` }"
    >
      <p class="font-medium">{{ labels[hover] }}</p>
      <p class="text-muted-foreground">{{ label }}: <span class="font-medium tabular-nums text-foreground">{{ formatNumber(values[hover]) }}</span></p>
    </div>
  </div>
</template>
