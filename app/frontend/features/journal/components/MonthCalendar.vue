<script setup lang="ts">
import { computed } from 'vue'
import { ChevronLeft, ChevronRight } from '@lucide/vue'
import { addDays } from '@/lib/dates'
import { WEEKDAYS, isoWeekday } from '@/lib/trackers'

/** A month grid (Monday first) with a dot on days that have entries. Only dates are needed. */
const props = defineProps<{ month: string; today: string; marked: Map<string, number>; selected?: string | null }>()
const emit = defineEmits<{ 'update:month': [month: string]; select: [date: string] }>()

const first = computed(() => `${props.month}-01`)
const days = computed(() => {
  const start = addDays(first.value, -(isoWeekday(first.value) - 1))
  return Array.from({ length: 42 }, (_, i) => addDays(start, i))
})
const label = computed(() => new Intl.DateTimeFormat('en-US', { month: 'long', year: 'numeric', timeZone: 'UTC' }).format(new Date(`${first.value}T12:00:00Z`)))

function shift(months: number) {
  const [y, m] = props.month.split('-').map(Number)
  const d = new Date(Date.UTC(y!, m! - 1 + months, 1))
  emit('update:month', d.toISOString().slice(0, 7))
}
</script>

<template>
  <div>
    <div class="mb-2 flex items-center justify-between">
      <span class="text-sm font-medium">{{ label }}</span>
      <div class="flex gap-0.5">
        <button type="button" class="rounded p-1 text-muted-foreground hover:bg-accent" aria-label="Previous month" @click="shift(-1)"><ChevronLeft class="size-4" /></button>
        <button type="button" class="rounded p-1 text-muted-foreground hover:bg-accent" aria-label="Next month" @click="shift(1)"><ChevronRight class="size-4" /></button>
      </div>
    </div>
    <div class="grid grid-cols-7 gap-0.5 text-center">
      <span v-for="d in WEEKDAYS" :key="d" class="pb-1 text-[10px] font-medium uppercase text-muted-foreground">{{ d.slice(0, 2) }}</span>
      <button
        v-for="day in days"
        :key="day"
        type="button"
        class="relative flex aspect-square items-center justify-center rounded-md text-xs tabular-nums transition-colors"
        :class="[
          day.slice(0, 7) !== month ? 'text-muted-foreground/40' : '',
          day === selected ? 'bg-primary text-primary-foreground' : day === today ? 'bg-accent font-semibold' : 'hover:bg-accent',
          day > today ? 'cursor-default opacity-50' : '',
        ]"
        :disabled="day > today"
        :aria-label="`${day}${marked.get(day) ? `, ${marked.get(day)} entries` : ''}`"
        @click="emit('select', day)"
      >
        {{ Number(day.slice(8)) }}
        <span v-if="marked.get(day)" class="absolute bottom-1 size-1 rounded-full" :class="day === selected ? 'bg-primary-foreground' : 'bg-primary'" />
      </button>
    </div>
  </div>
</template>
