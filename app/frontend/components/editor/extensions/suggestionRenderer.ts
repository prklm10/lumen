import { VueRenderer } from '@tiptap/vue-3'
import type { SuggestionKeyDownProps, SuggestionProps } from '@tiptap/suggestion'
import SuggestionList from '../SuggestionList.vue'

/** Mounts SuggestionList next to the caret (fixed positioning, flips above near the bottom). */
export function suggestionRenderer(extra: Record<string, unknown> = {}) {
  return () => {
    let renderer: VueRenderer | null = null

    const place = (props: SuggestionProps) => {
      const rect = props.clientRect?.()
      const el = renderer?.element as HTMLElement | undefined
      if (!rect || !el) return
      const below = window.innerHeight - rect.bottom > 340
      el.style.position = 'fixed'
      el.style.zIndex = '60'
      el.style.left = `${Math.min(rect.left, window.innerWidth - 300)}px`
      el.style.top = below ? `${rect.bottom + 6}px` : ''
      el.style.bottom = below ? '' : `${window.innerHeight - rect.top + 6}px`
    }

    return {
      onStart(props: SuggestionProps) {
        renderer = new VueRenderer(SuggestionList, { props: { ...props, ...extra }, editor: props.editor })
        document.body.appendChild(renderer.element!)
        place(props)
      },
      onUpdate(props: SuggestionProps) {
        renderer?.updateProps({ ...props, ...extra })
        place(props)
      },
      onKeyDown(props: SuggestionKeyDownProps) {
        if (props.event.key === 'Escape') {
          renderer?.element?.remove()
          return true
        }
        return (renderer?.ref as { onKeyDown?: (e: KeyboardEvent) => boolean } | null)?.onKeyDown?.(props.event) ?? false
      },
      onExit() {
        renderer?.element?.remove()
        renderer?.destroy()
        renderer = null
      },
    }
  }
}
