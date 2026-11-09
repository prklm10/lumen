<script setup lang="ts">
import { computed, ref } from 'vue'
import { Hash, X } from '@lucide/vue'
import { useTags } from '@/composables/useTasks'

/** Chips for a task's tags; type a name and press Enter or comma. Suggests existing tags. */
const props = defineProps<{ modelValue: string[] }>()
const emit = defineEmits<{ 'update:modelValue': [value: string[]] }>()

const { data: allTags } = useTags()
const draft = ref('')
const listId = `tags-${Math.random().toString(36).slice(2)}`

const suggestions = computed(() => {
  const taken = new Set(props.modelValue.map((t) => t.toLowerCase()))
  return (allTags.value ?? []).filter((t) => !taken.has(t.name.toLowerCase()))
})

function add() {
  const name = draft.value.trim().replace(/^#/, '').replace(/,$/, '').trim()
  draft.value = ''
  if (!name || props.modelValue.some((t) => t.toLowerCase() === name.toLowerCase())) return
  emit('update:modelValue', [...props.modelValue, name])
}

function remove(name: string) {
  emit('update:modelValue', props.modelValue.filter((t) => t !== name))
}

function onKeydown(event: KeyboardEvent) {
  if (event.key === 'Enter' || event.key === ',') {
    event.preventDefault()
    add()
  } else if (event.key === 'Backspace' && !draft.value && props.modelValue.length) {
    remove(props.modelValue[props.modelValue.length - 1]!)
  }
}
</script>

<template>
  <div class="flex min-h-8 flex-wrap items-center gap-1 rounded-md px-1 py-1 hover:bg-accent/50 focus-within:bg-accent/50">
    <span v-for="tag in modelValue" :key="tag" class="inline-flex items-center gap-0.5 rounded bg-secondary px-1.5 py-0.5 text-xs">
      <Hash class="size-3 text-muted-foreground" />{{ tag }}
      <button type="button" class="ml-0.5 rounded text-muted-foreground hover:text-foreground" :aria-label="`Remove ${tag}`" @click="remove(tag)">
        <X class="size-3" />
      </button>
    </span>
    <input
      v-model="draft"
      :list="listId"
      class="min-w-20 flex-1 bg-transparent px-1 text-sm outline-none placeholder:text-muted-foreground/70"
      :placeholder="modelValue.length ? '' : 'Add tags'"
      aria-label="Add a tag"
      @keydown="onKeydown"
      @blur="add"
    >
    <datalist :id="listId">
      <option v-for="tag in suggestions" :key="tag.id" :value="tag.name" />
    </datalist>
  </div>
</template>
