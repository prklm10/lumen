<script setup lang="ts">
import LumenLogo from '@/components/layout/LumenLogo.vue'

defineProps<{ title: string; subtitle: string }>()
</script>

<template>
  <div class="flex min-h-dvh items-center justify-center bg-sidebar px-4 py-12">
    <div class="w-full max-w-sm">
      <div class="mb-8 flex flex-col items-center text-center">
        <LumenLogo :size="40" />
        <h1 class="mt-5 text-xl font-semibold tracking-tight">{{ title }}</h1>
        <p class="mt-1.5 text-muted-foreground">{{ subtitle }}</p>
      </div>
      <div class="rounded-xl border bg-card p-6 shadow-xs">
        <slot />
      </div>
      <slot name="footer" />
    </div>
  </div>
</template>
