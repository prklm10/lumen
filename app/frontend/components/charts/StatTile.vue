<script setup lang="ts">
import { ArrowDownRight, ArrowUpRight } from '@lucide/vue'

/** A headline number. Change vs the previous period uses an arrow + words, not color alone. */
defineProps<{ label: string; value: string; hint?: string; delta?: { value: number; label: string } | null }>()
</script>

<template>
  <div class="rounded-xl border bg-card px-4 py-3">
    <p class="text-xs text-muted-foreground">{{ label }}</p>
    <p class="mt-1 text-2xl font-semibold tabular-nums tracking-tight">{{ value }}</p>
    <p v-if="delta" class="mt-0.5 flex items-center gap-1 text-xs text-muted-foreground">
      <component :is="delta.value >= 0 ? ArrowUpRight : ArrowDownRight" class="size-3.5" />
      {{ delta.label }}
    </p>
    <p v-else-if="hint" class="mt-0.5 text-xs text-muted-foreground">{{ hint }}</p>
  </div>
</template>
