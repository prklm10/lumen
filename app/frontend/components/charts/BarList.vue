<script setup lang="ts">
import { computed } from 'vue'
import { formatNumber } from './useChartWidth'

/**
 * Horizontal bars for magnitude by category: one hue, labels on the left, values in text ink
 * at the bar end. A small colored dot can carry an entity's own identity (e.g. a project).
 */
const props = defineProps<{ items: { key: string | number; label: string; value: number; dot?: string }[]; format?: (n: number) => string }>()
const max = computed(() => Math.max(1, ...props.items.map((i) => i.value)))
</script>

<template>
  <ul class="space-y-2">
    <li v-for="item in items" :key="item.key" class="group grid grid-cols-[minmax(6rem,9rem)_1fr_auto] items-center gap-3 text-sm" :title="`${item.label}: ${format ? format(item.value) : formatNumber(item.value)}`">
      <span class="flex min-w-0 items-center gap-1.5">
        <span v-if="item.dot" class="size-2 shrink-0 rounded-full" :class="item.dot" />
        <span class="truncate">{{ item.label }}</span>
      </span>
      <span class="h-2.5 rounded-r bg-muted/50">
        <span class="block h-full rounded-r transition-[width] group-hover:opacity-80" :style="{ width: `${Math.max(1.5, (item.value / max) * 100)}%`, background: 'var(--viz-1)' }" />
      </span>
      <span class="w-12 text-right tabular-nums text-muted-foreground">{{ format ? format(item.value) : formatNumber(item.value) }}</span>
    </li>
  </ul>
</template>
