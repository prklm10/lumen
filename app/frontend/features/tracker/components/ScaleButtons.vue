<script setup lang="ts">
defineProps<{ modelValue: number | null; size?: 'sm' | 'md' }>()
const emit = defineEmits<{ 'update:modelValue': [value: number] }>()
</script>

<template>
  <div class="flex gap-1" role="radiogroup" aria-label="Rating from 1 to 5">
    <button
      v-for="n in 5"
      :key="n"
      type="button"
      role="radio"
      :aria-checked="modelValue === n"
      class="rounded-md border font-medium tabular-nums transition-colors"
      :class="[
        size === 'sm' ? 'size-7 text-xs' : 'size-8 text-sm',
        modelValue === n ? 'border-primary bg-primary text-primary-foreground' : 'hover:bg-accent',
      ]"
      @click="emit('update:modelValue', n)"
    >
      {{ n }}
    </button>
  </div>
</template>
