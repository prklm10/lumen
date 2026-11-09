<script setup lang="ts">
import { computed, ref } from 'vue'
import { Check, Minus, Plus } from '@lucide/vue'
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'
import type { Tracker } from '@/api/trackers'
import { useTrackerMutations } from '@/composables/useTrackers'
import { colorClasses } from '@/lib/colors'
import { formatValue, isMet } from '@/lib/trackers'
import EntryEditor from './EntryEditor.vue'
import ScaleButtons from './ScaleButtons.vue'

/** Today's check-in, one tap where possible (TRK-3): toggle, stepper, 1–5, or a quick editor. */
const props = defineProps<{ tracker: Tracker; date: string }>()
const { checkIn } = useTrackerMutations()
const editing = ref(false)

const entry = computed(() => props.tracker.recent_entries.find((e) => e.logged_on === props.date))
const value = computed(() => entry.value?.value)
const met = computed(() => isMet(props.tracker, value.value))
const color = computed(() => colorClasses(props.tracker.color))

function set(next: number | null, note?: string | null) {
  checkIn.mutate({ tracker: props.tracker, date: props.date, value: next, note: note === undefined ? entry.value?.note : note })
}
</script>

<template>
  <!-- Yes / no: a single toggle -->
  <button
    v-if="tracker.kind === 'boolean'"
    type="button"
    class="flex size-9 items-center justify-center rounded-full border-2 transition-all active:scale-90"
    :class="met ? [color.dot, 'border-transparent text-white'] : 'border-border text-transparent hover:border-muted-foreground/50 hover:text-muted-foreground/40'"
    :aria-pressed="met"
    :aria-label="met ? `Undo ${tracker.name}` : `Mark ${tracker.name} done`"
    @click="set(met ? null : 1)"
  >
    <Check class="size-4" :stroke-width="3" />
  </button>

  <!-- Count: − n + -->
  <div v-else-if="tracker.kind === 'count'" class="flex items-center gap-1">
    <button
      type="button"
      class="flex size-8 items-center justify-center rounded-md border text-muted-foreground hover:bg-accent disabled:opacity-40"
      :disabled="!value"
      :aria-label="`One less ${tracker.unit ?? ''}`"
      @click="set(value! > 1 ? value! - 1 : null)"
    >
      <Minus class="size-3.5" />
    </button>
    <span class="min-w-14 text-center text-sm font-medium tabular-nums" :class="met && color.text">
      {{ value ?? 0 }}<span v-if="tracker.target" class="text-muted-foreground font-normal">/{{ tracker.target }}</span>
    </span>
    <button
      type="button"
      class="flex size-8 items-center justify-center rounded-md border hover:bg-accent"
      :aria-label="`One more ${tracker.unit ?? ''}`"
      @click="set((value ?? 0) + 1)"
    >
      <Plus class="size-3.5" />
    </button>
  </div>

  <!-- Scale: 1–5 -->
  <ScaleButtons v-else-if="tracker.kind === 'scale'" size="sm" :model-value="value ?? null" @update:model-value="(v) => set(v === value ? null : v)" />

  <!-- Duration / number: open a small editor -->
  <Popover v-else v-model:open="editing">
    <PopoverTrigger as-child>
      <button
        type="button"
        class="h-8 min-w-20 rounded-md border px-2.5 text-sm tabular-nums hover:bg-accent"
        :class="met ? [color.text, 'font-medium'] : value === undefined ? 'text-muted-foreground' : ''"
      >
        {{ value === undefined ? (tracker.kind === 'duration' ? '+ min' : '+ log') : formatValue(tracker, value) }}
      </button>
    </PopoverTrigger>
    <PopoverContent class="w-64" align="end">
      <EntryEditor
        :tracker="tracker"
        :date="date"
        :entry="entry"
        @save="(v, n) => { set(v, n); editing = false }"
        @clear="() => { set(null); editing = false }"
      />
    </PopoverContent>
  </Popover>
</template>
