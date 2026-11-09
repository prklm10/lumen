import { InputRule, Node, mergeAttributes } from '@tiptap/core'
import Suggestion from '@tiptap/suggestion'
import { PluginKey } from '@tiptap/pm/state'
import { FilePlus2, FileText } from '@lucide/vue'
import type { SuggestionItem } from '../SuggestionList.vue'
import { suggestionRenderer } from './suggestionRenderer'

export interface WikiLinkTarget {
  id: number | null
  title: string
}

export interface WikiLinkOptions {
  /** Notes to offer while typing after `[[`. */
  search: (query: string) => WikiLinkTarget[]
}

interface LinkItem extends SuggestionItem {
  target: WikiLinkTarget
}

/**
 * `[[Note title]]` links (LRN-4). Stored as an inline atom with the note's id and title; the
 * server reads these to build backlinks. Linking to a title with no note yet is allowed —
 * the link attaches when that note is created.
 */
export const WikiLink = Node.create<WikiLinkOptions>({
  name: 'wikiLink',
  group: 'inline',
  inline: true,
  atom: true,
  selectable: true,

  addOptions() {
    return { search: () => [] }
  },

  addAttributes() {
    return {
      id: { default: null, parseHTML: (el) => Number(el.dataset.id) || null, renderHTML: (a) => (a.id ? { 'data-id': a.id } : {}) },
      title: { default: '', parseHTML: (el) => el.dataset.title ?? el.textContent, renderHTML: (a) => ({ 'data-title': a.title }) },
    }
  },

  parseHTML() {
    return [{ tag: 'span[data-wiki-link]' }]
  },

  renderHTML({ node, HTMLAttributes }) {
    return ['span', mergeAttributes(HTMLAttributes, { 'data-wiki-link': '' }), node.attrs.title]
  },

  renderText({ node }) {
    return `[[${node.attrs.title}]]`
  },

  // Typing a complete [[Title]] (or pasting it as text) turns into a link too.
  addInputRules() {
    return [
      new InputRule({
        find: /\[\[([^[\]]{1,200})\]\]$/,
        handler: ({ state, range, match }) => {
          const title = match[1]!.trim()
          if (!title) return
          const existing = this.options.search(title).find((n) => n.title.toLowerCase() === title.toLowerCase())
          state.tr.replaceWith(range.from, range.to, this.type.create({ id: existing?.id ?? null, title: existing?.title ?? title }))
        },
      }),
    ]
  },

  addProseMirrorPlugins() {
    return [
      Suggestion<LinkItem>({
        editor: this.editor,
        pluginKey: new PluginKey('wikiLinkSuggestion'),
        char: '[[',
        allowSpaces: true,
        items: ({ query }) => {
          const q = query.trim()
          const matches: LinkItem[] = this.options.search(q).slice(0, 8)
            .map((n) => ({ key: `note-${n.id}`, title: n.title, icon: FileText, target: n }))
          const exact = matches.some((m) => m.title.toLowerCase() === q.toLowerCase())
          if (q && !exact) {
            matches.push({ key: 'create', title: `“${q}”`, description: 'New note — created when you open the link', icon: FilePlus2, target: { id: null, title: q } })
          }
          return matches
        },
        command: ({ editor, range, props }) => {
          // Swallow a "]]" the user may already have typed after the cursor.
          const after = editor.state.doc.textBetween(range.to, Math.min(range.to + 2, editor.state.doc.content.size))
          const to = after === ']]' ? range.to + 2 : range.to
          editor.chain().focus().insertContentAt({ from: range.from, to }, [
            { type: this.name, attrs: props.target },
            { type: 'text', text: ' ' },
          ]).run()
        },
        render: suggestionRenderer({ emptyText: 'Type a note title' }),
      }),
    ]
  },
})
