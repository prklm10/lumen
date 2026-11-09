<script setup lang="ts">
import type { Component } from 'vue'

defineProps<{ icon: Component; title: string; body?: string }>()
</script>

<template>
  <div class="flex flex-col items-center py-14 text-center">
    <div class="flex size-12 items-center justify-center rounded-full bg-primary/10 text-primary">
      <component :is="icon" class="size-5" />
    </div>
    <p class="mt-4 font-medium">{{ title }}</p>
    <p v-if="body" class="mt-1 max-w-xs text-sm text-muted-foreground">{{ body }}</p>
    <slot />
  </div>
</template>
