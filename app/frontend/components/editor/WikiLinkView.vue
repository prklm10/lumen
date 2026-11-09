<script setup lang="ts">
import { computed, inject } from 'vue'
import { NodeViewWrapper, nodeViewProps } from '@tiptap/vue-3'
import { wikiLinkContextKey } from './context'

const props = defineProps(nodeViewProps)
const ctx = inject(wikiLinkContextKey)!

// Show the target's current title, so renaming a note updates every link that points to it.
const target = computed(() => ctx.resolve(props.node.attrs.id, props.node.attrs.title))
</script>

<template>
  <NodeViewWrapper
    as="span"
    class="wiki-link"
    :class="[!target && 'wiki-link--missing', selected && 'wiki-link--selected']"
    :title="target ? `Open ${target.title}` : `Create “${node.attrs.title}”`"
    @click="ctx.open({ id: target?.id ?? null, title: target?.title ?? node.attrs.title })"
  >{{ target?.title ?? node.attrs.title }}</NodeViewWrapper>
</template>
