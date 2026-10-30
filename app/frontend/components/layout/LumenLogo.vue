<script setup lang="ts">
withDefaults(defineProps<{ size?: number }>(), { size: 24 })
</script>

<template>
  <svg :width="size" :height="size" viewBox="0 0 32 32" fill="none" aria-hidden="true">
    <rect width="32" height="32" rx="8" class="fill-primary" />
    <circle cx="16" cy="16" r="6.5" fill="white" fill-opacity="0.95" />
    <circle cx="16" cy="16" r="10.5" stroke="white" stroke-opacity="0.35" stroke-width="1.5" />
  </svg>
</template>
