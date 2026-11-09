<script setup lang="ts">
import { ref, watch, type Component } from 'vue'

/** Keyboard-driven popup list shared by the slash menu and [[wiki link]] autocomplete. */
export interface SuggestionItem {
  key: string
  title: string
  description?: string
  icon?: Component
  hint?: string
}

const props = defineProps<{ items: SuggestionItem[]; command: (item: SuggestionItem) => void; emptyText?: string }>()
const selected = ref(0)
const list = ref<HTMLElement>()

watch(() => props.items, () => (selected.value = 0))
watch(selected, (index) => list.value?.children[index]?.scrollIntoView({ block: 'nearest' }))

function onKeyDown(event: KeyboardEvent) {
  if (!props.items.length) return false
  if (event.key === 'ArrowDown') {
    selected.value = (selected.value + 1) % props.items.length
    return true
  }
  if (event.key === 'ArrowUp') {
    selected.value = (selected.value + props.items.length - 1) % props.items.length
    return true
  }
  if (event.key === 'Enter' || event.key === 'Tab') {
    props.command(props.items[selected.value]!)
    return true
  }
  return false
}

defineExpose({ onKeyDown })
</script>

<template>
  <div class="w-72 overflow-hidden rounded-lg border bg-popover text-popover-foreground shadow-lg">
    <div v-if="items.length" ref="list" class="max-h-80 overflow-y-auto p-1" role="listbox">
      <button
        v-for="(item, index) in items"
        :key="item.key"
        type="button"
        role="option"
        :aria-selected="index === selected"
        class="flex w-full items-center gap-2.5 rounded-md px-2 py-1.5 text-left text-sm"
        :class="index === selected ? 'bg-accent text-accent-foreground' : ''"
        @mouseenter="selected = index"
        @mousedown.prevent="command(item)"
      >
        <span v-if="item.icon" class="flex size-7 shrink-0 items-center justify-center rounded-md border bg-background">
          <component :is="item.icon" class="size-4 text-muted-foreground" />
        </span>
        <span class="min-w-0 flex-1">
          <span class="block truncate">{{ item.title }}</span>
          <span v-if="item.description" class="block truncate text-xs text-muted-foreground">{{ item.description }}</span>
        </span>
        <span v-if="item.hint" class="text-xs text-muted-foreground">{{ item.hint }}</span>
      </button>
    </div>
    <p v-else class="px-3 py-2 text-sm text-muted-foreground">{{ emptyText ?? 'No matches' }}</p>
  </div>
</template>
