<script setup lang="ts">
import { computed, ref } from 'vue'
import { CalendarDays, CalendarX, Sofa, Sun, SunMedium } from '@lucide/vue'
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'
import { addDays, relativeDay, weekdayName } from '@/lib/dates'
import { useToday } from '@/composables/useToday'

/** Due date + optional time. Emits `{ due_date, due_at }` with due_at as a local "YYYY-MM-DDTHH:mm". */
const props = defineProps<{ date: string | null; time: string | null; compact?: boolean }>()
const emit = defineEmits<{ change: [value: { date: string | null; time: string | null }] }>()

const open = ref(false)
const { today } = useToday()

const nextMonday = computed(() => {
  const dow = new Date(`${today.value}T12:00:00Z`).getUTCDay() // 0 = Sunday
  return addDays(today.value, ((8 - dow) % 7) || 7)
})
const thisWeekend = computed(() => {
  const dow = new Date(`${today.value}T12:00:00Z`).getUTCDay()
  return addDays(today.value, dow === 6 ? 0 : (6 - dow + 7) % 7)
})

const presets = computed(() => [
  { label: 'Today', date: today.value, icon: Sun, hint: weekdayName(today.value, 'short') },
  { label: 'Tomorrow', date: addDays(today.value, 1), icon: SunMedium, hint: weekdayName(addDays(today.value, 1), 'short') },
  { label: 'This weekend', date: thisWeekend.value, icon: Sofa, hint: weekdayName(thisWeekend.value, 'short') },
  { label: 'Next week', date: nextMonday.value, icon: CalendarDays, hint: relativeDay(nextMonday.value, today.value) },
])

const label = computed(() => (props.date ? relativeDay(props.date, today.value) : 'Due date'))
const tone = computed(() => {
  if (!props.date) return 'text-muted-foreground'
  if (props.date < today.value) return 'text-red-500'
  if (props.date === today.value) return 'text-green-600 dark:text-green-500'
  return 'text-foreground'
})

function pick(date: string | null) {
  emit('change', { date, time: date ? props.time : null })
  open.value = false
}

function setTime(event: Event) {
  const time = (event.target as HTMLInputElement).value || null
  emit('change', { date: props.date ?? today.value, time })
}
</script>

<template>
  <Popover v-model:open="open">
    <PopoverTrigger as-child>
      <button
        type="button"
        class="inline-flex h-7 items-center gap-1.5 rounded-md border px-2 text-xs hover:bg-accent"
        :class="tone"
      >
        <CalendarDays class="size-3.5" />
        <span v-if="!compact || date">{{ label }}</span>
        <span v-if="time" class="text-muted-foreground">{{ time }}</span>
      </button>
    </PopoverTrigger>
    <PopoverContent class="w-60 p-1" align="start">
      <button
        v-for="preset in presets"
        :key="preset.label"
        type="button"
        class="flex w-full items-center gap-2 rounded-sm px-2 py-1.5 text-sm hover:bg-accent"
        @click="pick(preset.date)"
      >
        <component :is="preset.icon" class="size-4 text-muted-foreground" />
        <span class="flex-1 text-left">{{ preset.label }}</span>
        <span class="text-xs text-muted-foreground">{{ preset.hint }}</span>
      </button>
      <button
        v-if="date"
        type="button"
        class="flex w-full items-center gap-2 rounded-sm px-2 py-1.5 text-sm hover:bg-accent"
        @click="pick(null)"
      >
        <CalendarX class="size-4 text-muted-foreground" />
        <span class="flex-1 text-left">No date</span>
      </button>
      <div class="mt-1 grid grid-cols-[1fr_auto] gap-1 border-t p-1 pt-2">
        <input
          type="date"
          aria-label="Pick a date"
          class="h-8 rounded-md border bg-transparent px-2 text-sm"
          :value="date ?? ''"
          @change="pick(($event.target as HTMLInputElement).value || null)"
        >
        <input
          type="time"
          aria-label="Time"
          class="h-8 rounded-md border bg-transparent px-2 text-sm"
          :value="time ?? ''"
          @change="setTime"
        >
      </div>
    </PopoverContent>
  </Popover>
</template>
