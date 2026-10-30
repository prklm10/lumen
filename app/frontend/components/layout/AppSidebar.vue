<script setup lang="ts">
import { PanelLeftClose, Search } from '@lucide/vue'
import { Kbd } from '@/components/ui/kbd'
import UserMenu from '@/components/layout/UserMenu.vue'
import { primaryNav, settingsNav } from '@/lib/navigation'

defineEmits<{ search: []; collapse: [] }>()
</script>

<template>
  <aside class="flex h-full w-60 shrink-0 flex-col border-r border-sidebar-border bg-sidebar text-sidebar-foreground">
    <div class="flex items-center gap-1 p-2">
      <div class="min-w-0 flex-1"><UserMenu /></div>
      <button
        type="button"
        class="rounded-md p-1.5 text-muted-foreground hover:bg-sidebar-accent hover:text-sidebar-accent-foreground"
        aria-label="Collapse sidebar"
        title="Collapse sidebar (⌘\)"
        @click="$emit('collapse')"
      >
        <PanelLeftClose class="size-4" />
      </button>
    </div>

    <div class="px-2 pb-2">
      <button
        type="button"
        class="flex w-full items-center gap-2 rounded-md px-2 py-1.5 text-muted-foreground hover:bg-sidebar-accent hover:text-sidebar-accent-foreground"
        @click="$emit('search')"
      >
        <Search class="size-4" />
        <span class="flex-1 text-left">Search</span>
        <Kbd>⌘K</Kbd>
      </button>
    </div>

    <nav class="flex-1 space-y-0.5 overflow-y-auto px-2" aria-label="Main">
      <RouterLink
        v-for="item in primaryNav"
        :key="item.name"
        :to="item.path"
        class="group flex items-center gap-2 rounded-md px-2 py-1.5 hover:bg-sidebar-accent hover:text-sidebar-accent-foreground"
        exact-active-class="bg-sidebar-accent text-sidebar-accent-foreground font-medium"
      >
        <component :is="item.icon" class="size-4 opacity-80" />
        <span class="flex-1">{{ item.label }}</span>
        <span v-if="item.phase" class="hidden text-[11px] text-muted-foreground group-hover:inline">Soon</span>
      </RouterLink>
    </nav>

    <div class="border-t border-sidebar-border p-2">
      <RouterLink
        :to="settingsNav.path"
        class="flex items-center gap-2 rounded-md px-2 py-1.5 hover:bg-sidebar-accent hover:text-sidebar-accent-foreground"
        exact-active-class="bg-sidebar-accent text-sidebar-accent-foreground font-medium"
      >
        <component :is="settingsNav.icon" class="size-4 opacity-80" />
        {{ settingsNav.label }}
      </RouterLink>
    </div>
  </aside>
</template>
