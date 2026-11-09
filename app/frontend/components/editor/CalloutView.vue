<script setup lang="ts">
import { computed } from 'vue'
import { NodeViewContent, NodeViewWrapper, nodeViewProps } from '@tiptap/vue-3'
import { AlertTriangle, Info, Lightbulb } from '@lucide/vue'

const props = defineProps(nodeViewProps)
const icons = { info: Info, tip: Lightbulb, warning: AlertTriangle }
const next = { info: 'tip', tip: 'warning', warning: 'info' } as const
const kind = computed(() => (props.node.attrs.kind as keyof typeof icons) ?? 'info')
</script>

<template>
  <NodeViewWrapper class="callout" :data-callout="kind">
    <button
      type="button"
      contenteditable="false"
      class="callout__icon"
      :aria-label="`Callout type: ${kind}. Click to change.`"
      :title="`${kind} — click to change`"
      @click="editor.isEditable && updateAttributes({ kind: next[kind] })"
    >
      <component :is="icons[kind]" class="size-4" />
    </button>
    <NodeViewContent class="callout__content" />
  </NodeViewWrapper>
</template>
