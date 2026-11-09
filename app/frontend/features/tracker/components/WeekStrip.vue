<script setup lang="ts">
import { computed, ref } from 'vue'
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'
import type { Tracker } from '@/api/trackers'
import { useTrackerMutations } from '@/composables/useTrackers'
import { addDays, weekdayName } from '@/lib/dates'
import { colorClasses } from '@/lib/colors'
import { formatValue, isMet, isScheduled } from '@/lib/trackers'
import EntryEditor from './EntryEditor.vue'

/** The last seven days; click any day to backfill or fix it (TRK-3). */
const props = defineProps<{ tracker: Tracker; today: string }>()
const { checkIn } = useTrackerMutations()
const open = ref<string | null>(null)

const days = computed(() =>
  Array.from({ length: 7 }, (_, i) => {
    const date = addDays(props.today, i - 6)
    const entry = props.tracker.recent_entries.find((e) => e.logged_on === date)
    return { date, entry, met: isMet(props.tracker, entry?.value), scheduled: isScheduled(props.tracker, date) }
  }),
)
const color = computed(() => colorClasses(props.tracker.color))

function save(date: string, value: number | null, note?: string | null) {
  checkIn.mutate({ tracker: props.tracker, date, value, note })
  open.value = null
}
</script>

<template>
  <div class="flex gap-1">
    <Popover v-for="day in days" :key="day.date" :open="open === day.date" @update:open="(o) => (open = o ? day.date : null)">
      <PopoverTrigger as-child>
        <button
          type="button"
          class="flex w-8 flex-col items-center gap-1 rounded-md py-1 text-[10px] text-muted-foreground hover:bg-accent"
          :aria-label="`${weekdayName(day.date)}: ${day.entry ? formatValue(tracker, day.entry.value) : 'no check-in'}`"
          :title="day.entry?.note ?? undefined"
        >
          <span :class="day.date === today && 'font-semibold text-foreground'">{{ weekdayName(day.date, 'short').slice(0, 2) }}</span>
          <span
            class="size-4 rounded-[5px] border"
            :class="[
              day.met ? [color.dot, 'border-transparent'] : day.entry ? [color.dot, 'border-transparent opacity-35'] : 'bg-muted/40',
              !day.scheduled && !day.entry && 'border-dashed opacity-50',
            ]"
          />
        </button>
      </PopoverTrigger>
      <PopoverContent class="w-64" align="center">
        <EntryEditor
          :tracker="tracker"
          :date="day.date"
          :entry="day.entry"
          @save="(v, n) => save(day.date, v, n)"
          @clear="save(day.date, null)"
        />
      </PopoverContent>
    </Popover>
  </div>
</template>
