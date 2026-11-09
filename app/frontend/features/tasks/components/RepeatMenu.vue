<script setup lang="ts">
import { computed } from 'vue'
import { Check, Repeat } from '@lucide/vue'
import {
  DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuSeparator, DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import { recurrenceLabel, repeatPresets, weeklyOn } from '@/lib/recurrence'
import { isoWeekday } from '@/lib/trackers'
import { weekdayName } from '@/lib/dates'

/** Repeat rule picker (TSK-7). Offers "every <due weekday>" when there's a due date. */
const props = defineProps<{ modelValue: string | null; dueDate: string | null; compact?: boolean }>()
const emit = defineEmits<{ 'update:modelValue': [rule: string | null] }>()

const options = computed(() => {
  const list = [...repeatPresets]
  if (props.dueDate) list.splice(3, 0, { label: `Every ${weekdayName(props.dueDate)}`, rule: weeklyOn([isoWeekday(props.dueDate)]) })
  return list
})
const label = computed(() => recurrenceLabel(props.modelValue))
</script>

<template>
  <DropdownMenu>
    <DropdownMenuTrigger as-child>
      <button type="button" class="inline-flex h-7 items-center gap-1.5 rounded-md border px-2 text-xs hover:bg-accent" :class="modelValue ? 'text-foreground' : 'text-muted-foreground'">
        <Repeat class="size-3.5" />
        <span v-if="!compact || modelValue">{{ label ?? 'Repeat' }}</span>
      </button>
    </DropdownMenuTrigger>
    <DropdownMenuContent align="start" class="w-52">
      <DropdownMenuItem v-for="o in options" :key="o.rule" @select="emit('update:modelValue', o.rule)">
        {{ o.label }}
        <Check v-if="modelValue === o.rule" class="ml-auto" />
      </DropdownMenuItem>
      <template v-if="modelValue">
        <DropdownMenuSeparator />
        <DropdownMenuItem @select="emit('update:modelValue', null)">Don’t repeat</DropdownMenuItem>
      </template>
    </DropdownMenuContent>
  </DropdownMenu>
</template>
