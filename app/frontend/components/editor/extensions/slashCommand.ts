import { Extension, type Editor, type Range } from '@tiptap/core'
import Suggestion from '@tiptap/suggestion'
import { PluginKey } from '@tiptap/pm/state'
import {
  CheckSquare, Code, Heading1, Heading2, Heading3, ImageIcon, Info, Link2, List, ListOrdered, Minus, Quote, Table, Type,
} from '@lucide/vue'
import type { SuggestionItem } from '../SuggestionList.vue'
import { suggestionRenderer } from './suggestionRenderer'

interface SlashItem extends SuggestionItem {
  keywords: string
  run: (editor: Editor, range: Range) => void
}

/** `/` opens a block menu (LRN-2). Markdown shortcuts (#, -, >, ```) come with StarterKit. */
export const SlashCommand = Extension.create<{ pickImage: () => void; exclude: string[] }>({
  name: 'slashCommand',

  addOptions() {
    return { pickImage: () => {}, exclude: [] }
  },

  addProseMirrorPlugins() {
    const pickImage = () => this.options.pickImage()
    const exclude = new Set(this.options.exclude)
    const all: SlashItem[] = [
      { key: 'text', title: 'Text', description: 'Plain paragraph', icon: Type, keywords: 'paragraph p', run: (e, r) => e.chain().focus().deleteRange(r).setParagraph().run() },
      { key: 'h1', title: 'Heading 1', description: 'Big section heading', icon: Heading1, hint: '#', keywords: 'title h1', run: (e, r) => e.chain().focus().deleteRange(r).setHeading({ level: 1 }).run() },
      { key: 'h2', title: 'Heading 2', icon: Heading2, hint: '##', keywords: 'subtitle h2', run: (e, r) => e.chain().focus().deleteRange(r).setHeading({ level: 2 }).run() },
      { key: 'h3', title: 'Heading 3', icon: Heading3, hint: '###', keywords: 'h3', run: (e, r) => e.chain().focus().deleteRange(r).setHeading({ level: 3 }).run() },
      { key: 'bullets', title: 'Bulleted list', icon: List, hint: '-', keywords: 'ul unordered', run: (e, r) => e.chain().focus().deleteRange(r).toggleBulletList().run() },
      { key: 'numbers', title: 'Numbered list', icon: ListOrdered, hint: '1.', keywords: 'ol ordered', run: (e, r) => e.chain().focus().deleteRange(r).toggleOrderedList().run() },
      { key: 'todo', title: 'To-do list', icon: CheckSquare, hint: '[ ]', keywords: 'task checkbox check', run: (e, r) => e.chain().focus().deleteRange(r).toggleTaskList().run() },
      { key: 'quote', title: 'Quote', icon: Quote, hint: '>', keywords: 'blockquote', run: (e, r) => e.chain().focus().deleteRange(r).toggleBlockquote().run() },
      { key: 'callout', title: 'Callout', description: 'Highlighted note or warning', icon: Info, keywords: 'info tip warning note box', run: (e, r) => e.chain().focus().deleteRange(r).setCallout().run() },
      { key: 'code', title: 'Code block', description: 'With syntax highlighting', icon: Code, hint: '```', keywords: 'snippet pre', run: (e, r) => e.chain().focus().deleteRange(r).setCodeBlock().run() },
      { key: 'table', title: 'Table', icon: Table, keywords: 'grid', run: (e, r) => e.chain().focus().deleteRange(r).insertTable({ rows: 3, cols: 3, withHeaderRow: true }).run() },
      { key: 'image', title: 'Image', description: 'Upload from your computer', icon: ImageIcon, keywords: 'photo picture upload', run: (e, r) => { e.chain().focus().deleteRange(r).run(); pickImage() } },
      { key: 'link', title: 'Link to note', description: 'Insert a [[wiki link]]', icon: Link2, keywords: 'wiki backlink', run: (e, r) => e.chain().focus().deleteRange(r).insertContent('[[').run() },
      { key: 'divider', title: 'Divider', icon: Minus, hint: '---', keywords: 'hr horizontal rule', run: (e, r) => e.chain().focus().deleteRange(r).setHorizontalRule().run() },
    ]
    const items = all.filter((item) => !exclude.has(item.key))

    return [
      Suggestion<SlashItem>({
        editor: this.editor,
        pluginKey: new PluginKey('slashCommand'),
        char: '/',
        startOfLine: false,
        items: ({ query }) => {
          const q = query.toLowerCase()
          return items.filter((item) => `${item.title} ${item.keywords}`.toLowerCase().includes(q))
        },
        command: ({ editor, range, props }) => props.run(editor, range),
        render: suggestionRenderer({ emptyText: 'No blocks match' }),
      }),
    ]
  },
})
