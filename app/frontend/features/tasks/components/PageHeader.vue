<script setup lang="ts">
defineProps<{ title: string; subtitle?: string }>()
</script>

<template>
  <header class="mb-6 flex items-start gap-3">
    <slot name="icon" />
    <div class="min-w-0 flex-1">
      <h1 class="truncate text-2xl font-semibold tracking-tight">{{ title }}</h1>
      <p v-if="subtitle" class="mt-0.5 text-sm text-muted-foreground">{{ subtitle }}</p>
    </div>
    <slot name="actions" />
  </header>
</template>
