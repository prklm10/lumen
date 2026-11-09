import { useRouter } from 'vue-router'
import type { WikiLinkContext } from '@/components/editor/context'
import type { WikiLinkTarget } from '@/components/editor/extensions/wikiLink'
import { useNoteMutations, useNotesList } from './useNotes'

/** Resolves, searches and follows [[wiki links]] against the notes list. */
export function useNoteLinks(currentId?: () => number | null): WikiLinkContext & { search: (q: string) => WikiLinkTarget[] } {
  const router = useRouter()
  const { data: notes } = useNotesList()
  const { create } = useNoteMutations()

  const byTitle = (title: string) => notes.value?.find((n) => n.title.toLowerCase() === title.trim().toLowerCase())

  return {
    resolve(id, title) {
      const note = (id && notes.value?.find((n) => n.id === id)) || byTitle(title)
      return note ? { id: note.id, title: note.title } : null
    },

    search(query) {
      const q = query.trim().toLowerCase()
      const others = (notes.value ?? []).filter((n) => n.id !== currentId?.())
      const scored = others
        .map((n) => {
          const t = n.title.toLowerCase()
          const score = !q ? 1 : t === q ? 100 : t.startsWith(q) ? 50 : t.includes(q) ? 10 : 0
          return { n, score }
        })
        .filter((x) => x.score > 0)
        .sort((a, b) => b.score - a.score || Date.parse(b.n.updated_at) - Date.parse(a.n.updated_at))
      return scored.map(({ n }) => ({ id: n.id, title: n.title }))
    },

    // Following a link to a note that doesn't exist yet creates it (LRN-4).
    async open(target) {
      const existing = (target.id && notes.value?.find((n) => n.id === target.id)) || byTitle(target.title)
      const id = existing ? existing.id : (await create.mutateAsync({ title: target.title })).id
      router.push({ name: 'note', params: { id } })
    },
  }
}
