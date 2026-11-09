<script setup lang="ts">
import { Flag } from '@lucide/vue'
import {
  DropdownMenu, DropdownMenuContent, DropdownMenuRadioGroup, DropdownMenuRadioItem, DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import type { Priority } from '@/api/tasks'
import { priorities, priorityStyles } from '@/lib/colors'

defineProps<{ modelValue: Priority; compact?: boolean }>()
const emit = defineEmits<{ 'update:modelValue': [value: Priority] }>()
</script>

<template>
  <DropdownMenu>
    <DropdownMenuTrigger as-child>
      <button
        type="button"
        class="inline-flex h-7 items-center gap-1.5 rounded-md border px-2 text-xs hover:bg-accent"
        :class="priorityStyles[modelValue].text"
      >
        <Flag class="size-3.5" />
        <span v-if="!compact || modelValue !== 'none'">{{ modelValue === 'none' ? 'Priority' : priorityStyles[modelValue].label }}</span>
      </button>
    </DropdownMenuTrigger>
    <DropdownMenuContent align="start" class="w-44">
      <DropdownMenuRadioGroup :model-value="modelValue" @update:model-value="emit('update:modelValue', $event as Priority)">
        <DropdownMenuRadioItem v-for="p in priorities" :key="p" :value="p">
          <Flag class="size-4" :class="priorityStyles[p].text" />
          {{ priorityStyles[p].label }}
        </DropdownMenuRadioItem>
      </DropdownMenuRadioGroup>
    </DropdownMenuContent>
  </DropdownMenu>
</template>
