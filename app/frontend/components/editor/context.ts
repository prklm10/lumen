import type { InjectionKey } from 'vue'
import type { WikiLinkTarget } from './extensions/wikiLink'

/** What wiki-link node views need from the page: resolving a link and following it. */
export interface WikiLinkContext {
  resolve: (id: number | null, title: string) => { id: number; title: string } | null
  open: (target: WikiLinkTarget) => void
}

export const wikiLinkContextKey: InjectionKey<WikiLinkContext> = Symbol('wikiLinkContext')
