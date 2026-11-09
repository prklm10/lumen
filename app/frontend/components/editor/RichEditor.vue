<script setup lang="ts">
import { onBeforeUnmount, provide, ref, watch } from 'vue'
import { EditorContent, VueNodeViewRenderer, useEditor, type JSONContent } from '@tiptap/vue-3'
import StarterKit from '@tiptap/starter-kit'
import { TaskItem, TaskList } from '@tiptap/extension-list'
import { TableKit } from '@tiptap/extension-table'
import { Placeholder } from '@tiptap/extensions'
import CodeBlockLowlight from '@tiptap/extension-code-block-lowlight'
import type { RichDoc } from '@/api/tasks'
import { Callout } from './extensions/callout'
import { SlashCommand } from './extensions/slashCommand'
import { WikiLink, type WikiLinkTarget } from './extensions/wikiLink'
import { UploadableImage, hasPendingUploads, insertImages } from './extensions/imageUpload'
import { wikiLinkContextKey, type WikiLinkContext } from './context'
import { lowlight } from './lowlight'
import CalloutView from './CalloutView.vue'
import ImageView from './ImageView.vue'
import WikiLinkView from './WikiLinkView.vue'

/**
 * The block editor (LRN-1/2): TipTap with Markdown shortcuts, a `/` menu, [[wiki links]],
 * callouts, tables, to-dos, highlighted code and image upload by paste, drop or picker.
 * Emits the document as TipTap JSON — the format notes are stored in.
 */
const props = defineProps<{
  content: RichDoc
  /** Wiki-link support; required for notes, absent in the journal. */
  links?: WikiLinkContext & { search: (query: string) => WikiLinkTarget[] }
  placeholder?: string
  /**
   * Journal mode: no image upload (it would send the picture to the server unencrypted) and
   * no wiki links (they'd make the server-side link graph aware of journal content).
   */
  journal?: boolean
}>()
const emit = defineEmits<{ update: [doc: RichDoc] }>()

if (props.links) provide(wikiLinkContextKey, props.links)
const fileInput = ref<HTMLInputElement>()

const editor = useEditor({
  content: props.content as JSONContent,
  extensions: [
    StarterKit.configure({ codeBlock: false, link: { openOnClick: false, autolink: true, defaultProtocol: 'https' } }),
    CodeBlockLowlight.configure({ lowlight, defaultLanguage: null }),
    TaskList,
    TaskItem.configure({ nested: true }),
    TableKit.configure({ table: { resizable: false } }),
    Placeholder.configure({
      placeholder: ({ node }) => (node.type.name === 'heading' ? 'Heading' : props.placeholder ?? 'Type / for blocks, [[ to link a note'),
    }),
    Callout.extend({ addNodeView: () => VueNodeViewRenderer(CalloutView) }),
    ...(props.journal ? [] : [
      UploadableImage.extend({ addNodeView: () => VueNodeViewRenderer(ImageView) }),
      WikiLink.extend({ addNodeView: () => VueNodeViewRenderer(WikiLinkView) }).configure({ search: (q) => props.links?.search(q) ?? [] }),
    ]),
    SlashCommand.configure({ pickImage: () => fileInput.value?.click(), exclude: props.journal ? ['image', 'link'] : [] }),
  ],
  editorProps: {
    attributes: { class: 'lumen-prose', 'aria-label': 'Note content', spellcheck: 'true' },
    // Links open in a new tab with ⌘/Ctrl-click; a plain click just places the caret.
    handleClick(_view, _pos, event) {
      const anchor = (event.target as HTMLElement).closest('a')
      if (anchor && (event.metaKey || event.ctrlKey)) {
        window.open(anchor.href, '_blank', 'noopener')
        return true
      }
      return false
    },
  },
  onUpdate: ({ editor }) => emit('update', editor.getJSON() as RichDoc),
})

// Replacing the document (navigating to another note) shouldn't run through history or emit updates.
watch(() => props.content, (doc) => {
  const current = editor.value
  if (current && JSON.stringify(current.getJSON()) !== JSON.stringify(doc)) current.commands.setContent(doc as JSONContent, { emitUpdate: false })
})

function onPick(event: Event) {
  const input = event.target as HTMLInputElement
  if (editor.value && input.files?.length) insertImages(editor.value, Array.from(input.files))
  input.value = ''
}

onBeforeUnmount(() => editor.value?.destroy())

defineExpose({
  // view.focus() is synchronous; TipTap's focus command alone waits a frame, and keys typed
  // in between (e.g. right after Enter in the title) would land in the wrong field.
  focus: (where: 'start' | 'end' = 'start') => {
    editor.value?.view.focus()
    editor.value?.commands.focus(where)
  },
  hasPendingUploads: () => (editor.value ? hasPendingUploads(editor.value) : false),
  getJSON: () => editor.value?.getJSON() as RichDoc | undefined,
})
</script>

<template>
  <div>
    <EditorContent :editor="editor" />
    <input v-if="!journal" ref="fileInput" type="file" accept="image/*,.heic,.heif,.avif" multiple class="hidden" @change="onPick">
  </div>
</template>
