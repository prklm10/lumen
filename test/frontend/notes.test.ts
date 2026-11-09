import { describe, expect, it } from 'vitest'
import { buildTree, folderPath } from '@/composables/useNotes'
import type { Folder, NoteSummary } from '@/api/notes'

const folder = (id: number, parent_id: number | null, position = id): Folder => ({ id, name: `F${id}`, parent_id, position })
const note = (id: number, folder_id: number | null, position = id): NoteSummary => ({
  id, title: `N${id}`, icon: null, folder_id, pinned: false, position, created_at: '', updated_at: '',
})

describe('buildTree', () => {
  it('nests folders and puts notes in their folder, ordered by position', () => {
    const { roots, looseNotes } = buildTree(
      [folder(2, null, 2), folder(1, null, 1), folder(3, 1)],
      [note(10, 3, 2), note(11, 3, 1), note(12, null)],
    )
    expect(roots.map((f) => f.id)).toEqual([1, 2])
    expect(roots[0]!.children[0]!.notes.map((n) => n.id)).toEqual([11, 10])
    expect(looseNotes.map((n) => n.id)).toEqual([12])
  })

  it('treats notes in an unknown folder as loose rather than losing them', () => {
    expect(buildTree([], [note(1, 99)]).looseNotes).toHaveLength(1)
  })
})

describe('folderPath', () => {
  it('walks from the root to the folder', () => {
    const folders = [folder(1, null), folder(2, 1), folder(3, 2)]
    expect(folderPath(folders, 3).map((f) => f.id)).toEqual([1, 2, 3])
    expect(folderPath(folders, null)).toEqual([])
  })
})
