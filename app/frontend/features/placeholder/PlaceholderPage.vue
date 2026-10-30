<script setup lang="ts">
import type { NavItem } from '@/lib/navigation'

defineProps<{ item: NavItem }>()
</script>

<template>
  <div class="mx-auto flex max-w-xl flex-col items-center px-6 pt-[18vh] text-center">
    <div class="flex size-14 items-center justify-center rounded-2xl border bg-card shadow-xs">
      <component :is="item.icon" class="size-6 text-primary" />
    </div>
    <h1 class="mt-6 text-2xl font-semibold tracking-tight">{{ item.label }}</h1>
    <p class="mt-2 text-balance text-muted-foreground">{{ item.description }}</p>
    <span class="mt-5 rounded-full border px-2.5 py-0.5 text-xs text-muted-foreground">Arrives in Phase {{ item.phase }}</span>
  </div>
</template>
