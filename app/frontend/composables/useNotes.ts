import { computed, toValue, type MaybeRefOrGetter } from 'vue'
import { useMutation, useQuery, useQueryClient } from '@tanstack/vue-query'
import { toast } from 'vue-sonner'
import { foldersApi, notesApi, type Folder, type NoteInput, type NoteSummary } from '@/api/notes'
import { errorMessage } from './useTasks'

export const noteKeys = {
  list: ['notes', 'list'] as const,
  detail: (id: number) => ['notes', 'detail', id] as const,
  folders: ['folders'] as const,
}

export function useNotesList() {
  return useQuery({ queryKey: noteKeys.list, queryFn: notesApi.list })
}

export function useFolders() {
  return useQuery({ queryKey: noteKeys.folders, queryFn: foldersApi.list })
}

export function useNote(id: MaybeRefOrGetter<number>) {
  return useQuery({
    queryKey: computed(() => noteKeys.detail(toValue(id))),
    queryFn: () => notesApi.get(toValue(id)),
    // The editor owns the content while open; refetching on focus would fight the user's typing.
    refetchOnWindowFocus: false,
    staleTime: Infinity,
  })
}

export interface FolderNode extends Folder {
  children: FolderNode[]
  notes: NoteSummary[]
}

/** Builds the folder tree (with notes in each folder) from the two flat lists. */
export function buildTree(folders: Folder[], notes: NoteSummary[]) {
  const byPosition = <T extends { position: number; id: number }>(a: T, b: T) => a.position - b.position || a.id - b.id
  const nodes = new Map<number, FolderNode>(folders.map((f) => [f.id, { ...f, children: [], notes: [] }]))
  const roots: FolderNode[] = []
  for (const node of nodes.values()) {
    const parent = node.parent_id ? nodes.get(node.parent_id) : undefined
    ;(parent ? parent.children : roots).push(node)
  }
  const looseNotes: NoteSummary[] = []
  for (const note of notes) {
    const folder = note.folder_id ? nodes.get(note.folder_id) : undefined
    ;(folder ? folder.notes : looseNotes).push(note)
  }
  const sort = (list: FolderNode[]) => {
    list.sort(byPosition)
    for (const n of list) {
      n.notes.sort(byPosition)
      sort(n.children)
    }
  }
  sort(roots)
  looseNotes.sort(byPosition)
  return { roots, looseNotes, byId: nodes }
}

/** Folder names from the root down to `folderId`, for breadcrumbs. */
export function folderPath(folders: Folder[], folderId: number | null) {
  const byId = new Map(folders.map((f) => [f.id, f]))
  const path: Folder[] = []
  let current = folderId ? byId.get(folderId) : undefined
  while (current && path.length < 50) {
    path.unshift(current)
    current = current.parent_id ? byId.get(current.parent_id) : undefined
  }
  return path
}

export function useNoteMutations() {
  const client = useQueryClient()
  const refreshList = () => client.invalidateQueries({ queryKey: noteKeys.list })
  const onError = (error: unknown) => toast.error(errorMessage(error))

  return {
    create: useMutation({
      mutationFn: (input: NoteInput) => notesApi.create(input),
      onSuccess: (note) => {
        client.setQueryData(noteKeys.detail(note.id), note)
        refreshList()
      },
      onError,
    }),
    /** Sidebar-level changes (move, pin, rename from the tree). The editor saves on its own. */
    update: useMutation({
      mutationFn: ({ id, input }: { id: number; input: NoteInput }) => notesApi.update(id, input),
      onSuccess: (note) => {
        client.setQueryData(noteKeys.detail(note.id), note)
        refreshList()
      },
      onError,
    }),
    destroy: useMutation({
      mutationFn: (id: number) => notesApi.destroy(id),
      onSuccess: () => {
        refreshList()
        client.invalidateQueries({ queryKey: ['tags'] })
      },
      onError,
    }),
  }
}

export function useFolderMutations() {
  const client = useQueryClient()
  const refresh = () => Promise.all([
    client.invalidateQueries({ queryKey: noteKeys.folders }),
    client.invalidateQueries({ queryKey: noteKeys.list }),
  ])
  const onError = (error: unknown) => toast.error(errorMessage(error))

  return {
    create: useMutation({ mutationFn: (input: Partial<Folder>) => foldersApi.create(input), onSuccess: refresh, onError }),
    update: useMutation({
      mutationFn: ({ id, input }: { id: number; input: Partial<Folder> }) => foldersApi.update(id, input),
      onSuccess: refresh,
      onError,
    }),
    destroy: useMutation({ mutationFn: (id: number) => foldersApi.destroy(id), onSuccess: refresh, onError }),
  }
}
