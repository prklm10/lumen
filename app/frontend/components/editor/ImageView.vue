<script setup lang="ts">
import { computed } from 'vue'
import { NodeViewWrapper, nodeViewProps } from '@tiptap/vue-3'
import { uploadProgress } from './extensions/imageUpload'

const props = defineProps(nodeViewProps)
const progress = computed(() => (props.node.attrs.uploadId ? uploadProgress.get(props.node.attrs.uploadId) ?? 0 : null))
const large = computed(() => (props.node.attrs.signedId ? (props.node.attrs.src as string).replace(/\/medium$/, '/large') : null))

function openLarge() {
  if (large.value) window.open(large.value, '_blank', 'noopener')
}
</script>

<template>
  <NodeViewWrapper class="note-image" :class="selected && 'note-image--selected'" data-drag-handle>
    <img
      :src="node.attrs.src"
      :alt="node.attrs.alt ?? ''"
      :width="node.attrs.width ?? undefined"
      :height="node.attrs.height ?? undefined"
      :class="progress !== null && 'opacity-60'"
      loading="lazy"
      @dblclick="openLarge"
    >
    <div v-if="progress !== null" class="note-image__progress" role="progressbar" :aria-valuenow="Math.round(progress * 100)" aria-valuemin="0" aria-valuemax="100">
      <span :style="{ width: `${Math.max(4, progress * 100)}%` }" />
    </div>
  </NodeViewWrapper>
</template>
