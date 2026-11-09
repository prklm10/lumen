<script setup lang="ts">
import { computed, ref } from 'vue'

/** Completions by weekday × hour of day: one sequential hue, light (few) → dark (many). */
const props = defineProps<{ cells: [number, number, number][] }>()
const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
const hover = ref<{ dow: number; hour: number; n: number } | null>(null)

const grid = computed(() => {
  const map = new Map(props.cells.map(([d, h, n]) => [`${d}-${h}`, n]))
  return { get: (d: number, h: number) => map.get(`${d}-${h}`) ?? 0, max: Math.max(1, ...props.cells.map((c) => c[2])) }
})

function level(n: number) {
  if (!n) return 'var(--muted)'
  return `var(--viz-seq-${Math.min(5, Math.max(1, Math.ceil((n / grid.value.max) * 5)))})`
}

const hourLabel = (h: number) => (h === 0 ? '12a' : h < 12 ? `${h}a` : h === 12 ? '12p' : `${h - 12}p`)
</script>

<template>
  <div class="relative">
    <div class="grid grid-cols-[2.25rem_repeat(24,minmax(0,1fr))] gap-[2px] text-[10px] text-muted-foreground" role="img" aria-label="Tasks completed by weekday and hour">
      <span />
      <span v-for="h in 24" :key="h" class="text-center">{{ (h - 1) % 6 === 0 ? hourLabel(h - 1) : '' }}</span>
      <template v-for="(day, d) in days" :key="day">
        <span class="pr-1 text-right leading-4">{{ day }}</span>
        <span
          v-for="h in 24"
          :key="h"
          class="h-4 rounded-[3px]"
          :style="{ background: level(grid.get(d + 1, h - 1)) }"
          @pointerenter="hover = { dow: d, hour: h - 1, n: grid.get(d + 1, h - 1) }"
          @pointerleave="hover = null"
        />
      </template>
    </div>
    <div class="mt-2 flex items-center justify-between text-xs text-muted-foreground">
      <span v-if="hover">{{ days[hover.dow] }} {{ hourLabel(hover.hour) }}–{{ hourLabel((hover.hour + 1) % 24) }}: <span class="font-medium text-foreground">{{ hover.n }}</span> completed</span>
      <span v-else>Hover a cell for details</span>
      <span class="flex items-center gap-1">Fewer <span v-for="i in 5" :key="i" class="size-2.5 rounded-[2px]" :style="{ background: `var(--viz-seq-${i})` }" /> More</span>
    </div>
  </div>
</template>
