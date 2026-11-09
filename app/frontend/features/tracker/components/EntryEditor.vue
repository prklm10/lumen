<script setup lang="ts">
import { ref } from 'vue'
import { Button } from '@/components/ui/button'
import type { Tracker, TrackerEntry } from '@/api/trackers'
import { longDay } from '@/lib/dates'
import ScaleButtons from './ScaleButtons.vue'

/** Edit one day's check-in: value (shaped by the tracker kind) and an optional note (TRK-7). */
const props = defineProps<{ tracker: Tracker; date: string; entry: TrackerEntry | undefined }>()
const emit = defineEmits<{ save: [value: number, note: string | null]; clear: [] }>()

const value = ref<number | null>(props.entry?.value ?? (props.tracker.kind === 'boolean' ? 1 : null))
const note = ref(props.entry?.note ?? '')

function save() {
  if (value.value === null || Number.isNaN(value.value)) return
  emit('save', value.value, note.value.trim() || null)
}
</script>

<template>
  <form class="space-y-3" @submit.prevent="save">
    <p class="text-xs font-medium text-muted-foreground">{{ longDay(date) }}</p>

    <div v-if="tracker.kind === 'boolean'" class="flex gap-2">
      <Button type="button" size="sm" :variant="value === 1 ? 'default' : 'outline'" @click="value = 1">Done</Button>
      <Button type="button" size="sm" :variant="value === 0 ? 'default' : 'outline'" @click="value = 0">Skipped</Button>
    </div>
    <ScaleButtons v-else-if="tracker.kind === 'scale'" :model-value="value" @update:model-value="value = $event" />
    <label v-else class="flex items-center gap-2">
      <input
        v-model.number="value"
        type="number"
        min="0"
        :step="tracker.kind === 'numeric' ? 'any' : 1"
        class="h-8 w-24 rounded-md border bg-transparent px-2 text-sm"
        :aria-label="tracker.kind === 'duration' ? 'Minutes' : 'Value'"
        autofocus
      >
      <span class="text-sm text-muted-foreground">{{ tracker.kind === 'duration' ? 'minutes' : tracker.unit }}</span>
    </label>

    <textarea
      v-model="note"
      rows="2"
      maxlength="500"
      class="w-full resize-none rounded-md border bg-transparent px-2 py-1.5 text-sm placeholder:text-muted-foreground/70"
      placeholder="Note (optional)"
      aria-label="Note"
    />
    <div class="flex justify-between gap-2">
      <Button v-if="entry" type="button" variant="ghost" size="sm" class="text-muted-foreground" @click="emit('clear')">Clear day</Button>
      <Button type="submit" size="sm" class="ml-auto" :disabled="value === null">Save</Button>
    </div>
  </form>
</template>
