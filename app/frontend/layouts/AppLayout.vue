<script setup lang="ts">
import { ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import { useMediaQuery, useStorage } from '@vueuse/core'
import { PanelLeftOpen } from '@lucide/vue'
import AppSidebar from '@/components/layout/AppSidebar.vue'
import CommandPalette from '@/components/layout/CommandPalette.vue'
import { useGlobalShortcuts } from '@/composables/useGlobalShortcuts'

const route = useRoute()
const isMobile = useMediaQuery('(max-width: 767px)')
const desktopCollapsed = useStorage('lumen-sidebar-collapsed', false)
const mobileOpen = ref(false)
const paletteOpen = ref(false)

function toggleSidebar() {
  if (isMobile.value) mobileOpen.value = !mobileOpen.value
  else desktopCollapsed.value = !desktopCollapsed.value
}

const sidebarVisible = () => (isMobile.value ? mobileOpen.value : !desktopCollapsed.value)

watch(() => route.fullPath, () => (mobileOpen.value = false))

useGlobalShortcuts({ palette: () => (paletteOpen.value = !paletteOpen.value), toggleSidebar })
</script>

<template>
  <div class="flex h-dvh overflow-hidden">
    <div
      v-if="isMobile && mobileOpen"
      class="fixed inset-0 z-30 bg-black/30 backdrop-blur-[1px]"
      @click="mobileOpen = false"
    />
    <Transition
      enter-from-class="-translate-x-full"
      leave-to-class="-translate-x-full"
      enter-active-class="transition-transform duration-200 ease-out"
      leave-active-class="transition-transform duration-150 ease-in"
    >
      <AppSidebar
        v-if="sidebarVisible()"
        :class="isMobile ? 'fixed inset-y-0 left-0 z-40 shadow-xl' : ''"
        @search="paletteOpen = true"
        @collapse="toggleSidebar"
      />
    </Transition>

    <main class="relative flex min-w-0 flex-1 flex-col">
      <header class="flex h-11 shrink-0 items-center gap-2 px-3">
        <button
          v-if="!sidebarVisible()"
          type="button"
          class="rounded-md p-1.5 text-muted-foreground hover:bg-accent hover:text-accent-foreground"
          aria-label="Open sidebar"
          title="Open sidebar (⌘\)"
          @click="toggleSidebar"
        >
          <PanelLeftOpen class="size-4" />
        </button>
        <span class="text-sm text-muted-foreground">{{ route.meta.title }}</span>
      </header>
      <div class="flex-1 overflow-y-auto">
        <RouterView />
      </div>
    </main>

    <CommandPalette v-model:open="paletteOpen" />
  </div>
</template>
