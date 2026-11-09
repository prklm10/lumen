<script setup lang="ts">
import { moods } from '../useJournal'

defineProps<{ modelValue: number | null }>()
const emit = defineEmits<{ 'update:modelValue': [value: number | null] }>()
</script>

<template>
  <div class="flex items-center gap-0.5" role="radiogroup" aria-label="Mood">
    <button
      v-for="mood in moods"
      :key="mood.value"
      type="button"
      role="radio"
      :aria-checked="modelValue === mood.value"
      :aria-label="mood.label"
      :title="mood.label"
      class="flex size-8 items-center justify-center rounded-full text-lg transition"
      :class="modelValue === mood.value ? 'scale-110 bg-primary/15 ring-1 ring-primary/50' : modelValue ? 'opacity-40 grayscale hover:opacity-100 hover:grayscale-0' : 'hover:bg-accent'"
      @click="emit('update:modelValue', modelValue === mood.value ? null : mood.value)"
    >
      {{ mood.emoji }}
    </button>
  </div>
</template>
