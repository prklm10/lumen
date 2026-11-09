<script setup lang="ts">
import { Check } from '@lucide/vue'
import type { Priority } from '@/api/tasks'
import { priorityStyles } from '@/lib/colors'

const props = defineProps<{ checked: boolean; priority: Priority; size?: 'sm' | 'md' }>()
defineEmits<{ toggle: [] }>()
</script>

<template>
  <button
    type="button"
    role="checkbox"
    :aria-checked="checked"
    :aria-label="checked ? 'Mark as not done' : 'Mark as done'"
    class="group/check relative flex shrink-0 items-center justify-center rounded-full border-[1.5px] transition-colors"
    :class="[
      props.size === 'sm' ? 'size-4' : 'size-[18px]',
      checked ? 'border-primary bg-primary text-primary-foreground' : [priorityStyles[priority].ring, priorityStyles[priority].fill],
    ]"
    @click.stop="$emit('toggle')"
  >
    <Check
      class="size-3 transition-opacity"
      :class="checked ? 'opacity-100 animate-in zoom-in-50 duration-200' : 'opacity-0 group-hover/check:opacity-60'"
      :stroke-width="3"
    />
  </button>
</template>
