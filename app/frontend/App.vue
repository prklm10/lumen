<script setup lang="ts">
import { computed } from 'vue'
import { Toaster } from '@/components/ui/sonner'
import { useTheme } from '@/composables/useTheme'

const { state } = useTheme()
const toasterTheme = computed(() => (state.value === 'dark' ? 'dark' : 'light'))
</script>

<template>
  <RouterView />
  <Toaster :theme="toasterTheme" position="bottom-right" />
</template>
