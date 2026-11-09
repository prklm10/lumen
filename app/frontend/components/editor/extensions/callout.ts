import { Node, mergeAttributes } from '@tiptap/core'

declare module '@tiptap/core' {
  interface Commands<ReturnType> {
    callout: {
      setCallout: (attrs?: { kind?: CalloutKind }) => ReturnType
      cycleCalloutKind: () => ReturnType
    }
  }
}

export type CalloutKind = 'info' | 'tip' | 'warning'
const kinds: CalloutKind[] = ['info', 'tip', 'warning']

/** A highlighted box of blocks. Click its icon to cycle info → tip → warning. */
export const Callout = Node.create({
  name: 'callout',
  group: 'block',
  content: 'block+',
  defining: true,

  addAttributes() {
    return {
      kind: {
        default: 'info',
        parseHTML: (el) => (kinds.includes(el.dataset.callout as CalloutKind) ? el.dataset.callout : 'info'),
        renderHTML: (attrs) => ({ 'data-callout': attrs.kind }),
      },
    }
  },

  parseHTML() {
    return [{ tag: 'div[data-callout]' }]
  },

  renderHTML({ HTMLAttributes }) {
    return ['div', mergeAttributes(HTMLAttributes, { class: 'callout' }), 0]
  },

  addCommands() {
    return {
      setCallout:
        (attrs) =>
        ({ commands }) =>
          commands.wrapIn(this.name, attrs),
      cycleCalloutKind:
        () =>
        ({ state, commands }) => {
          const { $from } = state.selection
          for (let depth = $from.depth; depth > 0; depth--) {
            const node = $from.node(depth)
            if (node.type.name === this.name) {
              const next = kinds[(kinds.indexOf(node.attrs.kind) + 1) % kinds.length]
              return commands.updateAttributes(this.name, { kind: next })
            }
          }
          return false
        },
    }
  },

  addKeyboardShortcuts() {
    return {
      // Backspace at the start of an empty callout unwraps it, like a quote.
      Backspace: ({ editor }) => {
        const { $from, empty } = editor.state.selection
        if (!empty || $from.parentOffset !== 0) return false
        const parent = $from.node(-1)
        if (parent?.type.name !== this.name || $from.index(-1) !== 0 || $from.parent.content.size !== 0) return false
        return editor.commands.lift(this.name)
      },
    }
  },
})
